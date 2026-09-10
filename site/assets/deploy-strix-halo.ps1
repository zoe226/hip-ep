#Requires -Version 5.1
<#
    Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
    Licensed under the MIT License.

.SYNOPSIS
    Installs the hip-ep release package on a Ryzen AI Max ("Strix Halo",
    gfx1151) running Windows, and proves the GPU executed a model.

.DESCRIPTION
    This is the scripted form of the Windows Quick Start. It is written to be
    handed to an agent or run unattended: it takes no interactive input, it is
    safe to re-run, it installs nothing system-wide, and it ends by verifying
    GPU execution rather than by assuming it.

    Everything lands under -Root. Deleting that directory uninstalls hip-ep
    completely: nothing is written to the registry, no service is created, and
    PATH is modified for the calling session only.

    WHAT IT CANNOT DO
    The GPU driver is out of scope. Installing an AMD Adrenalin driver needs
    administrator rights and a reboot, so this script detects the driver,
    reports its version, and tells you where to get a newer one -- it does not
    install one.

.PARAMETER Root
    Install directory. Default: $HOME\hip-ep-runtime.

.PARAMETER Version
    Release tag to install, e.g. v0.4.0. Omit to resolve the latest release
    from github.com. Ignored when -PackagePath is given.

.PARAMETER PackagePath
    Path to an already-downloaded gpu-test-package-windows-*.zip. Use this on a
    machine with no outbound network access.

.PARAMETER SkipVerify
    Install only; do not build the smoke model or run the GPU check. The
    install is then unproven -- prefer fixing whatever blocked verification.

.PARAMETER Force
    Re-download and re-extract even if the package is already present.

.OUTPUTS
    A JSON report at <Root>\deploy-report.json, and a final line of the form

        hip-ep-deploy: <STATUS> version=<tag> root=<path> l2=<value>

    Exit codes:
        0  OK             installed and GPU execution verified
        2  UNSUPPORTED    no supported GPU found
        3  FETCH_FAILED   could not download or extract the package
        4  RUNTIME_FAILED the installed binaries do not start
        5  VERIFY_FAILED  the GPU check ran and did not pass
        6  UNVERIFIED     installed, but the check could not run (no Python)

.EXAMPLE
    .\deploy-strix-halo.ps1

.EXAMPLE
    .\deploy-strix-halo.ps1 -PackagePath D:\gpu-test-package-windows-v0.4.0.zip
#>

