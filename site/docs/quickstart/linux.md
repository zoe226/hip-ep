---
title: Quick Start — Linux
description: From a machine with nothing installed to an ONNX model executing on an AMD GPU.
---

This page is written to be followed top to bottom without jumping. Every step
ends with a check and the output that check should produce; if the output does
not match, the fix is in the same step rather than in a separate troubleshooting
document.

Every command is safe to re-run. If you lose your shell, re-run
[step 4](#step-4) and continue.

Paths are concrete on purpose. Everything lands under `$HOME/hip-ep-runtime`;
substitute a different directory if you like, but substitute it everywhere.

<div class="note" markdown="1">
**Disk and time.** ROCm is about 2.4 GB compressed and roughly 8 GB extracted;
the hip-ep package is 459 MB compressed. Budget ~15 GB of free space and, on a
normal connection, 15–30 minutes — almost all of it download.
</div>

## Step 1 — Confirm the machine has a usable AMD GPU {#step-1}

The kernel driver exposes the GPU through `/dev/kfd`. If that file is missing,
no amount of userspace installation will help.

```bash
ls -la /dev/kfd /dev/dri/renderD*
```

Expected: both exist, and `/dev/kfd` is owned by group `render`.

```text
crw-rw---- 1 root render 234, 0 ... /dev/kfd
crw-rw---- 1 root render 226, 128 ... /dev/dri/renderD128
```

**If `/dev/kfd` does not exist**, the `amdgpu` kernel driver is not loaded. This
is a driver/kernel problem, not a hip-ep problem — install the AMD GPU driver
for your distribution and reboot before continuing.

Now confirm your user can open it:

```bash
id -nG | tr ' ' '\n' | grep -qx render && echo "render: OK" || echo "render: MISSING"
```

**If it prints `render: MISSING`**, add yourself to the group. This is the single
most common cause of "no GPU found" later on, and it fails silently:

```bash
sudo usermod -aG render "$USER"
```

Then log out and back in (a new shell is not enough — group membership is
established at login). Re-run the check before continuing.

## Step 2 — Install the ROCm runtime {#step-2}

The Linux hip-ep package does **not** bundle ROCm. You need a ROCm distribution,
and the one hip-ep is built and tested against is the TheRock 7.11.0 build for
`gfx1151`. This is the exact archive the source build downloads for itself, so
using it removes a whole class of version-mismatch problems.

```bash
mkdir -p "$HOME/hip-ep-runtime"
cd "$HOME/hip-ep-runtime"

curl -fL -O https://repo.amd.com/rocm/tarball/therock-dist-linux-gfx1151-7.11.0.tar.gz

mkdir -p therock-dist
tar -xzf therock-dist-linux-gfx1151-7.11.0.tar.gz -C therock-dist --strip-components=1
```

Check:

```bash
"$HOME/hip-ep-runtime/therock-dist/bin/rocminfo" | grep -m1 -o 'gfx[0-9a-f]*'
```

Expected: a single architecture name, for example `gfx1151`.

**If it prints `gfx1151`**, continue to step 3.

**If it prints anything else** — `gfx1150`, `gfx1152`, `gfx950`, or another
architecture — stop. The Linux release package is built for `gfx1151` only and
will fail at kernel launch on any other part. Go to
[Build from Source]({{ '/docs/quickstart/build/' | relative_url }}) and pass
`--hip_arch` for your architecture. Note that the *Windows* package does cover
`gfx1150` and `gfx1152`; the Linux one does not.

**If `rocminfo` prints nothing or errors**, return to step 1 — this is the same
`/dev/kfd` permission problem surfacing one layer up.

## Step 3 — Download and unpack hip-ep {#step-3}

```bash
cd "$HOME/hip-ep-runtime"

curl -fL -O https://github.com/ROCm/hip-ep/releases/download/{{ site.hip_ep_version }}/gpu-test-package-linux-gfx1151-{{ site.hip_ep_version }}.zip

mkdir -p hip-ep
unzip -oq gpu-test-package-linux-gfx1151-{{ site.hip_ep_version }}.zip -d hip-ep
chmod +x hip-ep/bin/*
```

The archive has no top-level directory of its own, which is why it is extracted
into one explicitly. `chmod` is required: the zip format does not preserve the
executable bit.

Check:

```bash
ls "$HOME/hip-ep-runtime/hip-ep"
```

Expected: `bin  etc  lib  wheels`.

## Step 4 — Set up the environment {#step-4}

Write the settings to a file rather than typing them into a shell, so that
recovering a lost session is one command instead of six.

```bash
cat > "$HOME/hip-ep-runtime/env.sh" <<'EOF'
export ROOT="$HOME/hip-ep-runtime/hip-ep"
export THEROCK_DIST="$HOME/hip-ep-runtime/therock-dist"

# ${VAR:+:$VAR} appends the previous value only if it was already set. A plain
# "$NEW:$OLD" would leave a trailing colon when $OLD is empty, and an empty
# entry in a library path means "the current directory".
export LD_LIBRARY_PATH="$ROOT/lib:$THEROCK_DIST/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LIBRARY_PATH="$ROOT/lib:$THEROCK_DIST/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"

case ":$PATH:" in
  *":$ROOT/bin:"*) ;;
  *) export PATH="$ROOT/bin:$PATH" ;;
esac
EOF

source "$HOME/hip-ep-runtime/env.sh"
```

Three of those are load-bearing and not obvious:

- `THEROCK_DIST` is read by the compiler driver to build the `-L` paths it hands
  to `ld.lld` when linking a model. Without it the link fails with `undefined
  symbol: hipGetDeviceCount`, which does not look like a missing environment
  variable.
- `LD_LIBRARY_PATH` must include TheRock even though the package bundles its
  transitive `.so` files, because `libamd_comgr_loader.so.1` is a stub that
  `dlopen`s the real library at runtime — the dynamic loader cannot see that
  dependency in advance.
- `PATH` must include `$ROOT/bin` because the per-model link step invokes
  `clang++` as a subprocess. The package ships its own `clang` and `lld` there,
  so no system LLVM is needed.

Check:

```bash
ldd "$ROOT/lib/libhipgpu.so" | grep "not found"
```

Expected: **no output at all.** An empty result means every shared-library
dependency resolved.

**If any line is printed**, a library is missing. Confirm `source
"$HOME/hip-ep-runtime/env.sh"` ran in *this* shell, and that `$THEROCK_DIST/lib`
exists and is non-empty.

Then confirm the tools run:

```bash
hip-onnx-runner --help | head -3
```

Expected: a usage block. Any output beginning with `Usage` means the binary
loaded successfully.

## Step 5 — Make a model to test with {#step-5}

Rather than downloading one, generate a tiny model locally. It takes a second,
depends on nothing gated, and is byte-identical for everyone reading this page —
which makes it a reliable thing to compare notes about.

```bash
cd "$HOME/hip-ep-runtime"
python3 -m pip install --quiet onnx

python3 - <<'EOF'
import onnx
from onnx import TensorProto, helper, numpy_helper
import numpy as np

rng = np.random.default_rng(0)
w = numpy_helper.from_array(rng.standard_normal((512, 512), dtype=np.float32), "W")
b = numpy_helper.from_array(rng.standard_normal((512,), dtype=np.float32), "B")

graph = helper.make_graph(
    [
        helper.make_node("MatMul", ["X", "W"], ["mm"]),
        helper.make_node("Add", ["mm", "B"], ["add"]),
        helper.make_node("Relu", ["add"], ["Y"]),
    ],
    "smoke",
    [helper.make_tensor_value_info("X", TensorProto.FLOAT, [1, 512])],
    [helper.make_tensor_value_info("Y", TensorProto.FLOAT, [1, 512])],
    [w, b],
)
model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 17)])
model.ir_version = 10
onnx.checker.check_model(model)
onnx.save(model, "smoke.onnx")
print("wrote smoke.onnx")
EOF
```

Expected: `wrote smoke.onnx`.

`ir_version` is pinned because ONNX Runtime rejects models newer than the IR
version it was built against, and the `onnx` package on PyPI moves faster than
the pinned runtime does.

## Step 6 — Run it {#step-6}

```bash
cd "$HOME/hip-ep-runtime"
hip-onnx-runner -m smoke.onnx
```

Expected: the run completes and prints timing. **The first run is slow** — this
is the compile — and a second run of the same command is fast.

`hip-onnx-runner` feeds random input by default, which is fine here. It is not
fine for a language model, whose `input_ids` must be below the vocabulary size;
for those, generate a valid input directory first:

```bash
curl -fL -O https://raw.githubusercontent.com/ROCm/hip-ep/main/tools/hip-onnx-runner/gen_hip_onnx_runner_inputs.py
python3 gen_hip_onnx_runner_inputs.py -o gen_inputs /path/to/llm.onnx
hip-onnx-runner -m /path/to/llm.onnx -i gen_inputs
```

## Step 7 — Prove the GPU actually ran it {#step-7}

This is the step people skip, and it is the reason "hip-ep is not faster than
CPU" reports usually turn out to be CPU-only runs. On a compilation failure ONNX
Runtime falls back to the CPU EP and still returns correct numbers.

```bash
HIPDNN_EP_STRICT=1 hip-onnx-runner -m smoke.onnx
```

Expected: the same successful run as step 6.

`HIPDNN_EP_STRICT=1` turns a silent fallback into a hard failure. **If step 6
succeeds and step 7 fails**, then step 6 was running on the CPU and the error
you now see is the real one.

For a second, independent confirmation, compare EP output against CPU output
directly:

```bash
hip-onnx-runner -m smoke.onnx -d 2                 # EP outputs  -> ep_o_dump/
hip-onnx-runner -m smoke.onnx -d 2 -n              # CPU outputs -> cpu_o_dump/
hip-onnx-runner -L ep_o_dump,cpu_o_dump            # L2-norm comparison
```

Expected: a small L2 norm. Exact bit equality is not expected and not a goal —
the GPU path uses different kernels and different accumulation order.

## Step 8 — Measure something real {#step-8}

`onnxruntime_perf_test` reports steady-state latency. Give it enough wall time
that the one-off compile does not dominate the average:

```bash
onnxruntime_perf_test \
  --plugin_ep_libs "hipgpu|$ROOT/lib/libhipgpu.so" \
  --plugin_eps     "hipgpu" \
  -C "session.disable_cpu_ep_fallback|1" \
  -t 60 -c 1 -s -I \
  smoke.onnx
```

`session.disable_cpu_ep_fallback|1` serves the same purpose as
`HIPDNN_EP_STRICT` above: it makes a fallback an error rather than a quiet
slowdown. For the CPU baseline you are comparing against:

```bash
onnxruntime_perf_test -e cpu -t 30 -c 1 -s smoke.onnx
```

<div class="note note--warn" markdown="1">
**Do not benchmark with debug tracing on.** `HIPDNN_EP_PERF=1` and
`HIPDNN_EP_DEBUG=1` add per-operation instrumentation, and numbers collected
with either of them set are not comparable to anything. Run GPU benchmarks
serially — a concurrent run invalidates both.
</div>

## Troubleshooting

**`Failed to get HIP device count or no devices available`**

The process cannot open `/dev/kfd`. Almost always group membership — re-run the
`render` check in [step 1](#step-1)
and confirm you logged out and back in, not just opened a new terminal.

**`EP library not found: libhipgpu.so`**

`hip-onnx-runner` searches `$MORPHIZEN_EP_LIB` (a full path), then the current
directory, then `<exe-dir>/libhipgpu.so`, then `<exe-dir>/../lib/libhipgpu.so`.
Running from the extracted package needs no variable at all. If you copied the
binary somewhere else, set `MORPHIZEN_EP_LIB` to the full path of the `.so`.

**`clang++ not found on PATH and HIPDNN_CLANG_PATH is unset or stale`**

The per-model link runs `clang++` as a subprocess. Put the bundled toolchain on
`PATH` — `export PATH="$ROOT/bin:$PATH"`, which
[step 4](#step-4) does.

**`undefined symbol: hipGetDeviceCount` during compilation**

`THEROCK_DIST` is unset or points somewhere without a `lib/`. See
[step 4](#step-4).

**`Got invalid dimensions for input: attention_mask`**

Specific to OGA models with a fixed-shape prefill/decode pipeline. Pass `-ml -1`
to `model_benchmark` so it keeps the `search.max_length` baked into
`genai_config.json` instead of overriding it with prompt + generation length.

**The first run appears to hang**

It is compiling. A large model can take several minutes on the first inference.
If you want to watch it, `HIPDNN_EP_DEBUG=1` will show progress — just do not
benchmark with it set.

## Next

- [Build from Source]({{ '/docs/quickstart/build/' | relative_url }}) if you need to change the compiler.
- [Overview]({{ '/docs/' | relative_url }}) for how the compilation pipeline actually works.
