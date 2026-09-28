"""Nela, the little sister (the helper). Modelled from the concept art:
a tiny adventurer with wild wavy blond hair and a little top ponytail,
huge blue eyes and a big laugh; pale-blue tee; puffy plum harem pants
with a cream folk pattern and gathered cuffs; cream socks and brown
boots with pink laces; a plum backpack with a green bedroll, a tin cup
and her bunny peeking out; a compass on a cord; and a glowing lantern.
Built on the KayKit adventurer rig so all animations work.
Output: nela.glb"""

import math
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from characters import chibi, face_paint  # noqa: E402
from characters.leo import render_previews  # noqa: E402

SKIN = (1.0, 0.82, 0.7)
SKIN_SHADE = (0.95, 0.68, 0.57)
BLUSH = (1.0, 0.5, 0.5)
HAIR_LIGHT = (1.0, 0.97, 0.8)
HAIR = (0.98, 0.87, 0.58)
HAIR_DARK = (0.8, 0.6, 0.34)
BROW = (0.8, 0.62, 0.38)
IRIS = (0.38, 0.72, 1.0)
IRIS_DARK = (0.12, 0.34, 0.7)
LASH = (0.22, 0.12, 0.1)
TEE = (0.98, 0.82, 0.88)
TEE_DARK = (0.88, 0.62, 0.74)
PANTS = (0.44, 0.13, 0.27)
PANTS_DARK = (0.3, 0.07, 0.18)
PATTERN = (0.95, 0.86, 0.8)
PATTERN_PINK = (0.86, 0.5, 0.62)
SOCK = (0.95, 0.92, 0.84)
BOOT = (0.52, 0.34, 0.2)
BOOT_TOE = (0.62, 0.46, 0.32)
SOLE = (0.34, 0.24, 0.16)
LACE = (0.98, 0.5, 0.68)
TIE = (0.98, 0.45, 0.65)
PACK = (0.52, 0.17, 0.36)
PACK_DARK = (0.36, 0.1, 0.25)
LEATHER = (0.52, 0.34, 0.2)
BRASS = (0.9, 0.72, 0.36)
BEDROLL = (0.36, 0.48, 0.28)
BUNNY = (0.9, 0.82, 0.72)
BUNNY_INNER = (1.0, 0.7, 0.72)
STEEL = (0.8, 0.82, 0.85)
ROPE = (0.82, 0.68, 0.44)
GOLD = (0.95, 0.74, 0.3)
BRONZE = (0.64, 0.44, 0.22)
BRONZE_DARK = (0.36, 0.22, 0.12)
GLOW = (1.0, 0.8, 0.38)

HEAD = chibi.HeadFrame((0, -0.01, 1.58), (0.31, 0.3, 0.32))
PROP = chibi.Proportions(legs=1.3, spine=1.1, arms=1.1)
WARMER = (0.9, 0.5, 0.66)
WARMER_DARK = (0.5, 0.2, 0.4)
FACE_PNG = os.path.join(common.ROOT, "build", "art_faces", "nela_face.png")
# Annie-style painted face: big eyes under heavy, sly lids with smoky
# pink-violet shadow and a winged liner, brows angled in (mischief), a
# small nose, small full rosy lips in a sly half-smile, strong blush.
FACE = face_paint.FaceLayout(
    size=0.36, eye_x=0.1, eye_z=-0.045, eye_w=0.058, eye_h=0.034, eye_tilt=0.06, lid=0.28, iris_r=0.03,
    look=(0.0, 0.0), iris=(0.4, 0.74, 0.98), iris_dark=(0.08, 0.28, 0.55), lash=(0.12, 0.06, 0.08),
    lash_width=0.0095, wing=0.011, lower_lash=0.5, eyeshadow=(0.66, 0.4, 0.58), eyeshadow_alpha=0.45,
    socket=(0.7, 0.44, 0.48), brows=((0.022, 0.22, 0.01, 0.006), (0.022, 0.22, 0.01, 0.006)), brow_len=0.058,
    brow_colour=(0.55, 0.36, 0.2), nose_z=-0.115, nose_w=0.014, mouth_z=-0.165, mouth_w=0.028, smile=6.0,
    smirk=0.12, lip_upper=0.006, lip_lower=0.009, lip_colour=(0.86, 0.42, 0.48), lip_dark=(0.58, 0.22, 0.3),
    chin_z=-0.24, skin_shadow=(0.7, 0.44, 0.42), blush=(1.0, 0.45, 0.5), blush_alpha=0.4, blush_pos=(0.125, -0.1),
    contour=0.4, highlight=(1.0, 0.92, 0.86))
