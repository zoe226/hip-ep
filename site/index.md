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
  <div class="section__inner hero__grid">
    <div class="hero__main">
      <p class="kicker">ONNX Runtime Execution Provider</p>
      <h1 class="headline-lg">The fastest, most efficient LLM inference on AMD GPUs</h1>
      <p class="lede">
        hip-ep compiles your ONNX graph through an MLIR pipeline — ONNX dialect,
        to a custom HIP dialect, to LLVM IR — and executes it on AMD GPUs with
        hipDNN, hipBLASLt and custom HIP kernels.
      </p>
      <div class="btn-row">
        <a class="btn btn--primary" href="{{ '/docs/quickstart/' | relative_url }}">Get started</a>
        <a class="btn btn--ghost" href="{{ '/models/' | relative_url }}">Models</a>
        <a class="btn btn--ghost" href="{{ '/docs/benchmarks/' | relative_url }}">Benchmarks</a>
        <a class="btn btn--ghost" href="{{ site.repo_url }}/releases/tag/{{ site.hip_ep_version }}">Download {{ site.hip_ep_version }}</a>
      </div>
    </div>

    {%- comment -%}
    The feature deck. Without JavaScript every panel is simply stacked and the
    controls stay hidden, which is why the slides are ordinary sections rather
    than an off-screen track: the fallback has to be readable, not merely
    present. initDeck() in script.js takes over from there.
    {%- endcomment -%}
    <aside class="deck" data-deck aria-label="What hip-ep does">
      <div class="deck__viewport" data-deck-viewport>
        {%- comment -%}
        Six claims, each led by the one figure that carries it. This panel used
        to step through the README Highlights, which describe how the thing is
        built; a visitor deciding whether to spend an afternoon on it is asking
        what it covers and what it costs them. The Highlights are still on the
        page, under "Under the hood", where a reader who has decided to care
        will go looking for them.
        {%- endcomment -%}
        <article class="deck__slide" data-deck-slide>
          <p class="deck__kicker">Models</p>
          <p class="deck__stat">50+</p>
          <p class="deck__title">LLMs running on Strix Halo today</p>
          <p class="deck__body">
            Brought up and measured on the hardware, not read off a
            compatibility list.
          </p>
        </article>
        <article class="deck__slide" data-deck-slide>
          <p class="deck__kicker">Coverage</p>
          <p class="deck__stat">20+</p>
          <p class="deck__title">Distinct model architectures</p>
          <p class="deck__body">
            Text generation, vision-language, speech recognition and vision —
            including sparse mixture of experts.
          </p>
        </article>
        <article class="deck__slide" data-deck-slide>
          <p class="deck__kicker">Context</p>
          <p class="deck__stat">32K</p>
          <p class="deck__title">Maximum supported context, in tokens</p>
          <p class="deck__body">
            One compiled model serves every prompt length, prefill and decode.
            No shape buckets, and no recompile mid-conversation.
          </p>
        </article>
        <article class="deck__slide" data-deck-slide>
          <p class="deck__kicker">Hardware</p>
          <p class="deck__stat">4</p>
          <p class="deck__title">AMD GPU architectures</p>
          <p class="deck__body">
            Ryzen AI Max (Strix Halo), Ryzen AI (Strix Point and Krackan Point),
            and Instinct MI350X.
          </p>
        </article>
        <article class="deck__slide" data-deck-slide>
          <p class="deck__kicker">Integration</p>
          <p class="deck__stat deck__stat--word">Drop-in</p>
          <p class="deck__title">An execution provider, not a new runtime</p>
          <p class="deck__body">
            The ONNX Runtime calls you already make stay as they are. hip-ep
            registers alongside the other providers and claims what it can
            compile.
          </p>
        </article>
        <article class="deck__slide" data-deck-slide>
          <p class="deck__kicker">License</p>
          <p class="deck__stat deck__stat--word">Open source</p>
          <p class="deck__title">Compiler, runtime and kernels in one repository</p>
          <p class="deck__body">
            Every layer that touched your graph is readable, including this
            site.
          </p>
        </article>
      </div>

      <div class="deck__controls" data-deck-controls hidden>
        <button class="deck__nav" type="button" data-deck-prev aria-label="Previous feature">&#8249;</button>
        <div class="deck__dots" data-deck-dots></div>
        <button class="deck__nav" type="button" data-deck-next aria-label="Next feature">&#8250;</button>
      </div>
    </aside>
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
    <p>
      The fifty-plus in the panel above is everything that has been brought up
      and measured on the hardware, on Strix Halo. Sixteen of those are the
      <em>official matrix</em> — the models that gate every release on function,
      performance and accuracy. Seven of the sixteen are below; the rest are on
      the <a href="{{ '/docs/models/' | relative_url }}">model matrix</a>.
    </p>

    <div class="badge-row">
      <span class="badge">Text generation</span>
      <span class="badge">Code generation</span>
      <span class="badge">Vision-language</span>
      <span class="badge">Speech recognition</span>
      <span class="badge">Image classification</span>
      <span class="badge">Object detection</span>
      <span class="badge">BEV perception</span>
      <span class="badge">Sparse mixture of experts</span>
    </div>

    <div class="model-grid">
      {%- for m in llm_hi %}
      {% include model-card.html m=m kind="LLM" compact=true %}
      {%- endfor %}
      {%- for m in vlm_hi %}
      {% include model-card.html m=m kind="VLM" compact=true %}
      {%- endfor %}
    </div>

    <div class="btn-row">
      <a class="btn btn--primary" href="{{ '/models/' | relative_url }}">The showcase in full</a>
      <a class="btn btn--ghost" href="{{ '/docs/models/' | relative_url }}">Model matrix</a>
      <a class="btn btn--ghost" href="{{ '/docs/benchmarks/' | relative_url }}">Benchmarks</a>
    </div>
  </div>
