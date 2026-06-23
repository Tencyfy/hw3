# HW3 Task 1: Object Generation and Scene Composition

This repository implements Task 1 of DL HW3. The current experiment uses:

- Object A: truck/car asset from `data/car_point_origin_30000.ply`
- Object B: text-to-3D chocolate chip cookie generated with threestudio DreamFusion / SDS
- Object C: single-image-to-3D stone stack generated from `data/stone_original.png` with Stable Zero123
- Background scene: garden asset from `data/garden_point_30000.ply`
- Final rendering: Blender composition with Garden, Object A, Object B, and Object C

The final technical report is:

```text
reports/task1_object_b_c_scene_report.md
```

The final scene fusion result image is:

```text
reports/Blender_result.png
```

## Repository Structure

```text
configs/
  object_b_dreamfusion_sd.yaml       # DreamFusion/SDS config for Object B
  object_c_stable_zero123.yaml       # Stable Zero123 config for Object C

data/
  car_point_origin_30000.ply         # Object A 3DGS PLY
  garden_point_30000.ply             # Garden scene 3DGS PLY
  stone_original.png                 # Original Object C image
  stone_rgba.png                     # Prepared RGBA Object C image

scripts/
  setup_threestudio.*                # Clone and install threestudio dependencies
  download_zero123_weights.*         # Download Stable Zero123 weights
  prepare_object_c_image.py          # Remove background and create square RGBA input
  train_object_b.*                   # Train Object B
  export_object_b.*                  # Export Object B OBJ
  train_object_c.*                   # Train Object C
  export_object_c.*                  # Export Object C OBJ
  convert_3dgs_to_colored_mesh.py    # Convert 3DGS PLY to colored surfel mesh
  prepare_scene_meshes.*             # Prepare Garden/Object A surfel meshes
  compose_task1_scene.py             # Blender scene composition and video rendering
  run_task1_pipeline.*               # Convenience wrapper for the full pipeline

object_B/                            # Object B result images and WandB screenshots
object_C/                            # Object C result images and WandB screenshots
reports/                             # Markdown report and final scene result image
requirements.txt                     # Utility dependencies for local scripts
environment.yml                      # Reference conda environment
```

## Environment

The recommended training environment is Linux with CUDA, Python 3.10, PyTorch CUDA 11.8, and threestudio.

Create and activate a conda environment:

```bash
conda create -n dl_hw3 python=3.10 -y
conda activate dl_hw3
```

Install PyTorch CUDA 11.8:

```bash
python -m pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 \
  --index-url https://download.pytorch.org/whl/cu118
```

Install local utility dependencies:

```bash
cd ~/DL_HW3
python -m pip install -r requirements.txt
```

Install threestudio and its CUDA extensions:

```bash
cd ~/DL_HW3

export CUDA_HOME=$CONDA_PREFIX
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$CUDA_HOME/lib:$CUDA_HOME/lib64:$LD_LIBRARY_PATH
export LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$CUDA_HOME/lib:$CUDA_HOME/lib64:$LIBRARY_PATH

SKIP_TORCH=1 bash scripts/setup_threestudio.sh
```

Check the key CUDA/threestudio dependencies:

```bash
python -c "import torch; import nerfacc; import tinycudann; import nvdiffrast.torch; print('deps ok')"
```

If the server has multiple CUDA toolkits, make sure `nvcc --version` matches the CUDA version used by PyTorch. In this experiment the stable setup used PyTorch CUDA 11.8.

## Model Weights

### Stable Zero123

Download the Stable Zero123 checkpoint and config:

```bash
cd ~/DL_HW3
bash scripts/download_zero123_weights.sh
```

Expected files:

```text
external/threestudio/load/zero123/stable_zero123.ckpt
external/threestudio/load/zero123/sd-objaverse-finetune-c_concat-256.yaml
```

### Stable Diffusion 2.1 Base

Object B uses a local Stable Diffusion 2.1 base cache. The config points to:

```text
external/threestudio/load/stable-diffusion-2-1-base
```

If direct Hugging Face access is blocked, download a compatible mirror repo to that directory, for example:

```bash
export HF_ENDPOINT=https://hf-mirror.com

python - <<'PY'
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="Manojb/stable-diffusion-2-1-base",
    local_dir="/home/fuchenxi/DL_HW3/external/threestudio/load/stable-diffusion-2-1-base",
    local_dir_use_symlinks=False,
    resume_download=True,
    allow_patterns=[
        "model_index.json",
        "scheduler/*",
        "tokenizer/*",
        "text_encoder/*",
        "unet/*",
        "vae/*",
        "feature_extractor/*",
    ],
)
PY
```

If threestudio reports that `tokenizer/config.json` is missing, copy the tokenizer config:

```bash
cp external/threestudio/load/stable-diffusion-2-1-base/tokenizer/tokenizer_config.json \
   external/threestudio/load/stable-diffusion-2-1-base/tokenizer/config.json
```

## Object B: Text-to-3D Cookie

Prompt:

```text
a single handmade chocolate chip cookie, round slightly irregular shape, golden-brown baked surface, cracked crumb texture, raised chocolate chips, single object, centered, plain background, photorealistic, highly detailed, studio lighting
```

Train Object B on physical GPU 1:

