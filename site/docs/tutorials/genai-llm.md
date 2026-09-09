---
title: Run an LLM with ONNX Runtime GenAI
description: A decoder graph is not a chatbot. Wire up the tokenizer, the KV cache and the decode loop.
---

The Quick Start ran a single ONNX graph exactly once. That is not how a language
model works, and the gap trips up almost everyone who tries to go straight from
the Quick Start to generating text.

**Prerequisite:** a working install — the
[Linux]({{ '/docs/quickstart/linux/' | relative_url }}) or
[Windows]({{ '/docs/quickstart/windows/' | relative_url }}) Quick Start,
completed through the step that proves the GPU ran the graph.

## Why `session.run()` is not enough

An exported decoder graph maps *(tokens so far, KV cache) → (logits for one more
token, updated KV cache)*. Calling it once gives you a probability distribution
over the vocabulary for a single position. To get a sentence, something has to:

1. turn your text into token ids using the model's own tokenizer;
2. run prefill over the whole prompt;
3. pick a token from the logits (greedy, top-k, sampling — your choice);
4. feed that token back in, along with the KV cache from the previous step;
5. repeat until an end-of-sequence token or a length limit.

That loop is **ONNX Runtime GenAI**'s job — usually written `onnxruntime-genai`,
abbreviated OGA. It is a separate project from hip-ep and from ONNX Runtime
itself. hip-ep never sees any of it: OGA calls ONNX Runtime, ONNX Runtime calls
the execution provider, and the execution provider is hip-ep.

<div class="note" markdown="1">
This layering is why "hip-ep supports model X" and "OGA supports model X" are
different claims. A graph hip-ep compiles perfectly is still unusable for text
generation if OGA has no configuration describing how to drive it.
</div>

## What an OGA model directory contains

OGA does not consume a bare `.onnx` file. It consumes a directory:

| File | What it is |
|---|---|
| `model.onnx` | The graph |
| `model.onnx.data` | External weights, for anything past the 2 GB protobuf limit |
| `tokenizer.json`, `tokenizer_config.json` | The model's own tokenizer — not interchangeable between models |
| `genai_config.json` | How OGA drives the graph: input/output names, search defaults, **and which execution provider to use** |

Stage one from Hugging Face:

```bash
huggingface-cli download <repo-id> --local-dir "$HOME/oga-models/<name>"
```

Replace `<repo-id>` with a repository that publishes an ONNX GenAI export. A
PyTorch checkpoint will not work — the directory must already contain
`model.onnx` and `genai_config.json`.

## The one thing people get wrong

**The execution provider is selected inside `genai_config.json`, not on your
command line.** OGA reads the provider list out of the config and discovers the
EP library next to the OGA runtime library. There is no `--use-hip-ep` flag,
because there is no place in the OGA API to put one.

The relevant fragment looks like this:

```json
{
  "model": {
    "decoder": {
      "session_options": {
        "provider_options": [
          { "AMDGPU": { "profile": "hip" } }
        ]
      }
    }
  }
}
```

hip-ep is reached through the AMD GPU umbrella EP, which is why the provider
name is `AMDGPU` and the `hip` profile rather than a hip-ep-specific string. If
`provider_options` is empty or absent, OGA runs the model on the CPU and tells
you nothing.

<div class="note note--warn" markdown="1">
A model directory downloaded from Hugging Face will usually have a
`provider_options` targeting whatever hardware the publisher used. **Check it
before you conclude hip-ep is slow.** Some directories ship several configs
side by side (`genai_config_<variant>.json`); only the file actually named
`genai_config.json` is read.
</div>

## Option A — generate text from Python

The release package ships ONNX Runtime and OGA wheels under `wheels/`. They are
built for **CPython 3.14 only**; a 3.11 or 3.12 environment will refuse to
install them.

```bash
python -m venv "$HOME/oga-venv"
source "$HOME/oga-venv/bin/activate"          # Windows: $HOME\oga-venv\Scripts\Activate.ps1
python -m pip install "$ROOT"/wheels/*.whl
```

Then the whole loop, which is shorter than the explanation of it:

