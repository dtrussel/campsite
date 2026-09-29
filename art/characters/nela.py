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
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from characters import chibi, face_paint, head_loft  # noqa: E402
from characters.leo import render_previews, sculpt_previews  # noqa: E402

SKIN = (0.99, 0.72, 0.56)
SKIN_SHADE = (0.88, 0.5, 0.38)
BLUSH = (1.0, 0.5, 0.48)
HAIR_LIGHT = (1.0, 0.88, 0.56)
HAIR = (0.88, 0.64, 0.3)
HAIR_DARK = (0.52, 0.32, 0.13)
TEE = (0.68, 0.78, 0.9)
TEE_DARK = (0.46, 0.56, 0.72)
DIRT = (0.52, 0.38, 0.24)
PANTS = (0.4, 0.1, 0.32)
PANTS_DARK = (0.22, 0.04, 0.17)
PATTERN = (0.94, 0.84, 0.82)
PATTERN_PINK = (0.78, 0.42, 0.66)
SOCK = (0.92, 0.88, 0.78)
BOOT = (0.44, 0.27, 0.14)
BOOT_TOE = (0.58, 0.4, 0.24)
SOLE = (0.24, 0.16, 0.1)
LACE = (0.82, 0.62, 0.36)
MUD = (0.28, 0.2, 0.13)
TIE = (0.5, 0.16, 0.5)
SCARF = (0.52, 0.16, 0.56)
SCARF_DARK = (0.3, 0.07, 0.34)
PACK = (0.34, 0.38, 0.2)
PACK_DARK = (0.2, 0.23, 0.11)
LEATHER = (0.4, 0.23, 0.11)
BRASS = (0.86, 0.66, 0.3)
BEDROLL = (0.3, 0.42, 0.24)
BUNNY = (0.86, 0.78, 0.66)
BUNNY_INNER = (0.98, 0.66, 0.68)
LEAF = (0.36, 0.62, 0.2)
GOLD = (0.92, 0.68, 0.26)
BRONZE = (0.58, 0.38, 0.18)
BRONZE_DARK = (0.3, 0.17, 0.08)
GLOW = (1.0, 0.8, 0.38)

HEAD = chibi.HeadFrame((0, -0.01, 1.57), (0.242, 0.252, 0.235))
PROP = chibi.Proportions(legs=1.3, spine=1.1, arms=1.1)
FACE_PNG = os.path.join(common.ROOT, "build", "art_faces", "nela_face.png")
# From the concept art: a 3-year-old's face. A big round cranium with the
# features sitting low; huge round deep-blue eyes with two catchlights
# and dark upper lashes; faint, high, soft brows; a tiny button nose;
# full low cheeks with a strong rosy blush and a few freckles; and a
# wide open laugh showing her top teeth.
FACE = face_paint.FaceLayout(
    size=0.34, eye_x=0.092, eye_z=-0.055, eye_w=0.053, eye_h=0.038, eye_tilt=0.03, lid=0.08, iris_r=0.032,
    look=(0.002, 0.004), iris=(0.36, 0.64, 0.98), iris_dark=(0.04, 0.14, 0.44), lash=(0.14, 0.07, 0.05),
    lash_width=0.011, wing=0.006, lower_lash=0.35, eyeshadow_alpha=0.0, socket=(0.84, 0.56, 0.5),
    socket_alpha=0.25, lid_fold=0.4, nose_shadow=0.12, nostril_alpha=0.22, brows=((0.03, 0.04, 0.011, 0.012), (0.03, 0.04, 0.011, 0.012)),
    brow_len=0.054, brow_colour=(0.66, 0.44, 0.22), brow_alpha=0.75, nose_z=-0.114, nose_w=0.014,
    mouth_z=-0.152, mouth_w=0.052, smile=7.0, smirk=0.0, open_mouth=0.016, lip_upper=0.003, lip_lower=0.008,
    lip_colour=(0.9, 0.48, 0.48), lip_dark=(0.52, 0.18, 0.18), tongue=(0.84, 0.38, 0.4), chin_z=-0.215,
    skin_shadow=(0.8, 0.46, 0.38), light_colour=(1.0, 0.9, 0.78), blush=(1.0, 0.42, 0.42), blush_alpha=0.6, blush_pos=(0.12, -0.115),
    contour=0.1, plane_light=1.0, face_half_w=0.21, catch2=0.9, flush_alpha=0.16, highlight=(1.0, 0.93, 0.87), freckle_colour=(0.72, 0.4, 0.28),
    freckles=[(sx * x, z) for sx in (-1, 1) for x, z in ((0.095, -0.11), (0.115, -0.125), (0.135, -0.108),
                                                          (0.11, -0.14), (0.15, -0.13))])
