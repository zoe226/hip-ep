---
title: Get Started
description: Four ways onto an AMD GPU on Windows — a script, two release packages, or a source build. Each one runs end to end.
---

Every page in this section starts from a machine with nothing installed and
ends with a model executing on the GPU, verified. They differ only in how
hip-ep gets there: a script that does it for you, one of the two release
packages, or a build of your own. Read the one that matches how you intend to
install — they are independent, and none is a prerequisite for another.

<div class="card-grid card-grid--fill" markdown="0">
  <div class="card">
    <p class="card__title">0 · One-command deploy</p>
    <p class="card__body">One PowerShell script: detect the GPU, fetch the
      release, unpack it, and prove the GPU ran a model. Ten minutes, almost
      all of it the download. Strix Halo only.</p>
  </div>
  <div class="card">
    <p class="card__title">1 · C++ package</p>
    <p class="card__body">Extract the release zip, put <code>bin</code> on
      <code>PATH</code>, run. Everything the binaries need ships inside the
      archive — no Python, no Visual Studio, nothing to place by hand.</p>
  </div>
  <div class="card">
    <p class="card__title">2 · Python package</p>
    <p class="card__body">Four wheels into a Python 3.14 environment, in an order
      that matters. For when you want to write the generation loop yourself
      rather than read numbers off a benchmark.</p>
  </div>
  <div class="card">
    <p class="card__title">3 · Source build</p>
    <p class="card__body">The same provider, none of the convenience. What a
      build tree does not wire up for you, and how to run models against it once
      you have.</p>
  </div>
</div>

## Which one

| If you want to | Read |
|---|---|
| Get a Strix Halo machine working without reading anything | [One-command deploy]({{ '/docs/get-started/deploy-script/' | relative_url }}) |
| Run the shipped models and benchmark them, with the least setup | [Run models with the C++ package]({{ '/docs/get-started/cpp-package/' | relative_url }}) |
| Drive ONNX Runtime and OGA from your own Python code | [Run models from Python]({{ '/docs/get-started/python-package/' | relative_url }}) |
| Change the compiler, or target a GPU no package covers | [Run models from a source build]({{ '/docs/get-started/source-build/' | relative_url }}) |

## Check that your GPU is covered

The Windows package carries kernels for all three RDNA 3.5 integrated GPUs, so
there is no architecture-specific download to pick — but you do need to be on
one of them.

```powershell
Get-CimInstance Win32_VideoController |
  Select-Object Name, DriverVersion, AdapterCompatibility
```

| Adapter name contains | Architecture | Product family |
|---|---|---|
| Radeon 8060S / 8050S | `gfx1151` | Ryzen AI Max 300 ("Strix Halo") |
| Radeon 890M / 880M | `gfx1150` | Ryzen AI 300 ("Strix Point") |
| Radeon 860M / 840M | `gfx1152` | Ryzen AI 300 ("Krackan Point") |

If your adapter is not in the table — a discrete Radeon card, an older
integrated GPU, or an Instinct part — the release packages will not run on it.
Build from source and pass `--hip_arch` for your architecture.

Confirm the driver is recent while you are here. hip-ep reaches the kernel-mode
driver through the bundled HIP runtime, and a driver more than a few releases
old is a common source of otherwise-inexplicable launch failures. Install the
current [AMD Adrenalin driver](https://www.amd.com/en/support) if you have not
lately.

## Before you start

**Windows needs no separate ROCm install.** The Windows archive bundles the HIP
runtime, the code-object manager, hipBLASLt, rocBLAS and MIOpen alongside the
EP. A current Adrenalin driver plus one download is the whole installation.
Budget 232 MB down and about 610 MB extracted.

## What you get

The same set of tools, whichever route you take:

| Tool | What it is for |
|---|---|
| `hip-onnx-runner` | Run one ONNX model through the EP; dump outputs; compare against CPU |
| `onnxruntime_perf_test` | Steady-state inference latency for a single graph |
| `model_benchmark` | End-to-end generative benchmark — prefill and decode — via OGA |
| `model_mm`, `benchmark_multimodal.py` | The same, for vision-language models |
| `hip-compiler`, `hip-mlir-opt`, `hip-inspect` | Compile and inspect the MLIR pipeline directly |

Nothing installs into system directories and nothing is registered globally.
Deleting the extracted directory removes hip-ep completely.