[CmdletBinding()]
param(
    [string] $Root = (Join-Path $HOME 'hip-ep-runtime'),
    [string] $Version,
    [string] $PackagePath,
    [switch] $SkipVerify,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Invoke-WebRequest renders a progress bar per chunk on Windows PowerShell 5.1,
# which costs more wall time than the transfer itself on a 232 MB download.
$ProgressPreference = 'SilentlyContinue'

# 5.1 still negotiates TLS 1.0 by default on some images; github.com refuses it.
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$RepoUrl = 'https://github.com/ROCm/hip-ep'
$DriverUrl = 'https://www.amd.com/en/support'

# The expected order of magnitude for smoke.onnx on gfx1151 -- deliberately two
# significant figures, because this number is not reproducible beyond that. Three
# runs on one machine, same driver, same package, byte-identical smoke.onnx and
# byte-identical runner, produced 0.0239186, 0.0234262 and 0.0217464: a spread of
# about 10%, because the GEMM library need not pick the same algorithm twice.
# The tolerance below is a wide upper bound rather than a comparison against this
# value; checking for equality here would fail working installs.
$L2Reference = 0.023
$L2Tolerance = 0.5

$report = [ordered]@{
    status       = 'UNKNOWN'
    started      = (Get-Date).ToString('o')
    root         = $Root
    version      = $null
    gpu          = $null
    driver       = $null
    l2           = $null
    l2_reference = $L2Reference
    notes        = @()
}

$script:pushed = $false

function Write-Phase([string] $Text) {
    Write-Host ''
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Note([string] $Text) {
    Write-Host "    $Text"
    $report.notes += $Text
}

function Complete-Run([string] $Status, [int] $Code) {
    # The verification step has to run with the current directory set to $Root,
    # because hip-onnx-runner creates its dump directories relative to cwd. Undo
    # that here rather than at the end of the happy path, so that an early exit
    # does not leave the caller's shell somewhere it did not ask to be.
    if ($script:pushed) { Pop-Location; $script:pushed = $false }

    $report.status = $Status
    $report.finished = (Get-Date).ToString('o')
    try {
        New-Item -ItemType Directory -Force -Path $Root | Out-Null
        $report | ConvertTo-Json -Depth 4 |
            Set-Content -Path (Join-Path $Root 'deploy-report.json') -Encoding UTF8
    } catch {
        Write-Host "    (could not write deploy-report.json: $($_.Exception.Message))"
    }
    Write-Host ''
    $l2 = if ($null -ne $report.l2) { $report.l2 } else { 'n/a' }
    $ver = if ($report.version) { $report.version } else { 'n/a' }
    Write-Host "hip-ep-deploy: $Status version=$ver root=$Root l2=$l2"
    exit $Code
}

# ---------------------------------------------------------------------------
# 1. Hardware
# ---------------------------------------------------------------------------

Write-Phase '1/6  Checking the GPU'

# The Windows package ships kernels for all three RDNA 3.5 integrated parts,
# but hipBLASLt and rocBLAS tuning data for gfx1151 only. This script targets
# gfx1151; the others are recognised and warned about rather than blocked,
# because they do run -- their GEMM performance is simply uncharacterized.
$archByAdapter = [ordered]@{
    '8060S' = 'gfx1151'; '8050S' = 'gfx1151'
    '890M'  = 'gfx1150'; '880M'  = 'gfx1150'
    '860M'  = 'gfx1152'; '840M'  = 'gfx1152'
}

$adapters = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
$match = $null
foreach ($a in $adapters) {
    foreach ($key in $archByAdapter.Keys) {
        if ($a.Name -match [regex]::Escape($key)) {
            $match = [pscustomobject]@{
                Name = $a.Name; Arch = $archByAdapter[$key]; Driver = $a.DriverVersion
            }
            break
        }
    }
    if ($match) { break }
}

if (-not $match) {
    Write-Host '    No supported AMD integrated GPU found. Adapters present:'
    foreach ($a in $adapters) { Write-Host "      - $($a.Name)" }
    Write-Note "The release package targets Ryzen AI / Ryzen AI Max integrated GPUs."
    Write-Note "For any other part, build from source: $RepoUrl"
    Complete-Run 'UNSUPPORTED' 2
}

$report.gpu = "$($match.Name) ($($match.Arch))"
$report.driver = $match.Driver
Write-Note "GPU:    $($match.Name)  ->  $($match.Arch)"
Write-Note "Driver: $($match.Driver)"

if ($match.Arch -ne 'gfx1151') {
    Write-Host ''
    Write-Host "    WARNING: this script is written for gfx1151 (Strix Halo)." -ForegroundColor Yellow
    Write-Host "    $($match.Arch) will run, but the package carries hipBLASLt and rocBLAS" -ForegroundColor Yellow
    Write-Host "    tuning data for gfx1151 only, so do not read its GEMM-heavy" -ForegroundColor Yellow
    Write-Host "    performance as representative." -ForegroundColor Yellow
    $report.notes += "Non-gfx1151 part: performance is uncharacterized."
}

Write-Note "This script cannot install a driver -- that needs admin rights and a reboot."
Write-Note "If anything below fails at kernel launch, update from $DriverUrl first."

# ---------------------------------------------------------------------------
# 2. Package
# ---------------------------------------------------------------------------

Write-Phase '2/6  Resolving the release'

$installDir = Join-Path $Root 'hip-ep'
$zipPath = Join-Path $Root 'hip-ep.zip'

if ($PackagePath) {
    if (-not (Test-Path -LiteralPath $PackagePath)) {
        Write-Note "No such file: $PackagePath"
        Complete-Run 'FETCH_FAILED' 3
    }
    $PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
    if ($PackagePath -match 'gpu-test-package-windows-(v[0-9][^\\/]*)\.zip$') {
        $report.version = $Matches[1]
    } else {
        $report.version = 'local'
    }
    Write-Note "Using local package: $PackagePath  ($($report.version))"
} else {
    if (-not $Version) {
        # Deliberately github.com and not api.github.com: the API is rate
        # limited per source IP and returns 403 from behind a corporate NAT,
        # which is a confusing way for an install to fail. The releases/latest
        # page redirects to the tag, and the tag is in the HTML either way.
        try {
            $html = (Invoke-WebRequest -Uri "$RepoUrl/releases/latest" -UseBasicParsing).Content
            $m = [regex]::Match($html, 'releases/tag/(v[0-9][0-9A-Za-z.\-]*)')
            if (-not $m.Success) { throw 'no release tag in the response' }
            $Version = $m.Groups[1].Value
        } catch {
            Write-Note "Could not resolve the latest release: $($_.Exception.Message)"
            Write-Note "Pass -Version <tag>, or -PackagePath <zip>, and re-run."
            Complete-Run 'FETCH_FAILED' 3
        }
    }
    $report.version = $Version
    Write-Note "Release: $Version"
}

Write-Phase '3/6  Installing'

New-Item -ItemType Directory -Force -Path $Root | Out-Null

# Written on every successful extract. Without it, a re-run that skips the
# download would report whatever version was *requested* rather than the one
# actually sitting on disk -- which is exactly the report an agent would trust.
$stamp = Join-Path $installDir 'installed-version.txt'

$alreadyInstalled = Test-Path (Join-Path $installDir 'bin\hip-onnx-runner.exe')
if ($alreadyInstalled -and -not $Force) {
    if (Test-Path $stamp) {
        $installedVersion = (Get-Content $stamp -Raw).Trim()
        if ($installedVersion -ne $report.version) {
            Write-Note "Requested $($report.version) but $installedVersion is already installed."
            Write-Note 'Re-run with -Force to replace it. Reporting what is on disk.'
        }
        $report.version = $installedVersion
    } else {
        Write-Note 'An install is present but carries no version stamp; recording it as unknown.'
        $report.version = 'unknown'
    }
    Write-Note "Already present at $installDir -- skipping download. Use -Force to replace."
} else {
    if ($PackagePath) {
        $zipPath = $PackagePath
    } else {
        $url = "$RepoUrl/releases/download/$Version/gpu-test-package-windows-$Version.zip"
        Write-Note "Downloading $url"
        Write-Note 'About 232 MB; this is the slow step.'
        try {
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        } catch {
            Write-Note "Download failed: $($_.Exception.Message)"
            Write-Note "Check that $Version has a Windows package attached."
            Complete-Run 'FETCH_FAILED' 3
        }
        $mb = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
        Write-Note "Downloaded $mb MB"
    }

    # The archive has no top-level directory of its own, so it is extracted
    # into one explicitly rather than spraying bin/ lib/ into $Root.
    Write-Note "Extracting into $installDir (about 610 MB across 299 files)"
    try {
        Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
    } catch {
        Write-Note "Extract failed: $($_.Exception.Message)"
        Complete-Run 'FETCH_FAILED' 3
    }
    Set-Content -Path $stamp -Value $report.version -Encoding UTF8
}

if (-not (Test-Path (Join-Path $installDir 'bin\hip-onnx-runner.exe'))) {
    Write-Note "Installed tree looks wrong: no bin\hip-onnx-runner.exe under $installDir"
    Complete-Run 'FETCH_FAILED' 3
}

# ---------------------------------------------------------------------------
# 3. Environment
# ---------------------------------------------------------------------------

Write-Phase '4/6  Writing the environment file'

# Everything the EP needs resolves relative to bin\, so the whole setup is one
# directory on PATH. Written to a file so that recovering a lost shell is one
# command rather than a re-read of the docs.
$envFile = Join-Path $Root 'env.ps1'
@'
$env:HIPEP_ROOT = Join-Path (Split-Path -Parent $PSCommandPath) 'hip-ep'
# Prepend only once, so re-sourcing this file does not grow PATH without bound.
$binDir = Join-Path $env:HIPEP_ROOT 'bin'
if (-not ($env:PATH -split ';' | Where-Object { $_ -eq $binDir })) {
    $env:PATH = "$binDir;$env:PATH"
}
'@ | Set-Content -Path $envFile -Encoding UTF8

. $envFile
Write-Note "Wrote $envFile and sourced it into this session."
Write-Note "Session-scoped only: nothing was written to the registry or system PATH."

$runner = Join-Path $env:HIPEP_ROOT 'bin\hip-onnx-runner.exe'
$null = & $runner --help 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Note "hip-onnx-runner.exe did not start (exit $LASTEXITCODE)."
    Write-Note 'A 0xc0000135 or "module could not be found" means a DLL failed to load.'
    Write-Note 'Every dependency resolves relative to bin\ -- run the binaries in place.'
    Complete-Run 'RUNTIME_FAILED' 4
}
Write-Note 'hip-onnx-runner.exe starts.'

if ($SkipVerify) {
    Write-Note '-SkipVerify given: the install is not proven.'
    Complete-Run 'UNVERIFIED' 6
}

# ---------------------------------------------------------------------------
# 4. Test model
# ---------------------------------------------------------------------------

Write-Phase '5/6  Building a test model'

# Generated locally rather than downloaded: it depends on nothing gated, takes
# a second, and is byte-identical for everyone -- which is what makes the
# expected L2 below meaningful as a reference.
$python = $null
foreach ($candidate in @('python', 'python3', 'py')) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $python = $cmd.Source; break }
}