FEATURES = dict(socket=0.012, eyeball=0.006, brow=0.008, nose=0.016, lips=0.007, chin=0.008)


# ---------------------------------------------------------------- body

def skin_piece():
    parts = [chibi.tube([(0, 0, 1.1), (0, 0.01, 1.4)], [0.07, 0.066], name="neck")]
    for s in (-1, 1):
        parts.append(chibi.tube([(s * 0.28, 0, 1.11), (s * 0.55, 0, 1.11), (s * 0.8, 0, 1.11)], [0.07, 0.066, 0.06],
                                name="arm"))
        parts.append(chibi.tube([(s * 0.16, 0, 0.46), (s * 0.17, -0.01, 0.29), (s * 0.17, 0.02, 0.14)],
                                [0.08, 0.075, 0.065], name="leg"))
    body = chibi.fuse(parts, "Skin", voxel=0.014, faces=1400)
    common.color_by(body, lambda p, n: common.lerp(SKIN, SKIN_SHADE, max(0.0, -n.z * 0.5)))
    return body


def shirt_piece():
    parts = [
        chibi.ellipsoid((0, 0, 1.01), (0.225, 0.19, 0.21), name="chest"),
        chibi.ellipsoid((0, -0.02, 0.78), (0.245, 0.215, 0.27), name="belly"),
    ]
    for s in (-1, 1):
        parts.append(chibi.tube([(s * 0.13, 0, 1.1), (s * 0.37, 0, 1.1)], [0.11, 0.1], name="sleeve", levels=2))
    shirt = chibi.fuse(parts, "Shirt", voxel=0.014, faces=2200)
    for s in (-1, 1):
        chibi.cut_open(shirt, (s * 0.35, 0, 0), (s, 0, 0))

    def colour(pos, normal):
        if abs(pos.x) > 0.315:
            return TEE_DARK
        # A little mountain print on the tummy.
        if normal.y < -0.8 and abs(pos.x) < 0.1 and 0.8 < pos.z < 0.93:
            peak = 0.925 - abs(pos.x) * 1.1
            if pos.z < peak:
                return (0.3, 0.5, 0.75) if pos.z > 0.845 else (0.35, 0.6, 0.4)
        return TEE
    common.color_by(shirt, colour, smooth=False)
    return shirt


def folk_pattern(pos, leg_x):
    """Bold cream zigzag bands and dotted rows on plum, wrapped around
    the leg (big enough to read at game scale)."""
    a = math.atan2(pos.y, pos.x - leg_x)
    u = a / math.tau * 7.0  # 7 repeats around the leg
    band = 0.12
    v = (pos.z % band) / band
    zig = abs((u % 1.0) * 2.0 - 1.0)
    if abs(v - (0.12 + zig * 0.3)) < 0.1:
        return PATTERN
    du = abs(((u + 0.5) % 1.0) - 0.5)
    if du < 0.16 and abs(v - 0.78) < 0.11:
        return PATTERN_PINK
    return PANTS


