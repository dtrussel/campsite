"""Feature 017 props, in the same chunky painted style as camp.py:

- clay_pit / clay_pit_dug:     a mound of orange river clay with a spade
- mushrooms / mushrooms_picked: a mossy patch of brown forest mushrooms
- junk_pile / junk_pile_picked: an old camper's junk (crate, cans, wheel)
- snap_trap_base / snap_trap_jaw: a wooden snap trap (jaws animate in Godot)
- glow_lantern:                a stone-footed post with a caged glow crystal
- glow_shard:                  a small glowing crystal (imp drop pickup)
- hearth_ring:                 clay bricks around the campfire (Stone Hearth)

Run: python art/props/forage.py [prop ...]"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from nature.rocks import boulder  # noqa: E402
from props.camp import (IRON, WOOD, WOOD_DARK, WOOD_LIGHT, block, colour_wood, log, rope_ring,  # noqa: E402
                        stake)

CLAY = (0.78, 0.42, 0.24)
CLAY_LIGHT = (0.9, 0.58, 0.36)
CLAY_WET = (0.5, 0.26, 0.16)
MOSS = (0.35, 0.55, 0.2)
MOSS_LIGHT = (0.55, 0.72, 0.28)
CAP = (0.55, 0.32, 0.18)
CAP_LIGHT = (0.74, 0.5, 0.28)
STEM = (0.93, 0.88, 0.76)
TIN = (0.62, 0.66, 0.7)
RUST = (0.62, 0.34, 0.2)
LABEL = (0.82, 0.24, 0.2)
GLOW = (0.45, 0.95, 1.0)
GLOW_DEEP = (0.55, 0.45, 1.0)


def finish_prop(parts, name, size=512, preview_elevation=35, budget=1400, **paint):
    """camp.finish_prop plus decimation to the prop triangle budget."""
    obj = common.join(parts, name)
    _decimate_to(obj, budget)
    params = dict(ao_distance=0.25, ao_strength=0.7, edge_strength=0.45, edge_radius=0.02, noise_scale=6.0)
    params.update(paint)
    paint_bake.paint(obj, size=size, **params)
    common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), [obj])
    print(name, "tris:", common.triangle_count([obj]))
    preview.render([obj], name, elevation=preview_elevation)
    return obj


def _decimate_to(obj, budget):
    tris = common.triangle_count([obj])
    if tris > budget:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = budget / tris
        common.apply_all_modifiers(obj)


def _place(obj, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1)):
    """Bakes the object's current transform into its mesh, then moves it."""
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.location = location
    obj.rotation_euler = rotation
    obj.scale = scale
    common.apply_transform(obj)
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True)
    return obj


