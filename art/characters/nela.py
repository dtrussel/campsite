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
from characters import chibi, face_paint, head_sculpt  # noqa: E402
from characters.leo import render_previews, sculpt_previews  # noqa: E402

SKIN = (0.98, 0.76, 0.62)
SKIN_SHADE = (0.86, 0.56, 0.46)
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

HEAD = chibi.HeadFrame((0, -0.01, 1.58), (0.32, 0.31, 0.315))
PROP = chibi.Proportions(legs=1.3, spine=1.1, arms=1.1)
FACE_PNG = os.path.join(common.ROOT, "build", "art_faces", "nela_face.png")
# From the concept art: a 3-year-old's face. A big round cranium with the
# features sitting low; huge round deep-blue eyes with two catchlights
# and dark upper lashes; faint, high, soft brows; a tiny button nose;
# full low cheeks with a strong rosy blush and a few freckles; and a
# wide open laugh showing her top teeth.
FACE = face_paint.FaceLayout(
    size=0.36, eye_x=0.108, eye_z=-0.07, eye_w=0.058, eye_h=0.05, eye_tilt=0.0, lid=0.04, iris_r=0.041,
    look=(0.002, 0.004), iris=(0.36, 0.64, 0.98), iris_dark=(0.04, 0.14, 0.44), lash=(0.14, 0.07, 0.05),
    lash_width=0.0105, wing=0.006, lower_lash=0.35, eyeshadow_alpha=0.0, socket=(0.84, 0.56, 0.5),
    socket_alpha=0.25, lid_fold=0.4, nose_shadow=0.12, nostril_alpha=0.22, brows=((0.05, 0.04, 0.011, 0.012), (0.05, 0.04, 0.011, 0.012)),
    brow_len=0.06, brow_colour=(0.66, 0.44, 0.22), brow_alpha=0.75, nose_z=-0.14, nose_w=0.015,
    mouth_z=-0.18, mouth_w=0.06, smile=7.5, smirk=0.0, open_mouth=0.026, lip_upper=0.003, lip_lower=0.008,
    lip_colour=(0.9, 0.48, 0.48), lip_dark=(0.52, 0.18, 0.18), tongue=(0.84, 0.38, 0.4), chin_z=-0.245,
    skin_shadow=(0.78, 0.48, 0.42), blush=(1.0, 0.42, 0.42), blush_alpha=0.5, blush_pos=(0.14, -0.15),
    contour=0.2, catch2=0.9, flush_alpha=0.1, highlight=(1.0, 0.93, 0.87), freckle_colour=(0.72, 0.4, 0.28),
    freckles=[(sx * x, z) for sx in (-1, 1) for x, z in ((0.1, -0.135), (0.12, -0.15), (0.14, -0.132),
                                                          (0.115, -0.165), (0.155, -0.155))])
# Sculpt: a 3-year-old's head. A big round cranium and forehead, the
# features set low, very full low cheeks, a soft wide jaw and a small
# chin, a tiny button nose with almost no bridge, and an open laugh.
SHAPE = head_sculpt.HeadShape(
    occiput=0.05, face_flat=0.02, mid_face=0.03, forehead=0.032, temple=0.001, jaw_w=0.23, jaw_y=0.07, jaw_z=-0.2,
    chin_w=0.09, chin_z=-0.27, chin_fwd=0.022, jaw_soft=0.035, jaw_top=-0.17, cheek=0.03, cheek_pos=(0.13, -0.15),
    cheek_size=(0.085, 0.075), cheekbone=0.0, socket=0.012, eyeball=0.019, lid=0.006, lid_band=0.01, crease=0.001,
    lower_lid=0.001, brow=0.005, bridge=0.0, bridge_top=-0.8, tip=0.02, tip_lift=0.004, alae=0.009, nostril=0.004,
    muzzle=0.014, upper_lip=0.004, lower_lip=0.006, mouth_depth=0.02, apple=0.014, chin_pad=0.006)


# ---------------------------------------------------------------- body

