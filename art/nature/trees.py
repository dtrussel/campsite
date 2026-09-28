"""Stylized broadleaf trees (LoL-like): a chunky, slightly twisted trunk
with flared roots splitting into two or three limbs, and a clumpy canopy
of fused leaf lumps painted from a dark, cool underside to a sunlit,
yellow-green top. Outputs tree_a/b/c.glb and tree_stump.glb."""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402  (must precede bmesh / mathutils)
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402

BARK_DARK = (0.3, 0.19, 0.13)
BARK = (0.52, 0.34, 0.22)
BARK_LIGHT = (0.66, 0.47, 0.3)
LEAF_DARK = (0.12, 0.3, 0.2)
LEAF = (0.27, 0.55, 0.22)
LEAF_LIGHT = (0.64, 0.8, 0.26)
WOOD_RING = (0.85, 0.66, 0.42)


def skin_trunk(rng, height, limbs, base_radius):
    """Trunk + roots + limbs as a skin-modified vertex graph.
    Returns (object, limb tip positions)."""
    bm = bmesh.new()
    radii = {}

    def vert(co, r):
        v = bm.verts.new(co)
        radii[v] = r
        return v

    base = vert(Vector((0, 0, -0.1)), base_radius * 1.1)
    # Trunk with a gentle S-curve twist.
    prev = base
    segments = 4
    trunk_top = None
    for i in range(1, segments + 1):
        t = i / segments
        co = Vector((math.sin(t * 2.2 + rng.random()) * 0.18, math.cos(t * 1.7) * 0.1, height * 0.55 * t))
        v = vert(co, base_radius * (1.0 - 0.45 * t))
        bm.edges.new((prev, v))
        prev = v
        trunk_top = v
    # Roots flare out and dip into the ground.
    for i in range(4):
        a = i / 4 * math.tau + rng.uniform(-0.3, 0.3)
        mid = vert(Vector((math.cos(a) * base_radius * 1.5, math.sin(a) * base_radius * 1.5, 0.08)), base_radius * 0.5)
        tip = vert(Vector((math.cos(a) * base_radius * 2.3, math.sin(a) * base_radius * 2.3, -0.02)), base_radius * 0.22)
        bm.edges.new((base, mid))
        bm.edges.new((mid, tip))
    # Limbs.
    tips = []
    for i in range(limbs):
        a = i / limbs * math.tau + rng.uniform(-0.4, 0.4)
        spread = rng.uniform(0.55, 0.9)
        elbow = vert(trunk_top.co + Vector((math.cos(a) * spread * 0.5, math.sin(a) * spread * 0.5, height * 0.14)), base_radius * 0.4)
        tip = vert(trunk_top.co + Vector((math.cos(a) * spread, math.sin(a) * spread, height * 0.3)), base_radius * 0.22)
        bm.edges.new((trunk_top, elbow))
        bm.edges.new((elbow, tip))
        tips.append(tip.co.copy())
    tips.append(trunk_top.co + Vector((0, 0, height * 0.28)))
    top = vert(tips[-1], base_radius * 0.25)
    bm.edges.new((trunk_top, top))

    obj = common.mesh_object("trunk", bm)
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    for v in obj.data.vertices:
        pass
    # Radii via the skin layer.
    bm2 = bmesh.new()
    bm2.from_mesh(obj.data)
    bm2.verts.ensure_lookup_table()
    layer = bm2.verts.layers.skin.verify()
    for v, (orig) in zip(bm2.verts, list(radii.values())):
        v[layer].radius = (orig, orig)
    bm2.verts[0][layer].use_root = True
    bm2.to_mesh(obj.data)
    bm2.free()
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 1
    common.apply_all_modifiers(obj)
    common.decimate(obj, 700)
    common.shade_smooth(obj)
    return obj, tips


def canopy(rng, tips, height, spread, seed):
    """Separate leaf clumps arranged in a dome over the limbs. Clumps
    overlap, so the bake's AO paints dark gaps between them - the
    classic stylized-tree read."""
    center = Vector((0, 0, height * 0.8))
    radius = spread * 1.25
    anchors = [t.copy() for t in tips]
    # Fill the dome with clumps (golden-angle spiral, upper half only).
    count = 11
    for i in range(count):
        t = (i + 0.5) / count
        polar = math.acos(1.0 - t * 1.1)
        azimuth = i * 2.39996 + rng.random() * 0.3
        d = Vector((math.sin(polar) * math.cos(azimuth), math.sin(polar) * math.sin(azimuth), math.cos(polar) * 0.75))
        anchors.append(center + d * radius)
    clumps = []
    for i, anchor in enumerate(anchors):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
        r = rng.uniform(0.6, 0.85) * spread
        for v in bm.verts:
            n = noise.noise(v.co * 1.8 + Vector((i * 3.1, seed, i)))
            v.co *= r * (1.0 + n * 0.18)
            v.co.z *= 0.82
            if v.co.z < -r * 0.35:
                v.co.z = -r * 0.35 + (v.co.z + r * 0.35) * 0.4  # flatter underside
            v.co += anchor
        clumps.append(common.mesh_object("clump%d" % i, bm))
    obj = common.join(clumps, "canopy")
    common.decimate(obj, 1900)
    common.shade_smooth(obj)
    return obj


