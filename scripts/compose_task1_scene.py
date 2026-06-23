#!/usr/bin/env python
"""Compose Task 1 assets in Blender and optionally render a fly-through video.

Run with Blender, for example:
blender --background --python scripts/compose_task1_scene.py -- \
  --garden-ply E:/DL_HW3/data/garden_point_30000.ply \
  --car-ply E:/DL_HW3/data/car_point_origin_30000.ply \
  --garden-mesh outputs/scene_meshes/garden_surfels.ply \
  --car-mesh outputs/scene_meshes/car_surfels.ply \
  --cookie-obj outputs/object_b/.../exports/mesh.obj \
  --object-c-obj outputs/object_c/.../exports/mesh.obj \
  --object-c-image E:/DL_HW3/data/stone_rgba.png \
  --output-blend outputs/task1_scene.blend \
  --output-video outputs/task1_flythrough.mp4
"""

from __future__ import annotations

import argparse
import math
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Vector

SH_C0 = 0.28209479177387814


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--garden-ply", type=Path, required=True)
    parser.add_argument("--car-ply", type=Path, required=True)
    parser.add_argument("--garden-mesh", type=Path, default=None)
    parser.add_argument("--car-mesh", type=Path, default=None)
    parser.add_argument("--cookie-obj", type=Path, default=None)
    parser.add_argument("--bacon-obj", type=Path, default=None)
    parser.add_argument("--bacon-image", type=Path, default=None)
    parser.add_argument("--object-c-obj", type=Path, default=None)
    parser.add_argument("--object-c-image", type=Path, default=None)
    parser.add_argument("--output-blend", type=Path, default=Path("outputs/task1_scene.blend"))
    parser.add_argument("--output-video", type=Path, default=Path("outputs/task1_flythrough.mp4"))
    parser.add_argument("--max-garden-points", type=int, default=12000)
    parser.add_argument("--max-car-points", type=int, default=6000)
    parser.add_argument("--render-video", action="store_true")
    parser.add_argument("--allow-proxies", action="store_true", default=True)
    return parser.parse_args(argv)


def read_gaussian_ply(path: Path, max_points: int):
    import numpy as np

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

    if len(data) > max_points:
        idx = np.linspace(0, len(data) - 1, max_points).astype(np.int64)
        data = data[idx]

    xyz = np.stack([data["x"], data["y"], data["z"]], axis=1).astype("float32")
    if {"f_dc_0", "f_dc_1", "f_dc_2"}.issubset(data.dtype.names):
        rgb = np.stack([data["f_dc_0"], data["f_dc_1"], data["f_dc_2"]], axis=1) * SH_C0 + 0.5
        rgb = np.clip(rgb, 0.0, 1.0).astype("float32")
    else:
        rgb = np.ones_like(xyz, dtype="float32") * 0.7
    return xyz, rgb


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def make_colored_cubes(name: str, points, colors, radius: float, location=(0, 0, 0), scale=1.0):
    verts = []
    faces = []
    face_point_ids = []
    cube_offsets = [
        (-1, -1, -1),
        (1, -1, -1),
        (1, 1, -1),
        (-1, 1, -1),
        (-1, -1, 1),
        (1, -1, 1),
        (1, 1, 1),
        (-1, 1, 1),
    ]
    cube_faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    loc = Vector(location)
    for point_id, p in enumerate(points):
        base = len(verts)
        center = Vector((float(p[0]), float(p[1]), float(p[2]))) * scale + loc
        for ox, oy, oz in cube_offsets:
            verts.append((center.x + ox * radius, center.y + oy * radius, center.z + oz * radius))
        for face in cube_faces:
            faces.append(tuple(base + i for i in face))
            face_point_ids.append(point_id)

    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    color_attr = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    for poly, point_id in zip(mesh.polygons, face_point_ids):
        color = colors[point_id]
        for loop_index in poly.loop_indices:
            color_attr.data[loop_index].color = (float(color[0]), float(color[1]), float(color[2]), 1.0)

    material = bpy.data.materials.new(name + "VertexColor")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    attr = nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    material.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    mesh.materials.append(material)

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def normalize_points(points, target_extent: float):
    import numpy as np

    mins = points.min(axis=0)
    maxs = points.max(axis=0)
    center = (mins + maxs) / 2.0
    extent = float((maxs - mins).max())
    scale = target_extent / extent if extent > 0 else 1.0
    return (points - center) * scale, scale


def import_obj(path: Path, name: str):
    if path is None or str(path).strip() in {"", "."} or not path.exists() or path.is_dir():
        return None
    if hasattr(bpy.ops.wm, "obj_import"):
        bpy.ops.wm.obj_import(filepath=str(path))
    else:
        bpy.ops.import_scene.obj(filepath=str(path))
    selected = list(bpy.context.selected_objects)
    if selected:
        obj = selected[0]
        obj.name = name
        return obj
    return None