# Head (feature 014): a drawn, planar game head, related to Leo's but its
# own shape - a young girl: a rounder, softer section, a larger cranium
# relative to the face, a shorter lower face, round (not chubby) cheek
# planes, a small chin and a tiny wedge nose. The face is painted (FACE).
LOFT = head_loft.HeadLoft(
    sections=((0.235, 0.02, -0.02, 0.02, 2.0, 2.0), (0.222, 0.11, -0.11, 0.13, 2.0, 2.0),
              (0.19, 0.175, -0.175, 0.195, 2.0, 2.0), (0.14, 0.215, -0.218, 0.232, 2.1, 2.05),
              (0.09, 0.232, -0.238, 0.244, 2.2, 2.1), (0.04, 0.238, -0.246, 0.24, 2.3, 2.1),
              (0.0, 0.236, -0.248, 0.23, 2.35, 2.15), (-0.04, 0.23, -0.245, 0.215, 2.4, 2.2),
              (-0.08, 0.218, -0.243, 0.195, 2.4, 2.2), (-0.12, 0.196, -0.238, 0.165, 2.4, 2.2),
              (-0.155, 0.16, -0.228, 0.13, 2.4, 2.2), (-0.185, 0.112, -0.215, 0.095, 2.35, 2.15),
              (-0.205, 0.066, -0.2, 0.06, 2.2, 2.1), (-0.22, 0.03, -0.165, 0.03, 2.1, 2.0)),
    nose_top=-0.075, nose_tip_z=-0.106, nose_base_z=-0.117, nose_h=0.013, nose_bridge_h=0.002,
    nose_w=(0.004, 0.009), nose_side=0.011, alae=0.0, cheek=0.009, cheek_pos=(0.115, -0.11),
    eye_inset=0.004, eye_plate=(1.1, 1.35), brow_shelf=0.003,
    upper_lip=0.0025, lower_lip=0.0035, chin=0.003, rings=90)


# ---------------------------------------------------------------- body

def skin_piece():
    """Toddler skin: short neck, chubby arms (soft elbow, a wrist crease
    instead of a bony wrist), chubby legs mostly hidden by the pants."""
    parts = [chibi.limb([(0, 0.005, 1.08), (0, 0.01, 1.25), (0, 0.012, 1.38)], [(0.09, 0.084), (0.082, 0.078),
                                                                             (0.078, 0.072)], up=(0, -1, 0),
                        name="neck")]
    for s in (-1, 1):
        xs = (0.28, 0.37, 0.45, 0.53, 0.62, 0.7, 0.735, 0.78)
        rr = ((0.08, 0.082), (0.08, 0.08), (0.072, 0.07), (0.074, 0.07), (0.068, 0.062), (0.06, 0.052),
              (0.052, 0.044), (0.056, 0.046))
        parts.append(chibi.limb([(s * x, 0, 1.107) for x in xs], rr, up=(0, 0, 1), name="arm"))
        parts.append(chibi.ellipsoid((s * 0.39, -0.02, 1.114), (0.07, 0.05, 0.05), name="chub", segs=(14, 10)))
        zs = (0.47, 0.38, 0.3, 0.24, 0.19, 0.15, 0.12)
        rr = ((0.09, 0.09), (0.084, 0.086), (0.074, 0.076), (0.07, 0.074), (0.062, 0.062), (0.056, 0.056),
              (0.058, 0.062))
        parts.append(chibi.limb([(s * 0.17, 0.0, z) for z in zs], rr, up=(0, -1, 0), name="leg"))
    body = chibi.fuse(parts, "Skin", voxel=0.008, faces=8000)
    common.color_by(body, lambda p, n: common.lerp(SKIN, SKIN_SHADE, max(0.0, -n.z * 0.5)))
    return body


def shirt_piece():
    parts = [
        chibi.ellipsoid((0, 0, 1.01), (0.225, 0.19, 0.21), name="chest"),
        chibi.ellipsoid((0, -0.02, 0.78), (0.245, 0.215, 0.27), name="belly"),
    ]
    for s in (-1, 1):
        parts.append(chibi.limb([(s * 0.13, 0, 1.1), (s * 0.28, 0, 1.1), (s * 0.37, 0, 1.098)],
                                [(0.112, 0.112), (0.106, 0.106), (0.112, 0.11)], up=(0, 0, 1), name="sleeve"))
        parts.append(chibi.ellipsoid((s * 0.2, 0.0, 1.12), (0.09, 0.1, 0.08), name="deltoid", segs=(16, 12)))
        parts.append(chibi.hem_ring((s * 0.34, 0, 1.098), (0.112, 0.11), 0.012, name="hem", axis="X"))
    # Loose hem hanging over the pants' waist.
    parts.append(chibi.limb([(0, -0.02, 0.7), (0, -0.02, 0.6), (0, -0.02, 0.53)],
                            [(0.25, 0.225), (0.27, 0.235), (0.275, 0.238)], up=(0, -1, 0), name="skirt"))
    parts.append(chibi.hem_ring((0, -0.02, 0.535), (0.275, 0.238), 0.009, name="hem", axis="Z"))
    shirt = chibi.fuse(parts, "Shirt", voxel=0.0065, faces=12000)
    for s in (-1, 1):
        chibi.cut_open(shirt, (s * 0.355, 0, 0), (s, 0, 0))
    chibi.cut_open(shirt, (0, 0, 0.525), (0, 0, -1))
    for s in (-1, 1):
        chibi.fold(shirt, (s * 0.19, -0.07, 1.02), (0.12, 0.2, 0.13), 0.011, radial_axis=(0, 1, 0), count=5,
                   twist=0.4 * s, seed=21 + s)
        chibi.fold(shirt, (s * 0.29, 0, 1.1), (0.08, 0.15, 0.15), 0.008, wavelength=0.05, across=(1, 0, 0),
                   twist=0.8, seed=23 + s)
    chibi.fold(shirt, (0, -0.05, 0.62), (0.34, 0.3, 0.12), 0.011, wavelength=0.06, across=(0, 0, 1), twist=1.4,
               seed=25)

    def colour(pos, normal):
        if abs(pos.x) > 0.315:
            return TEE_DARK  # sleeve hem
        if pos.z < 0.56:
            return common.lerp(TEE, TEE_DARK, 0.45)  # hem band
        if abs(pos.z - 0.575) < 0.006 and int(pos.x * 110) % 2 == 0:
            return (0.9, 0.94, 1.0)  # stitched hem
        # Painted folds under the arms and across the tummy.
        fold = math.sin(pos.x * 34 - pos.z * 26) * max(0.0, 0.9 - pos.z) * 2.0
        pit = math.exp(-((abs(pos.x) - 0.18) / 0.05) ** 2 - ((pos.z - 1.0) / 0.08) ** 2)
        c = common.lerp(TEE, TEE_DARK, max(0.0, min(0.55, fold * 0.5 + pit * 0.5)))
        return common.lerp(c, (0.86, 0.92, 0.98), max(0.0, min(0.3, -fold * 0.3)))
    common.color_by(shirt, colour)
    # A well-played-in tee: brown smudges and dirt splotches (the art).
    common.grime(shirt, DIRT, lambda p, n: max(0.0, noise.noise(p * 11.0 + Vector((5, 1, 3))) - 0.1) * 2.2)
    return shirt