</section>

{%- comment -%}
Directly under the models, and with the section's own top padding removed, so
the two read as one thought: here is what runs, and here is what it runs on.
The exceptions used to be three paragraphs; they are the same three facts, but
a reader checking whether their own GPU is on the list is scanning the table,
not reading around it.
{%- endcomment -%}
<section class="section section--attached">
  <div class="section__inner">
    <h2 class="headline-md">Supported hardware</h2>

{%- comment -%}
Full-width column so this heading starts on the same line as the models above
it, but the table itself is capped: four rows of two short cells stretched to
the full page width is a lot of ruled whitespace between a GPU and its
architecture.
{%- endcomment -%}
<div class="prose prose--table-narrow" markdown="1">

| GPU | Architecture |
|---|---|
| Ryzen AI Max ("Strix Halo") | `gfx1151` |
| Ryzen AI ("Strix Point") | `gfx1150` |
| Ryzen AI ("Krackan Point") | `gfx1152` |
| Instinct MI350X | `gfx950` |

</div>

    <p class="table-note">
      Prebuilt packages cover all three Ryzen AI parts on Windows and Ryzen AI
      Max on Linux; the rest are a
      <a href="{{ '/docs/quickstart/build/' | relative_url }}">source build</a>,
      and MI350X is Linux only. Only <code>gfx1151</code> ships hipBLASLt and
      rocBLAS tuning data, so read Strix Point and Krackan Point GEMM
      performance as uncharacterized rather than representative. A GPU that is
      not in this table will still build, but nothing in CI exercises it — the
      <a href="{{ '/docs/' | relative_url }}">overview</a> has the detail.
    </p>
  </div>
</section>

<section class="section section--alt" id="install">
  <div class="section__inner">
    <p class="kicker">Install</p>
    <h2 class="headline-md">Now put one on your own machine</h2>
    <p class="lede">
      On Windows with a Ryzen AI Max, this is the entire setup. It detects the
      GPU, fetches the release, unpacks it, then generates a small model and
      runs it twice — once through hip-ep and once CPU-only — so the script
      finishes by <em>proving</em> the GPU did the work rather than assuming it.
      About ten minutes, almost all of it the download.
    </p>

<div class="prose install__cmd" markdown="1">
```powershell
irm {{ site.url }}{{ site.baseurl }}/assets/deploy-strix-halo.ps1 -OutFile deploy.ps1
.\deploy.ps1
```
</div>

    <p class="install__note">
      Non-interactive and safe to re-run. The last line of output and a JSON
      report are both machine-readable, which is what makes it something a
      coding agent can be handed as a prerequisite.
    </p>

    <div class="btn-row">
      <a class="btn btn--primary" href="{{ '/docs/quickstart/deploy-script/' | relative_url }}">What the script does</a>
      <a class="btn btn--ghost" href="{{ '/docs/quickstart/' | relative_url }}">Linux, and the other GPUs</a>
    </div>

    {%- comment -%}
    The manual route stays on the page, below a rule and at half the weight.
    It is not a footnote -- it is the only route on Linux, and it is what
    anyone who has to explain the install to someone else will want -- but
    presenting the two as equals was leaving the reader to make a choice the
    page is in a better position to make for them.
    {%- endcomment -%}
    <div class="install__manual">
      <p class="split__label">Or do it a command at a time</p>
      <div class="split">
        <div class="split__col">

