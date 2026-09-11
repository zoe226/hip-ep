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
      <h1 class="headline-lg">The fastest, most efficient LLM inference backend on AMD iGPU</h1>
      <p class="lede">
        hip-ep compiles your ONNX graph through an MLIR pipeline — ONNX dialect,
        to a custom HIP dialect, to LLVM IR — and executes it on AMD GPUs with
        hipDNN, hipBLASLt and custom HIP kernels.
      </p>
      <div class="btn-row">
        <a class="btn btn--primary" href="{{ '/docs/get-started/' | relative_url }}">Get started</a>
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
        what it covers and what it costs them. The Highlights are in the README
        and in the design docs, where a reader who has decided to care will go
        looking for them.
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
          <p class="deck__stat">16</p>
          <p class="deck__title">Models validated every release</p>
          <p class="deck__body">
            Eight text and eight vision-language, from a 4B dense decoder to a
            120B sparse mixture of experts.
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
          <p class="deck__stat">3</p>
          <p class="deck__title">RDNA 3.5 GPU architectures</p>
          <p class="deck__body">
            Ryzen AI Max (Strix Halo) and Ryzen AI (Strix Point, Krackan Point)
            — all three in one Windows download, with no architecture to pick.
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
      {%- if snap.placeholder %}
      Time to first token is measured for all of them and not published yet,
      which is why that line is empty.
      {%- endif %}
    </p>
    <p>
      Six of the sixteen in the official matrix are below. The rest of the
      matrix, and the fifty-plus models brought up on Strix Halo behind it, are
      on the <a href="{{ '/docs/models/' | relative_url }}">model matrix</a>.
    </p>

    <div class="badge-row">
      <span class="badge">Text generation</span>
      <span class="badge">Code generation</span>
      <span class="badge">Vision-language</span>
      <span class="badge">Reasoning</span>
      <span class="badge">Sparse mixture of experts</span>
      <span class="badge">Gated DeltaNet</span>
      <span class="badge">int4 weight-only</span>
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
A reader checking whether their own GPU is on the list is scanning the table,
not reading around it, so the prose under it is two sentences: what the one
package covers, and what happens if you are not in the table.
{%- endcomment -%}
<section class="section section--attached">
  <div class="section__inner">
    <h2 class="headline-md">Supported hardware</h2>

{%- comment -%}
Full-width column so this heading starts on the same line as the models above
it, but the table itself is capped: three rows of two short cells stretched to
the full page width is a lot of ruled whitespace between a GPU and its
architecture.
{%- endcomment -%}
<div class="prose prose--table-narrow" markdown="1">

| GPU | Architecture |
|---|---|
| Ryzen AI Max ("Strix Halo") | `gfx1151` |
| Ryzen AI ("Strix Point") | `gfx1150` |
| Ryzen AI ("Krackan Point") | `gfx1152` |

</div>

    <p class="table-note">
      One Windows package covers all three, which is why it has no architecture
      suffix. A GPU that is not in this table will still
      <a href="{{ '/docs/get-started/source-build/' | relative_url }}">build from
      source</a>, but nothing in CI exercises it.
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
      <a class="btn btn--primary" href="{{ '/docs/get-started/deploy-script/' | relative_url }}">What the script does</a>
      <a class="btn btn--ghost" href="{{ '/docs/get-started/' | relative_url }}">Every install path</a>
    </div>

    {%- comment -%}
    The manual route stays on the page, below a rule and at half the weight.
    It is not a footnote -- it is what anyone who has to explain the install to
    someone else will want, and the script covers gfx1151 only -- but
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
            Two commands, and the second one is already inference — nothing to
            install, nothing to register, because every DLL the binaries need
            ships inside the archive. There is a Python package as well, and a
            source build for changing the compiler. All three are written out a
            step at a time, each with the result to expect, so a step that goes
            wrong is caught where it goes wrong rather than three commands
            later.
          </p>
          <div class="btn-row">
            <a class="btn btn--ghost" href="{{ '/docs/get-started/cpp-package/' | relative_url }}">C++ package</a>
            <a class="btn btn--ghost" href="{{ '/docs/get-started/python-package/' | relative_url }}">Python package</a>
            <a class="btn btn--ghost" href="{{ '/docs/get-started/source-build/' | relative_url }}">Source build</a>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<section class="section">
  <div class="section__inner">
    <h2 class="headline-md">Start here</h2>
    <div class="card-grid">
      <a class="card card--link" href="{{ '/docs/get-started/' | relative_url }}">
        <p class="card__title">Get Started</p>
        <p class="card__body">From an empty machine to a model on the GPU, one
          page per install path, each ending in a check that catches the silent
          CPU fallback.</p>
      </a>
      <a class="card card--link" href="{{ '/docs/' | relative_url }}">
        <p class="card__title">Overview</p>
        <p class="card__body">What hip-ep is, how a graph reaches the GPU, which
          hardware is covered, and what it is pinned to.</p>
      </a>
      <a class="card card--link" href="{{ '/docs/get-started/deploy-script/' | relative_url }}">
        <p class="card__title">One-command deploy</p>
        <p class="card__body">The Strix Halo install as a single script — the
          same steps, unattended, ending in the same proof.</p>
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
      <a class="card card--link" href="{{ '/docs/get-started/source-build/' | relative_url }}">
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
