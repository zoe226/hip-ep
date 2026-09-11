---
layout: page
permalink: /models/
full_width: true
title: Models
description: >-
  A selection of the models hip-ep validates for function, performance and
  accuracy every release. The full matrix and every number behind it are linked
  from here.
---

{%- assign snap = site.data.benchmarks.snapshot -%}
{%- assign llm_hi = site.data.models.llm | where: "highlight", true -%}
{%- assign vlm_hi = site.data.models.vlm | where: "highlight", true -%}

<section class="hero">
  <div class="section__inner">
    <p class="kicker">Model showcase</p>
    <h1 class="headline-lg">Models that already<br />run on your GPU.</h1>
    <p class="lede">
      Every model below is in the release validation suite: it is checked for
      function, performance and accuracy before {{ snap.release }} ships, and a
      regression in any of the three blocks the release.
      {%- if snap.placeholder %}
      Throughput and latency are withheld pending release approval, so each card
      shows what the model <em>is</em> rather than how fast it ran; the
      measurements exist and are not published yet.
      {%- else %}
      The numbers on each card are from the {{ snap.run_date }} snapshot on
      {{ snap.gpu }}.
      {%- endif %}
    </p>
    <div class="btn-row">
      <a class="btn btn--primary" href="{{ '/docs/models/' | relative_url }}">Full model matrix</a>
      <a class="btn btn--ghost" href="{{ '/docs/benchmarks/' | relative_url }}">All benchmark numbers</a>
      <a class="btn btn--ghost" href="{{ '/docs/get-started/' | relative_url }}">Run one yourself</a>
    </div>
  </div>
</section>

<section class="section section--alt">
  <div class="section__inner">
    <h2 class="headline-md">Language models</h2>
    <p class="lede">
      Text and code generation.
      {%- if snap.placeholder %}
      For a sparse mixture of experts the second figure is what is actually read
      per token, which is why a 120B model generates at a usable rate at all.
      {%- else %}
      TPS is the steady-state generation rate; TTFT is the wait before the first
      token appears.
      {%- endif %}
    </p>

    <div class="model-grid">
      {%- for m in llm_hi %}
      {% include model-card.html m=m kind="LLM" %}
      {%- endfor %}
    </div>
  </div>
</section>

<section class="section">
  <div class="section__inner">
    <h2 class="headline-md">Vision-language models</h2>
    <p class="lede">
      Image in, text out.
      {%- if snap.placeholder %}
      The parameter counts below cover the text decoder and the vision encoder
      together; the two run at different precisions, which the line above each
      card spells out.
      {%- else %}
      Their time-to-first-token is higher than a language model's at the same
      prompt length because it includes running the image through the vision
      encoder — work that happens once, before generation starts.
      {%- endif %}
    </p>

    <div class="model-grid">
      {%- for m in vlm_hi %}
      {% include model-card.html m=m kind="VLM" %}
      {%- endfor %}
    </div>
  </div>
</section>

<section class="section section--alt">
  <div class="section__inner section__inner--narrow">
    <h2 class="headline-md">What these cards do not tell you</h2>

<div class="prose" markdown="1">
{% if snap.placeholder -%}
How fast any of them is. Throughput and latency are measured every release and
are simply not cleared for publication yet, so the cards carry size and
architecture instead. Parameter count is a poor stand-in for speed — the sparse
models here generate faster than dense models several times smaller — so the
cards are not a ranking.

Size is not the whole shape of a model either. Two models with the same
parameter count can behave nothing alike depending on how much of it is read per
token, what precision the weights are in, and whether a vision encoder has to
run before any text is generated.
{%- else -%}
Each card quotes one prompt length. That is a real simplification: TTFT grows
with prompt length and TPS falls as the KV cache does, so a card is a point on a
curve, not the curve. The
[benchmarks page]({{ '/docs/benchmarks/' | relative_url }}) has all three
lengths for every model.

They also quote one machine, on one day, running one release. Numbers from a
different GPU, driver or thermal envelope are not comparable to these — and a
benchmark without those conditions attached is a benchmark you cannot check.
{%- endif %}

And this is a selection. The full matrix is
{{ site.data.models.llm | size }} language models and
{{ site.data.models.vlm | size }} vision-language models — from a 4B dense
decoder to a 120B sparse mixture of experts, with Gated DeltaNet somewhere in
the middle. All of them are on the
[model matrix]({{ '/docs/models/' | relative_url }}).
</div>
  </div>
</section>

<section class="section">
  <div class="section__inner">
    <h2 class="headline-md">Bringing your own</h2>
    <p class="lede">
      Nothing on this page is special-cased. hip-ep compiles the subgraph ONNX
      Runtime hands it, so a model that is not on this list is untested rather
      than unsupported — the difference being that nobody can tell you in
      advance how it will do.
    </p>
    <div class="card-grid">
      <a class="card card--link" href="{{ '/docs/get-started/cpp-package/' | relative_url }}">
        <p class="card__title">With the C++ package</p>
        <p class="card__body">Point the bundled binaries at any ONNX graph or
          OGA model directory. Nothing here is special-cased for the models
          above.</p>
      </a>
      <a class="card card--link" href="{{ '/docs/get-started/python-package/' | relative_url }}">
        <p class="card__title">From Python</p>
        <p class="card__body">The same models through your own code, when you
          want the generation loop rather than a benchmark's.</p>
      </a>
      <a class="card card--link" href="{{ '/docs/get-started/source-build/' | relative_url }}">
        <p class="card__title">From a source build</p>
        <p class="card__body">Compare the EP's outputs against the CPU's, and
          find out which parts of a graph it actually claimed.</p>
      </a>
    </div>
  </div>
</section>
