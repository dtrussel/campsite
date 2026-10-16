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

from lib import common, detail, paint_bake, preview  # noqa: E402
from nature.trees import skin_trunk  # noqa: E402
from props.camp import IRON, WOOD, WOOD_DARK, WOOD_LIGHT, block, colour_wood, log, rope_ring  # noqa: E402
from props.forage import (_decimate_to, _place, _wood_grain, board, dense_block, dense_cylinder, displace,  # noqa: E402
                          finish_prop, iron_colour, rivets, torus)

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

FLESH = (0.98, 0.78, 0.38)


def pumpkin_body(radius, height, colour_main, colour_dark, seed):
    """A dense ribbed pumpkin on z = 0: 8 deep ribs with soft grooves,
    fine vertical striations, speckles and a blemish or two."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=128, v_segments=64, radius=1.0)
    for v in bm.verts:
        angle = math.atan2(v.co.y, v.co.x)
        g = 0.5 + 0.5 * math.cos(angle * 8)
        rib = 1.0 - 0.1 * (1.0 - g ** 0.6)  # rounded lobes, sharper grooves
        rib *= 1.0 + noise.noise(Vector((math.cos(angle) * 2, math.sin(angle) * 2, v.co.z + seed))) * 0.03
        v.co.x *= radius * rib
        v.co.y *= radius * rib
        v.co.z = (v.co.z * 0.5 + 0.5) * height  # sit on z = 0
        pinch = 1.0 - 0.18 * (abs(v.co.z / height - 0.5) * 2) ** 3
        v.co.x *= pinch
        v.co.y *= pinch
    bm.normal_update()
    obj = common.mesh_object("pumpkin", bm)
    common.shade_smooth(obj)

    def colour(pos, normal):
        angle = math.atan2(pos.y, pos.x)
        groove = 0.5 + 0.5 * math.cos(angle * 8)
        streak = noise.noise(Vector((math.cos(angle) * 30, math.sin(angle) * 30, pos.z * 2.0 + seed)))
        c = common.lerp(colour_dark, colour_main, min(1.0, groove * 1.2 + 0.15 + streak * 0.18
                                                      + noise.noise(pos * 5 + Vector((seed, 0, 0))) * 0.12))
        speck = noise.noise(pos * 60.0 + Vector((0, seed, 0)))
        if speck > 0.55:
            c = common.lerp(c, PUMPKIN_YELLOW, 0.5)
        blem = noise.noise(pos * 4.0 + Vector((seed * 3, 1, 2)))
        if blem > 0.55:
            c = common.lerp(c, (0.55, 0.42, 0.2), min(1.0, (blem - 0.55) * 6) * 0.5)  # weathered scar
        t = pos.z / height
        if t > 0.86 or t < 0.08:
            c = common.lerp(c, (0.5, 0.48, 0.2), 0.35 * min(1.0, abs(t - 0.5) * 5 - 1.8))  # greenish poles
        return c
    common.color_by(obj, colour, smooth=True)
    return obj


def pumpkin_stem(height, seed, scale=1.0, bend_deg=35.0):
    """A ridged, slightly curled stem with a cut, paler tip."""
    stem = dense_cylinder(0.07 * scale, 0.24 * scale, location=(0, 0, 0.12 * scale), segments=32, radius2=0.042 * scale)
    displace(stem, lambda p, n: (0.012 * scale * (math.cos(math.atan2(p.y, p.x) * 5) - 0.5)
                                 if abs(n.z) < 0.7 else 0.0) + noise.noise(p * 40.0 / scale) * 0.003 * scale)
    bend = stem.modifiers.new("Bend", "SIMPLE_DEFORM")
    bend.deform_method = "BEND"
    bend.angle = math.radians(bend_deg)
    bend.deform_axis = "Y"
    common.apply_all_modifiers(stem)
    common.shade_smooth(stem, auto_angle=60)

    def colour(p, n):
        if n.z > 0.75 and p.z > 0.2 * scale:
            return (0.78, 0.74, 0.5)
        a = math.atan2(p.y, p.x)
        ridge = 0.5 + 0.5 * math.cos(a * 5)
        c = common.lerp((0.26, 0.28, 0.1), STEM, ridge * 0.8 + noise.noise(Vector((math.cos(a) * 9, math.sin(a) * 9, p.z * 6 + seed))) * 0.2)
        if p.z < 0.04 * scale:
            c = common.lerp(c, (0.3, 0.26, 0.1), 0.5)
        return c
    common.color_by(stem, colour)
    stem.location = (0.02 * scale, 0, height + 0.085 * scale)
    stem.rotation_euler = (0, 0, 0.3 + seed)
    return stem


def _face_shapes():
    """The carved face as 2D outlines in (x / radius, z / height): two
    triangle eyes and a curved grin with two square teeth, jittered a
    little like a hand-cut carving."""
    shapes = []
    for side in (-1, 1):
        cx = side * 0.32
        shapes.append([(cx - 0.19, 0.54), (cx + 0.19, 0.54), (cx + side * 0.02, 0.75)])
    mouth = []
    for k in range(9):  # bottom edge, curved up at the corners
        x = -0.36 + 0.72 * k / 8
        mouth.append((x, 0.26))
    mouth += [(0.5, 0.44), (0.22, 0.44), (0.22, 0.36), (0.1, 0.36), (0.1, 0.44), (-0.1, 0.44), (-0.1, 0.36),
              (-0.22, 0.36), (-0.22, 0.44), (-0.5, 0.44)]
    mouth = [(x, z + 0.08 * (x / 0.5) ** 2) for x, z in mouth]
    shapes.append(mouth)
    out = []
    for i, shape in enumerate(shapes):
        out.append([(x + noise.noise(Vector((x * 7, z * 7, i))) * 0.012, z + noise.noise(Vector((z * 7, x * 7, i + 5))) * 0.012)
                    for x, z in shape])
    return out


def _surface_y(x, z, radius, height):
    """Front (-Y) surface of the pumpkin body at (x, z), lobe crest."""
    t = z / height
    pinch = 1.0 - 0.18 * (abs(t - 0.5) * 2) ** 3
    ring = radius * pinch * math.sqrt(max(0.0, 1.0 - (2 * t - 1) ** 2))
    return -math.sqrt(max(0.0, ring * ring - x * x))


def carve_face(body, radius, height, depth):
    """Boolean-cuts the face `depth` into the -Y side. Returns the glow
    (emissive copies of the pocket floors) and paints the pocket walls
    pale flesh."""
    bm = bmesh.new()
    floors = []
    for shape in _face_shapes():
        front = [bm.verts.new((x * radius, -radius * 1.3, z * height)) for x, z in shape]
        back = [bm.verts.new((x * radius, _surface_y(x * radius, z * height, radius, height) + depth, z * height))
                for x, z in shape]
        n = len(shape)
        bm.faces.new(front)
        bm.faces.new(list(reversed(back)))
        floors.append([v.co.copy() for v in back])
        for k in range(n):
            bm.faces.new((front[k], front[(k + 1) % n], back[(k + 1) % n], back[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    cutter = common.mesh_object("cutter", bm)
    mod = body.modifiers.new("Carve", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    common.apply_all_modifiers(body)
    bpy.data.objects.remove(cutter)
    # Pocket walls and floors: pale, glow-lit flesh.
    shapes = _face_shapes()

    def in_cut(x, z, tol):
        for shape in shapes:
            pts = [(sx * radius, sz * height) for sx, sz in shape]
            inside = False
            near = False
            for k in range(len(pts)):
                (x1, z1), (x2, z2) = pts[k], pts[(k + 1) % len(pts)]
                if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
                    inside = not inside
                ex, ez = x2 - x1, z2 - z1
                t = max(0.0, min(1.0, ((x - x1) * ex + (z - z1) * ez) / max(1e-9, ex * ex + ez * ez)))
                if math.hypot(x - x1 - ex * t, z - z1 - ez * t) < tol:
                    near = True
            if inside or near:
                return True
        return False
    pocket = [p.index for p in body.data.polygons
              if p.center.y < -radius * 0.4 and in_cut(p.center.x, p.center.z, 0.006)]
    common.set_color(body, FLESH, faces=pocket)
    # Glow: the floors, nudged toward the viewer.
    gm = bmesh.new()
    for floor in floors:
        gm.faces.new([gm.verts.new(co - Vector((0, 0.004, 0))) for co in floor])
    bmesh.ops.triangulate(gm, faces=gm.faces[:])
    glow = common.mesh_object("face_glow", gm)
    paint_bake.flat_material(glow, GLOW, emission=3.0, name="jack_glow")
    return glow


def jack_o_lantern():
    common.reset(41)
    r, h = 0.672, 1.15
    body = pumpkin_body(r, h, PUMPKIN, PUMPKIN_DARK, 1)
    glow = carve_face(body, r, h, 0.07)
    parts = [body, pumpkin_stem(h, 2, scale=1.15)]
    detail.bake_prop(parts, "jack_o_lantern", budget=1460, size=512, ray=0.08, extra=[glow], preview_elevation=15,
                     ao_distance=0.2, ao_strength=0.6, edge_strength=0.3)


def pumpkin_small():
    common.reset(42)
    body = pumpkin_body(0.285, 0.48, PUMPKIN_YELLOW, (0.8, 0.5, 0.12), 3)
    detail.bake_prop([body, pumpkin_stem(0.48, 4, scale=0.95, bend_deg=10.0)], "pumpkin_small", budget=1000, size=512, ray=0.02,
                     edge_strength=0.3)


# --- Lantern and bucket ------------------------------------------------------------

def camp_lantern():
    """A floor lantern: square base, four posts, a roof and a handle,
    with a warm flame inside (separate emissive mesh)."""
    common.reset(43)
    parts = []
    parts.append(dense_block((0.5, 0.5, 0.1), location=(0, 0, 0.05), bevel=0.02, density=0.012, colour=iron_colour(1, rust=0.12),
                             dent=0.003, seed=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(board((0.55, 0.05, 0.05), location=(sx * 0.2, sy * 0.2, 0.37), rotation=(0, math.pi / 2, 0),
                               seed=sx + sy * 2 + 4, base=WOOD_DARK, light=WOOD, bevel=0.01, knots=False))
    parts.append(rivets([(sx * 0.2, sy * 0.2, 0.1) for sx in (-1, 1) for sy in (-1, 1)], 0.014))
    roof = dense_block((0.56, 0.56, 0.08), location=(0, 0, 0.68), bevel=0.02, density=0.012, colour=iron_colour(2, rust=0.12),
                       dent=0.003, seed=2)
    parts.append(roof)
    parts.append(rivets([(sx * 0.2, sy * 0.2, 0.72) for sx in (-1, 1) for sy in (-1, 1)], 0.014))
    parts.append(dense_block((0.3, 0.3, 0.1), location=(0, 0, 0.77), bevel=0.02, density=0.012, colour=iron_colour(3, rust=0.12),
                             dent=0.003, seed=3))
    # Vent holes around the cap.
    parts.append(rivets([((sx * 0.152, y, 0.77), (sx, 0, 0)) for sx in (-1, 1) for y in (-0.08, 0.0, 0.08)], 0.012,
                        colour=(0.1, 0.08, 0.08)))
    parts.append(torus(0.12, 0.018, location=(0, 0, 0.88), rotation=(math.pi / 2, 0, 0), segments=40, tube=10,
                       colour=iron_colour(4, rust=0.12)))
    # Candle with wax drips, standing in a puddle of wax.
    candle = dense_cylinder(0.06, 0.2, location=(0, 0, 0.2), segments=24, rings=20)

    def drip(p, n):
        a = math.atan2(p.y, p.x)
        d = max(0.0, math.sin(a * 5 + 1.0)) ** 4
        reach = 0.1 - d * 0.16 + noise.noise(Vector((math.cos(a) * 3, math.sin(a) * 3, 0))) * 0.03
        return 0.006 * d if abs(n.z) < 0.5 and p.z > reach - 0.1 else 0.0
    displace(candle, drip)
    common.color_by(candle, lambda p, n: common.lerp((0.95, 0.9, 0.78), (1.0, 0.97, 0.88),
                                                     max(0.0, min(1.0, (p.z + 0.1) / 0.2))))
    parts.append(candle)
    puddle = dense_cylinder(0.085, 0.012, location=(0, 0, 0.105), segments=24, rings=2, bevel=0.004)
    displace(puddle, lambda p, n: noise.noise(p * 30.0) * 0.006 if abs(n.z) < 0.5 else 0.0)
    common.color_by(puddle, lambda p, n: (0.93, 0.88, 0.74))
    parts.append(puddle)
    parts.append(dense_cylinder(0.006, 0.03, location=(0, 0, 0.31), segments=6, colour=lambda p, n: (0.1, 0.08, 0.06)))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=8, radius=0.06)
    for v in bm.verts:
        v.co.z *= 1.7
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.4))
    flame = common.mesh_object("flame", bm)
    paint_bake.flat_material(flame, GLOW, emission=3.5, name="lantern_flame_glow")
    detail.bake_prop(parts, "camp_lantern", budget=1200, size=512, ray=0.02, extra=[flame], preview_elevation=25,
                     ao_distance=0.15, ao_strength=0.6, edge_strength=0.35, edge_radius=0.015)


def water_bucket():
    """Twelve staves (each its own tone), two riveted iron hoops, a
    rippled water surface sunk below the rim and a bail handle."""
    common.reset(44)
    staves = 12
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=96, radius1=0.2, radius2=0.25, depth=0.4)
    side = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.2]
    bmesh.ops.subdivide_edges(bm, edges=side, cuts=40, use_grid_fill=True)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.2))
    top = [f for f in bm.faces if f.normal.z > 0.9 and f.calc_center_median().z > 0.39]
    res = bmesh.ops.inset_region(bm, faces=top, thickness=0.022, depth=0.0)
    for f in top:
        for v in f.verts:
            v.co.z -= 0.035
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        f = (a / math.tau * staves) % 1.0
        if 0.012 < v.co.z < 0.385 and Vector((v.co.x, v.co.y)).length > 0.19 + v.co.z * 0.12:
            k = 1.0 - (0.012 if (f < 0.04 or f > 0.96) else 0.0) / max(0.05, Vector((v.co.x, v.co.y)).length)
            v.co.x *= k
            v.co.y *= k
    bm.normal_update()
    bucket = common.mesh_object("bucket", bm)
    common.shade_smooth(bucket, auto_angle=40)

    def colour(pos, normal):
        if normal.z > 0.9 and pos.z > 0.33 and pos.z < 0.38:
            ripple = math.sin(Vector((pos.x - 0.05, pos.y + 0.03)).length * 160.0)
            c = common.lerp(WATER, (0.55, 0.78, 0.9), max(0.0, ripple) * 0.5)
            return common.lerp(c, (0.18, 0.32, 0.45), max(0.0, noise.noise(pos * 10.0)) * 0.6)
        a = math.atan2(pos.y, pos.x)
        idx = int((a / math.tau * staves) % staves)
        f = (a / math.tau * staves) % 1.0
        if f < 0.05 or f > 0.95:
            return WOOD_DARK
        tone = (idx * 0.37) % 1.0
        g = noise.noise(Vector((math.cos(a) * 40, math.sin(a) * 40, pos.z * 3.0 + idx)))
        c = common.lerp(WOOD, WOOD_LIGHT, max(0.0, min(1.0, 0.25 + tone * 0.5 + g * 0.4)))
        if g < -0.4:
            c = common.lerp(c, WOOD_DARK, 0.5)
        if pos.z > 0.39 or normal.z > 0.9:
            c = common.lerp(c, (0.88, 0.7, 0.46), 0.4)  # end grain on the rim
        if pos.z < 0.05:
            c = common.lerp(c, (0.3, 0.22, 0.14), 0.5 * (1 - pos.z / 0.05))  # damp foot
        return c
    common.color_by(bucket, colour, smooth=True)
    # Water: a dense disc just below the sunk rim, rippling out from a drip.
    wm = bmesh.new()
    rings, segs, wr, wz = 10, 64, 0.226, 0.368
    centre = wm.verts.new((0, 0, wz))
    prev = None
    for i in range(1, rings + 1):
        row = [wm.verts.new((math.cos(k / segs * math.tau) * wr * i / rings, math.sin(k / segs * math.tau) * wr * i / rings,
                             wz)) for k in range(segs)]
        for k in range(segs):
            if prev is None:
                wm.faces.new((centre, row[k], row[(k + 1) % segs]))
            else:
                wm.faces.new((prev[k], row[k], row[(k + 1) % segs], prev[(k + 1) % segs]))
        prev = row
    water = common.mesh_object("water", wm)

    def water_colour(p, n):
        d = Vector((p.x - 0.05, p.y + 0.03)).length
        ripple = math.sin(d * 120.0) * max(0.0, 1.0 - d * 4.0)
        c = common.lerp(WATER, (0.62, 0.84, 0.94), max(0.0, ripple) * 0.6)
        c = common.lerp(c, (0.2, 0.36, 0.5), max(0.0, noise.noise(p * 9.0)) * 0.5)
        if Vector((p.x, p.y)).length > wr * 0.9:
            c = common.lerp(c, (0.22, 0.34, 0.4), 0.5)  # shade under the rim
        return c
    common.color_by(water, water_colour)
    parts = [bucket, water]
    for z, r in ((0.08, 0.212), (0.32, 0.242)):
        hoop = torus(r, 0.014, location=(0, 0, z), segments=64, tube=8, colour=iron_colour(int(z * 100), rust=0.3))
        for v in hoop.data.vertices:
            v.co.z *= 1.9
        parts.append(hoop)
        parts.append(rivets([((math.cos(a) * (r + 0.012), math.sin(a) * (r + 0.012), z), (math.cos(a), math.sin(a), 0))
                             for a in (0.3, 0.3 + math.tau / 3, 0.3 + 2 * math.tau / 3)], 0.008))
    parts.append(torus(0.24, 0.012, location=(0, 0, 0.42), rotation=(math.pi / 2, 0, 0), segments=48, tube=8,
                       colour=iron_colour(9)))
    for sx in (-1, 1):  # ear lugs holding the bail
        parts.append(dense_block((0.03, 0.05, 0.08), location=(sx * 0.245, 0, 0.37), bevel=0.008, density=0.008,
                                 colour=_wood_grain(sx + 3, base=WOOD_DARK, light=WOOD)))
    detail.bake_prop(parts, "water_bucket", budget=900, size=512, ray=0.02, edge_strength=0.35)


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
    """A bare, twisted tree: the skin_trunk modelled dense with carved,
    weathered bark (deep vertical cracks, pale silvery ridges, a mossy
    foot), thin twigs and hanging moss, baked onto the budget mesh."""
    common.reset(seed)
    rng = random.Random(seed)
    trunk, tips = skin_trunk(rng, height, limbs, base_radius=0.26, subsurf=3, budget=None)
    off = Vector((seed * 0.37, seed * 0.11, seed * 0.07))

    def ridge_at(p):
        q = Vector((p.x * 10.0, p.y * 10.0, p.z * 0.6)) + off
        return min(1.0, abs(noise.noise(q)) * 6.0)
    mesh = trunk.data
    for v in mesh.vertices:
        v.co = v.co - v.normal * (1.0 - ridge_at(v.co)) * 0.026
    mesh.update()
    common.shade_smooth(trunk)
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
        r = ridge_at(pos)
        streak = noise.noise(Vector((pos.x * 3.0, pos.y * 3.0, pos.z * 0.6 + seed)))
        c = common.lerp(DEAD_BARK, DEAD_BARK_LIGHT, max(0.0, min(1.0, 0.45 + streak * 0.8)))
        c = common.lerp(DEAD_BARK_DARK, c, 0.3 + 0.7 * r)
        if r > 0.85 and normal.z > -0.2:
            c = common.lerp(c, DEAD_BARK_LIGHT, 0.35)
        foot = max(0.0, 1.0 - pos.z / 0.5)
        m = noise.noise(pos * 4.0 + off) * 0.5 + 0.5
        if foot > 0 and m > 0.45:
            c = common.lerp(c, MOSS_GREY, min(1.0, (m - 0.45) * 4.0) * foot * 0.8)
        return c
    common.color_by(wood, colour)
    parts = [wood]
    for i, tip in enumerate(tips[:3]):
        parts.append(moss_strand(tip + Vector((0, 0, -0.1)), rng.uniform(0.35, 0.6), seed + i))
    detail.bake_prop(parts, name, 1400, size=512, preview_elevation=20, ray=0.06, edge_strength=0.2, cavity=0.5)


# --- Far hills ---------------------------------------------------------------------------

def tree_clump(center, size, seed, autumn=False):
    """A far tree crown: a small tufted leaf clump with a sunny top."""
    obj = detail.leaf_clump(center, size, seed, tufts=7, bump=0.28, squash=0.9, under=10.0, wobble=0.12,
                            noise_freq=2.5, noise_offset=(seed, 0, 0), subdivisions=2)
    main = LEAF_AUTUMN if autumn else LEAF
    light = (1.0, 0.72, 0.3) if autumn else (0.62, 0.8, 0.28)
    dark = (0.42, 0.16, 0.06) if autumn else LEAF_DARK
    detail.colour_foliage(obj, dark, main, light, seed, lo=center.z - size, hi=center.z + size, fleck=0.0)
    return obj


def backdrop_mound(name, seed, width, height, clumps, rocky):
    """A mound about `width` across and `height` tall (KayKit hex tile
    scale: the dressing scales it by 4.5-9), dotted with tufted tree
    clumps; soft grass with sunny patches, rocky mountains get faceted
    stone bands. Kept cheap: it sits in the blurred background."""
    common.reset(seed)
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=14, radius=1.0)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0.0
        n = noise.noise(v.co * 2.0 + Vector((seed, 0, 0)))
        v.co.x *= width * 0.5 * (1 + n * 0.12)
        v.co.y *= width * 0.5 * (1 + n * 0.12)
        v.co.z *= height * (0.85 + n * 0.3 if rocky else 1.0 + n * 0.12)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    mound = common.mesh_object("mound", bm)
    common.shade_smooth(mound, auto_angle=50 if rocky else None)

    def colour(pos, normal):
        n = noise.noise(pos * 4.0 + Vector((seed, 0, 0)))
        patch = noise.noise(pos * 9.0 + Vector((0, seed, 0)))
        if rocky and normal.z < 0.55:
            band = math.sin(pos.z * 22.0 + n * 2.0) * 0.5 + 0.5
            c = common.lerp(ROCK, DIRT, max(0.0, min(1.0, 0.35 + n * 0.8)))
            return common.lerp(c, (0.68, 0.64, 0.6), band * 0.35 * max(0.0, normal.z + 0.2))
        c = common.lerp(GRASS, GRASS_LIGHT, max(0.0, min(1.0, 0.45 + n * 0.8 + normal.z * 0.3)))
        if patch > 0.35:
            c = common.lerp(c, (0.78, 0.82, 0.36), min(1.0, (patch - 0.35) * 2.5) * 0.6)
        if normal.z < 0.3:
            c = common.lerp(c, DIRT, 0.5)
        return c
    common.color_by(mound, colour, smooth=True)
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
    finish_prop(parts, name, size=512, budget=1300, preview_elevation=25, edge_strength=0.0, ao_distance=0.3)


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