def pants_piece():
    parts = [chibi.ellipsoid((0, 0, 0.57), (0.29, 0.235, 0.15), name="hips")]
    for s in (-1, 1):
        parts.append(chibi.tube([(s * 0.14, 0, 0.58), (s * 0.185, -0.01, 0.36), (s * 0.18, 0.015, 0.2)],
                                [0.15, 0.158, 0.13], name="pantleg", levels=2))
    pants = chibi.fuse(parts, "Pants", voxel=0.011, faces=5200)
    chibi.cut_open(pants, (0, 0, 0.33), (0, 0, -1))

    def colour(pos, normal):
        if pos.z < 0.37:
            return PANTS_DARK  # gathered cuff
        leg_x = 0.17 if pos.x > 0 else -0.17
        return folk_pattern(pos, leg_x)
    common.color_by(pants, colour, smooth=False)
    return pants


def cuffs():
    parts = []
    for s, bone in ((1, "lowerleg.l"), (-1, "lowerleg.r")):
        ring = chibi.torus((s * 0.178, 0.005, 0.345), 0.115, 0.028, name="cuff", segs=(22, 8))
        common.set_color(ring, PANTS_DARK)
        parts.append((ring, bone))
        # Slouchy striped leg warmers (an Annie cue) above the boots.
        warmer = chibi.tube([(s * 0.172, 0.01, 0.34), (s * 0.17, 0.02, 0.24), (s * 0.17, 0.02, 0.14)],
                            [0.078, 0.09, 0.098], name="warmer", levels=2)
        common.color_by(warmer, lambda p, n: WARMER if int((p.z - 0.12) / 0.028) % 2 == 0 else WARMER_DARK)
        parts.append((warmer, bone))
    # Patch pocket on her right thigh.
    pocket = chibi.box((0.03, 0.12, 0.12), (-0.33, -0.01, 0.42), bevel=0.012, name="pocket")
    common.color_by(pocket, lambda p, n: PANTS_DARK if p.z > 0.45 else PANTS, smooth=False)
    parts.append((pocket, "upperleg.r"))
    return parts


def hands_and_feet():
    rigid = []
    for h, bone in chibi.hands(SKIN, radius=0.085):
        rigid.append((h, bone))
    for s, bone in ((1, "foot.l"), (-1, "foot.r")):
        for part in chibi.boot(s, BOOT, SOLE, BOOT_TOE, LACE, accent=LACE, scale=1.02):
            rigid.append((part, bone))
    return rigid


# ----------------------------------------------------------------- head

F, R, U = Vector((0, -1, 0)), Vector((-1, 0, 0)), Vector((0, 0, 1))  # forward, her right, up


def clump(parts, root, up, controls, width, thickness=0.45, steps=8):
    pts = chibi.sweep(root, controls, steps=steps)
    widths = [width * (1.0 - (i / (steps - 1)) ** 1.8) * (0.85 + 0.3 * math.sin(math.pi * i / (steps - 1)))
              for i in range(steps)]
    widths[-1] = 0.0
    obj = chibi.hair_clump(pts, widths, thickness, up, name="curl")
    length = sum((pts[i + 1] - pts[i]).length for i in range(steps - 1))
    common.color_by(obj, chibi.lock_colour(root, length, HAIR_LIGHT, HAIR, HAIR_DARK))
    parts.append(obj)


def hair_cap():
    """Smooth rounded hair over the crown, open for the face."""
    c, r = HEAD.c, HEAD.r
    shell_r = (r.x + 0.03, r.y + 0.03, r.z + 0.025)
    shell = chibi.ellipsoid(c + Vector((0, 0.01, 0.015)), shell_r, name="hairshell", segs=(40, 26))
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    kill = []
    for v in bm.verts:
        d = v.co - c
        d = Vector((d.x / shell_r[0], d.y / shell_r[1], d.z / shell_r[2]))
        keep = d.z > 0.5 or (d.y > -0.3 and d.z > -0.2) or (d.y > 0.3 and d.z > -0.55)
        if not keep:
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(shell.data)
    bm.free()
    mod = shell.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.025
    common.apply_all_modifiers(shell)
    common.shade_smooth(shell)
    common.color_by(shell, chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, c, scale=5.0, strands=34))
    return shell