if (-not $python) {
    Write-Note 'No Python interpreter on PATH, so the test model cannot be generated.'
    Write-Note 'hip-ep itself does not need Python -- only this verification step does.'
    Write-Note 'Install Python and re-run, or supply your own model and follow'
    Write-Note "step 6 of the Windows Quick Start by hand."
    Complete-Run 'UNVERIFIED' 6
}
Write-Note "Python: $python"

& $python -c 'import onnx' 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Note 'Installing the onnx package (this lands in the interpreter above, not in -Root).'
    & $python -m pip install --quiet onnx
    if ($LASTEXITCODE -ne 0) {
        Write-Note 'pip install onnx failed.'
        Complete-Run 'UNVERIFIED' 6
    }
}

# hip-onnx-runner creates its dump directories under the *current* directory,
# named from the model file stem -- not next to the model. So the rest of this
# runs from $Root. Complete-Run restores the caller's directory on every path.
Push-Location $Root
$script:pushed = $true

$makeSmoke = Join-Path $Root 'make_smoke.py'
@'
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
# Pinned: ONNX Runtime rejects models newer than the IR version it was built
# against, and the onnx package on PyPI moves faster than the pinned runtime.
model.ir_version = 10
onnx.checker.check_model(model)
onnx.save(model, "smoke.onnx")
print("wrote smoke.onnx")
'@ | Set-Content -Path $makeSmoke -Encoding UTF8

