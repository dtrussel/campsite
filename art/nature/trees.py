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

from lib import common, detail, paint_bake, preview  # noqa: E402

BARK_DARK = (0.3, 0.19, 0.13)
BARK = (0.52, 0.34, 0.22)
BARK_LIGHT = (0.66, 0.47, 0.3)
LEAF_SHADE = (0.05, 0.16, 0.12)
LEAF_DARK = (0.12, 0.3, 0.2)
LEAF = (0.27, 0.55, 0.22)
LEAF_LIGHT = (0.64, 0.8, 0.26)
WOOD_RING = (0.85, 0.66, 0.42)
MOSS = (0.34, 0.46, 0.16)


def skin_trunk(rng, height, limbs, base_radius, subsurf=1, budget=700):
    """Trunk + roots + limbs as a skin-modified vertex graph.
    Returns (object, limb tip positions). `subsurf`/`budget` (None = no
    decimation) let bark_trunk build a dense copy of the same trunk."""
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
    sub.levels = subsurf
    common.apply_all_modifiers(obj)
    if budget:
        common.decimate(obj, budget)
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


def bark_trunk(rng, height, limbs, base_radius, seed):
    """The same trunk as skin_trunk, built dense and carved with
    vertical bark ridges and dark cracks; roots get a mossy, earthy foot."""
    obj, tips = skin_trunk(rng, height, limbs, base_radius, subsurf=3, budget=None)
    mesh = obj.data
    off = Vector((seed * 0.37, seed * 0.11, seed * 0.07))
    ridge = []
    for v in mesh.vertices:
        p = v.co
        q = Vector((p.x * 7.0, p.y * 7.0, p.z * 0.9)) + off
        r = min(1.0, abs(noise.noise(q)) * 5.0)
        ridge.append(r)
        v.co = p - v.normal * (1.0 - r) * 0.028
    mesh.update()
    common.shade_smooth(obj)

    def colour(pos, normal):
        q = Vector((pos.x * 7.0, pos.y * 7.0, pos.z * 0.9)) + off
        r = min(1.0, abs(noise.noise(q)) * 5.0)
        strip = noise.noise(Vector((pos.x * 3.0, pos.y * 3.0, pos.z * 0.5)) + off * 2.0) * 0.5 + 0.5
        fleck = noise.noise(pos * 25.0) * 0.5 + 0.5
        c = common.lerp(BARK, BARK_LIGHT, strip * (0.55 + 0.45 * fleck))
        c = common.lerp(BARK_DARK, c, 0.25 + 0.75 * r)
        # Sun-bleached ridge tops on the upper trunk.
        if normal.z > 0.3:
            c = common.lerp(c, BARK_LIGHT, 0.3)
        # Moss and earth about the foot and on the roots.
        foot = max(0.0, 1.0 - pos.z / 0.55)
        m = noise.noise(pos * 4.0 + off) * 0.5 + 0.5
        if foot > 0 and m > 0.45:
            c = common.lerp(c, MOSS, min(1.0, (m - 0.45) * 4.0) * foot * 0.8)
        return c
    common.color_by(obj, colour)
    return obj, tips


def leafy_canopy(rng, tips, height, spread, seed):
    """The canopy() dome of clumps, each a dense leaf_clump with tufts.
    Uses the rng exactly as canopy() so the tree keeps its shape."""
    center = Vector((0, 0, height * 0.8))
    radius = spread * 1.25
    anchors = [t.copy() for t in tips]
    count = 11
    for i in range(count):
        t = (i + 0.5) / count
        polar = math.acos(1.0 - t * 1.1)
        azimuth = i * 2.39996 + rng.random() * 0.3
        d = Vector((math.sin(polar) * math.cos(azimuth), math.sin(polar) * math.sin(azimuth), math.cos(polar) * 0.75))
        anchors.append(center + d * radius)
    clumps = []
    for i, anchor in enumerate(anchors):
        r = rng.uniform(0.6, 0.85) * spread
        clumps.append(detail.leaf_clump(anchor, r, seed * 31 + i, tufts=13, bump=0.2,
                                        noise_offset=(i * 3.1, seed, i), name="clump%d" % i))
    return clumps


