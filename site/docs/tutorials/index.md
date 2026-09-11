---
title: Tutorials
description: Three end-to-end walkthroughs on Windows — one per way of installing hip-ep.
---

The [Quick Start]({{ '/docs/quickstart/' | relative_url }}) ends the moment one
ONNX graph runs on the GPU. That is the smallest possible proof that the
installation works, and it is deliberately not useful for anything else.

These three pages pick up from there. Each covers one way of getting hip-ep onto
a Windows machine and everything that follows from it: what the install actually
gives you, how to run a plain ONNX graph, an LLM and a vision-language model
against it, how to point a model at the provider, and how to confirm the GPU ran
it rather than the CPU. Read the one that matches how you installed — they are
independent, and none of them is a prerequisite for another.

<div class="card-grid card-grid--fill" markdown="0">
  <div class="card">
    <p class="card__title">1 · C++ package</p>
    <p class="card__body">Extract the release zip, put <code>bin</code> on
      <code>PATH</code>, run. Everything the binaries need ships inside the
      archive — no Python, no Visual Studio, nothing to place by hand.</p>
  </div>
  <div class="card">
    <p class="card__title">2 · Python package</p>
    <p class="card__body">Four wheels into a Python 3.14 environment, in an order
      that matters. For when you want to write the generation loop yourself
      rather than read numbers off a benchmark.</p>
  </div>
  <div class="card">
    <p class="card__title">3 · Source build</p>
    <p class="card__body">The same provider, none of the convenience. What a
      build tree does not wire up for you, and how to run models against it once
      you have.</p>
  </div>
</div>

## Which one

| If you want to | Read |
|---|---|
| Run the shipped models and benchmark them, with the least setup | [Run models with the C++ package]({{ '/docs/tutorials/cpp-package/' | relative_url }}) |
| Drive ONNX Runtime and OGA from your own Python code | [Run models from Python]({{ '/docs/tutorials/python-package/' | relative_url }}) |
| Change the compiler, or target a GPU no package covers | [Run models from a source build]({{ '/docs/tutorials/source-build/' | relative_url }}) |

All three are Windows. For Linux, the
[Linux Quick Start]({{ '/docs/quickstart/linux/' | relative_url }}) and the
[build page]({{ '/docs/quickstart/build/' | relative_url }}) cover the
equivalent ground.

<div class="note" markdown="1">
**Every page ends with the same section, and it is the one to read first if
something looks wrong.** ONNX Runtime does not fail when a provider cannot take
a graph — it runs that part on the CPU and returns correct answers. A model that
never reached the GPU therefore looks exactly like one that did, only slower.
Benchmarking a CPU fallback is the most common way to waste an afternoon with
this project.
</div>

<div class="note note--warn" markdown="1">
**These pages have not been executed end to end on hardware yet.** Every command,
flag and environment variable was read out of the hip-ep source tree, its CI
workflows and the release artifacts rather than invented, and corrections found
while dry-running the
[Windows Quick Start]({{ '/docs/quickstart/windows/' | relative_url }}) on a
Ryzen AI Max have been applied here — but the tutorials themselves are still
pending a run of their own. If a command does not behave as described, that is a
documentation bug — please
[open an issue]({{ site.repo_url }}/issues).
</div>