def folk_pattern(pos, leg_x):
    """Bold cream zigzag bands and dotted rows on plum, wrapped around
    the leg (big enough to read at game scale)."""
    a = math.atan2(pos.y, pos.x - leg_x)
    u = a / math.tau * 12.0  # 12 repeats around the leg
    band = 0.065
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
        # Puffy harem legs, full length, gathered at the ankle.
        parts.append(chibi.limb([(s * 0.14, 0, 0.58), (s * 0.19, -0.01, 0.42), (s * 0.19, 0.0, 0.31),
                                 (s * 0.18, 0.015, 0.26), (s * 0.175, 0.02, 0.225)],
                                [(0.15, 0.15), (0.168, 0.162), (0.164, 0.16), (0.13, 0.13), (0.1, 0.1)], up=(0, -1, 0),
                                name="pantleg"))
    # Low, saggy harem crotch.
    parts.append(chibi.ellipsoid((0, 0.0, 0.45), (0.14, 0.15, 0.1), name="crotch"))
    pants = chibi.fuse(parts, "Pants", voxel=0.0105)  # even quads: crisp pattern
    chibi.cut_open(pants, (0, 0, 0.235), (0, 0, -1))
    # Harem drape: vertical folds down each leg, gathered into accordion
    # folds at the ankle cuffs; a gathered elastic waist; crotch sag folds.
    for s in (-1, 1):
        chibi.fold(pants, (s * 0.19, 0, 0.4), (0.22, 0.22, 0.2), 0.016, radial_axis=(0, 0, 1), count=7,
                   twist=0.8 * s, seed=31 + s)
        chibi.fold(pants, (s * 0.178, 0.018, 0.25), (0.16, 0.16, 0.05), 0.012, radial_axis=(0, 0, 1), count=12,
                   seed=33 + s)
    chibi.fold(pants, (0, 0, 0.66), (0.34, 0.3, 0.07), 0.01, radial_axis=(0, 0, 1), count=18, seed=35)
    chibi.fold(pants, (0, -0.14, 0.45), (0.16, 0.2, 0.12), 0.012, radial_axis=(0, 1, 0), count=5, seed=36)

    def colour(pos, normal):
        if pos.z < 0.265:
            return PANTS_DARK  # gathered cuff
        leg_x = 0.17 if pos.x > 0 else -0.17
        c = folk_pattern(pos, leg_x)
        # Painted gathers: dark folds running down to the cuffs.
        a = math.atan2(pos.y, pos.x - leg_x)
        fold = max(0.0, math.sin(a * 9 + pos.z * 8)) * max(0.0, 0.42 - pos.z) * 5
        return common.lerp(c, PANTS_DARK, min(0.55, fold * 0.55))
    common.color_by(pants, colour, smooth=False)
    common.grime(pants, DIRT, lambda p, n: max(0.0, noise.noise(p * 10.0) - 0.35) * 0.7)
    return pants


def cuffs():
    parts = []
    for s, bone in ((1, "lowerleg.l"), (-1, "lowerleg.r")):
        ring = chibi.hem_ring((s * 0.175, 0.02, 0.238), (0.1, 0.1), 0.024, name="cuff", segs=(32, 8))
        common.set_color(ring, PANTS_DARK)
        parts.append((ring, bone))
        # Slouchy cream socks bunched over the boot tops.
        sock = chibi.tube([(s * 0.172, 0.02, 0.25), (s * 0.17, 0.02, 0.2), (s * 0.17, 0.02, 0.15)],
                          [0.084, 0.106, 0.1], name="sock", levels=2)
        common.color_by(sock, lambda p, n: common.lerp(SOCK, (0.62, 0.56, 0.46),
                                                       0.45 if int(p.z * 90) % 2 == 0 else 0.0))
        parts.append((sock, bone))
    # Patch pocket on her right thigh.
    pocket = chibi.box((0.03, 0.12, 0.13), (-0.35, -0.01, 0.4), bevel=0.012, name="pocket")
    common.color_by(pocket, lambda p, n: PANTS_DARK if p.z > 0.45 else PANTS, smooth=False)
    parts.append((pocket, "upperleg.r"))
    return parts


