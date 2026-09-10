---
title: One-command deploy (Strix Halo)
description: >-
  A single PowerShell script that installs the hip-ep release package on a
  Ryzen AI Max running Windows and proves the GPU executed a model. Written to
  be run unattended, or handed to an agent.
---

The [Windows Quick Start]({{ '/docs/quickstart/windows/' | relative_url }}) walks
through installation one command at a time, so you can see what each step does
and check its result. This page is the same thing collapsed into one script, for
when you do not want to read it — an unattended install, a fresh machine, or a
coding agent that needs a working environment before it can start.

It is deliberately narrow. **Windows on a Ryzen AI Max ("Strix Halo",
`gfx1151`)**, using the release package. That is the configuration hip-ep is
characterised on. For anything else, use the platform pages.

## Run it

```powershell
irm {{ site.url }}{{ site.baseurl }}/assets/deploy-strix-halo.ps1 -OutFile deploy-strix-halo.ps1
.\deploy-strix-halo.ps1
```

Downloading and then running is one more step than piping straight into
`iex`, and it is the right habit: it lets you read the script before it runs,
and re-run the same copy later. The script needs no administrator rights.

About ten minutes, almost all of it the 232 MB download. When it finishes:

```text
hip-ep-deploy: OK version=v0.4.0 root=C:\Users\you\hip-ep-runtime l2=0.0234262
```

That `l2` is the GPU-versus-CPU difference on the test model, and it is the part
that matters: it is evidence the GPU ran the graph. Expect something near
`0.02`, not that exact value. Three runs on one machine — same driver, same
package, byte-identical inputs — produced `0.0239186`, `0.0234262` and
`0.0217464`, because the GEMM library does not have to pick the same algorithm
twice. Read the magnitude and ignore the digits; the script's threshold is
correspondingly loose.

Then, in that shell or any later one:

```powershell
. $HOME\hip-ep-runtime\env.ps1
hip-onnx-runner.exe -m your-model.onnx
```

## What it does

1. **Identifies the GPU** from `Win32_VideoController` and maps it to an
   architecture. Stops if there is no supported part.
2. **Resolves the latest release** from `github.com` and downloads the Windows
   package, unless you passed `-Version` or `-PackagePath`.
3. **Extracts** it under `-Root` and writes an `env.ps1` that puts `bin\` on
   `PATH` for the calling session.
4. **Generates a small ONNX model** — a 512×512 MatMul, Add and Relu — locally,
   so the check depends on nothing gated and is identical on every machine.
5. **Runs it under `HIPDNN_EP_STRICT`**, which turns a compile failure into an
   error instead of a silent CPU fallback.
6. **Runs it twice more**, once through the EP and once CPU-only, and compares
   the outputs. The L2 difference it prints is the proof that the GPU ran the
   graph.

Steps 4 to 6 are the part worth keeping. ONNX Runtime falls back to the CPU
without saying so and still returns correct answers, so an install that is
entirely broken looks exactly like one that works, only slower. The script does
not report success until it has evidence.

## Options

| Flag | Effect |
|---|---|
| `-Root <path>` | Where to install. Default `$HOME\hip-ep-runtime`. |
| `-Version <tag>` | Install a specific release instead of the latest. |
| `-PackagePath <zip>` | Use a package you already have. No network needed. |
| `-Force` | Re-download and replace an existing install. |
| `-SkipVerify` | Install only. Leaves the install unproven — see above. |

On a machine with no outbound access, download
`gpu-test-package-windows-{{ site.hip_ep_version }}.zip` from the
[releases page]({{ site.repo_url }}/releases) elsewhere, copy it over, and:

```powershell
.\deploy-strix-halo.ps1 -PackagePath D:\gpu-test-package-windows-{{ site.hip_ep_version }}.zip
```

## What it will not do

**It does not install a GPU driver.** That needs administrator rights and a
reboot, neither of which belongs in an unattended script. It reports the driver
version it found and points at [AMD support](https://www.amd.com/en/support) —
if a step fails at kernel launch, update the driver before investigating
anything else.

**It does not touch anything outside `-Root`.** No registry keys, no service, no
change to the system `PATH`. Uninstalling is:

```powershell
Remove-Item -Recurse -Force $HOME\hip-ep-runtime
```

The one exception is Python: if the `onnx` package is missing, the script
installs it into whichever interpreter is on `PATH`, because step 4 needs it.
hip-ep itself does not — only the verification does.

**It does not cover Linux.** The Linux package needs a ROCm runtime it
deliberately does not bundle, and the correct way to get one differs by
distribution. The [Linux Quick Start]({{ '/docs/quickstart/linux/' | relative_url }})
covers that.

## For agents

The script is non-interactive, takes no input on stdin, and is safe to re-run.
Two things are meant to be read back by a program.

The last line of stdout:

```text
hip-ep-deploy: <STATUS> version=<tag> root=<path> l2=<value>
```

And `<Root>\deploy-report.json`, which carries the same fields plus the detected
GPU, the driver version, and every note printed during the run.

The exit code says what to do next:

| Code | Status | Meaning |
|---|---|---|
| 0 | `OK` | Installed, and GPU execution verified. |
| 2 | `UNSUPPORTED` | No supported GPU. Nothing to retry. |
| 3 | `FETCH_FAILED` | Download or extract failed. Retry, or supply `-PackagePath`. |
| 4 | `RUNTIME_FAILED` | Binaries do not start. Usually a driver problem. |
| 5 | `VERIFY_FAILED` | The GPU check ran and did not pass. Do not use this install. |
| 6 | `UNVERIFIED` | Installed, but unproven — no Python, or `-SkipVerify`. |

Treat 6 as a warning rather than a success: the install may well be fine, but
nothing has demonstrated that the GPU is being used.

## If it fails

The script prints every command's failure output rather than swallowing it, so
the message it shows is the one to act on. When you need to see a step in
isolation, the [Windows Quick Start]({{ '/docs/quickstart/windows/' | relative_url }})
has the same sequence expanded, with the expected result after each command —
including the reference L2 value the script checks against.