def pigtail(side):
    """A big puffy pigtail set high on the side of the head, with a pink
    tie and a few curly ends."""
    parts = []
    root, n = HEAD.point(side * 1.45, 0.42, 0.02)
    out = Vector((side, 0.15, 0)).normalized()
    centres = [root + out * 0.08 + Vector((0, 0.02, 0.0)),
               root + out * 0.17 + Vector((0, 0.04, -0.07)),
               root + out * 0.21 + Vector((0, 0.05, -0.18)),
               root + out * 0.19 + Vector((0, 0.05, -0.28))]
    sizes = [0.075, 0.12, 0.125, 0.09]
    puffs = [chibi.ellipsoid(cc, (sz, sz * 0.9, sz), name="puff", segs=(18, 12)) for cc, sz in zip(centres, sizes)]
    tail = chibi.fuse(puffs, "pigtail", voxel=0.014, smooth=2, faces=1200)
    common.color_by(tail, chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, centres[1], scale=10.0, strands=14))
    parts.append(tail)
    tie = chibi.torus((0, 0, 0), 0.07, 0.028, name="tie", segs=(18, 8))
    for v in tie.data.vertices:
        v.co.z += 0.007 * math.sin(math.atan2(v.co.y, v.co.x) * 7)  # scrunchie
    tie.data.transform(Matrix.Translation(root + out * 0.05) @ out.to_track_quat("Z", "Y").to_matrix().to_4x4())
    common.set_color(tie, TIE)
    parts.append(tie)
    return parts


def hair():
    parts = [hair_cap()]
    # Annie-style blunt fringe: a solid sheet following the forehead from
    # the hairline down to just above the brows, cut straight across.
    bm = bmesh.new()
    cols, rows = 28, 10
    grid = []
    for i in range(cols + 1):
        yaw = -0.95 + 1.9 * i / cols
        column = []
        for j in range(rows + 1):
            pitch = 0.16 + (1.1 - 0.16) * j / rows
            lift = 0.012 + 0.016 * (j / rows)
            p, n = HEAD.point(yaw, pitch, lift)
            column.append(bm.verts.new(p))
        grid.append(column)
    for i in range(cols):
        for j in range(rows):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    sheet = common.mesh_object("fringe", bm)
    for f in sheet.data.polygons:
        if f.normal.dot(f.center - HEAD.c) < 0:
            f.flip()
    mod = sheet.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.018
    mod.offset = 1.0
    sub = sheet.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    common.apply_all_modifiers(sheet)
    common.shade_smooth(sheet)

    def strands(pos, normal):
        rel = pos - HEAD.c
        a = math.atan2(rel.x, -rel.y)
        streak = math.sin(a * 60 + noise.noise(pos * 20) * 2.0) * 0.5 + 0.5
        t = max(0.0, min(1.0, 0.55 + (rel.z / HEAD.r.z) * 0.5 + (streak - 0.5) * 0.4))
        return common.lerp(HAIR_DARK, HAIR, t / 0.5) if t < 0.5 else common.lerp(HAIR, HAIR_LIGHT, (t - 0.5) / 0.5)
    common.color_by(sheet, strands)
    parts.append(sheet)
    for side in (-1, 1):
        parts += pigtail(side)
    return parts


def ears():
    parts = []
    for side in (-1, 1):
        p, n = HEAD.point(side * 1.5, -0.15)
        e = chibi.ellipsoid(p + n * 0.01, (0.03, 0.026, 0.044), name="ear", segs=(14, 8))
        common.set_color(e, SKIN)
        parts.append(e)
    return parts


