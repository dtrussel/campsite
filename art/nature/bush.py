"""Berry bush: a low mound of leafy clumps studded with big, glossy
cartoon berries (red with a white catch-light). Outputs berry_bush.glb
(full) and berry_bush_picked.glb (depleted, no berries)."""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402

LEAF_DARK = (0.1, 0.28, 0.18)
LEAF = (0.22, 0.52, 0.2)
LEAF_LIGHT = (0.55, 0.76, 0.24)
BERRY = (0.9, 0.08, 0.22)
BERRY_DARK = (0.5, 0.02, 0.12)
SHINE = (1.0, 0.9, 0.9)


def clumps(rng, count, radius, seed, squash=0.75):
    parts = []
    for i in range(count):
        a = i / count * math.tau + rng.uniform(-0.3, 0.3)
        d = rng.uniform(0.25, 0.55) * radius
        center = Vector((math.cos(a) * d, math.sin(a) * d, radius * rng.uniform(0.35, 0.55)))
        if i == 0:
            center = Vector((0, 0, radius * 0.7))
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
        r = radius * rng.uniform(0.42, 0.55)
        for v in bm.verts:
            n = noise.noise(v.co * 2.0 + Vector((i, seed, 0)))
            v.co *= r * (1.0 + n * 0.16)
            v.co.z *= squash
            v.co += center
        parts.append(common.mesh_object("clump%d" % i, bm))
    return parts


def berries(rng, count, leaves):
    """Clusters of three berries sitting on the leaf surface (ray cast
    from outside toward the bush centre)."""
    from mathutils.bvhtree import BVHTree
    tree = BVHTree.FromObject(leaves, bpy.context.evaluated_depsgraph_get())
    zs = [v.co.z for v in leaves.data.vertices]
    center = Vector((0, 0, (min(zs) + max(zs)) * 0.5))
    parts = []
    for i in range(count):
        a = rng.uniform(0, math.tau)
        el = rng.uniform(0.05, 0.9)
        direction = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
        hit, normal, _, _ = tree.ray_cast(center + direction * 4.0, -direction)
        if hit is None:
            continue
        side = normal.cross(Vector((0, 0, 1)))
        if side.length < 0.01:
            side = Vector((1, 0, 0))
        side.normalize()
        up = normal.cross(side)
        for k in range(3):
            offset = side * math.cos(k * 2.09) * 0.09 + up * math.sin(k * 2.09) * 0.09
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.085)
            bmesh.ops.translate(bm, verts=bm.verts, vec=hit + normal * 0.05 + offset)
            parts.append(common.mesh_object("berry%d_%d" % (i, k), bm))
    return parts


def colour_leaves(obj, seed):
    zs = [v.co.z for v in obj.data.vertices]
    lo, hi = min(zs), max(zs)

    def colour(pos, normal):
        h = (pos.z - lo) / max(hi - lo, 0.01)
        n = noise.noise(pos * 3.0 + Vector((seed, 0, 0)))
        t = max(0.0, min(1.0, h * 0.5 + max(0.0, normal.z) * 0.5 + n * 0.3))
        c = common.lerp(LEAF_DARK, LEAF, min(1.0, t * 1.6))
        if t > 0.62:
            c = common.lerp(c, LEAF_LIGHT, min(1.0, (t - 0.62) * 2.5))
        return c
    common.color_by(obj, colour)


def colour_berry(obj, center):
    def colour(pos, normal):
        light = Vector((-0.4, -0.5, 0.75)).normalized()
        d = normal.dot(light)
        if d > 0.9:
            return SHINE
        return common.lerp(BERRY_DARK, BERRY, max(0.0, min(1.0, 0.55 + normal.z * 0.5)))
    common.color_by(obj, colour, smooth=False)


def build(picked):
    seed = 5
    common.reset(seed)
    rng = random.Random(seed)
    radius = 0.95
    leaves = common.join(clumps(rng, 6, radius, seed), "leaves")
    common.decimate(leaves, 1300)
    common.shade_smooth(leaves)
    colour_leaves(leaves, seed)
    parts = [leaves]
    if not picked:
        for b in berries(rng, 8, leaves):
            common.shade_smooth(b)
            colour_berry(b, None)
            parts.append(b)
    name = "berry_bush_picked" if picked else "berry_bush"
    bush = common.join(parts, name)
    paint_bake.paint(bush, size=512, ao_distance=0.4, ao_strength=0.75, edge_strength=0.0, noise_scale=4.0)
    common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), [bush])
    print(name, "tris:", common.triangle_count([bush]))
    preview.render([bush], name)


if __name__ == "__main__":
    build(False)
    build(True)