def build_tree(name, seed, height, limbs, spread):
    common.reset(seed)
    rng = random.Random(seed)
    trunk, tips = bark_trunk(rng, height, limbs, 0.34, seed)
    clumps = leafy_canopy(rng, tips, height, spread, seed)
    detail.cull_hidden(clumps + [trunk], clumps, margin=0.04)
    shell = common.join(clumps, "canopy")
    common.shade_smooth(shell)
    zs = [v.co.z for v in shell.data.vertices]
    lo, hi = min(zs), max(zs)
    # The shell is the shade between the leaves (M8): dark and cool.
    detail.colour_foliage(shell, LEAF_SHADE, LEAF_DARK, LEAF, seed, lo=lo, hi=hi, fleck=0.3)
    leaves = detail.scatter_leaves(shell, seed, length=0.42, width=0.32, coverage=3.2, max_count=1000, tilt=0.3,
                                   droop=0.2, min_up=-0.7,
                                   colour=detail.leaf_colour(LEAF_DARK, LEAF, LEAF_LIGHT, lo, hi, seed))
    leaves_high = leaves.copy()
    leaves_high.data = leaves.data.copy()
    leaves.users_collection[0].objects.link(leaves_high)
    detail.bake_prop_lows([trunk, shell], name, 5100, lows=[leaves], dense_only=[leaves_high], size=1024,
                          ray=0.12, ao_distance=0.45, ao_strength=0.35, edge_strength=0.0, noise_scale=2.5,
                          stroke_strength=0.1, cavity=0.3)
    preview.render([bpy.data.objects[name]], name, elevation=30)


def _stump_ridge(p):
    """Bark ridges that run up the trunk and out along the roots."""
    a = math.atan2(p.y, p.x)
    r = Vector((p.x, p.y)).length
    q = Vector((math.cos(a) * 3.5, math.sin(a) * 3.5, (p.z + r) * 1.2 + 4.1))
    return min(1.0, abs(noise.noise(q)) * 5.0)


