"""Feature 025: painted replacements for the last KayKit environment
models, in the same chunky hand-painted style as camp.py / forage.py.
Each matches the footprint of the model it replaces, so the world
dressing keeps its positions and (mostly) its scales.

- jack_o_lantern (+ glowing face) / pumpkin_small: ribbed pumpkins
- camp_lantern:    a floor lantern with a warm glowing flame
- water_bucket:    staved bucket with iron bands and water
- dead_tree_a/b/c: bare, twisted spooky trees with hanging moss
- hill_a/b/c, mountain_a/b: far backdrop mounds covered in tree clumps
  (unit-sized like the KayKit hex tiles; the dressing scales them up)

Run: python art/props/haunted.py [prop ...]"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from nature.trees import skin_trunk  # noqa: E402
from props.camp import IRON, WOOD, WOOD_DARK, WOOD_LIGHT, block, colour_wood, log, rope_ring  # noqa: E402
from props.forage import _decimate_to, _place, finish_prop  # noqa: E402

PUMPKIN = (0.95, 0.5, 0.12)
PUMPKIN_DARK = (0.66, 0.26, 0.06)
PUMPKIN_YELLOW = (0.98, 0.78, 0.25)
STEM = (0.38, 0.42, 0.16)
CARVED = (0.18, 0.07, 0.03)
GLOW = (1.0, 0.62, 0.18)
DEAD_BARK = (0.36, 0.3, 0.28)
DEAD_BARK_LIGHT = (0.55, 0.48, 0.44)
DEAD_BARK_DARK = (0.2, 0.16, 0.16)
MOSS_GREY = (0.52, 0.58, 0.4)
GRASS = (0.4, 0.62, 0.22)
GRASS_LIGHT = (0.62, 0.78, 0.3)
DIRT = (0.5, 0.38, 0.26)
ROCK = (0.55, 0.53, 0.52)
LEAF_DARK = (0.12, 0.3, 0.2)
LEAF = (0.27, 0.55, 0.22)
LEAF_AUTUMN = (0.86, 0.45, 0.14)
WATER = (0.3, 0.55, 0.75)


# --- Pumpkins -------------------------------------------------------------------

def pumpkin_body(radius, height, colour_main, colour_dark, seed, face=False):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=1.0)
    for v in bm.verts:
        angle = math.atan2(v.co.y, v.co.x)
        rib = 1.0 - 0.08 * (0.5 + 0.5 * math.cos(angle * 8))  # 8 ribs
        v.co.x *= radius * rib
        v.co.y *= radius * rib
        v.co.z = (v.co.z * 0.5 + 0.5) * height  # sit on z = 0
        # Pinch the top and bottom in, like a real pumpkin.
        pinch = 1.0 - 0.18 * (abs(v.co.z / height - 0.5) * 2) ** 3
        v.co.x *= pinch
        v.co.y *= pinch
    obj = common.mesh_object("pumpkin", bm)
    common.shade_smooth(obj)

    def colour(pos, normal):
        angle = math.atan2(pos.y, pos.x)
        groove = 0.5 + 0.5 * math.cos(angle * 8)
        c = common.lerp(colour_dark, colour_main, min(1.0, groove * 1.3 + 0.1 + noise.noise(pos * 5 + Vector((seed, 0, 0))) * 0.15))
        if face and normal.y < -0.5:
            # Carved face on the -Y side: two triangle eyes and a toothy grin.
            x, z = pos.x / radius, pos.z / height
            for side in (-1, 1):
                ex, ez = x - side * 0.32, z - 0.62
                if ez > -0.08 and ez < 0.1 and abs(ex) < 0.12 - ez * 0.9:
                    return CARVED
            if 0.26 < z < 0.44 and abs(x) < 0.5 - (0.44 - z) * 0.8:
                tooth = math.sin(x * 22.0) > 0.4 and z > 0.37
                return common.lerp(colour_main, colour_dark, 0.3) if tooth else CARVED
        return c
    common.color_by(obj, colour, smooth=False)
    return obj


def pumpkin_stem(height, seed):
    stem = log(0.22, 0.07, rotation=(0, math.radians(-80), 0.3), location=(0.02, 0, height + 0.07), taper=0.6, seed=seed)
    common.set_color(stem, STEM)
    return stem


def face_glow(radius, height):
    """Emissive shapes just inside the carved face, so it glows at night."""
    bm = bmesh.new()
    y = -radius * 0.9
    for side in (-1, 1):
        cx = side * 0.32 * radius
        pts = [(cx - 0.12 * radius, y, 0.62 * height - 0.06 * height), (cx + 0.12 * radius, y, 0.62 * height - 0.06 * height),
               (cx, y, 0.62 * height + 0.1 * height)]
        bm.faces.new([bm.verts.new(p) for p in pts])
    mouth = [(-0.38 * radius, y, 0.42 * height), (0.38 * radius, y, 0.42 * height), (0.26 * radius, y, 0.28 * height),
             (-0.26 * radius, y, 0.28 * height)]
    bm.faces.new([bm.verts.new(p) for p in mouth])
    obj = common.mesh_object("face_glow", bm)
    solid = obj.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = 0.02
    common.apply_all_modifiers(obj)
    paint_bake.flat_material(obj, GLOW, emission=3.0, name="jack_glow")
    return obj


def jack_o_lantern():
    common.reset(41)
    r, h = 0.7, 1.15
    body = pumpkin_body(r, h, PUMPKIN, PUMPKIN_DARK, 1, face=True)
    parts = [body, pumpkin_stem(h, 2)]
    obj = common.join(parts, "jack_o_lantern")
    _decimate_to(obj, 1800)
    paint_bake.paint(obj, size=512, ao_distance=0.2, ao_strength=0.6, edge_strength=0.3, edge_radius=0.02, noise_scale=6.0)
    glow = face_glow(r, h)
    common.export_glb(os.path.join(common.OUT_DIR, "jack_o_lantern.glb"), [obj, glow])
    print("jack_o_lantern tris:", common.triangle_count([obj, glow]))
    preview.render([obj, glow], "jack_o_lantern", elevation=15, azimuth=float(os.environ.get("AZ", "200")))


def pumpkin_small():
    common.reset(42)
    body = pumpkin_body(0.3, 0.48, PUMPKIN_YELLOW, (0.8, 0.5, 0.12), 3)
    finish_prop([body, pumpkin_stem(0.48, 4)], "pumpkin_small", size=256, budget=1000, edge_strength=0.3)


# --- Lantern and bucket ------------------------------------------------------------

def camp_lantern():
    """A floor lantern: square base, four posts, a roof and a handle,
    with a warm flame inside (separate emissive mesh)."""
    common.reset(43)
    parts = []
    base = block((0.5, 0.5, 0.1), location=(0, 0, 0.05), bevel=0.02)
    common.set_color(base, IRON)
    parts.append(base)
    for sx in (-1, 1):
        for sy in (-1, 1):
            post = block((0.05, 0.05, 0.55), location=(sx * 0.2, sy * 0.2, 0.37), bevel=0.01)
            colour_wood(post, sx + sy * 2, base=WOOD_DARK, light=WOOD)
            parts.append(post)
    roof = block((0.56, 0.56, 0.08), location=(0, 0, 0.68), bevel=0.02)
    common.set_color(roof, IRON)
    parts.append(roof)
    cap = block((0.3, 0.3, 0.1), location=(0, 0, 0.77), bevel=0.02)
    common.set_color(cap, IRON)
    parts.append(cap)
    handle = rope_ring(0.12, 0.018, (0, 0, 0.88), rotation=(math.pi / 2, 0, 0))
    common.set_color(handle, IRON)
    parts.append(handle)
    candle = log(0.2, 0.06, rotation=(0, math.radians(-90), 0), location=(0, 0, 0.2), taper=1.0, seed=5)
    common.set_color(candle, (0.95, 0.9, 0.78))
    parts.append(candle)
    body = common.join(parts, "camp_lantern")
    _decimate_to(body, 1200)
    paint_bake.paint(body, size=256, ao_distance=0.15, ao_strength=0.6, edge_strength=0.35, edge_radius=0.015, noise_scale=6.0)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=8, radius=0.06)
    for v in bm.verts:
        v.co.z *= 1.7
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.4))
    flame = common.mesh_object("flame", bm)
    paint_bake.flat_material(flame, GLOW, emission=3.5, name="lantern_flame_glow")
    common.export_glb(os.path.join(common.OUT_DIR, "camp_lantern.glb"), [body, flame])
    print("camp_lantern tris:", common.triangle_count([body, flame]))
    preview.render([body, flame], "camp_lantern", elevation=25)


def water_bucket():
    common.reset(44)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.2, radius2=0.25, depth=0.4)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.2))
    bucket = common.mesh_object("bucket", bm)
    common.shade_smooth(bucket, auto_angle=40)

    def colour(pos, normal):
        if normal.z > 0.9 and pos.z > 0.35:
            return WATER
        stave = math.sin(math.atan2(pos.y, pos.x) * 10) > 0.85
        return WOOD_DARK if stave else common.lerp(WOOD, WOOD_LIGHT, 0.5 + noise.noise(pos * 9) * 0.5)
    common.color_by(bucket, colour, smooth=False)
    parts = [bucket]
    for z, r in ((0.08, 0.215), (0.32, 0.245)):
        band = rope_ring(r, 0.015, (0, 0, z))
        common.set_color(band, IRON)
        parts.append(band)
    handle = rope_ring(0.24, 0.012, (0, 0, 0.42), rotation=(math.pi / 2, 0, 0))
    common.set_color(handle, IRON)
    parts.append(handle)
    finish_prop(parts, "water_bucket", size=256, budget=900, edge_strength=0.35)


# --- Dead trees --------------------------------------------------------------------------

def moss_strand(top, length, seed):
    rng = random.Random(seed)
    pts = [top + Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), -length * t)) for t in (0.0, 0.35, 0.7, 1.0)]
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in pts]
    for a, b in zip(verts, verts[1:]):
        bm.edges.new((a, b))
    obj = common.mesh_object("moss", bm)
    obj.modifiers.new("Skin", "SKIN")
    bm2 = bmesh.new()
    bm2.from_mesh(obj.data)
    bm2.verts.ensure_lookup_table()
    layer = bm2.verts.layers.skin.verify()
    for v, r in zip(bm2.verts, (0.035, 0.03, 0.022, 0.008)):
        v[layer].radius = (r, r * 0.6)
    bm2.verts[0][layer].use_root = True
    bm2.to_mesh(obj.data)
    bm2.free()
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    common.set_color(obj, MOSS_GREY)
    return obj


def dead_tree(name, seed, height, limbs):
    common.reset(seed)
    rng = random.Random(seed)
    trunk, tips = skin_trunk(rng, height, limbs, base_radius=0.26)
    # A second, thinner set of twigs off the limb tips.
    twigs = []
    for i, tip in enumerate(tips):
        for k in range(2):
            a = rng.uniform(0, math.tau)
            end = tip + Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, rng.uniform(0.1, 0.4)))
            twig = log((end - tip).length, 0.035, taper=0.3, seed=seed * 10 + i * 2 + k)
            twig.rotation_mode = "QUATERNION"
            twig.rotation_quaternion = Vector((1, 0, 0)).rotation_difference((end - tip).normalized())
            twig.location = (tip + end) / 2
            common.apply_transform(twig)
            common.select_only([twig])
            bpy.ops.object.transform_apply(location=True)
            twigs.append(twig)
    wood = common.join([trunk] + twigs, name)

    def colour(pos, normal):
        streak = noise.noise(Vector((pos.x * 9.0, pos.y * 9.0, pos.z * 1.5 + seed)))
        c = common.lerp(DEAD_BARK, DEAD_BARK_LIGHT, max(0.0, min(1.0, 0.5 + streak)))
        if streak < -0.2:
            c = common.lerp(c, DEAD_BARK_DARK, min(1.0, (-0.2 - streak) * 3.0))
        return c
    common.color_by(wood, colour, smooth=False)
    parts = [wood]
    for i, tip in enumerate(tips[:3]):
        parts.append(moss_strand(tip + Vector((0, 0, -0.1)), rng.uniform(0.35, 0.6), seed + i))
    finish_prop(parts, name, size=512, budget=1400, preview_elevation=20, edge_strength=0.2)


# --- Far hills ---------------------------------------------------------------------------

def tree_clump(center, size, seed, autumn=False):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=size)
    for v in bm.verts:
        v.co.z *= 0.9
        v.co += Vector((noise.noise(v.co * 5 + Vector((seed, 0, 0))), noise.noise(v.co * 5 + Vector((0, seed, 0))), 0)) * size * 0.2
    bmesh.ops.translate(bm, verts=bm.verts, vec=center)
    obj = common.mesh_object("clump", bm)
    common.shade_smooth(obj)
    top = center.z + size

    def colour(pos, normal):
        t = max(0.0, min(1.0, (pos.z - center.z + size) / (2 * size) * 0.7 + normal.z * 0.4))
        main = LEAF_AUTUMN if autumn else LEAF
        return common.lerp(LEAF_DARK, main, t)
    common.color_by(obj, colour, smooth=False)
    return obj


def backdrop_mound(name, seed, width, height, clumps, rocky):
    """A mound about `width` across and `height` tall (KayKit hex tile
    scale: the dressing scales it by 4.5-9), dotted with tree clumps."""
    common.reset(seed)
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=10, radius=1.0)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0.0
        n = noise.noise(v.co * 2.0 + Vector((seed, 0, 0)))
        v.co.x *= width * 0.5 * (1 + n * 0.12)
        v.co.y *= width * 0.5 * (1 + n * 0.12)
        v.co.z *= height * (0.85 + n * 0.3 if rocky else 1.0 + n * 0.12)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    mound = common.mesh_object("mound", bm)
    common.shade_smooth(mound)

    def colour(pos, normal):
        n = noise.noise(pos * 4.0 + Vector((seed, 0, 0)))
        if rocky and normal.z < 0.55:
            return common.lerp(ROCK, DIRT, max(0.0, min(1.0, 0.4 + n)))
        c = common.lerp(GRASS, GRASS_LIGHT, max(0.0, min(1.0, 0.5 + n + normal.z * 0.3)))
        if normal.z < 0.3:
            c = common.lerp(c, DIRT, 0.5)
        return c
    common.color_by(mound, colour, smooth=False)
    parts = [mound]
    for i in range(clumps):
        a = rng.uniform(0, math.tau)
        r = math.sqrt(rng.random()) * 0.42
        x, y = math.cos(a) * r * width, math.sin(a) * r * width
        # Height of the mound at (x, y): ellipsoid.
        d = min(1.0, (x * x + y * y) / (width * 0.5) ** 2)
        z = height * math.sqrt(max(0.0, 1.0 - d)) * (0.9 if rocky else 1.0)
        size = rng.uniform(0.1, 0.2) * width
        parts.append(tree_clump(Vector((x, y, z + size * 0.3)), size, seed * 10 + i, autumn=rng.random() < 0.3))
    finish_prop(parts, name, size=512, budget=2600, preview_elevation=25, edge_strength=0.0, ao_distance=0.3)


PROPS = {
    "jack_o_lantern": jack_o_lantern,
    "pumpkin_small": pumpkin_small,
    "camp_lantern": camp_lantern,
    "water_bucket": water_bucket,
    "dead_tree_a": lambda: dead_tree("dead_tree_a", 51, 4.6, 3),
    "dead_tree_b": lambda: dead_tree("dead_tree_b", 52, 3.8, 4),
    "dead_tree_c": lambda: dead_tree("dead_tree_c", 53, 3.0, 2),
    "hill_a": lambda: backdrop_mound("hill_a", 61, 1.76, 0.75, 9, False),
    "hill_b": lambda: backdrop_mound("hill_b", 62, 1.76, 0.9, 11, False),
    "hill_c": lambda: backdrop_mound("hill_c", 63, 1.8, 1.0, 12, False),
    "mountain_a": lambda: backdrop_mound("mountain_a", 64, 1.86, 1.9, 8, True),
    "mountain_b": lambda: backdrop_mound("mountain_b", 65, 1.86, 1.6, 10, True),
}

if __name__ == "__main__":
    for name in (sys.argv[1:] or PROPS.keys()):
        random.seed(hash(name) & 0xFFFF)
        PROPS[name]()
