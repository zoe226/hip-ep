---
title: Run models with the C++ package
description: Extract the Windows release package and drive ONNX graphs, LLMs and vision-language models from the bundled binaries.
---

The release package is self-contained. The EP, the ONNX Runtime and OGA
binaries, the ROCm runtime and the CRT import libraries the JIT linker needs are
all inside the archive, so there is nothing to install, nothing to register and
no Visual Studio on the machine: extract it, put `bin\` on `PATH`, and run.

This page goes from an empty machine to models you actually care about: extract,
verify with a model it generates for you, then run ONNX graphs, an LLM and a
vision-language model with the tools in `bin\`. If you would rather not follow
it by hand, steps up to the verification are also available as a single script —
[One-command deploy]({{ '/docs/get-started/deploy-script/' | relative_url }}),
which covers `gfx1151` only. Read this page anyway when something goes wrong;
the script's checks are these checks.

| Item | Requirement |
|---|---|
| OS | Windows, x64 |
| Shell | **PowerShell.** Every command below is PowerShell syntax; the classic Command Prompt is not supported |
| GPU | Ryzen AI Max (`gfx1151`), Ryzen AI (`gfx1150` / `gfx1152`), with a current [Adrenalin driver](https://www.amd.com/en/support) — the driver is what supplies `amdhip64_7.dll` |
| Disk | About 610 MB extracted, from a 232 MB download |
| Python | Only for the vision-language section, and only CPython 3.14 |

## Get the package

```powershell
$Root = "$HOME\hip-ep-runtime"
New-Item -ItemType Directory -Force -Path $Root | Out-Null
Set-Location $Root

$Url = "{{ site.repo_url }}/releases/download/{{ site.hip_ep_version }}/gpu-test-package-windows-{{ site.hip_ep_version }}.zip"
Invoke-WebRequest -Uri $Url -OutFile "$Root\hip-ep.zip"
Expand-Archive -Path "$Root\hip-ep.zip" -DestinationPath "$Root\hip-ep" -Force
```

The archive has no top-level directory of its own, which is why it is extracted
into one explicitly. `-Force` makes the step safe to re-run.

| Path | Contents |
|---|---|
| `bin\` | Every binary and every DLL, including the ROCm runtime |
| `lib\` | Import libraries the JIT linker passes to `lld-link` |
| `wheels\` | ONNX Runtime and OGA wheels, **CPython 3.14 only** |
| `morphizen_config.json` | EP configuration read at session creation |

## Put `bin` on PATH

```powershell
$env:HIPEP_ROOT = "$HOME\hip-ep-runtime\hip-ep"
$env:PATH = "$env:HIPEP_ROOT\bin;$env:PATH"

& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" --help | Select-Object -First 3
```

Expected: a usage block. This sets the environment for the current PowerShell
session only — nothing is written to the registry, and deleting
`$HOME\hip-ep-runtime` removes hip-ep completely.

<div class="note" markdown="1">
**Run the executables where they are.** Windows searches an executable's own
directory first, and every dependency — the EP, the custom-kernel DLLs, the HIP
runtime, hipBLASLt — is resolved relative to `bin\`. Copying a single `.exe`
somewhere else produces "The specified module could not be found" or a bare
`0xc0000135` exit, which names neither the missing DLL nor the reason. Call the
binaries by full path instead of moving them.
</div>

## What is in `bin`

| Tool | Use it for |
|---|---|
| `hip-onnx-runner.exe` | One ONNX graph, one session, random or supplied inputs. The quickest way to find out whether a model compiles at all |
| `onnxruntime_perf_test.exe` | Steady-state latency for a single graph |
| `model_benchmark.exe` | Text generation through OGA — prefill and decode, end to end |
| `model_mm.exe`, `benchmark_multimodal.py` | The same, for vision-language models |
| `hipgpu.dll` | The EP itself, with the compiler linked into it |
| `custom_kernels_gfx*.dll` | The HIP kernels, JIT-loaded by architecture |
| `DirectML.dll` | Present so the DML EP is available as a same-machine baseline |

## Check the install

Before pointing this at a model that takes minutes to compile, prove the
installation works on one that takes a second. Rather than downloading
something, generate it locally: it depends on nothing gated and is
byte-identical for everyone reading this page.

```powershell
Set-Location "$HOME\hip-ep-runtime"
python -m pip install --quiet onnx

