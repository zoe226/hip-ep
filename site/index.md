---
layout: page
permalink: /
title: null
description: >-
  hip-ep is an ONNX Runtime Execution Provider for AMD GPUs. It compiles ONNX
  graphs through an MLIR pipeline and runs them with hipDNN, hipBLASLt and
  custom HIP kernels.
---

{%- assign snap = site.data.benchmarks.snapshot -%}
{%- assign llm_hi = site.data.models.llm | where: "highlight", true -%}
{%- assign vlm_hi = site.data.models.vlm | where: "highlight", true -%}

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

<div class="prose hero__cmd" markdown="1">
```powershell
irm {{ site.url }}{{ site.baseurl }}/assets/deploy-strix-halo.ps1 -OutFile deploy.ps1; .\deploy.ps1
```
</div>

    <p class="hero__cmd-note">
      Windows on a Ryzen AI Max. Installs the release package, then proves the
      GPU executed a model rather than assuming it.
      <a href="{{ '/docs/quickstart/deploy-script/' | relative_url }}">What this script does</a>
      &middot;
      <a href="{{ '/docs/quickstart/' | relative_url }}">Other platforms</a>
    </p>
  </div>
</section>

<section class="section section--alt">
  <div class="section__inner">
    <div class="stat-row">
      <div class="stat">
        <span class="stat__value">50+</span>
        <span class="stat__label">LLMs brought up on Strix Halo</span>
      </div>
      <div class="stat">
        <span class="stat__value">20+</span>
        <span class="stat__label">Distinct architectures — LLM, VLM, vision, speech</span>
      </div>
      <div class="stat">
        <span class="stat__value">One graph</span>
        <span class="stat__label">Any prompt length, prefill and decode, compiled once</span>
      </div>
      <div class="stat">
        <span class="stat__value">32K</span>
        <span class="stat__label">Maximum supported context, in tokens</span>
      </div>
    </div>
    <p>
      Fifty-plus is what has been brought up and measured on the hardware.
      Sixteen of those are the <em>official matrix</em> — the models that gate
      every release on function, performance and accuracy. Seven of the sixteen
      are below; the rest are on the
      <a href="{{ '/docs/models/' | relative_url }}">model matrix</a>.
    </p>
  </div>
</section>

<section class="section">
  <div class="section__inner">
    <p class="kicker">Model showcase</p>
    <h2 class="headline-md">Models that already run on your GPU</h2>
    <p class="lede">
      Not a compatibility list. Every model here is in the release validation
      suite — brought up on the hardware and checked for function, performance
      and accuracy before {{ snap.release }} ships, with a regression in any of
      the three blocking the release.
    </p>

    <div class="model-grid">
      {%- for m in llm_hi %}
      {% include model-card.html m=m kind="LLM" %}
      {%- endfor %}
      {%- for m in vlm_hi %}
      {% include model-card.html m=m kind="VLM" %}
      {%- endfor %}
    </div>

    <div class="btn-row">
      <a class="btn btn--primary" href="{{ '/models/' | relative_url }}">The showcase in full</a>
      <a class="btn btn--ghost" href="{{ '/docs/models/' | relative_url }}">Model matrix</a>
      <a class="btn btn--ghost" href="{{ '/docs/benchmarks/' | relative_url }}">Benchmarks</a>
    </div>
  </div>
</section>

<section class="section section--alt">
  <div class="section__inner">
    <h2 class="headline-md">From download to inference</h2>
    <p class="lede">
      On Windows the release package is self-contained — the HIP runtime,
      hipBLASLt, rocBLAS and MIOpen all ship with it. Nothing is compiled,
      nothing is installed system-wide, and no administrator rights are needed.
    </p>

    <div class="split">
      <div class="split__col">
        <p class="split__label">Hand it to a script</p>

<div class="prose" markdown="1">
```powershell
irm {{ site.url }}{{ site.baseurl }}/assets/deploy-strix-halo.ps1 -OutFile deploy.ps1
.\deploy.ps1
```
</div>

        <p>
          Detects the GPU, fetches the release, unpacks it, then generates a
          small model and runs it twice — once through hip-ep and once CPU-only
          — to confirm the GPU actually did the work. About ten minutes, almost
          all of it the download.
        </p>
        <p>
          It is non-interactive and safe to re-run. The last line of output and
          a JSON report are both machine-readable, which is what makes it
          something a coding agent can be handed as a prerequisite.
        </p>
        <div class="btn-row">
          <a class="btn btn--primary" href="{{ '/docs/quickstart/deploy-script/' | relative_url }}">What the script does</a>
        </div>
      </div>

      <div class="split__col">
        <p class="split__label">Or do it yourself</p>

