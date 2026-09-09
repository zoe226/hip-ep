---
title: Look inside the compiler
description: Dump the MLIR at every stage, inspect the compiled artifact, and run the pipeline by hand.
---

hip-ep is a compiler wearing an execution provider's clothes. When a graph fails
to compile — or compiles into something slower than you expected — the useful
question is *what did the pipeline do to it*, and that is answerable.

**Prerequisite:** a working install. Nothing here needs a source build, though
some of it is more pleasant with one.

## What actually happens on that first slow inference

1. ONNX Runtime hands hip-ep a set of nodes it claimed in `GetCapability`.
2. Those nodes are converted into MLIR, in an `onnx` dialect representation.
3. A pass pipeline lowers `onnx` → the **`hip` dialect** → LLVM IR.
4. The result is serialized as an artifact.
5. The artifact is loaded and its entry point is called for every inference
   after that.

Step 4's default output is **OS-portable LLVM bitcode** (`.bc`), JIT-loaded
in-process together with embedded runtime bitcode. A per-OS native `.dll`/`.so`
is an opt-in alternative. Either way the generated entry point is the same:

```text
inference_compute(state, inputs)
```

Graph outputs are allocated inside the generated code through `hip.alloc_output`
and the EP's output-allocation callback, rather than being passed in
pre-allocated. That is why the ABI takes inputs but not outputs.

## Dump the MLIR

The one-flag version, which sets up the environment for you before the EP loads:

```bash
hip-onnx-runner -m your_model.onnx --dump-compiler-mlir
```

It prints where it is writing. By default that is
`$WORKSPACE/temp/mlir-dumps/<model-stem>/`, falling back to
`./temp/mlir-dumps/<model-stem>/` when `WORKSPACE` is unset. Override it:

```bash
hip-onnx-runner -m your_model.onnx \
  --dump-compiler-mlir \
  --mlir-dump-dir /tmp/my-dumps
```

You get two kinds of file:

| File | Content |
|---|---|
| `mlir_bytecode_dump.mlir` | The IR **as handed to the compiler** — the input to everything below |
| `morphizen.*.mlir` | Per-pass snapshots through the pipeline |

`mlir_bytecode_dump.mlir` is the one to read first. If your operator is missing
or mis-shaped there, the problem is in conversion, before any lowering ran.

<div class="note" markdown="1">
`--dump-compiler-mlir` works by setting `MORPHIZEN_DEBUG_MLIR_BACKEND=2`,
`MORPHIZEN_SAVE_MLIR_AS_TEXT=1`, `ENABLE_SAVE_GRAPH_MLIR=1` and
`HIP_EP_VERBOSE=2` *before* the EP library loads. That ordering matters: the EP
reads many of its debug variables once at library initialization, so exporting
them after the process has started has no effect. Setting them by hand works
too, as long as you set them before the EP is registered.
</div>

## Dump the pass pipeline itself

The dumps above come from the MorphiZen layer. To watch the MLIR pass manager,
use the compiler driver's own IR printing:

```bash
HIPDNN_EP_IR_DUMP_PATH=/tmp/ir.mlir hip-onnx-runner -m your_model.onnx
```

ORT can invoke the compiler several times per session — shape subgraphs, prefill
specialization, decode specialization — so each compile gets its own numbered
file: `/tmp/ir.0.mlir`, `/tmp/ir.1.mlir`, and so on. That numbering is what lets
you diff prefill against decode.

Four companion variables shape the output:

| Variable | Effect |
|---|---|
| `HIPDNN_EP_IR_DUMP_TREE` | One file per pass, under the dump path as a **directory**: `<idx>_<pass-name>.mlir`. Usually under 1 MB each, versus a multi-megabyte monolith. Start here. |
| `HIPDNN_EP_IR_DUMP_AFTER_ONLY` | Suppress the "before" dump for each pass. Roughly halves the size while keeping every change visible. |
| `HIPDNN_EP_IR_DUMP_SINGLE` | Restore legacy single-file behavior — no counter, overwritten each compile. |
| `HIPDNN_EP_PIPELINE` | Override the pass pipeline entirely. |

Tree mode disables multithreading in the MLIR context so the files come out in a
deterministic order. Expect the compile to be slower; that is the trade.