<div class="prose" markdown="1">
```powershell
Expand-Archive gpu-test-package-windows-{{ site.hip_ep_version }}.zip -DestinationPath hip-ep
.\hip-ep\bin\hip-onnx-runner.exe -m your-model.onnx
```
</div>

        </div>
        <div class="split__col">
          <p>
            Two commands, and the second one is already inference. Linux needs
            one more thing — a ROCm runtime, which the package deliberately does
            not bundle, because the right way to get one differs by
            distribution. Both platforms are written out a step at a time, each
            with the result to expect, so a step that goes wrong is caught where
            it goes wrong rather than three commands later.
          </p>
          <div class="btn-row">
            <a class="btn btn--ghost" href="{{ '/docs/quickstart/windows/' | relative_url }}">Windows Quick Start</a>
            <a class="btn btn--ghost" href="{{ '/docs/quickstart/linux/' | relative_url }}">Linux Quick Start</a>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<section class="section">
  <div class="section__inner">
    <p class="kicker">Verification</p>
    <h2 class="headline-md">Proof, not assumption</h2>
    <p class="lede">
      ONNX Runtime does not fail when a provider cannot take your graph. It
      quietly runs that part on the CPU and returns correct answers — so an
      install where the GPU is doing nothing at all looks exactly like one that
      works, only slower. Every path on this site ends by ruling that out, and
      neither way of doing it needs you to know how fast the model should have
      been.
    </p>

    <div class="split">
      <div class="split__col">
        <p class="split__label">Turn the fallback into a failure</p>

<div class="prose" markdown="1">
```powershell
$env:HIPDNN_EP_STRICT = "1"
hip-onnx-runner.exe -m your-model.onnx
```
</div>

        <p>
          A subgraph the compiler cannot handle now stops the run at the pass
          that gave up, with the operator named, rather than disappearing into
          the CPU provider. It is a validation switch, not a production one —
          unset it before you measure anything.
        </p>
      </div>

      <div class="split__col">
        <p class="split__label">Or ask the provider what it chose</p>

<div class="prose" markdown="1">
```text
morphizen-ep.cpp:344] Using backend: mlir-backend
```
</div>

        <p>
          Set <code>MORPHIZEN_DEBUG_MORPHIZEN_EP=1</code> and the EP logs the
          backend it selected. That line is direct attribution — it is the
          provider saying what it did, not a conclusion drawn from a stopwatch.
        </p>
      </div>
    </div>

    <div class="btn-row">
      <a class="btn btn--primary" href="{{ '/docs/tutorials/verify-gpu/' | relative_url }}">Prove the GPU ran it</a>
      <a class="btn btn--ghost" href="{{ '/docs/tutorials/benchmark/' | relative_url }}">Benchmark without fooling yourself</a>
    </div>
  </div>
</section>

{%- comment -%}
The Highlights from the repository README. They were in the hero panel and are
now here, below the install and the verification sections: they answer "how is
this built", which is a question a reader asks after deciding the thing is
worth their afternoon, not before.
{%- endcomment -%}
<section class="section">
  <div class="section__inner">
    <p class="kicker">Under the hood</p>
    <h2 class="headline-md">What the provider actually does</h2>
    <div class="card-grid">
      <div class="card">
        <p class="card__title">MLIR compiler pipeline</p>
        <p class="card__body">ONNX dialect, to a custom HIP dialect, to LLVM IR
          — integrated with ONNX Runtime through the MorphiZen pass framework.</p>
      </div>
      <div class="card">
        <p class="card__title">ROCm execution backends</p>
        <p class="card__body">The compiled graph dispatches into hipDNN and
          hipBLASLt for the operations they cover, and into HIP kernels written
          for this project where they do not.</p>
      </div>
      <div class="card">
        <p class="card__title">Dynamic shapes</p>
        <p class="card__body">Shapes are refined during compilation and the rest
          is computed in the graph, including outputs whose size is not known
          until the run.</p>
      </div>
      <div class="card">
        <p class="card__title">GPU memory planning</p>
        <p class="card__body">Every transient is placed in one of a few
          grow-on-demand pools rather than allocated per inference. Host-written
          shape scalars are kept apart, in host-mapped scratch.</p>
      </div>
      <div class="card">
        <p class="card__title">In-graph output allocation</p>
        <p class="card__body">Graph outputs come from the provider's own
          allocation callback once their runtime shapes are known, so they stay
          owned by the runtime instead of being copied out of a pool.</p>
      </div>
      <div class="card">
        <p class="card__title">Externalized constants</p>
        <p class="card__body">Large tensors live beside the model artifact
          rather than inside it, which keeps the artifact small enough to cache
          and re-emit cheaply.</p>
      </div>
      <div class="card">
        <p class="card__title">Two artifact formats</p>
        <p class="card__body">By default a model becomes OS-portable LLVM
          bitcode, JIT-loaded in-process when the session is created. A native
          <code>.dll</code>/<code>.so</code> is an opt-in.</p>
      </div>
      <div class="card">
        <p class="card__title">Extensible pipeline</p>
        <p class="card__body">The pipeline exposes registered plugin slots, and
          dialects and passes can be loaded from outside the tree — so a stage
          can be replaced without forking the compiler.</p>
      </div>
    </div>
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
    <p>
      Something here wrong, missing, or contradicted by your own machine? The
      compiler, the runtime, the kernels and this site are all in
      <a href="{{ site.repo_url }}">one open-source repository</a> — open an
      <a href="{{ site.repo_url }}/issues">issue</a>, including the case where
      the documentation is what is broken.
    </p>
  </div>
</section>
