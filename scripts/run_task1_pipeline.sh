#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="${ROOT_DIR:-$PROJECT_ROOT}"
DATA_DIR="${DATA_DIR:-$ROOT_DIR/data}"
GPU="${GPU:-0}"
OBJECT_B_STEPS="${OBJECT_B_STEPS:-10000}"
OBJECT_C_STEPS="${OBJECT_C_STEPS:-600}"
SKIP_TRAINING="${SKIP_TRAINING:-0}"
DRY_RUN="${DRY_RUN:-0}"

OBJECT_C_INPUT="${OBJECT_C_INPUT:-"$DATA_DIR/stone_original.png"}"
OBJECT_C_PREPARED="${OBJECT_C_PREPARED:-"$DATA_DIR/stone_rgba.png"}"
OBJECT_C_PREP_ARGS="${OBJECT_C_PREP_ARGS:---remove-bg}"
COOKIE_PROMPT="a single handmade chocolate chip cookie, round slightly irregular shape, golden-brown baked surface, cracked crumb texture, raised chocolate chips, single object, centered, plain background, photorealistic, highly detailed, studio lighting"

echo "Task 1 data directory: $DATA_DIR"
echo "Object A: $DATA_DIR/car_point_origin_30000.ply"
echo "Scene:    $DATA_DIR/garden_point_30000.ply"
echo "Object B prompt: $COOKIE_PROMPT"
echo "Object C source: $OBJECT_C_INPUT"

read -r -a object_c_prep_args <<< "$OBJECT_C_PREP_ARGS"
prepare_cmd=(python "$PROJECT_ROOT/scripts/prepare_object_c_image.py" "$OBJECT_C_INPUT" "$OBJECT_C_PREPARED" "${object_c_prep_args[@]}")
printf '%q ' "${prepare_cmd[@]}"; echo
if [ "$DRY_RUN" != "1" ]; then
  "${prepare_cmd[@]}"
fi

if [ "$SKIP_TRAINING" != "1" ]; then
  train_b=(bash "$PROJECT_ROOT/scripts/train_object_b.sh")
  train_c=(bash "$PROJECT_ROOT/scripts/train_object_c.sh")
  export_b=(bash "$PROJECT_ROOT/scripts/export_object_b.sh")
  export_c=(bash "$PROJECT_ROOT/scripts/export_object_c.sh")

  echo "PROMPT=\"$COOKIE_PROMPT\" GPU=$GPU MAX_STEPS=$OBJECT_B_STEPS ${train_b[*]}"
  echo "IMAGE_PATH=\"$OBJECT_C_PREPARED\" GPU=$GPU MAX_STEPS=$OBJECT_C_STEPS ${train_c[*]}"
  echo "GPU=$GPU ${export_b[*]}"
  echo "GPU=$GPU ${export_c[*]}"

  if [ "$DRY_RUN" != "1" ]; then
    PROMPT="$COOKIE_PROMPT" GPU="$GPU" MAX_STEPS="$OBJECT_B_STEPS" "${train_b[@]}"
    IMAGE_PATH="$OBJECT_C_PREPARED" GPU="$GPU" MAX_STEPS="$OBJECT_C_STEPS" "${train_c[@]}"
    GPU="$GPU" "${export_b[@]}"
    GPU="$GPU" "${export_c[@]}"
  fi
fi

echo "After exporting OBJ meshes, compose the final garden scene in Blender:"
echo "blender --background --python scripts/compose_task1_scene.py -- --garden-ply $DATA_DIR/garden_point_30000.ply --car-ply $DATA_DIR/car_point_origin_30000.ply --object-c-image $OBJECT_C_PREPARED"
