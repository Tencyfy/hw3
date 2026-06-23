#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THREESTUDIO_DIR="${THREESTUDIO_DIR:-"$PROJECT_ROOT/external/threestudio"}"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu118}"
SKIP_TORCH="${SKIP_TORCH:-0}"
NO_BUILD_ISOLATION="${NO_BUILD_ISOLATION:-1}"

if [ -z "${CUDA_HOME:-}" ]; then
  if command -v nvcc >/dev/null 2>&1; then
    CUDA_HOME="$(cd "$(dirname "$(command -v nvcc)")/.." && pwd)"
    export CUDA_HOME
  elif [ -d /usr/local/cuda ]; then
    CUDA_HOME="/usr/local/cuda"
    export CUDA_HOME
  elif [ -d /usr/local/cuda-12.1 ]; then
    CUDA_HOME="/usr/local/cuda-12.1"
    export CUDA_HOME
  elif [ -d /usr/local/cuda-11.8 ]; then
    CUDA_HOME="/usr/local/cuda-11.8"
    export CUDA_HOME
  fi
fi

if [ -n "${CUDA_HOME:-}" ]; then
  export PATH="$CUDA_HOME/bin:$PATH"
  export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
fi

if [ ! -f "$THREESTUDIO_DIR/launch.py" ]; then
  git clone https://github.com/threestudio-project/threestudio.git "$THREESTUDIO_DIR"
fi

cd "$THREESTUDIO_DIR"
python -m pip install --upgrade pip
python -m pip install --upgrade "setuptools<70" wheel packaging cmake ninja pybind11
if [ "$SKIP_TORCH" != "1" ]; then
  python -m pip install torch torchvision --index-url "$TORCH_INDEX_URL"
fi
python - <<'PY'
import sys
import torch
import os

major, minor = sys.version_info[:2]
if (major, minor) >= (3, 12):
    print(
        "WARNING: Python 3.12 detected. threestudio and nerfacc v0.5.2 are more reliable with Python 3.10.",
        file=sys.stderr,
    )
print("Python:", sys.version.replace("\n", " "))
print("Torch:", torch.__version__, "CUDA:", torch.version.cuda)
print("CUDA_HOME:", os.environ.get("CUDA_HOME", "<not set>"))
PY
if [ -z "${CUDA_HOME:-}" ] || [ ! -x "$CUDA_HOME/bin/nvcc" ]; then
  echo "ERROR: CUDA Toolkit with nvcc is required to build nerfacc, but CUDA_HOME/bin/nvcc was not found." >&2
  echo "Load/install CUDA Toolkit first, then rerun. Example: export CUDA_HOME=/usr/local/cuda-11.8" >&2
  exit 1
fi
if [ "$NO_BUILD_ISOLATION" = "1" ]; then
  python -m pip install --no-build-isolation -r requirements.txt
else
  python -m pip install -r requirements.txt
fi