& $python $makeSmoke
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $Root 'smoke.onnx'))) {
    Write-Note 'Could not generate smoke.onnx.'
    Complete-Run 'UNVERIFIED' 6
}

# ---------------------------------------------------------------------------
# 5. Proof
# ---------------------------------------------------------------------------

Write-Phase '6/6  Proving the GPU ran it'

$smoke = Join-Path $Root 'smoke.onnx'

# Strict mode aborts inside the compiler at the pass that failed, instead of
# letting a partially-compiled graph through. Note that the variable is tested
# for PRESENCE, not value: HIPDNN_EP_STRICT=0 enables it exactly as =1 does,
# which is why it is removed rather than zeroed afterwards.
$env:HIPDNN_EP_STRICT = '1'
$strictOut = & $runner -m $smoke 2>&1
$strictCode = $LASTEXITCODE
Remove-Item Env:\HIPDNN_EP_STRICT -ErrorAction SilentlyContinue

if ($strictCode -ne 0) {
    Write-Note "Strict-mode run failed (exit $strictCode). Output:"
    $strictOut | ForEach-Object { Write-Host "      $_" }
    Complete-Run 'VERIFY_FAILED' 5
}
Write-Note 'Strict mode: every subgraph hip-ep claimed, it also compiled.'

# Second, independent confirmation: same model down the EP path and the CPU
# path, outputs compared. Dump directories are named from the model file stem,
# so the two do not collide.
Remove-Item -Path @(
    (Join-Path $Root 'smoke_o_dump')
    (Join-Path $Root 'smoke_cpu_o_dump')
) -Recurse -Force -ErrorAction SilentlyContinue

& $runner -m $smoke -d 2 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Note 'EP dump run failed.'; Complete-Run 'VERIFY_FAILED' 5 }

& $runner -m $smoke -d 2 -n | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Note 'CPU dump run failed.'; Complete-Run 'VERIFY_FAILED' 5 }

$cmpOut = & $runner -L 'smoke_o_dump,smoke_cpu_o_dump' 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Note 'Comparison failed. Output:'
    $cmpOut | ForEach-Object { Write-Host "      $_" }
    Complete-Run 'VERIFY_FAILED' 5
}

$m = [regex]::Match(($cmpOut -join "`n"), 'Combined L2 \(stacked diffs\):\s*([0-9.eE+\-]+)')
if (-not $m.Success) {
    Write-Note 'Could not read the combined L2 from the comparison output:'
    $cmpOut | ForEach-Object { Write-Host "      $_" }
    Complete-Run 'VERIFY_FAILED' 5
}

$l2 = [double] $m.Groups[1].Value
$report.l2 = $l2
Write-Note ("Combined L2 vs CPU: {0}  (expect roughly {1} on gfx1151; it varies run to run)" -f $l2, $L2Reference)

if ([double]::IsNaN($l2) -or $l2 -gt $L2Tolerance) {
    Write-Note "That is too far from the reference to be accumulation order."
    Write-Note 'Update the GPU driver and re-run before investigating anything else.'
    Complete-Run 'VERIFY_FAILED' 5
}

Write-Host ''
Write-Host '    Installed and verified. To use hip-ep in a new shell:' -ForegroundColor Green
Write-Host "        . `"$envFile`"" -ForegroundColor Green
Write-Host ''
Write-Host '    Uninstall is: Remove-Item -Recurse -Force "' -NoNewline -ForegroundColor Green
Write-Host "$Root`"" -ForegroundColor Green

Complete-Run 'OK' 0
