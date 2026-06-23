param(
    [string]$ThreeStudioDir = "",
    [string]$TorchIndexUrl = "https://download.pytorch.org/whl/cu118",
    [switch]$SkipTorch,
    [switch]$UseBuildIsolation,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($ThreeStudioDir -eq "") {
    $ThreeStudioDir = Join-Path $ProjectRoot "external\threestudio"
}

if (-not (Test-Path $ThreeStudioDir)) {
    $cloneArgs = @("clone", "https://github.com/threestudio-project/threestudio.git", $ThreeStudioDir)
    Write-Host "git $($cloneArgs -join ' ')"
    if (-not $DryRun) {
        & git @cloneArgs
    }
}

$commands = @()
$commands += "python -m pip install --upgrade pip"
$commands += "python -m pip install --upgrade `"setuptools<70`" wheel packaging cmake ninja pybind11"
if (-not $SkipTorch) {
    $commands += "python -m pip install torch torchvision --index-url $TorchIndexUrl"
}
$commands += "python -c `"import sys, torch; print('Python:', sys.version.replace(chr(10), ' ')); print('Torch:', torch.__version__, 'CUDA:', torch.version.cuda); print('WARNING: Python 3.12 detected. threestudio and nerfacc v0.5.2 are more reliable with Python 3.10.') if sys.version_info[:2] >= (3, 12) else None`""
if ($UseBuildIsolation) {
    $commands += "python -m pip install -r requirements.txt"
}
else {
    $commands += "python -m pip install --no-build-isolation -r requirements.txt"
}

Write-Host "ThreeStudio directory: $ThreeStudioDir"
foreach ($command in $commands) {
    Write-Host $command
}

if ($DryRun) {
    exit 0
}

Push-Location $ThreeStudioDir
try {
    & python -m pip install --upgrade pip
    & python -m pip install --upgrade "setuptools<70" wheel packaging cmake ninja pybind11
    if (-not $SkipTorch) {
        & python -m pip install torch torchvision --index-url $TorchIndexUrl
    }
    & python -c "import sys, torch; print('Python:', sys.version.replace(chr(10), ' ')); print('Torch:', torch.__version__, 'CUDA:', torch.version.cuda); print('WARNING: Python 3.12 detected. threestudio and nerfacc v0.5.2 are more reliable with Python 3.10.') if sys.version_info[:2] >= (3, 12) else None"
    if ($UseBuildIsolation) {
        & python -m pip install -r requirements.txt
    }
    else {
        & python -m pip install --no-build-isolation -r requirements.txt
    }
}
finally {
    Pop-Location
}