def build_stump():
    """Watertight stump as before (metaball trunk + root flares, cut
    flat on top), now modelled dense: carved bark ridges on the sides,
    concentric growth rings, a bark rim and a drying crack on the cut,
    moss about the roots. Baked onto the game mesh with bake_prop."""
    common.reset(41)
    rng = random.Random(41)
    elements = [((0, 0, 0.25), 0.55, 2.0, "CAPSULE", (0.25, 0.0, 0.0), (0.7071, 0, 0.7071, 0))]
    from mathutils import Quaternion
    for i in range(5):
        a = i / 5 * math.tau + rng.uniform(-0.3, 0.3)
        rot = Quaternion((0, 0, 1), a) @ Quaternion((0, 1, 0), 0.35)
        elements.append(((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.06), 0.2, 2.0, "CAPSULE", (0.22, 0, 0), tuple(rot)))
        elements.append(((math.cos(a) * 0.72, math.sin(a) * 0.72, -0.02), 0.12, 2.0, "CAPSULE", (0.14, 0, 0), tuple(rot)))
    stump = common.metaball_object("tree_stump", elements, resolution=0.022, threshold=0.6)
    bm = bmesh.new()
    bm.from_mesh(stump.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    top_normal = Vector((0.12, 0.05, 1)).normalized()
    for cut_co, cut_no in (((0, 0, 0.6), (0.12, 0.05, 1)), ((0, 0, -0.05), (0, 0, -1))):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        result = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=cut_co, plane_no=cut_no, clear_outer=True)
        edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if cut_no[2] < 0:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
            continue
        # The cut: concentric rings from the boundary loop in to the
        # centre, so growth rings and the crack have vertices.
        loop = sorted({v for e in edges for v in e.verts if e.is_boundary},
                      key=lambda v: math.atan2(v.co.y, v.co.x))
        c = sum((v.co for v in loop), Vector()) / len(loop)
        rings = [loop]
        steps = 18
        for k in range(1, steps):
            t = k / steps
            rings.append([bm.verts.new(v.co.lerp(c, t)) for v in loop])
        hub = bm.verts.new(c)
        n = len(loop)
        for k in range(steps - 1):
            a_ring, b_ring = rings[k], rings[k + 1]
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((a_ring[i], a_ring[j], b_ring[j], b_ring[i]))
        for i in range(n):
            bm.faces.new((rings[-1][i], rings[-1][(i + 1) % n], hub))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    centre = Vector((0, 0, 0.6))
    crack_a = rng.uniform(0, math.tau)
    for v in bm.verts:
        on_top = (v.co - centre).dot(top_normal) > -0.004
        if on_top:
            rel = v.co - centre
            r = Vector((rel.x, rel.y)).length
            ang = math.atan2(rel.y, rel.x)
            da = abs((ang - crack_a + math.pi) % math.tau - math.pi)
            if da * max(r, 0.05) < 0.03 and 0.06 < r < 0.36:
                v.co -= top_normal * 0.035 * (1.0 - r / 0.36)
            v.co -= top_normal * noise.noise(Vector((v.co.x * 9, v.co.y * 9, 1.3))) * 0.006
        elif v.normal.z < 0.85:
            ridge = _stump_ridge(v.co)
            v.co -= v.normal * (1.0 - ridge) * 0.03
    bm.to_mesh(stump.data)
    bm.free()
    common.shade_smooth(stump, auto_angle=40)

    def colour(pos, normal):
        rel = pos - centre
        if rel.dot(top_normal) > -0.012 and normal.z > 0.6:
            r = Vector((rel.x, rel.y)).length
            if r > 0.41:
                return BARK_DARK
            if r > 0.375:
                return common.lerp(BARK, BARK_LIGHT, 0.4)
            wob = noise.noise(Vector((rel.x * 5, rel.y * 5, 2.0))) * 0.025
            ring = math.sin((r + wob) * 80.0) * 0.5 + 0.5
            c = common.lerp(WOOD_RING, (0.68, 0.47, 0.28), ring * 0.5 + r * 0.5)
            ang = math.atan2(rel.y, rel.x)
            da = abs((ang - crack_a + math.pi) % math.tau - math.pi)
            if da * max(r, 0.05) < 0.032 and 0.06 < r < 0.36:
                c = BARK_DARK
            return c
        ridge = _stump_ridge(pos)
        strip = noise.noise(Vector((pos.x * 3.0, pos.y * 3.0, pos.z * 0.6))) * 0.5 + 0.5
        c = common.lerp(BARK, BARK_LIGHT, strip * 0.85)
        c = common.lerp(BARK_DARK, c, 0.2 + 0.8 * ridge)
        m = noise.noise(pos * 3.5 + Vector((2, 0, 0))) * 0.5 + 0.5
        foot = max(0.0, 1.0 - pos.z / 0.3)
        if m > 0.5 and foot > 0:
            c = common.lerp(c, MOSS, min(1.0, (m - 0.5) * 4.0) * foot * 0.75)
        return c
    common.color_by(stump, colour)
    detail.bake_prop([stump], "tree_stump", 1500, size=512, ray=0.1, ao_distance=0.25, edge_strength=0.4,
                     edge_radius=0.03, cavity=0.5)


if __name__ == "__main__":
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    specs = [("tree_a", 101, 3.6, 3, 1.05), ("tree_b", 202, 4.0, 2, 1.15), ("tree_c", 303, 3.3, 3, 0.95)]
    for spec in specs:
        if only is None or spec[0] in only:
            build_tree(*spec)
    if only is None or "tree_stump" in only:
        build_stump()
