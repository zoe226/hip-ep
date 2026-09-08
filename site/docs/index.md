---
title: Overview
description: What hip-ep is, how it executes an ONNX graph on an AMD GPU, and which page to read next.
---

hip-ep is an **ONNX Runtime Execution Provider (EP)** for AMD GPUs. You do not
run models *on* hip-ep the way you would run them on a standalone inference
server — you register it with ONNX Runtime, and ONNX Runtime hands it the parts
of your graph it can execute.

That distinction shapes everything else on this site: if you already have an
application that calls ONNX Runtime, adopting hip-ep is a deployment change
rather than a rewrite.

## How a graph gets executed

hip-ep is a compiler, not an operator library. When ONNX Runtime assigns a
subgraph to it, hip-ep lowers that subgraph through an MLIR pipeline and
produces machine code for your specific GPU:

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

## Two things that will bite you

These are the two failure modes that account for most confusing first
experiences, so they are stated once here rather than buried.

<div class="note note--warn" markdown="1">
**A build must target the architecture of the GPU that will run it.** A
mismatched architecture builds and installs cleanly and then fails at the moment
a kernel launches. The build auto-detects the local GPU; if you build on one
machine and run on another, set the target explicitly.
</div>

<div class="note note--warn" markdown="1">
**Correct numerical output is not proof that the GPU ran anything.** If hip-ep
fails to compile a subgraph, ONNX Runtime silently falls back to the CPU EP and
the results are still right — just slow. Set `HIPDNN_EP_STRICT=1` when you need
compilation failures to be loud.
</div>

## Supported hardware

The published release assets are the authoritative statement of what ships. The
table below is a reading of the `{{ site.hip_ep_version }}` packages, and the
two platforms do not cover the same set of GPUs.

| GPU | Architecture | Linux package | Windows package |
|---|---|---|---|
| Ryzen AI Max ("Strix Halo") | `gfx1151` | Yes | Yes |
| Ryzen AI ("Strix Point") | `gfx1150` | Source build | Yes |
| Ryzen AI ("Krackan Point") | `gfx1152` | Source build | Yes |
| Instinct MI350X | `gfx950` | Source build | — |

The Windows package carries the GPU kernels for all three RDNA 3.5 parts in one
download, which is why it has no architecture suffix. The Linux package is
built for `gfx1151` only.

<div class="note" markdown="1">
**Tuned-library coverage is narrower than kernel coverage.** The Windows package
ships hipBLASLt and rocBLAS tuning data for `gfx1151` only. `gfx1150` and
`gfx1152` run, but GEMM-heavy models on those parts are not running against
tuning data selected for them, so treat their performance as uncharacterised
rather than representative.
</div>

Anything not listed is a source build away, not a supported configuration.
`build.py` accepts `--hip_arch <gfx-arch>` for any architecture the underlying
ROCm toolchain supports, but only the rows above are validated.

## What ROCm you need

This differs by platform, and getting it wrong is the most common reason a first
run fails.

- **Windows — nothing to install.** The package is self-contained: alongside the
  EP it bundles the HIP runtime (`amdhip64_7.dll`), the code-object manager, the
  HIP RTC libraries, hipBLASLt, rocBLAS and MIOpen. You need a current AMD
  Adrenalin driver and nothing else.
- **Linux — install ROCm yourself.** The package bundles the EP, the ONNX
  Runtime and OGA runtimes, and a `clang`/`lld` toolchain for the per-model link
  step, but no ROCm. You supply the HIP runtime and point `THEROCK_DIST` at it.

The [Quick Start]({{ '/docs/quickstart/' | relative_url }}) walks through each
platform in order.

## Version pinning

hip-ep is pinned to exact upstream versions. Mixing in a different ONNX Runtime
is not a supported configuration — the EP is loaded as a plugin against a
specific ABI.

| Component | Version |
|---|---|
| hip-ep | `{{ site.hip_ep_version }}` |
| ONNX Runtime | 1.27.0 |
| ONNX Runtime GenAI (OGA) | 0.14.0, plus [PR 2194](https://github.com/microsoft/onnxruntime-genai/pull/2194) |

The full dependency set — LLVM/MLIR/LLD, protobuf, flatbuffers, ONNX Runtime,
TheRock ROCm — is pinned in [`cmake/deps.txt`]({{ site.repo_url }}/blob/main/cmake/deps.txt),
which is the single source of truth if this table and the repository ever
disagree.

## Where to go next

<div class="card-grid" markdown="0">
  <div class="card">
    <p class="card__title">Just want to run a model</p>
    <p class="card__body">Download a release package and run your first
      inference. No compiler required.</p>
  </div>
  <div class="card">
    <p class="card__title">Want to change the compiler</p>
    <p class="card__body">Build from source. Budget several hours for the first
      build — LLVM is built from source.</p>
  </div>
</div>

- [Quick Start]({{ '/docs/quickstart/' | relative_url }}) — pick your platform and get one model running.
- [Build from Source]({{ '/docs/quickstart/build/' | relative_url }}) — the developer path.
- [Supported operations]({{ site.repo_url }}/blob/main/docs/supported-operations.md) — which ONNX ops the compiler handles today.
- [Design documentation]({{ site.repo_url }}/tree/main/docs/design) — pass ordering, the compiler/runtime ABI, memory planning.
