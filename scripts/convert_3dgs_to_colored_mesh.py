#!/usr/bin/env python
"""Convert a 3D Gaussian Splatting PLY into a Blender-friendly colored mesh.

This script creates a vertex-colored surfel mesh: each sampled Gaussian center
becomes a small colored quad oriented by the stored normal when available. It is
not a full 3DGS renderer, but it is much smoother in Blender than representing
points as cubes.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

SH_C0 = 0.28209479177387814


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_ply", type=Path)
    parser.add_argument("output_ply", type=Path)
    parser.add_argument("--max-points", type=int, default=250_000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--surfel-size", type=float, default=0.006)
    parser.add_argument(
        "--surfel-size-ratio",
        type=float,
        default=0.0,
        help="Use bbox_extent * ratio as surfel size. This survives later Blender normalization better than an absolute size.",
    )
    parser.add_argument("--size-from-gaussian-scale", action="store_true")
    parser.add_argument("--min-opacity-percentile", type=float, default=10.0)
    parser.add_argument("--crop-percentile", type=float, default=0.5)
    parser.add_argument("--flip-normals", action="store_true")
    return parser.parse_args()


def read_gaussian_ply(path: Path):
    with path.open("rb") as f:
        header_lines = []
        while True:
            line = f.readline()
            if not line:
                raise ValueError(f"Invalid PLY header in {path}")
            decoded = line.decode("ascii", errors="replace").strip()
            header_lines.append(decoded)
            if decoded == "end_header":
                break

        vertex_count = 0
        properties = []
        in_vertex = False
        for line in header_lines:
            parts = line.split()
            if len(parts) >= 3 and parts[:2] == ["element", "vertex"]:
                vertex_count = int(parts[2])
                in_vertex = True
            elif len(parts) >= 2 and parts[0] == "element" and parts[1] != "vertex":
                in_vertex = False
            elif in_vertex and len(parts) == 3 and parts[0] == "property":
                properties.append((parts[1], parts[2]))

        dtype_map = {
            "float": "<f4",
            "float32": "<f4",
            "double": "<f8",
            "uchar": "u1",
            "uint8": "u1",
            "int": "<i4",
            "int32": "<i4",
            "uint": "<u4",
            "uint32": "<u4",
        }
        dtype = np.dtype([(name, dtype_map[kind]) for kind, name in properties])
        data = np.fromfile(f, dtype=dtype, count=vertex_count)
    return data


def sigmoid(x):
    return 1.0 / (1.0 + np.exp(-np.clip(x, -60.0, 60.0)))


def select_points(data, args):
    names = set(data.dtype.names)
    mask = np.ones(len(data), dtype=bool)

    xyz = np.stack([data["x"], data["y"], data["z"]], axis=1).astype(np.float32)
    finite = np.isfinite(xyz).all(axis=1)
    mask &= finite

    if args.crop_percentile > 0:
        lo = np.percentile(xyz[finite], args.crop_percentile, axis=0)
        hi = np.percentile(xyz[finite], 100.0 - args.crop_percentile, axis=0)
        mask &= ((xyz >= lo) & (xyz <= hi)).all(axis=1)

    if "opacity" in names and args.min_opacity_percentile > 0:
        alpha = sigmoid(data["opacity"].astype(np.float32))
        threshold = np.percentile(alpha[mask], args.min_opacity_percentile)
        mask &= alpha >= threshold

    idx = np.flatnonzero(mask)
    if len(idx) > args.max_points:
        rng = np.random.default_rng(args.seed)
        idx = rng.choice(idx, size=args.max_points, replace=False)
        idx.sort()
    return data[idx]


def colors_from_sh(data):
    names = set(data.dtype.names)
    if {"f_dc_0", "f_dc_1", "f_dc_2"}.issubset(names):
        rgb = np.stack([data["f_dc_0"], data["f_dc_1"], data["f_dc_2"]], axis=1) * SH_C0 + 0.5
        rgb = np.clip(rgb, 0.0, 1.0)
    elif {"red", "green", "blue"}.issubset(names):
        rgb = np.stack([data["red"], data["green"], data["blue"]], axis=1) / 255.0
    else:
        rgb = np.ones((len(data), 3), dtype=np.float32) * 0.7
    return (rgb * 255.0 + 0.5).astype(np.uint8)


def normals_from_data(data, flip=False):
    names = set(data.dtype.names)
    if {"nx", "ny", "nz"}.issubset(names):
        normals = np.stack([data["nx"], data["ny"], data["nz"]], axis=1).astype(np.float32)
    else:
        normals = np.tile(np.array([[0.0, 0.0, 1.0]], dtype=np.float32), (len(data), 1))
    length = np.linalg.norm(normals, axis=1, keepdims=True)
    bad = length[:, 0] < 1e-6
    normals[bad] = np.array([0.0, 0.0, 1.0], dtype=np.float32)
    normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-6)
    if flip:
        normals *= -1.0
    return normals


def surfel_sizes(data, base_size: float, use_gaussian_scale: bool):
    names = set(data.dtype.names)
    if not use_gaussian_scale or not {"scale_0", "scale_1", "scale_2"}.issubset(names):
        return np.full(len(data), base_size, dtype=np.float32)
    # 3DGS stores log-scales. Clamp aggressively so outliers do not create huge quads.
    scales = np.exp(np.stack([data["scale_0"], data["scale_1"], data["scale_2"]], axis=1).astype(np.float32))
    size = np.median(scales, axis=1)
    size = np.clip(size, base_size * 0.35, base_size * 4.0)
    return size.astype(np.float32)


def build_surfels(data, args):
    xyz = np.stack([data["x"], data["y"], data["z"]], axis=1).astype(np.float32)
    colors = colors_from_sh(data)
    normals = normals_from_data(data, args.flip_normals)
    extent = float((xyz.max(axis=0) - xyz.min(axis=0)).max())
    base_size = extent * args.surfel_size_ratio if args.surfel_size_ratio > 0 else args.surfel_size
    sizes = surfel_sizes(data, base_size, args.size_from_gaussian_scale)

    ref = np.tile(np.array([[0.0, 0.0, 1.0]], dtype=np.float32), (len(data), 1))
    parallel = np.abs((normals * ref).sum(axis=1)) > 0.92
    ref[parallel] = np.array([0.0, 1.0, 0.0], dtype=np.float32)
    tangent = np.cross(normals, ref)
    tangent /= np.maximum(np.linalg.norm(tangent, axis=1, keepdims=True), 1e-6)
    bitangent = np.cross(normals, tangent)
    bitangent /= np.maximum(np.linalg.norm(bitangent, axis=1, keepdims=True), 1e-6)

    offsets = np.array([[-1, -1], [1, -1], [1, 1], [-1, 1]], dtype=np.float32)
    vertices = np.empty((len(data) * 4, 3), dtype=np.float32)
    vertex_colors = np.repeat(colors, 4, axis=0)
    faces = np.empty((len(data), 4), dtype=np.int32)
    for i, (center, t, b, size) in enumerate(zip(xyz, tangent, bitangent, sizes)):
        quad = center + (offsets[:, :1] * t + offsets[:, 1:] * b) * size
        start = i * 4
        vertices[start : start + 4] = quad
        faces[i] = [start, start + 1, start + 2, start + 3]
    return vertices, vertex_colors, faces


def write_ascii_ply(path: Path, vertices, colors, faces):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as f:
        f.write("ply\n")
        f.write("format ascii 1.0\n")
        f.write(f"element vertex {len(vertices)}\n")
        f.write("property float x\nproperty float y\nproperty float z\n")
        f.write("property uchar red\nproperty uchar green\nproperty uchar blue\n")
        f.write(f"element face {len(faces)}\n")
        f.write("property list uchar int vertex_indices\n")
        f.write("end_header\n")
        for (x, y, z), (r, g, b) in zip(vertices, colors):
            f.write(f"{x:.7g} {y:.7g} {z:.7g} {int(r)} {int(g)} {int(b)}\n")
        for a, b, c, d in faces:
            f.write(f"4 {int(a)} {int(b)} {int(c)} {int(d)}\n")


def main() -> None:
    args = parse_args()
    data = read_gaussian_ply(args.input_ply)
    selected = select_points(data, args)
    vertices, colors, faces = build_surfels(selected, args)
    write_ascii_ply(args.output_ply, vertices, colors, faces)
    print(f"Read {len(data):,} Gaussians")
    print(f"Selected {len(selected):,} surfels")
    print(f"Wrote {args.output_ply} with {len(vertices):,} vertices and {len(faces):,} faces")


if __name__ == "__main__":
    main()