@'
import onnx
from onnx import TensorProto, helper, numpy_helper
import numpy as np

rng = np.random.default_rng(0)
w = numpy_helper.from_array(rng.standard_normal((512, 512), dtype=np.float32), "W")
b = numpy_helper.from_array(rng.standard_normal((512,), dtype=np.float32), "B")

graph = helper.make_graph(
    [
        helper.make_node("MatMul", ["X", "W"], ["mm"]),
        helper.make_node("Add", ["mm", "B"], ["add"]),
        helper.make_node("Relu", ["add"], ["Y"]),
    ],
    "smoke",
    [helper.make_tensor_value_info("X", TensorProto.FLOAT, [1, 512])],
    [helper.make_tensor_value_info("Y", TensorProto.FLOAT, [1, 512])],
    [w, b],
)
model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 17)])
model.ir_version = 10
onnx.checker.check_model(model)
onnx.save(model, "smoke.onnx")
print("wrote smoke.onnx")
'@ | Set-Content -Path make_smoke.py

python make_smoke.py
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx
```

`ir_version` is pinned because ONNX Runtime rejects models newer than the IR
version it was built against, and the `onnx` package on PyPI moves faster than
the pinned runtime does. **Any** Python will do for this — the CPython 3.14
constraint applies to the wheels in `wheels\`, not to generating a model.

Expected: the run completes in a few seconds, most of it spent compiling during
session creation. On a Ryzen AI Max it took 2.40 s, then 2.12 s, then 2.11 s —
re-running is not faster, because there is no on-disk artifact cache in
`{{ site.hip_ep_version }}`.

Now check that the GPU, and not the CPU EP, produced those numbers. Dump the
outputs both ways and compare them:

```powershell
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx -d 2       # EP  -> smoke_o_dump\
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx -d 2 -n    # CPU -> smoke_cpu_o_dump\
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -L smoke_o_dump,smoke_cpu_o_dump
```

Dump directories are named from the model file's stem, so the two do not
overwrite each other; with a model of your own they are `<stem>_o_dump` and
`<stem>_cpu_o_dump`.

Expected: a small L2 norm, on the order of `0.02` for this model on a Ryzen AI
Max. **Read the magnitude, not the digits.** Bit equality is neither expected
nor a goal — the GPU path uses different kernels and a different accumulation
order — and three runs of this check on one machine, same driver, same package,
byte-identical `smoke.onnx`, produced `0.0239186`, `0.0234262` and `0.0217464`,
because the GEMM library does not have to pick the same algorithm twice.
Anything in the same order of magnitude is a pass. A result in the ones, or a
non-finite one, is a real failure worth stopping on.

<div class="note" markdown="1">
**Do not read a performance result out of `smoke.onnx`.** Three nodes over a
512×512 matrix is deliberately small enough to generate inline, and at that size
launch and dispatch overhead is nearly all of the measurement — including
against the DML baseline that `DirectML.dll` makes available. It is a check that
the toolchain works end to end, not a workload. Take performance from
[the benchmarks]({{ '/docs/benchmarks/' | relative_url }}) or from a model of
your own at a realistic size.
</div>

## Run a single ONNX graph

```powershell
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m C:\path\to\model.onnx
```

The first run is slow, and not because the model is slow: the graph is compiled
during session creation, and `{{ site.hip_ep_version }}` has no on-disk artifact
cache, so every invocation pays that cost again. The `Inference:` line it prints
is the first inference on a freshly compiled model, carrying kernel load and
warm-up with it — treat it as a smoke signal, not a latency.

| Flag | Meaning |
|---|---|
| `-m <file>` | The `.onnx` model |
| `-i <dir>` | Read inputs from a directory instead of generating random ones |
| `-f <name>:<value>` | Pin a symbolic input dimension for the run; repeatable. The EP still compiles the dynamic graph |
| `-n` | CPU only — skip EP registration entirely |
| `-d <level>` | Dump: `0` off, `1` inputs, `2` outputs, `3` both |
| `-L <dir1>,<dir2>` | L2-norm comparison between two dump directories |

Random inputs are fine for a vision model and wrong for a language model, whose
`input_ids` must be below the vocabulary size. Generate a valid input directory
first:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/{{ site.repo }}/main/tools/hip-onnx-runner/gen_hip_onnx_runner_inputs.py" -OutFile gen_inputs.py
python gen_inputs.py -o gen_inputs C:\path\to\llm.onnx
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m C:\path\to\llm.onnx -i gen_inputs
```