<div class="note note--warn" markdown="1">
**These are presence flags, not value flags.** The code checks whether the
variable is set to anything at all, so `HIPDNN_EP_IR_DUMP_TREE=0` enables tree
mode. To turn one off, `unset` it. The same convention governs
`HIPDNN_EP_STRICT` — see
[Prove the GPU ran it]({{ '/docs/tutorials/verify-gpu/' | relative_url }}).

The notable exception is `HIPDNN_EP_DEBUG`, which *does* parse its value, so
`HIPDNN_EP_DEBUG=0` really does disable it. Do not generalize from that one.
</div>

`HIPDNN_EP_PIPELINE` is for compiler work rather than debugging a model. A custom
pipeline that drops the pass emitting the C-ABI entry point produces a module the
rest of the EP cannot load, so the driver checks for `inference_compute` after an
overridden pipeline runs and fails loudly rather than later with a missing-symbol
error. The built-in pipeline always emits it; the pass menu is documented in
[`docs/pipeline_pass_menu.md`]({{ site.repo_url }}/blob/main/docs/pipeline_pass_menu.md).

## Inspect a compiled artifact

`hip-inspect` reads the metadata out of a compiled model and prints its inputs,
outputs and constants:

```bash
hip-inspect model.bc
hip-inspect model.bc --json     # raw metadata JSON
```

It accepts both artifact formats — LLVM bitcode (`.bc`) and native `.dll`/`.so`.

The bitcode path is the useful one for triage: it parses the `@__metadata_json`
global directly out of the module, so it needs **no ROCm, no GPU and no JIT**. You
can copy a `.bc` off a test machine and inspect it anywhere. The native path
loads the artifact as a plugin and calls into it, so it needs a working runtime.

Use it to answer "did the compiler produce the interface I expected" — wrong
shapes, an unexpected input count or missing constants show up here before you
spend time on the runtime.

## Run the pipeline by hand

With MLIR in hand you can skip ONNX Runtime entirely:

```bash
hip-compiler input.mlir -o output.bc                  # default: LLVM_IR
hip-compiler input.mlir -o output.so --mode NATIVE    # native artifact
```

Feed it `mlir_bytecode_dump.mlir` from the dump above and you have a
reproducible, single-process compile of exactly what the EP was compiling — no
session, no ORT, no partitioning. That is usually the shortest path to a bug
report someone else can act on.

`hip-mlir-opt` runs individual passes or custom pipelines over the same IR, in
the style of the upstream `mlir-opt`. Between the two, a compilation failure can
be narrowed to a single pass.

## Choosing the artifact format at run time

The default is bitcode. To switch:

```bash
HIPDNN_EP_ARTIFACT_FORMAT=<format> hip-onnx-runner -m your_model.onnx
```

`hip-onnx-runner` forwards that value to the EP as the `artifact_format`
provider option. Native artifacts link a per-OS shared library at producer time
and load it through the plugin path; bitcode is JIT-loaded in-process. The
comparison lives in
[`docs/native-vs-ir-comparison.md`]({{ site.repo_url }}/blob/main/docs/native-vs-ir-comparison.md).

Unless you have a specific reason, stay on the default. Bitcode is what the
official models are validated with.

## When compilation fails

Work in this order:

1. `HIPDNN_EP_STRICT=1` — make the failure loud instead of a silent CPU
   fallback, and get a backtrace naming the failing pass.
2. `HIPDNN_EP_IR_DUMP_TREE=1 HIPDNN_EP_IR_DUMP_PATH=/tmp/ir` — find the last
   pass that produced sane IR.
3. `hip-compiler` on the dumped input — reproduce it without ONNX Runtime in
   the picture.
4. Report it with the failing pass name, the input MLIR, and the operator
   involved.

Step 3 is what makes the report actionable. A `.mlir` file and a one-line
`hip-compiler` command is something a compiler engineer can run in seconds; "my
model fails" is not.

## Next

- [Bring your own ONNX model]({{ '/docs/tutorials/bring-your-own-model/' | relative_url }}) if the graph is not being claimed in the first place.
- [Benchmark your own model]({{ '/docs/tutorials/benchmark/' | relative_url }}) once it compiles and you want to know where the time goes.
