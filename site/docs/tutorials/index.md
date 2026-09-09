---
title: Tutorials
description: Five things you will need to do after the Quick Start works.
---

The [Quick Start]({{ '/docs/quickstart/' | relative_url }}) ends the moment one
ONNX graph runs on the GPU. That is the smallest possible proof that the
installation works, and it is deliberately not useful for anything else.

These five pages pick up from there. Each one is independent — read the one that
matches what you are trying to do.

<div class="card-grid" markdown="0">
  <div class="card">
    <p class="card__title">1 · Run a real LLM</p>
    <p class="card__body">A decoder graph is not a chatbot. Wire up ONNX Runtime
      GenAI for the tokenizer, the KV cache and the decode loop, and generate
      actual text.</p>
  </div>
  <div class="card">
    <p class="card__title">2 · Prove it ran on the GPU</p>
    <p class="card__body">ONNX Runtime falls back to CPU silently and returns
      correct answers. Three independent ways to catch it, and the environment
      variable that does the opposite of what its name suggests.</p>
  </div>
  <div class="card">
    <p class="card__title">3 · Benchmark your own model</p>
    <p class="card__body">Which tool for which model shape, what to set, what to
      never set, and how to read the per-operation breakdown.</p>
  </div>
  <div class="card">
    <p class="card__title">4 · Bring your own ONNX model</p>
    <p class="card__body">Find out which parts of your graph hip-ep claimed,
      which it did not, and what to do about the gap.</p>
  </div>
  <div class="card">
    <p class="card__title">5 · Look inside the compiler</p>
    <p class="card__body">Dump the MLIR at every stage, inspect the compiled
      artifact's ABI, and run the pipeline by hand without ONNX Runtime.</p>
  </div>
</div>

## Reading order

| If you want to | Read |
|---|---|
| Generate text from an LLM | [Run an LLM with GenAI]({{ '/docs/tutorials/genai-llm/' | relative_url }}) |
| Explain why hip-ep "is not faster than CPU" | [Prove the GPU ran it]({{ '/docs/tutorials/verify-gpu/' | relative_url }}) |
| Produce numbers you can defend | [Benchmark your own model]({{ '/docs/tutorials/benchmark/' | relative_url }}) |
| Run a model that is not on the official list | [Bring your own ONNX model]({{ '/docs/tutorials/bring-your-own-model/' | relative_url }}) |
| Debug a compilation failure, or just understand the pipeline | [Look inside the compiler]({{ '/docs/tutorials/inside-the-compiler/' | relative_url }}) |

If you are here because something is slow, start with tutorial 2 before
tutorial 3. Benchmarking a CPU fallback is the most common way to waste an
afternoon with this project.

<div class="note note--warn" markdown="1">
**These pages have not been executed end to end on hardware yet.** Every command,
flag and environment variable below was read out of the hip-ep source tree rather
than invented, and corrections found while dry-running the
[Windows Quick Start]({{ '/docs/quickstart/windows/' | relative_url }}) on a
Ryzen AI Max have been applied here — but the tutorials themselves are still
pending a run of their own. If a command does not behave as described, that is a
documentation bug — please
[open an issue]({{ site.repo_url }}/issues).
</div>
