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

<div class="note" markdown="1">
**Windows needs no separate ROCm install.** Unlike the Linux package, the
Windows archive bundles the HIP runtime, the code-object manager, hipBLASLt,
rocBLAS and MIOpen alongside the EP. A current AMD Adrenalin driver plus this one
download is the whole installation. Budget 232 MB down, about 800 MB extracted.
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
</div>

## Step 5 — Run it {#step-5}

```powershell
Set-Location "$HOME\hip-ep-runtime"
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx
```

Expected: the run completes and prints timing. **The first run is slow** — this
is the compile — and a second run of the same command is fast.

`hip-onnx-runner` feeds random input by default, which is fine here. It is not
fine for a language model, whose `input_ids` must be below the vocabulary size;
for those, generate a valid input directory first:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ROCm/hip-ep/main/tools/hip-onnx-runner/gen_hip_onnx_runner_inputs.py" -OutFile gen_inputs.py
python gen_inputs.py -o gen_inputs C:\path\to\llm.onnx
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m C:\path\to\llm.onnx -i gen_inputs
```

## Step 6 — Prove the GPU actually ran it {#step-6}

This is the step people skip, and it is the reason "hip-ep is not faster than
CPU" reports usually turn out to be CPU-only runs. On a compilation failure ONNX
Runtime falls back to the CPU EP and still returns correct numbers.

```powershell
$env:HIPDNN_EP_STRICT = "1"
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx
Remove-Item Env:\HIPDNN_EP_STRICT
```

Expected: the same successful run as step 5.

`HIPDNN_EP_STRICT=1` turns a silent fallback into a hard failure. **If step 5
succeeds and step 6 fails**, then step 5 was running on the CPU and the error you
now see is the real one.

For a second, independent confirmation, compare EP output against CPU output:

```powershell
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx -d 2       # EP  -> ep_o_dump\
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m smoke.onnx -d 2 -n    # CPU -> cpu_o_dump\
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -L ep_o_dump,cpu_o_dump
```

Expected: a small L2 norm. Exact bit equality is not expected and not a goal —
the GPU path uses different kernels and a different accumulation order.

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

`session.disable_cpu_ep_fallback|1` serves the same purpose as
`HIPDNN_EP_STRICT` above: it makes a fallback an error rather than a quiet
slowdown.

For a comparison point, the package also bundles `DirectML.dll`, so the DML EP is
available as a same-machine baseline:

```powershell
.\onnxruntime_perf_test.exe `
  -e dml `
  -C "ep.dml.disable_graph_fusion|1" `
  -t 60 -c 1 -s -I `
  "$HOME\hip-ep-runtime\smoke.onnx"
```

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
.\model_benchmark.exe -i C:\path\to\oga-model-dir -l 128 -g 32 -ml -1 -r 5 -w 1
```

Two things about this command are non-obvious and both cause errors that do not
name the real problem:

- **Do not pass `--ep_library`.** Upstream `model_benchmark` rejects it. The EP is
  discovered next to `onnxruntime-genai.dll`, which is why everything must stay in
  `bin\`. The model's `provider_options` selects the AMD GPU umbrella:
  `[{ "AMDGPU": {"profile": "hip"} }]`.
- **`-ml -1` is usually required.** Without it, `model_benchmark` overrides the
  config's `search.max_length` with prompt + generation length, which breaks the
  fixed attention-mask shape a `prefill_*.onnx` / `decode_*.onnx` pair expects.

## Troubleshooting

**`Got invalid dimensions for input: attention_mask  Got: X  Expected: Y`**

Either `-ml -1` is missing (see step 8), or `-l <prompt_length>` does not match
the model's `model.decoder.fixed_prompt_length` in `genai_config.json`. Pass the
value the config expects.

**`EP library not found: hipgpu.dll`**

`hip-onnx-runner` searches `%MORPHIZEN_EP_LIB%` (a full path), then the current
directory, then next to the executable, then `..\lib`. Running from `bin\` needs
no variable at all. If you copied the binary elsewhere, set `MORPHIZEN_EP_LIB` to
the full path of the DLL.

**The first run appears to hang**

It is compiling. A large model can take several minutes on the first inference.
`HIPDNN_EP_DEBUG=1` will show progress — just do not benchmark with it set.

**Results are correct but no faster than CPU**

You are on the CPU. Re-run step 6.

## Next

- [Build from Source]({{ '/docs/quickstart/build/' | relative_url }}) if you need to change the compiler.
- [Overview]({{ '/docs/' | relative_url }}) for how the compilation pipeline actually works.
