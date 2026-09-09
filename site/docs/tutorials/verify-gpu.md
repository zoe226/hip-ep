---
title: Prove the GPU actually ran it
description: ONNX Runtime falls back to the CPU silently and returns correct answers. Three ways to catch it.
---

Nearly every "hip-ep is no faster than the CPU" report turns out to be a run
that never touched the GPU.

This is not a bug in ONNX Runtime — silent fallback is a feature. An execution
provider declares which parts of a graph it can handle, and ORT places whatever
is left on the CPU. If hip-ep declares nothing, or fails while compiling what it
declared, ORT runs the whole graph on the CPU and returns **numerically correct
results**. Nothing in the output distinguishes that from a successful GPU run.

So you have to check on purpose. Here are three independent checks, cheapest
first, plus the environment variable whose behaviour does not match its name.

## Check 1 — Make compilation failures fatal

```bash
HIPDNN_EP_STRICT=1 hip-onnx-runner -m your_model.onnx
```

```powershell
$env:HIPDNN_EP_STRICT = "1"
& "$env:HIPEP_ROOT\bin\hip-onnx-runner.exe" -m your_model.onnx
Remove-Item Env:\HIPDNN_EP_STRICT
```

If the same command succeeds without `HIPDNN_EP_STRICT` and fails with it, the
successful run was on the CPU, and the error you now see is the real one that
was being swallowed.

**What it actually does:** when the MLIR pass pipeline fails to compile a graph
hip-ep has claimed, the default behaviour is to return failure quietly and let
ORT fall back. With the variable set, the process calls `abort()` instead, and
the crash handler prints a backtrace pointing at the failing pass.

<div class="note note--warn" markdown="1">
**`HIPDNN_EP_STRICT=0` does not turn strict mode off — it turns it on.**

The check is whether the variable is *set to anything at all*, not whether its
value is `1`
([`lib/Compiler/CompilerDriver.cpp`]({{ site.repo_url }}/blob/main/lib/Compiler/CompilerDriver.cpp)).
`0`, `false` and `no` are all non-empty, so all three enable it.

To disable strict mode you must **unset** the variable:

```bash
unset HIPDNN_EP_STRICT                  # Linux / macOS
```
```powershell
Remove-Item Env:\HIPDNN_EP_STRICT       # Windows PowerShell
```

Note that this is *not* how `HIPDNN_EP_DEBUG` behaves — that one does parse its
value, so `HIPDNN_EP_DEBUG=0` really does disable it. The two variables do not
follow the same rule.
</div>

### What this check does not cover

Strict mode fires on one specific failure: the pass pipeline erroring out on a
graph hip-ep already claimed. It is silent when

- the EP library never loaded, so hip-ep was never consulted;
- hip-ep loaded but claimed no nodes, so there was nothing to compile;
- part of the graph was claimed and the rest was placed on CPU by design.

A clean run under `HIPDNN_EP_STRICT=1` therefore means "nothing hip-ep tried to
compile blew up". It does not by itself mean "the GPU did the work". That is
what checks 2 and 3 are for.

## Check 2 — Refuse CPU fallback at the session level

This is an ONNX Runtime session option rather than a hip-ep variable, and it
closes a different hole: it makes ORT itself error out rather than silently
placing nodes on the CPU EP.

`hip-onnx-runner` already sets it for you — whenever it registers the EP it adds
`session.disable_cpu_ep_fallback=1` unconditionally — so a plain
`hip-onnx-runner -m your_model.onnx` that creates a session has already passed
this check. Other harnesses do not, so set it explicitly:

```bash
onnxruntime_perf_test \
  --plugin_ep_libs "hipgpu|$ROOT/lib/libhipgpu.so" \
  --plugin_eps     "hipgpu" \
  -C "session.disable_cpu_ep_fallback|1" \
  -t 30 -c 1 -s -I \
  your_model.onnx
```

