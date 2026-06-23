#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${DATA_DIR:-"$PROJECT_ROOT/data"}"
OUTPUT_DIR="${OUTPUT_DIR:-"$PROJECT_ROOT/outputs/scene_meshes"}"

GARDEN_MAX_POINTS="${GARDEN_MAX_POINTS:-800000}"
CAR_MAX_POINTS="${CAR_MAX_POINTS:-350000}"
GARDEN_SURFEL_SIZE_RATIO="${GARDEN_SURFEL_SIZE_RATIO:-0.0035}"
CAR_SURFEL_SIZE_RATIO="${CAR_SURFEL_SIZE_RATIO:-0.006}"

mkdir -p "$OUTPUT_DIR"

python "$PROJECT_ROOT/scripts/convert_3dgs_to_colored_mesh.py" \
  "$DATA_DIR/garden_point_30000.ply" \
  "$OUTPUT_DIR/garden_surfels.ply" \
  --max-points "$GARDEN_MAX_POINTS" \
  --surfel-size-ratio "$GARDEN_SURFEL_SIZE_RATIO" \
  --min-opacity-percentile 5 \
  --crop-percentile 0.1

python "$PROJECT_ROOT/scripts/convert_3dgs_to_colored_mesh.py" \
  "$DATA_DIR/car_point_origin_30000.ply" \
  "$OUTPUT_DIR/car_surfels.ply" \
  --max-points "$CAR_MAX_POINTS" \
  --surfel-size-ratio "$CAR_SURFEL_SIZE_RATIO" \
  --min-opacity-percentile 5 \
  --crop-percentile 0.1

echo "Scene meshes are ready:"
echo "$OUTPUT_DIR/garden_surfels.ply"
echo "$OUTPUT_DIR/car_surfels.ply"
