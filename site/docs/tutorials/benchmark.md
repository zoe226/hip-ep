---
title: Benchmark your own model
description: Which tool for which model, what to set, what never to set, and how to read the per-operation breakdown.
---

Benchmarking hip-ep is easy to do and easy to do wrong. The wrong version
produces plausible numbers, which is why it survives review.

**Prerequisite:** everything in
[Prove the GPU ran it]({{ '/docs/tutorials/verify-gpu/' | relative_url }}). A
benchmark of a CPU fallback is worse than no benchmark, because it looks like
data.

## Pick the right tool

| Your model | Tool | Reports |
|---|---|---|
| A single graph — vision, embedding, encoder, one forward pass | `onnxruntime_perf_test` | Steady-state per-inference latency |
| A generative LLM driven by OGA | `model_benchmark` | Prefill and decode separately, plus sampling and end-to-end |
| A multimodal / VLM pipeline | `model_mm` | Image + prompt through the full pipeline |

The distinction matters more than it looks. Running `onnxruntime_perf_test`
against a decoder graph measures one decode step in isolation, with no KV cache
growth and no prefill — a number that is real but answers a question nobody
asked.

`onnxruntime_perf_test` and `model_benchmark` both ship in the release package.
`model_mm` is an OGA C++ example that is present in a source build's
`install/bin/`; check whether your package includes it before planning around
it.

## Rules that decide whether the number means anything

These come from the project's own benchmarking policy, and each one exists
because ignoring it produced a wrong answer that someone believed.

<div class="note note--warn" markdown="1">
- **Run GPU benchmarks serially.** Two benchmarks sharing a GPU invalidate both.
  Not "add noise" — invalidate.
- **Never measure throughput with `HIPDNN_EP_PERF=1` or `HIPDNN_EP_DEBUG=1`.**
  Both add per-operation instrumentation. Numbers collected with either set are
  not comparable to numbers collected without, or to each other.
- **Unset `HIPDNN_EP_STRICT` before measuring.** Use it to validate the run, then
  drop it. And remember that setting it to `0` does *not* unset it — see the
  [previous tutorial]({{ '/docs/tutorials/verify-gpu/' | relative_url }}).
- **Exclude the first inference.** It includes compiling the graph. Use warm-up
  runs, or a `-t` window long enough that a one-off compile is noise.
- **Prime the kernel autotune cache** after rebuilding custom kernels. A cold
  autotune cache measures the tuner, not the kernel.
- **Account for thermal drift.** On a compute-bound workload in a thin chassis,
  back-to-back runs drift downward. That is the machine, not the release.
</div>

## Single graph: `onnxruntime_perf_test`

```bash
onnxruntime_perf_test \
  --plugin_ep_libs "hipgpu|$ROOT/lib/libhipgpu.so" \
  --plugin_eps     "hipgpu" \
  -C "session.disable_cpu_ep_fallback|1" \
  -t 60 -c 1 -s -I \
  your_model.onnx
```

```powershell
.\onnxruntime_perf_test.exe `
  --plugin_ep_libs "hipgpu|hipgpu.dll" `
  --plugin_eps "hipgpu" `
  -C "session.disable_cpu_ep_fallback|1" `
  -t 60 -c 1 -s -I `
  "path\to\your_model.onnx"
```

`-t 60` runs for sixty seconds, which is the point: it gives the one-off compile
time somewhere to disappear. A three-second run on a model that took two seconds
to compile is measuring the compiler.

`-c 1` keeps requests serial. Leave it at 1 — see the rules above. Run
`onnxruntime_perf_test --help` for the full flag list; it belongs to ONNX
Runtime, not to hip-ep, and the set varies by version.

Keeping `session.disable_cpu_ep_fallback|1` on during the measurement is
deliberate. It costs nothing and it means a partial fallback fails the run
instead of quietly halving your throughput.

For a baseline on the same machine:

```bash
onnxruntime_perf_test -e cpu -t 30 -c 1 -s your_model.onnx
```

On Windows the package also bundles `DirectML.dll`, so the DML EP is available
as a second same-machine reference point.

## Generative: `model_benchmark`

```bash
$ROOT/bin/model_benchmark \
  -i /path/to/oga-model-dir \
  -l 128 -g 128 -ml -1 \
  -r 5 -w 1
```

`-w 1` is the warm-up that absorbs the compile; `-r 5` gives you five measured
repetitions. See
[Run an LLM with GenAI]({{ '/docs/tutorials/genai-llm/' | relative_url }}) for
what `-ml -1` is for and why omitting it breaks fixed-shape models.

Vary `-l` rather than only `-g` when you care about the shape of the curve.
Time-to-first-token is dominated by prefill and grows with prompt length;
tokens-per-second is dominated by memory bandwidth and degrades as the KV cache
grows. Measuring one prompt length tells you about that prompt length.

The [Benchmarks page]({{ '/docs/benchmarks/' | relative_url }}) reports exactly
these two metrics across three prompt lengths, for the same reason.

## Finding out where the time goes

A total is not a diagnosis. When you need the per-operation breakdown, turn the
profiler on — accepting that the totals are now inflated and no longer
comparable to your clean run.

```bash
HIPDNN_EP_PERF=1 $ROOT/bin/model_benchmark \
  -i /path/to/oga-model-dir \
  -l 128 -g 128 -ml -1 -r 3 -w 1 2>&1 | tee run.log
```

That log now interleaves three separate measurement streams plus
`model_benchmark`'s own output, which is unpleasant to read. The repository ships
a formatter:

```bash
python3 tools/perf-report/format_perf_report.py run.log
```

It renders four stable sections:

| Section | Content |
|---|---|
| `§ 1 HEADLINE` | Prefill (TTFT), decode, sampling, end-to-end, peak working set |
| `§ 2 STEADY-STATE DECODE BREAKDOWN` | One decode token split into OGA/ORT framework overhead vs. EP compute |
| `§ 3 PER-OP GPU BREAKDOWN` | Per-operation GPU and CPU time for the last `Compute()` call |
| `§ 4 PER-CALL DISTRIBUTION` | min / median / p99 / max across every `Compute()` invocation |

§ 2 is usually the interesting one: it tells you whether your time is going to
the GPU at all or to orchestration around it. § 3 tells you which operator to
look at once you know it is the GPU.

<div class="note" markdown="1">
`format_perf_report.py` needs `model_benchmark`'s statistics block to render
anything, and exits with code **2** if the log lacks it. Logs from
`onnxruntime_perf_test` or from pytest contain the per-operation tables but not
that block, so they are not supported — fall back to reading the tail of the log
directly.

The script is pure Python 3.10+ with no third-party dependencies, so you can
capture a log on one machine and format it on another.
</div>

Development-tree drivers `tools/perf-report/run_bench.sh` and
`docker_run_bench.sh` automate the capture-and-format cycle, including setting
the environment. They assume a Linux Docker build with the artifacts in
`$WORKSPACE/install/`, and they are **not** part of the release package.

## Reporting a number

Whatever you publish internally, publish the conditions with it: release
version, GPU and architecture, OS, driver, prompt and generation lengths,
repetition count, and whether the profiler was on. A number without those is
not reproducible, and six weeks later you will not remember.

That is the same information the [Benchmarks page]({{ '/docs/benchmarks/' | relative_url }})
carries at the top of its snapshot, and for the same reason.

## Next

- [Bring your own ONNX model]({{ '/docs/tutorials/bring-your-own-model/' | relative_url }}) if part of your graph is not being claimed.
- [Look inside the compiler]({{ '/docs/tutorials/inside-the-compiler/' | relative_url }}) if a single operator dominates § 3.
