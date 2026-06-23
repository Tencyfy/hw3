param(
    [string]$Prompt = "a single handmade chocolate chip cookie, round slightly irregular shape, golden-brown baked surface, cracked crumb texture, raised chocolate chips, single object, centered, plain background, photorealistic, highly detailed, studio lighting",
    [string]$Gpu = "0",
    [int]$MaxSteps = 10000,
    [int]$Width = 64,
    [int]$Height = 64,
    [int]$Seed = 42,
    [string]$SdModelPath = "./load/stable-diffusion-2-1-base",
    [bool]$WandbEnable = $true,
    [string]$WandbProject = "hw3-task1",
    [string]$WandbName = "object-b-cookie",
    [string]$WandbMode = "offline",
    [string]$ThreeStudioDir = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Config = Join-Path $ProjectRoot "configs\object_b_dreamfusion_sd.yaml"
$OutputRoot = Join-Path $ProjectRoot "outputs\object_b"
$env:WANDB_MODE = $WandbMode
if ($ThreeStudioDir -eq "") {
    $ThreeStudioDir = Join-Path $ProjectRoot "external\threestudio"
}

if ((-not $DryRun) -and (-not (Test-Path (Join-Path $ThreeStudioDir "launch.py")))) {
    throw "Cannot find threestudio launch.py in '$ThreeStudioDir'. Run scripts\setup_threestudio.ps1 first, or pass -ThreeStudioDir."
}

$launchArgs = @(
    "launch.py",
    "--config", $Config,
    "--train",
    "--gpu", $Gpu,
    "system.prompt_processor.prompt=$Prompt",
    "trainer.max_steps=$MaxSteps",
    "data.width=$Width",
    "data.height=$Height",
    "seed=$Seed",
    "exp_root_dir=$OutputRoot",
    "system.prompt_processor.pretrained_model_name_or_path=$SdModelPath",
    "system.guidance.pretrained_model_name_or_path=$SdModelPath",
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
