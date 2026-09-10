---
layout: page
permalink: /models/
full_width: true
title: Models
description: >-
  A selection of the models hip-ep validates every release, with the measured
  numbers attached. The full matrix and every number behind it are linked from
  here.
---

{%- assign snap = site.data.benchmarks.snapshot -%}
{%- comment -%}
The card wall quotes one prompt length so the cards stay comparable at a
glance. Index 1 of `prompt_lengths` is the middle column -- 2048 tokens -- which
is the length the whole matrix is characterised at. Change both together.
{%- endcomment -%}
{%- assign col = 1 -%}
{%- assign quoted_len = site.data.benchmarks.prompt_lengths[col] -%}
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
      The performance figures on each card are withheld pending release approval
      and show as zero — that means "not published", not "measured as zero".
      {%- else %}
      The numbers on each card are from the {{ snap.run_date }} snapshot on
      {{ snap.gpu }}.
      {%- endif %}
    </p>
    <div class="btn-row">
      <a class="btn btn--primary" href="{{ '/docs/models/' | relative_url }}">Full model matrix</a>
      <a class="btn btn--ghost" href="{{ '/docs/benchmarks/' | relative_url }}">All benchmark numbers</a>
      <a class="btn btn--ghost" href="{{ '/docs/quickstart/' | relative_url }}">Run one yourself</a>
    </div>
  </div>
</section>

<section class="section section--alt">
  <div class="section__inner">
    <h2 class="headline-md">Language models</h2>
    <p class="lede">
      Text and code generation. TPS is the steady-state generation rate; TTFT is
      the wait before the first token appears.
    </p>

    <div class="model-grid">
      {%- for m in llm_hi %}
      {%- assign b = site.data.benchmarks.lm | where: "id", m.id | first %}
      <article class="card model-card">
        <p class="model-card__kind">LLM{% if m.status != 'Validated' %} &middot; New in {{ snap.release }}{% endif %}</p>
        <h3 class="model-card__name">{% if m.hf %}<a href="https://huggingface.co/{{ m.hf }}">{{ m.name }}</a>{% else %}{{ m.name }}{% endif %}</h3>
        <p class="model-card__meta">{{ m.params }} &middot; {{ m.arch }} &middot; {{ m.precision }}</p>
        <p class="card__body">{{ m.tagline }}</p>
        <dl class="model-card__metrics">
          <div>
            <dt>Tokens / sec</dt>
            <dd>{{ b.tps[col] }}</dd>
          </div>
          <div>
            <dt>Time to first token</dt>
            <dd>{{ b.ttft[col] }} <span>s</span></dd>
          </div>
        </dl>
        <p class="model-card__cond">{{ quoted_len }}-token prompt &middot; {{ snap.release }}</p>
      </article>
      {%- endfor %}
    </div>
  </div>
</section>

<section class="section">
  <div class="section__inner">
    <h2 class="headline-md">Vision-language models</h2>
    <p class="lede">
      Image in, text out. Their time-to-first-token is higher than a language
      model's at the same prompt length because it includes running the image
      through the vision encoder — work that happens once, before generation
      starts.
    </p>

    <div class="model-grid">
      {%- for m in vlm_hi %}
      {%- assign b = site.data.benchmarks.lm | where: "id", m.id | first %}
      <article class="card model-card">
        <p class="model-card__kind">VLM{% if m.status != 'Validated' %} &middot; New in {{ snap.release }}{% endif %}</p>
        <h3 class="model-card__name">{% if m.hf %}<a href="https://huggingface.co/{{ m.hf }}">{{ m.name }}</a>{% else %}{{ m.name }}{% endif %}</h3>
        <p class="model-card__meta">{{ m.params }} &middot; {{ m.arch }} &middot; {{ m.precision }}</p>
        <p class="card__body">{{ m.tagline }}</p>
        <dl class="model-card__metrics">
          <div>
            <dt>Tokens / sec</dt>
            <dd>{{ b.tps[col] }}</dd>
          </div>
          <div>
            <dt>Time to first token</dt>
            <dd>{{ b.ttft[col] }} <span>s</span></dd>
          </div>
        </dl>
        <p class="model-card__cond">{{ quoted_len }}-token prompt &middot; {{ snap.release }}</p>
      </article>
      {%- endfor %}
    </div>
  </div>
</section>

<section class="section section--alt">
  <div class="section__inner section__inner--narrow">
    <h2 class="headline-md">What these cards do not tell you</h2>

<div class="prose" markdown="1">
Each card quotes one prompt length. That is a real simplification: TTFT grows
with prompt length and TPS falls as the KV cache does, so a card is a point on a
curve, not the curve. The
[benchmarks page]({{ '/docs/benchmarks/' | relative_url }}) has all three
lengths for every model.

They also quote one machine, on one day, running one release. Numbers from a
different GPU, driver or thermal envelope are not comparable to these — and a
benchmark without those conditions attached is a benchmark you cannot check.

And this is a selection. The full matrix is
{{ site.data.models.llm | size }} language models,
{{ site.data.models.vlm | size }} vision-language models,
{{ site.data.models.speech | size }} Whisper configurations and
{{ site.data.models.vision | size }} single-graph vision models — including a
70B dense decoder, batch-8 Swin v2 at 2048×3072, and BEV perception stacks. All
of them are on the [model matrix]({{ '/docs/models/' | relative_url }}).
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
      <a class="card card--link" href="{{ '/docs/tutorials/genai-llm/' | relative_url }}">
        <p class="card__title">Run an LLM with GenAI</p>
        <p class="card__body">The tokenizer, KV cache and decode loop a
          generative model needs around it, and where hip-ep fits in.</p>
      </a>
      <a class="card card--link" href="{{ '/docs/tutorials/bring-your-own-model/' | relative_url }}">
        <p class="card__title">Bring your own ONNX model</p>
        <p class="card__body">What to do when part of your graph is not claimed
          by the EP, and how to find out which part.</p>
      </a>
      <a class="card card--link" href="{{ '/docs/tutorials/verify-gpu/' | relative_url }}">
        <p class="card__title">Prove the GPU ran it</p>
        <p class="card__body">ONNX Runtime falls back to CPU silently and
          produces correct answers. Here is how to catch that.</p>
      </a>
    </div>
  </div>
</section>
