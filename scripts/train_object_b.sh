#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THREESTUDIO_DIR="${THREESTUDIO_DIR:-"$PROJECT_ROOT/external/threestudio"}"
CONFIG="$PROJECT_ROOT/configs/object_b_dreamfusion_sd.yaml"
OUTPUT_ROOT="$PROJECT_ROOT/outputs/object_b"

PROMPT="${PROMPT:-a single handmade chocolate chip cookie, round slightly irregular shape, golden-brown baked surface, cracked crumb texture, raised chocolate chips, single object, centered, plain background, photorealistic, highly detailed, studio lighting}"
GPU="${GPU:-0}"
MAX_STEPS="${MAX_STEPS:-10000}"
WIDTH="${WIDTH:-64}"
HEIGHT="${HEIGHT:-64}"
SEED="${SEED:-42}"
SD_MODEL_PATH="${SD_MODEL_PATH:-./load/stable-diffusion-2-1-base}"
WANDB_ENABLE="${WANDB_ENABLE:-true}"
WANDB_PROJECT="${WANDB_PROJECT:-hw3-task1}"
WANDB_NAME="${WANDB_NAME:-object-b-cookie}"
WANDB_MODE="${WANDB_MODE:-offline}"
export WANDB_MODE

if [ ! -f "$THREESTUDIO_DIR/launch.py" ]; then
  echo "Cannot find threestudio at $THREESTUDIO_DIR. Run scripts/setup_threestudio.sh first." >&2
  exit 1
fi

cd "$THREESTUDIO_DIR"
python launch.py \
  --config "$CONFIG" \
  --train \
  --gpu "$GPU" \
  "system.prompt_processor.prompt=$PROMPT" \
  "trainer.max_steps=$MAX_STEPS" \
  "data.width=$WIDTH" \
  "data.height=$HEIGHT" \
  "seed=$SEED" \
  "exp_root_dir=$OUTPUT_ROOT" \
  "system.prompt_processor.pretrained_model_name_or_path=$SD_MODEL_PATH" \
  "system.guidance.pretrained_model_name_or_path=$SD_MODEL_PATH" \
  "system.loggers.wandb.enable=$WANDB_ENABLE" \
  "system.loggers.wandb.project=$WANDB_PROJECT" \
  "system.loggers.wandb.name=$WANDB_NAME"
