"""Shared helpers for the procedural art scripts (run with Blender's bpy).

Every asset script builds its model from scratch (or from a vendored
KayKit rig), runs the painted bake, and exports a .glb into
game/assets/custom/. Scripts are deterministic: fixed random seeds.
"""

import math
import os
import random

import bpy  # must precede bmesh / mathutils when run as a module
import bmesh
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "game", "assets", "custom")
KAYKIT = os.path.join(ROOT, "game", "assets", "kaykit")
PREVIEW_DIR = os.environ.get("ART_PREVIEW_DIR", os.path.join(ROOT, "build", "art_previews"))


def reset(seed=1):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    random.seed(seed)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.threads_mode = "AUTO"
    scene.unit_settings.system = "METRIC"
    return scene


def select_only(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return link(bpy.data.objects.new(name, mesh))


def apply_all_modifiers(obj, keep=("ARMATURE",)):
    select_only([obj])
    for mod in list(obj.modifiers):
        if mod.type in keep:
            continue
        bpy.ops.object.modifier_apply(modifier=mod.name)


def apply_transform(obj):
    select_only([obj])
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def join(objects, name):
    objects = [o for o in objects if o is not None]
    select_only(objects)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def shade_smooth(obj, auto_angle=None):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if auto_angle is not None:
        select_only([obj])
        bpy.ops.object.shade_auto_smooth(angle=math.radians(auto_angle))


def srgb(c):
    """Palette colours are authored in sRGB; colour attributes are linear."""
    def ch(x):
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return tuple(ch(max(0.0, min(1.0, v))) for v in c[:3])


def set_color(obj, color, faces=None):
    """Writes a face-corner colour attribute 'Col' (the bake's base colour)."""
    mesh = obj.data
    attr = mesh.color_attributes.get("Col")
    if attr is None:
        attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        for i in range(len(attr.data)):
            attr.data[i].color = (1, 1, 1, 1)
    targets = range(len(mesh.polygons)) if faces is None else faces
    for f in targets:
        for li in mesh.polygons[f].loop_indices:
            attr.data[li].color = (*srgb(color), 1.0)
    mesh.color_attributes.active_color = attr


def color_by(obj, fn, smooth=True):
    """Colours the mesh: fn(position_local, normal) -> sRGB (r,g,b).

    smooth=True evaluates per vertex (soft painted transitions);
    smooth=False evaluates per face (crisp colour regions)."""
    mesh = obj.data
    attr = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    if smooth:
        per_vertex = [srgb(fn(v.co, v.normal)) for v in mesh.vertices]
        for loop in mesh.loops:
            attr.data[loop.index].color = (*per_vertex[loop.vertex_index], 1.0)
    else:
        for poly in mesh.polygons:
            c = srgb(fn(poly.center, poly.normal))
            for li in poly.loop_indices:
                attr.data[li].color = (*c, 1.0)
    mesh.color_attributes.active_color = attr


def grime(obj, colour, amount):
    """Blends `colour` (sRGB) over the existing 'Col' attribute:
    amount(position_local, normal) -> 0..1 per vertex. For painted dirt,
    wear, scuffs and mud on top of colours set by color_by/set_color."""
    mesh = obj.data
    attr = mesh.color_attributes.get("Col")
    if attr is None:
        return
    target = srgb(colour)
    weights = [max(0.0, min(1.0, amount(v.co, v.normal))) for v in mesh.vertices]
    for loop in mesh.loops:
        t = weights[loop.vertex_index]
        if t > 0.0:
            c = attr.data[loop.index].color
            attr.data[loop.index].color = (*(c[i] + (target[i] - c[i]) * t for i in range(3)), 1.0)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def voxel_remesh(obj, voxel=0.04, smooth_iterations=0):
    mod = obj.modifiers.new("Remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    mod.use_smooth_shade = True
    apply_all_modifiers(obj)
    if smooth_iterations:
        mod = obj.modifiers.new("Smooth", "SMOOTH")
        mod.iterations = smooth_iterations
        mod.factor = 0.6
        apply_all_modifiers(obj)


def decimate(obj, target_faces):
    faces = len(obj.data.polygons)
    if faces <= target_faces:
        return
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = target_faces / faces
    apply_all_modifiers(obj)


def displace_noise(obj, strength=0.1, scale=1.0, seed=0):
    tex = bpy.data.textures.new("noise_%d" % seed, "CLOUDS")
    tex.noise_scale = scale
    tex.noise_depth = 2
    mod = obj.modifiers.new("Displace", "DISPLACE")
    mod.texture = tex
    mod.strength = strength
    mod.mid_level = 0.5
    mod.texture_coords = "OBJECT"
    empty = bpy.data.objects.new("noise_offset_%d" % seed, None)
    link(empty)
    empty.location = (seed * 3.7, seed * 1.3, seed * 2.1)
    mod.texture_coords_object = empty
    apply_all_modifiers(obj)
    bpy.data.objects.remove(empty)


def metaball_object(name, elements, resolution=0.05, threshold=0.6):
    """elements: list of (location, radius, stiffness, type, size_vec)."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    for el in elements:
        loc, radius = el[0], el[1]
        stiffness = el[2] if len(el) > 2 else 2.0
        kind = el[3] if len(el) > 3 else "BALL"
        e = mb.elements.new(type=kind)
        e.co = loc
        e.radius = radius
        e.stiffness = stiffness
        if kind in ("ELLIPSOID", "CAPSULE", "CUBE") and len(el) > 4:
            e.size_x, e.size_y, e.size_z = el[4]
        if len(el) > 5:
            e.rotation = el[5]
    obj = link(bpy.data.objects.new(name, mb))
    bpy.context.view_layer.update()
    select_only([obj])
    bpy.ops.object.convert(target="MESH")
    result = bpy.context.view_layer.objects.active
    result.name = name
    return result


def export_glb(path, objects, animations=False, image_format="AUTO"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    select_only(objects)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_image_format=image_format,
        export_image_quality=92,
        export_animations=animations,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_all_influences=False,
        export_vertex_color="NONE",
    )
    print("exported", os.path.relpath(path, ROOT))


def triangle_count(objects):
    total = 0
    for obj in objects:
        if obj.type == "MESH":
            total += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return total