def hands_and_feet():
    rigid = []
    for h, bone in chibi.hands(SKIN, sculpted=True, crease=SKIN_SHADE, size=1.05):
        rigid.append((h, bone))
    for s, bone in ((1, "foot.l"), (-1, "foot.r")):
        for part in chibi.sculpted_boot(s, BOOT, SOLE, BOOT_TOE, LACE, scale=1.1, height=0.8,
                                        collar=(0.3, 0.18, 0.09)):
            # Scuffed leather, caked with mud toward the soles.
            common.grime(part, MUD, lambda p, n: max(0.0, (0.1 - p.z) / 0.08) * 0.75 +
                         max(0.0, noise.noise(p * 26.0) - 0.3) * 0.9)
            rigid.append((part, bone))
    # Braided leather bracelets on both wrists.
    for side, bone in ((1, "lowerarm.l"), (-1, "lowerarm.r")):
        for k, dx in enumerate((0.74, 0.77)):
            ring = chibi.torus((side * dx, 0, 1.11), 0.066, 0.012, name="bracelet", axis="X", segs=(16, 6))
            common.color_by(ring, lambda p, n, k=k: LEATHER if (int(math.atan2(p.y, p.z - 1.11) * 5) + k) % 2
                            else common.lerp(LEATHER, (0.1, 0.05, 0.02), 0.4), smooth=False)
            rigid.append((ring, bone))
    return rigid


# ----------------------------------------------------------------- head

F, R, U = Vector((0, -1, 0)), Vector((-1, 0, 0)), Vector((0, 0, 1))  # forward, her right, up


def clump(parts, root, up, controls, width, thickness=0.45, steps=8):
    pts = chibi.sweep(root, controls, steps=steps)
    widths = [width * (1.0 - (i / (steps - 1)) ** 1.8) * (0.85 + 0.3 * math.sin(math.pi * i / (steps - 1)))
              for i in range(steps)]
    widths[-1] = 0.0
    obj = chibi.hair_clump(pts, widths, thickness, up, name="curl", ring=8)
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


def wavy(parts, root, up, controls, width, wave, side, thickness=0.42, steps=9, sharp=False, twist=0.0, tier=1,
          ring=8):
    """A wavy lock: the swept centreline wiggles sideways as it falls.
    tier 0 = primary mass (darker roots), 1 = secondary, 2 = flyaway (lighter)."""
    pts = chibi.sweep(root, controls, steps=steps)
    for i in range(1, steps):
        pts[i] = pts[i] + side * wave * math.sin(i / (steps - 1) * math.pi * 2.2) * (i / (steps - 1))
    widths = [width * (1.0 - (i / (steps - 1)) ** 1.8) * (0.85 + 0.3 * math.sin(math.pi * i / (steps - 1)))
              for i in range(steps)]
    widths[-1] = 0.0
    obj = chibi.hair_clump(pts, widths, thickness, up, name="curl", ring=ring, sharp=sharp, twist=twist)
    length = sum((pts[i + 1] - pts[i]).length for i in range(steps - 1))
    light, mid, dark = HAIR_LIGHT, HAIR, HAIR_DARK
    if tier == 0:
        mid, dark = common.lerp(HAIR, HAIR_DARK, 0.25), common.lerp(HAIR_DARK, (0.2, 0.1, 0.03), 0.3)
    elif tier == 2:
        light, mid = common.lerp(HAIR_LIGHT, (1, 1, 0.9), 0.35), common.lerp(HAIR, HAIR_LIGHT, 0.45)
    common.color_by(obj, chibi.lock_colour(root, length, light, mid, dark))
    parts.append(obj)


BUN_BASE = Vector((0.03, 0.09, 0.0))   # set from HEAD in bun_base()


def bun_base():
    """Where her hair is gathered: the back of the crown, a little
    off-centre (as in the art)."""
    p, n = HEAD.point(0.35, 1.05, 0.02)
    return p + Vector((0.0, 0.03, 0.0))


def top_bun():
    """The messy bun: a lumpy knot with loops and a purple tie, and a few
    loose wisps springing out of it."""
    parts = []
    base = bun_base()
    rng = random.Random(11)
    puffs = [chibi.ellipsoid(base + Vector(o), rad, name="bun", segs=(16, 10))
             for o, rad in (((0, 0.01, 0.045), (0.085, 0.08, 0.065)), ((0.045, 0.03, 0.08), (0.058, 0.055, 0.05)),
                            ((-0.04, 0.0, 0.085), (0.055, 0.05, 0.05)), ((0.0, 0.05, 0.1), (0.05, 0.045, 0.045)))]
    bun = chibi.fuse(puffs, "bun", voxel=0.01, smooth=2, faces=1400)
    common.color_by(bun, chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, base, scale=14.0, strands=18))
    parts.append(bun)
    tie = chibi.torus(base + Vector((0, 0.005, 0.012)), 0.062, 0.017, name="tie", segs=(18, 8))
    common.set_color(tie, TIE)
    parts.append(tie)
    for k in range(11):
        a = k / 11 * math.tau + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(a), math.sin(a), 0.15)).normalized()
        root = base + Vector((0, 0.02, 0.08)) + out * 0.05
        side = Vector((-out.y, out.x, 0)).normalized()
        L = rng.uniform(0.07, 0.13)
        wavy(parts, root, side, [root + out * L * 0.5, root + out * L * 0.9 + side * 0.02 - U * 0.02,
                                 root + out * L + side * 0.05 - U * 0.06],
             rng.uniform(0.012, 0.02), 0.012, side, thickness=0.3, steps=7, sharp=True, tier=2)
    return parts


