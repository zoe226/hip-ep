---
title: Build from Source
description: The developer path — build hip-ep and its whole dependency stack from source.
---

Build from source if you need to change the compiler, target an architecture no
release package covers, or work against an unreleased commit. If none of those
apply, a [release package]({{ '/docs/quickstart/' | relative_url }}) will get you
running in minutes instead of hours.

<div class="note note--warn" markdown="1">
**The first build is measured in hours, not minutes.** LLVM/MLIR/LLD is built
from source, and that is the long pole. It lands in the build tree and is reused
across rebuilds, so you pay it once — but you do pay it. Budget several hours and
around 100 GB of free disk for a cold tree.
</div>

## What builds itself

You do not fetch dependencies manually. `cmake/deps.cmake` resolves the entire
stack — LLVM/MLIR/LLD, protobuf, flatbuffers, ONNX Runtime and the TheRock ROCm
SDK — reusing them from a prefix when one is available and building or
downloading them otherwise.

The versions are pinned in
[`cmake/deps.txt`]({{ site.repo_url }}/blob/main/cmake/deps.txt). That file is the
single source of truth: to move to a newer LLVM or ONNX Runtime, edit the line
there and reconfigure.

## Directory layout

Clone so that source, build output and install prefix are siblings. Every command
below runs from the source directory and refers to the others with `..`.

```text
<workspace>/
├── hip-ep/            source — $PWD for every command below
├── build/
│   └── hip-ep/        cmake build tree (including the from-source LLVM)
└── install/           install prefix: bin/, lib/
```

## Linux

### Prerequisites

| Tool | Why |
|---|---|
| CMake ≥ 3.29, Ninja, Git, a C++ compiler, `python3` | Native build |
| Docker 26+ | Only for the container path |
| An AMD GPU with `/dev/kfd` and `/dev/dri/renderD*` | Only to *run* what you built |

No system LLVM is needed — one is built for you.

### Build

```bash
git clone https://github.com/ROCm/hip-ep.git
cd hip-ep
python3 build.py
```

`build.py` checks the toolchain, auto-detects the GPU architecture from
`/sys/class/kfd`, configures and builds, installs into `../install/`, and then
runs the LIT suite plus the GPU-free unit tests.

If you would rather not install a toolchain on the host, the container path runs
the same `build.py` inside an image with everything pinned:

```bash
./docker/run.sh image     # first time only
./docker/run.sh build
```

This is the authoritative build on the project's own Linux host. Your user must be
in the `docker` group; you do **not** need to be in `render` or `video`, because
the entrypoint reads the host GID off `/dev/kfd` and joins the container user to
it.

### Running what you built

A locally built `install/` is **not** self-contained — `libonnxruntime.so` lives
in the ONNX Runtime prefix and the ROCm libraries in TheRock:

```bash
WORKSPACE="$(cd .. && pwd)"
export ROOT="$WORKSPACE/install"
export THEROCK_DIST="$WORKSPACE/build/hip-ep/_therock"
export LD_LIBRARY_PATH="$ROOT/lib:$THEROCK_DIST/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$ROOT/bin:$PATH"

ldd "$ROOT/lib/libhipgpu.so" | grep "not found"   # expect no output
```

`THEROCK_DIST` points at the SDK `cmake/deps.cmake` downloaded into the build
tree during configure. From here, the run and verification steps are identical to
the [Linux Quick Start]({{ '/docs/quickstart/linux/' | relative_url }}) from step
5 onward.

<div class="note" markdown="1">
**`model_benchmark` is not part of the Linux source build.** It comes from OGA. If
you need end-to-end generative benchmarking, take that binary from a
[release package]({{ '/docs/quickstart/linux/' | relative_url }}).
</div>

## Windows

### Prerequisites

```powershell
# MSVC (cl.exe / link.exe), the Windows SDK and CMake
winget install Microsoft.VisualStudio.2022.BuildTools --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Component.VC.CMake.Project --includeRecommended"

winget install Ninja-build.Ninja
winget install Python.Python.3.14
winget install Mozilla.sccache
winget install Git.Git
```

`sccache` is not optional in practice: without a compiler cache, every
reconfigure that touches LLVM costs you the full build again.

### Build

The default generator is Visual Studio 17 2022, which locates MSVC on its own —
no special prompt needed. To use Ninja instead, run from an **x64 Native Tools
Command Prompt for VS 2022** and pass `--cmake_generator Ninja`.

