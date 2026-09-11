---
title: Benchmarks
description: One measured snapshot per release, with the conditions it was measured under.
---

{% assign snap = site.data.benchmarks.snapshot -%}
{% assign lens = site.data.benchmarks.prompt_lengths -%}
{% assign catalog = site.data.models.llm | concat: site.data.models.vlm -%}

{% if snap.placeholder %}
<div class="note note--warn" markdown="1">
**Numbers withheld — every value below is a zero placeholder.** The measurements
exist and the run described here happened; the results are simply not cleared for
publication yet. Zero means "not published", not "measured as zero", and nothing
on this page should be cited or compared against anything.

The page is here so the layout, units, rounding and per-model coverage can be
reviewed ahead of that clearance. Publishing is a single edit to
`site/_data/benchmarks.yml`: drop in the numbers and set `placeholder: false`.
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

Neither figure includes the compile. hip-ep compiles the graph on first use and
every call after that runs compiled code, so the first request of a session is
not a steady-state measurement and is excluded from both columns. The compiled
artifact lives for the life of the session — in {{ site.hip_ep_version }} there
is no on-disk cache, so a new process pays the compile again. See the
[overview]({{ '/docs/' | relative_url }}) for what happens during that first
call.

## The numbers

Prompt lengths are {{ lens | join: ", " }} tokens.

<div class="table-scroll" markdown="1">

| Model | Parameters | {% for l in lens %}TTFT {{ l }} (s) | {% endfor %}{% for l in lens %}TPS {{ l }} | {% endfor %}
|---|---|{% for l in lens %}---:|{% endfor %}{% for l in lens %}---:|{% endfor %}
{% for row in site.data.benchmarks.lm -%}
{% assign m = catalog | where: "id", row.id | first -%}
| {{ m.name | default: row.id }} | {{ m.params }} | {% for v in row.ttft %}{{ v }} | {% endfor %}{% for v in row.tps %}{{ v }} | {% endfor %}
{% endfor %}

</div>

TTFT rising roughly linearly with prompt length is expected — prefill is compute
bound and processes every prompt token. TPS falling as the prompt grows is also
expected: each generated token attends over a longer KV cache.

Two shapes in that table are worth naming, because both look like errors and
neither is. The sparse mixture-of-experts models — the `A3B` and `A4B` rows —
generate faster than dense models several times smaller, because only their
active parameters are read per token. And the vision-language models start with
a much higher TTFT at 128 tokens than the language models do: that figure
includes running the image through the vision encoder, which happens once and
before any text is generated.

## What is not on this page

Sixteen generative models, and nothing else. The release validation suite is
wider than that, and this page is deliberately not: TTFT and TPS are the two
numbers that describe what it is like to use a model, and a page that mixes
them with per-inference latencies for a different class of workload invites
comparisons between figures that do not mean the same thing.

The Procyon AI Inference Benchmark is also part of the suite, and in
{{ snap.release }} it is at *functionality verified, optimization in progress* —
the workloads run and produce correct results, and the performance work has not
been done yet. Publishing those numbers now would characterise a deliberately
unoptimized path, so they are not here either.

## How these were measured

The conditions matter more than the numbers, because getting any of these wrong
produces results that look fine and are not. These are the rules the benchmark
harness runs under, and they are the rules to copy if you want numbers
comparable to these:

- **Runs are serial.** Two benchmarks sharing a GPU invalidate both.
- **No debug or tracing environment variables.** `HIPDNN_EP_PERF=1` and
  `HIPDNN_EP_DEBUG=1` change what is measured. They are off.
- **Kernel autotune caches are primed first.** A cold autotune cache measures
  the tuner, not the kernel.
- **The first inference is excluded.** It includes compiling the graph, which
  is a one-off cost and not a property of the model.

One condition is not controlled and cannot be: **thermal state**. On a
compute-bound workload in a thin chassis, back-to-back runs drift downward as
the machine heats up. That is a property of the hardware rather than of the
release, and it is the main reason two honest runs of the same build disagree.

If you reproduce these on your own hardware, expect different absolute numbers.
A different driver, a different power profile or a different memory
configuration moves everything. What should hold is the shape: which models are
fast relative to each other, and how each degrades with prompt length.

## Reproducing them

The tool is in the release package: `model_benchmark` on Windows, which drives
the model through OGA and reports TTFT and TPS directly. The
[C++ package]({{ '/docs/get-started/cpp-package/' | relative_url }}) page covers
it, along with the flags that make a measurement comparable to these.

<div class="note note--warn" markdown="1">
Before trusting a number you measured yourself, confirm the graph actually ran
on the GPU. ONNX Runtime falls back to CPU silently, and a CPU fallback produces
correct output at a wrong speed. Set `HIPDNN_EP_STRICT=1` to turn that fallback
into a hard failure.
</div>
