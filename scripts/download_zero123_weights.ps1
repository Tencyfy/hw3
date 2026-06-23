param(
    [string]$ThreeStudioDir = "",
    [string]$RepoId = "stabilityai/stable-zero123",
    [string]$HuggingFaceToken = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($ThreeStudioDir -eq "") {
    $ThreeStudioDir = Join-Path $ProjectRoot "external\threestudio"
}
if ((-not $DryRun) -and (-not (Test-Path (Join-Path $ThreeStudioDir "launch.py")))) {
    throw "Cannot find threestudio launch.py in '$ThreeStudioDir'. Run scripts\setup_threestudio.ps1 first, or pass -ThreeStudioDir."
}

$Zero123Dir = Join-Path $ThreeStudioDir "load\zero123"
$downloadArgs = @(
    "download",
    $RepoId,
    "--local-dir", $Zero123Dir,
    "--include", "stable_zero123.ckpt",
    "--include", "sd-objaverse-finetune-c_concat-256.yaml"
)

Write-Host "python -m pip install `"huggingface_hub<1.0`""
Write-Host "huggingface-cli $($downloadArgs -join ' ')"
if ($DryRun) {
    exit 0
}

New-Item -ItemType Directory -Force -Path $Zero123Dir | Out-Null
& python -m pip install "huggingface_hub<1.0"
if ($HuggingFaceToken -ne "") {
    $env:HF_TOKEN = $HuggingFaceToken
}
if (Get-Command hf -ErrorAction SilentlyContinue) {
    & hf @downloadArgs
}
else {
    & huggingface-cli @downloadArgs
}
Write-Host "Zero123 weights are ready in $Zero123Dir"
