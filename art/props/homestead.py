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
from props.camp import (CANVAS, EARTH, IRON, MOSS, ROOF, ROOF_LIGHT, ROPE, RUST, WOOD, WOOD_DARK,  # noqa: E402
                        WOOD_LIGHT, _apply, _clamp, _tri_grid, block, board, colour_wood, dense_box, disc, helix, log,
                        low_disc, nail, revolve, rope_loop, rope_ring, rope_tube, shingles, stone, wood_colour)
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


def iron_colour(p, n):
    """Hammered iron with a little rust."""
    c = common.lerp(IRON, (0.44, 0.46, 0.52), _clamp(0.5 + noise.noise(p * 28.0) * 0.8))
    rust = noise.noise(p * 14.0 + Vector((3, 1, 0)))
    if rust > 0.35:
        c = common.lerp(c, RUST, _clamp((rust - 0.35) * 3) * 0.6)
    return c


def stump_seat():
    """A sawn stump on four bark roots: checked end grain on top."""
    common.reset(62)
    stump = detail.bark_log(0.42, 0.26, rotation=(0, math.radians(-90), 0), location=(0, 0, 0.21), taper=1.05, seed=7,
                            segments=96)
    _apply(stump)
    common.grime(stump, MOSS, lambda p, n: _clamp((0.12 - p.z) / 0.1 + noise.noise(p * 8.0) * 0.8 - 0.3) * 0.6)
    parts = [stump]
    top_z = max(v.co.z for v in stump.data.vertices)
    top_r = 0.26 * 1.05 * 0.86
    face = disc(top_r, top_z - 0.004, step=0.008, name="end_grain")
    cracks = [0.4, 2.3, 4.2, 5.4]
    for v in face.data.vertices:
        r = Vector((v.co.x, v.co.y)).length
        a = math.atan2(v.co.y, v.co.x)
        v.co.z += noise.noise(Vector((v.co.x * 9, v.co.y * 9, 1.0))) * 0.004 + 0.006 * (1 - (r / top_r) ** 2)
        for k, ca in enumerate(cracks):
            d = abs((a - ca + math.pi) % math.tau - math.pi) * r
            reach = top_r * (0.95 if k % 2 == 0 else 0.6)
            if d < 0.007 and 0.02 < r < reach:
                v.co.z -= 0.014 * (1 - d / 0.007)

    def grain(p, n):
        r = Vector((p.x, p.y)).length
        t = r / top_r
        a = math.atan2(p.y, p.x)
        rings = math.sin(t * 40.0 + noise.noise(Vector((p.x * 6, p.y * 6, 2.0))) * 2.5) * 0.5 + 0.5
        c = common.lerp(detail.END_GRAIN, detail.RING, rings * 0.5 + t * 0.25)
        if t < 0.08:
            c = common.lerp(c, detail.RING, 0.6)
        for k, ca in enumerate(cracks):
            d = abs((a - ca + math.pi) % math.tau - math.pi) * r
            if d < 0.008 and 0.02 < r < top_r * (0.95 if k % 2 == 0 else 0.6):
                c = common.lerp(c, detail.BARK_DARK, 0.85 * (1 - d / 0.008))
        saw = noise.noise(Vector((p.x * 3.0, p.y * 40.0, 0.5)))
        return common.lerp(c, detail.SEAT, _clamp(saw) * 0.3)
    common.color_by(face, grain, smooth=True)
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        root = detail.bark_log(0.34, 0.08, rotation=(0, math.radians(32), a),
                               location=(math.cos(a) * 0.27, math.sin(a) * 0.27, 0.06), taper=0.5, seed=i + 3,
                               segments=40)
        _apply(root)
        common.grime(root, EARTH, lambda p, n: _clamp((0.05 - p.z) / 0.06) * 0.7)
        parts.append(root)
    detail.bake_prop_lows(parts, "stump_seat", budget=600, dense_only=[face], size=512, ray=0.03)


def _link(centre, turn, size=0.022, thick=0.0065):
    loop = rope_loop(size * 0.62, thick, rotation=(math.pi / 2, 0, turn), squash=1.0, strands=0, base=IRON, seg=8)
    # Stretch the ring into an oval link along its local up (Z after the rotation).
    _apply(loop)
    for v in loop.data.vertices:
        v.co.z *= 1.6
    loop.location = centre
    _apply(loop)
    common.color_by(loop, iron_colour, smooth=True)
    return loop


