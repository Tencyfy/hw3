param(
    [string]$RootDir = "",
    [string]$Gpu = "0",
    [int]$ObjectBSteps = 10000,
    [int]$ObjectCSteps = 600,
    [switch]$SkipTraining,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($RootDir -eq "") {
    $RootDir = $ProjectRoot
}
$DataDir = Join-Path $RootDir "data"
$ObjectCInput = Join-Path $DataDir "stone_original.png"
$ObjectCPrepared = Join-Path $DataDir "stone_rgba.png"
$CookiePrompt = "a single handmade chocolate chip cookie, round slightly irregular shape, golden-brown baked surface, cracked crumb texture, raised chocolate chips, single object, centered, plain background, photorealistic, highly detailed, studio lighting"

Write-Host "Task 1 data directory: $DataDir"
Write-Host "Object A: $(Join-Path $DataDir 'car_point_origin_30000.ply')"
Write-Host "Scene:    $(Join-Path $DataDir 'garden_point_30000.ply')"
Write-Host "Object B prompt: $CookiePrompt"
Write-Host "Object C source: $ObjectCInput"

$prepareArgs = @(
    (Join-Path $ProjectRoot "scripts\prepare_object_c_image.py"),
    $ObjectCInput,
    $ObjectCPrepared,
    "--remove-bg"
)
Write-Host "python $($prepareArgs -join ' ')"
if (-not $DryRun) {
    & python @prepareArgs
}

if (-not $SkipTraining) {
    $trainB = Join-Path $ProjectRoot "scripts\train_object_b.ps1"
    $trainC = Join-Path $ProjectRoot "scripts\train_object_c.ps1"
    $exportB = Join-Path $ProjectRoot "scripts\export_object_b.ps1"
    $exportC = Join-Path $ProjectRoot "scripts\export_object_c.ps1"

    Write-Host "& $trainB -Prompt `"$CookiePrompt`" -Gpu $Gpu -MaxSteps $ObjectBSteps"
    Write-Host "& $trainC -ImagePath $ObjectCPrepared -Gpu $Gpu -MaxSteps $ObjectCSteps"
    Write-Host "& $exportB -Gpu $Gpu"
    Write-Host "& $exportC -Gpu $Gpu"

    if (-not $DryRun) {
        & $trainB -Prompt $CookiePrompt -Gpu $Gpu -MaxSteps $ObjectBSteps
        & $trainC -ImagePath $ObjectCPrepared -Gpu $Gpu -MaxSteps $ObjectCSteps
        & $exportB -Gpu $Gpu
        & $exportC -Gpu $Gpu
    }
}

Write-Host "After exporting OBJ meshes, compose the final garden scene in Blender:"
Write-Host "blender --background --python scripts/compose_task1_scene.py -- --garden-ply $DataDir\garden_point_30000.ply --car-ply $DataDir\car_point_origin_30000.ply --object-c-image $ObjectCPrepared"
