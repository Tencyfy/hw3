#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THREESTUDIO_DIR="${THREESTUDIO_DIR:-"$PROJECT_ROOT/external/threestudio"}"
ZERO123_DIR="$THREESTUDIO_DIR/load/zero123"
REPO_ID="${REPO_ID:-stabilityai/stable-zero123}"

if [ ! -f "$THREESTUDIO_DIR/launch.py" ]; then
  echo "Cannot find threestudio at $THREESTUDIO_DIR. Run scripts/setup_threestudio.sh first." >&2
  exit 1
fi

mkdir -p "$ZERO123_DIR"
python -m pip install "huggingface_hub<1.0"

if [ -n "${HF_TOKEN:-}" ]; then
  export HF_TOKEN
fi

if command -v hf >/dev/null 2>&1; then
  hf download "$REPO_ID" \
    --local-dir "$ZERO123_DIR" \
    --include stable_zero123.ckpt \
    --include sd-objaverse-finetune-c_concat-256.yaml
else
  huggingface-cli download "$REPO_ID" \
    --local-dir "$ZERO123_DIR" \
    --include stable_zero123.ckpt \
    --include sd-objaverse-finetune-c_concat-256.yaml
fi

echo "Zero123 weights are ready in $ZERO123_DIR"
