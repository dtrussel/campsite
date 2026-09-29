"""Leo, the big brother (the player). Modelled from the concept art: messy
blond hair under a backwards navy cap, big blue eyes, freckles and a
grin; light-blue tee with a forest badge; teal board shorts with lime
stripes; grey socks and chunky hiking boots; a big camo backpack with a
navy bedroll, steel bottle and rope; a compass on a cord; and his
trusty walking stick. Built on the KayKit adventurer rig so all 76
animations work. Output: leo.glb"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from characters import chibi, face_paint, head_loft, head_sculpt  # noqa: E402

SKIN = (0.97, 0.68, 0.5)
SKIN_SHADE = (0.8, 0.44, 0.32)
BLUSH = (0.98, 0.5, 0.44)
HAIR_LIGHT = (1.0, 0.86, 0.5)
HAIR = (0.84, 0.6, 0.26)
HAIR_DARK = (0.44, 0.27, 0.1)
SCUFF = (0.62, 0.36, 0.26)       # grazed, dusty knees
DIRT = (0.42, 0.32, 0.22)
TEE = (0.46, 0.64, 0.84)
TEE_DARK = (0.26, 0.4, 0.62)
BADGE = (0.12, 0.22, 0.45)
BADGE_TREE = (0.42, 0.72, 0.18)
SHORTS = (0.07, 0.36, 0.5)
SHORTS_DARK = (0.03, 0.18, 0.3)
SHORTS_LIGHT = (0.18, 0.54, 0.7)
LIME = (0.62, 0.84, 0.14)
STITCH = (0.6, 0.8, 0.84)
SOCK = (0.6, 0.6, 0.62)
BOOT = (0.14, 0.19, 0.34)
BOOT_TOE = (0.42, 0.34, 0.26)
SOLE = (0.6, 0.48, 0.34)
LACE = (0.92, 0.46, 0.14)
BOOT_ACCENT = (0.62, 0.8, 0.2)
MUD = (0.3, 0.22, 0.14)
CAP = (0.1, 0.13, 0.28)
CAP_SEAM = (0.05, 0.07, 0.16)
CAMO = [(0.26, 0.33, 0.15), (0.14, 0.18, 0.09), (0.4, 0.37, 0.22)]
STRAP = (0.34, 0.2, 0.1)
BEDROLL = (0.12, 0.2, 0.42)
STEEL = (0.74, 0.76, 0.8)
ROPE = (0.78, 0.62, 0.38)
GOLD = (0.92, 0.68, 0.26)
BARK = (0.38, 0.23, 0.12)
BARK_LIGHT = (0.58, 0.4, 0.22)
LEAF = (0.36, 0.62, 0.2)
RED = (0.86, 0.16, 0.14)
METAL = (0.72, 0.68, 0.6)

HEAD = chibi.HeadFrame((0, -0.01, 1.565), (0.214, 0.235, 0.225))
PROP = chibi.Proportions(legs=1.85, spine=1.3, arms=1.25)
FACE_PNG = os.path.join(common.ROOT, "build", "art_faces", "leo_face.png")
# From the concept art: a round, open 7-year-old face. Big bright-blue
# eyes looking up and off to the side (two catchlights), soft raised
# light-brown brows, a small upturned button nose, a wide happy grin
# showing a hint of teeth, freckles over the nose and cheeks and a warm
# sun-flush. Contouring is kept soft: children's faces are rounded.
FACE = face_paint.FaceLayout(
    size=0.3, eye_x=0.086, eye_z=-0.03, eye_w=0.05, eye_h=0.033, eye_tilt=0.05, lid=0.12, iris_r=0.029,
    look=(0.006, 0.005), iris=(0.36, 0.72, 0.98), iris_dark=(0.03, 0.2, 0.46), lash=(0.2, 0.11, 0.06),
    lash_width=0.0095, wing=0.005, lower_lash=0.3, eyeshadow_alpha=0.0, socket=(0.8, 0.52, 0.44),
    socket_alpha=0.3, lid_fold=0.4, nose_shadow=0.22, nostril_alpha=0.25, brows=((0.024, 0.08, 0.012, 0.01), (0.02, 0.06, 0.012, 0.009)),
    brow_len=0.056, brow_colour=(0.44, 0.25, 0.1), brow_alpha=1.0, nose_z=-0.098, nose_w=0.016,
    mouth_z=-0.145, mouth_w=0.054, smile=7.0, smirk=0.06, open_mouth=0.011, lip_upper=0.004, lip_lower=0.007,
    lip_colour=(0.88, 0.5, 0.44), lip_dark=(0.5, 0.2, 0.16), tongue=(0.8, 0.36, 0.36), chin_z=-0.228,
    skin_shadow=(0.74, 0.4, 0.3), light_colour=(1.0, 0.88, 0.74), blush=(0.98, 0.46, 0.4), blush_alpha=0.45, blush_pos=(0.125, -0.1),
    contour=0.12, plane_light=1.0, face_half_w=0.19, catch2=0.8, flush_alpha=0.22, freckle_colour=(0.66, 0.36, 0.22),
    freckles=[(sx * x, z) for sx in (-1, 1) for x, z in ((0.03, -0.075), (0.045, -0.07), (0.06, -0.078),
                                                          (0.075, -0.09), (0.052, -0.088), (0.09, -0.1),
                                                          (0.11, -0.09), (0.1, -0.115), (0.022, -0.086))]
    + [(0.0, -0.072), (0.008, -0.08), (-0.009, -0.078)])
# Head (feature 014): a drawn, planar game head lofted from the concept's
# front outline and side profile - a 7-year-old boy: a slightly long face,
# a squarish face front with defined cheek and jaw corners, a wedge nose
# with an upturned tip, a clear chin. The face itself is painted (FACE).
# Sections: (z, half-width, front depth, back depth, squareness front/back).
LOFT = head_loft.HeadLoft(
    sections=((0.228, 0.02, -0.02, 0.02, 2.0, 2.0), (0.215, 0.1, -0.1, 0.115, 2.0, 2.0),
              (0.185, 0.16, -0.16, 0.18, 2.05, 2.05), (0.13, 0.2, -0.2, 0.222, 2.2, 2.1),
              (0.08, 0.212, -0.222, 0.234, 2.35, 2.15), (0.03, 0.214, -0.232, 0.232, 2.5, 2.2),
              (-0.01, 0.212, -0.236, 0.222, 2.65, 2.25), (-0.05, 0.207, -0.228, 0.205, 2.75, 2.3),
              (-0.09, 0.196, -0.232, 0.185, 2.8, 2.3), (-0.13, 0.172, -0.233, 0.16, 2.8, 2.35),
              (-0.165, 0.138, -0.226, 0.13, 2.9, 2.35), (-0.195, 0.095, -0.216, 0.095, 2.9, 2.3),
              (-0.218, 0.055, -0.2, 0.06, 2.5, 2.2), (-0.235, 0.028, -0.155, 0.03, 2.2, 2.1)),
    nose_top=-0.05, nose_tip_z=-0.092, nose_base_z=-0.108, nose_h=0.019, nose_bridge_h=0.004,
    nose_w=(0.006, 0.012), nose_side=0.014, alae=0.0, cheek=0.006, cheek_pos=(0.11, -0.085),
    eye_inset=0.004, eye_plate=(1.1, 1.35), brow_shelf=0.004)


def camo(pos, normal):
    n = noise.noise(pos * 7.0 + Vector((3, 1, 2)))
    m = noise.noise(pos * 11.0 + Vector((7, 5, 1)))
    if n > 0.25:
        return CAMO[1]
    if m > 0.3:
        return CAMO[2]
    return CAMO[0]


# ---------------------------------------------------------------- body

def skin_piece():
    """Skin with stylised landmarks (rest pose, before the proportions
    stretch): shoulder at x 0.21, elbow 0.45, wrist 0.75; hip z 0.52,
    knee 0.29, ankle 0.145."""
    parts = [chibi.limb([(0, 0.005, 1.08), (0, 0.01, 1.25), (0, 0.012, 1.4)], [(0.092, 0.084), (0.084, 0.078),
                                                                             (0.078, 0.072)], up=(0, -1, 0),
                        name="neck")]
    for s in (-1, 1):
        # Arm: widths are (front-back, up-down). Bicep swell, a narrower
        # elbow, the forearm widest just below it, a flat narrow wrist.
        xs = (0.3, 0.38, 0.45, 0.5, 0.58, 0.66, 0.72, 0.78)
        rr = ((0.08, 0.082), (0.078, 0.08), (0.066, 0.064), (0.074, 0.068), (0.068, 0.061), (0.059, 0.051),
              (0.052, 0.041), (0.05, 0.039))
        parts.append(chibi.limb([(s * x, 0, 1.107) for x in xs], rr, up=(0, 0, 1), name="arm"))
        parts.append(chibi.ellipsoid((s * 0.455, 0.036, 1.107), (0.024, 0.02, 0.022), name="elbow", segs=(12, 8)))
        parts.append(chibi.ellipsoid((s * 0.37, -0.024, 1.117), (0.05, 0.034, 0.036), name="bicep", segs=(14, 10)))
        # Leg: thigh (under the shorts), knee, calf swell behind, a tapering
        # shin and a narrow ankle.
        zs = (0.47, 0.38, 0.3, 0.25, 0.2, 0.16, 0.13)
        rr = ((0.086, 0.086), (0.078, 0.08), (0.068, 0.07), (0.066, 0.07), (0.058, 0.056), (0.05, 0.05),
              (0.052, 0.056))
        parts.append(chibi.limb([(s * 0.17, 0.0, z) for z in zs], rr, up=(0, -1, 0), name="leg"))
        parts.append(chibi.ellipsoid((s * 0.17, -0.052, 0.296), (0.04, 0.024, 0.036), name="knee", segs=(12, 8)))
        parts.append(chibi.ellipsoid((s * 0.172, 0.03, 0.235), (0.052, 0.045, 0.062), name="calf", segs=(14, 10)))
    body = chibi.fuse(parts, "Skin", voxel=0.008, faces=9000)
    common.color_by(body, lambda p, n: common.lerp(SKIN, SKIN_SHADE, max(0.0, -n.z * 0.5)))
    # Grazed, dusty knees and shins (an outdoors kid).
    common.grime(body, SCUFF, lambda p, n: 0.7 * math.exp(-((p.z - 0.3) / 0.05) ** 2) * max(0.0, -n.y)
                 * (0.5 + noise.noise(p * 40.0)))
    common.grime(body, DIRT, lambda p, n: 0.35 * max(0.0, (0.26 - p.z) / 0.12) * (0.6 + noise.noise(p * 25.0)))
    return body


def shirt_piece():
    # Lean V-shaped torso: broader chest, narrower waist; deltoid caps, a
    # trapezius slope from the neck, shoulder blades; flared sleeves.
    parts = [
        chibi.ellipsoid((0, 0, 1.01), (0.27, 0.2, 0.23), name="chest"),
        chibi.ellipsoid((0, -0.005, 0.78), (0.225, 0.19, 0.27), name="belly"),
    ]
    for s in (-1, 1):
        parts.append(chibi.limb([(s * 0.14, 0, 1.1), (s * 0.3, 0, 1.1), (s * 0.4, 0, 1.098)],
                                [(0.12, 0.12), (0.112, 0.112), (0.118, 0.115)], up=(0, 0, 1), name="sleeve"))
        parts.append(chibi.ellipsoid((s * 0.22, 0.0, 1.13), (0.1, 0.11, 0.09), name="deltoid", segs=(16, 12)))
        parts.append(chibi.ellipsoid((s * 0.11, 0.025, 1.19), (0.11, 0.08, 0.05), name="trap", segs=(16, 10)))
        parts.append(chibi.ellipsoid((s * 0.1, 0.14, 1.03), (0.085, 0.05, 0.1), name="blade", segs=(14, 10)))
        # Rolled sleeve hem.
        parts.append(chibi.hem_ring((s * 0.372, 0, 1.098), (0.118, 0.115), 0.013, name="hem", axis="X"))
    # Loose bottom hanging over the shorts' waist, with a rolled hem.
    parts.append(chibi.limb([(0, -0.005, 0.74), (0, -0.005, 0.64), (0, -0.005, 0.56)],
                            [(0.215, 0.185), (0.245, 0.205), (0.255, 0.212)], up=(0, -1, 0), name="skirt"))
    parts.append(chibi.hem_ring((0, -0.005, 0.565), (0.255, 0.212), 0.009, name="hem", axis="Z"))
    shirt = chibi.fuse(parts, "Shirt", voxel=0.0065, faces=12000)
    for s in (-1, 1):
        chibi.cut_open(shirt, (s * 0.39, 0, 0), (s, 0, 0))
    chibi.cut_open(shirt, (0, 0, 0.555), (0, 0, -1))
    # Sculpted folds: tension folds radiating from the armpits, rings on
    # the sleeves, compression folds at the waist, a drag fold from the
    # pack straps.
    for s in (-1, 1):
        chibi.fold(shirt, (s * 0.2, -0.06, 1.02), (0.13, 0.2, 0.14), 0.014, radial_axis=(0, 1, 0), count=6,
                   twist=0.4 * s, seed=3 + s)
        chibi.fold(shirt, (s * 0.2, 0.08, 1.02), (0.13, 0.2, 0.14), 0.012, radial_axis=(0, 1, 0), count=5,
                   seed=5 + s)
        chibi.fold(shirt, (s * 0.32, 0, 1.1), (0.09, 0.16, 0.16), 0.01, wavelength=0.05, across=(1, 0, 0),
                   twist=0.8, seed=7 + s)
    chibi.fold(shirt, (0, 0, 0.66), (0.32, 0.3, 0.12), 0.013, wavelength=0.055, across=(0, 0, 1), twist=1.2, seed=2)
    chibi.fold(shirt, (0.02, -0.18, 0.84), (0.2, 0.12, 0.14), 0.01, wavelength=0.06, across=(1, 0, 0.6), seed=4)

    def colour(pos, normal):
        if abs(pos.x) > 0.345:
            return TEE_DARK  # sleeve hem
        if abs(abs(pos.x) - 0.33) < 0.006 and int(pos.z * 90) % 2 == 0:
            return common.lerp(TEE, (0.9, 0.95, 1.0), 0.5)  # stitched sleeve hem
        if pos.z < 0.6:
            return common.lerp(TEE, TEE_DARK, 0.5)  # hem band
        # Painted fabric folds: diagonal creases at the waist and armpits,
        # a lighter ridge on each crease.
        fold = math.sin(pos.x * 38 + pos.z * 22) * max(0.0, 0.88 - pos.z) * 2.4
        pit = math.exp(-((abs(pos.x) - 0.2) / 0.05) ** 2 - ((pos.z - 1.0) / 0.08) ** 2)
        c = common.lerp(TEE, TEE_DARK, max(0.0, min(0.55, fold * 0.5 + pit * 0.5)))
        return common.lerp(c, (0.66, 0.8, 0.94), max(0.0, min(0.35, -fold * 0.3)))
    common.color_by(shirt, colour)
    common.grime(shirt, DIRT, lambda p, n: max(0.0, noise.noise(p * 9.0 + Vector((2, 7, 1))) - 0.25) * 0.8)
    return shirt


def shorts_piece():
    parts = [chibi.ellipsoid((0, 0, 0.58), (0.24, 0.195, 0.14), name="hips")]
    for s in (-1, 1):
        parts.append(chibi.limb([(s * 0.13, 0, 0.6), (s * 0.165, -0.004, 0.44), (s * 0.178, 0, 0.32)],
                                [(0.128, 0.126), (0.133, 0.128), (0.136, 0.128)], up=(0, -1, 0), name="shortleg"))
        parts.append(chibi.hem_ring((s * 0.178, 0, 0.34), (0.136, 0.128), 0.012, name="hem", axis="Z"))
    shorts = chibi.fuse(parts, "Shorts", voxel=0.009)  # even quads: crisp stripes
    chibi.cut_open(shorts, (0, 0, 0.325), (0, 0, -1))
    # Crotch folds radiating from the fork, drag folds on the legs, and
    # bunching above the hems.
    chibi.fold(shorts, (0, -0.12, 0.47), (0.16, 0.2, 0.13), 0.014, radial_axis=(0, 1, 0), count=5, twist=0.3,
               seed=11)
    chibi.fold(shorts, (0, 0.12, 0.47), (0.16, 0.2, 0.13), 0.011, radial_axis=(0, 1, 0), count=4, seed=12)
    for s in (-1, 1):
        chibi.fold(shorts, (s * 0.18, 0, 0.38), (0.16, 0.16, 0.07), 0.01, wavelength=0.04, across=(0, 0, 1),
                   twist=1.0, seed=13 + s)
        chibi.fold(shorts, (s * 0.2, -0.1, 0.42), (0.12, 0.08, 0.1), 0.009, wavelength=0.05, across=(s, 0, 1),
                   seed=15 + s)

    def colour(pos, normal):
        z = pos.z
        if z < 0.345:
            return SHORTS_DARK  # hem
        if abs(z - 0.355) < 0.005 and int(pos.x * 120) % 2 == 0:
            return STITCH  # stitched hem line
        # Two parallel diagonal lime stripes across both legs,
        # with a lighter blue band between them (the art's board shorts).
        t = z - 0.3 * pos.x
        if 0.4 < t < 0.44 or 0.465 < t < 0.49:
            return LIME
        if 0.44 <= t <= 0.465:
            return SHORTS_LIGHT
        if abs(normal.x) > 0.85 and z > 0.46:
            return SHORTS_LIGHT  # side panel
        # Painted folds at the crotch and behind the knees.
        fold = math.exp(-(pos.x / 0.05) ** 2 - ((z - 0.45) / 0.06) ** 2) + \
            0.5 * max(0.0, math.sin(pos.x * 60 + z * 30)) * max(0.0, 0.45 - z) * 6
        return common.lerp(SHORTS, SHORTS_DARK, min(0.6, fold * 0.6))
    common.color_by(shorts, colour)
    common.grime(shorts, (0.5, 0.42, 0.3), lambda p, n: max(0.0, noise.noise(p * 12.0) - 0.3) * 0.6)
    return shorts


def cargo_pockets():
    """Flapped cargo pockets on the outside of each thigh."""
    rigid = []
    for s, bone in ((1, "upperleg.l"), (-1, "upperleg.r")):
        pocket = chibi.box((0.03, 0.13, 0.12), (s * 0.305, -0.005, 0.44), bevel=0.012, name="pocket")
        common.color_by(pocket, lambda p, n: SHORTS_DARK if abs(p.y + 0.005) > 0.055 or p.z < 0.35 else SHORTS,
                        smooth=False)
        flap = chibi.box((0.036, 0.14, 0.04), (s * 0.31, -0.005, 0.5), bevel=0.01, name="pocketflap")
        common.color_by(flap, lambda p, n: SHORTS_DARK if n.z < 0.5 else SHORTS_LIGHT, smooth=False)
        rigid += [(pocket, bone), (flap, bone)]
    return rigid


def badge():
    """The camp logo on the tee: a navy ring, a pale sky disc, a green
    hill and a dark pine (built from pieces so it reads without texels)."""
    c = Vector((0.07, -0.212, 0.9))
    parts = []

    def piece(obj, colour):
        common.set_color(obj, colour)
        parts.append(obj)
    piece(chibi.cylinder(c, 0.064, 0.008, name="badge", axis="Y", segments=24, bevel=0.003), BADGE)
    piece(chibi.cylinder(c + Vector((0, -0.005, 0)), 0.05, 0.006, name="badge", axis="Y", segments=24),
          (0.7, 0.84, 0.96))
    hill = chibi.ellipsoid(c + Vector((0, -0.01, -0.035)), (0.05, 0.004, 0.022), name="badge", segs=(16, 6))
    piece(hill, BADGE_TREE)
    for dx, h in ((-0.015, 0.05), (0.018, 0.038)):
        pine = chibi.cylinder(c + Vector((dx, -0.012, -0.012 + h * 0.5)), 0.018, h, name="badge", segments=3,
                              radius2=0.0)
        piece(pine, (0.08, 0.32, 0.18))
    return common.join(parts, "badge")


def hands_and_feet():
    rigid = []
    for h, bone in chibi.hands(SKIN, sculpted=True, crease=SKIN_SHADE, size=1.12):
        rigid.append((h, bone))
    for s, bone in ((1, "foot.l"), (-1, "foot.r")):
        for part in chibi.sculpted_boot(s, BOOT, SOLE, BOOT_TOE, LACE, collar=(0.1, 0.12, 0.22), scale=1.22,
                                        height=0.8):
            # Muddy, scuffed hiking boots.
            common.grime(part, MUD, lambda p, n: max(0.0, (0.09 - p.z) / 0.08) * 0.7 +
                         max(0.0, noise.noise(p * 30.0) - 0.35) * 0.8)
            rigid.append((part, bone))
        # Slouchy grey socks folded over the boot tops.
        sock = chibi.limb([(s * 0.17, 0.01, 0.235), (s * 0.17, 0.012, 0.2), (s * 0.17, 0.012, 0.15)],
                          [(0.056, 0.058), (0.062, 0.066), (0.07, 0.078)], up=(0, -1, 0), name="sock")
        roll = chibi.hem_ring((s * 0.17, 0.01, 0.228), (0.058, 0.06), 0.011, name="sock")
        sock = common.join([sock, roll], "sock")
        common.color_by(sock, lambda p, n: common.lerp(SOCK, (0.36, 0.36, 0.4),
                                                       0.5 if int(p.z * 110) % 2 == 0 else 0.0))
        rigid.append((sock, "lowerleg." + bone[-1]))
    return rigid


# ----------------------------------------------------------------- head

F, R, U = Vector((0, -1, 0)), Vector((-1, 0, 0)), Vector((0, 0, 1))  # forward, his right, up


def clump(parts, root, up, controls, width, length_ratio=None, thickness=0.55, colour=None, steps=7, sharp=False,
          twist=0.0, ring=8, tier=1):
    """One hair clump. tier 0 = primary mass (darker roots), 1 = secondary,
    2 = tertiary flick (lighter)."""
    pts = chibi.sweep(root, controls, steps=steps)
    widths = [width * (1.0 - (i / (steps - 1)) ** 1.6) * (0.85 + 0.3 * math.sin(math.pi * i / (steps - 1)))
              for i in range(steps)]
    widths[-1] = 0.0
    obj = chibi.hair_clump(pts, widths, thickness, up, name="clump", ring=ring, sharp=sharp, twist=twist)
    length = sum((pts[i + 1] - pts[i]).length for i in range(steps - 1))
    light, mid, dark = HAIR_LIGHT, HAIR, HAIR_DARK
    if tier == 0:
        mid, dark = common.lerp(HAIR, HAIR_DARK, 0.25), common.lerp(HAIR_DARK, (0.2, 0.1, 0.03), 0.3)
    elif tier == 2:
        light, mid = common.lerp(HAIR_LIGHT, (1, 1, 0.9), 0.3), common.lerp(HAIR, HAIR_LIGHT, 0.4)
    common.color_by(obj, colour or chibi.lock_colour(root, length, light, mid, dark))
    parts.append(obj)


def hair_and_cap():
    c = HEAD.c
    r = HEAD.r
    parts = []
    # Close-cropped hair shell under the cap (sides and back).
    shell_r = (r.x + 0.02, r.y + 0.02, r.z + 0.015)
    shell = chibi.ellipsoid(c + Vector((0, 0.012, 0.01)), shell_r, name="hairshell", segs=(36, 22))
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    kill = []
    for v in bm.verts:
        d = v.co - c
        d = Vector((d.x / shell_r[0], d.y / shell_r[1], d.z / shell_r[2]))
        keep = d.z > 0.45 or (d.y > -0.25 and d.z > -0.05) or (d.y > 0.35 and d.z > -0.5)
        if not keep:
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(shell.data)
    bm.free()
    mod = shell.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.02
    common.apply_all_modifiers(shell)
    common.shade_smooth(shell)
    common.color_by(shell, chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, c, strands=30))
    parts.append(shell)

    # Messy fringe out of the backwards cap's front opening, in three
    # tiers (MOBA-style layered hair): a few big primary masses that set
    # the silhouette, secondary clumps layered between them, and thin sharp
    # tertiary flicks. Most of it sweeps to his right, as in the art.
    rng = random.Random(7)

    def fringe(yaw, pitch, drop, sweep, width, tier, lift=0.045, up_flick=0.0):
        root, n = HEAD.point(yaw, pitch, -0.012)
        side = Vector((-math.cos(yaw), -math.sin(yaw), 0))  # tangent toward his right
        controls = [root + F * 0.06 + U * (lift + up_flick),
                    root + F * 0.1 - U * (drop * 0.4 - up_flick * 1.5) + side * sweep * 0.55,
                    root + F * (0.08 + up_flick) - U * (drop - up_flick * 3.0) + side * sweep * 1.5]
        clump(parts, root, F, controls, width, thickness=(0.5, 0.4, 0.35)[tier], sharp=tier > 0,
              twist=rng.uniform(-0.35, 0.35), ring=(10, 8, 8)[tier], steps=(9, 8, 7)[tier], tier=tier)

    # Primary masses: short, sweeping to his right, ending above the brows.
    for yaw, drop, sweep, width in ((-0.58, 0.1, 0.1, 0.095), (-0.24, 0.085, 0.12, 0.1), (0.1, 0.075, 0.11, 0.095),
                                    (0.46, 0.1, -0.04, 0.09)):
        fringe(yaw, 0.66, drop, sweep, width, 0)
    # Secondary clumps between and on top of them.
    for k in range(8):
        yaw = -0.7 + k * 0.19 + rng.uniform(-0.04, 0.04)
        fringe(yaw, 0.69, rng.uniform(0.05, 0.1), rng.uniform(0.06, 0.14) * (1 if yaw < 0.35 else -0.6),
               rng.uniform(0.05, 0.066), 1, lift=0.055)
    # Tertiary: thin sharp flicks, a couple sticking up out of the opening,
    # and single strands falling over the forehead.
    for yaw, drop, sweep, flick in ((-0.46, 0.06, 0.12, 0.028), (-0.05, 0.08, -0.06, 0.012), (0.36, 0.07, -0.1, 0.018),
                                    (-0.3, 0.13, 0.08, 0.0), (0.02, 0.12, 0.1, 0.0), (0.28, 0.12, 0.06, 0.0),
                                    (0.62, 0.12, -0.08, 0.0), (-0.72, 0.13, 0.05, 0.01), (0.74, 0.1, -0.04, 0.015)):
        fringe(yaw, 0.7, drop, sweep, rng.uniform(0.022, 0.032), 2, lift=0.05, up_flick=flick)
    # Sides over the ears: layered sharp tufts flicking out at the tips.
    for side in (-1, 1):
        out = Vector((side, 0, 0))
        for k, yaw in enumerate((1.25, 1.45, 1.65, 1.85, 2.05, 2.25)):
            root, n = HEAD.point(side * yaw, 0.36 + 0.04 * (k % 2), -0.01)
            back = Vector((0, 1, 0)) * (0.02 + 0.03 * (yaw - 1.25))
            length = rng.uniform(0.09, 0.14)
            clump(parts, root, n, [root - U * length * 0.4 + out * 0.03,
                                   root - U * length * 0.85 + out * 0.045 + back,
                                   root - U * length + out * (0.07 + 0.03 * (k % 2)) + back * 1.5],
                  rng.uniform(0.045, 0.065), thickness=0.4, sharp=True, twist=side * 0.3, tier=1 + k % 2)
    # Nape: uneven tufts under the cap, alternating directions.
    for k, yaw in enumerate((2.4, 2.65, 2.9, 3.14, 3.38, 3.63, 3.88)):
        root, n = HEAD.point(yaw, 0.1, -0.01)
        outv = (root - c)
        outv.z = 0
        outv.normalize()
        sidev = Vector((-outv.y, outv.x, 0)) * (0.03 if k % 2 else -0.03)
        length = rng.uniform(0.12, 0.18)
        clump(parts, root, n, [root - U * length * 0.5 + outv * 0.02, root - U * length * 0.85 + outv * 0.05 + sidev,
                               root - U * length + outv * 0.1 + sidev * 1.6], rng.uniform(0.05, 0.075), thickness=0.4,
              sharp=True, tier=k % 3)

    # Backwards cap: snug crown, cut higher at the front.
    cap_c = c + Vector((0, 0.018, 0.02))
    cr = (r.x + 0.042, r.y + 0.042, r.z + 0.03)
    dome = chibi.ellipsoid(cap_c, cr, name="cap", segs=(40, 24))
    normal = Vector((0, 0.42 / cr[1], 1 / cr[2])).normalized()
    bm = bmesh.new()
    bm.from_mesh(dome.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                           plane_co=cap_c + Vector((0, 0, 0.26 * cr[2])), plane_no=normal, clear_inner=True)
    bm.to_mesh(dome.data)
    bm.free()
    mod = dome.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.025
    common.apply_all_modifiers(dome)
    common.shade_smooth(dome)

    def cap_colour(pos, normal):
        rel = pos - cap_c
        a = math.atan2(rel.x, rel.y)
        if abs(((a / (math.tau / 6)) % 1.0) - 0.5) > 0.465 and rel.z > 0.08:
            return CAP_SEAM
        # Painted top light on the crown.
        return common.lerp(CAP, (0.3, 0.38, 0.62), max(0.0, normal.z - 0.6) * 0.8)
    common.color_by(dome, cap_colour, smooth=False)
    parts.append(dome)
    button = chibi.ellipsoid(cap_c + Vector((0, 0, cr[2])), (0.03, 0.03, 0.016), name="button", segs=(12, 8))
    common.set_color(button, CAP_SEAM)
    parts.append(button)
    # Big curved brim sticking out behind, tilted down a little.
    brim = chibi.ellipsoid((0, 0, 0), (0.23, 0.2, 0.018), name="brim", segs=(32, 10))
    for v in brim.data.vertices:
        v.co.z -= (v.co.x ** 2) * 1.6  # strong LoL curve
    brim.data.transform(Matrix.Translation(cap_c + Vector((0, cr[1] - 0.02, -0.03)))
                        @ Matrix.Rotation(math.radians(-12), 4, "X"))

    def brim_colour(pos, normal):
        if normal.z < -0.3:
            return camo(pos, normal)
        return common.lerp(CAP, (0.3, 0.38, 0.62), max(0.0, normal.z - 0.5))
    common.color_by(brim, brim_colour, smooth=False)
    parts.append(brim)
    # Snapback strap across the front opening, under the quiff.
    strap_root, sn = HEAD.point(0, 0.64, 0.03)
    strap = chibi.box((0.12, 0.018, 0.025), (0, 0, 0), bevel=0.006, name="snap")
    strap.data.transform(Matrix.Translation(strap_root) @ sn.to_track_quat("Y", "Z").to_matrix().to_4x4())
    common.set_color(strap, CAP_SEAM)
    # Push the whole cap back on his head so the quiff can burst out.
    pivot = c + Vector((0, r.y * 0.8, 0.0))
    tilt = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(-6), 4, "X") @ Matrix.Translation(-pivot)
    for obj in (dome, button, brim, strap):
        obj.data.transform(tilt)
    parts.append(strap)
    return parts


def ears():
    # Ears that stick out a little (the art), angled back.
    return [head_sculpt.ear(HEAD, side, yaw=1.5, pitch=-0.13, size=1.12, tilt=0.5, colour=SKIN, shade=SKIN_SHADE)
            for side in (-1, 1)]


def head_piece():
    face_paint.paint_face(FACE, FACE_PNG)
    head = head_loft.build_head(HEAD, FACE, LOFT, SKIN, SKIN_SHADE, BLUSH)
    chibi.face_uv(head, HEAD, FACE)
    ear_parts = ears()
    for part in ear_parts:
        chibi.no_face_uv(part)
    hair = hair_and_cap()
    chibi.report([head] + ear_parts + hair)
    # Separate textures: the face gets most of the head's texels.
    hair_obj = common.join(hair, "Leo_Hair")
    chibi.decimate_tris(hair_obj, 24000)
    return common.join([head] + ear_parts, "Leo_Head"), hair_obj


# ----------------------------------------------------------------- gear

def backpack():
    """A layered camo hiking pack (the art): a canvas bag with sculpted
    wrinkles, an overhanging top flap, a front pocket with its own flap and
    buckle strap, side pockets, compression straps with buckles, a haul
    loop, the navy bedroll cinched on top (overhanging his left), a steel
    bottle on his left and the rope on a red carabiner on his right."""
    parts = []
    bag = chibi.fuse([chibi.box((0.52, 0.28, 0.6), (0, 0.41, 0.94), bevel=0.1, name="pack", segments=4),
                      chibi.ellipsoid((0, 0.47, 0.8), (0.25, 0.14, 0.2), name="sag")], "pack", voxel=0.008,
                     faces=6000)
    chibi.fold(bag, (0, 0.55, 0.95), (0.3, 0.2, 0.36), 0.006, wavelength=0.07, across=(0.3, 0, 1), twist=1.2, seed=41)
    common.color_by(bag, camo)
    parts.append(bag)
    flap = chibi.box((0.56, 0.33, 0.07), (0, 0.42, 1.235), bevel=0.028, name="flap", segments=3)
    for v in flap.data.vertices:
        # Sag over the front edge and droop at the corners.
        front = max(0.0, (v.co.y - 0.45) / 0.14)
        v.co.z -= 0.09 * front ** 2 + 0.03 * front * (abs(v.co.x) / 0.28) ** 2
    common.color_by(flap, lambda p, n: common.lerp(camo(p, n), (0.08, 0.1, 0.05), 0.3))
    parts.append(flap)
    # Front pocket with its own flap and buckle strap.
    pocket = chibi.box((0.34, 0.09, 0.26), (0, 0.585, 0.83), bevel=0.035, name="pocket", segments=3)
    common.color_by(pocket, camo)
    parts.append(pocket)
    pflap = chibi.box((0.36, 0.1, 0.06), (0, 0.595, 0.95), bevel=0.02, name="pocketflap", segments=2)
    for v in pflap.data.vertices:
        v.co.z -= 0.03 * max(0.0, (v.co.y - 0.6) / 0.05) ** 2
    common.color_by(pflap, lambda p, n: common.lerp(camo(p, n), (0.08, 0.1, 0.05), 0.35))
    parts.append(pflap)
    # Side pockets.
    for sx in (-1, 1):
        side = chibi.box((0.07, 0.2, 0.24), (sx * 0.29, 0.42, 0.8), bevel=0.03, name="sidepocket", segments=2)
        common.color_by(side, camo)
        parts.append(side)
    # Compression straps down the front, each with a buckle, and the
    # pocket strap.
    for sx in (-0.12, 0.12):
        path = [Vector((sx, 0.47, 1.25)), Vector((sx, 0.555, 1.2)), Vector((sx, 0.64, 1.05)), Vector((sx, 0.645, 0.9)),
                Vector((sx, 0.64, 0.74))]
        st = chibi.webbing(path, [(0, 0, 1), (0, 0.6, 0.8), (0, 1, 0.1), (0, 1, 0), (0, 1, 0)], width=0.02,
                           thick=0.006, name="packstrap")
        common.set_color(st, STRAP)
        parts.append(st)
        parts.append(chibi.buckle((sx, 0.655, 1.0), (0, 1, 0), width=0.05, height=0.04, colour=METAL))
    haul = chibi.torus((0, 0.3, 1.27), 0.05, 0.011, name="haul", axis="Y", segs=(18, 6))
    for v in haul.data.vertices:
        v.co.z = max(v.co.z, 1.265)
    common.set_color(haul, STRAP)
    parts.append(haul)
    # Bedroll on top, overhanging his left side; cinched.
    roll_c = (0.05, 0.4, 1.38)
    parts.append(chibi.bedroll(roll_c, 0.7, 0.105, BEDROLL, STRAP))
    parts += chibi.bedroll_detail(roll_c, 0.7, 0.105, BEDROLL, STRAP, metal=METAL)
    # Steel bottle on his left: cap, neck ring, painted mountain logo.
    bc = Vector((0.33, 0.42, 0.84))
    bottle = chibi.cylinder(bc, 0.062, 0.25, name="bottle", bevel=0.02, segments=24)
    common.color_by(bottle, lambda p, n: (0.3, 0.32, 0.36) if 0.8 < p.z < 0.86 and n.x > 0.5 else STEEL,
                    smooth=False)
    parts.append(bottle)
    neck = chibi.cylinder(bc + Vector((0, 0, 0.14)), 0.035, 0.04, name="bottle", segments=16)
    common.set_color(neck, STEEL)
    cap = chibi.cylinder(bc + Vector((0, 0, 0.175)), 0.04, 0.035, name="bottle", bevel=0.008, segments=16)
    common.set_color(cap, (0.18, 0.18, 0.2))
    ring = chibi.torus(bc + Vector((0, 0, 0.2)), 0.02, 0.005, name="bottle", axis="Y", segs=(12, 5))
    common.set_color(ring, (0.18, 0.18, 0.2))
    parts += [neck, cap, ring]
    # Rope coil on his right, clipped with a red carabiner.
    parts += chibi.rope_coil((-0.34, 0.42, 0.82), 0.11, ROPE, loops=5, axis="X")
    clip = chibi.torus((-0.34, 0.37, 0.99), 0.04, 0.01, name="carabiner", axis="X", segs=(16, 6))
    for v in clip.data.vertices:
        v.co.z = 0.99 + (v.co.z - 0.99) * 1.5
    common.set_color(clip, RED)
    parts.append(clip)
    parts += chibi.straps(STRAP, top_y=0.22, front_y=-0.245, xs=(-0.15, 0.15), shoulder_z=1.235, bottom_z=0.74,
                          width=0.034, thick=0.01, metal=METAL)
    sternum = chibi.webbing([(-0.17, -0.252, 1.06), (0, -0.258, 1.06), (0.17, -0.252, 1.06)],
                            [(0, -1, 0)] * 3, width=0.012, thick=0.006, name="sternum")
    common.set_color(sternum, STRAP)
    parts.append(sternum)
    parts.append(chibi.buckle((0, -0.266, 1.06), (0, -1, 0), width=0.045, height=0.035, colour=METAL))
    return parts


def stick(rig, down):
    """Knotty walking stick in the handslot.r frame: local +X points down
    in the idle pose; `down` is the hand's height, so it reaches the
    ground. A hand-carved faceted shaft (flat-shaded planes), knots and a
    snapped-off spur, a carved knob, a twine helix grip and two leafy
    twigs with folded leaves."""
    to_world = chibi.bone_frame(rig, "handslot.r")
    top = 0.55
    pts, radii = [], []
    for k in range(15):
        t = k / 14
        x = -top + t * (top + down)
        wob = Vector((0, noise.noise(Vector((t * 4, 1, 0))) * 0.035, noise.noise(Vector((t * 4, 5, 0))) * 0.035))
        pts.append(Vector((x, 0, 0)) + wob)
        radii.append(0.036 - t * 0.011)
    shaft = chibi.limb(pts, radii, up=(0, 0, 1), name="stick", ring=7)
    for poly in shaft.data.polygons:
        poly.use_smooth = False     # whittled planes
    parts = [shaft]
    for k, (i, ang) in enumerate(((3, 0.5), (6, 2.4), (9, 4.1), (12, 1.2))):
        q = pts[i] + Vector((0, math.cos(ang), math.sin(ang))) * radii[i] * 0.85
        parts.append(chibi.ellipsoid(q, (0.02, 0.014, 0.014), name="knot", segs=(10, 6)))
    knob = chibi.ellipsoid(pts[0] + Vector((-0.045, 0, 0)), (0.075, 0.056, 0.056), name="knob", segs=(9, 7))
    for poly in knob.data.polygons:
        poly.use_smooth = False
    parts.append(knob)
    parts.append(chibi.curved_lock(pts[3], (-0.5, 0.7, 0.2), 0.12, 0.018, name="spur"))
    body = common.join(parts, "stick")
    common.color_by(body, lambda p, n: BARK_LIGHT if noise.noise(Vector((p.x * 30, p.y * 4, p.z * 4))) > 0.15
                    else (common.lerp(BARK, (0.1, 0.06, 0.03), 0.3) if noise.noise(p * 50) > 0.3 else BARK),
                    smooth=False)
    parts = [body]
    # Twine wound as a real helix around the grip.
    helix = [Vector((-0.11 + 0.22 * i / 60, 0.042 * math.cos(i * 0.9), 0.042 * math.sin(i * 0.9))) for i in range(61)]
    twine = chibi.tube(helix, [0.009] * len(helix), name="twine", levels=0)
    common.color_by(twine, lambda p, n: ROPE if noise.noise(p * 80) > -0.2 else common.lerp(ROPE, (0.3, 0.2, 0.1), 0.4))
    parts.append(twine)
    for end in (-0.12, 0.12):
        knot = chibi.torus((end, 0, 0), 0.043, 0.012, name="twine", axis="X", segs=(14, 6))
        common.set_color(knot, common.lerp(ROPE, (0.3, 0.2, 0.1), 0.3))
        parts.append(knot)
    # Leafy twigs with leaves folded along the midrib.
    for x, ang, twig_dir in ((pts[1].x, 0.6, (0.3, 0.8, 0.4)), (pts[3].x + 0.02, -0.9, (0.2, -0.7, 0.5))):
        root = Vector((x, 0, 0))
        twig = chibi.curved_lock(root, twig_dir, 0.08, 0.008, name="twig")
        common.set_color(twig, BARK)
        parts.append(twig)
        tip = root + Vector(twig_dir).normalized() * 0.08
        for k, spread in enumerate((-0.5, 0.4)):
            leaf = chibi.ellipsoid((0, 0.05, 0), (0.024, 0.055, 0.005), name="leaf", segs=(12, 6))
            for v in leaf.data.vertices:
                v.co.z += abs(v.co.x) * 0.45            # fold along the midrib
                v.co.z += (v.co.y / 0.1) ** 2 * 0.02     # droop to the tip
            leaf.data.transform(Matrix.Translation(tip) @ Matrix.Rotation(ang + spread, 4, "X")
                                @ Matrix.Rotation(spread, 4, "Z"))
            common.color_by(leaf, lambda p, n: LEAF if abs(p.x - tip.x) > 0.003 else common.lerp(LEAF, (1, 1, 0.6), 0.3))
            parts.append(leaf)
    obj = common.join(parts, "Leo_Stick")
    obj.data.transform(to_world)
    return obj


def build():
    rig = chibi.load_rig()
    soft = [skin_piece(), shirt_piece(), shorts_piece()]
    rigid = hands_and_feet()
    rigid.append((badge(), "chest"))
    for part in chibi.compass((0, -0.228, 0.98), GOLD, neck_z=1.22, radius=0.042, lid=True):
        rigid.append((part, "chest"))
    rigid += cargo_pockets()
    pack_c = Vector((0, 0.37, 1.0))
    for part in backpack():
        # Hug the leaner back and shrink a little so the silhouette reads.
        part.data.transform(Matrix.Translation(pack_c + Vector((0, -0.03, 0))) @ Matrix.Scale(0.85, 4)
                            @ Matrix.Translation(-pack_c))
        rigid.append((part, "chest"))
    collar = chibi.torus((0, 0, 1.2), 0.09, 0.022, name="collar")
    common.set_color(collar, TEE_DARK)
    rigid.append((collar, "chest"))
    head, hair = head_piece()
    PROP.stretch_rig(rig)
    body = chibi.finish(rig, soft, rigid, "Leo", prop=PROP)
    PROP.stretch_mesh(head)
    PROP.stretch_mesh(hair)
    walking_stick = stick(rig, chibi.idle_hand_height(rig))
    for obj, bone in ((head, "head"), (hair, "head"), (walking_stick, "hand.r")):
        chibi.rigid(obj, bone)
        obj.parent = rig
        obj.modifiers.new("Armature", "ARMATURE").object = rig

    meshes = [body, head, hair, walking_stick]
    # Game budget (~35k): each mesh is decimated; its dense copy carries
    # the paint and is baked onto it (HIGH_POLY=1 keeps the dense meshes).
    highs = {}
    if not os.environ.get("HIGH_POLY"):
        chibi.report(meshes)
        budget = {body: 20000, head: 4500, hair: 9000, walking_stick: 1500}
        highs = {mesh: chibi.lowpoly(mesh, tris) for mesh, tris in budget.items()}

    if os.environ.get("SCULPT"):
        print("leo tris:", common.triangle_count(meshes))
        sculpt_previews(rig, meshes, "leo", ("Running_A", 8), ("1H_Melee_Attack_Chop", 14))
        return
    if chibi.quick_mode():
        for mesh in meshes:
            chibi.quick_material(mesh, overlay=(FACE_PNG, "FaceUV") if mesh is head else None)
        print("leo tris:", common.triangle_count(meshes))
        render_previews(rig, meshes, head, "leo", ("Running_A", 8), ("1H_Melee_Attack_Chop", 14), ("PickUp", 12), ("Death_A", 40))
        return
    params = dict(size=2048, ao_distance=0.18, ao_strength=0.65, edge_strength=0.3, edge_radius=0.012,
                  noise_scale=6.0, stroke_strength=0.08, light=(1.12, 1.04, 0.94), shadow=(0.42, 0.36, 0.55),
                  foot_darken=0.4, foot_height=1.1, key_light=(-0.4, -0.6, 0.8), key_strength=0.55,
                  curvature_tint=((0.72, 0.55, 0.5), (1.1, 1.08, 1.12), 0.85))
    for mesh in meshes:
        # Softer occlusion and a warm shadow tint on the head: the face keeps
        # the art's warm, bright skin instead of going violet-grey.
        extra = dict(ao_strength=0.45, ao_distance=0.05, overlay=(FACE_PNG, "FaceUV"), cavity=0.3,
                     shadow=(0.84, 0.58, 0.5), light=(1.12, 1.03, 0.94), key_strength=0.35,
                     curvature_tint=((0.9, 0.7, 0.64), (1.05, 1.03, 1.02), 0.45)) \
            if mesh is head else dict(cavity=0.3)
        paint_bake.paint(mesh, source="attribute", high=highs.get(mesh), **dict(params, **extra))
    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "leo.glb"), [rig] + meshes, animations=True, image_format="WEBP")
    print("leo tris:", common.triangle_count(meshes))
    render_previews(rig, meshes, head, "leo", ("Running_A", 8), ("1H_Melee_Attack_Chop", 14))


def sculpt_previews(rig, meshes, name, *actions):
    """SCULPT=1: clay views of the Idle pose, silhouettes at game size and
    clay animation frames, for judging forms without paint."""
    rig.data.pose_position = "POSE"
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions.get("Idle")
    bpy.context.scene.frame_set(1)
    preview.render_clay(meshes, name, size=720)
    preview.render_silhouette(meshes, name)
    for action_name, frame in actions:
        rig.animation_data.action = bpy.data.actions.get(action_name)
        preview.render_clay(meshes, name + "_" + action_name, views=(("34", 30, 8),), size=480, frame=frame)


def render_previews(rig, meshes, head, name, *actions):
    rig.data.pose_position = "REST"
    preview.render(meshes, name, elevation=10, azimuth=25)
    preview.render([head], name + "_face", elevation=4, azimuth=12, size=512)
    preview.render(meshes, name + "_back", elevation=15, azimuth=160, size=384)
    rig.data.pose_position = "POSE"
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions.get("Idle")
    preview.render(meshes, name + "_front", frame=1, elevation=6, azimuth=15, size=768)
    rig.data.pose_position = "REST"
    rig.data.pose_position = "POSE"
    rig.animation_data_create()
    for action_name, frame in (("Idle", 1),) + actions:
        rig.animation_data.action = bpy.data.actions.get(action_name)
        preview.render(meshes, name + "_" + action_name, frame=frame, elevation=10, azimuth=25, size=384)


if __name__ == "__main__":
    build()