def color_trunk(obj, seed):
    def colour(pos, normal):
        streak = noise.noise(Vector((pos.x * 9.0, pos.y * 9.0, pos.z * 1.5 + seed)))
        c = common.lerp(BARK, BARK_LIGHT, max(0.0, min(1.0, 0.5 + streak)))
        if streak < -0.25:
            c = common.lerp(c, BARK_DARK, min(1.0, (-0.25 - streak) * 3.0))
        return c
    common.color_by(obj, colour)


def color_canopy(obj, seed):
    zs = [v.co.z for v in obj.data.vertices]
    lo, hi = min(zs), max(zs)

    def colour(pos, normal):
        h = (pos.z - lo) / max(hi - lo, 0.01)
        clump = noise.noise(pos * 1.6 + Vector((seed, 0, seed)))
        up = max(0.0, normal.z)
        t = max(0.0, min(1.0, h * 0.6 + up * 0.55 + clump * 0.35 - 0.1))
        c = common.lerp(LEAF_DARK, LEAF, min(1.0, t * 1.6))
        if t > 0.62:
            c = common.lerp(c, LEAF_LIGHT, min(1.0, (t - 0.62) * 2.6))
        return c
    common.color_by(obj, colour)


def build_tree(name, seed, height, limbs, spread):
    common.reset(seed)
    rng = random.Random(seed)
    trunk, tips = skin_trunk(rng, height, limbs, base_radius=0.34)
    leaves = canopy(rng, tips, height, spread, seed)
    color_trunk(trunk, seed)
    color_canopy(leaves, seed)
    tree = common.join([trunk, leaves], name)
    paint_bake.paint(tree, size=1024, ao_distance=0.9, ao_strength=0.8, edge_strength=0.0,
                     noise_scale=2.5, stroke_strength=0.1)
    common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), [tree])
    print(name, "tris:", common.triangle_count([tree]))
    preview.render([tree], name, elevation=30)


def build_stump():
    """Watertight stump: metaball trunk + root flares, cut flat on top
    with painted growth rings."""
    common.reset(41)
    rng = random.Random(41)
    elements = [((0, 0, 0.25), 0.55, 2.0, "CAPSULE", (0.25, 0.0, 0.0), (0.7071, 0, 0.7071, 0))]
    from mathutils import Quaternion
    for i in range(5):
        a = i / 5 * math.tau + rng.uniform(-0.3, 0.3)
        rot = Quaternion((0, 0, 1), a) @ Quaternion((0, 1, 0), 0.35)
        elements.append(((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.06), 0.2, 2.0, "CAPSULE", (0.22, 0, 0), tuple(rot)))
        elements.append(((math.cos(a) * 0.72, math.sin(a) * 0.72, -0.02), 0.12, 2.0, "CAPSULE", (0.14, 0, 0), tuple(rot)))
    stump = common.metaball_object("tree_stump", elements, resolution=0.04, threshold=0.6)
    bm = bmesh.new()
    bm.from_mesh(stump.data)
    for cut_co, cut_no in (((0, 0, 0.6), (0.12, 0.05, 1)), ((0, 0, -0.05), (0, 0, -1))):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        result = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=cut_co, plane_no=cut_no, clear_outer=True)
        edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(stump.data)
    bm.free()
    common.decimate(stump, 900)
    common.shade_smooth(stump, auto_angle=40)
    top = max(v.co.z for v in stump.data.vertices)

    def colour(pos, normal):
        if normal.z > 0.8 and pos.z > top - 0.2:
            r = Vector((pos.x, pos.y)).length
            ring = math.sin(r * 38.0) * 0.5 + 0.5
            return common.lerp(WOOD_RING, (0.7, 0.5, 0.3), ring * 0.45 + r * 0.4)
        streak = noise.noise(Vector((pos.x * 8.0, pos.y * 8.0, pos.z * 1.2)))
        c = common.lerp(BARK, BARK_LIGHT, max(0.0, min(1.0, 0.5 + streak)))
        if streak < -0.2:
            c = common.lerp(c, BARK_DARK, min(1.0, (-0.2 - streak) * 3.0))
        return c
    common.color_by(stump, colour, smooth=False)
    paint_bake.paint(stump, size=512, ao_distance=0.25, edge_strength=0.4, edge_radius=0.03)
    common.export_glb(os.path.join(common.OUT_DIR, "tree_stump.glb"), [stump])
    print("tree_stump tris:", common.triangle_count([stump]))
    preview.render([stump], "tree_stump")


if __name__ == "__main__":
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    specs = [("tree_a", 101, 3.6, 3, 1.05), ("tree_b", 202, 4.0, 2, 1.15), ("tree_c", 303, 3.3, 3, 0.95)]
    for spec in specs:
        if only is None or spec[0] in only:
            build_tree(*spec)
    if only is None or "tree_stump" in only:
        build_stump()
