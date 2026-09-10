---
title: Quick Start — Windows
description: From a machine with nothing installed to an ONNX model executing on an AMD GPU.
---

This page is written to be followed top to bottom without jumping. Every step
ends with a check and the output that check should produce; if the output does
not match, the fix is in the same step rather than in a separate troubleshooting
document.

Every command is safe to re-run. If you lose your shell, re-run
[step 3](#step-3) and continue.

Commands are **PowerShell**. Everything lands under `$HOME\hip-ep-runtime`;
substitute a different directory if you like, but substitute it everywhere.

If you would rather not follow it by hand, steps 1 through 6 are also available
as a single script: [One-command deploy]({{ '/docs/quickstart/deploy-script/' | relative_url }}).
It covers `gfx1151` only. Read this page anyway when something goes wrong — the
script's checks are these checks.

Steps 1 through 7 were last run end to end on 2026-09-09, on a Ryzen AI Max
(Radeon 8060S, `gfx1151`) running Windows 11 with driver `32.0.31035.1003`,
against `{{ site.hip_ep_version }}`. The timings quoted below are from that run.
Step 8 is verified only in part — see the note there.

<div class="note" markdown="1">
**Windows needs no separate ROCm install.** Unlike the Linux package, the
Windows archive bundles the HIP runtime, the code-object manager, hipBLASLt,
rocBLAS and MIOpen alongside the EP. A current AMD Adrenalin driver plus this one
download is the whole installation. Budget 232 MB down, about 610 MB extracted
across 299 files.
</div>

## Step 1 — Check that your GPU is covered {#step-1}

The Windows package carries kernels for all three RDNA 3.5 integrated GPUs, so
you do not need to pick an architecture-specific download — but you do need to
be on one of them.

```powershell
Get-CimInstance Win32_VideoController |
  Select-Object Name, DriverVersion, AdapterCompatibility
```

Match the adapter name against this table:

| Adapter name contains | Architecture | Product family |
|---|---|---|
| Radeon 8060S / 8050S | `gfx1151` | Ryzen AI Max 300 ("Strix Halo") |
| Radeon 890M / 880M | `gfx1150` | Ryzen AI 300 ("Strix Point") |
| Radeon 860M / 840M | `gfx1152` | Ryzen AI 300 ("Krackan Point") |

**If your adapter is in the table**, continue to step 2.

**If it is not** — a discrete Radeon card, an older integrated GPU, or an
Instinct part — the release package will not run on it. See
[Build from Source]({{ '/docs/quickstart/build/' | relative_url }}) and pass
`--hip_arch` for your architecture.

<div class="note" markdown="1">
**A caveat specific to `gfx1150` and `gfx1152`.** The package ships hipBLASLt and
rocBLAS tuning data for `gfx1151` only. Models will run on the other two parts,
but GEMM-heavy workloads are not selecting tuned kernels for the hardware they
are on, so do not read their performance as representative.
</div>

Also confirm the driver is recent. hip-ep talks to the kernel-mode driver
through the bundled HIP runtime, and a driver more than a few releases old is a
common source of otherwise-inexplicable launch failures. Install the current
[AMD Adrenalin driver](https://www.amd.com/en/support) for your part if you have
not recently.

## Step 2 — Download and unpack hip-ep {#step-2}

```powershell
$Root = "$HOME\hip-ep-runtime"
New-Item -ItemType Directory -Force -Path $Root | Out-Null
Set-Location $Root

$Url = "https://github.com/ROCm/hip-ep/releases/download/{{ site.hip_ep_version }}/gpu-test-package-windows-{{ site.hip_ep_version }}.zip"
Invoke-WebRequest -Uri $Url -OutFile "$Root\hip-ep.zip"

Expand-Archive -Path "$Root\hip-ep.zip" -DestinationPath "$Root\hip-ep" -Force
```

The archive has no top-level directory of its own, which is why it is extracted
into one explicitly. `-Force` makes re-running this step overwrite rather than
fail.

Check:

```powershell
Get-ChildItem "$Root\hip-ep"
```

Expected: `bin`, `lib`, `wheels`, and `morphizen_config.json`.

## Step 3 — Set up the environment {#step-3}

Everything the EP needs lives in `bin\`, so the whole setup is one directory on
`PATH`. Write it to a file so that recovering a lost session is one command.

```powershell
@'
$env:HIPEP_ROOT = "$HOME\hip-ep-runtime\hip-ep"
# Prepend only once, so re-sourcing this file does not grow PATH without bound.
if (-not ($env:PATH -split ';' | Where-Object { $_ -eq "$env:HIPEP_ROOT\bin" })) {
    $env:PATH = "$env:HIPEP_ROOT\bin;$env:PATH"
}
'@ | Set-Content -Path "$HOME\hip-ep-runtime\env.ps1"

. "$HOME\hip-ep-runtime\env.ps1"
```

This sets the environment for the **current PowerShell session only**. Nothing is
written to the registry and nothing is installed system-wide; deleting
`$HOME\hip-ep-runtime` removes hip-ep completely.

Check:

```powershell
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" --help | Select-Object -First 3
```

Expected: a usage block.

**If you get "The specified module could not be found" or a 0xc0000135 exit**, a
DLL failed to load. The cause is almost always running the `.exe` from a copy
outside `bin\` — every dependency, including the HIP runtime, is resolved
relative to that directory. Run it in place.

## Step 4 — Make a model to test with {#step-4}

Rather than downloading one, generate a tiny model locally. It takes a second,
depends on nothing gated, and is byte-identical for everyone reading this page.

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
```

Expected: `wrote smoke.onnx`.

`ir_version` is pinned because ONNX Runtime rejects models newer than the IR
version it was built against, and the `onnx` package on PyPI moves faster than
the pinned runtime does.

<div class="note" markdown="1">
**Any Python works for this step.** The wheels shipped in `wheels\` are built for
**CPython 3.14 only** — that constraint applies if you later want to drive ORT or
OGA from Python, not to generating a model with the `onnx` package.

Note that this `pip install` is the one thing on this page that lands outside
`$HOME\hip-ep-runtime`: it goes into whichever interpreter is on your `PATH`. Use
a virtual environment under the runtime root if you would rather keep the
"delete the directory and it is gone" property exact.
</div>

## Step 5 — Run it {#step-5}

```powershell
Set-Location "$HOME\hip-ep-runtime"
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx
```

Expected: the run completes and prints timing — a few seconds in total, most of
it spent compiling during session creation.

Two things about that output are easy to misread:

- **Re-running is not faster.** There is no on-disk artifact cache in
  `{{ site.hip_ep_version }}`, so every invocation recompiles the model from
  scratch. Measured on a Ryzen AI Max: 2.40 s, then 2.12 s, then 2.11 s.
- **The `Inference:` line is not this model's latency.** It is the first
  inference on a freshly compiled model, so it carries kernel load and warm-up —
  on the same machine it reported `159695 us` for a model whose steady-state
  latency is 0.164 ms, a thousandfold difference. Step 7 measures the number you
  actually want.

`hip-onnx-runner` feeds random input by default, which is fine here. It is not
fine for a language model, whose `input_ids` must be below the vocabulary size;
for those, generate a valid input directory first:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ROCm/hip-ep/main/tools/hip-onnx-runner/gen_hip_onnx_runner_inputs.py" -OutFile gen_inputs.py
python gen_inputs.py -o gen_inputs C:\path\to\llm.onnx
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m C:\path\to\llm.onnx -i gen_inputs
```

## Step 6 — Prove the GPU actually ran it {#step-6}

On a compilation failure ONNX Runtime falls back to the CPU EP and still returns
correct numbers, so a run that looks fine can be a CPU run.

`hip-onnx-runner` already guards against that for you: it sets
`session.disable_cpu_ep_fallback=1` on every session, so a fallback is a hard
error here rather than a silent one. That guard is a property of this tool, not
of hip-ep — your own application, a Python script, or `model_benchmark` will
fall back silently unless you disable it yourself.

`HIPDNN_EP_STRICT` goes further. It aborts inside the compiler at the pass that
failed, which is what you want when you need to see *why* a graph could not be
compiled rather than just that it could not:

```powershell
$env:HIPDNN_EP_STRICT = "1"
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx
Remove-Item Env:\HIPDNN_EP_STRICT
```

Expected: the same successful run as step 5. A clean run under strict mode means
every subgraph hip-ep claimed, it also compiled.

<div class="note note--warn" markdown="1">
**Unset the variable to turn strict mode off — do not set it to `0`.** The
variable is tested for presence, not for value, so `HIPDNN_EP_STRICT=0` enables
strict mode exactly as `=1` does. `Remove-Item Env:\HIPDNN_EP_STRICT`, as above,
is the only way to disable it.
</div>

For a second, independent confirmation, compare EP output against CPU output:

```powershell
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx -d 2       # EP  -> smoke_o_dump\
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx -d 2 -n    # CPU -> smoke_cpu_o_dump\
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -L smoke_o_dump,smoke_cpu_o_dump
```

Dump directories are named from the model file's stem, so with a model of your
own the two directories are `<stem>_o_dump` and `<stem>_cpu_o_dump`. The names
differ, so the second command does not overwrite the first.

Expected: a small L2 norm, on the order of `0.02` for this model on a Ryzen AI
Max. Exact bit equality is not expected and not a goal — the GPU path uses
different kernels and a different accumulation order.

Read the magnitude, not the digits. Three runs of this check on the same machine,
with the same driver, the same package and byte-identical `smoke.onnx`, produced
`0.0239186`, `0.0234262` and `0.0217464` — a spread of about 10%, because the
GEMM library does not have to pick the same algorithm every time. So treat
anything in the same order of magnitude as a pass. A result in the ones, or a
non-finite one, is a real failure and worth stopping on.

## Step 7 — Measure something real {#step-7}

`onnxruntime_perf_test` reports steady-state latency. Give it enough wall time
that the one-off compile does not dominate the average:

```powershell
Set-Location "$env:HIPEP_ROOT\bin"
.\onnxruntime_perf_test.exe `
  --plugin_ep_libs "hipgpu|hipgpu.dll" `
  --plugin_eps "hipgpu" `
  -C "session.disable_cpu_ep_fallback|1" `
  -t 60 -c 1 -s -I `
  "$HOME\hip-ep-runtime\smoke.onnx"
```

`session.disable_cpu_ep_fallback|1` is needed here in a way it was not in step 6:
`onnxruntime_perf_test` does not set it for you the way `hip-onnx-runner` does.

On a Ryzen AI Max this reports about `0.164 ms` average, `0.156 ms` P50, roughly
6,100 inferences/s.

For a comparison point, the package also bundles `DirectML.dll`, so the DML EP is
available as a same-machine baseline:

```powershell
.\onnxruntime_perf_test.exe `
  -e dml `
  -C "ep.dml.disable_graph_fusion|1" `
  -t 60 -c 1 -s -I `
  "$HOME\hip-ep-runtime\smoke.onnx"
```

<div class="note" markdown="1">
**Do not read anything into how this comparison comes out.** `smoke.onnx` is
three nodes over a 512×512 matrix, deliberately small enough to be generated
inline in step 4, and at that size launch and dispatch overhead is nearly all of
the measurement — whichever provider wins, the number is measuring overhead
rather than the model. It is a check that the toolchain works end to end, not a
workload. Draw performance conclusions from
[the benchmarks]({{ '/docs/benchmarks/' | relative_url }}) or from a model of
your own at a realistic size.
</div>

<div class="note note--warn" markdown="1">
**Do not benchmark with debug tracing on.** `HIPDNN_EP_PERF=1` and
`HIPDNN_EP_DEBUG=1` add per-operation instrumentation, and numbers collected with
either of them set are not comparable to anything. Run GPU benchmarks serially —
a concurrent run invalidates both.
</div>

## Step 8 — Generative models {#step-8}

`model_benchmark.exe` drives the full prefill + decode pipeline through OGA. The
EP is chosen by the model's own `genai_config.json`, not by a command-line flag:

```powershell
Set-Location "$env:HIPEP_ROOT\bin"
.\model_benchmark.exe -i C:\path\to\oga-model-dir -l 128 -g 32 -r 5 -w 1
```

Three things about this command are non-obvious, and each causes an error that
does not name the real problem:

- **Do not pass `--ep_library`.** Upstream `model_benchmark` rejects it. The EP is
  discovered next to `onnxruntime-genai.dll`, which is why everything must stay in
  `bin\`. The model's `provider_options` selects the AMD GPU umbrella:
  `[{ "AMDGPU": {"profile": "hip"} }]`.
- **Leave `-e` alone.** Its accepted values are `cpu`, `cuda`, `dml` and
  `NvTensorRtRtx` — there is no AMD entry, and the absence is not a mistake. The
  default is `cpu`, and a run that leaves it at the default still executes on
  hip-ep, because `provider_options` in the config is what selects the provider.
- **`-ml -1` depends on the model, so decide it deliberately.** It means "use the
  config file's `search.max_length`". A `prefill_*.onnx` / `decode_*.onnx` pair
  with a fixed attention-mask shape needs it — without it `model_benchmark`
  overrides `search.max_length` with prompt + generation length and the shapes no
  longer match. A dynamic-shape decoder is the opposite case: the command above
  omits `-ml -1` because that model's config sets `search.max_length: 32768`, and
  honouring it would size the KV cache for 32768 tokens to generate 32.

A successful run reports four blocks — prompt processing, token generation,
token sampling and end-to-end — in this shape:

```text
Batch size: 1, prompt tokens: 128, tokens to generate: 32
Prompt processing (time to first token):
	avg (us):       <n>         avg (tokens/s): <n>
	p50 (us):       <n>         stddev (us):    <n>         n: 5 * 128 token(s)
Token generation:
	avg (us):       <n>         avg (tokens/s): <n>
	p50 (us):       <n>         stddev (us):    <n>         n: 155 * 1 token(s)
Token sampling:
	avg (us):       <n>         avg (tokens/s): <n>
E2E generation (entire generation loop):
	avg (ms):       <n>         p50 (ms): <n>       stddev (ms): <n>        n: 5
Peak working set size (bytes): <n>
```

Two of those are the ones to read: **time to first token** under prompt
processing, and **token generation** in tokens per second. Compare them against
[the benchmark page]({{ '/docs/benchmarks/' | relative_url }}) for the same model
and prompt length. Landing within a few percent is the useful check — a working
install reproduces published numbers, and one that has quietly fallen back to
something else does not come close.

<div class="note note--warn" markdown="1">
Those reference numbers are not published yet, so that comparison cannot be made
from this site today. Until they are, rely on the provider check below, which is
direct evidence and does not depend on any number.
</div>

<div class="note" markdown="1">
**Confirm the provider rather than inferring it from speed.** Setting
`MORPHIZEN_DEBUG_MORPHIZEN_EP=1` makes the EP log the backend it selected:

```text
morphizen-ep.cpp:344] Using backend: mlir-backend
```

That line is the direct evidence. Do not benchmark with it set.
</div>

## Troubleshooting

**An OGA model downloaded from Hugging Face runs, but not on hip-ep**

Check `provider_options` in its `genai_config.json`. Published ONNX artifacts for
Windows are commonly built for DirectML and ship:

```json
"provider_options": [ { "dml": {} } ]
```

Nothing about that is an error — it is a different provider's config — but it is
what selects the provider, so hip-ep never sees the graph. Replace it with:

```json
"provider_options": [ { "AMDGPU": { "profile": "hip" } } ]
```

Keep a copy of the original first. The rest of the config carries over unchanged.

**`Exception: Error encountered while parsing genai_config.json  JSON Error: Unknown value "" at line 1 index 1`**

The file has a UTF-8 byte-order mark and OGA's parser will not accept one. This
is easy to introduce by accident while making the edit above: PowerShell 5.1's
`Set-Content -Encoding utf8` writes a BOM, as does Notepad's "UTF-8" (choose
"UTF-8 without BOM"). The message points at index 1 of line 1 because the three
BOM bytes sit in front of the opening brace.

To rewrite the file without one:

```powershell
[IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
```

To check: `Get-Content $path -Encoding Byte -TotalCount 3` should be `123 13 10`
(`{`, CR, LF), not `239 187 191`.

**`Got invalid dimensions for input: attention_mask  Got: X  Expected: Y`**

Either `-ml -1` is missing (see step 8), or `-l <prompt_length>` does not match
the model's `model.decoder.fixed_prompt_length` in `genai_config.json`. Pass the
value the config expects.

**`Exception: Invalid rank for input: image_features  Got: 2  Expected: 3`**

The model is multi-modal and `model_benchmark` cannot drive it. The message
blames the model, but nothing is wrong with it: `model_benchmark` is a text-only
harness, and it has no way to produce the image tensor a vision-language model's
embedding graph expects. A `genai_config.json` with a `model.vision` section, or
a directory containing `vision.onnx`, is the tell.

This failure happens after the EP has already been selected and consulted, so it
says nothing about your hip-ep installation. Benchmark a text-only OGA model
instead, and drive multi-modal models through the ONNX Runtime GenAI API where
you can supply images yourself.

**`EP library not found: hipgpu.dll`**

`hip-onnx-runner` searches `%MORPHIZEN_EP_LIB%` (a full path), then the current
directory, then next to the executable, then `..\lib`. Running from `bin\` needs
no variable at all. If you copied the binary elsewhere, set `MORPHIZEN_EP_LIB` to
the full path of the DLL.

**The first run appears to hang**

It is compiling. A large model can take several minutes on the first inference.
`HIPDNN_EP_DEBUG=1` will show progress — just do not benchmark with it set.

**Results are correct but no faster than CPU**

Rule out a CPU fallback first — re-run step 6. If the run really is on the GPU,
the next likely cause is that the model is too small for the GPU to pay for
itself: at small sizes launch and dispatch overhead dominates, and `smoke.onnx`
from step 4 is deliberately in that regime. Compare on a model of realistic size
before concluding anything.

## Next

- [Build from Source]({{ '/docs/quickstart/build/' | relative_url }}) if you need to change the compiler.
- [Overview]({{ '/docs/' | relative_url }}) for how the compilation pipeline actually works.
