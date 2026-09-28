"""Stylized boulders: chunky faceted planes, bevelled edges that catch
painted light, cool grey-blue stone with warm lights and mossy tops.
Outputs rock_a/b/c.glb (single boulders) and rock_cluster.glb (the
gatherable stone node) plus rock_pebbles.glb (depleted leftover)."""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # must precede bmesh / mathutils when run as a module
import bmesh
from mathutils import Vector, noise

from lib import common, paint_bake, preview

STONE = (0.5, 0.53, 0.64)
STONE_WARM = (0.68, 0.63, 0.58)
MOSS = (0.35, 0.58, 0.18)
MOSS_LIGHT = (0.62, 0.78, 0.25)


def boulder(name, seed, size=(1.0, 0.85, 0.6), subdiv=1, jag=0.3, moss=True):
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv + 1, radius=0.5)
    for v in bm.verts:
        n = noise.noise(v.co * 2.3 + Vector((seed * 1.7, seed * 0.3, seed * 2.9)))
        v.co *= 1.0 + n * jag + rng.uniform(-0.05, 0.05)
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    # Chisel: slice off caps with random planes for big flat facets.
    for i in range(7):
        direction = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 1))).normalized()
        extent = max(abs(direction.x) * size[0], abs(direction.y) * size[1], abs(direction.z) * size[2]) * 0.5
        point = direction * extent * rng.uniform(0.62, 0.82)
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        result = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=point, plane_no=direction, clear_outer=True)
        edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    # Flatten the bottom so it sits on the ground.
    for v in bm.verts:
        if v.co.z < -size[2] * 0.15:
            v.co.z = -size[2] * 0.15 + (v.co.z + size[2] * 0.15) * 0.15
    obj = common.mesh_object(name, bm)
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.045
    bev.segments = 2
    bev.limit_method = "ANGLE"
    bev.angle_limit = math.radians(25)
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj, auto_angle=22)
    # Sit on z = 0.
    lowest = min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.z -= lowest

    top = max(v.co.z for v in obj.data.vertices)
    use_moss = moss

    def colour(pos, normal):
        n = noise.noise(pos * 3.1 + Vector((seed, seed * 2, 0)))
        base = common.lerp(STONE, STONE_WARM, max(0.0, min(1.0, 0.5 + n * 0.8)))
        # Moss creeps over the upper, up-facing surfaces with a noisy edge.
        moss = (normal.z - 0.72) * 5.0 + (pos.z / max(top, 0.01) - 0.62) * 3.0 + n * 1.5
        moss = max(0.0, min(1.0, moss)) if use_moss else 0.0
        green = common.lerp(MOSS, MOSS_LIGHT, max(0.0, min(1.0, 0.5 + n)))
        return common.lerp(base, green, moss)

    common.color_by(obj, colour)
    return obj


def build():
    common.reset(seed=7)
    outputs = []
    specs = [("rock_a", 11, (1.3, 1.0, 0.75)), ("rock_b", 23, (1.0, 0.9, 0.9)), ("rock_c", 37, (1.4, 0.8, 0.55))]
    for name, seed, size in specs:
        obj = boulder(name, seed, size)
        paint_bake.paint(obj, size=512, ao_distance=0.3, edge_strength=0.45, edge_radius=0.04)
        common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), [obj])
        outputs.append(obj)
        obj.hide_render = True

    # Gatherable cluster: one big boulder and two smaller ones.
    common.reset(seed=8)
    parts = []
    for i, (seed, size, offset, scale) in enumerate([
        (51, (1.3, 1.0, 0.8), (0, 0, 0), 1.25),
        (52, (1.0, 0.9, 0.8), (0.75, 0.45, 0), 0.7),
        (53, (1.2, 0.9, 0.6), (-0.7, 0.35, 0), 0.6),
    ]):
        part = boulder("part%d" % i, seed, size)
        part.scale = (scale, scale, scale)
        part.location = offset
        part.rotation_euler = (0, 0, seed * 0.7)
        common.apply_transform(part)
        common.select_only([part])
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        parts.append(part)
    cluster = common.join(parts, "rock_cluster")
    paint_bake.paint(cluster, size=1024, ao_distance=0.35, edge_strength=0.45, edge_radius=0.04)
    common.export_glb(os.path.join(common.OUT_DIR, "rock_cluster.glb"), [cluster])
    preview.render([cluster], "rock_cluster")
    print("rock_cluster tris:", common.triangle_count([cluster]))

    common.reset(seed=9)
    pebbles = []
    for i in range(4):
        p = boulder("pebble%d" % i, 70 + i, (1.0, 0.9, 0.6), subdiv=0)
        p.scale = (0.35, 0.35, 0.35)
        p.location = (math.cos(i * 1.7) * 0.5, math.sin(i * 1.7) * 0.5, 0)
        common.apply_transform(p)
        common.select_only([p])
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        pebbles.append(p)
    peb = common.join(pebbles, "rock_pebbles")
    paint_bake.paint(peb, size=256)
    common.export_glb(os.path.join(common.OUT_DIR, "rock_pebbles.glb"), [peb])


if __name__ == "__main__":
    build()
