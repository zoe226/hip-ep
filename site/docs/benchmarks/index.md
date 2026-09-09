---
title: Benchmarks
description: One measured snapshot per release, with the conditions it was measured under.
---

{% assign snap = site.data.benchmarks.snapshot -%}
{% assign lens = site.data.benchmarks.prompt_lengths -%}

{% if snap.placeholder %}
<div class="note note--warn" markdown="1">
**Placeholder numbers.** Every value on this page is invented. It exists so the
layout, units and rounding can be reviewed before real results are published.
Do not cite anything here. Replacing it is an edit to
`site/_data/benchmarks.yml`.
</div>
{% endif %}

<div class="stat-row">
  <div class="stat">
    <span class="stat__value">{{ snap.release }}</span>
    <span class="stat__label">Release measured</span>
  </div>
  <div class="stat">
    <span class="stat__value">{{ snap.run_date }}</span>
    <span class="stat__label">Run date</span>
  </div>
  <div class="stat">
    <span class="stat__value">{{ snap.os }}</span>
    <span class="stat__label">Operating system</span>
  </div>
</div>

Measured on {{ snap.gpu }}. {{ snap.note }}

## What this page is, and is not

This is **one snapshot**: the current release, on one machine, on one day. There
is deliberately no version history, no trend line and no comparison against
other runtimes.

That is a real limitation and worth stating plainly. You cannot use this page to
answer "did release N make my model faster than release N-1", and you cannot use
it to answer "is hip-ep faster than X". It answers one question: *what does this
release do on this hardware today.*

<div class="note note--warn" markdown="1">
A benchmark page with no date is a benchmark page that is quietly wrong. If the
run date above is far behind the current release, treat every number below as
unverified rather than as a measurement.
</div>

## How to read the numbers

| Metric | Unit | Direction | What it measures |
|---|---|---|---|
| TTFT | seconds | Lower is better | Time from submitting the prompt to the first generated token. Dominated by prefill, so it grows with prompt length. |
| TPS | tokens/second | Higher is better | Steady-state generation rate after the first token. Dominated by memory bandwidth. |
| RTF | ratio | Lower is better | Wall-clock seconds spent per second of audio. 0.05 means a minute of audio transcribes in three seconds. |
| First infer | milliseconds | Lower is better | The first call, which includes compiling the graph. Not a steady-state number. |
| Average infer | milliseconds | Lower is better | Mean of the calls after the first. This is the number to compare. |
| QPS | queries/second | Higher is better | Sustained throughput with the harness's own batching, which is why it is not simply 1000 ÷ average infer. |

The gap between *first infer* and *average infer* is the point of the
architecture, not a defect: hip-ep compiles the graph on first use and caches
the artifact. See the [overview]({{ '/docs/' | relative_url }}) for what happens
during that first call.

## Language and vision-language models

Prompt lengths are {{ lens | join: ", " }} tokens.

<div class="table-scroll" markdown="1">

| Model | {% for l in lens %}TTFT {{ l }} (s) | {% endfor %}{% for l in lens %}TPS {{ l }} | {% endfor %}
|---|{% for l in lens %}---:|{% endfor %}{% for l in lens %}---:|{% endfor %}
{% for row in site.data.benchmarks.lm -%}
| `{{ row.id }}` | {% for v in row.ttft %}{{ v }} | {% endfor %}{% for v in row.tps %}{{ v }} | {% endfor %}
{% endfor %}

</div>

TTFT rising roughly linearly with prompt length is expected — prefill is compute
bound and processes every prompt token. TPS falling as the prompt grows is also
expected: each generated token attends over a longer KV cache.

## Speech recognition

<div class="table-scroll" markdown="1">

| Model | TTFT (s) | TPS | RTF |
|---|---:|---:|---:|
{% for row in site.data.benchmarks.speech -%}
| `{{ row.id }}` | {{ row.ttft }} | {{ row.tps }} | {{ row.rtf }} |
{% endfor %}

</div>

## Vision models

<div class="table-scroll" markdown="1">

| Model | First infer (ms) | Average infer (ms) | QPS |
|---|---:|---:|---:|
{% for row in site.data.benchmarks.vision -%}
| `{{ row.id }}` | {{ row.first_infer }} | {{ row.avg_infer }} | {{ row.qps }} |
{% endfor %}

</div>

## How these were measured

The conditions matter more than the numbers, because getting any of these wrong
produces results that look fine and are not:

- **Runs are serial.** Two benchmarks sharing a GPU invalidate both.
- **No debug or tracing environment variables.** `HIPDNN_EP_PERF=1` and
  `HIPDNN_EP_DEBUG=1` change what is measured. They are off.
- **Kernel autotune caches are primed first.** A cold autotune cache measures
  the tuner, not the kernel.
- **The first inference is excluded from steady-state figures**, and reported
  separately where it is reported at all.
- **Thermal state is accounted for.** On a compute-bound workload in a thin
  chassis, back-to-back runs drift downward. This is a property of the machine,
  not the release.

If you reproduce these on your own hardware, expect different absolute numbers.
A different driver, a different power profile or a different memory
configuration moves everything. What should hold is the shape: which models are
fast relative to each other, and how each degrades with prompt length.

## Reproducing them

The tools are in the release package —
`onnxruntime_perf_test` for single graphs and `model_benchmark` for generative
models on Windows. The
[Windows Quick Start]({{ '/docs/quickstart/windows/' | relative_url }}) and
[Linux Quick Start]({{ '/docs/quickstart/linux/' | relative_url }}) both end
with a benchmark step.

<div class="note note--warn" markdown="1">
Before trusting a number you measured yourself, confirm the graph actually ran
on the GPU. ONNX Runtime falls back to CPU silently, and a CPU fallback produces
correct output at a wrong speed. Set `HIPDNN_EP_STRICT=1` to turn that fallback
into a hard failure.
</div>