def cook_tripod():
    """Three bark poles lashed with rope, an iron chain, a sooty bulging pot
    of stew on a bail handle."""
    common.reset(63)
    parts = []
    apex = Vector((0, 0, 1.45))
    for i in range(3):
        a = i / 3 * math.tau + 0.5
        foot = Vector((math.cos(a) * 0.62, math.sin(a) * 0.62, 0))
        d = apex - foot
        lg = detail.bark_log(d.length + 0.16, 0.035, seed=i + 4, segments=20, groove=0.16)
        place(lg, foot + d * 0.5 + d.normalized() * 0.08, Vector((1, 0, 0)).rotation_difference(d.normalized()).to_euler())
        parts.append(lg)
    for k, (z, tilt) in enumerate(((1.37, 0.25), (1.405, -0.2), (1.44, 0.1))):
        parts.append(rope_loop(0.068, 0.016, (0, 0, z), rotation=(tilt, -tilt * 0.6, k)))
    # Chain from the lashing down to the bail.
    z = 1.34
    k = 0
    while z > 1.15:
        parts.append(_link((0, 0, z), (k % 2) * math.pi / 2))
        z -= 0.03
        k += 1
    pz = 0.66
    rim = 0.94
    pot = revolve([(0.0, pz), (0.12, pz), (0.17, pz + 0.03), (0.2, pz + 0.08), (0.212, pz + 0.14), (0.205, pz + 0.2),
                   (0.185, pz + 0.255), (0.19, rim - 0.005), (0.2, rim), (0.192, rim + 0.008), (0.178, rim),
                   (0.172, rim - 0.035)], 48, name="pot")

    def pot_colour(p, n):
        c = common.lerp(POT, (0.32, 0.31, 0.34), _clamp(0.5 + noise.noise(p * 24.0) * 0.7))
        soot = _clamp((pz + 0.12 - p.z) / 0.1) * 0.7
        c = common.lerp(c, (0.08, 0.07, 0.07), soot)
        if p.z > rim - 0.008 and n.z > 0.3:
            c = common.lerp(c, (0.5, 0.5, 0.55), 0.5)
        if noise.noise(p * 12.0 + Vector((0, 4, 0))) > 0.5:
            c = common.lerp(c, RUST, 0.35)
        return c
    common.color_by(pot, pot_colour, smooth=True)
    parts.append(pot)
    stew = disc(0.176, rim - 0.03, step=0.012, name="stew")
    rng = random.Random(63)
    bubbles = [(Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12))), rng.uniform(0.012, 0.022)) for _ in range(7)]
    for v in stew.data.vertices:
        for c, r in bubbles:
            d = (Vector((v.co.x, v.co.y)) - c).length
            if d < r:
                v.co.z += (r * r - d * d) ** 0.5 * 0.8

    def stew_colour(p, n):
        c = common.lerp(STEW, (0.78, 0.5, 0.22), _clamp(0.5 + noise.noise(p * 30.0)))
        bits = noise.noise(p * 45.0 + Vector((7, 0, 0)))
        if bits > 0.45:
            c = (0.96, 0.6, 0.2)  # carrot
        elif bits < -0.5:
            c = (0.45, 0.6, 0.24)  # herbs
        return c
    common.color_by(stew, stew_colour, smooth=True)
    dense, lows = [stew], [low_disc(0.18, rim - 0.022, 16)]
    for sx in (-1, 1):
        lug = dense_box((0.03, 0.04, 0.035), location=(sx * 0.205, 0, rim - 0.03), bevel=0.008, step=0.01)
        common.color_by(lug, iron_colour, smooth=True)
        parts.append(lug)
    bail = [(math.cos(t) * 0.215, 0, rim - 0.03 + math.sin(t) * 0.2) for t in (math.pi * k / 24 for k in range(25))]
    bail_obj = rope_tube(bail, 0.008, strands=0, base=IRON, seg=8)
    common.color_by(bail_obj, iron_colour, smooth=True)
    parts.append(bail_obj)
    detail.bake_prop_lows(parts, "cook_tripod", budget=1300, lows=lows, dense_only=dense, size=512, ray=0.03)


