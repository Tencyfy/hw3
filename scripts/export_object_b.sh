#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THREESTUDIO_DIR="${THREESTUDIO_DIR:-"$PROJECT_ROOT/external/threestudio"}"
GPU="${GPU:-0}"
ISO_SURFACE_THRESHOLD="${ISO_SURFACE_THRESHOLD:-10.0}"
ISO_SURFACE_RESOLUTION="${ISO_SURFACE_RESOLUTION:-256}"

if [ ! -f "$THREESTUDIO_DIR/launch.py" ]; then
  echo "Cannot find threestudio at $THREESTUDIO_DIR. Run scripts/setup_threestudio.sh first." >&2
  exit 1
fi

if [ -z "${TRIAL_DIR:-}" ]; then
  SEARCH_ROOT="$PROJECT_ROOT/outputs/object_b/hw3-object-b-dreamfusion-sd"
  TRIAL_DIR="$(find "$SEARCH_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
fi

if [ -z "$TRIAL_DIR" ] || [ ! -d "$TRIAL_DIR" ]; then
  echo "Cannot find trial directory. Set TRIAL_DIR=/path/to/trial." >&2
  exit 1
fi

PARSED_CONFIG="$TRIAL_DIR/configs/parsed.yaml"
CHECKPOINT="$TRIAL_DIR/ckpts/last.ckpt"
if [ ! -f "$PARSED_CONFIG" ] || [ ! -f "$CHECKPOINT" ]; then
  echo "Missing parsed config or checkpoint in $TRIAL_DIR." >&2
  exit 1
fi

cd "$THREESTUDIO_DIR"
python launch.py \
  --config "$PARSED_CONFIG" \
  --export \
  --gpu "$GPU" \
  "resume=$CHECKPOINT" \
  "system.exporter_type=mesh-exporter" \
  "system.exporter.fmt=obj" \
  "system.geometry.isosurface_threshold=$ISO_SURFACE_THRESHOLD" \
  "system.geometry.isosurface_method=mc-cpu" \
  "system.geometry.isosurface_resolution=$ISO_SURFACE_RESOLUTION"