def hair():
    """Her hair as in the art: pulled up into a messy bun at the back of
    the crown - locks lie along the skull and run up to it - with loose
    face-framing locks falling to the chin and curling out, loose locks
    at the nape, and thin curling flyaways all round (the wild outline).
    Built in tiers: primary pulled masses, secondary locks, flyaways."""
    parts = [hair_cap()]
    rng = random.Random(3)
    base = bun_base()

    def pulled(yaw, pitch, width, tier, lift=0.012):
        """A lock from the hairline running along the skull up to the bun."""
        root, n = HEAD.point(yaw, pitch, lift)
        mids = []
        for t in (0.35, 0.7):
            q, qn = HEAD.point(yaw * (1 - t) + 0.35 * t, pitch * (1 - t) + 1.0 * t, lift + 0.012 + 0.012 * t)
            mids.append(q)
        side = (mids[0] - root).cross(n).normalized()
        wavy(parts, root, n, mids + [base + (root - base).normalized() * 0.04], width, 0.008, side,
             thickness=(0.42, 0.36, 0.3)[tier], steps=9, sharp=tier > 0, twist=rng.uniform(-0.3, 0.3), tier=tier,
             ring=10 if tier == 0 else 8)

    # Primary pulled masses all round the head, then secondary locks over them.
    for k in range(12):
        yaw = -math.pi + (k + 0.5) / 12 * math.tau
        if abs(yaw) < 1.0:
            continue                                     # keep the forehead for the fringe
        pulled(yaw, 0.25 + 0.08 * (k % 2), 0.085, 0, lift=0.006)
    for k in range(22):
        yaw = rng.uniform(-2.9, 2.9)
        if abs(yaw) < 0.9:
            continue
        pulled(yaw, rng.uniform(0.28, 0.58), rng.uniform(0.032, 0.05), 1, lift=0.012)
    # Wispy side-swept fringe, parted a little off-centre; lifted toward the bun.
    for yaw, drop, fan, width, tier in ((-0.5, 0.1, -0.07, 0.026, 2), (-0.34, 0.08, -0.09, 0.022, 2),
                                        (-0.16, 0.065, -0.1, 0.02, 2), (0.02, 0.06, 0.08, 0.018, 2),
                                        (0.2, 0.075, 0.1, 0.022, 2), (0.36, 0.09, 0.09, 0.024, 2),
                                        (0.52, 0.11, 0.07, 0.026, 2)):
        root, n = HEAD.point(yaw, 0.8, 0.006)
        side = Vector((-math.cos(yaw), -math.sin(yaw), 0))
        wavy(parts, root, F, [root + F * 0.05 + U * 0.02, root + F * 0.06 - U * drop * 0.5 - side * fan * 0.5,
                              root + F * 0.045 - U * drop - side * fan * 1.3], width, 0.01, side,
             thickness=0.3 if tier == 1 else 0.26, sharp=True, twist=rng.uniform(-0.3, 0.3), tier=tier)
    # Loose face-framing locks from the temples to the chin, curling out.
    for side in (-1, 1):
        out = Vector((side, 0, 0))
        for k, (yaw, length, width) in enumerate(((0.82, 0.24, 0.03), (0.95, 0.3, 0.034), (1.1, 0.27, 0.022))):
            root, n = HEAD.point(side * yaw, 0.32 - 0.06 * k, 0.012)
            wavy(parts, root, n, [root + out * 0.02 - U * length * 0.35 + F * 0.01,
                                  root + out * 0.03 - U * length * 0.8 + F * 0.02,
                                  root + out * 0.08 - U * length + F * 0.015], width, 0.018, F,
                 thickness=0.34, steps=9, sharp=True, twist=side * 0.4, tier=1)
    # Loose locks at the nape.
    for k, yaw in enumerate((2.5, 2.75, 3.0, 3.25, 3.5, 3.75)):
        root, n = HEAD.point(yaw, -0.05, 0.01)
        flat = Vector((n.x, n.y, 0)).normalized()
        length = rng.uniform(0.12, 0.22)
        wavy(parts, root, n, [root - U * length * 0.4 + flat * 0.02, root - U * length * 0.85 + flat * 0.04,
                              root - U * length + flat * 0.07], rng.uniform(0.03, 0.045), 0.015,
             Vector((1, 0, 0)) * rng.choice((-1, 1)), thickness=0.36, sharp=True, tier=1)
    # Flyaways: thin strands curling off the mass (the messy outline).
    for k in range(26):
        yaw = rng.uniform(-3.0, 3.0)
        if abs(yaw) < 0.8:
            yaw += 0.8 * math.copysign(1, yaw)
        pitch = rng.uniform(0.1, 0.95)
        root, n = HEAD.point(yaw, pitch, 0.028)
        side = Vector((math.cos(yaw), math.sin(yaw), 0)) * rng.choice((-1, 1))
        # Droop sideways-and-down along the mass, lifting off it a little,
        # then curl back: a loose wisp, not a straw.
        curl = (side * 0.7 - U * rng.uniform(0.4, 0.8)).normalized()
        length = rng.uniform(0.08, 0.14)
        wavy(parts, root, n, [root + n * length * 0.25 + curl * length * 0.45,
                              root + n * length * 0.3 + curl * length * 0.9 + side * 0.015,
                              root + n * length * 0.1 + curl * length * 1.1 + side * 0.04],
             rng.uniform(0.01, 0.016), 0.02, side, thickness=0.3, steps=9, sharp=True, tier=2)
    parts += top_bun()
    return parts


