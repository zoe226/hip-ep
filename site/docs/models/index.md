---
title: Official Models
description: The models validated against every hip-ep release, and what that validation covers.
---

An *official model* is one that runs in the validation suite before every
release. A model on this page is not merely known to load — it is checked each
release for three separate things, and a regression in any of them blocks the
release rather than being discovered by users afterwards.

Anything not on this page may still work. Plenty does. It just has not been
measured, so nobody can tell you in advance whether it will.

This page is the complete generative matrix: sixteen models, eight of them
vision-language. For a shorter, opinionated selection with the numbers
attached, see the [model showcase]({{ '/models/' | relative_url }}).

## What gets checked

| Check | What it means | What failing it looks like |
|---|---|---|
| Function | The model compiles and produces output for every prompt length in the suite | A missing operator, a shape the compiler cannot infer, or a crash |
| Performance | Time-to-first-token and tokens-per-second stay within tolerance of the previous release | The model still runs, only slower — the failure mode nobody notices without a baseline |
| Accuracy | Perplexity and task scores do not degrade against the reference implementation | Fluent output that is subtly wrong |

Performance and accuracy are tracked separately on purpose. A change that makes
a model faster by taking a shortcut through a kernel will pass the performance
check and fail the accuracy one.

<div class="note" markdown="1">
**The names below are base models, not the files that run.** The suite runs
quantized ONNX exports produced from each of these. Naming the base model and
the quantization scheme separately is the honest version: it tells you what the
model is and what was done to it, and the link goes somewhere you can actually
read about it.
</div>

## Language models

<div class="table-scroll" markdown="1">

| Model | Parameters | Architecture | Quantization | Status |
|---|---|---|---|---|
{% for m in site.data.models.llm -%}
| {% if m.hf %}[{{ m.name }}](https://huggingface.co/{{ m.hf }}){% else %}{{ m.name }}{% endif %} | {{ m.params }} | {{ m.arch }} | {{ m.precision }} | {{ m.status }} |
{% endfor %}

</div>

## Vision-language models

<div class="table-scroll" markdown="1">

| Model | Parameters | Architecture | Quantization | Status |
|---|---|---|---|---|
{% for m in site.data.models.vlm -%}
| {% if m.hf %}[{{ m.name }}](https://huggingface.co/{{ m.hf }}){% else %}{{ m.name }}{% endif %} | {{ m.params }} | {{ m.arch }} | {{ m.precision }} | {{ m.status }} |
{% endfor %}

</div>

Two of these are worth pointing at. The `A3B` and `A4B` suffixes mark sparse
mixture-of-experts models — thirty-five billion parameters of which three are
active per token — and Qwen3.6 pairs that with Gated DeltaNet rather than plain
attention. Neither is a stock transformer, and neither needed a new operator
library: they compile through the same pipeline as everything else on this
page. That is the argument for a compiler, stated as a fact instead of a claim.

## What "int4" means here

Every model in the matrix is quantized. The weights are 4-bit
integers grouped along the input dimension, with a scale — and for asymmetric
schemes a zero point — per group. Activations stay in fp16.

This is not a hip-ep-specific format. These are the same ONNX weight-only
quantized models the rest of the ecosystem produces; hip-ep consumes the
standard `MatMulNBits` representation. On the vision-language models the vision
encoder stays in fp16 while the text decoder is quantized, because the encoder
runs once per image and the decoder runs once per token.

The schemes differ between models — RTN, AWQ, k-quant, symmetric and
asymmetric, group sizes from 32 to 128 — because they come from wherever the
best export of that model came from. hip-ep does not care which one you bring.

<div class="note" markdown="1">
Quantization is a property of the model file, not a runtime flag. hip-ep does
not quantize anything for you. If you bring an fp16 model it runs in fp16, with
the memory footprint that implies.
</div>

## Running one of these

Nothing about these models needs special handling. They load through the same
path as any other ONNX model — see the
[Get Started]({{ '/docs/get-started/' | relative_url }}) — with one caveat that
catches people:

<div class="note note--warn" markdown="1">
A generative model is not a single ONNX graph you call once. It needs a
tokenizer, a KV cache and a decode loop around it. That orchestration is
[ONNX Runtime GenAI](https://github.com/microsoft/onnxruntime-genai)'s job, not
hip-ep's. Calling `session.run()` on a decoder graph directly will produce
logits for exactly one token and no way to continue.
</div>

## Where the numbers are

Measured results for this matrix are on the
[Benchmarks]({{ '/docs/benchmarks/' | relative_url }}) page. That page carries a
single snapshot from a single release, not a history — see it for what is and is
not comparable.
