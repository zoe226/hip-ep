---
title: Run models from a source build
description: Build hip-ep on Windows, then set up the environment a source tree needs and run ONNX graphs, latency benchmarks and LLMs against it.
---

A source build gives you the same provider as the release packages and none of
their convenience. The packages are self-contained by construction — every DLL
they need sits next to the executable that loads it. A build tree is not: the
compiler output lands in your install prefix, the ROCm runtime stays in the
build tree where CMake downloaded it, and ONNX Runtime is wherever you put it.
Nothing finds anything until you say where it is.

That is what this page is about. Building is
[covered separately]({{ '/docs/quickstart/build/' | relative_url }}) and is
summarized below only far enough to make the run steps make sense.

Take this route when you need to change the compiler, target a GPU no package
covers, or run against an unreleased commit. Otherwise use the
[C++ package]({{ '/docs/tutorials/cpp-package/' | relative_url }}) or the
[Python package]({{ '/docs/tutorials/python-package/' | relative_url }}).

| Item | Requirement |
|---|---|
| OS | Windows, x64 |
| Shell | **Git Bash**, launched from an *x64 Native Tools Command Prompt for VS 2022*. Unlike the package tutorials, the commands here are bash |
| GPU | Ryzen AI Max (`gfx1151`), Ryzen AI (`gfx1150` / `gfx1152`), with a current [Adrenalin driver](https://www.amd.com/en/support) |
| Disk | ~100 GB free for a cold tree |
| Time | Hours. LLVM/MLIR/LLD is built from source on the first configure |

<div class="note note--warn" markdown="1">
**Git Bash must inherit the MSVC environment.** Launch it from inside the
x64 Native Tools prompt so `cl.exe`, `link.exe` and the MSVC headers are
visible. Check with `echo $INCLUDE` — it should contain paths under
"Microsoft Visual Studio". A Git Bash opened from the Start menu will configure
and then fail somewhere inside the dependency builds.
</div>

## Build

```bash
winget install Microsoft.VisualStudio.2022.BuildTools --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Component.VC.CMake.Project --includeRecommended"
winget install Ninja-build.Ninja
winget install Python.Python.3.14
winget install Mozilla.sccache
winget install Git.Git
```

```bash
cd <workspace>
git clone {{ site.repo_url }}.git
cd hip-ep

mkdir -p ../local
LOCAL_DIR=$(cd ../local && pwd)

# Prefer the HIP that TheRock ships; a pre-installed HIP_PATH will interfere.
unset HIP_PATH

python build.py --install_dir "$LOCAL_DIR" --cmake_prefix_path "$LOCAL_DIR"
```

`build.py` resolves every dependency, detects your GPU architecture, builds,
installs into `../local/`, and runs the LIT suite. You end up with:

```text
<workspace>/
├── hip-ep/                    source — $PWD for every command below
├── build/
│   └── hip-ep/
│       ├── _therock/bin/      ROCm runtime DLLs
│       └── python/dist/       the EP wheel
└── local/
    ├── bin/                   hip-onnx-runner.exe, hipgpu.dll, custom kernels
    └── lib/
```

Two flags matter more than the rest. `--hip_arch gfx1151` targets a specific
GPU, and you need it whenever the machine you build on is not the machine you
run on — a wrong architecture is not a build error, it configures, compiles,
installs and runs right up until a kernel launches. `--mock` builds the
compiler against a mock runtime with no GPU, HIP or ROCm involved, which is how
you work on the compiler from a laptop. The
[build page]({{ '/docs/quickstart/build/' | relative_url }}) has the rest.

## Set up the environment

Do this once per shell. Everything below depends on it.

```bash
LOCAL_DIR=$(cd ../local && pwd)
export PATH="$(cd ../build/$(basename $PWD)/_therock/bin && pwd):$LOCAL_DIR/bin:$PATH"
```

`_therock/bin` is the ROCm runtime that `cmake/deps.cmake` downloaded into the
build tree during configure. Without it on `PATH` the provider fails to load
`amdhip64.dll` and you get a bare `0xc0000135` with nothing naming the culprit.

## Run a single ONNX graph

`hip-onnx-runner` runs one model through the provider and reports timing. It is
built by the default configure; no extra step.

```bash
$LOCAL_DIR/bin/hip-onnx-runner.exe -m /path/to/model.onnx
```

| Flag | Meaning |
|---|---|
| `-m <path>` | The `.onnx` model |
| `-i <dir>` | Load inputs from a directory instead of generating random ones |
| `-n` | CPU only — skip provider registration. The reference side of a comparison |
| `-d <level>` | Dump: `0` off, `1` inputs, `2` outputs, `3` both |
| `-f <name>:<val>` | Pin a symbolic input dimension at runtime. Repeatable. The provider still compiles the dynamic graph; unmatched symbolic dims default to 1 |
| `-L <dir1>,<dir2>` | L2-norm comparison of two dumped output directories |

Random inputs are fine for a vision model and wrong for a language model, whose
`input_ids` must be below the vocabulary size. Generate a valid input directory
first:

```bash
python tools/hip-onnx-runner/gen_hip_onnx_runner_inputs.py -o gen_inputs /path/to/model.onnx
$LOCAL_DIR/bin/hip-onnx-runner.exe -m /path/to/model.onnx -i gen_inputs
```

To check the provider against the CPU rather than against your expectations,
dump both and compare:

```bash
$LOCAL_DIR/bin/hip-onnx-runner.exe -m /path/to/model.onnx -i gen_inputs -d 2      # -> ep_o_dump
$LOCAL_DIR/bin/hip-onnx-runner.exe -m /path/to/model.onnx -i gen_inputs -d 2 -n   # -> cpu_o_dump
$LOCAL_DIR/bin/hip-onnx-runner.exe -L ep_o_dump,cpu_o_dump
```

## Benchmark latency

`onnxruntime_perf_test` measures per-inference latency. It is **not installed by
default** — stage it from the ONNX Runtime build tree first:

```bash
cp ../build/onnxruntime/Release/Release/onnxruntime_perf_test.exe "$LOCAL_DIR/bin/"

"$LOCAL_DIR/bin/onnxruntime_perf_test.exe" \
  --plugin_ep_libs "hipgpu|hipgpu.dll" \
  --plugin_eps "hipgpu" \
  -t 60 -c 1 -s -I \
  /path/to/model.onnx
```

`-t 60` runs for sixty seconds, `-c 1` keeps it to one concurrent thread, `-s`
prints per-iteration statistics and `-I` stops the inputs being re-randomized
between iterations. Run one benchmark at a time — concurrent GPU runs invalidate
each other's numbers.

If you want a DirectML baseline on the same machine, that is
`-e dml -C "ep.dml.disable_graph_fusion|1"` with the same timing flags.

## Run an LLM end to end

`model_benchmark.exe` drives the whole generative pipeline — prefill and decode
— and it comes from OGA, not from this repository. Building it means building
ONNX Runtime from source (step 1 of
[`docs/quick_start.md`]({{ site.repo_url }}/blob/main/docs/quick_start.md)) so
OGA has an `ORT_HOME`, then OGA itself at the tag and PR set that CI pins in
`.github/workflows/windows-build-real.yml`, then copying two files in:

```bash
cp ../build/onnxruntime-genai/Release/benchmark/c/model_benchmark.exe "$LOCAL_DIR/bin/"
cp ../build/onnxruntime-genai/Release/onnxruntime-genai.dll "$LOCAL_DIR/bin/"
```

```bash
"$LOCAL_DIR/bin/model_benchmark.exe" -i /path/to/oga_model_dir -l 512 -g 128 -r 5 -w 1
```

| Flag | Meaning |
|---|---|
| `-i <dir>` | OGA model directory: the one with `genai_config.json` and the tokenizer files |
| `-l <n>` | Auto-generated prompt length. Mutually exclusive with `--prompt_file` |
| `--prompt_file <path>` | Take the prompt from a file instead |
| `-g <n>` | Maximum tokens to generate |
| `-r <n>` / `-w <n>` | Repetitions / warm-up runs |

<div class="note note--warn" markdown="1">
**Do not pass `--ep_library`.** Upstream `model_benchmark` rejects the flag. The
provider is selected by the model's `genai_config.json` and discovered next to
`onnxruntime-genai.dll`, which means `amdgpu-ep.dll` and the rest of the
umbrella chain have to sit in `$LOCAL_DIR/bin/` alongside it.
</div>

If all you want is the LLM path and not a modified compiler, the
[C++ package]({{ '/docs/tutorials/cpp-package/' | relative_url }}) ships
`model_benchmark.exe` prebuilt with every DLL it needs already beside it.

## Point a model at hip-ep

Anything driven through OGA picks its provider from the model, not from the
command line. In `genai_config.json`, set `model` → `decoder` →
`session_options` → `provider_options` to:

```json
"provider_options": [
  { "AMDGPU": { "profile": "hip" } }
]
```

Published Windows artifacts commonly ship `[ { "dml": {} } ]` instead. That is
not an error — it is another provider's configuration — but it is what selects
the provider, so hip-ep never sees the graph. Save the file **without a
byte-order mark**; OGA's parser rejects one and blames the first character
rather than the encoding.

`hip-onnx-runner` and `onnxruntime_perf_test` do not read that file — they take
the provider from their own flags.

## Install the Python wheel

`build.py` builds the EP wheel by default on Windows (`--skip_wheel` to opt out,
or `cmake --build ../build/hip-ep --target wheel` to build only it). It lands in
`../build/hip-ep/python/dist/`.

```bash
pip install \
  ../build/onnxruntime/Release/dist/onnxruntime_directml-*.whl \
  onnxruntime_ep_amdgpu-*.whl \
  ../build/hip-ep/python/dist/onnxruntime_ep_hip-*.whl \
  ../build/onnxruntime-genai/Release/wheel/onnxruntime_genai_directml-*.whl
```

`onnxruntime_ep_amdgpu` is the upstream AMD GPU umbrella provider, built by CI's
`amdgpu` deps job and shipped in the
[Python package]({{ '/docs/tutorials/python-package/' | relative_url }}) — take
it from there. Install it **before** the hip-ep wheel: hip-ep's native files
land in that same package directory, and that colocation is what lets
`hip-backend.dll` resolve `hipgpu.dll` by bare name. From there, the Python
workflow is the one on the
[Python package page]({{ '/docs/tutorials/python-package/' | relative_url }}),
including `run_onnx.py`, which sets the `AMDGPU_EP_PATH` and `LIB` that a wheel
install needs.

## Confirm the GPU ran it

ONNX Runtime does not fail when a provider cannot take a graph. It runs that
part on the CPU and returns correct answers, so a model that never reached the
GPU looks like one that did, only slower — and on a source build, where a
half-configured `PATH` is the normal failure, this is the check that catches it.

```bash
MORPHIZEN_DEBUG_MORPHIZEN_EP=1 "$LOCAL_DIR/bin/hip-onnx-runner.exe" -m /path/to/model.onnx -i gen_inputs
```

Expected:

```text
morphizen-ep.cpp:344] Using backend: mlir-backend
hipdnn_ep_get_pool_base: growing pool[0] <n> -> <n> bytes
```

The first line is the provider naming the backend it chose. The
`hipdnn_ep_get_pool_base` lines are the GPU memory pool growing — they appear
once per new input shape and then stop, and they are runtime-side evidence
rather than a compile-time claim.

For a graph you expect to be taken in full, `HIPDNN_EP_STRICT` turns a partial
claim into a hard failure instead of a quiet CPU fallback.

<div class="note note--warn" markdown="1">
**`HIPDNN_EP_STRICT` is a presence flag.** The provider checks whether it is
set, not what it is set to, so `HIPDNN_EP_STRICT=0` **enables** strict mode.
Unset it to turn it off:

```bash
unset HIPDNN_EP_STRICT
```

And do not benchmark with it, `MORPHIZEN_DEBUG_MORPHIZEN_EP`,
`HIPDNN_EP_DEBUG=1` or `HIPDNN_EP_PERF=1` set — each adds instrumentation, and
numbers collected under any of them are not comparable to anything.
</div>

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| The exe exits instantly with `0xc0000135` | A DLL did not resolve. Almost always `_therock/bin` missing from `PATH` — re-run the export above |
| Configure starts building LLVM from source | Expected on a fresh tree with no prefix. Reuse the same build directory so it is paid once |
| `Could not find compiler launcher sccache` | Install it, or drop the `CMAKE_*_COMPILER_LAUNCHER` defines |
| Link errors mentioning `/MT` vs `/MTd` or `/MD` | Everything is built Release `/MT`. Do not build `Debug` and do not set `CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDebug` |
| Dependency builds cannot find a compiler | Git Bash was not launched from the x64 Native Tools prompt. `echo $INCLUDE` to confirm |
| `MorphizenMLIRLitTests` passes in under a second with no test names | `lit` was not found at configure time. `pip install lit`, then reconfigure with `--fresh` |
| Runs, but on the CPU | Through OGA: `provider_options` is not `[{ "AMDGPU": { "profile": "hip" } }]`. Through `hip-onnx-runner`: `-n` was passed, which skips provider registration entirely |
| Kernel launch fails on a model that built cleanly | The build targeted a different architecture than the GPU running it. Rebuild with `--hip_arch` set to the *target* machine's arch |

## Next

- [Build from Source]({{ '/docs/quickstart/build/' | relative_url }}) — build options, Linux, cross-compiling for MI350X, and the test suites.
- [Run models from Python]({{ '/docs/tutorials/python-package/' | relative_url }}) — the wheel workflow in full.
- [Model matrix]({{ '/docs/models/' | relative_url }}) — what is validated each release.