def ears():
    return [head_loft.ear(HEAD, side, yaw=1.5, pitch=-0.2, size=1.0, tilt=0.35, colour=SKIN, shade=SKIN_SHADE)
            for side in (-1, 1)]


def head_piece():
    face_paint.paint_face(FACE, FACE_PNG)
    head = head_loft.build_head(HEAD, FACE, LOFT, SKIN, SKIN_SHADE, BLUSH)
    chibi.face_uv(head, HEAD, FACE)
    ear_parts = ears()
    for part in ear_parts:
        chibi.no_face_uv(part)
    hair_parts = hair()
    chibi.report([head] + ear_parts + hair_parts)
    hair_obj = common.join(hair_parts, "Nela_Hair")
    chibi.decimate_tris(hair_obj, 28000)
    return common.join([head] + ear_parts, "Nela_Head"), hair_obj


# ----------------------------------------------------------------- gear

def bunny():
    """Her plush bunny, riding in the top of the backpack and peeking over
    her left shoulder (as in the art): head, both long ears (one flopped),
    little paws over the rim, a stitched patch and a button eye."""
    parts = []
    head_c = Vector((0.36, 0.3, 1.3))
    body_c = head_c + Vector((0.0, 0.03, -0.16))

    def add(obj, colour):
        common.color_by(obj, colour if callable(colour) else (lambda p, n: colour))
        parts.append(obj)
    fuzz = lambda p, n: common.lerp(BUNNY, (0.62, 0.52, 0.42), max(0.0, noise.noise(p * 60.0)) * 0.6)
    add(chibi.ellipsoid(body_c, (0.1, 0.08, 0.12), name="bunny", segs=(18, 12)), fuzz)
    add(chibi.ellipsoid(head_c, (0.11, 0.1, 0.1), name="bunny", segs=(20, 14)), fuzz)
    add(chibi.ellipsoid(head_c + Vector((0, -0.08, -0.03)), (0.055, 0.035, 0.04), name="bunny", segs=(14, 8)),
        (0.98, 0.92, 0.86))
    add(chibi.ellipsoid(head_c + Vector((0, -0.114, -0.01)), (0.018, 0.011, 0.012), name="bunny", segs=(8, 6)),
        BUNNY_INNER)
    add(chibi.ellipsoid(head_c + Vector((-0.045, -0.088, 0.022)), (0.015, 0.009, 0.018), name="bunny", segs=(8, 6)),
        (0.06, 0.04, 0.04))
    # Well-loved: a red button eye on her side, and a stitched patch.
    add(chibi.cylinder(head_c + Vector((0.045, -0.092, 0.022)), 0.022, 0.008, name="button", axis="Y", segments=12),
        (0.72, 0.16, 0.16))
    add(chibi.box((0.05, 0.012, 0.045), head_c + Vector((0.05, -0.07, 0.07)), bevel=0.004, name="patch"),
        (0.72, 0.56, 0.4))
    for k in range(4):
        st = chibi.box((0.004, 0.006, 0.016), head_c + Vector((0.03 + k * 0.013, -0.078, 0.07)), bevel=0.001,
                       name="stitch", segments=1)
        st.data.transform(Matrix.Translation(head_c + Vector((0.03 + k * 0.013, -0.078, 0.07)))
                          @ Matrix.Rotation(0.5, 4, "Y") @ Matrix.Translation(-(head_c + Vector((0.03 + k * 0.013,
                                                                                                -0.078, 0.07)))))
        add(st, (0.3, 0.16, 0.12))
    for s in (-1, 1):
        ear = chibi.ellipsoid((0, 0, 0.14), (0.04, 0.018, 0.14), name="bunny_ear", segs=(14, 8))
        common.color_by(ear, lambda p, n: BUNNY_INNER if n.y < -0.5 and abs(p.x) < 0.024 else BUNNY, smooth=False)
        rot = Matrix.Rotation(s * -0.25, 4, "Y") if s > 0 else Matrix.Rotation(1.2, 4, "Y") @ Matrix.Rotation(0.4, 4, "X")
        ear.data.transform(Matrix.Translation(head_c + Vector((s * 0.05, 0.01, 0.06))) @ rot)
        parts.append(ear)
        # Paws hooked over the pack rim.
        add(chibi.ellipsoid(body_c + Vector((s * 0.07, -0.07, 0.06)), (0.035, 0.035, 0.045), name="bunny",
                            segs=(12, 8)), BUNNY)
    obj = common.join(parts, "Nela_Bunny")
    obj.data.transform(Matrix.Translation(head_c) @ Matrix.Scale(1.25, 4) @ Matrix.Translation(-head_c))
    return obj


def scarf(anchor):
    """The purple scarf knotted to the pack, tails fluttering down."""
    parts = []
    knot = chibi.ellipsoid(anchor, (0.035, 0.03, 0.04), name="scarf", segs=(12, 8))
    parts.append(knot)
    for d, length in (((0.25, 0.3, -1.0), 0.2), ((0.5, -0.1, -1.0), 0.16)):
        tail = chibi.curved_lock(anchor, d, length, 0.035, bend=(0.03, 0.02, 0.0), name="scarf")
        chibi.flatten_along(tail, Vector(anchor), Vector((0, 1, 0)), 0.45)
        parts.append(tail)
    for part in parts:
        common.color_by(part, lambda p, n: common.lerp(SCARF, SCARF_DARK, max(0.0, -n.z) * 0.7 +
                                                       max(0.0, noise.noise(p * 40.0)) * 0.3))
    return parts


