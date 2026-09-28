"""Camp props in the chunky, painted style: campfire (stones + teepee
logs), kid's striped tent, stake fence, watch post, torch, woodpile,
crate, barrel and toadstools. Each prop is built from bevelled blocks,
logs and ropes, coloured per part, then painted-baked.

Run: python art/props/camp.py [prop ...]"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Euler, Matrix, Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from nature.rocks import boulder  # noqa: E402

WOOD = (0.62, 0.4, 0.24)
WOOD_LIGHT = (0.8, 0.58, 0.34)
WOOD_DARK = (0.36, 0.22, 0.13)
BARK = (0.42, 0.27, 0.17)
END_GRAIN = (0.9, 0.7, 0.45)
CHAR = (0.12, 0.09, 0.08)
ROPE = (0.86, 0.74, 0.5)
IRON = (0.3, 0.32, 0.38)
CANVAS = (0.95, 0.88, 0.72)
STRIPE = (0.86, 0.26, 0.2)
ROOF = (0.72, 0.22, 0.16)
ROOF_LIGHT = (0.92, 0.42, 0.24)


# --- Primitive builders -----------------------------------------------------

def _finish(obj, bevel=0.03, segments=2, smooth_angle=35):
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(30)
        common.apply_all_modifiers(obj)
    common.shade_smooth(obj, auto_angle=smooth_angle)
    return obj


def block(size, location=(0, 0, 0), rotation=(0, 0, 0), bevel=0.03, warp=0.0, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        if warp:
            v.co += Vector((noise.noise(v.co * 3 + Vector((seed, 0, 0))), noise.noise(v.co * 3 + Vector((0, seed, 0))), 0)) * warp
    obj = common.mesh_object("block", bm)
    _finish(obj, bevel)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def log(length, radius, location=(0, 0, 0), rotation=(0, 0, 0), segments=10, taper=0.9, seed=0):
    """A log along local X with bark sides and pale end grain."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius * taper, depth=length)
    for v in bm.verts:
        v.co.xy *= 1.0 + noise.noise(v.co * 4 + Vector((seed, seed, 0))) * 0.08
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    obj = common.mesh_object("log", bm)
    _finish(obj, bevel=radius * 0.18, segments=2, smooth_angle=50)

    def colour(pos, normal):
        if abs(normal.x) > 0.8:
            r = Vector((pos.y, pos.z)).length / radius
            return common.lerp(END_GRAIN, WOOD, (math.sin(r * 14.0) * 0.5 + 0.5) * 0.35 + r * 0.35)
        n = noise.noise(Vector((pos.x * 1.5, pos.y * 10.0, pos.z * 10.0)) + Vector((seed, 0, 0)))
        return common.lerp(BARK, WOOD, max(0.0, min(1.0, 0.45 + n * 0.8)))
    common.color_by(obj, colour, smooth=False)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def stake(height, radius, location=(0, 0, 0), tilt=(0, 0), seed=0):
    """A sharpened post: log body with a conical point."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=radius, radius2=radius * 0.95, depth=height)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, height / 2))
    top = [v for v in bm.verts if v.co.z > height - 0.001]
    bmesh.ops.pointmerge(bm, verts=top, merge_co=(0, 0, height + radius * 2.2))
    for v in bm.verts:
        v.co.xy *= 1.0 + noise.noise(v.co * 5 + Vector((seed, 0, 0))) * 0.1
    obj = common.mesh_object("stake", bm)
    _finish(obj, bevel=0.015, smooth_angle=45)

    def colour(pos, normal):
        if pos.z > height - radius * 0.2:
            return WOOD_LIGHT
        n = noise.noise(Vector((pos.x * 12, pos.y * 12, pos.z * 1.2 + seed)))
        return common.lerp(BARK, WOOD, max(0.0, min(1.0, 0.5 + n)))
    common.color_by(obj, colour, smooth=False)
    obj.rotation_euler = (tilt[0], tilt[1], 0)
    obj.location = location
    return obj


def rope_ring(radius, thickness, location, rotation=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, segments=12, radius=radius)
    obj = common.mesh_object("rope", bm)
    mod = obj.modifiers.new("Skin", "SKIN")
    bm2 = bmesh.new()
    bm2.from_mesh(obj.data)
    bm2.verts.ensure_lookup_table()
    layer = bm2.verts.layers.skin.verify()
    for v in bm2.verts:
        v[layer].radius = (thickness, thickness)
    bm2.to_mesh(obj.data)
    bm2.free()
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    common.set_color(obj, ROPE)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def colour_wood(obj, seed=0, base=WOOD, light=WOOD_LIGHT, dark=WOOD_DARK):
    def colour(pos, normal):
        grain = noise.noise(Vector((pos.x * 1.2, pos.y * 14.0, pos.z * 14.0)) + Vector((seed, 0, 0)))
        grain += noise.noise(Vector((pos.x * 14.0, pos.y * 1.2, pos.z * 14.0)) + Vector((0, seed, 0))) * 0.5
        c = common.lerp(base, light, max(0.0, min(1.0, 0.5 + grain * 0.6)))
        if grain < -0.35:
            c = common.lerp(c, dark, 0.6)
        return c
    common.color_by(obj, colour, smooth=False)


def flat(obj, colour):
    common.set_color(obj, colour)
    return obj


def finish_prop(parts, name, size=512, preview_elevation=35, **paint):
    obj = common.join(parts, name)
    params = dict(ao_distance=0.25, ao_strength=0.7, edge_strength=0.45, edge_radius=0.02, noise_scale=6.0)
    params.update(paint)
    paint_bake.paint(obj, size=size, **params)
    common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), [obj])
    print(name, "tris:", common.triangle_count([obj]))
    preview.render([obj], name, elevation=preview_elevation)
    return obj


# --- Props -------------------------------------------------------------------

def campfire():
    common.reset(3)
    parts = []
    for i in range(11):
        a = i / 11 * math.tau
        s = boulder("stone%d" % i, 200 + i, (1.0, 0.8, 0.7), moss=False)
        s.scale = (0.5, 0.5, 0.5)
        s.location = (math.cos(a) * 0.82, math.sin(a) * 0.82, 0)
        s.rotation_euler = (0, 0, a)
        common.apply_transform(s)
        common.select_only([s])
        bpy.ops.object.transform_apply(location=True)
        parts.append(s)
    # Teepee of logs leaning to the centre.
    for i in range(5):
        a = i / 5 * math.tau + 0.3
        lg = log(0.95, 0.085, seed=i)
        # Upper end leans in toward the centre: a teepee.
        lg.rotation_euler = (0, math.radians(-55), a + math.pi)
        lg.location = (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.36)
        common.apply_transform(lg)
        common.select_only([lg])
        bpy.ops.object.transform_apply(location=True)
        # Charred inner ends.
        attr = lg.data.color_attributes["Col"]
        for poly in lg.data.polygons:
            if Vector((poly.center.x, poly.center.y)).length < 0.12 or poly.center.z > 0.62:
                for li in poly.loop_indices:
                    attr.data[li].color = (*common.srgb(CHAR), 1)
        parts.append(lg)
    # Ash bed.
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=16, radius=0.55)
    bed = common.mesh_object("ash", bm)
    bed.location = (0, 0, 0.02)
    common.select_only([bed])
    bpy.ops.object.transform_apply(location=True)
    common.set_color(bed, (0.2, 0.15, 0.13))
    parts.append(bed)
    finish_prop(parts, "campfire", size=1024)


def tent():
    common.reset(4)
    length, half_w, h = 2.2, 1.0, 1.55
    bm = bmesh.new()
    # Two sloped canvas panels meeting at the ridge (along X), with a
    # slight sag, subdivided so stripes can be painted.
    rows, cols = 6, 10
    grid = {}
    for side in (-1, 1):
        for i in range(cols + 1):
            for j in range(rows + 1):
                x = -length / 2 + length * i / cols
                t = j / rows  # 0 ridge -> 1 hem
                y = side * half_w * t
                z = h * (1 - t) + 0.06
                sag = math.sin(t * math.pi) * 0.08 * (1 - abs(x) / length)
                grid[(side, i, j)] = bm.verts.new((x, y * (1 + sag * 0.5), z - sag))
    for side in (-1, 1):
        for i in range(cols):
            for j in range(rows):
                quad = [grid[(side, i, j)], grid[(side, i + 1, j)], grid[(side, i + 1, j + 1)], grid[(side, i, j + 1)]]
                if side < 0:
                    quad.reverse()
                bm.faces.new(quad)
    # Back wall.
    back = [bm.verts.new((length / 2, -half_w, 0.06)), bm.verts.new((length / 2, half_w, 0.06)), bm.verts.new((length / 2, 0, h + 0.06))]
    bm.faces.new(back)
    canvas = common.mesh_object("canvas", bm)
    solid = canvas.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.04
    common.apply_all_modifiers(canvas)
    common.shade_smooth(canvas, auto_angle=40)

    def canvas_colour(pos, normal):
        stripe = math.sin(pos.x * math.pi * 2.6) > 0.35
        base = STRIPE if stripe else CANVAS
        if pos.x > length / 2 - 0.05:
            base = CANVAS
        return base
    common.color_by(canvas, canvas_colour, smooth=False)
    parts = [canvas]
    # Front flaps rolled open, dark opening inside.
    for side in (-1, 1):
        roll = log(1.3, 0.09, seed=side + 5)
        common.set_color(roll, STRIPE)
        roll.rotation_euler = (math.atan2(h, half_w) * side, math.radians(90), 0)
        roll.location = (-length / 2 - 0.05, side * half_w * 0.48, h * 0.52)
        parts.append(roll)
    inner = block((0.02, half_w * 1.6, h * 0.8), location=(-length / 2 + 0.25, 0, h * 0.4), bevel=0.0)
    common.set_color(inner, (0.12, 0.1, 0.14))
    parts.append(inner)
    # Poles and pegs with ropes.
    for x in (-length / 2 - 0.08, length / 2 + 0.08):
        pole = stake(h + 0.15, 0.045, location=(x, 0, 0), seed=int(x * 10))
        parts.append(pole)
    for sx in (-1, 1):
        for sy in (-1, 1):
            peg = stake(0.28, 0.035, location=(sx * length * 0.42, sy * (half_w + 0.35), 0), seed=sx * 3 + sy)
            parts.append(peg)
    finish_prop(parts, "tent", size=1024, edge_strength=0.25)


def fence():
    common.reset(5)
    parts = []
    count = 6
    span = 1.7
    for i in range(count):
        x = -span / 2 + span * i / (count - 1)
        h = 1.15 + (0.12 if i % 2 else 0.0) + random.uniform(-0.05, 0.05)
        parts.append(stake(h, 0.1, location=(x, 0, 0), tilt=(random.uniform(-0.04, 0.04), random.uniform(-0.05, 0.05)), seed=i))
    for z in (0.35, 0.8):
        rail = block((span + 0.15, 0.07, 0.1), location=(0, -0.1, z), rotation=(0, random.uniform(-0.04, 0.04), 0), warp=0.01, seed=int(z * 10))
        colour_wood(rail, seed=int(z * 10))
        parts.append(rail)
        for i in range(count):
            x = -span / 2 + span * i / (count - 1)
            parts.append(rope_ring(0.13, 0.022, (x, -0.02, z), rotation=(0, math.radians(90), 0)))
    finish_prop(parts, "fence", size=512, preview_elevation=25)


def watch_post():
    common.reset(6)
    parts = []
    w = 0.7
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = log(2.3, 0.08, rotation=(0, math.radians(-90), 0), location=(sx * w, sy * w, 1.15), seed=sx + sy * 2)
            leg.rotation_euler = (sy * 0.06, math.radians(-90) + sx * 0.06, 0)
            parts.append(leg)
    deck = block((1.7, 1.7, 0.12), location=(0, 0, 1.55), warp=0.02, seed=3)
    colour_wood(deck, 3)
    parts.append(deck)
    for side in range(4):
        rot = side * math.pi / 2
        rail = block((1.7, 0.07, 0.08), location=(math.cos(rot) * -0.82 * 0 + (0 if side % 2 == 0 else math.cos(rot) * 0.82),
                                                  (math.sin(rot) * 0.82 if side % 2 == 1 else (0.82 if side == 0 else -0.82)), 2.1),
                     rotation=(0, 0, rot if side % 2 else 0), seed=side)
        colour_wood(rail, side)
        parts.append(rail)
    for sx in (-1, 1):
        for sy in (-1, 1):
            post = log(1.3, 0.05, rotation=(0, math.radians(-90), 0), location=(sx * 0.8, sy * 0.8, 2.25), seed=7)
            parts.append(post)
    # Pyramid roof with overhang.
    bm = bmesh.new()
    r = 1.3
    base_z = 2.85
    corners = [bm.verts.new((sx * r, sy * r, base_z)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    apex = bm.verts.new((0, 0, base_z + 0.95))
    for i in range(4):
        bm.faces.new((corners[i], corners[(i + 1) % 4], apex))
    bm.faces.new(list(reversed(corners)))
    roof = common.mesh_object("roof", bm)
    solid = roof.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.1
    common.apply_all_modifiers(roof)
    _finish(roof, 0.03, smooth_angle=30)

    def roof_colour(pos, normal):
        shingle = math.sin((pos.z - base_z) * 22.0) > 0.2
        c = ROOF_LIGHT if shingle else ROOF
        return c if normal.z > -0.3 else WOOD_DARK
    common.color_by(roof, roof_colour, smooth=False)
    parts.append(roof)
    # Ladder.
    for sy in (-0.22, 0.22):
        rail = log(1.8, 0.04, rotation=(0, math.radians(-72), 0), location=(-1.05, sy, 0.85), seed=9)
        parts.append(rail)
    for k in range(5):
        z = 0.25 + k * 0.3
        rung = log(0.5, 0.03, rotation=(0, 0, math.pi / 2), location=(-1.2 + z * 0.3, 0, z), seed=k)
        parts.append(rung)
    finish_prop(parts, "watch_post", size=1024, preview_elevation=25)


def torch():
    common.reset(7)
    shaft = log(1.0, 0.05, rotation=(0, math.radians(-90), 0), location=(0, 0, 0.5), taper=1.2, seed=1)
    parts = [shaft]
    for k in range(3):
        ring = rope_ring(0.07, 0.035, (0, 0, 0.8 + k * 0.065))
        common.set_color(ring, (0.82, 0.7, 0.52) if k % 2 else (0.66, 0.52, 0.38))
        parts.append(ring)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.07, radius2=0.15, depth=0.14)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 1.04))
    cup = common.mesh_object("cup", bm)
    _finish(cup, 0.015)
    common.set_color(cup, (0.52, 0.54, 0.6))
    parts.append(cup)
    coal = block((0.2, 0.2, 0.05), location=(0, 0, 1.11), bevel=0.02)
    common.set_color(coal, (1.0, 0.6, 0.15))
    parts.append(coal)
    finish_prop(parts, "torch", size=256, preview_elevation=20)


def woodpile():
    common.reset(8)
    parts = []
    layers = [(3, 0.13), (2, 0.36), (1, 0.59)]
    for row, (count, z) in enumerate(layers):
        for i in range(count):
            y = (i - (count - 1) / 2) * 0.27
            parts.append(log(1.2 + random.uniform(-0.1, 0.1), 0.13, location=(random.uniform(-0.05, 0.05), y, z), seed=row * 3 + i))
    finish_prop(parts, "woodpile", size=512)


def crate():
    common.reset(9)
    box = block((0.8, 0.8, 0.7), location=(0, 0, 0.35), bevel=0.04)
    colour_wood(box, 1)
    parts = [box]
    # Dark corner posts and rim boards frame the planks.
    for sx in (-1, 1):
        for sy in (-1, 1):
            post = block((0.1, 0.1, 0.74), location=(sx * 0.37, sy * 0.37, 0.37), bevel=0.02)
            colour_wood(post, sx * 2 + sy, base=WOOD_DARK, light=WOOD)
            parts.append(post)
    for z in (0.06, 0.66):
        for k, (dx, dy) in enumerate(((0, 0.37), (0, -0.37), (0.37, 0), (-0.37, 0))):
            along_x = dx == 0
            rim = block((0.84 if along_x else 0.1, 0.1 if along_x else 0.84, 0.1), location=(dx, dy, z), bevel=0.02)
            colour_wood(rim, int(z * 10) + k, base=WOOD_DARK, light=WOOD)
            parts.append(rim)
    finish_prop(parts, "crate", size=512)


def barrel():
    common.reset(10)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=0.34, radius2=0.34, depth=0.95)
    bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.5], cuts=4)
    for v in bm.verts:
        bulge = 1.0 + 0.16 * (1 - (v.co.z / 0.475) ** 2)
        v.co.x *= bulge
        v.co.y *= bulge
        v.co.z += 0.475
    body = common.mesh_object("barrel", bm)
    _finish(body, 0.02, smooth_angle=50)

    def colour(pos, normal):
        if normal.z > 0.9:
            return WOOD_LIGHT
        stave = math.sin(math.atan2(pos.y, pos.x) * 14) > 0.85
        return WOOD_DARK if stave else common.lerp(WOOD, WOOD_LIGHT, 0.5 + noise.noise(pos * 8) * 0.5)
    common.color_by(body, colour, smooth=False)
    parts = [body]
    for z in (0.18, 0.77):
        ring = rope_ring(0.39, 0.03, (0, 0, z))
        common.set_color(ring, IRON)
        parts.append(ring)
    finish_prop(parts, "barrel", size=512)


def toadstools():
    common.reset(11)
    parts = []
    for i, (x, y, s) in enumerate([(0, 0, 1.0), (0.3, 0.15, 0.7), (-0.22, 0.25, 0.55)]):
        stem = log(0.32 * s, 0.07 * s, rotation=(0, math.radians(-90), 0), location=(x, y, 0.16 * s), taper=0.8, seed=i)
        common.set_color(stem, (0.96, 0.92, 0.84))
        parts.append(stem)
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, radius=0.22 * s)
        for v in bm.verts:
            if v.co.z < 0:
                v.co.z *= 0.25
            v.co.z *= 0.8
        bmesh.ops.translate(bm, verts=bm.verts, vec=(x, y, 0.32 * s))
        cap = common.mesh_object("cap", bm)
        common.shade_smooth(cap)

        def colour(pos, normal, s=s):
            if normal.z < -0.2:
                return (0.95, 0.85, 0.75)
            spot = noise.noise(pos * 18.0 / s)
            return (1.0, 0.95, 0.9) if spot > 0.35 else (0.88, 0.14, 0.12)
        common.color_by(cap, colour, smooth=False)
        parts.append(cap)
    finish_prop(parts, "toadstools", size=256, edge_strength=0.2)


PROPS = {
    "campfire": campfire, "tent": tent, "fence": fence, "watch_post": watch_post, "torch": torch,
    "woodpile": woodpile, "crate": crate, "barrel": barrel, "toadstools": toadstools,
}

if __name__ == "__main__":
    for name in (sys.argv[1:] or PROPS.keys()):
        random.seed(hash(name) & 0xFFFF)
        PROPS[name]()