def camp_sign():
    """The carved tent-glyph signpost of the concept art (front: -Y): three
    nailed planks on a post, the glyph a raised cream inlay with a dark door."""
    common.reset(64)
    parts = [board((1.35, 0.14, 0.14), location=(0, 0.04, 0.675), rotation=(0, math.radians(90), 0), seed=1,
                   base=WOOD_DARK, light=WOOD, bevel=0.02)]
    for k in range(3):
        z = 1.08 + (k - 1) * 0.2
        parts.append(board((0.95 - 0.02 * (k % 2), 0.07, 0.19), location=(0.008 * (k - 1), -0.045, z),
                           rotation=(0, 0.015 * (k - 1), 0), seed=k + 2, warp=0.006))
        for x in (-0.38, 0.38):
            parts.append(nail((x, -0.082, z), (0, -1, 0), radius=0.016))
    for points, y, colour in (([(-0.25, -0.2), (0.25, -0.2), (0.0, 0.22)], -0.088, CREAM),
                              ([(-0.08, -0.2), (0.08, -0.2), (0.0, 0.02)], -0.094, WOOD_DARK)):
        bm = bmesh.new()
        _tri_grid(bm, *[(x, y, 1.08 + z) for x, z in points], 16)
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        inlay = common.mesh_object("glyph", bm)
        mod = inlay.modifiers.new("Solidify", "SOLIDIFY")
        mod.thickness = 0.012
        common.apply_all_modifiers(inlay)
        common.shade_smooth(inlay, auto_angle=40)
        common.color_by(inlay, lambda p, n, colour=colour: common.lerp(colour, (0.98, 0.95, 0.82) if colour == CREAM
                        else (0.2, 0.12, 0.08), _clamp(noise.noise(p * 30.0) * 0.8)), smooth=True)
        parts.append(inlay)
    detail.bake_prop(parts, "camp_sign", budget=1200, size=512, ray=0.03, edge_strength=0.3)


def lantern_post():
    common.reset(65)
    parts = [board((1.8, 0.12, 0.12), location=(0, 0, 0.9), rotation=(0, math.radians(90), 0), seed=1,
                   base=WOOD_DARK, light=WOOD_LIGHT, dark=(0.2, 0.12, 0.07), bevel=0.018, step=0.015, carve=0.008)]
    common.grime(parts[0], EARTH, lambda p, n: _clamp((p.x - 0.65) / 0.25) * 0.5)
    parts.append(board((0.6, 0.08, 0.08), location=(0.24, 0, 1.72), seed=2, base=WOOD_DARK, light=WOOD))
    parts.append(board((0.34, 0.06, 0.06), location=(0.11, 0, 1.58), rotation=(0, math.radians(-42), 0), seed=3,
                       base=WOOD_DARK, light=WOOD))
    for p, nrm in (((0.04, -0.041, 1.72), (0, -1, 0)), ((0.4, -0.041, 1.72), (0, -1, 0)), ((0.2, -0.031, 1.69), (0, -1, 0))):
        parts.append(nail(p, nrm, radius=0.012))
    parts.append(rope_tube(helix(0.088, 1.4, 1.48, 2.0, centre=(0, 0)), 0.012))
    strap = dense_box((0.135, 0.135, 0.04), location=(0, 0, 1.78), bevel=0.006, step=0.012)
    common.color_by(strap, iron_colour, smooth=True)
    parts.append(strap)
    for a in range(4):
        d = Vector((math.cos(a * math.pi / 2), math.sin(a * math.pi / 2), 0))
        parts.append(nail(Vector((0, 0, 1.78)) + d * 0.0675, d, radius=0.009))
    c = Vector((0.44, 0, 1.36))
    hook = rope_loop(0.04, 0.01, c + Vector((0, 0, 0.3)), rotation=(math.pi / 2, 0, 0), strands=0, base=IRON, seg=8)
    common.color_by(hook, iron_colour, smooth=True)
    parts.append(hook)
    for offset, size in [((0, 0, 0.17), (0.22, 0.22, 0.05)), ((0, 0, 0.22), (0.12, 0.12, 0.06)),
                         ((0, 0, -0.15), (0.2, 0.2, 0.04))]:
        piece = dense_box(size, location=c + Vector(offset), bevel=0.012, step=0.015)
        common.color_by(piece, iron_colour, smooth=True)
        parts.append(piece)
        for sx in (-1, 1):
            for sy in (-1, 1):
                if size[2] < 0.06:
                    parts.append(nail(c + Vector(offset) + Vector((sx * (size[0] / 2 - 0.02), sy * (size[1] / 2 - 0.02),
                                                                    size[2] / 2)), (0, 0, 1), radius=0.008))
    for sx in (-1, 1):
        for sy in (-1, 1):
            rod = dense_box((0.025, 0.025, 0.3), location=c + Vector((sx * 0.09, sy * 0.09, 0)), bevel=0.006, step=0.012)
            common.color_by(rod, iron_colour, smooth=True)
            parts.append(rod)
    for i in range(3):
        a = i / 3 * math.tau
        parts.append(stone((0.16, 0.13, 0.1), location=(math.cos(a) * 0.14, math.sin(a) * 0.14, 0.0), rotation=(0, 0, a),
                           seed=i + 5, base=STONE, light=STONE_LIGHT, moss=0.5))
    glass = block((0.15, 0.15, 0.26), location=c, bevel=0.01)
    glass = common.join([glass], "lantern_post_glass")
    paint_bake.flat_material(glass, GLOW, emission=2.8, name="lantern_post_glow")
    detail.bake_prop(parts, "lantern_post", budget=1200, size=512, preview_elevation=25, ray=0.03, extra=[glass],
                     ao_distance=0.2, ao_strength=0.65, edge_strength=0.35, edge_radius=0.015)


