param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath,
    [string]$Gpu = "0",
    [int]$MaxSteps = 600,
    [int]$Seed = 42,
    [double]$DefaultElevationDeg = 5.0,
    [double]$DefaultCameraDistance = 3.8,
    [bool]$WandbEnable = $true,
    [string]$WandbProject = "hw3-task1",
    [string]$WandbName = "object-c-stone",
    [string]$WandbMode = "offline",
    [string]$ThreeStudioDir = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Config = Join-Path $ProjectRoot "configs\object_c_stable_zero123.yaml"
$OutputRoot = Join-Path $ProjectRoot "outputs\object_c"
$env:WANDB_MODE = $WandbMode
if ($ThreeStudioDir -eq "") {
    $ThreeStudioDir = Join-Path $ProjectRoot "external\threestudio"
}

if (-not (Test-Path $ImagePath)) {
    throw "Cannot find image: $ImagePath"
}
if ((-not $DryRun) -and (-not (Test-Path (Join-Path $ThreeStudioDir "launch.py")))) {
    throw "Cannot find threestudio launch.py in '$ThreeStudioDir'. Run scripts\setup_threestudio.ps1 first, or pass -ThreeStudioDir."
}
if ((-not $DryRun) -and (-not (Test-Path (Join-Path $ThreeStudioDir "load\zero123\stable_zero123.ckpt")))) {
    throw "Cannot find Stable Zero123 weights. Run scripts\download_zero123_weights.ps1 first."
}

$ImageFullPath = (Resolve-Path $ImagePath).Path.Replace("\", "/")
$launchArgs = @(
    "launch.py",
    "--config", $Config,
    "--train",
    "--gpu", $Gpu,
    "data.image_path=$ImageFullPath",
    "trainer.max_steps=$MaxSteps",
    "seed=$Seed",
    "exp_root_dir=$OutputRoot",
    "data.default_elevation_deg=$DefaultElevationDeg",
    "data.default_camera_distance=$DefaultCameraDistance",
    "system.loggers.wandb.enable=$($WandbEnable.ToString().ToLower())",
    "system.loggers.wandb.project=$WandbProject",
    "system.loggers.wandb.name=$WandbName"
)

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