def backpack():
    """Olive canvas pack (the art): a wrinkled bag, a leather-trimmed flap
    sagging over the front, a front pocket, two vertical leather straps
    with brass buckles, the green bedroll cinched underneath, the purple
    scarf, a leaf sprig and padded leather shoulder straps."""
    parts = []
    canvas = lambda p, n: common.lerp(PACK, PACK_DARK, max(0.0, -n.z) * 0.5 +
                                      max(0.0, noise.noise(p * 14.0) - 0.2) * 0.5)
    bag = chibi.fuse([chibi.box((0.48, 0.26, 0.48), (0, 0.4, 0.98), bevel=0.1, name="pack", segments=4),
                      chibi.ellipsoid((0, 0.45, 0.88), (0.23, 0.13, 0.17), name="sag")], "pack", voxel=0.008,
                     faces=5000)
    chibi.fold(bag, (0, 0.52, 0.98), (0.28, 0.2, 0.3), 0.006, wavelength=0.07, across=(-0.3, 0, 1), twist=1.0,
               seed=51)
    common.color_by(bag, canvas)
    parts.append(bag)
    flap = chibi.box((0.5, 0.3, 0.06), (0, 0.405, 1.22), bevel=0.025, name="flap", segments=3)
    for v in flap.data.vertices:
        front = max(0.0, (v.co.y - 0.43) / 0.13)
        v.co.z -= 0.1 * front ** 2 + 0.025 * front * (abs(v.co.x) / 0.25) ** 2
    common.color_by(flap, lambda p, n: LEATHER if p.y > 0.53 or abs(p.x) > 0.22 else common.lerp(canvas(p, n), PACK_DARK, 0.3))
    parts.append(flap)
    pocket = chibi.box((0.3, 0.09, 0.22), (0, 0.56, 0.9), bevel=0.035, name="pocket", segments=3)
    common.color_by(pocket, lambda p, n: LEATHER if p.z > 0.98 else canvas(p, n))
    parts.append(pocket)
    for sx in (-0.11, 0.11):
        path = [Vector((sx, 0.45, 1.24)), Vector((sx, 0.53, 1.19)), Vector((sx, 0.6, 1.05)), Vector((sx, 0.61, 0.9)),
                Vector((sx, 0.6, 0.8))]
        st = chibi.webbing(path, [(0, 0, 1), (0, 0.6, 0.8), (0, 1, 0.1), (0, 1, 0), (0, 1, 0)], width=0.022,
                           thick=0.007, name="packstrap")
        common.set_color(st, LEATHER)
        parts.append(st)
        parts.append(chibi.buckle((sx, 0.622, 1.0), (0, 1, 0), width=0.05, height=0.04, colour=BRASS))
    roll_c = (0.0, 0.4, 0.7)
    parts.append(chibi.bedroll(roll_c, 0.54, 0.085, BEDROLL, LEATHER))
    parts += chibi.bedroll_detail(roll_c, 0.54, 0.085, BEDROLL, LEATHER, metal=BRASS)
    parts += scarf((0.24, 0.5, 1.02))
    for ang in (0.4, -0.5):
        leaf = chibi.ellipsoid((0, 0, 0.05), (0.022, 0.006, 0.05), name="leaf", segs=(10, 6))
        for v in leaf.data.vertices:
            v.co.y -= abs(v.co.x) * 0.4
        leaf.data.transform(Matrix.Translation((-0.12, -0.262, 1.1)) @ Matrix.Rotation(ang, 4, "Y"))
        common.set_color(leaf, LEAF)
        parts.append(leaf)
    parts += chibi.straps(LEATHER, top_y=0.22, front_y=-0.255, xs=(-0.15, 0.15), shoulder_z=1.23, bottom_z=0.74,
                          width=0.032, thick=0.01, metal=BRASS)
    chest = chibi.webbing([(-0.17, -0.262, 1.04), (0, -0.27, 1.04), (0.17, -0.262, 1.04)], [(0, -1, 0)] * 3,
                          width=0.013, thick=0.006, name="sternum")
    common.set_color(chest, LEATHER)
    parts.append(chest)
    parts.append(chibi.buckle((0, -0.278, 1.04), (0, -1, 0), width=0.045, height=0.035, colour=BRASS))
    return parts