STRIPES = 8


def stripes(width):
    def colour(pos, normal):
        return AWNING if int((pos.x + width / 2) / (width / STRIPES)) % 2 == 0 else CANVAS
    return colour


def _sheet(width, height, cols, rows, thickness, bottom=None, sag=None):
    """A grid sheet in the local XY plane (normal +Z), solidified. bottom(x)
    gives a shaped lower edge (scallops); sag(x, y) bows it along Z."""
    bm = bmesh.new()
    grid = []
    for j in range(rows + 1):
        row = []
        for i in range(cols + 1):
            x = -width / 2 + width * i / cols
            y0 = bottom(x) if bottom else -height / 2
            y = y0 + (height / 2 - y0) * j / rows
            z = sag(x, y) if sag else 0.0
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(rows):
        for i in range(cols):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    obj = common.mesh_object("sheet", bm)
    mod = obj.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 0.0
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj, auto_angle=40)
    return obj


def _canvas_stripes(width, seed):
    sw = width / STRIPES

    def colour(pos, normal):
        f = (pos.x + width / 2) / sw
        red = int(f) % 2 == 0
        c = AWNING if red else CANVAS
        stain = noise.noise(Vector((pos.x * 2.0, pos.y * 2.0, seed)))
        c = common.lerp(c, (0.98, 0.92, 0.78) if not red else (0.92, 0.32, 0.22), _clamp(stain) * 0.5)
        c = common.lerp(c, (0.7, 0.56, 0.42) if not red else (0.62, 0.14, 0.1), _clamp(-stain - 0.3) * 0.5)
        edge = min(f % 1.0, 1 - f % 1.0) * sw
        if 0.012 < edge < 0.026 and int(pos.y * 40) % 2 == 0:
            c = common.lerp(c, (0.4, 0.26, 0.18), 0.55)  # stitched seams
        return c
    return colour


def _fruit(centre, radius, colour, seed):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=18, v_segments=12, radius=radius)
    for v in bm.verts:
        v.co.z *= 0.9
        v.co *= 1.0 + noise.noise(v.co * 30.0 + Vector((seed, 0, 0))) * 0.03
    obj = common.mesh_object("fruit", bm)
    common.shade_smooth(obj)
    light = common.lerp(colour, (1.0, 0.95, 0.7), 0.35)
    dark = common.lerp(colour, (0.3, 0.1, 0.05), 0.4)

    def col(p, n):
        if p.z > radius * 0.8 and Vector((p.x, p.y)).length < radius * 0.18:
            return (0.3, 0.2, 0.1)  # stem dimple
        c = common.lerp(colour, light, _clamp(n.z * 0.6 + noise.noise(p * 60.0) * 0.3))
        return common.lerp(c, dark, _clamp(-n.z) * 0.5)
    common.color_by(obj, col, smooth=True)
    obj.location = centre
    return obj


