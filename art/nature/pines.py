"""Stylized autumn pines (the Resin trees): a slim trunk carrying
stacked, drooping tiers with scalloped, pointed hems, painted from deep
red underneath to glowing orange and golden tips. Outputs pine_a/b.glb."""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402

BARK = (0.42, 0.27, 0.18)
BARK_LIGHT = (0.58, 0.4, 0.26)
NEEDLE_DARK = (0.48, 0.12, 0.08)
NEEDLE = (0.86, 0.36, 0.1)
NEEDLE_LIGHT = (1.0, 0.72, 0.25)


def tier(rng, z, radius, height, points, droop, seed):
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
    sub.levels = 1
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    return obj


def trunk(height):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.24, radius2=0.1, depth=height)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, height / 2 - 0.05))
    obj = common.mesh_object("trunk", bm)
    common.shade_smooth(obj)
    return obj


def build(name, seed, tiers, base_radius, total):
    common.reset(seed)
    rng = random.Random(seed)
    parts = [trunk(total * 0.5)]
    z = total * 0.18
    step = (total - z) / (tiers + 0.4)
    for i in range(tiers):
        t = i / max(tiers - 1, 1)
        radius = base_radius * (1.0 - t * 0.62)
        parts.append(tier(rng, z, radius, step * 1.55, points=9 - i // 2, droop=step * 0.45, seed=seed + i * 0.7))
        z += step
    tree = common.join(parts, name)
    zs = [v.co.z for v in tree.data.vertices]
    lo, hi = min(zs), max(zs)

    def colour(pos, normal):
        r = Vector((pos.x, pos.y)).length
        if r < 0.26 and pos.z < total * 0.3:
            return common.lerp(BARK, BARK_LIGHT, 0.5 + noise.noise(pos * 6.0) * 0.5)
        h = (pos.z - lo) / max(hi - lo, 0.01)
        n = noise.noise(pos * 2.2 + Vector((seed, 0, 0)))
        up = max(0.0, normal.z)
        t = max(0.0, min(1.0, up * 0.8 + h * 0.3 + n * 0.35 + r * 0.12))
        c = common.lerp(NEEDLE_DARK, NEEDLE, min(1.0, t * 1.5))
        if t > 0.5:
            c = common.lerp(c, NEEDLE_LIGHT, min(1.0, (t - 0.5) * 2.0))
        return c
    common.color_by(tree, colour)
    paint_bake.paint(tree, size=1024, ao_distance=0.7, ao_strength=0.7, edge_strength=0.25, edge_radius=0.05,
                     noise_scale=3.0)
    common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), [tree])
    print(name, "tris:", common.triangle_count([tree]))
    preview.render([tree], name, elevation=25)


if __name__ == "__main__":
    build("pine_a", 11, 4, 1.35, 3.8)
    build("pine_b", 23, 5, 1.2, 4.4)