def skin_piece():
    """Toddler skin: short neck, chubby arms (soft elbow, a wrist crease
    instead of a bony wrist), chubby legs mostly hidden by the pants."""
    parts = [chibi.limb([(0, 0.005, 1.08), (0, 0.01, 1.25), (0, 0.012, 1.38)], [(0.08, 0.076), (0.074, 0.07),
                                                                             (0.07, 0.066)], up=(0, -1, 0),
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


def top_bun():
    """The messy little top bun from the art: a lumpy knot of hair on the
    crown, a purple tie and a few loose wisps sticking out."""
    parts = []
    c, r = HEAD.c, HEAD.r
    base = c + Vector((0.035, 0.07, r.z * 0.9))  # a little off-centre, as in the art
    puffs = [chibi.ellipsoid(base + Vector(o), rad, name="bun", segs=(16, 10))
             for o, rad in (((0, 0, 0.07), (0.1, 0.09, 0.08)), ((0.04, 0.02, 0.12), (0.07, 0.065, 0.06)),
                            ((-0.04, -0.01, 0.11), (0.065, 0.06, 0.06)))]
    bun = chibi.fuse(puffs, "bun", voxel=0.012, smooth=2, faces=900)
    common.color_by(bun, chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, base, scale=12.0, strands=16))
    parts.append(bun)
    tie = chibi.torus(base + Vector((0, 0, 0.02)), 0.08, 0.02, name="tie", segs=(18, 8))
    common.set_color(tie, TIE)
    parts.append(tie)
    for k, (dx, dy, lean) in enumerate(((0.05, -0.02, 1), (-0.06, 0.02, -1), (0.0, 0.07, 1), (0.03, -0.05, -1))):
        root = base + Vector((dx, dy, 0.13))
        out = Vector((dx, dy, 0)).normalized() if (dx or dy) else Vector((1, 0, 0))
        wavy(parts, root, out, [root + U * 0.06 + out * 0.03, root + U * 0.1 + out * 0.08,
                                              root + U * 0.1 + out * 0.14 + Vector((0, 0, -0.03))],
             0.03, 0.012, Vector((-out.y, out.x, 0)) * lean, thickness=0.35, steps=7, sharp=True, tier=2)
    return parts


def hair():
    """Her wild wavy mane in three tiers: big primary masses that make the
    cloud-like silhouette, secondary locks layered over them, and thin
    sharp flyaways and face-framing strands. Her left side is fuller."""
    parts = [hair_cap()]
    rng = random.Random(3)
    # Side-swept wispy fringe, parted a little off-centre.
    for yaw, drop, fan, width, tier in ((-0.55, 0.24, -0.08, 0.075, 1), (-0.25, 0.16, -0.14, 0.08, 1),
                                        (0.05, 0.1, 0.16, 0.07, 1), (0.3, 0.2, 0.12, 0.08, 1),
                                        (0.58, 0.26, 0.07, 0.075, 1), (-0.4, 0.26, -0.03, 0.03, 2),
                                        (0.16, 0.22, 0.1, 0.028, 2), (0.45, 0.3, 0.02, 0.03, 2)):
        root, n = HEAD.point(yaw, 0.78, 0.01)
        side = Vector((-math.cos(yaw), -math.sin(yaw), 0))
        wavy(parts, root, F, [root + F * 0.06 + U * 0.02, root + F * 0.07 - U * drop * 0.5 - side * fan * 0.5,
                              root + F * 0.05 - U * drop - side * fan * 1.3], width, 0.01, side,
             thickness=0.38 if tier == 1 else 0.3, sharp=True, twist=rng.uniform(-0.3, 0.3), tier=tier)
    for side in (-1, 1):
        out = Vector((side, 0, 0))
        full = 0.03 if side > 0 else 0.0
        # Primary masses: big, thick, wavy, puffing out to the shoulders.
        for k, yaw in enumerate((1.35, 1.75, 2.15, 2.55)):
            root, n = HEAD.point(side * yaw, 0.5, -0.005)
            flat = Vector((n.x, n.y, 0)).normalized()
            puff = 0.1 + 0.03 * (k % 2) + full
            length = 0.38 + 0.05 * (k % 2)
            wavy(parts, root, n, [root + flat * puff * 0.7 - U * length * 0.25, root + flat * puff - U * length * 0.7,
                                  root + flat * puff * 0.8 - U * length + out * 0.02],
                 0.12, 0.035, Vector((-flat.y, flat.x, 0)) * (1 if k % 2 else -1), thickness=0.45, ring=10,
                 tier=0, sharp=True, twist=0.3 * side)
        # Secondary locks layered over the masses.
        for k in range(8):
            yaw = 0.9 + k * 0.24 + rng.uniform(-0.05, 0.05)
            pitch = rng.uniform(0.3, 0.55)
            root, n = HEAD.point(side * yaw, pitch, 0.01)
            flat = Vector((n.x, n.y, 0)).normalized()
            puff = rng.uniform(0.1, 0.17) + full
            length = rng.uniform(0.24, 0.42)
            wavy(parts, root, n, [root + flat * puff * 0.75 - U * length * 0.3, root + flat * puff - U * length * 0.7,
                                  root + flat * puff * 0.9 - U * length + out * 0.03],
                 rng.uniform(0.07, 0.1), 0.03, Vector((-flat.y, flat.x, 0)) * rng.choice((-1, 1)), thickness=0.42,
                 sharp=True, twist=rng.uniform(-0.5, 0.5), tier=1)
        # Face-framing strand in front of the ear, down to the cheek.
        root, n = HEAD.point(side * 0.95, 0.35, 0.01)
        wavy(parts, root, n, [root + out * 0.03 - U * 0.08, root + out * 0.05 - U * 0.2 + F * 0.02,
                              root + out * 0.07 - U * 0.3 + F * 0.03], 0.035, 0.02, F, thickness=0.3, sharp=True,
             twist=side * 0.4, tier=2)
    # Back: two primary masses and secondary locks.
    for yaw in (2.85, 3.43):
        root, n = HEAD.point(yaw, 0.35, 0.0)
        flat = Vector((n.x, n.y, 0)).normalized()
        wavy(parts, root, n, [root + flat * 0.1 - U * 0.1, root + flat * 0.13 - U * 0.3, root + flat * 0.12 - U * 0.44],
             0.16, 0.03, Vector((1, 0, 0)), thickness=0.55, ring=10, tier=0)
    for k in range(5):
        yaw = 2.7 + k * 0.22
        root, n = HEAD.point(yaw, rng.uniform(0.35, 0.6), 0.01)
        flat = Vector((n.x, n.y, 0)).normalized()
        length = rng.uniform(0.3, 0.45)
        wavy(parts, root, n, [root + flat * 0.12 - U * length * 0.3, root + flat * 0.15 - U * length * 0.7,
                              root + flat * 0.13 - U * length], rng.uniform(0.07, 0.1), 0.03,
             Vector((1, 0, 0)) * rng.choice((-1, 1)), thickness=0.42, sharp=True, twist=rng.uniform(-0.5, 0.5))
    # Tertiary: thin sharp flyaways springing off the mane and crown.
    for k in range(14):
        yaw = rng.uniform(-2.6, 2.6)
        yaw += 0.6 * math.copysign(1, yaw) if abs(yaw) < 0.6 else 0.0   # keep them off the face
        pitch = rng.uniform(0.2, 1.05)
        root, n = HEAD.point(yaw, pitch, 0.03)
        curl = Vector((math.cos(yaw), math.sin(yaw), 0)) * rng.choice((-1, 1))
        length = rng.uniform(0.08, 0.16)
        wavy(parts, root, n, [root + n * length * 0.3 + curl * length * 0.4,
                              root + n * length * 0.45 + curl * length * 0.85,
                              root + n * length * 0.35 + curl * length * 1.1 - U * 0.03],
             rng.uniform(0.018, 0.028), 0.01, curl, thickness=0.3, steps=7, sharp=True, tier=2)
    parts += top_bun()
    return parts


def ears():
    return [head_sculpt.ear(HEAD, side, yaw=1.5, pitch=-0.2, size=1.0, tilt=0.35, colour=SKIN, shade=SKIN_SHADE)
            for side in (-1, 1)]


def head_piece():
    face_paint.paint_face(FACE, FACE_PNG)
    head = head_sculpt.build_head(HEAD, FACE, SHAPE, SKIN, SKIN_SHADE, BLUSH, tris=24000)
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
    params = dict(size=2048, ao_distance=0.18, ao_strength=0.62, edge_strength=0.3, edge_radius=0.012,
                  noise_scale=6.0, stroke_strength=0.08, light=(1.12, 1.04, 0.95), shadow=(0.45, 0.38, 0.58),
                  foot_darken=0.38, foot_height=0.9, key_light=(-0.4, -0.6, 0.8), key_strength=0.55,
                  curvature_tint=((0.72, 0.55, 0.5), (1.1, 1.08, 1.12), 0.85))
    for mesh in meshes:
        # Softer occlusion and a warm shadow tint on the head: the face keeps
        # the art's warm, bright skin instead of going violet-grey.
        extra = dict(ao_strength=0.4, ao_distance=0.05, overlay=(FACE_PNG, "FaceUV"), cavity=0.25,
                     shadow=(0.8, 0.62, 0.62), light=(1.14, 1.06, 0.98), key_strength=0.35,
                     curvature_tint=((0.9, 0.7, 0.64), (1.05, 1.03, 1.02), 0.45)) \
            if mesh is head else dict(cavity=0.3)
        paint_bake.paint(mesh, source="attribute", **dict(params, **extra))
    paint_bake.flat_material(glow, GLOW, emission=3.0, name="lantern_glow")
    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "nela.glb"), [rig] + meshes + [glow], animations=True, image_format="WEBP")
    print("nela tris:", common.triangle_count(meshes + [glow]))
    render_previews(rig, meshes + [glow], head, "nela", ("Running_A", 8), ("Spellcast_Shoot", 12), ("PickUp", 12))


if __name__ == "__main__":
    build()