def slat_crate(size, location, rotation_z, seed, lid=True):
    """A small crate: dark core, slatted boards on four sides, corner posts."""
    sx, sy, sz = size
    parts = []
    core = block((sx - 0.04, sy - 0.04, sz - 0.02), location=(0, 0, sz / 2), bevel=0.0)
    common.set_color(core, (0.16, 0.1, 0.07))
    parts.append(core)
    slats = max(2, int(sz / 0.1))
    for k, (nx, ny) in enumerate(((0, -1), (0, 1), (1, 0), (-1, 0))):
        length = sx - 0.06 if nx == 0 else sy - 0.06
        for b in range(slats):
            z = (b + 0.5) * sz / slats
            loc = (nx * (sx / 2 - 0.012), ny * (sy / 2 - 0.012), z)
            parts.append(board((length, 0.022, sz / slats - 0.012), location=loc,
                               rotation=(0, 0, 0 if nx == 0 else math.pi / 2), seed=seed + k * 5 + b, step=0.02,
                               warp=0.003, bevel=0.006))
    for px in (-1, 1):
        for py in (-1, 1):
            parts.append(board((sz, 0.045, 0.045), location=(px * (sx / 2 - 0.02), py * (sy / 2 - 0.02), sz / 2),
                               rotation=(0, math.radians(90), 0), seed=seed + px + py * 3, base=WOOD_DARK, light=WOOD,
                               bevel=0.008, step=0.02))
    if lid:
        n = max(2, int(sx / 0.13))
        for b in range(n):
            x = -sx / 2 + (b + 0.5) * sx / n
            parts.append(board((sy - 0.01, sx / n - 0.012, 0.025), location=(x, 0, sz - 0.005),
                               rotation=(0, 0, math.pi / 2), seed=seed + 40 + b, step=0.02, bevel=0.006))
    obj = _apply(common.join(parts, "crate"))
    obj.rotation_euler = (0, 0, rotation_z)
    obj.location = location
    return obj


