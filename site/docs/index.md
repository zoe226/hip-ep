---
title: Overview
description: What hip-ep is, how it executes an ONNX graph on an AMD GPU, and which page to read next.
---

hip-ep is an **ONNX Runtime Execution Provider (EP)** for AMD GPUs. It is not a
standalone inference server and it has no API of its own. You register it with
ONNX Runtime, and ONNX Runtime hands it whichever parts of your graph it can
execute.

That distinction shapes everything else on this site: if you already have an
application that calls ONNX Runtime, adopting hip-ep is a deployment change
rather than a rewrite.

## How a graph gets executed

hip-ep is an LLM inference backend, not an operator library. When ONNX Runtime
assigns a subgraph to it, hip-ep lowers that subgraph through an MLIR pipeline
and produces machine code for your specific GPU:

1. **ONNX → HIP dialect.** The ONNX operations are converted into a custom MLIR
   `hip` dialect that models GPU memory, kernels and library calls explicitly.
2. **HIP dialect → LLVM IR.** Shape inference, memory planning and buffer
   pooling run here, then the dialect is lowered to LLVM IR.
3. **Execution.** The generated code dispatches to
   [hipDNN](https://github.com/ROCm/hipDNN), [hipBLASLt](https://github.com/ROCm/hipBLASLt)
   and hand-written HIP kernels shipped with the EP.

The default per-model artifact is **OS-portable LLVM bitcode**, JIT-loaded
in-process by the EP together with the embedded runtime bitcode. Native
`.dll`/`.so` model artifacts are an opt-in mode.

The practical consequence: **the first inference of a model is slow** — that is
the compile — and every inference after it is not. Any benchmark that does not
warm up is measuring the compiler, not the GPU.

## Supported hardware

The table below is what the `{{ site.hip_ep_version }}` packages actually
contain, checked by unpacking them.

| GPU | Architecture |
|---|---|
| Ryzen AI Max ("Strix Halo") | `gfx1151` |
| Ryzen AI ("Strix Point") | `gfx1150` |
| Ryzen AI ("Krackan Point") | `gfx1152` |

The Windows package carries the GPU kernels for all three RDNA 3.5 parts in one
download, which is why it has no architecture suffix.

## Version pinning

hip-ep is pinned to exact upstream versions. Mixing in a different ONNX Runtime
is not a supported configuration — the EP is loaded as a plugin against a
specific ABI.

| Component | Version |
|---|---|
| hip-ep | `{{ site.hip_ep_version }}` |
| ONNX Runtime | `1.27.0` |
| ONNX Runtime GenAI (OGA) | `0.14.0` |

The full dependency set — LLVM/MLIR/LLD, protobuf, flatbuffers, ONNX Runtime,
TheRock ROCm — is pinned in [`cmake/deps.txt`]({{ site.repo_url }}/blob/main/cmake/deps.txt),
which is the single source of truth if this table and the repository ever
disagree.

## Where to go next

<div class="card-grid" markdown="0">
  <a class="card card--link" href="{{ '/docs/get-started/cpp-package/' | relative_url }}">
    <p class="card__title">Just want to run a model</p>
    <p class="card__body">The C++ package. Extract a release archive, put
      <code>bin</code> on <code>PATH</code>, get one inference on the GPU. No
      compiler required.</p>
  </a>
  <a class="card card--link" href="{{ '/docs/get-started/python-package/' | relative_url }}">
    <p class="card__title">Want to drive it yourself</p>
    <p class="card__body">The Python package. Serve an LLM, prove the GPU really
      ran it, benchmark honestly, and bring a model of your own.</p>
  </a>
  <a class="card card--link" href="{{ '/docs/get-started/source-build/' | relative_url }}">
    <p class="card__title">Want to change the compiler</p>
    <p class="card__body">Build from source. Budget several hours for the first
      build — LLVM is compiled along with it.</p>
  </a>
</div>

Also worth knowing:
[Official models]({{ '/docs/models/' | relative_url }}) and
[Benchmarks]({{ '/docs/benchmarks/' | relative_url }}) cover what is validated
each release and how fast it runs;
[supported operations]({{ site.repo_url }}/blob/main/docs/supported-operations.md)
lists which ONNX operations the compiler handles today; and the
[design documentation]({{ site.repo_url }}/tree/main/docs/design) covers pass
ordering, the compiler/runtime ABI and memory planning.