def head_piece():
    face_paint.paint_face(FACE, FACE_PNG)
    head = chibi.sculpt_head(HEAD, SKIN, SKIN_SHADE, BLUSH, jaw=0.3, chin_len=0.04, chin_fwd=0.04, cheeks=0.16,
                             face_flat=0.08, blush_yaw=0.62, blush_pitch=-0.46, blush_size=0.01,
                             layout=FACE, features=FEATURES)
    chibi.face_uv(head, HEAD, FACE)
    ear_parts = ears()
    for part in ear_parts:
        chibi.no_face_uv(part)
    hair_parts = hair()
    chibi.report([head] + ear_parts + hair_parts)
    return common.join([head] + ear_parts, "Nela_Head"), common.join(hair_parts, "Nela_Hair")


# ----------------------------------------------------------------- gear

def bunny(hand):
    """Her big plush bunny, held by one paw and dangling from her left
    hand (like a favourite toy that goes everywhere). Built in world
    space below where the hand is in the idle pose."""
    parts = []
    grip = Vector(hand) + Vector((0.02, -0.04, -0.03))
    body_c = grip + Vector((0.03, -0.03, -0.24))
    head_c = body_c + Vector((0.01, -0.01, 0.17))

    def add(obj, colour):
        common.color_by(obj, colour if callable(colour) else (lambda p, n: colour))
        parts.append(obj)
    add(chibi.ellipsoid(body_c, (0.085, 0.07, 0.11), name="bunny", segs=(18, 12)), BUNNY)
    add(chibi.ellipsoid(body_c + Vector((0, -0.05, -0.01)), (0.055, 0.03, 0.07), name="bunny", segs=(14, 8)),
        (1.0, 0.95, 0.9))
    add(chibi.ellipsoid(head_c, (0.1, 0.09, 0.09), name="bunny", segs=(20, 12)), BUNNY)
    add(chibi.ellipsoid(head_c + Vector((0, -0.075, -0.025)), (0.05, 0.03, 0.035), name="bunny", segs=(14, 8)),
        (1.0, 0.95, 0.9))
    add(chibi.ellipsoid(head_c + Vector((0, -0.105, -0.005)), (0.016, 0.01, 0.011), name="bunny", segs=(8, 6)),
        BUNNY_INNER)
    for s in (-1, 1):
        add(chibi.ellipsoid(head_c + Vector((s * 0.042, -0.08, 0.02)), (0.013, 0.008, 0.016), name="bunny",
                            segs=(8, 6)), (0.08, 0.05, 0.05))
        ear = chibi.ellipsoid((0, 0, 0.13), (0.035, 0.016, 0.13), name="bunny_ear", segs=(14, 8))
        common.color_by(ear, lambda p, n: BUNNY_INNER if n.y < -0.5 and abs(p.x) < 0.022 else BUNNY, smooth=False)
        # One ear up, one flopped over.
        rot = Matrix.Rotation(s * -0.3, 4, "Y") if s > 0 else Matrix.Rotation(1.3, 4, "Y") @ Matrix.Rotation(0.3, 4, "X")
        ear.data.transform(Matrix.Translation(head_c + Vector((s * 0.045, 0.01, 0.06))) @ rot)
        parts.append(ear)
        # Legs dangling, and the raised paw she holds it by.
        add(chibi.ellipsoid(body_c + Vector((s * 0.05, -0.02, -0.11)), (0.035, 0.035, 0.05), name="bunny",
                            segs=(12, 8)), BUNNY)
    arm = chibi.tube([body_c + Vector((0.06, 0, 0.06)), grip], [0.03, 0.028], name="bunny", levels=1)
    add(arm, BUNNY)
    add(chibi.ellipsoid(body_c + Vector((-0.08, -0.02, 0.02)), (0.03, 0.03, 0.05), name="bunny", segs=(12, 8)),
        BUNNY)
    # Well-loved: a red button eye and a stitched patch on the tummy.
    add(chibi.cylinder(head_c + Vector((0.042, -0.085, 0.02)), 0.02, 0.008, name="button", axis="Y", segments=12),
        (0.82, 0.2, 0.2))
    add(chibi.box((0.05, 0.012, 0.045), body_c + Vector((-0.015, -0.07, 0.01)), bevel=0.004, name="patch"),
        (0.98, 0.76, 0.56))
    for k in range(3):
        stitch = chibi.box((0.03, 0.006, 0.005), body_c + Vector((-0.015, -0.078, -0.01 + k * 0.012)), bevel=0.0,
                           name="stitch")
        add(stitch, (0.4, 0.22, 0.2))
    # A little pink bow at the neck.
    add(chibi.ellipsoid(head_c + Vector((0, -0.06, -0.085)), (0.045, 0.02, 0.022), name="bow", segs=(12, 8)), TIE)
    obj = common.join(parts, "Nela_Bunny")
    obj.data.transform(Matrix.Translation(grip) @ Matrix.Scale(1.4, 4) @ Matrix.Translation(-grip))
    return obj


