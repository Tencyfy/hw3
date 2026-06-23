param(
    [string]$DataDir = "",
    [string]$OutputDir = "",
    [int]$GardenMaxPoints = 800000,
    [int]$CarMaxPoints = 350000,
    [double]$GardenSurfelSizeRatio = 0.0035,
    [double]$CarSurfelSizeRatio = 0.006
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($DataDir -eq "") {
    $DataDir = Join-Path $ProjectRoot "data"
}
if ($OutputDir -eq "") {
    $OutputDir = Join-Path $ProjectRoot "outputs\scene_meshes"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

& python (Join-Path $ProjectRoot "scripts\convert_3dgs_to_colored_mesh.py") `
    (Join-Path $DataDir "garden_point_30000.ply") `
    (Join-Path $OutputDir "garden_surfels.ply") `
    --max-points $GardenMaxPoints `
    --surfel-size-ratio $GardenSurfelSizeRatio `
    --min-opacity-percentile 5 `
    --crop-percentile 0.1

& python (Join-Path $ProjectRoot "scripts\convert_3dgs_to_colored_mesh.py") `
    (Join-Path $DataDir "car_point_origin_30000.ply") `
    (Join-Path $OutputDir "car_surfels.ply") `
    --max-points $CarMaxPoints `
    --surfel-size-ratio $CarSurfelSizeRatio `
    --min-opacity-percentile 5 `
    --crop-percentile 0.1

Write-Host "Scene meshes are ready:"
Write-Host (Join-Path $OutputDir "garden_surfels.ply")
Write-Host (Join-Path $OutputDir "car_surfels.ply")
