# 3D Gaussian Splatting Repository

包含两场景训练结果、数据集元数据与复现脚本。

## 目录结构

- `results/garden/` — 花园场景训练结果
- `results/truck/` — 卡车场景训练结果
- `dataset/garden/` — 花园 COLMAP SfM 数据（images_2 + sparse/0）
- `dataset/truck/` — 卡车 COLMAP SfM 数据（images + sparse/0）
- `src/` — 关键训练/渲染/评估源码

PLY 模型文件未包含，见百度网盘链接。

## 训练命令

```bash
# 环境（Conda / CUDA 11.8, RTX 4090）
conda activate gaussian_splatting

# Scene 2: Garden（Mip-NeRF 360）
python train.py -s dataset/garden \
    --model_path results/garden \
    --resolution 2 \
    --iterations 30000 \
    --test_iterations 7000 30000

# Object A: Truck（Tanks and Temples）
python train.py -s dataset/truck \
    --model_path results/truck \
    --iterations 30000 \
    --test_iterations 7000 30000
```

## 复现步骤

```bash
# 安装
conda env create --file environment.yml
conda activate gaussian_splatting

# 训练（以上命令）

# 渲染
python src/render.py -m results/garden
python src/render.py -m results/truck

# 计算指标
python src/metrics.py -m results/garden
python src/metrics.py -m results/truck
```

## 硬件配置

- NVIDIA RTX 4090 24 GB VRAM
- CUDA 11.8
- Python 3.8 + PyTorch 2.0.0

## 指标总览

| 场景 | 最终 PSNR (dB) | 最终 L1 Loss | 高斯点数 (30k it) |
|------|---------------|--------------|-------------------|
| Garden | 33.41 | 0.0087 | ~470,621 |
| Truck | 28.41 | 0.0096 | ~2,000,000 |