```bash
git clone https://github.com/ROCm/hip-ep.git
cd hip-ep

mkdir -p ../local
LOCAL_DIR=$(cd ../local && pwd)

# Prefer the HIP that TheRock ships; a pre-installed HIP_PATH will interfere.
unset HIP_PATH

python build.py --install_dir "$LOCAL_DIR" --cmake_prefix_path "$LOCAL_DIR"
```

<div class="note note--warn" markdown="1">
**ABI: everything is built `/MT` (`MultiThreaded`, static CRT) in Release.**
Building `Debug`, or setting `CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDebug`,
produces runtime-library mismatch link errors against the prebuilt dependencies.
Do not mix configurations.
</div>

## Build options

| Option | Effect |
|---|---|
| `--hip_arch <gfx-arch>` | Target a specific GPU instead of auto-detecting. Required when the build host and the run host differ. |
| `--mock` | Build the compiler against a mock runtime — no GPU, HIP or ROCm needed. The way to work on the compiler from a laptop. |
| `--config RelWithDebInfo` | Build type; default `Release`. |
| `--skip_tests` | Skip the post-install test run. |
| `--clean` | Remove the build and install trees, then exit. |
| `--install_dir`, `--cmake_prefix_path` | Override the install prefix / dependency search prefix. |

<div class="note note--warn" markdown="1">
**A build must target the architecture of the GPU that will run it.** Getting
this wrong is not a build error. It configures, compiles, installs and runs
right up until a kernel launches. If you build on one machine and run on
another, pass `--hip_arch` explicitly with the *target* machine's architecture.
</div>

## Cross-compiling for MI350X

`gfx950` (CDNA 4) is a wave64 architecture, unlike the wave32 RDNA parts, and a
few things change accordingly. Build as above with `--hip_arch gfx950`, then read
[`docs/quick_start_mi350.md`]({{ site.repo_url }}/blob/main/docs/quick_start_mi350.md)
for what wave64 changes.

## Tests

`build.py` runs the LIT suite and the GPU-free unit tests after install unless
you pass `--skip_tests`. To re-run without a rebuild:

```bash
BUILD_DIR="../build/$(basename "$PWD")"

# Everything ctest knows about. Some E2E tests need a GPU.
ctest --test-dir "$BUILD_DIR" -C Release --verbose

# Just the MLIR pass-verification suite.
ctest --test-dir "$BUILD_DIR" -C Release -R MorphizenMLIRLitTests --verbose
```

LIT needs `pip install lit`. The suites divide up as:

| Suite | Covers |
|---|---|
| `test/lit/` | IR transformations and ABI lowering |
| `test/numeric/` | Per-operation GPU-vs-CPU correctness |
| `test/e2e/`, `test/python/` | Whole-model and runtime paths |

Each directory has a `README.md` with its own setup. When you add a test, make
sure it proves GPU execution — a test that silently falls back to the CPU EP
compares CPU against CPU and passes for the wrong reason.

## Before you commit

```bash
pre-commit run --all-files
```

This runs `lintrunner` (clang-format for C++, Ruff for Python) and the MIT
license-header check, which is enforced on every file.
[`CONTRIBUTING.md`]({{ site.repo_url }}/blob/main/CONTRIBUTING.md) covers the PR,
AI-disclosure and commit-trailer requirements.

## Troubleshooting

**CMake starts building LLVM from source and I did not expect it to**

That is the designed fallback: no LLVM/MLIR was found on `CMAKE_PREFIX_PATH`. It
is expected on a fresh tree. To avoid it, install a prebuilt LLVM/MLIR/LLD into a
prefix and pass `-DCMAKE_PREFIX_PATH=<prefix>`. Reuse the same build directory
across reconfigures so the source build is not repeated.

**Dependency builds cannot find a compiler**

On Windows, run configure and build from a Visual Studio Developer shell so
`cl.exe`, `ninja` and `git` are on `PATH`.

**`Could not find compiler launcher sccache`**

Install sccache, or drop `CMAKE_C_COMPILER_LAUNCHER` / `CMAKE_CXX_COMPILER_LAUNCHER`
from the configure line.

**`MorphizenMLIRLitTests` passes instantly without naming any tests**

`lit` was not found at configure time. `pip install lit`, then reconfigure with
`--fresh`.

**Linker errors mentioning `/MT` vs `/MTd` or `/MD`**

A configuration mix on Windows. Use `Release` with
`CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded` throughout.

## Next

- [Overview]({{ '/docs/' | relative_url }}) — how the compilation pipeline is structured.
- [Pass menu]({{ site.repo_url }}/blob/main/docs/pipeline_pass_menu.md) — pass ordering and the plugin slots.
- [Plugin authoring]({{ site.repo_url }}/blob/main/docs/plugin_authoring.md) — adding your own pass.