If session creation now fails, some part of your graph was going to the CPU. The
error names what could not be placed, which is the starting point for
[Bring your own ONNX model]({{ '/docs/tutorials/bring-your-own-model/' | relative_url }}).

Use both this and check 1. They catch different things: `disable_cpu_ep_fallback`
catches *unclaimed* nodes, `HIPDNN_EP_STRICT` catches *claimed-then-failed* ones.

## Check 3 — Compare EP output against CPU output

The strongest positive evidence, and the only one that confirms the GPU produced
the numbers rather than merely being present.

```bash
hip-onnx-runner -m your_model.onnx -d 2        # EP  outputs -> your_model_o_dump/
hip-onnx-runner -m your_model.onnx -d 2 -n     # CPU outputs -> ..._o_dump/ (rename first)
hip-onnx-runner -L ep_o_dump,cpu_o_dump        # element-wise L2 norm
```

`-n` skips EP registration entirely, so the second run is a genuine CPU
reference. Rename or move the first dump directory before the second run, or the
second will overwrite it.

Expected: a **small but non-zero** L2 norm.

<div class="note note--warn" markdown="1">
**An L2 norm of exactly zero is a red flag, not a success.** The GPU path uses
different kernels and a different accumulation order than the CPU reference, so
bit-identical output is not expected. Exact equality usually means you compared
a CPU fallback against the CPU — the classic version of this failure is an
accuracy test reporting a perfect cosine similarity of 1.0 because both sides
ran on the CPU.
</div>

Related flags on `hip-onnx-runner`:

| Flag | Effect |
|---|---|
| `-d 1` / `-d 2` / `-d 3` | Dump inputs / outputs / both |
| `-n`, `--no-ep` | CPU only; skip EP registration |
| `-i <dir>` | Load fixed inputs from `input_<idx>_<name>_<type>.bin` instead of generating random ones |
| `-s <n>` | RNG seed for random inputs (default 42) |
| `-L dir1,dir2` | Compare two dump directories; no `-m` needed |

Use `-i` or a fixed `-s` when comparing runs. Two runs with different random
inputs are not comparable, and the seed defaults to 42 precisely so that
back-to-back runs match.

## Check 4 — Watch the EP decide

When the checks above disagree, or you want to see the partitioning directly,
turn on the EP's own logging:

```bash
MORPHIZEN_DEBUG_MORPHIZEN_EP=1 hip-onnx-runner -m your_model.onnx
```

Level `1` logs each `GetCapability` call — the point at which hip-ep tells ORT
which nodes it wants — including the graph name and whether it is a subgraph.
Level `2` adds provider-option and session-config detail.

Two things in that output are easy to misread:

- **`is_subgraph=1` followed by "Skip GetCapability for subgraph"** is normal.
  The bodies of `Loop`, `If` and `Scan` are claimed through their parent node at
  the top level, not separately. Seeing hip-ep decline a subgraph does not mean
  the subgraph runs on the CPU.
- **"Failed to compile ONNX model to MorphiZen EP"** means hip-ep claimed
  nothing at all. Everything runs on the CPU from here. This is the message to
  grep for.

## Putting it together

A run you can defend has all of:

1. `HIPDNN_EP_STRICT=1` set, and the run completed;
2. `session.disable_cpu_ep_fallback|1` set, and the session was created;
3. EP-vs-CPU L2 norm small and non-zero;
4. no "Failed to compile ONNX model" in the EP log.

Then, and only then, is a timing number worth recording. Take it to
[Benchmark your own model]({{ '/docs/tutorials/benchmark/' | relative_url }}) —
and drop all four of these variables first, because several of them change what
you would be measuring.

## Next

- [Benchmark your own model]({{ '/docs/tutorials/benchmark/' | relative_url }})
- [Bring your own ONNX model]({{ '/docs/tutorials/bring-your-own-model/' | relative_url }}) if check 2 or 4 says parts of your graph were not claimed.