```python
import numpy as np
import onnxruntime_genai as og

MODEL_DIR = "/path/to/oga-model-dir"

# follow_config: take the provider list from genai_config.json. This is what
# you want -- see the section above.
config = og.Config(MODEL_DIR)
model = og.Model(config)
tokenizer = og.Tokenizer(model)

params = og.GeneratorParams(model)
params.set_search_options(
    max_length=512,
    do_sample=False,      # greedy: reproducible, which is what you want first
    temperature=0.0,
    top_k=1,
)

generator = og.Generator(model, params)
generator.append_tokens(
    np.array(tokenizer.encode("Explain what an execution provider is."),
             dtype=np.int32)
)

stream = tokenizer.create_stream()
while not generator.is_done():
    generator.generate_next_token()
    print(stream.decode(int(generator.get_next_tokens()[0])), end="", flush=True)
print()
```

Expected: a long pause, then tokens appearing one at a time.

**That first pause is hip-ep compiling the graph**, not a hang. On a large model
it can run to several minutes. Run the same script a second time and it starts
almost immediately — the compiled artifact is reused.

If you want to override the provider from Python instead of editing the config —
useful for producing a CPU baseline — clear and re-append:

```python
config = og.Config(MODEL_DIR)
config.clear_providers()          # now CPU-only
# config.append_provider("AMDGPU")  # put the GPU back
```

## Option B — measure it with `model_benchmark`

If your goal is a number rather than text, the release package includes
`model_benchmark`, the OGA benchmark harness. It reports prefill and decode
separately, which is what you actually care about.

```bash
$ROOT/bin/model_benchmark \
  -i /path/to/oga-model-dir \
  -l 128 -g 32 -ml -1 \
  -r 5 -w 1
```

| Flag | Meaning |
|---|---|
| `-i <path>` | OGA model directory (the one with `genai_config.json`) |
| `-l <n>` | Length of an auto-generated prompt |
| `--prompt_file <path>` | Use a real prompt from a file instead (mutually exclusive with `-l`) |
| `-g <n>` | Tokens to generate |
| `-r <n>` | Repetitions |
| `-w <n>` | Warm-up runs, excluded from the statistics |
| `-ml -1` | Keep `search.max_length` from `genai_config.json` |

<div class="note note--warn" markdown="1">
**Do not pass `--ep_library`.** Upstream `model_benchmark` rejects it. The EP is
discovered next to the OGA runtime library and selected by the config, exactly
as in option A.
</div>

**`-ml -1` is not optional for fixed-shape models.** Some models are exported as
a fixed-shape `prefill_*.onnx` + `decode_*.onnx` pair with a `max_length` baked
in. Without `-ml -1`, `model_benchmark` overrides the config's `search.max_length`
with *prompt + generation*, and decode fails with:

```text
Got invalid dimensions for input: attention_mask  Got: <l+g>  Expected: <max_length>
```

Passing `-ml -1` on a model that does not need it is harmless, so pass it.

## Verify it really used the GPU

`model_benchmark` will happily report CPU numbers without ever mentioning the
CPU. Before you trust any of this, run through
[Prove the GPU ran it]({{ '/docs/tutorials/verify-gpu/' | relative_url }}) — it
takes two minutes and it is the difference between a measurement and a guess.

## Troubleshooting

**The script generates text but at CPU speed**

`provider_options` in `genai_config.json` is empty, missing, or naming a
provider that is not installed. OGA does not warn about this.

**`ImportError` / `no matching distribution` installing the wheels**

The wheels are CPython 3.14 only. Check with `python -V`.

**Output is repetitive or degenerate**

That is a search-parameter problem, not a hip-ep problem. The example above is
deliberately greedy (`do_sample=False`, `top_k=1`) so that runs are comparable;
real deployments set `do_sample=True` with a temperature.

**The first run appears to hang**

It is compiling. `HIPDNN_EP_DEBUG=1` will show progress — but never leave it set
for a run you intend to measure.

## Next

- [Prove the GPU ran it]({{ '/docs/tutorials/verify-gpu/' | relative_url }})
- [Benchmark your own model]({{ '/docs/tutorials/benchmark/' | relative_url }})