def import_ply_mesh(path: Path, name: str):
    if path is None or str(path).strip() in {"", "."} or not path.exists() or path.is_dir():
        return None
    before = set(bpy.context.scene.objects)
    if hasattr(bpy.ops.wm, "ply_import"):
        bpy.ops.wm.ply_import(filepath=str(path))
    else:
        bpy.ops.import_mesh.ply(filepath=str(path))
    after = set(bpy.context.scene.objects)
    created = list(after - before)
    obj = created[0] if created else (bpy.context.object if bpy.context.object else None)
    if obj is None:
        return None
    obj.name = name
    ensure_vertex_color_material(obj, name + "_vertex_color")
    return obj


def ensure_vertex_color_material(obj, name: str):
    if not hasattr(obj.data, "color_attributes") or not obj.data.color_attributes:
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = (0.55, 0.55, 0.55, 1.0)
        obj.data.materials.append(mat)
        return mat
    color_name = obj.data.color_attributes[0].name
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    attr = nodes.new("ShaderNodeAttribute")
    attr.attribute_name = color_name
    if bsdf is not None:
        mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
        if "Emission Color" in bsdf.inputs:
            mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 0.45
        elif "Emission" in bsdf.inputs:
            mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Emission"])
    obj.data.materials.append(mat)
    return mat


def set_object_fit(obj, location, max_extent: float, rotation=(0, 0, 0)):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    dims = obj.dimensions
    largest = max(dims.x, dims.y, dims.z, 1e-6)
    factor = max_extent / largest
    obj.scale = (obj.scale.x * factor, obj.scale.y * factor, obj.scale.z * factor)
    obj.location = location
    obj.rotation_euler = rotation
    obj.select_set(False)


def assign_cookie_material(obj):
    mat = bpy.data.materials.new("Object_B_cookie_procedural")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (0.68, 0.42, 0.18, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.82
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 38.0
        noise.inputs["Detail"].default_value = 11.0
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.24
        ramp.color_ramp.elements[0].color = (0.42, 0.22, 0.08, 1.0)
        ramp.color_ramp.elements[1].position = 1.0
        ramp.color_ramp.elements[1].color = (0.95, 0.67, 0.28, 1.0)
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def assign_stone_material(obj):
    mat = bpy.data.materials.new("Object_C_stone_procedural")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (0.66, 0.66, 0.61, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.92
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 55.0
        noise.inputs["Detail"].default_value = 14.0
        noise.inputs["Roughness"].default_value = 0.62
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.18
        ramp.color_ramp.elements[0].color = (0.23, 0.22, 0.20, 1.0)
        ramp.color_ramp.elements[1].position = 1.0
        ramp.color_ramp.elements[1].color = (0.86, 0.85, 0.78, 1.0)
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def set_scene_fit(obj, target_extent: float, location=(0, 0, 0)):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    largest = max(obj.dimensions.x, obj.dimensions.y, obj.dimensions.z, 1e-6)
    factor = target_extent / largest
    obj.scale = (obj.scale.x * factor, obj.scale.y * factor, obj.scale.z * factor)
    obj.location = location
    obj.select_set(False)
    return factor


def create_cookie_proxy():
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=0.75, depth=0.16, location=(-1.8, 0.2, 0.45))
    cookie = bpy.context.object
    cookie.name = "Object_B_cookie_proxy"
    mat = bpy.data.materials.new("cookie_golden_brown")
    mat.diffuse_color = (0.62, 0.36, 0.12, 1.0)
    cookie.data.materials.append(mat)
    chip_mat = bpy.data.materials.new("cookie_chocolate_chips")
    chip_mat.diffuse_color = (0.12, 0.055, 0.025, 1.0)
    for i in range(18):
        angle = i * 2.399963
        radius = 0.18 + 0.48 * ((i * 37) % 100) / 100.0
        x = cookie.location.x + math.cos(angle) * radius
        y = cookie.location.y + math.sin(angle) * radius
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.045, location=(x, y, 0.55))
        chip = bpy.context.object
        chip.name = "cookie_chip"
        chip.scale.z = 0.35
        chip.data.materials.append(chip_mat)
    return cookie