def mound(name, radius, height, seed, colour_fn, segments=18, rings=5):
    """A low, lumpy dome sitting on z = 0."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings * 2, radius=1.0)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0.0
        n = noise.noise(v.co * 2.2 + Vector((seed, seed * 0.5, 0)))
        v.co.x *= radius * (1 + n * 0.18)
        v.co.y *= radius * (1 + n * 0.18)
        v.co.z *= height * (1 + n * 0.3)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    obj = common.mesh_object(name, bm)
    common.shade_smooth(obj, auto_angle=40)
    common.color_by(obj, colour_fn)
    return obj


def disc(name, radius, colour, z=0.015, segments=16, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=segments, radius=radius)
    for v in bm.verts:
        v.co.xy *= 1.0 + noise.noise(v.co * 3 + Vector((seed, 0, 0))) * 0.2
    obj = common.mesh_object(name, bm)
    obj.location = (0, 0, z)
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True)
    common.set_color(obj, colour)
    return obj


def _clay_colour(seed):
    def colour(pos, normal):
        n = noise.noise(pos * 4.0 + Vector((seed, 0, 0)))
        c = common.lerp(CLAY, CLAY_LIGHT, max(0.0, min(1.0, 0.5 + n * 0.9)))
        # Wet, darker clay low down and in the dug hollow.
        if pos.z < 0.06:
            c = common.lerp(c, CLAY_WET, 0.6)
        return c
    return colour


def clay_lump(seed, size, location):
    lump = boulder("lump%d" % seed, 400 + seed, (1.0, 0.9, 0.6), subdiv=0, jag=0.2, moss=False)
    common.color_by(lump, _clay_colour(seed))
    return _place(lump, location, (0, 0, seed), (size, size, size))


def spade():
    handle = log(0.9, 0.035, rotation=(0, math.radians(-90), 0), location=(0, 0, 0.45), taper=1.0, seed=3)
    blade = block((0.22, 0.04, 0.26), location=(0, 0, 0.0), bevel=0.015)
    common.set_color(blade, IRON)
    grip = block((0.2, 0.05, 0.05), location=(0, 0, 0.9), bevel=0.015)
    colour_wood(grip, 2)
    parts = [handle, blade, grip]
    joined = common.join(parts, "spade")
    return _place(joined, (0.32, -0.1, 0.18), (math.radians(18), math.radians(-12), 0.4))


def clay_pit():
    common.reset(21)
    parts = [mound("clay", 0.62, 0.42, 1, _clay_colour(1))]
    # Dug hollow: a darker, wetter scoop near the top.
    parts.append(_place(disc("scoop", 0.2, CLAY_WET, z=0.0, seed=2), (-0.12, 0.1, 0.36), (0.25, -0.2, 0)))
    for i, (x, y, s) in enumerate([(0.72, 0.3, 0.3), (-0.7, -0.3, 0.26), (0.1, 0.78, 0.22)]):
        parts.append(clay_lump(i, s, (x, y, 0)))
    parts.append(spade())
    finish_prop(parts, "clay_pit", size=512, edge_strength=0.3)


def clay_pit_dug():
    common.reset(22)
    parts = [disc("patch", 0.75, CLAY_WET, seed=4)]
    parts.append(mound("rim", 0.5, 0.08, 5, _clay_colour(5)))
    parts.append(clay_lump(7, 0.16, (0.55, 0.2, 0)))
    finish_prop(parts, "clay_pit_dug", size=256, edge_strength=0.25)


def mushroom(seed, s, location, lean=0.0):
    x, y, _ = location
    stem = log(0.34 * s, 0.075 * s, rotation=(0, math.radians(-90), 0), location=(0, 0, 0.17 * s), taper=0.75, seed=seed)
    common.set_color(stem, STEM)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, radius=0.2 * s)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z *= 0.2
        v.co.z *= 0.75
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.33 * s))
    cap = common.mesh_object("cap", bm)
    common.shade_smooth(cap)

    def colour(pos, normal, s=s):
        if normal.z < -0.2:
            return (0.92, 0.84, 0.66)  # pale gills
        n = noise.noise(pos * 10.0 / s + Vector((seed, 0, 0)))
        return common.lerp(CAP, CAP_LIGHT, max(0.0, min(1.0, 0.45 + n + (pos.z - 0.3 * s) * 2.0)))
    common.color_by(cap, colour, smooth=False)
    joined = common.join([stem, cap], "mushroom")
    return _place(joined, (x, y, 0), (lean, 0, seed * 1.3))


def moss_bed(radius, seed):
    def colour(pos, normal):
        n = noise.noise(pos * 5.0 + Vector((seed, 0, 0)))
        return common.lerp(MOSS, MOSS_LIGHT, max(0.0, min(1.0, 0.5 + n)))
    return mound("moss", radius, 0.07, seed, colour, segments=14, rings=3)


def mushrooms():
    common.reset(23)
    parts = [moss_bed(0.62, 1)]
    for i, (x, y, s, lean) in enumerate([(0, 0, 1.15, 0.0), (0.3, 0.14, 0.8, 0.2), (-0.26, 0.22, 0.7, -0.15),
                                         (0.12, -0.32, 0.6, 0.15), (-0.3, -0.18, 0.5, -0.2)]):
        parts.append(mushroom(i, s, (x, y, 0.03), lean))
    finish_prop(parts, "mushrooms", size=512, edge_strength=0.25)


def mushrooms_picked():
    common.reset(24)
    parts = [moss_bed(0.58, 3)]
    for i, (x, y) in enumerate([(0, 0), (0.28, 0.12), (-0.24, 0.2)]):
        nub = log(0.08, 0.05, rotation=(0, math.radians(-90), 0), location=(x, y, 0.08), taper=0.9, seed=i)
        common.set_color(nub, STEM)
        parts.append(nub)
    finish_prop(parts, "mushrooms_picked", size=256, edge_strength=0.2)


def tin_can(seed, location, rotation):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.09, radius2=0.09, depth=0.2)
    can = common.mesh_object("can", bm)
    common.shade_smooth(can, auto_angle=40)

    def colour(pos, normal):
        if abs(normal.z) > 0.8:
            return TIN
        if abs(pos.z) < 0.055:
            return LABEL
        return common.lerp(TIN, RUST, max(0.0, noise.noise(pos * 20 + Vector((seed, 0, 0)))))
    common.color_by(can, colour, smooth=False)
    return _place(can, location, rotation)


def cart_wheel(location, rotation):
    rim = rope_ring(0.34, 0.04, (0, 0, 0))
    colour_wood(rim, 5, base=WOOD_DARK, light=WOOD)
    parts = [rim]
    hub = log(0.12, 0.07, rotation=(0, 0, math.pi / 2), seed=6)
    parts.append(hub)
    for k in range(6):
        a = k / 6 * math.tau
        spoke = block((0.3, 0.035, 0.035), location=(math.cos(a) * 0.16, math.sin(a) * 0.16, 0), rotation=(0, 0, a), bevel=0.01)
        colour_wood(spoke, k)
        parts.append(spoke)
    wheel = common.join(parts, "wheel")
    return _place(wheel, location, rotation)


def broken_crate(seed, location, rotation):
    parts = []
    for k in range(3):  # three planks left of one side, and a leaning lid plank
        plank = block((0.7, 0.05, 0.16), location=(0, 0.3, 0.1 + k * 0.19), bevel=0.015, warp=0.02, seed=seed + k)
        colour_wood(plank, seed + k)
        parts.append(plank)
    for sx in (-1, 1):
        post = block((0.08, 0.08, 0.6), location=(sx * 0.32, 0.3, 0.3), bevel=0.015)
        colour_wood(post, seed + sx, base=WOOD_DARK, light=WOOD)
        parts.append(post)
    side = block((0.05, 0.6, 0.5), location=(-0.32, 0.0, 0.25), bevel=0.015, warp=0.03, seed=seed)
    colour_wood(side, seed + 7)
    parts.append(side)
    lid = block((0.75, 0.3, 0.05), location=(0.2, -0.25, 0.18), rotation=(math.radians(35), 0, 0.3), bevel=0.015)
    colour_wood(lid, seed + 9, base=WOOD_LIGHT, light=WOOD)
    parts.append(lid)
    crate = common.join(parts, "broken_crate")
    return _place(crate, location, rotation)


def pipe(location, rotation):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=8, radius1=0.05, radius2=0.05, depth=0.7)
    obj = common.mesh_object("pipe", bm)
    bend = obj.modifiers.new("Bend", "SIMPLE_DEFORM")
    bend.deform_method = "BEND"
    bend.angle = math.radians(60)
    bend.deform_axis = "X"
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj, auto_angle=50)
    common.color_by(obj, lambda pos, n: common.lerp(IRON, RUST, max(0.0, min(1.0, 0.5 + noise.noise(pos * 9)))), smooth=False)
    return _place(obj, location, rotation)


def junk_pile():
    common.reset(25)
    parts = [disc("dirt", 0.8, (0.45, 0.36, 0.26), seed=5)]
    parts.append(broken_crate(1, (0.05, 0.05, 0), (0, 0, 0.3)))
    parts.append(cart_wheel((-0.45, -0.25, 0.22), (math.radians(70), 0, 0.6)))
    parts.append(tin_can(1, (0.45, -0.35, 0.09), (0, 0, 0)))
    parts.append(tin_can(2, (0.55, -0.1, 0.07), (math.radians(90), 0, 1.0)))
    parts.append(pipe((0.35, 0.45, 0.08), (math.radians(90), 0, 2.2)))
    finish_prop(parts, "junk_pile", size=512, edge_strength=0.4)


def junk_pile_picked():
    common.reset(26)
    parts = [disc("dirt", 0.75, (0.45, 0.36, 0.26), seed=6)]
    for k in range(3):
        plank = block((0.6, 0.14, 0.04), location=(random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), 0.03 + k * 0.045),
                      rotation=(0, 0, random.uniform(0, math.pi)), bevel=0.012)
        colour_wood(plank, k)
        parts.append(plank)
    parts.append(tin_can(3, (0.4, 0.3, 0.07), (math.radians(90), 0, 0.2)))
    finish_prop(parts, "junk_pile_picked", size=256, edge_strength=0.35)


def snap_trap_base():
    common.reset(27)
    board = block((0.9, 0.7, 0.07), location=(0, 0, 0.035), bevel=0.02)
    colour_wood(board, 1)
    parts = [board]
    for sx in (-1, 1):  # hinge blocks and the iron spring
        hinge = block((0.12, 0.62, 0.08), location=(sx * 0.05, 0, 0.1), bevel=0.015)
        common.set_color(hinge, IRON)
        parts.append(hinge)
    pad = block((0.22, 0.22, 0.03), location=(0, 0, 0.085), bevel=0.01)
    common.set_color(pad, (0.9, 0.72, 0.3))
    parts.append(pad)
    peg = stake(0.25, 0.04, location=(0.5, 0.3, -0.05), seed=2)
    parts.append(peg)
    finish_prop(parts, "snap_trap_base", size=256, edge_strength=0.35)


def snap_trap_jaw():
    """One jaw, hinged on its local origin, lying open along +X."""
    common.reset(28)
    bar = block((0.4, 0.6, 0.05), location=(0.2, 0, 0.025), bevel=0.012)
    colour_wood(bar, 3, base=WOOD_DARK, light=WOOD)
    parts = [bar]
    for k in range(5):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.045, radius2=0.0, depth=0.14)
        tooth = common.mesh_object("tooth", bm)
        _place(tooth, (0.4, -0.24 + k * 0.12, 0.08), (0, 0, math.pi / 4))
        common.set_color(tooth, (0.92, 0.9, 0.84))
        parts.append(tooth)
    finish_prop(parts, "snap_trap_jaw", size=256, edge_strength=0.3)


def glow_crystal(seed, height, radius, location, tilt):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=radius, radius2=radius * 0.8, depth=height)
    top = [v for v in bm.verts if v.co.z > 0]
    for v in top:
        v.co.z += 0.0
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, height / 2))
    tip = [v for v in bm.verts if v.co.z > height - 0.001]
    bmesh.ops.pointmerge(bm, verts=tip, merge_co=(0, 0, height + radius * 1.5))
    crystal = common.mesh_object("crystal%d" % seed, bm)
    return _place(crystal, location, (tilt[0], tilt[1], seed))


def _glow_group(specs, name):
    crystals = [glow_crystal(i, *spec) for i, spec in enumerate(specs)]
    glow = common.join(crystals, name)
    paint_bake.flat_material(glow, GLOW, emission=2.4, name="glow_crystal_glow")
    return glow


def glow_shard():
    common.reset(29)
    glow = _glow_group([(0.34, 0.07, (0, 0, 0), (0.1, 0.0)), (0.24, 0.055, (0.08, 0.04, 0), (0.5, 0.2)),
                        (0.2, 0.05, (-0.07, 0.03, 0), (-0.45, 0.1))], "glow_shard")
    common.export_glb(os.path.join(common.OUT_DIR, "glow_shard.glb"), [glow])
    print("glow_shard tris:", common.triangle_count([glow]))
    preview.render([glow], "glow_shard", elevation=20)


def glow_lantern():
    common.reset(30)
    parts = []
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        s = boulder("foot%d" % i, 500 + i, (1.0, 0.85, 0.6), subdiv=0, moss=True)
        parts.append(_place(s, (math.cos(a) * 0.2, math.sin(a) * 0.2, 0), (0, 0, a), (0.5, 0.5, 0.5)))
    post = log(1.6, 0.07, rotation=(0, math.radians(-90), 0), location=(0, 0, 0.8), taper=0.85, seed=4)
    parts.append(post)
    arm = block((0.5, 0.06, 0.06), location=(0.2, 0, 1.55), bevel=0.015)
    colour_wood(arm, 3)
    parts.append(arm)
    # Iron cage hanging from the arm.
    cx, cz = 0.38, 1.18
    for sx in (-1, 1):
        for sy in (-1, 1):
            bar = block((0.025, 0.025, 0.36), location=(cx + sx * 0.1, sy * 0.1, cz), bevel=0.006)
            common.set_color(bar, IRON)
            parts.append(bar)
    for z in (cz - 0.18, cz + 0.18):
        plate = block((0.26, 0.26, 0.035), location=(cx, 0, z), bevel=0.01)
        common.set_color(plate, IRON)
        parts.append(plate)
    hook = rope_ring(0.05, 0.012, (cx, 0, 1.43), rotation=(math.pi / 2, 0, 0))
    common.set_color(hook, IRON)
    parts.append(hook)
    body = common.join(parts, "glow_lantern")
    _decimate_to(body, 1300)
    paint_bake.paint(body, size=512, ao_distance=0.25, ao_strength=0.7, edge_strength=0.4, edge_radius=0.02,
                     noise_scale=6.0)
    glow = _glow_group([(0.22, 0.05, (cx, 0, cz - 0.14), (0.05, 0.0)), (0.16, 0.04, (cx + 0.04, 0.03, cz - 0.14), (0.4, 0.2)),
                        (0.14, 0.035, (cx - 0.05, -0.02, cz - 0.14), (-0.35, 0.1))], "glow_lantern_crystal")
    common.export_glb(os.path.join(common.OUT_DIR, "glow_lantern.glb"), [body, glow])
    print("glow_lantern tris:", common.triangle_count([body, glow]))
    preview.render([body, glow], "glow_lantern", elevation=25)


def hearth_ring():
    """Clay bricks laid in a ring just outside the campfire stones."""
    common.reset(31)
    parts = []
    count = 16
    for i in range(count):
        a = i / count * math.tau
        brick = block((0.3, 0.16, 0.14), location=(0, 0, 0.07), bevel=0.02, warp=0.015, seed=i)
        common.color_by(brick, _clay_colour(i), smooth=False)
        parts.append(_place(brick, (math.cos(a) * 1.12, math.sin(a) * 1.12, 0), (0, 0, a + math.pi / 2)))
        if i % 2 == 0:  # a second, staggered course on every other brick
            top = block((0.26, 0.15, 0.12), location=(0, 0, 0.2), bevel=0.02, warp=0.015, seed=i + 50)
            common.color_by(top, _clay_colour(i + 50), smooth=False)
            b = a + math.pi / count
            parts.append(_place(top, (math.cos(b) * 1.12, math.sin(b) * 1.12, 0), (0, 0, b + math.pi / 2)))
    finish_prop(parts, "hearth_ring", size=512, edge_strength=0.35)


PROPS = {
    "clay_pit": clay_pit, "clay_pit_dug": clay_pit_dug, "mushrooms": mushrooms, "mushrooms_picked": mushrooms_picked,
    "junk_pile": junk_pile, "junk_pile_picked": junk_pile_picked, "snap_trap_base": snap_trap_base,
    "snap_trap_jaw": snap_trap_jaw, "glow_shard": glow_shard, "glow_lantern": glow_lantern, "hearth_ring": hearth_ring,
}

if __name__ == "__main__":
    for name in (sys.argv[1:] or PROPS.keys()):
        random.seed(hash(name) & 0xFFFF)
        PROPS[name]()
