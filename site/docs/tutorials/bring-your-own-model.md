---
title: Bring your own ONNX model
description: Find out which parts of your graph hip-ep claimed, which it did not, and what to do about the gap.
---

The [official models]({{ '/docs/models/' | relative_url }}) are validated every
release. Your model is not on that list, which does not mean it will not work —
it means nobody has checked, so you get to.

This page is about the one question that decides everything else: **which nodes
of your graph did hip-ep actually take?**

## How a graph gets divided

Execution providers do not take or reject a model as a whole. ONNX Runtime walks
the graph and asks each provider, in priority order, which nodes it can handle.
hip-ep answers in `GetCapability`, returning groups of nodes it wants fused into
single compiled units. Whatever no provider claims runs on the CPU.

Three outcomes, and they behave very differently:

| Outcome | What you see | What to do |
|---|---|---|
| Everything claimed | Fast, one compiled artifact | Nothing |
| Nothing claimed | CPU speed, no errors, no warnings | Find the blocking operator — below |
| Partly claimed | Somewhere in between, often much worse than either | Usually the interesting case |

The partial case deserves attention. Splitting a graph between the GPU and the
CPU means tensors crossing the PCIe boundary at every seam. A model that is 90 %
claimed can be *slower* than one that is 0 % claimed, because the 10 % sits in
the middle of the hot path and forces a round trip per inference.

## Step 1 — Find out what happened

`hip-onnx-runner` already sets `session.disable_cpu_ep_fallback=1` whenever it
registers the EP, so a plain run is a partitioning test:

```bash
hip-onnx-runner -m your_model.onnx
```

If the session fails to create, something in your graph was not claimed, and the
error names it. If it runs, the whole graph was claimed.

For detail, turn on the EP's own log:

```bash
MORPHIZEN_DEBUG_MORPHIZEN_EP=1 hip-onnx-runner -m your_model.onnx
```

Read it for two things:

- **"Failed to compile ONNX model to MorphiZen EP"** — hip-ep claimed nothing.
  Go to step 2.
- **"Skip GetCapability for subgraph"** — expected and harmless. The bodies of
  `Loop`, `If` and `Scan` are claimed through their parent node at the top
  level; hip-ep declining them individually is by design, not a fallback.

## Step 2 — Find the operator that blocked it

Start from the reference table:
[`docs/supported-operations.md`]({{ site.repo_url }}/blob/main/docs/supported-operations.md)
in the repository lists the ONNX operations the built-in pipeline handles and how
each is backed — a vendor library, a custom HIP kernel, a decomposition, or a
standard MLIR transformation.

<div class="note" markdown="1">
That table is a summary, and the page says so itself: the conversion
registrations in `lib/Conversion/OnnxToHip/OnnxToHip.cpp` and the LIT/numeric
tests are the source of truth. An operation can be listed and still be
unsupported *for your case* — restrictions on data type, rank, attribute values
and dynamic shapes are documented in each operation's conversion and test files,
not in the summary table.
</div>

So "my operator is in the table and it still did not work" is a normal outcome,
and the usual causes are:

- **an unsupported data type** — the kernel exists for f32 and f16, your graph is
  bf16 or int8;
- **an unsupported rank** — the kernel handles 4-D, your tensor is 5-D;
- **an attribute combination** nothing has been written for — an unusual
  dilation, a padding mode, a non-default axis;
- **a dynamic shape** where the conversion needs a static one.

To enumerate the operators in your model without any hip-ep involvement:

```python
import onnx, collections
m = onnx.load("your_model.onnx")
print(collections.Counter(n.op_type for n in m.graph.node).most_common())
```

Cross-reference the result against the table. Anything unlisted is a candidate.

## Step 3 — Rule out the easy explanations

Several things that look like unsupported operators are not.

**Graph optimization level.** ORT rewrites the graph before the EP sees it, and
the level changes which operators actually reach hip-ep. If your results differ
between tools, this is often why:

```bash
hip-onnx-runner -m your_model.onnx -o 0    # ORT_DISABLE_ALL
hip-onnx-runner -m your_model.onnx -o 99   # ORT_ENABLE_ALL
```

`-1` (the default) leaves ORT's own default in place. Disabling optimization is
a diagnostic, not a fix — a graph that only works at `-o 0` has an underlying
problem worth reporting.

**Symbolic dimensions defaulting to 1.** If your model has free dimensions like
`batch_size` or `sequence_length`, `hip-onnx-runner` sizes them to **1** unless
told otherwise. A model that "works" at sequence length 1 and fails at 512 was
never tested at 512:

```bash
hip-onnx-runner -m your_model.onnx -f sequence_length:512 -f batch_size:1
```

`--free-dim` is repeatable and also accepts a comma-separated list. Note what it
deliberately does *not* do: it does not substitute the dimension into the graph
before the EP sees it. hip-ep still compiles the dynamic, symbolic graph; the
value only sizes the input tensors at run time. That is the behavior you want
when testing, because it matches what a real dynamic-shape deployment does.

**Wrong GPU architecture.** A package or build targeting a different
architecture can load, claim nodes, compile, and fail only when a kernel
launches. Confirm your architecture matches what you installed — the Quick Start
pages open with that check for this reason.

## Step 4 — Decide what to do

**If a small number of operators are the problem**, the cheapest fix is usually
in the export rather than in hip-ep: a different opset version, a different
decomposition, or replacing an exotic operator with an equivalent composition of
supported ones. Re-export and re-run step 1.

**If the operator is genuinely missing**, that is a feature request. Open an
issue with the operator name, its attributes, the data types and ranks involved,
and ideally a minimal `.onnx` reproducing it — that last part is what turns an
issue into a fix.

**If your model is claimed but slow**, the problem is not partitioning. Go to
[Benchmark your own model]({{ '/docs/tutorials/benchmark/' | relative_url }})
and get the per-operation breakdown before guessing.

## A note on quantized models

hip-ep consumes the standard ONNX weight-only quantized representation —
`MatMulNBits` with 4-bit weights grouped along the input dimension. It does not
quantize anything for you. Bring an fp16 model and it runs in fp16, with the
memory footprint that implies. See
[the Models page]({{ '/docs/models/' | relative_url }}) for what the official
matrix uses.

## Next

- [Look inside the compiler]({{ '/docs/tutorials/inside-the-compiler/' | relative_url }}) to see exactly where a claimed graph fails to compile.
- [Prove the GPU ran it]({{ '/docs/tutorials/verify-gpu/' | relative_url }}) if you are not yet sure the answer is coming from the GPU at all.
