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

from lib import common, detail, paint_bake, preview

STONE = (0.6, 0.57, 0.54)  # warm beige-grey (feature 031)
STONE_WARM = (0.78, 0.7, 0.58)
STONE_DARK = (0.34, 0.31, 0.3)
LICHEN = (0.82, 0.78, 0.55)
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


def _crack_planes(seed):
    rng = random.Random(seed * 7 + 3)
    planes = []
    for k in range(4):
        n = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 0.3))).normalized()
        planes.append((n, rng.uniform(-0.15, 0.15), 0.022 if k < 2 else 0.012, rng.uniform(0, 10)))
    return planes


def crack(p, seed, planes=None):
    """0 in a crack, 1 away from one: a few long, slightly jagged
    fissures where random planes cut the rock (main ones wider), each
    fading out along its length so it does not ring the whole stone.
    Returns (main, hairline)."""
    planes = planes or _crack_planes(seed)
    vals = []
    for n, d, w, o in planes:
        jag = noise.noise(p * 6.0 + Vector((o, 0, 0))) * 0.018 + noise.noise(p * 2.0 + Vector((0, o, 0))) * 0.05
        dist = abs(p.dot(n) - d + jag)
        fade = noise.noise(p * 1.4 + Vector((0, 0, o)))
        v = min(1.0, dist / w)
        if fade < -0.15:
            v = 1.0
        elif fade < 0.1:
            v = v + (1.0 - v) * (0.1 - fade) / 0.25
        vals.append(v)
    return min(vals[:2]), min(vals[2:])


def densify(obj, seed, moss=True, voxel=0.012, depth=0.014):
    """Turns a boulder() into a dense, detailed rock in place: its facets
    kept (simple subdivision), carved with fissures and hairline cracks,
    chipped edges, mossy cushions on top, lichen spots and speckle."""
    # Even, dense topology that keeps the facets: a coarse voxel remesh,
    # subdivided, then shrink-wrapped back onto the original boulder.
    target = obj.copy()
    target.data = obj.data.copy()
    obj.users_collection[0].objects.link(target)
    common.voxel_remesh(obj, voxel=voxel * 1.6, smooth_iterations=2)
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    wrap = obj.modifiers.new("Wrap", "SHRINKWRAP")
    wrap.target = target
    wrap.wrap_method = "NEAREST_SURFACEPOINT"
    common.apply_all_modifiers(obj)
    bpy.data.objects.remove(target)
    mesh = obj.data
    mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    top = max(v.co.z for v in mesh.vertices)
    off = Vector((seed, seed * 2, 0))
    planes = _crack_planes(seed)
    info = []
    for v in mesh.vertices:
        p = v.co.copy()
        big, fine = crack(p, seed, planes)
        ground = max(0.0, min(1.0, (p.z - 0.05) / 0.12))
        cut = ((1.0 - big) * depth + (1.0 - fine) * depth * 0.35) * ground
        n = noise.noise(p * 3.1 + off)
        m = (v.normal.z - 0.72) * 5.0 + (p.z / max(top, 0.01) - 0.62) * 3.0 + n * 1.5
        m += noise.noise(p * 5.0 + off) * 0.6
        m = max(0.0, min(1.0, m)) if moss else 0.0
        pit = 0.0
        v.co = p - v.normal * (cut + pit)
        info.append((big, fine, m))
    mesh.update()
    common.shade_smooth(obj, auto_angle=30)
    colours = []
    for v, (big, fine, m) in zip(mesh.vertices, info):
        pos, normal = v.co, v.normal
        n = noise.noise(pos * 3.1 + off)
        c = common.lerp(STONE, STONE_WARM, max(0.0, min(1.0, 0.5 + n * 0.8)))
        mottle = noise.noise(pos * 9.0 + off)
        c = common.lerp(c, STONE_WARM if mottle > 0 else STONE_DARK, abs(mottle) * 0.25)
        # Faint strata bands.
        band = math.sin(pos.z * 38.0 + noise.noise(pos * 2.0 + off) * 2.5)
        if band > 0.75:
            c = common.lerp(c, STONE_DARK, 0.12)
        c = common.lerp(STONE_DARK, c, 0.35 + 0.65 * min(big, 0.5 + 0.5 * fine))
        lich = noise.noise(pos * 4.5 + off * 3.0)
        if lich > 0.45 and normal.z > -0.2:
            c = common.lerp(c, LICHEN, min(1.0, (lich - 0.45) * 5.0) * 0.5)
        if m > 0:
            g = noise.noise(pos * 6.0 + off) * 0.5 + 0.5
            green = common.lerp(MOSS, MOSS_LIGHT, max(0.0, min(1.0, 0.3 + g * 0.8 + n * 0.3)))
            c = common.lerp(c, green, m)
        colours.append(c)
    col = mesh.color_attributes.get("Col")
    per_vertex = [common.srgb(c) for c in colours]
    for loop in mesh.loops:
        col.data[loop.index].color = (*per_vertex[loop.vertex_index], 1.0)
    return obj


SINGLES = [("rock_a", 11, (1.3, 1.0, 0.75)), ("rock_b", 23, (1.0, 0.9, 0.9)), ("rock_c", 37, (1.4, 0.8, 0.55))]
CLUSTER = [
    (51, (1.3, 1.0, 0.8), (0, 0, 0), 1.25),
    (52, (1.0, 0.9, 0.8), (0.75, 0.45, 0), 0.7),
    (53, (1.2, 0.9, 0.6), (-0.7, 0.35, 0), 0.6),
]


def build_single(name, seed, size):
    common.reset(seed=7)
    obj = boulder(name, seed, size)
    densify(obj, seed)
    detail.bake_prop([obj], name, 800, size=512, ray=0.06, ao_distance=0.3, edge_strength=0.45, edge_radius=0.04,
                     cavity=0.6)


def build_cluster():
    common.reset(seed=8)
    parts = []
    for i, (seed, size, offset, scale) in enumerate(CLUSTER):
        part = boulder("part%d" % i, seed, size)
        densify(part, seed, voxel=0.012 / scale, depth=0.014 / scale)
        part.scale = (scale, scale, scale)
        part.location = offset
        part.rotation_euler = (0, 0, seed * 0.7)
        common.apply_transform(part)
        common.select_only([part])
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        parts.append(part)
    detail.bake_prop(parts, "rock_cluster", 1450, size=1024, ray=0.05, ao_distance=0.35, edge_strength=0.45,
                     edge_radius=0.04, cavity=0.6)


def build_pebbles():
    """Depleted leftover (unchanged: the detailed pass did not read at
    this size)."""
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
    only = sys.argv[1:]
    for name, seed, size in SINGLES:
        if not only or name in only:
            build_single(name, seed, size)
    if not only or "rock_cluster" in only:
        build_cluster()
    if not only or "rock_pebbles" in only:
        build_pebbles()