def market_stall():
    """Counter, striped awning and fruit crates (front: -Y). One per map,
    so like the well it may use a little over the prop budget. The canvas
    is modelled dense (seams, stitches, sag, scalloped valance) and baked
    onto a clean low sheet, so the stripes stay crisp."""
    common.reset(66)
    w, d = 1.8, 0.9
    parts = []
    for sx in (-1, 1):
        for sy, h in ((-1, 1.71), (1, 1.96)):
            parts.append(board((h, 0.1, 0.1), location=(sx * w / 2, sy * d / 2, h / 2), rotation=(0, math.radians(90), 0),
                               seed=sx * 3 + sy + 10, base=WOOD_DARK, light=WOOD, bevel=0.015))
    n = 3
    for k in range(n):
        y = -d * 0.45 + (k + 0.5) * d * 0.9 / n
        parts.append(board((w + 0.1, d * 0.9 / n - 0.008, 0.08), location=(0, y, 0.87), seed=k + 20,
                           base=WOOD_LIGHT, light=(0.88, 0.68, 0.42), warp=0.005))
    nb = 9
    for k in range(nb):
        x = -w / 2 + (k + 0.5) * w / nb
        parts.append(board((0.78, 0.04, w / nb - 0.01), location=(x, -d / 2 + 0.02, 0.45), rotation=(0, math.radians(90), 0),
                           seed=k + 30, warp=0.004))
    for z in (0.2, 0.68):
        parts.append(board((w, 0.03, 0.08), location=(0, -d / 2 - 0.015, z), seed=int(z * 10) + 40, base=WOOD_DARK,
                           light=WOOD))
        for k in range(nb):
            x = -w / 2 + (k + 0.5) * w / nb
            parts.append(nail((x, -d / 2 - 0.031, z), (0, -1, 0), radius=0.011))
    # Awning: sloped striped canvas, back high, overhanging the front.
    depth = d + 0.55
    slope = math.atan2(0.4, depth)
    aw = w + 0.35
    length = depth / math.cos(slope)

    def sag(x, y):
        f = (x + aw / 2) / (aw / STRIPES)
        return -0.03 * math.sin(math.pi * (y / length + 0.5)) - 0.006 * math.sin(math.pi * (f % 1.0))
    awning = _sheet(aw, length, STRIPES * 14, 40, 0.03, sag=sag)
    common.color_by(awning, _canvas_stripes(aw, 1), smooth=False)
    place(awning, (0, d / 2 - depth / 2, 1.82), (slope, 0, 0))
    low_awning = _sheet(aw, length, STRIPES, 3, 0.03, sag=lambda x, y: -0.03 * math.sin(math.pi * (y / length + 0.5)))
    place(low_awning, (0, d / 2 - depth / 2, 1.82), (slope, 0, 0))

    def scallop(x):
        f = ((x + aw / 2) / (aw / STRIPES)) % 1.0
        return -0.08 - 0.05 * math.sin(math.pi * f)
    valance = _sheet(aw, 0.16, STRIPES * 14, 10, 0.02, bottom=scallop)
    common.color_by(valance, _canvas_stripes(aw, 2), smooth=False)
    place(valance, (0, d / 2 - depth - 0.01, 1.55), (math.radians(90), 0, 0))
    low_valance = _sheet(aw, 0.16, STRIPES * 4, 1, 0.02, bottom=scallop)
    place(low_valance, (0, d / 2 - depth - 0.01, 1.55), (math.radians(90), 0, 0))
    rng = random.Random(66)
    for i, x in enumerate((-0.55, 0.0, 0.55)):
        parts.append(slat_crate((0.46, 0.34, 0.13), (x, -0.05, 0.915), 0.0, seed=100 + i * 20, lid=False))
        colour = FRUIT[i % len(FRUIT)]
        spots = [((k % 3 - 1) * 0.13, (k // 3 - 0.5) * 0.13, 1.08) for k in range(6)]
        spots += [((k - 1) * 0.12 + 0.03, 0.0, 1.15) for k in range(2)] + [(-0.06, 0.02, 1.15)]
        for k, (fx, fy, fz) in enumerate(spots):
            c = FRUIT[(i + 1) % len(FRUIT)] if k == 4 else colour
            parts.append(_fruit((x + fx + rng.uniform(-0.015, 0.015), -0.05 + fy + rng.uniform(-0.015, 0.015), fz),
                                0.068 + rng.uniform(-0.006, 0.006), c, seed=i * 10 + k))
    for x, s in ((-1.25, 0.5), (1.2, 0.42)):
        parts.append(slat_crate((s, s, s * 0.8), (x, -0.1, 0.0), 0.2 * x, seed=int(x * 10) + 200))
    detail.bake_prop_lows(parts, "market_stall", budget=2600, lows=[low_awning, low_valance],
                          dense_only=[awning, valance], size=1024, ray=0.04, edge_strength=0.3)


def _arc_stone(a0, a1, r_in, r_out, z0, z1, seed):
    """A rounded stone block bent around the well's circle."""
    rng = random.Random(seed)
    rm = (r_in + r_out) / 2
    arc = (a1 - a0) * rm
    obj = dense_box((arc, r_out - r_in, z1 - z0), bevel=min(0.035, (z1 - z0) * 0.3), step=0.018)
    off = Vector((seed * 1.3, seed * 0.7, 0))
    for v in obj.data.vertices:
        u, w, h = v.co
        bulge = noise.noise(Vector((u * 8, w * 8, h * 8)) + off) * 0.01
        a = a0 + (u + arc / 2) / rm
        # -w points outward: (tangent, -radial, up) keeps the box right-handed.
        r = rm - w + (bulge if w < 0 else -bulge * 0.5)
        v.co = Vector((math.cos(a) * r, math.sin(a) * r, (z0 + z1) / 2 + h + bulge * 0.4))
    common.shade_smooth(obj, auto_angle=40)
    tone = rng.random()
    base = common.lerp(STONE, STONE_LIGHT, tone * 0.7)

    def colour(p, n):
        g = noise.noise(p * 9.0 + off)
        c = common.lerp(base, STONE_LIGHT, _clamp(0.4 + g * 0.6))
        speck = noise.noise(p * 26.0 + off)
        if speck > 0.4:
            c = common.lerp(c, MORTAR, 0.35)
        if p.z < 0.14:
            c = common.lerp(c, MOSS, _clamp((0.14 - p.z) / 0.1 + noise.noise(p * 6.0) * 0.6 - 0.2) * 0.6)
        if n.z > 0.6 and noise.noise(p * 7.0 + off) > 0.35:
            c = common.lerp(c, (0.7, 0.72, 0.5), 0.35)  # lichen
        return c
    common.color_by(obj, colour, smooth=True)
    return obj


def stone_well():
    """A round well of fitted stones with mortar joints and a capstone rim,
    posts, a crossbar with rope coils and a crank, a staved bucket, and a
    roof of red barrel tiles. One per map, so it may use a little over the
    prop budget."""
    common.reset(67)
    rng = random.Random(67)
    parts = []
    mortar = revolve([(0.56, 0.0), (0.66, 0.0), (0.66, 0.73), (0.56, 0.73)], 40, name="mortar")
    common.color_by(mortar, lambda p, n: common.lerp(MORTAR, (0.5, 0.46, 0.4), _clamp(0.5 + noise.noise(p * 20.0))),
                    smooth=True)
    parts.append(mortar)
    courses, per = 4, 11
    for k in range(courses):
        z0, z1 = k * 0.18 + 0.006, (k + 1) * 0.18 - 0.006
        shift = (0.5 if k % 2 else 0.0) + rng.uniform(-0.1, 0.1)
        for j in range(per):
            a0 = (j + shift) / per * math.tau + 0.012
            a1 = (j + 1 + shift) / per * math.tau - 0.012
            parts.append(_arc_stone(a0, a1, 0.54 + rng.uniform(-0.01, 0.01), 0.69 + rng.uniform(-0.012, 0.01),
                                    z0 + rng.uniform(0, 0.008), z1 - rng.uniform(0, 0.01), seed=k * 20 + j))
    for j in range(9):
        a0 = (j + 0.2) / 9 * math.tau + 0.01
        a1 = (j + 1.2) / 9 * math.tau - 0.01
        parts.append(_arc_stone(a0, a1, 0.5, 0.72, 0.72, 0.8 + rng.uniform(-0.006, 0.006), seed=200 + j))
    water = disc(0.55, 0.5, step=0.02, name="water")

    def water_colour(p, n):
        r = Vector((p.x, p.y)).length
        ripple = math.sin(r * 60.0 + noise.noise(p * 5.0) * 3.0)
        c = common.lerp(WATER, (0.2, 0.46, 0.52), _clamp(ripple * 0.5 + 0.2) * 0.6)
        return common.lerp(c, (0.06, 0.16, 0.2), _clamp((r - 0.42) / 0.12))
    common.color_by(water, water_colour, smooth=True)
    lows, dense = [low_disc(0.57, 0.5, 20)], [water]
    for x in (-0.66, 0.66):
        parts.append(board((1.55, 0.12, 0.12), location=(x, 0, 0.95), rotation=(0, math.radians(90), 0), seed=int(x * 10) + 7,
                           base=WOOD_DARK, light=WOOD, bevel=0.018))
    parts.append(detail.bark_log(1.5, 0.05, location=(0, 0, 1.48), seed=4, segments=32))
    parts.append(board((0.2, 0.04, 0.04), location=(0.8, 0, 1.39), rotation=(0, math.radians(90), 0), seed=9,
                       base=WOOD_DARK, light=WOOD, bevel=0.01, step=0.015))
    parts.append(detail.bark_log(0.12, 0.018, location=(0.84, 0, 1.3), seed=5, segments=16))
    for k in range(5):
        parts.append(rope_loop(0.058, 0.012, (-0.08 + k * 0.04, 0, 1.48), rotation=(0, math.radians(90), 0)))
    parts.append(rope_tube([(0, 0.055, 1.47), (0, 0.06, 1.3), (0, 0.0, 1.17)], 0.012, seg=10))
    bz0, bz1 = 0.91, 1.09
    bucket = revolve([(0.0, bz0), (0.1, bz0), (0.13, bz1), (0.118, bz1), (0.105, bz1 - 0.03)], 40,
                     shape=lambda a, z, r: r * (1 - 0.03 * _clamp(1 - min((a / math.tau * 10) % 1, 1 - (a / math.tau * 10) % 1) / 0.08)),
                     name="bucket")
    common.color_by(bucket, wood_colour(6, along=2, knots=False), smooth=True)
    parts.append(bucket)
    bucket_water = low_disc(0.112, bz1 - 0.028, 12)
    common.set_color(bucket_water, WATER)
    parts.append(bucket_water)
    for z in (0.94, 1.06):
        rr = 0.1 + 0.03 * (z - bz0) / (bz1 - bz0)
        hoop = revolve([(rr - 0.004, z - 0.012), (rr + 0.007, z - 0.012), (rr + 0.008, z + 0.012), (rr - 0.004, z + 0.012)],
                       40, name="hoop")
        common.color_by(hoop, iron_colour, smooth=True)
        parts.append(hoop)
    handle = rope_tube([(math.cos(t) * 0.13, 0, 1.07 + math.sin(t) * 0.1) for t in (math.pi * k / 16 for k in range(17))],
                       0.007, strands=0, base=IRON, seg=8)
    common.color_by(handle, iron_colour, smooth=True)
    parts.append(handle)
    # Gable roof: a plank deck under two panels of overlapping barrel tiles.
    pitch = math.radians(34)
    for side in (-1, 1):
        loc = (0, side * math.cos(pitch) * 0.39, 2.0 - math.sin(pitch) * 0.39)
        rot = (-side * pitch, 0, 0)
        deck = _sheet(1.75, 0.78, 50, 22, 0.06)
        common.color_by(deck, lambda p, n: wood_colour(int(p.y * 7) + 3, WOOD_DARK, WOOD, (0.22, 0.13, 0.08))(p, n)
                        if abs((p.y * 7) % 1.0 - 0.5) < 0.44 else (0.2, 0.12, 0.08), smooth=True)
        place(deck, loc, rot)
        parts.append(deck)
        e = 0.42 * side
        tiles = shingles(((-0.9 * side, e, 0.03), (0.9 * side, e, 0.03), (0.9 * side, -0.39 * side, 0.03),
                          (-0.9 * side, -0.39 * side, 0.03)), rows=6, cols=12, normal=(0, 0, 1), lift=0.03, arch=0.022,
                         gap=0.014, overlap=0.3, seed=300 + side, res=6, round_tabs=0.35)
        place(tiles, loc, rot)
        dense.append(tiles)
        low = _sheet(1.8, 0.84, 6, 3, 0.05)
        for v in low.data.vertices:
            v.co.z += 0.055
            v.co.y += 0.015 * side
        place(low, loc, rot)
        lows.append(low)
    for k in range(11):
        x = -0.85 + k * 0.17
        cap = revolve([(0.0, -0.09), (0.06, -0.09), (0.066, 0.0), (0.072, 0.09), (0.0, 0.09)], 20, name="ridge_tile")
        cap.rotation_euler = (0, math.radians(90), 0)
        cap.location = (x, 0, 1.965)
        common.color_by(cap, lambda p, n: common.lerp(ROOF, (0.55, 0.16, 0.12), _clamp(0.5 + noise.noise(p * 25.0))),
                        smooth=True)
        parts.append(cap)
    detail.bake_prop_lows(parts, "stone_well", budget=2600, lows=lows, dense_only=dense, size=1024, ray=0.08,
                          edge_strength=0.35)


PROPS = {
    "log_seat": log_seat, "stump_seat": stump_seat, "cook_tripod": cook_tripod, "camp_sign": camp_sign,
    "lantern_post": lantern_post, "market_stall": market_stall, "stone_well": stone_well,
}

if __name__ == "__main__":
    for name in (sys.argv[1:] or PROPS.keys()):
        random.seed(hash(name) & 0xFFFF)
        PROPS[name]()
