---
title: Run models from Python
description: Install the hip-ep wheels into a Python 3.14 environment and drive ONNX models, LLMs and vision-language models from scripts you can edit.
---

The Python package is the same EP as the [C++ package]({{ '/docs/tutorials/cpp-package/' | relative_url }}),
delivered as wheels. Nothing has to be placed by hand and no Visual Studio is
needed: the EP's native files — the plugin itself, the custom kernels, the ROCm
runtime and the CRT import libraries the JIT linker uses — install into the
package directory with the wheel, and ONNX Runtime and OGA discover them from
there.

Take this route when you want to write the generation loop yourself, wrap the
model in a service, or change what the benchmark measures. If you only need to
run a model and read numbers off it, the C++ package is fewer moving parts.

| Item | Requirement |
|---|---|
| OS | Windows, x64 |
| Shell | **PowerShell.** Every command below is PowerShell syntax |
| GPU | Ryzen AI Max (`gfx1151`), Ryzen AI (`gfx1150` / `gfx1152`), with a current [Adrenalin driver](https://www.amd.com/en/support) |
| Python | **CPython 3.14, exactly.** The wheels are `cp314` and pip will refuse every other interpreter |

## Get the package

```powershell
$Root = "$HOME\hip-ep-python"
New-Item -ItemType Directory -Force -Path $Root | Out-Null
Set-Location $Root

$Url = "{{ site.repo_url }}/releases/download/{{ site.hip_ep_version }}/hip-python-package-windows-{{ site.hip_ep_version }}.zip"
Invoke-WebRequest -Uri $Url -OutFile "$Root\hip-python-package.zip"
Expand-Archive -Path "$Root\hip-python-package.zip" -DestinationPath "$Root\pkg" -Force

Get-ChildItem "$Root\pkg"
```

| Path | Contents |
|---|---|
| `wheels\` | The four wheels, below |
| `run_onnx.py` | The launcher. Sets the environment the EP needs, then runs a model or delegates to a benchmark script |
| `benchmark_e2e.py` | OGA's end-to-end text benchmark |
| `vlm_benchmark.py` | Vision-language benchmark — TTFT, tokens/s, image preprocessing |

| Wheel | Role |
|---|---|
| `onnxruntime_directml-*.whl` | ONNX Runtime, built with plugin-EP support |
| `onnxruntime_genai_directml-*.whl` | OGA — tokenizer, KV cache, decode loop |
| `onnxruntime_ep_amdgpu-*.whl` | The AMD GPU umbrella EP that OGA asks for by name |
| `onnxruntime_ep_hip-*.whl` | hip-ep: the plugin, the compiler inside it, the kernels and the ROCm runtime |

## Install

```powershell
py -3.14 -m venv .venv
.venv\Scripts\activate
python -V        # expect 3.14.x

Set-Location "$HOME\hip-ep-python\pkg\wheels"

# 1. Runtime and generative stack, with their dependencies.
pip install (Get-Item onnxruntime_directml-*.whl).Name `
            (Get-Item onnxruntime_genai_directml-*.whl).Name `
            psutil tqdm pandas

# 2. The two EP wheels, in this order, without dependency resolution.
pip install --no-deps (Get-Item onnxruntime_ep_amdgpu-*.whl).Name
pip install --no-deps (Get-Item onnxruntime_ep_hip-*.whl).Name

Set-Location "$HOME\hip-ep-python"
```

<div class="note" markdown="1">
**The order of those last two is load-bearing, and so is `--no-deps`.**
`onnxruntime_ep_hip` unpacks its native files *into the `onnxruntime_ep_amdgpu`
package directory* — that colocation is what lets the umbrella resolve
`hipgpu.dll` by bare name, with no path and no environment variable. Installing
them the other way round means the umbrella directory is rewritten after hip-ep
has populated it. `--no-deps` keeps pip from replacing the two custom builds
above with stock PyPI releases that have no plugin-EP support.
</div>

Verify:

```powershell
python -c "import onnxruntime_ep_amdgpu as m; print(m.get_library_path())"
```

Expected: a path ending in `onnxruntime_ep_amdgpu\`. Note the import name —
the distribution you install is `onnxruntime_ep_hip`, the package you import is
`onnxruntime_ep_amdgpu`, and pip will happily tell you the first is installed
while an import of the same name fails.

## Run a single ONNX graph

```powershell
python pkg\run_onnx.py C:\path\to\model.onnx
```

`run_onnx.py` registers the plugin with `ort.register_execution_provider_library`,
sets `session.disable_cpu_ep_fallback` so a graph the EP cannot take is an error
rather than a silent CPU run, feeds random inputs, and prints the shape and
dtype of every output.

Expected, before the outputs:

```text
MorphiZenEP device(s): 1 (['AMD'])
providers: ['MorphiZenEP', 'CPUExecutionProvider']
```

Random inputs are fine for a vision model and wrong for a language model, whose
`input_ids` must be below the vocabulary size — use the OGA path below for those
rather than feeding a decoder noise.

## Run an LLM end to end

```powershell
python pkg\run_onnx.py --benchmark pkg\benchmark_e2e.py `
  -i C:\path\to\Llama-3.1-8B-awq-g128-int4-asym-fp16-onnx-dml `
  -l 128 -g 128 -r 5 -w 1 -b 1 -m -1 -v
```

`--benchmark` is not a mode of the benchmark; it is a mode of the launcher. The
script sets `AMDGPU_EP_PATH` — OGA looks for the umbrella next to
`onnxruntime.dll`, and in a wheel install it is not there — and `LIB`, which the
JIT linker needs, then runs the script you named as a child process with both
inherited. That is the whole reason to go through it rather than calling
`benchmark_e2e.py` directly.

| Flag | Meaning |
|---|---|
| `-i <dir>` | OGA model directory: the one with `genai_config.json` |
| `-l <n>` / `-g <n>` | Prompt length / tokens to generate |
| `-r <n>` / `-w <n>` | Repetitions / warm-up runs |
| `-b <n>` | Batch size |
| `-m <n>` | Max length. `-1` means "use `search.max_length` from the config" |
| `-v` | Verbose |

Output:

```text
Args: batch_size = 1, prompt_length = 128, tokens = 128, max_length = 256
hipdnn_ep_get_pool_base: growing pool[0] <n> -> <n> bytes
Average Prompt Processing Latency (per token): <n> ms
Average Prompt Processing Throughput (per token): <n> tps
Average Token Generation Latency (per token): <n> ms
Average Token Generation Throughput (per token): <n> tps
Average Wall Clock Time: <n> s
Average Wall Clock Throughput: <n> tps
Results saved in genai_e2e!
```

The two numbers worth reading are prompt-processing throughput (prefill, which
is what time-to-first-token comes from) and token-generation throughput
(decode). The `hipdnn_ep_get_pool_base` lines are not noise — they are the GPU
memory pool growing, which is evidence the run reached the GPU at all. They
appear once per new input shape and then stop.

## Run a vision-language model

```powershell
pip install Pillow numpy psutil

python pkg\run_onnx.py --benchmark pkg\vlm_benchmark.py `
  -m C:\path\to\gemma3-4b-it-rtn-int4-128gs-fp16-onnx-gpu `
  -i C:\path\to\dog.jpg `
  -p "Describe this image in detail." `
  --max_tokens 128 --max_length 4096 `
  -n 3 -w 1 -v
```

`-n` and `-w` are iterations and warm-up here, not the single-letter flags they
are in `benchmark_e2e.py` — the two scripts come from different upstreams.
`vlm_benchmark.py --help` is the authority for the rest.

The model's `genai_config.json` has to select hip-ep, exactly as for a text
model. See below.

## Point a model at hip-ep

Anything driven through OGA picks its provider from the model, not from the
command line. In `genai_config.json`, set `model` → `decoder` →
`session_options` → `provider_options` to:

```json
"provider_options": [
  { "AMDGPU": { "profile": "hip" } }
]
```

Published ONNX artifacts for Windows are commonly built for DirectML and ship
`[ { "dml": {} } ]`. That is not an error, it is another provider's
configuration — but it is what selects the provider, so hip-ep never sees the
graph.

<div class="note note--warn" markdown="1">
**Do not save that file with a byte-order mark.** OGA's parser rejects one and
blames the first character instead of the encoding:

```text
Exception: Error encountered while parsing genai_config.json  JSON Error: Unknown value "" at line 1 index 1
```

PowerShell 5.1's `Set-Content -Encoding utf8` writes a BOM; so does Notepad's
plain "UTF-8". Write it without one:

```powershell
[IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
```
</div>

## Confirm the GPU ran it

ONNX Runtime does not fail when a provider cannot take a graph — it runs that
part on the CPU and returns correct answers, so a model that never reached the
GPU looks like one that did, only slower.

For a plain ORT session, `run_onnx.py` has already ruled it out: it sets
`session.disable_cpu_ep_fallback`, so a fallback raises instead of succeeding
quietly. Through OGA nothing sets that for you, and the direct evidence is the
provider's own log line:

```powershell
$env:MORPHIZEN_DEBUG_MORPHIZEN_EP = "1"
python pkg\run_onnx.py --benchmark pkg\benchmark_e2e.py -i C:\path\to\model-dir -l 128 -g 32 -r 1 -w 0
Remove-Item Env:\MORPHIZEN_DEBUG_MORPHIZEN_EP
```

Expected:

```text
morphizen-ep.cpp:344] Using backend: mlir-backend
```

That is the provider saying what it chose, rather than a conclusion drawn from a
stopwatch.

<div class="note note--warn" markdown="1">
**Do not benchmark with it set.** `MORPHIZEN_DEBUG_MORPHIZEN_EP`,
`HIPDNN_EP_DEBUG=1` and `HIPDNN_EP_PERF=1` all add instrumentation, and numbers
collected under any of them are not comparable to anything.
</div>

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `... is not a supported wheel on this platform` | The interpreter is not CPython 3.14. Recreate the venv with `py -3.14 -m venv` |
| `ModuleNotFoundError: onnxruntime_ep_amdgpu` | The umbrella wheel was skipped. The distribution named `onnxruntime_ep_hip` does not provide that import by itself |
| `lld-link: could not open 'msvcrt.lib'` | `LIB` does not point at the package directory, where the CRT import libraries live. Go through `run_onnx.py`, which sets it |
| `lld-link: could not open 'amdhip64.lib'` | The ROCm import libraries are missing from the package directory — usually the EP wheel was installed before the umbrella, so its files were overwritten. Reinstall it |
| `Failed to load ... amdhip64_7.dll` | The graphics driver is too old to supply it. Install the current Adrenalin release |
| Runs, but on the CPU | Through OGA: `provider_options` in `genai_config.json` is not `[{ "AMDGPU": { "profile": "hip" } }]`. Through plain ORT: the session was built without the plugin registered — compare against `run_onnx.py` |
| The first run appears to hang | It is compiling. A large model takes minutes on the first inference, and `{{ site.hip_ep_version }}` has no on-disk artifact cache, so each process pays it again |

<div class="note" markdown="1">
**Native `.dll` model artifacts are not supported from a wheel.** That mode
links the compiled model with `lld-link` against the ROCm import libraries,
which only a full `THEROCK_DIST` installation carries. The default artifact —
OS-portable LLVM bitcode, JIT-loaded in-process — is what a wheel install uses,
and is the default everywhere else too.
</div>

## Next

- [Run models with the C++ package]({{ '/docs/tutorials/cpp-package/' | relative_url }}) — the same models, no Python.
- [Run models from a source build]({{ '/docs/tutorials/source-build/' | relative_url }}) — when you need to change the compiler.
- [Model matrix]({{ '/docs/models/' | relative_url }}) — what is validated each release.
