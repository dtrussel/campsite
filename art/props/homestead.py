"""Feature 031: cozy camp decor after the October concept art
(art/reference/concept-2026-10/01-02, 12): log and stump seats, a
cooking tripod with a pot, the carved tent-glyph signpost, a lantern
post (warm emissive glass), a striped market stall with fruit crates and
a stone well with a red tile roof. All decor: no gameplay.

Run: python art/props/homestead.py [prop ...]"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402,F401
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

from lib import common, detail, paint_bake, preview  # noqa: E402
from props.camp import (CANVAS, IRON, ROOF, ROOF_LIGHT, ROPE, WOOD, WOOD_DARK, WOOD_LIGHT, block,  # noqa: E402
                        colour_wood, log, rope_ring)
from props.forage import _decimate_to, finish_prop  # noqa: E402

GLOW = (1.0, 0.66, 0.26)
CREAM = (0.95, 0.87, 0.66)
AWNING = (0.84, 0.2, 0.15)
STONE = (0.66, 0.62, 0.56)
STONE_LIGHT = (0.82, 0.76, 0.66)
MORTAR = (0.4, 0.36, 0.32)
POT = (0.2, 0.2, 0.24)
STEW = (0.62, 0.36, 0.16)
WATER = (0.12, 0.32, 0.38)
FRUIT = [(0.96, 0.52, 0.12), (0.9, 0.2, 0.15), (1.0, 0.82, 0.2), (0.55, 0.75, 0.2)]


# --- Helpers -------------------------------------------------------------

def panel(width, height, x_cuts, y_cuts, thickness=0.0):
    """A subdivided flat panel in the local XY plane (normal +Z), centred
    on the origin, so painted patterns (glyphs, stripes, tiles) resolve."""
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=x_cuts, y_segments=y_cuts, size=0.5)
    for v in bm.verts:
        v.co.x *= width
        v.co.y *= height
    obj = common.mesh_object("panel", bm)
    if thickness > 0:
        mod = obj.modifiers.new("Solidify", "SOLIDIFY")
        mod.thickness = thickness
        mod.offset = 0.0
        common.apply_all_modifiers(obj)
    return obj


def place(obj, location=(0, 0, 0), rotation=(0, 0, 0)):
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def post(size, location, seed):
    p = block(size, location=location, bevel=0.02)
    colour_wood(p, seed, base=WOOD_DARK, light=WOOD)
    return p


def export_with_glow(parts, name, glow_parts, budget, size=256):
    body = common.join(parts, name)
    _decimate_to(body, budget)
    paint_bake.paint(body, size=size, ao_distance=0.2, ao_strength=0.65, edge_strength=0.35, edge_radius=0.015,
                     noise_scale=6.0)
    glow = common.join(glow_parts, name + "_glass")
    paint_bake.flat_material(glow, GLOW, emission=2.8, name=name + "_glow")
    common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), [body, glow])
    print(name, "tris:", common.triangle_count([body, glow]))
    preview.render([body, glow], name, elevation=25)


# --- Props -----------------------------------------------------------------

def log_seat():
    """A bark log on two notched chocks; the top is adzed flat to sit on."""
    common.reset(61)
    seat = detail.bark_log(1.3, 0.2, location=(0, 0, 0.21), seed=3, adze=0.93)
    parts = [seat]
    for x in (-0.42, 0.42):
        parts.append(detail.plank((0.12, 0.42, 0.12), location=(x, 0, 0.06), seed=int(x * 10) + 5,
                                  base=WOOD_DARK, light=WOOD, knots=False))
    detail.bake_prop(parts, "log_seat", budget=800, size=512)


def stump_seat():
    common.reset(62)
    parts = [log(0.42, 0.26, rotation=(0, math.radians(-90), 0), location=(0, 0, 0.21), taper=1.05, seed=7)]
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        parts.append(log(0.34, 0.08, rotation=(0, math.radians(32), a),
                         location=(math.cos(a) * 0.27, math.sin(a) * 0.27, 0.06), taper=0.5, seed=i))
    finish_prop(parts, "stump_seat", size=256, budget=600)


def cook_tripod():
    common.reset(63)
    parts = []
    apex = Vector((0, 0, 1.45))
    for i in range(3):
        a = i / 3 * math.tau + 0.5
        foot = Vector((math.cos(a) * 0.62, math.sin(a) * 0.62, 0))
        d = apex - foot
        lg = log(d.length + 0.16, 0.035, segments=6, seed=i)
        place(lg, foot + d * 0.5 + d.normalized() * 0.08, Vector((1, 0, 0)).rotation_difference(d.normalized()).to_euler())
        parts.append(lg)
    tie = rope_ring(0.07, 0.022, (0, 0, 1.4))
    parts.append(tie)
    chain = log(0.42, 0.012, rotation=(0, math.radians(-90), 0), location=(0, 0, 1.15), taper=1.0, segments=5)
    common.set_color(chain, IRON)
    parts.append(chain)
    # A bulging iron pot with stew inside and a bail handle.
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=0.17, radius2=0.22, depth=0.28)
    bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.1], cuts=2)
    for v in bm.verts:
        bulge = 1.0 + 0.18 * (1 - (v.co.z / 0.14) ** 2)
        v.co.x *= bulge
        v.co.y *= bulge
    pot = common.mesh_object("pot", bm)
    common.shade_smooth(pot, auto_angle=50)
    common.color_by(pot, lambda pos, n: STEW if n.z > 0.9 and pos.z > 0.1 else POT, smooth=False)
    place(pot, (0, 0, 0.8))
    parts.append(pot)
    handle = rope_ring(0.24, 0.012, (0, 0, 0.94), rotation=(math.pi / 2, 0, 0))
    common.set_color(handle, IRON)
    parts.append(handle)
    finish_prop(parts, "cook_tripod", size=512, budget=1300)


def camp_sign():
    """The carved tent-glyph signpost of the concept art (front: -Y). The
    glyph is real geometry (a cream inlay with a dark door), so it stays
    crisp at the prop budget."""
    common.reset(64)
    parts = [post((0.14, 0.14, 1.35), (0, 0.04, 0.67), 1)]
    board = block((0.95, 0.09, 0.6), location=(0, -0.04, 1.08), bevel=0.03)
    colour_wood(board, 2, base=WOOD, light=WOOD_LIGHT)
    parts.append(board)
    for points, y, colour in (([(-0.25, -0.2), (0.25, -0.2), (0.0, 0.22)], -0.09, CREAM),
                              ([(-0.08, -0.2), (0.08, -0.2), (0.0, 0.02)], -0.1, WOOD_DARK)):
        bm = bmesh.new()
        verts = [bm.verts.new((x, y, 1.08 + z)) for x, z in points]
        bm.faces.new(verts)
        inlay = common.mesh_object("glyph", bm)
        mod = inlay.modifiers.new("Solidify", "SOLIDIFY")
        mod.thickness = 0.012
        common.apply_all_modifiers(inlay)
        common.set_color(inlay, colour)
        parts.append(inlay)
    for x in (-0.38, 0.38):
        for z in (0.88, 1.28):
            nail = block((0.04, 0.03, 0.04), location=(x, -0.09, z), bevel=0.01)
            common.set_color(nail, IRON)
            parts.append(nail)
    finish_prop(parts, "camp_sign", size=512, budget=1400, edge_strength=0.3)


def lantern_post():
    common.reset(65)
    parts = [post((0.12, 0.12, 1.8), (0, 0, 0.9), 1)]
    arm = post((0.6, 0.08, 0.08), (0.24, 0, 1.72), 2)
    parts.append(arm)
    brace = post((0.34, 0.06, 0.06), (0.11, 0, 1.58), 3)
    brace.rotation_euler = (0, math.radians(-42), 0)
    parts.append(brace)
    c = Vector((0.44, 0, 1.36))
    hook = rope_ring(0.04, 0.01, c + Vector((0, 0, 0.3)), rotation=(math.pi / 2, 0, 0))
    common.set_color(hook, IRON)
    parts.append(hook)
    for offset, size in [((0, 0, 0.17), (0.22, 0.22, 0.05)), ((0, 0, 0.22), (0.12, 0.12, 0.06)),
                         ((0, 0, -0.15), (0.2, 0.2, 0.04))]:
        piece = block(size, location=c + Vector(offset), bevel=0.01)
        common.set_color(piece, IRON)
        parts.append(piece)
    for sx in (-1, 1):
        for sy in (-1, 1):
            rod = block((0.025, 0.025, 0.3), location=c + Vector((sx * 0.09, sy * 0.09, 0)), bevel=0.0)
            common.set_color(rod, IRON)
            parts.append(rod)
    for i in range(3):  # a few stones round the foot
        a = i / 3 * math.tau
        stone = block((0.16, 0.13, 0.1), location=(math.cos(a) * 0.14, math.sin(a) * 0.14, 0.04),
                      rotation=(0, 0, a), bevel=0.04, warp=0.03, seed=i)
        common.set_color(stone, STONE)
        parts.append(stone)
    glass = block((0.15, 0.15, 0.26), location=c, bevel=0.01)
    export_with_glow(parts, "lantern_post", [glass], budget=1200)


STRIPES = 8


def stripes(width):
    def colour(pos, normal):
        return AWNING if int((pos.x + width / 2) / (width / STRIPES)) % 2 == 0 else CANVAS
    return colour


def market_stall():
    """Counter, striped awning and fruit crates (front: -Y). One per map,
    so like the well it may use a little over the prop budget."""
    common.reset(66)
    w, d = 1.8, 0.9
    parts = []
    for sx in (-1, 1):
        for sy, h in ((-1, 1.75), (1, 2.0)):
            parts.append(post((0.1, 0.1, h), (sx * w / 2, sy * d / 2, h / 2), sx * 3 + sy))
    counter = block((w + 0.1, d * 0.9, 0.1), location=(0, 0, 0.86), bevel=0.02)
    colour_wood(counter, 4, base=WOOD_LIGHT, light=(0.88, 0.68, 0.42))
    parts.append(counter)
    front = panel(w, 0.78, 12, 4, thickness=0.05)
    colour_wood(front, 5)
    place(front, (0, -d / 2 + 0.02, 0.45), (math.radians(90), 0, 0))
    parts.append(front)
    # Awning: sloped striped canvas, back high, overhanging the front.
    depth = d + 0.55
    slope = math.atan2(0.4, depth)
    # One face column per stripe, so the stripes survive any decimation.
    awning = panel(w + 0.35, depth / math.cos(slope), STRIPES, 1, thickness=0.03)
    common.color_by(awning, stripes(w + 0.35), smooth=False)
    place(awning, (0, d / 2 - depth / 2, 1.82), (slope, 0, 0))
    parts.append(awning)
    valance = panel(w + 0.35, 0.16, STRIPES, 1, thickness=0.02)
    common.color_by(valance, stripes(w + 0.35), smooth=False)
    place(valance, (0, d / 2 - depth - 0.01, 1.55), (math.radians(90), 0, 0))
    parts.append(valance)
    rng = random.Random(66)
    for i, x in enumerate((-0.55, 0.0, 0.55)):
        box = block((0.46, 0.34, 0.13), location=(x, -0.05, 0.98), bevel=0.015)
        colour_wood(box, 10 + i, base=WOOD_DARK, light=WOOD)
        parts.append(box)
        colour = FRUIT[i % len(FRUIT)]
        for k in range(6):
            bm = bmesh.new()
            bmesh.ops.create_icosphere(bm, subdivisions=0, radius=0.07)
            bmesh.ops.translate(bm, verts=bm.verts, vec=(x + (k % 3 - 1) * 0.13 + rng.uniform(-0.02, 0.02),
                                                         -0.05 + (k // 3 - 0.5) * 0.13, 1.08))
            fruit = common.mesh_object("fruit", bm)
            common.shade_smooth(fruit)
            common.set_color(fruit, FRUIT[(i + 1) % len(FRUIT)] if k == 4 else colour)
            parts.append(fruit)
    for x, s in ((-1.25, 0.5), (1.2, 0.42)):
        crate = block((s, s, s * 0.8), location=(x, -0.1, s * 0.4), rotation=(0, 0, 0.2 * x), bevel=0.02)
        colour_wood(crate, int(x * 10))
        parts.append(crate)
    finish_prop(parts, "market_stall", size=1024, budget=2600, edge_strength=0.3)


def stone_well():
    """A round stone well with posts, a crossbar, a bucket and a red tile
    roof. One per map, so it may use a little over the prop budget."""
    common.reset(67)
    parts = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=28, radius1=0.7, radius2=0.7, depth=0.76)
    bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.5], cuts=7)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.38))
    wall = common.mesh_object("wall", bm)
    mod = wall.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = 0.18
    common.apply_all_modifiers(wall)

    def bricks(pos, normal):
        row = int(pos.z / 0.19)
        angle = (math.atan2(pos.y, pos.x) / math.tau + 0.5 + row * 0.5 / 9) * 9
        if normal.z > 0.7 and pos.z > 0.7:
            return STONE_LIGHT  # the top rim
        if (pos.z / 0.19) % 1.0 < 0.14 or angle % 1.0 < 0.1:
            return MORTAR
        n = noise.noise(Vector((row * 1.7, math.floor(angle), 0.3)))
        return common.lerp(STONE, STONE_LIGHT, max(0.0, min(1.0, 0.5 + n)))
    common.color_by(wall, bricks, smooth=False)
    common.shade_smooth(wall, auto_angle=60)
    parts.append(wall)
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=16, radius=0.62)
    water = common.mesh_object("water", bm)
    common.set_color(water, WATER)
    place(water, (0, 0, 0.5))
    parts.append(water)
    for x in (-0.66, 0.66):
        parts.append(post((0.12, 0.12, 1.55), (x, 0, 0.95), int(x * 10)))
    bar = log(1.5, 0.05, location=(0, 0, 1.48), seed=4)
    parts.append(bar)
    rope = log(0.38, 0.012, rotation=(0, math.radians(-90), 0), location=(0, 0, 1.28), taper=1.0, segments=5)
    common.set_color(rope, ROPE)
    parts.append(rope)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.1, radius2=0.13, depth=0.18)
    bucket = common.mesh_object("bucket", bm)
    colour_wood(bucket, 6)
    place(bucket, (0, 0, 1.0))
    parts.append(bucket)
    # Gable roof of two tiled panels meeting over the crossbar.
    pitch = math.radians(34)
    for side in (-1, 1):
        roof = panel(1.75, 0.78, 14, 6, thickness=0.06)

        def tiles(pos, normal):
            course = (pos.y + 0.39) / 0.13
            if course % 1.0 < 0.18:
                return ROOF
            n = noise.noise(Vector((math.floor(pos.x / 0.125 + (math.floor(course) % 2) * 0.5), math.floor(course), 0.5)))
            return common.lerp(ROOF, ROOF_LIGHT, max(0.0, min(1.0, 0.45 + n)))
        common.color_by(roof, tiles, smooth=False)
        # Each panel hangs down and outward from the ridge at z = 2.0.
        place(roof, (0, side * math.cos(pitch) * 0.39, 2.0 - math.sin(pitch) * 0.39), (-side * pitch, 0, 0))
        parts.append(roof)
    ridge = block((1.85, 0.12, 0.1), location=(0, 0, 1.97), bevel=0.03)
    common.set_color(ridge, ROOF)
    parts.append(ridge)
    finish_prop(parts, "stone_well", size=1024, budget=2400, edge_strength=0.35)


PROPS = {
    "log_seat": log_seat, "stump_seat": stump_seat, "cook_tripod": cook_tripod, "camp_sign": camp_sign,
    "lantern_post": lantern_post, "market_stall": market_stall, "stone_well": stone_well,
}

if __name__ == "__main__":
    for name in (sys.argv[1:] or PROPS.keys()):
        random.seed(hash(name) & 0xFFFF)
        PROPS[name]()