def lantern(rig):
    """A little camping lantern in the handslot.r frame; its local +X
    points down in the idle pose, so it hangs from her hand. Layered: a
    bail with side loops, a vented chimney and top ring, a flared cap, a
    glass frame of six bars between two rings, and a thick stepped base
    with a fuel knob."""
    to_world = chibi.bone_frame(rig, "handslot.r")
    metal = []
    bail = chibi.torus((0.04, 0, 0), 0.06, 0.008, name="bail", axis="Y", segs=(22, 6))
    for v in bail.data.vertices:
        v.co.x = min(v.co.x, 0.075)
    metal.append(bail)
    for sy in (-1, 1):
        metal.append(chibi.torus((0.075, sy * 0.06, 0), 0.014, 0.005, name="bailloop", axis="Y", segs=(10, 5)))
    metal.append(chibi.torus((0.06, 0, 0), 0.018, 0.006, name="topring", axis="X", segs=(12, 5)))
    metal.append(chibi.cylinder((0.08, 0, 0), 0.028, 0.04, name="chimney", axis="X", bevel=0.004, segments=16))
    metal.append(chibi.cylinder((0.12, 0, 0), 0.045, 0.05, name="cap", axis="X", radius2=0.08, bevel=0.008,
                                segments=20))
    metal.append(chibi.torus((0.1, 0, 0), 0.033, 0.006, name="vent", axis="X", segs=(16, 5)))
    metal.append(chibi.cylinder((0.155, 0, 0), 0.088, 0.022, name="rim", axis="X", bevel=0.006, segments=24))
    for x in (0.165, 0.315):
        metal.append(chibi.torus((x, 0, 0), 0.078, 0.008, name="framering", axis="X", segs=(24, 6)))
    for k in range(6):
        a = k / 6 * math.tau
        metal.append(chibi.cylinder((0.24, math.cos(a) * 0.078, math.sin(a) * 0.078), 0.007, 0.16, name="bar",
                                    axis="X", segments=6))
    metal.append(chibi.cylinder((0.335, 0, 0), 0.092, 0.03, name="base", axis="X", bevel=0.008, segments=24))
    metal.append(chibi.cylinder((0.36, 0, 0), 0.098, 0.022, name="base", axis="X", bevel=0.007, segments=24))
    metal.append(chibi.cylinder((0.335, 0.1, 0), 0.014, 0.022, name="knob", axis="Y", bevel=0.004, segments=10))
    body = common.join(metal, "Nela_Lantern")

    def metal_colour(p, n):
        c = BRONZE if n.x > -0.3 or p.x > 0.3 else BRONZE_DARK
        if 0.085 < p.x < 0.11 and abs(math.atan2(p.z, p.y) * 4 % 1.0 - 0.5) < 0.2:
            c = (0.12, 0.07, 0.04)      # vent slots
        if n.dot(Vector((0, 0.5, 0.8)).normalized()) > 0.75:
            c = common.lerp(c, (1.0, 0.85, 0.55), 0.35)   # polished highlights
        return c
    common.color_by(body, metal_colour, smooth=False)
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
    # Compass clipped to her left shoulder strap, hanging at the hip (art).
    for part in chibi.compass((0.16, -0.265, 0.84), GOLD, neck_z=0.95, radius=0.04):
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
    plush = bunny()
    plush.data.transform(Matrix.Translation((0, -0.04, 0)))
    PROP.stretch_mesh(plush)
    for obj, bone in ((head, "head"), (hair_obj, "head"), (lamp, "hand.r"), (glow, "hand.r"), (plush, "chest")):
        chibi.rigid(obj, bone)
        obj.parent = rig
        obj.modifiers.new("Armature", "ARMATURE").object = rig

    meshes = [body, head, hair_obj, lamp, plush]
    # Game budget (~35k): each mesh is decimated; its dense copy carries
    # the paint and is baked onto it (HIGH_POLY=1 keeps the dense meshes).
    highs = {}
    if not os.environ.get("HIGH_POLY"):
        chibi.report(meshes)
        budget = {body: 18000, head: 4500, hair_obj: 10000, lamp: 1500, plush: 1500}
        highs = {mesh: chibi.lowpoly(mesh, tris) for mesh, tris in budget.items()}

    if os.environ.get("SCULPT"):
        print("nela tris:", common.triangle_count(meshes + [glow]))
        sculpt_previews(rig, meshes + [glow], "nela", ("Running_A", 8), ("PickUp", 12))
        return
    if chibi.quick_mode():
        for mesh in meshes:
            chibi.quick_material(mesh, overlay=(FACE_PNG, "FaceUV") if mesh is head else None)
        paint_bake.flat_material(glow, GLOW, emission=3.0, name="lantern_glow")
        print("nela tris:", common.triangle_count(meshes + [glow]))
        render_previews(rig, meshes + [glow], head, "nela", ("Running_A", 8), ("Spellcast_Shoot", 12), ("PickUp", 12))
        return
    params = dict(size=1024, ao_distance=0.18, ao_strength=0.62, edge_strength=0.3, edge_radius=0.012,
                  noise_scale=6.0, stroke_strength=0.08, light=(1.12, 1.04, 0.95), shadow=(0.45, 0.38, 0.58),
                  foot_darken=0.38, foot_height=0.9, key_light=(-0.4, -0.6, 0.8), key_strength=0.55,
                  curvature_tint=((0.72, 0.55, 0.5), (1.1, 1.08, 1.12), 0.85))
    for mesh in meshes:
        # Softer occlusion and a warm shadow tint on the head: the face keeps
        # the art's warm, bright skin instead of going violet-grey.
        extra = dict(ao_strength=0.4, ao_distance=0.05, overlay=(FACE_PNG, "FaceUV"), cavity=0.25,
                     shadow=(0.84, 0.58, 0.5), light=(1.12, 1.03, 0.94), key_strength=0.35,
                     curvature_tint=((0.9, 0.7, 0.64), (1.05, 1.03, 1.02), 0.45)) \
            if mesh is head else dict(cavity=0.3)
        paint_bake.paint(mesh, source="attribute", high=highs.get(mesh), **dict(params, **extra))
    paint_bake.flat_material(glow, GLOW, emission=3.0, name="lantern_glow")
    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "nela.glb"), [rig] + meshes + [glow], animations=True, image_format="WEBP")
    print("nela tris:", common.triangle_count(meshes + [glow]))
    render_previews(rig, meshes + [glow], head, "nela", ("Running_A", 8), ("Spellcast_Shoot", 12), ("PickUp", 12))


if __name__ == "__main__":
    build()
