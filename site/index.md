---
layout: page
permalink: /
title: null
description: >-
  hip-ep is an ONNX Runtime Execution Provider for AMD GPUs. It compiles ONNX
  graphs through an MLIR pipeline and runs them with hipDNN, hipBLASLt and
  custom HIP kernels.
---

<section class="hero">
  <div class="section__inner">
    <p class="kicker">ONNX Runtime Execution Provider</p>
    <h1 class="headline-lg">Run ONNX models<br />on AMD GPUs.</h1>
    <p class="lede">
      hip-ep compiles your ONNX graph through an MLIR pipeline into machine code
      for the GPU in front of you, then executes it with hipDNN, hipBLASLt and
      hand-written HIP kernels. It plugs into the ONNX Runtime you already call.
    </p>
    <div class="btn-row">
      <a class="btn btn--primary" href="{{ '/docs/quickstart/' | relative_url }}">Get started</a>
      <a class="btn btn--ghost" href="{{ site.repo_url }}/releases/tag/{{ site.hip_ep_version }}">Download {{ site.hip_ep_version }}</a>
      <a class="btn btn--ghost" href="{{ site.repo_url }}">View on GitHub</a>
    </div>
  </div>
</section>

<section class="section section--alt">
  <div class="section__inner">
    <div class="stat-row">
      <div class="stat">
        <span class="stat__value">3</span>
        <span class="stat__label">RDNA 3.5 GPUs in one Windows package</span>
      </div>
      <div class="stat">
        <span class="stat__value">1.27.0</span>
        <span class="stat__label">ONNX Runtime, pinned</span>
      </div>
      <div class="stat">
        <span class="stat__value">MLIR</span>
        <span class="stat__label">Compiler pipeline, not an op library</span>
      </div>
      <div class="stat">
        <span class="stat__value">MIT</span>
        <span class="stat__label">Licensed, source available</span>
      </div>
    </div>
  </div>
</section>

<section class="section">
  <div class="section__inner">
    <h2 class="headline-md">A compiler, not an operator library</h2>
    <p class="lede">
      Most execution providers dispatch each operation to a precompiled kernel.
      hip-ep compiles the subgraph ONNX Runtime hands it, which is why the first
      inference is slow and the rest are not.
    </p>

    <div class="card-grid">
      <div class="card">
        <p class="card__title">1 · ONNX to HIP dialect</p>
        <p class="card__body">
          Your operations are converted into a custom MLIR dialect that models
          GPU memory, kernels and library calls explicitly — so they can be
          reasoned about, not just executed.
        </p>
      </div>
      <div class="card">
        <p class="card__title">2 · HIP dialect to LLVM IR</p>
        <p class="card__body">
          Shape inference, memory planning and buffer pooling run over the whole
          graph. Every transient allocation is pooled; outputs are allocated
          through the runtime.
        </p>
      </div>
      <div class="card">
        <p class="card__title">3 · Execution</p>
        <p class="card__body">
          The result is OS-portable LLVM bitcode, JIT-loaded in-process and
          dispatched to hipDNN, hipBLASLt and custom HIP kernels.
        </p>
      </div>
    </div>
  </div>
</section>

<section class="section section--alt">
  <div class="section__inner section__inner--narrow">
    <h2 class="headline-md">Two commands from download to inference</h2>
    <p class="lede">
      On Windows the release package is self-contained — the HIP runtime,
      hipBLASLt, rocBLAS and MIOpen all ship with it.
    </p>

<div class="prose" markdown="1">
```powershell
Expand-Archive gpu-test-package-windows-{{ site.hip_ep_version }}.zip -DestinationPath hip-ep
.\hip-ep\bin\hip-onnx-runner.exe -m your-model.onnx
```
</div>

    <p>
      Linux needs one more thing: a ROCm runtime, which the package deliberately
      does not bundle. Both paths are written out step by step, with a check and
      an expected result after every command.
    </p>
    <div class="btn-row">
      <a class="btn btn--primary" href="{{ '/docs/quickstart/linux/' | relative_url }}">Linux Quick Start</a>
      <a class="btn btn--ghost" href="{{ '/docs/quickstart/windows/' | relative_url }}">Windows Quick Start</a>
    </div>
  </div>
</section>

<section class="section">
  <div class="section__inner">
    <h2 class="headline-md">Supported hardware</h2>

<div class="prose" markdown="1">

| GPU | Architecture | Linux | Windows |
|---|---|---|---|
| Ryzen AI Max ("Strix Halo") | `gfx1151` | Package | Package |
| Ryzen AI ("Strix Point") | `gfx1150` | Source | Package |
| Ryzen AI ("Krackan Point") | `gfx1152` | Source | Package |
| Instinct MI350X | `gfx950` | Source | — |

</div>

    <p>
      Anything not listed is a source build away, not a supported
      configuration. The <a href="{{ '/docs/' | relative_url }}">overview</a>
      covers what "supported" means here, including where tuned-library coverage
      is narrower than kernel coverage.
    </p>
  </div>
</section>

<section class="section section--alt">
  <div class="section__inner">
    <h2 class="headline-md">Start here</h2>
    <div class="card-grid">
      <div class="card">
        <p class="card__title"><a href="{{ '/docs/quickstart/' | relative_url }}">Quick Start</a></p>
        <p class="card__body">From an empty machine to a model on the GPU, with
          a verification step that catches the silent CPU fallback.</p>
      </div>
      <div class="card">
        <p class="card__title"><a href="{{ '/docs/' | relative_url }}">Overview</a></p>
        <p class="card__body">What hip-ep is, how a graph reaches the GPU, and
          the two mistakes that account for most confusing first runs.</p>
      </div>
      <div class="card">
        <p class="card__title"><a href="{{ '/docs/quickstart/build/' | relative_url }}">Build from Source</a></p>
        <p class="card__body">The developer path, including the mock runtime for
          working on the compiler without a GPU.</p>
      </div>
    </div>
  </div>
</section>