For steady-state latency on the same graph, give `onnxruntime_perf_test` enough
wall time that the one-off compile does not dominate the average:

```powershell
Set-Location "$env:HIPEP_ROOT\bin"
.\onnxruntime_perf_test.exe `
  --plugin_ep_libs "hipgpu|hipgpu.dll" `
  --plugin_eps "hipgpu" `
  -C "session.disable_cpu_ep_fallback|1" `
  -t 60 -c 1 -s -I `
  C:\path\to\model.onnx
```

`session.disable_cpu_ep_fallback|1` matters here in a way it does not for
`hip-onnx-runner`, which sets it for you. Without it, a graph the EP could not
claim is measured on the CPU and reported as a result.

## Run an LLM end to end

`model_benchmark.exe` drives the whole generative pipeline — tokenizer, prefill,
KV cache, decode loop. Point `-i` at an **OGA model directory**: the one holding
`genai_config.json` and the tokenizer files, not a bare `.onnx` file.

```powershell
Set-Location "$env:HIPEP_ROOT\bin"
.\model_benchmark.exe -i C:\path\to\Llama-3.1-8B-awq-g128-int4-asym-fp16-onnx-dml `
  -l 128 -g 128 -r 5 -w 1 -b 1 -v
```

| Flag | Meaning |
|---|---|
| `-i <dir>` | OGA model directory |
| `-l <n>` | Prompt length, auto-generated. Mutually exclusive with `--prompt_file` |
| `--prompt_file <path>` | Use real prompt text instead |
| `-g <n>` | Tokens to generate |
| `-r <n>` / `-w <n>` | Repetitions / warm-up runs |
| `-b <n>` | Batch size |
| `-v` | Verbose |

Three things about this command are non-obvious, and each one fails with an
error that does not name the real problem:

- **Do not pass `--ep_library`.** Upstream `model_benchmark` rejects it. The EP
  is discovered next to `onnxruntime-genai.dll`, which is the other reason
  everything has to stay in `bin\`.
- **Leave `-e` alone.** Its accepted values are `cpu`, `cuda`, `dml` and
  `NvTensorRtRtx`; there is no AMD entry and the absence is not an oversight. A
  run that leaves `-e` at its `cpu` default still executes on hip-ep, because
  the model's `provider_options` is what selects the provider.
- **`-ml -1` is a deliberate choice, not a default to copy.** It means "use the
  config's `search.max_length`". A `prefill_*.onnx` / `decode_*.onnx` pair with
  a fixed attention-mask shape needs it. A dynamic-shape decoder whose config
  says `search.max_length: 32768` does not — passing it there sizes the KV cache
  for 32768 tokens in order to generate 128.

Example output — `Llama-3.1-8B-awq-g128-int4-asym-fp16-onnx-dml` on `gfx1151`.
Numbers vary by machine, driver and thermal state:

```text
[ConvertOnnxToHipPass] streaming: 743 file-ref + 2 splat -> per-entry descriptors
Running warmup iterations (1)...
Running iterations (5)...
Batch size: 1, prompt tokens: 128, tokens to generate: 128
Prompt processing (time to first token):
        avg (tokens/s): 513.82
Token generation:
        avg (tokens/s): 33.85
E2E generation (entire generation loop):
        avg (ms):       4000.83
