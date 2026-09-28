"""Shared steps for upgrading a KayKit adventurer into one of our kids:
import the rig, drop unused accessories, subdivide the skinned body for
rounder forms, enlarge the head (kid proportions), turn the atlas
colours into vertex colours, add rigid gear, paint-bake, export."""

import math
import os

import bpy  # noqa: F401  (must precede bmesh / mathutils)
import bmesh
from mathutils import Matrix, Vector

from lib import common, paint_bake


def load(path, drop):
    common.reset(12)
    bpy.ops.import_scene.gltf(filepath=path)
    rig = bpy.data.objects["Rig"]
    for obj in list(bpy.data.objects):
        if obj.name in drop or obj.name.startswith("Icosphere"):
            bpy.data.objects.remove(obj)
    rig.data.pose_position = "REST"
    return rig


def texture_to_attribute(obj):
    """Samples the object's atlas texture per face into the 'Col' attribute."""
    image = None
    for slot in obj.material_slots:
        if slot.material and slot.material.use_nodes:
            for node in slot.material.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image:
                    image = node.image
    mesh = obj.data
    attr = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    if image is None:
        return
    w, h = image.size
    pixels = list(image.pixels)
    uv = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        u = sum(uv[li].uv.x for li in poly.loop_indices) / poly.loop_total
        v = sum(uv[li].uv.y for li in poly.loop_indices) / poly.loop_total
        x = min(w - 1, max(0, int(u % 1.0 * w)))
        y = min(h - 1, max(0, int(v % 1.0 * h)))
        i = (y * w + x) * 4
        c = common.srgb(pixels[i:i + 3])
        for li in poly.loop_indices:
            attr.data[li].color = (*c, 1.0)
    mesh.color_attributes.active_color = attr


def recolor(obj, fn):
    """fn(linear_rgb, position, normal) -> sRGB colour or None to keep."""
    mesh = obj.data
    attr = mesh.color_attributes["Col"]
    for poly in mesh.polygons:
        li0 = poly.loop_indices[0]
        current = tuple(attr.data[li0].color[:3])
        new = fn(current, poly.center, poly.normal)
        if new is not None:
            lin = common.srgb(new)
            for li in poly.loop_indices:
                attr.data[li].color = (*lin, 1.0)


def subdivide_skinned(obj, levels=1):
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    mod.use_limit_surface = True
    common.select_only([obj])
    bpy.ops.object.modifier_move_to_index(modifier="Subsurf", index=0)
    bpy.ops.object.modifier_apply(modifier="Subsurf")
    common.shade_smooth(obj)


def bone_head(rig, name):
    return rig.matrix_world @ rig.data.bones[name].head_local


def scale_by_weight(obj, rig, bone, factor, pivot_offset=(0, 0, 0)):
    """Scales vertices bound to `bone` (by weight) around the bone head."""
    group = obj.vertex_groups.get(bone)
    if group is None:
        return
    pivot = bone_head(rig, bone) + Vector(pivot_offset)
    for v in obj.data.vertices:
        w = 0.0
        for g in v.groups:
            if g.group == group.index:
                w = g.weight
        if w > 0.0:
            s = 1.0 + (factor - 1.0) * w
            v.co = pivot + (v.co - pivot) * s


def scale_object_around(obj, pivot, factor):
    """Scales a bone-parented rigid accessory around a world pivot."""
    mw = obj.matrix_world.copy()
    t = Matrix.Translation(pivot) @ Matrix.Scale(factor, 4) @ Matrix.Translation(-pivot)
    obj.matrix_world = t @ mw


def rigid_part(obj, rig, bone):
    """Binds a new mesh fully to one bone (for joining into the body)."""
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


def paint_and_export(rig, meshes, name, **paint):
    params = dict(size=1024, ao_distance=0.18, ao_strength=0.55, edge_strength=0.35, edge_radius=0.015,
                  noise_scale=6.0, stroke_strength=0.05, light=(1.12, 1.05, 0.98), shadow=(0.5, 0.45, 0.66))
    params.update(paint)
    for mesh in meshes:
        paint_bake.paint(mesh, source="attribute", **params)
    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), [rig] + meshes, animations=True)
    print(name, "tris:", common.triangle_count(meshes))


def tube(points, radii, name, levels=1):
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in points]
    for a, b in zip(verts, verts[1:]):
        bm.edges.new((a, b))
    obj = common.mesh_object(name, bm)
    obj.modifiers.new("Skin", "SKIN")
    bm2 = bmesh.new()
    bm2.from_mesh(obj.data)
    bm2.verts.ensure_lookup_table()
    layer = bm2.verts.layers.skin.verify()
    for v, r in zip(bm2.verts, radii):
        v[layer].radius = (r, r)
    bm2.verts[0][layer].use_root = True
    bm2.to_mesh(obj.data)
    bm2.free()
    if levels:
        sub = obj.modifiers.new("Sub", "SUBSURF")
        sub.levels = levels
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    return obj


def rounded_box(size, location, bevel=0.04, name="box"):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(location)
    obj = common.mesh_object(name, bm)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 3
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj, auto_angle=40)
    return obj