def backpack():
    parts = []
    bag = chibi.box((0.5, 0.28, 0.54), (0, 0.4, 0.92), bevel=0.1, name="pack")
    common.color_by(bag, lambda p, n: PACK if n.z < 0.7 else PACK_DARK, smooth=False)
    parts.append(bag)
    flap = chibi.box((0.52, 0.3, 0.12), (0, 0.405, 1.17), bevel=0.05, name="flap")
    common.set_color(flap, PACK_DARK)
    parts.append(flap)
    pocket = chibi.box((0.32, 0.1, 0.22), (0, 0.56, 0.84), bevel=0.04, name="pocket")
    common.color_by(pocket, lambda p, n: LEATHER if p.z > 0.9 else PACK, smooth=False)
    parts.append(pocket)
    for sx in (-0.12, 0.12):
        strap = chibi.box((0.045, 0.13, 0.22), (sx, 0.57, 1.02), bevel=0.01, name="buckle")
        common.color_by(strap, lambda p, n: BRASS if 0.98 < p.z < 1.01 else LEATHER, smooth=False)
        parts.append(strap)
    parts.append(chibi.bedroll((0.06, 0.38, 1.3), 0.5, 0.09, BEDROLL, LEATHER))
    cup = chibi.cylinder((0.3, 0.42, 0.8), 0.055, 0.1, name="cup", bevel=0.01)
    common.set_color(cup, STEEL)
    parts.append(cup)
    handle = chibi.torus((0.36, 0.42, 0.8), 0.03, 0.008, name="cup_handle", axis="Y", segs=(12, 6))
    common.set_color(handle, STEEL)
    parts.append(handle)
    parts += chibi.rope_coil((-0.3, 0.42, 0.86), 0.08, ROPE, loops=3, axis="X")
    parts += chibi.straps(LEATHER, top_y=0.22, front_y=-0.225, xs=(-0.15, 0.15), shoulder_z=1.21, bottom_z=0.74)
    chest_strap = chibi.box((0.3, 0.02, 0.028), (0, -0.225, 1.04), bevel=0.006, name="sternum")
    common.color_by(chest_strap, lambda p, n: BRASS if abs(p.x) < 0.03 else LEATHER, smooth=False)
    parts.append(chest_strap)
    return parts


def lantern(rig):
    """A little camping lantern in the handslot.r frame; its local +X
    points down in the idle pose, so it hangs from her hand."""
    to_world = chibi.bone_frame(rig, "handslot.r")
    metal = []
    bail = chibi.torus((0.04, 0, 0), 0.055, 0.009, name="bail", axis="Y", segs=(18, 6))
    metal.append(bail)
    metal.append(chibi.cylinder((0.12, 0, 0), 0.045, 0.05, name="cap", axis="X", radius2=0.075, bevel=0.01))
    metal.append(chibi.cylinder((0.155, 0, 0), 0.085, 0.025, name="rim", axis="X", bevel=0.008))
    metal.append(chibi.cylinder((0.33, 0, 0), 0.09, 0.04, name="base", axis="X", bevel=0.01))
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        bar = chibi.cylinder((0.24, math.cos(a) * 0.076, math.sin(a) * 0.076), 0.009, 0.16, name="bar", axis="X",
                             segments=8)
        metal.append(bar)
    body = common.join(metal, "Nela_Lantern")
    common.color_by(body, lambda p, n: BRONZE if n.x > -0.3 or p.x > 0.3 else BRONZE_DARK, smooth=False)
    glass = chibi.cylinder((0.24, 0, 0), 0.07, 0.16, name="Nela_LanternGlow", axis="X", segments=20)
    flame = chibi.ellipsoid((0.25, 0, 0), (0.045, 0.028, 0.028), name="flame", segs=(10, 8))
    glass = common.join([glass, flame], "Nela_LanternGlow")
    for obj in (body, glass):
        obj.data.transform(to_world @ Matrix.Scale(1.5, 4))
    return body, glass