Peak working set size (bytes): 1304625152
```

Two of those are the ones to read: **prompt processing**, which is where
time-to-first-token comes from, and **token generation** in tokens per second.
E2E is the sum of the two over the whole loop.

The `[ConvertOnnxToHipPass]` line is the compiler reporting what it did with the
model's constants, and together with the `hipdnn_ep_get_pool_base: growing
pool[0] ...` lines it is evidence the run reached hip-ep rather than falling
back to the CPU EP.

## Run a vision-language model

`model_benchmark` is a text-only harness. Pointed at a multi-modal model it
fails with

```text
Exception: Invalid rank for input: image_features  Got: 2  Expected: 3
```

which reads like a broken model and is not one — the harness simply has no way
to produce the image tensor the embedding graph expects. The tell is a
`model.vision` section in `genai_config.json`, or a `vision.onnx` beside the
decoder.

The package ships an OGA example for that case instead: `model_mm.exe`, with
`benchmark_multimodal.py` as its scripted driver. `model_mm` reads
`genai_config.json` straight out of the model directory, so the directory's
active config must already select hip-ep (see below).

```powershell
Set-Location "$env:HIPEP_ROOT\bin"
.\model_mm.exe --help
```

Both are upstream OGA examples rather than hip-ep tools, so take the flag list
from `--help` rather than from this page. One behaviour is worth knowing in
advance: **`model_mm` ignores `-g` / `--max_new_tokens`**. Generation runs until
EOS, bounded only by `search.max_length` in the config, so capping the token
count means editing that value.

If you would rather drive vision-language models from a script you can modify,
that is the [Python package]({{ '/docs/get-started/python-package/' | relative_url }})
route.

## Models

Pre-quantized ONNX models that run on hip-ep. Download a model directory, then
point `-i` at it.

| Model | Type | Download |
|---|---|---|
| `DeepSeek-R1-Distill-Llama-70B-dml-int4-awq-block-128` | Dense 70B | AMD internal |
| `gpt-oss-120b-w-uint4-pergroup-asym-awq-onnx-fp16` | MoE 120B | [Hugging&nbsp;Face](https://huggingface.co/amd/gpt-oss-120b-w-uint4-pergroup-asym-awq-onnx-fp16) |
| `Llama-3.1-8B-awq-g128-int4-asym-fp16-onnx-dml` | Dense 8B | [Hugging&nbsp;Face](https://huggingface.co/amd/Llama-3.1-8B-awq-g128-int4-asym-fp16-onnx-dml) |
| `Mistral-7B-Instruct-v0.3-dml-int4-awq-block-128` | Dense 7B | AMD internal |
| `phi4-14B-int4-rtn-block-32_directml` | Dense 14B | AMD internal |
| `Qwen2.5-14B-instruct-rtn-128gs-fp16-onnx-gpu` | Dense 14B | [Hugging&nbsp;Face](https://huggingface.co/amd/Qwen2.5-14B-instruct-rtn-128gs-fp16-onnx-gpu) |
| `Qwen2.5-Coder-14B-instruct-rtn-128gs-fp16-onnx-gpu` | Dense 14B | [Hugging&nbsp;Face](https://huggingface.co/amd/Qwen2.5-Coder-14B-instruct-rtn-128gs-fp16-onnx-gpu) |
| `gpt-oss-20b-webgpu-int4-rtn-block-32` | MoE 20B | [Hugging&nbsp;Face](https://huggingface.co/onnxruntime/gpt-oss-20b-onnx) |
| `Qwen3.5-35B-A3B-fp16-ve-fp16-int4-text-gs32-dml` | MoE 35B | [Hugging&nbsp;Face](https://huggingface.co/amd/Qwen3.5-35B-A3B-fp16-ve-fp16-int4-text-gs32-dml) |
| `Qwen3.5-9B-fp16-ve-fp16-int4-text-gs32-dml` | Dense 9B | [Hugging&nbsp;Face](https://huggingface.co/amd/Qwen3.5-9B-fp16-ve-fp16-int4-text-gs32-dml) |
| `gemma3-4b-it-rtn-int4-128gs-fp16-onnx-gpu` | Dense 4B, vision-language | [Hugging&nbsp;Face](https://huggingface.co/amd/gemma3-4b-it-rtn-int4-128gs-fp16-onnx-gpu) |
| `Qwen3.6-35B-A3B-fp16-ve-fp16-int4-text-gs32-dml` | MoE 35B | [Hugging&nbsp;Face](https://huggingface.co/amd/Qwen3.6-35B-A3B-fp16-ve-fp16-int4-text-gs32-dml) |

<p class="table-note">
These are the quantized ONNX artifacts, not the base models — the
<a href="{{ '/docs/models/' | relative_url }}">model matrix</a> covers what each
one is and how it was validated. Most of the <code>amd/</code> repositories are
gated: you will need to be signed in to Hugging Face and have requested access
before the download works. The three marked AMD internal have no public mirror.
</p>

### Selecting the EP in `genai_config.json`

For anything driven through OGA — `model_benchmark`, `model_mm`, or your own
code — the provider is selected by the model, not by the command line. Open
`genai_config.json` and set `model` → `decoder` → `session_options` →
`provider_options` to:

```json
"provider_options": [
  { "AMDGPU": { "profile": "hip" } }
]
```

Published ONNX artifacts for Windows are commonly built for DirectML and ship
`[ { "dml": {} } ]` instead. Nothing about that is an error — it is another
provider's configuration — but it is what selects the provider, so hip-ep never
sees the graph. Keep a copy of the original; the rest of the config carries over
unchanged.

<div class="note note--warn" markdown="1">
**Do not save that file with a byte-order mark.** OGA's JSON parser rejects one,
and the message blames your first character rather than the encoding:

```text
Exception: Error encountered while parsing genai_config.json  JSON Error: Unknown value "" at line 1 index 1
```

PowerShell 5.1's `Set-Content -Encoding utf8` writes a BOM, and so does
Notepad's plain "UTF-8". Write it without one:

```powershell
[IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
```

To check: `Get-Content $path -Encoding Byte -TotalCount 3` should be
`123 13 10` (`{`, CR, LF), not `239 187 191`.
</div>

## Confirm the GPU ran it

ONNX Runtime does not fail when a provider cannot take your graph — it runs that
part on the CPU and returns correct answers. A model that never reached the GPU
looks exactly like one that did, only slower, so end every one of these runs by
ruling it out.

```powershell
$env:MORPHIZEN_DEBUG_MORPHIZEN_EP = "1"
.\model_benchmark.exe -i C:\path\to\model-dir -l 128 -g 32 -r 1 -w 0
Remove-Item Env:\MORPHIZEN_DEBUG_MORPHIZEN_EP
```

Expected, in the log:

```text
morphizen-ep.cpp:344] Using backend: mlir-backend
```

That line is the provider stating what it did. It is direct attribution, and
unlike a speed comparison it does not depend on knowing how fast the model
should have been. The `hipdnn_ep_get_pool_base: growing pool[0] ...` lines are
the same kind of evidence from the runtime side: they come from the GPU memory
pool, which a CPU run has no reason to touch.

<div class="note note--warn" markdown="1">
**Do not benchmark with either debug variable set.** `MORPHIZEN_DEBUG_MORPHIZEN_EP`,
`HIPDNN_EP_DEBUG=1` and `HIPDNN_EP_PERF=1` add per-operation instrumentation,
and numbers collected with any of them are not comparable to anything. Run GPU
benchmarks serially, too — a concurrent run invalidates both.
</div>

For a graph you expect to be fully offloaded, `HIPDNN_EP_STRICT` turns the
fallback into a failure, stopping at the pass that gave up with the operator
named:

```powershell
$env:HIPDNN_EP_STRICT = "1"
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m C:\path\to\model.onnx
Remove-Item Env:\HIPDNN_EP_STRICT
```

<div class="note note--warn" markdown="1">
**Unset that variable to turn it off — do not set it to `0`.** It is tested for
presence, not for value, so `HIPDNN_EP_STRICT=0` enables strict mode exactly as
`=1` does. `Remove-Item Env:\HIPDNN_EP_STRICT` is the only way to disable it.
</div>

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `The specified module could not be found`, or exit `0xc0000135` | An executable was run from a copy outside `bin\`. Run it in place |
| `Failed to load ... amdhip64_7.dll` | `bin\` is not on `PATH`, or the graphics driver is too old to supply it |
| `EP library not found: hipgpu.dll` | `hip-onnx-runner` searches `%MORPHIZEN_EP_LIB%`, then the working directory, then its own directory, then `..\lib`. From `bin\` no variable is needed; from elsewhere set `MORPHIZEN_EP_LIB` to the DLL's full path |
| The first run appears to hang | It is compiling. A large model can take several minutes on the first inference. `HIPDNN_EP_DEBUG=1` shows progress — just do not benchmark with it set |
| `Got invalid dimensions for input: attention_mask` | Either `-ml -1` is missing, or `-l <n>` does not match `model.decoder.fixed_prompt_length` in the config |
| `Invalid rank for input: image_features` | A multi-modal model under `model_benchmark`. Use `model_mm` instead |
| Correct results, no faster than CPU | Rule out the fallback first, above. If it really is on the GPU, the model may simply be too small for the GPU to pay for itself — at small sizes launch and dispatch overhead is most of the measurement |

## Next

- [Run models from Python]({{ '/docs/get-started/python-package/' | relative_url }}) — the same models from a script you can edit.
- [Run models from a source build]({{ '/docs/get-started/source-build/' | relative_url }}) — when you need to change the compiler.
- [Benchmarks]({{ '/docs/benchmarks/' | relative_url }}) — the published numbers, and the conditions behind them.
