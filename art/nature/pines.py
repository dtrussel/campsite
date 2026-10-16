"""Stylized pines: a slim trunk carrying stacked, drooping tiers with
scalloped, pointed hems.

- pine_a/b.glb: the autumn Resin trees, painted from deep red underneath
  to glowing orange and golden tips.
- pine_c/d.glb (feature 031): green border pines after the October
  concept art, deep green underneath to yellow-green sunlit tips."""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

from lib import common, detail, paint_bake, preview  # noqa: E402

BARK = (0.42, 0.27, 0.18)
BARK_LIGHT = (0.58, 0.4, 0.26)
BARK_DARK = (0.24, 0.15, 0.1)
NEEDLE_DARK = (0.48, 0.12, 0.08)
NEEDLE = (0.86, 0.36, 0.1)
NEEDLE_LIGHT = (1.0, 0.72, 0.25)
AUTUMN = (NEEDLE_DARK, NEEDLE, NEEDLE_LIGHT)
GREEN = ((0.08, 0.24, 0.12), (0.2, 0.46, 0.18), (0.66, 0.78, 0.26))


def tier(rng, z, radius, height, points, droop, seed, levels=1):
    """One cone tier with a scalloped hem: `points` spikes that droop."""
    bm = bmesh.new()
    apex = bm.verts.new((0, 0, z + height))
    rings = []
    ring_count = 3
    for r in range(1, ring_count + 1):
        t = r / ring_count
        ring = []
        count = points * 2
        for i in range(count):
            a = i / count * math.tau + seed
            spike = 1.0 if i % 2 == 0 else 0.52
            rr = radius * t * (spike if r == ring_count else (0.82 + 0.18 * spike))
            dz = z + height * (1.0 - t) - (droop * t * t * (1.25 if i % 2 == 0 else 0.35))
            rr *= 1.0 + rng.uniform(-0.06, 0.06)
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, dz)))
        rings.append(ring)
    first = rings[0]
    for i in range(len(first)):
        bm.faces.new((apex, first[i], first[(i + 1) % len(first)]))
    for r in range(len(rings) - 1):
        a_ring, b_ring = rings[r], rings[r + 1]
        for i in range(len(a_ring)):
            j = (i + 1) % len(a_ring)
            bm.faces.new((a_ring[i], b_ring[i], b_ring[j], a_ring[j]))
    # Underside: pull the hem back in so the tier has thickness.
    last = rings[-1]
    inner = [bm.verts.new((v.co.x * 0.55, v.co.y * 0.55, v.co.z + height * 0.28)) for v in last]
    for i in range(len(last)):
        j = (i + 1) % len(last)
        bm.faces.new((last[j], last[i], inner[i], inner[j]))
    center = bm.verts.new((0, 0, z + height * 0.35))
    for i in range(len(inner)):
        j = (i + 1) % len(inner)
        bm.faces.new((inner[j], inner[i], center))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = common.mesh_object("tier", bm)
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = levels
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    return obj


def needle_tier(rng, z, radius, height, points, droop, seed):
    """tier() built dense, its top carved with needle-bundle ridges that
    run from the apex out to every spike and notch. Stores the ridge
    value (1 on a bundle, 0 in a groove) in the 'tuft' attribute."""
    obj = tier(rng, z, radius, height, points, droop, seed, levels=3)
    mesh = obj.data
    values = []
    off = Vector((seed * 1.3, seed * 0.7, seed))
    for v in mesh.vertices:
        p = v.co
        r = Vector((p.x, p.y)).length
        a = math.atan2(p.y, p.x)
        u = r / max(radius, 0.01)
        # Irregular needle strokes, long down the slope.
        q = Vector((math.cos(a) * r * 5.5, math.sin(a) * r * 5.5, u * 1.1)) + off
        streak = min(1.0, abs(noise.noise(q)) * 3.0)
        # Overlapping rows of pointed needle tufts, like little hems: a
        # sawtooth down the slope whose ledges zigzag around the tier.
        k = points * 2
        zig = abs(((a / math.tau * k + seed) % 1.0) - 0.5) * 2.0
        wob = noise.noise(Vector((math.cos(a) * 2.0, math.sin(a) * 2.0, seed))) * 0.15
        layer = (u * 2.2 + zig * 0.45 + wob) % 1.0
        top = v.normal.z > -0.1
        reach = max(0.0, min(1.0, (u - 0.15) / 0.25))
        g = 0.3 * streak + 0.7 * layer
        g = 0.5 + (g - 0.5) * reach
        values.append(g if top else 0.3)
    mesh.update()
    attr = mesh.attributes.new("tuft", "FLOAT", "POINT")
    for i, val in enumerate(values):
        attr.data[i].value = val
    common.shade_smooth(obj)
    return obj