<div class="prose" markdown="1">
```powershell
Expand-Archive gpu-test-package-windows-{{ site.hip_ep_version }}.zip -DestinationPath hip-ep
.\hip-ep\bin\hip-onnx-runner.exe -m your-model.onnx
```
</div>

        <p>
          Two commands, and the second one is already inference. Linux needs one
          more thing — a ROCm runtime, which the package deliberately does not
          bundle, because the right way to get one differs by distribution.
        </p>
        <p>
          Both platforms are written out a command at a time, each with the
          result to expect, and both end by checking that the graph ran where
          you think it did. ONNX Runtime falls back to the CPU silently and
          still returns correct answers, so that check is the point.
        </p>
        <div class="btn-row">
          <a class="btn btn--ghost" href="{{ '/docs/quickstart/windows/' | relative_url }}">Windows Quick Start</a>
          <a class="btn btn--ghost" href="{{ '/docs/quickstart/linux/' | relative_url }}">Linux Quick Start</a>
        </div>
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

    <p>
      That pipeline is why <strong>one graph</strong> is enough. hip-ep compiles
      for dynamic shape, so a single compilation serves any prompt length and
      both phases of generation — prefill and decode — rather than one
      specialization per shape bucket. It is also why a model whose
      architecture did not exist when the compiler was written can be brought
      up without adding kernels for it: a sparse mixture of experts and a Gated
      DeltaNet block go through the same passes as a plain transformer.
    </p>
    <p>
      Around 70 ONNX operators are supported today. The pipeline is built on
      MLIR, pins ONNX Runtime 1.27.0, and is MIT licensed — compiler, runtime
      and kernels are all in the repository.
    </p>
  </div>
</section>

<section class="section section--alt">
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
      A GPU that is not in this table is not a supported configuration. You can
      still build for it — the build accepts any architecture the ROCm toolchain
      handles — but nothing in CI exercises it.
    </p>
    <p>
      One caveat inside the table: the Windows package carries GPU kernels for
      all three RDNA 3.5 parts, but hipBLASLt and rocBLAS tuning data for
      <code>gfx1151</code> only. Strix Point and Krackan Point run, and their
      GEMM-heavy performance should be read as uncharacterized rather than
      representative. The <a href="{{ '/docs/' | relative_url }}">overview</a>
      goes through this in full.
    </p>
  </div>
</section>

<section class="section">
  <div class="section__inner">
    <h2 class="headline-md">Start here</h2>
    <div class="card-grid">
      <a class="card card--link" href="{{ '/docs/quickstart/' | relative_url }}">
        <p class="card__title">Quick Start</p>
        <p class="card__body">From an empty machine to a model on the GPU, with
          a verification step that catches the silent CPU fallback.</p>
      </a>
      <a class="card card--link" href="{{ '/docs/' | relative_url }}">
        <p class="card__title">Overview</p>
        <p class="card__body">What hip-ep is, how a graph reaches the GPU, and
          the two behaviors that make a working setup look broken.</p>
      </a>
      <a class="card card--link" href="{{ '/docs/tutorials/' | relative_url }}">
        <p class="card__title">Tutorials</p>
        <p class="card__body">Serve an LLM, prove the GPU really ran it,
          benchmark without fooling yourself, bring your own ONNX model.</p>
      </a>
      <a class="card card--link" href="{{ '/models/' | relative_url }}">
        <p class="card__title">Models</p>
        <p class="card__body">The language and vision-language models validated
          on every release, and what each one is built out of.</p>
      </a>
      <a class="card card--link" href="{{ '/docs/benchmarks/' | relative_url }}">
        <p class="card__title">Benchmarks</p>
        <p class="card__body">One snapshot per release — throughput and latency,
          with the machine, the commands and the warm-up rules behind them.</p>
      </a>
      <a class="card card--link" href="{{ '/docs/quickstart/build/' | relative_url }}">
        <p class="card__title">Build from Source</p>
        <p class="card__body">For changing the compiler itself, or targeting a
          GPU the release packages do not cover.</p>
      </a>
    </div>
  </div>
</section>
