param(
    [string]$TrialDir = "",
    [string]$Gpu = "0",
    [double]$IsoSurfaceThreshold = 10.0,
    [int]$IsoSurfaceResolution = 256,
    [string]$ThreeStudioDir = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($ThreeStudioDir -eq "") {
    $ThreeStudioDir = Join-Path $ProjectRoot "external\threestudio"
}
if (-not (Test-Path (Join-Path $ThreeStudioDir "launch.py"))) {
    throw "Cannot find threestudio launch.py in '$ThreeStudioDir'. Run scripts\setup_threestudio.ps1 first, or pass -ThreeStudioDir."
}

if ($TrialDir -eq "") {
    $SearchRoot = Join-Path $ProjectRoot "outputs\object_b\hw3-object-b-dreamfusion-sd"
    if (-not (Test-Path $SearchRoot)) {
        throw "Cannot find trial directory under '$SearchRoot'. Train object B first or pass -TrialDir."
    }
    $TrialDir = (Get-ChildItem $SearchRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

$ParsedConfig = Join-Path $TrialDir "configs\parsed.yaml"
$Checkpoint = Join-Path $TrialDir "ckpts\last.ckpt"
if (-not (Test-Path $ParsedConfig)) {
    throw "Cannot find parsed config: $ParsedConfig"
}
if (-not (Test-Path $Checkpoint)) {
    throw "Cannot find checkpoint: $Checkpoint"
}

$launchArgs = @(
    "launch.py",
    "--config", $ParsedConfig,
    "--export",
    "--gpu", $Gpu,
    "resume=$Checkpoint",
    "system.exporter_type=mesh-exporter",
    "system.exporter.fmt=obj",
    "system.geometry.isosurface_threshold=$IsoSurfaceThreshold",
    "system.geometry.isosurface_method=mc-cpu",
    "system.geometry.isosurface_resolution=$IsoSurfaceResolution"
)

Write-Host "Trial directory: $TrialDir"
Write-Host "cd $ThreeStudioDir"
Write-Host "python $($launchArgs -join ' ')"

if ($DryRun) {
    exit 0
}

Push-Location $ThreeStudioDir
try {
    & python @launchArgs
}
finally {
    Pop-Location
}