def create_stone_proxy(image_path: Path | None):
    mat = bpy.data.materials.new("stone_material")
    mat.diffuse_color = (0.64, 0.64, 0.58, 1.0)
    if image_path and image_path.exists():
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(image_path))
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    for i in range(4):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0.1 + i * 0.12, -1.25 + i * 0.08, 0.45 + i * 0.05))
        stone = bpy.context.object
        stone.name = "Object_C_stone_proxy"
        stone.dimensions = (1.15 - i * 0.16, 0.42 - i * 0.04, 0.18 - i * 0.02)
        stone.location = (0.1 + i * 0.02, -1.25 + i * 0.02, 0.45 + i * 0.18)
        stone.rotation_euler = (0.12, 0.0, 0.08 + i * 0.13)
        stone.data.materials.append(mat)


def add_camera_and_lights(render_video: bool):
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 8))
    sun = bpy.context.object
    sun.name = "Task1_sun"
    sun.data.energy = 3.5
    bpy.ops.object.light_add(type="AREA", location=(0, -3.5, 5.0))
    area = bpy.context.object
    area.name = "Task1_soft_area"
    area.data.energy = 450
    area.data.size = 7.0
    bpy.ops.object.camera_add(location=(0, -8.0, 3.2), rotation=(math.radians(68), 0, 0))
    camera = bpy.context.object
    bpy.context.scene.camera = camera
    if render_video:
        bpy.context.scene.frame_start = 1
        bpy.context.scene.frame_end = 180
        for frame, loc, rot_z in [
            (1, (0, -8.0, 3.2), 0),
            (90, (5.5, -4.5, 2.6), math.radians(38)),
            (180, (-5.2, -4.0, 2.8), math.radians(-38)),
        ]:
            bpy.context.scene.frame_set(frame)
            camera.location = loc
            camera.rotation_euler = (math.radians(68), 0, rot_z)
            camera.keyframe_insert(data_path="location")
            camera.keyframe_insert(data_path="rotation_euler")


def main() -> None:
    args = parse_args()
    clear_scene()
    args.output_blend.parent.mkdir(parents=True, exist_ok=True)
    args.output_video.parent.mkdir(parents=True, exist_ok=True)

    garden_obj = import_ply_mesh(args.garden_mesh, "Scene_garden_colored_mesh") if args.garden_mesh else None
    if garden_obj is not None:
        set_scene_fit(garden_obj, 18.0)
    else:
        garden_points, garden_colors = read_gaussian_ply(args.garden_ply, args.max_garden_points)
        garden_points, _ = normalize_points(garden_points, 18.0)
        make_colored_cubes("Scene_garden_3DGS_preview", garden_points, garden_colors, radius=0.018)

    car_obj = import_ply_mesh(args.car_mesh, "Object_A_car_colored_mesh") if args.car_mesh else None
    if car_obj is not None:
        set_scene_fit(car_obj, 2.4, location=(2.2, 0.1, 0.5))
    else:
        car_points, car_colors = read_gaussian_ply(args.car_ply, args.max_car_points)
        car_points, _ = normalize_points(car_points, 2.4)
        make_colored_cubes("Object_A_car_3DGS_preview", car_points, car_colors, radius=0.025, location=(2.2, 0.1, 0.5))

    if args.cookie_obj and str(args.cookie_obj).strip() not in {"", "."}:
        cookie = import_obj(args.cookie_obj, "Object_B_cookie_mesh")
        if cookie is not None:
            set_object_fit(cookie, (-1.8, 0.2, 0.55), 1.5, rotation=(0, 0, math.radians(18)))
            assign_cookie_material(cookie)
        elif args.allow_proxies:
            create_cookie_proxy()
    elif args.allow_proxies:
        create_cookie_proxy()

    object_c_obj_path = args.object_c_obj or args.bacon_obj
    object_c_image_path = args.object_c_image or args.bacon_image
    if object_c_obj_path and str(object_c_obj_path).strip() not in {"", "."}:
        stone = import_obj(object_c_obj_path, "Object_C_stone_mesh")
        if stone is not None:
            set_object_fit(stone, (0.1, -1.25, 0.55), 1.6, rotation=(0, 0, math.radians(-20)))
            assign_stone_material(stone)
        elif args.allow_proxies:
            create_stone_proxy(object_c_image_path)
    elif args.allow_proxies:
        create_stone_proxy(object_c_image_path)

    add_camera_and_lights(args.render_video)
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [item.identifier for item in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    bpy.context.scene.render.resolution_x = 1280
    bpy.context.scene.render.resolution_y = 720
    bpy.context.scene.eevee.taa_render_samples = 64
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output_blend))

    if args.render_video:
        bpy.context.scene.render.filepath = str(args.output_video)
        bpy.context.scene.render.image_settings.file_format = "FFMPEG"
        bpy.context.scene.render.ffmpeg.format = "MPEG4"
        bpy.context.scene.render.ffmpeg.codec = "H264"
        bpy.ops.render.render(animation=True)


if __name__ == "__main__":
    main()