def build():
    rig = chibi.load_rig()
    soft = [skin_piece(), shirt_piece(), pants_piece()]
    rigid = hands_and_feet() + cuffs()
    for part in chibi.compass((0, -0.235, 0.99), GOLD, neck_z=1.22, radius=0.04):
        rigid.append((part, "chest"))
    for part in backpack():
        part.data.transform(Matrix.Translation((0, -0.04, 0)))
        rigid.append((part, "chest"))
    collar = chibi.torus((0, 0, 1.2), 0.085, 0.02, name="collar")
    common.set_color(collar, TEE_DARK)
    rigid.append((collar, "chest"))
    head, hair_obj = head_piece()
    PROP.stretch_rig(rig)
    body = chibi.finish(rig, soft, rigid, "Nela", prop=PROP)
    PROP.stretch_mesh(head)
    PROP.stretch_mesh(hair_obj)
    lamp, glow = lantern(rig)
    plush = bunny(chibi.idle_bone_position(rig, "hand.l"))
    chibi.place_in_hand([plush], rig, "hand.l")
    for obj, bone in ((head, "head"), (hair_obj, "head"), (lamp, "hand.r"), (glow, "hand.r"), (plush, "hand.l")):
        chibi.rigid(obj, bone)
        obj.parent = rig
        obj.modifiers.new("Armature", "ARMATURE").object = rig

    meshes = [body, head, hair_obj, lamp, plush]
    if chibi.quick_mode():
        for mesh in meshes:
            chibi.quick_material(mesh, overlay=(FACE_PNG, "FaceUV") if mesh is head else None)
        paint_bake.flat_material(glow, GLOW, emission=3.0, name="lantern_glow")
        print("nela tris:", common.triangle_count(meshes + [glow]))
        render_previews(rig, meshes + [glow], head, "nela", ("Running_A", 8), ("Spellcast_Shoot", 12), ("PickUp", 12))
        return
    params = dict(size=1024, ao_distance=0.18, ao_strength=0.62, edge_strength=0.3, edge_radius=0.012,
                  noise_scale=6.0, stroke_strength=0.08, light=(1.12, 1.04, 0.95), shadow=(0.45, 0.38, 0.58),
                  foot_darken=0.38, foot_height=0.9, key_light=(-0.4, -0.6, 0.8), key_strength=0.4)
    for mesh in meshes:
        # Softer occlusion on the head so the fringe doesn't smudge the face.
        extra = dict(ao_strength=0.4, ao_distance=0.05, overlay=(FACE_PNG, "FaceUV"), cavity=0.25) \
            if mesh is head else dict(cavity=0.2)
        paint_bake.paint(mesh, source="attribute", **dict(params, **extra))
    paint_bake.flat_material(glow, GLOW, emission=3.0, name="lantern_glow")
    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "nela.glb"), [rig] + meshes + [glow], animations=True)
    print("nela tris:", common.triangle_count(meshes + [glow]))
    render_previews(rig, meshes + [glow], head, "nela", ("Running_A", 8), ("Spellcast_Shoot", 12), ("PickUp", 12))


if __name__ == "__main__":
    build()
