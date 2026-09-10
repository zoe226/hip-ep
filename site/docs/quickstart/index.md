---
title: Quick Start
description: Pick an installation path, then follow one page end to end.
---

There are two ways to get hip-ep, and which one you want depends on whether you
intend to change the compiler.

<div class="card-grid" markdown="0">
  <div class="card">
    <p class="card__title">Use a release package</p>
    <p class="card__body">A prebuilt archive with the EP, the runtimes and the
      tools. Nothing is compiled on your machine. Minutes, not hours. This is the
      right answer unless you know it isn't.</p>
  </div>
  <div class="card">
    <p class="card__title">Build from source</p>
    <p class="card__body">Required to modify the compiler, target an
      architecture no package covers, or work against an unreleased commit. The
      first build takes hours — LLVM is built from source.</p>
  </div>
</div>

## Choose your page

| If | Read |
|---|---|
| You are on Linux and want to run models | [Linux]({{ '/docs/quickstart/linux/' | relative_url }}) |
| You are on Windows and want to run models | [Windows]({{ '/docs/quickstart/windows/' | relative_url }}) |
| You want a Strix Halo machine set up without reading anything | [One-command deploy]({{ '/docs/quickstart/deploy-script/' | relative_url }}) |
| You intend to change hip-ep itself | [Build from Source]({{ '/docs/quickstart/build/' | relative_url }}) |

Each page is self-contained: it starts from a machine with nothing installed and
ends with a model executing on the GPU. You should not need to jump between
them.

The third row is the Windows page as a single script, for unattended installs
and for handing to an agent. It covers `gfx1151` only, and it ends with the same
GPU-execution check the manual page does.

## Before you start

Three things are worth knowing up front, because each one produces a confusing
symptom rather than a clear error.

**Your GPU architecture decides which package you can use.** hip-ep compiles
for one specific architecture. The Linux package is built for `gfx1151` (Strix
Halo) only; the Windows package covers `gfx1150`, `gfx1151` and `gfx1152`. The
first step of each platform page is to find out which one you have, before
downloading anything.

**The first inference of any model is slow.** That is hip-ep compiling the
graph, and it can take minutes on a large model. It is not a hang. Every
subsequent inference of the same model uses the cached artifact.

**A wrong setup usually produces correct results, slowly.** If the EP fails to
load or fails to compile your graph, ONNX Runtime quietly falls back to the CPU.
Each page therefore includes an explicit check that the GPU actually ran the
graph — do not skip it, because nothing else will tell you.

## What gets installed

The release packages contain the same set of tools on both platforms:

| Tool | What it is for |
|---|---|
| `hip-onnx-runner` | Run one ONNX model through the EP; dump outputs; compare against CPU |
| `onnxruntime_perf_test` | Steady-state inference latency |
| `model_benchmark` | End-to-end generative benchmark (prefill + decode) via OGA |
| `hip-compiler`, `hip-mlir-opt`, `hip-inspect` | Compile and inspect the MLIR pipeline directly |
| `wheels/` | ONNX Runtime and OGA Python wheels, built for **CPython 3.14 only** |

Nothing installs into system directories and nothing is registered globally.
Deleting the extracted directory removes hip-ep completely.
