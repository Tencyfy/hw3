#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THREESTUDIO_DIR="${THREESTUDIO_DIR:-"$PROJECT_ROOT/external/threestudio"}"
CONFIG="$PROJECT_ROOT/configs/object_c_stable_zero123.yaml"
OUTPUT_ROOT="$PROJECT_ROOT/outputs/object_c"

IMAGE_PATH="${IMAGE_PATH:-}"
GPU="${GPU:-0}"
MAX_STEPS="${MAX_STEPS:-600}"
SEED="${SEED:-42}"
DEFAULT_ELEVATION_DEG="${DEFAULT_ELEVATION_DEG:-5.0}"
DEFAULT_CAMERA_DISTANCE="${DEFAULT_CAMERA_DISTANCE:-3.8}"
WANDB_ENABLE="${WANDB_ENABLE:-true}"
WANDB_PROJECT="${WANDB_PROJECT:-hw3-task1}"
WANDB_NAME="${WANDB_NAME:-object-c-stone}"
WANDB_MODE="${WANDB_MODE:-offline}"
export WANDB_MODE

if [ -z "$IMAGE_PATH" ]; then
  echo "Set IMAGE_PATH to a square RGBA foreground PNG, for example: IMAGE_PATH=data/object_c_rgba.png bash scripts/train_object_c.sh" >&2
  exit 1
fi
if [ ! -f "$IMAGE_PATH" ]; then
  echo "Cannot find image: $IMAGE_PATH" >&2
  exit 1
fi
if [ ! -f "$THREESTUDIO_DIR/launch.py" ]; then
  echo "Cannot find threestudio at $THREESTUDIO_DIR. Run scripts/setup_threestudio.sh first." >&2
  exit 1
fi
if [ ! -f "$THREESTUDIO_DIR/load/zero123/stable_zero123.ckpt" ]; then
  echo "Cannot find Stable Zero123 weights. Run scripts/download_zero123_weights.sh first." >&2
  exit 1
fi

IMAGE_PATH="$(cd "$(dirname "$IMAGE_PATH")" && pwd)/$(basename "$IMAGE_PATH")"

cd "$THREESTUDIO_DIR"
python launch.py \
  --config "$CONFIG" \
  --train \
  --gpu "$GPU" \
  "data.image_path=$IMAGE_PATH" \
  "trainer.max_steps=$MAX_STEPS" \
  "seed=$SEED" \
  "exp_root_dir=$OUTPUT_ROOT" \
  "data.default_elevation_deg=$DEFAULT_ELEVATION_DEG" \
  "data.default_camera_distance=$DEFAULT_CAMERA_DISTANCE" \
  "system.loggers.wandb.enable=$WANDB_ENABLE" \
  "system.loggers.wandb.project=$WANDB_PROJECT" \
  "system.loggers.wandb.name=$WANDB_NAME"