```bash
cd ~/DL_HW3
conda activate dl_hw3

export CUDA_HOME=$CONDA_PREFIX
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$CUDA_HOME/lib:$CUDA_HOME/lib64:$LD_LIBRARY_PATH
export LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$CUDA_HOME/lib:$CUDA_HOME/lib64:$LIBRARY_PATH

WANDB_MODE=offline \
WANDB_PROJECT=hw3-task1 \
WANDB_NAME=object-b-cookie-final \
CUDA_VISIBLE_DEVICES=1 GPU=0 MAX_STEPS=5000 \
bash scripts/train_object_b.sh
```

Export Object B:

```bash
CUDA_VISIBLE_DEVICES=1 GPU=0 bash scripts/export_object_b.sh
```

## Object C: Single-Image-to-3D Stone Stack

Prepare the input image:

```bash
cd ~/DL_HW3
python scripts/prepare_object_c_image.py \
  data/stone_original.png \
  data/stone_rgba.png \
  --remove-bg
```

Train Object C. In the current experiment, Object C was trained with `MAX_STEPS=300` because of GPU memory limits:

```bash
cd ~/DL_HW3
conda activate dl_hw3

export CUDA_HOME=$CONDA_PREFIX
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$CUDA_HOME/lib:$CUDA_HOME/lib64:$LD_LIBRARY_PATH
export LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$CUDA_HOME/lib:$CUDA_HOME/lib64:$LIBRARY_PATH

WANDB_MODE=offline \
WANDB_PROJECT=hw3-task1 \
WANDB_NAME=object-c-stone-final \
CUDA_VISIBLE_DEVICES=7 GPU=0 IMAGE_PATH=~/DL_HW3/data/stone_rgba.png MAX_STEPS=300 \
bash scripts/train_object_c.sh
```

Export Object C:

```bash
CUDA_VISIBLE_DEVICES=7 GPU=0 bash scripts/export_object_c.sh
```

## WandB Logging

The training scripts enable WandB by default. Offline mode is recommended when the server network is unstable:

```bash
WANDB_MODE=offline
```

After training, sync offline runs if needed:

```bash
wandb sync wandb/offline-run-*
```

For online logging:

```bash
wandb login

WANDB_MODE=online \
WANDB_PROJECT=hw3-task1 \
WANDB_NAME=object-b-cookie-final \
CUDA_VISIBLE_DEVICES=1 GPU=0 MAX_STEPS=5000 \
bash scripts/train_object_b.sh
```

The report uses screenshots saved in:

```text
object_B/
object_C/
```

## Prepare Dense Garden/Object A Surfel Meshes

Blender cannot directly render 3DGS with native Gaussian splatting quality. For Blender composition, convert the Garden and Object A PLY files into vertex-colored surfel meshes:

```bash
cd ~/DL_HW3

GARDEN_MAX_POINTS=1500000 \
CAR_MAX_POINTS=700000 \
GARDEN_SURFEL_SIZE_RATIO=0.006 \
CAR_SURFEL_SIZE_RATIO=0.01 \
bash scripts/prepare_scene_meshes.sh
```

Expected outputs:

```text
outputs/scene_meshes/garden_surfels.ply
outputs/scene_meshes/car_surfels.ply
```

## Blender Scene Composition

Find the latest exported Object B and Object C meshes:

```bash
cd ~/DL_HW3

COOKIE_OBJ=$(find outputs/object_b -type f -name "*.obj" | sort | tail -n 1)
STONE_OBJ=$(find outputs/object_c -type f -name "*.obj" | sort | tail -n 1)

echo "$COOKIE_OBJ"
echo "$STONE_OBJ"
```

Render the final scene:

```bash
~/DL_HW3/external/blender-4.0.2-linux-x64/blender --background --python scripts/compose_task1_scene.py -- \
  --garden-ply data/garden_point_30000.ply \
  --car-ply data/car_point_origin_30000.ply \
  --garden-mesh outputs/scene_meshes/garden_surfels.ply \
  --car-mesh outputs/scene_meshes/car_surfels.ply \
  --cookie-obj "$COOKIE_OBJ" \
  --object-c-obj "$STONE_OBJ" \
  --object-c-image data/stone_rgba.png \
  --output-blend outputs/task1_scene_final.blend \
  --output-video outputs/task1_flythrough_final.mp4 \
  --render-video
```

Expected final outputs:

```text
outputs/task1_scene_final.blend
outputs/task1_flythrough_final.mp4
reports/Blender_result.png
```

## Convenience Full-Pipeline Command

The wrapper script prints and optionally runs the standard Task 1 pipeline:

```bash
cd ~/DL_HW3

DRY_RUN=1 SKIP_TRAINING=1 bash scripts/run_task1_pipeline.sh
```

Run the full pipeline on one visible GPU:

```bash
CUDA_VISIBLE_DEVICES=0 GPU=0 OBJECT_B_STEPS=5000 OBJECT_C_STEPS=300 \
bash scripts/run_task1_pipeline.sh
```

For final experiments, running Object B and Object C separately on different GPUs is recommended.

## Notes and Limitations

- Object B uses SDS guidance, so `train/loss_sds` is noisy and not expected to decrease monotonically.
- Object C uses a single image, so geometry is less reliable than multi-view reconstruction.
- The Blender Garden/Object A result is a colored surfel approximation of 3DGS, not native Gaussian splatting.
- If exported OBJ files have no `.mtl` or texture maps, `compose_task1_scene.py` assigns procedural cookie/stone materials for visualization.
- Large files in `outputs/` can take many GB. Keep checkpoints, exported OBJ files, final videos, WandB screenshots, and the report; intermediate validation videos can be removed if disk space is limited.