def bark_trunk(height):
    """A dense trunk with vertical bark ridges."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=0.24, radius2=0.1, depth=height)
    side = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > height * 0.5]
    bmesh.ops.subdivide_edges(bm, edges=side, cuts=30, use_grid_fill=True)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, height / 2 - 0.05))
    for v in bm.verts:
        r = Vector((v.co.x, v.co.y)).length
        if r > 0.02:
            a = math.atan2(v.co.y, v.co.x)
            ridge = min(1.0, abs(noise.noise(Vector((math.cos(a) * 2.5, math.sin(a) * 2.5, v.co.z * 1.4)))) * 5.0)
            s = (r - (1.0 - ridge) * 0.02) / r
            v.co.x *= s
            v.co.y *= s
    obj = common.mesh_object("trunk", bm)
    common.shade_smooth(obj)
    return obj


def trunk(height):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.24, radius2=0.1, depth=height)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, height / 2 - 0.05))
    obj = common.mesh_object("trunk", bm)
    common.shade_smooth(obj)
    return obj


def build(name, seed, tiers, base_radius, total, palette=AUTUMN):
    """Same tiered tree as before, modelled dense (needle-bundle ridges on
    every tier, bark on the trunk) and baked onto the budget mesh."""
    dark, mid, light = palette
    common.reset(seed)
    rng = random.Random(seed)
    parts = [bark_trunk(total * 0.5)]
    z = total * 0.18
    step = (total - z) / (tiers + 0.4)
    for i in range(tiers):
        t = i / max(tiers - 1, 1)
        radius = base_radius * (1.0 - t * 0.62)
        parts.append(needle_tier(rng, z, radius, step * 1.55, points=9 - i // 2, droop=step * 0.45, seed=seed + i * 0.7))
        z += step
    tree = common.join(parts, name)
    mesh = tree.data
    attr = mesh.attributes.get("tuft")
    tufts = [a.value for a in attr.data]
    zs = [v.co.z for v in mesh.vertices]
    lo, hi = min(zs), max(zs)
    colours = []
    for v in mesh.vertices:
        pos, normal = v.co, v.normal
        r = Vector((pos.x, pos.y)).length
        if r < 0.26 and pos.z < total * 0.3 and abs(normal.z) < 0.6:
            a = math.atan2(pos.y, pos.x)
            ridge = min(1.0, abs(noise.noise(Vector((math.cos(a) * 2.5, math.sin(a) * 2.5, pos.z * 1.4)))) * 5.0)
            c = common.lerp(BARK, BARK_LIGHT, 0.5 + noise.noise(pos * 6.0) * 0.5)
            colours.append(common.lerp(BARK_DARK, c, 0.3 + 0.7 * ridge))
            continue
        g = tufts[v.index]
        h = (pos.z - lo) / max(hi - lo, 0.01)
        n = noise.noise(pos * 2.2 + Vector((seed, 0, 0)))
        up = max(0.0, normal.z)
        t = max(0.0, min(1.0, up * 0.65 + h * 0.3 + n * 0.12 + r * 0.12 + (g - 0.5) * 0.75))
        c = common.lerp(dark, mid, min(1.0, t * 1.5))
        if t > 0.5:
            c = common.lerp(c, light, min(1.0, (t - 0.5) * 2.0))
        if g < 0.22:
            c = common.lerp(c, dark, (0.22 - g) * 3.0)
        colours.append(c)
    common.color_by(tree, lambda pos, normal: (0, 0, 0))
    col = mesh.color_attributes["Col"]
    per_vertex = [common.srgb(c) for c in colours]
    for loop in mesh.loops:
        col.data[loop.index].color = (*per_vertex[loop.vertex_index], 1.0)
    # Needle tufts (M8): pointed blades running down every tier's slope
    # and drooping past the hem, so the tiers read shaggy, not smooth.
    tufts_obj = detail.scatter_leaves(tree, seed, length=0.34, width=0.12, coverage=1.4, max_count=850, tilt=0.2,
                                      sink=0.02, droop=0.3, min_up=0.15, outward=0.8, needle=True,
                                      colour=detail.leaf_colour(dark, mid, light, lo, hi, seed, lift=0.2),
                                      name="needles")
    tufts_high = tufts_obj.copy()
    tufts_high.data = tufts_obj.data.copy()
    tufts_obj.users_collection[0].objects.link(tufts_high)
    detail.bake_prop_lows([tree], name, 3600, lows=[tufts_obj], dense_only=[tufts_high], size=1024, ray=0.02,
                          ao_distance=0.6, ao_strength=0.5, edge_strength=0.25, edge_radius=0.05, noise_scale=3.0,
                          cavity=0.0)
    preview.render([bpy.data.objects[name]], name, elevation=25)


SPECS = {
    "pine_a": (11, 4, 1.35, 3.8, AUTUMN),
    "pine_b": (23, 5, 1.2, 4.4, AUTUMN),
    "pine_c": (31, 4, 1.3, 4.0, GREEN),
    "pine_d": (47, 5, 1.15, 4.8, GREEN),
}

if __name__ == "__main__":
    for name in (sys.argv[1:] or SPECS.keys()):
        build(name, *SPECS[name])
