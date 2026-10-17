"""Mum, the forest ranger (feature 043). Modelled from the team's
character sheet (art/reference/concept-2026-10/14_mum_character_sheet.webp):
a grown-up with long wavy golden-blond hair gathered in a loose low bun,
loose locks framing her face and falling over her shoulders, blue eyes,
freckles and a warm smile; a lime-green ranger jacket with the sleeves
rolled up over a black long-sleeved top, a mountain badge on her left
sleeve, chest pockets and a leather belt; a tan scarf; charcoal cargo
trousers; brown hiking boots with red laces; an olive backpack with a
blue bedroll, a tin mug on a red carabiner, and a brass compass.
(The beagle on the sheet is not part of the game.)

Built on the same KayKit adventurer rig as Leo and Nela, so all 76
clips work, plus a hand-keyed Wave. She is an adult: much longer legs,
torso and arms (Proportions) and a smaller head (built at the kids'
scale, then scaled by HEAD_SCALE).
Output: mum.glb"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

from lib import common, paint_bake  # noqa: E402
from characters import chibi, face_paint, head_loft, rig_anims  # noqa: E402
from characters.leo import render_previews, sculpt_previews  # noqa: E402

SKIN = (0.98, 0.74, 0.6)
SKIN_SHADE = (0.86, 0.52, 0.42)
BLUSH = (0.98, 0.52, 0.46)
HAIR_LIGHT = (1.0, 0.9, 0.6)
HAIR = (0.92, 0.72, 0.36)
HAIR_DARK = (0.58, 0.38, 0.16)
JACKET = (0.78, 0.82, 0.2)
JACKET_DARK = (0.5, 0.56, 0.12)
TOP = (0.13, 0.13, 0.15)
TOP_LIGHT = (0.26, 0.26, 0.29)
SCARF = (0.78, 0.67, 0.52)
SCARF_DARK = (0.56, 0.45, 0.33)
TROUSERS = (0.27, 0.23, 0.21)
TROUSERS_DARK = (0.15, 0.12, 0.11)
BOOT = (0.52, 0.34, 0.2)
BOOT_TOE = (0.62, 0.44, 0.28)
SOLE = (0.2, 0.14, 0.1)
LACE = (0.86, 0.24, 0.16)
MUD = (0.3, 0.22, 0.14)
LEATHER = (0.42, 0.25, 0.12)
BRASS = (0.86, 0.66, 0.3)
GOLD = (0.92, 0.7, 0.28)
PACK = (0.38, 0.4, 0.2)
PACK_DARK = (0.22, 0.24, 0.11)
BEDROLL = (0.2, 0.34, 0.66)
TIN = (0.62, 0.62, 0.6)
TIN_DARK = (0.34, 0.34, 0.33)
CARABINER = (0.84, 0.2, 0.14)
BADGE = (0.3, 0.3, 0.32)
BADGE_MARK = (0.86, 0.84, 0.78)

# Solved against the sheet's front turnaround (feature 043, third pass;
# art/lib/measure.py): in fractions of her height, head 0.17 (about 5.8
# heads tall, a stylised build - not a realistic 7.5), chin 0.83,
# shoulders 0.75, belt 0.55, crotch 0.47, knees 0.27; shoulders 0.25 and
# hips 0.21 wide, each thigh 0.1.
PROP = chibi.Proportions(legs=3.1, spine=0.92, arms=1.4, shins=3.7)
# The head is built at the kids' scale around HEAD (so the face kit's
# numbers fit), then scaled about its centre and set down onto the neck.
HEAD = chibi.HeadFrame((0, -0.01, 1.515), (0.215, 0.235, 0.25))
HEAD_SCALE = 0.9
HEAD_DROP = -0.06
FACE_PNG = os.path.join(common.ROOT, "build", "art_faces", "mum_face.png")
# From the sheet: a grown-up's face - the eyes higher and smaller than
# the kids', bright blue with a dark lash line, soft gold brows, a small
# straight nose, freckles over the nose and cheeks, and a warm closed-
# mouth smile with a hint of teeth.
FACE = face_paint.FaceLayout(
    size=0.32, eye_x=0.084, eye_z=-0.04, eye_w=0.05, eye_h=0.036, eye_tilt=0.05, lid=0.1, iris_r=0.03,
    look=(0.009, 0.004), iris=(0.36, 0.62, 0.95), iris_dark=(0.05, 0.16, 0.42), lash=(0.16, 0.08, 0.05),
    lash_width=0.01, wing=0.008, lower_lash=0.3, eyeshadow_alpha=0.08, socket=(0.82, 0.55, 0.48),
    socket_alpha=0.28, lid_fold=0.5, nose_shadow=0.16, nostril_alpha=0.25,
    brows=((0.036, 0.06, 0.014, 0.013), (0.036, 0.06, 0.014, 0.013)),
    brow_len=0.062, brow_colour=(0.58, 0.36, 0.15), brow_alpha=0.95, nose_z=-0.1, nose_w=0.015,
    mouth_z=-0.146, mouth_w=0.062, smile=9.0, smirk=0.0, open_mouth=0.011, lip_upper=0.003, lip_lower=0.008,
    lip_colour=(0.86, 0.46, 0.44), lip_dark=(0.5, 0.18, 0.18), tongue=(0.84, 0.38, 0.4), chin_z=-0.228,
    skin_shadow=(0.8, 0.48, 0.4), light_colour=(1.0, 0.9, 0.8), blush=(0.98, 0.44, 0.4), blush_alpha=0.58,
    blush_pos=(0.118, -0.1), contour=0.12, plane_light=1.0, face_half_w=0.2, catch2=0.8, flush_alpha=0.2,
    highlight=(1.0, 0.93, 0.87), freckle_colour=(0.7, 0.42, 0.3),
    freckles=[(sx * x, z) for sx in (-1, 1) for x, z in ((0.03, -0.085), (0.06, -0.095), (0.085, -0.1),
                                                          (0.105, -0.09), (0.095, -0.115), (0.125, -0.105),
                                                          (0.07, -0.115))])
# Nela's drawn head, made a grown-up oval: narrower, longer, a longer
# lower face and a defined chin.
_NELA_SECTIONS = ((0.235, 0.02, -0.02, 0.02, 2.0, 2.0), (0.222, 0.11, -0.11, 0.13, 2.0, 2.0),
                  (0.19, 0.175, -0.175, 0.195, 2.0, 2.0), (0.14, 0.215, -0.218, 0.232, 2.1, 2.05),
                  (0.09, 0.232, -0.238, 0.244, 2.2, 2.1), (0.04, 0.238, -0.246, 0.24, 2.3, 2.1),
                  (0.0, 0.236, -0.248, 0.23, 2.35, 2.15), (-0.04, 0.23, -0.245, 0.215, 2.4, 2.2),
                  (-0.08, 0.218, -0.243, 0.195, 2.4, 2.2), (-0.12, 0.196, -0.238, 0.165, 2.4, 2.2),
                  (-0.155, 0.16, -0.228, 0.13, 2.4, 2.2), (-0.185, 0.112, -0.215, 0.095, 2.35, 2.15),
                  (-0.205, 0.066, -0.2, 0.06, 2.2, 2.1), (-0.22, 0.03, -0.165, 0.03, 2.1, 2.0))
LOFT = head_loft.HeadLoft(
    sections=tuple((z * (1.05 if z > 0 else 1.06), w * (0.9 if z > -0.12 else 0.88), f * 0.97, b * 0.94, sf, sb)
                   for z, w, f, b, sf, sb in _NELA_SECTIONS),
    nose_top=-0.06, nose_tip_z=-0.098, nose_base_z=-0.11, nose_h=0.018, nose_bridge_h=0.003,
    nose_w=(0.004, 0.009), nose_side=0.011, alae=0.003, cheek=0.006, cheek_pos=(0.105, -0.1),
    eye_inset=0.004, eye_plate=(1.2, 1.5), brow_shelf=0.004,
    upper_lip=0.003, lower_lip=0.004, chin=0.005, rings=90)

F, R, U = Vector((0, -1, 0)), Vector((-1, 0, 0)), Vector((0, 0, 1))  # forward, her right, up


# ---------------------------------------------------------------- body

def skin_piece():
    """Only the neck shows (the top's sleeves and the trousers cover the
    rest); slim adult arms inside help the auto-weights. No legs: they
    poked through the trousers when she sits or kneels."""
    parts = [chibi.limb([(0, 0.0, 1.08), (0, 0.004, 1.25), (0, 0.006, 1.38)],
                        [(0.07, 0.066), (0.062, 0.06), (0.06, 0.058)], up=(0, -1, 0), name="neck")]
    for s in (-1, 1):
        xs = (0.24, 0.34, 0.45, 0.55, 0.65, 0.74, 0.78)
        rr = ((0.06, 0.062), (0.056, 0.056), (0.05, 0.05), (0.048, 0.046), (0.044, 0.04), (0.038, 0.034),
              (0.036, 0.032))
        parts.append(chibi.limb([(s * x, 0, 1.107) for x in xs], rr, up=(0, 0, 1), name="arm"))
    body = chibi.fuse(parts, "Skin", voxel=0.008, faces=6000)
    common.color_by(body, lambda p, n: common.lerp(SKIN, SKIN_SHADE, max(0.0, -n.z * 0.5)))
    return body


def badge(pos, normal):
    """The grey mountain badge on her left sleeve (the sheet). None off it."""
    if pos.x < 0.3 or pos.x > 0.42 or normal.x < 0.0 and normal.z < 0.3:
        return None
    u, v = pos.x - 0.36, pos.z - 1.135
    if abs(u) > 0.04 or abs(v) > 0.04 or pos.z < 1.09:
        return None
    # A white triangle (the mountain) on the dark patch.
    if v < 0.02 and v > -0.025 and abs(u) < (0.02 - v) * 0.8:
        return BADGE_MARK
    return BADGE


def jacket_piece():
    """The ranger jacket and the black top under it, as one soft piece:
    the jacket open at the front over the top, short (rolled) lime
    sleeves to the elbow with the top's black sleeves to the wrist, a hem
    over the hips."""
    parts = [
        chibi.ellipsoid((0, 0, 1.0), (0.235, 0.205, 0.17), name="chest"),
        chibi.ellipsoid((0, -0.06, 0.96), (0.19, 0.14, 0.09), name="bust"),
        chibi.ellipsoid((0, 0, 0.8), (0.185, 0.145, 0.17), name="waist"),
        chibi.ellipsoid((0, 0, 0.63), (0.25, 0.18, 0.12), name="hipline"),
    ]
    for s in (-1, 1):
        # One sleeve along the whole arm: jacket to the elbow, top beyond.
        parts.append(chibi.limb([(s * 0.12, 0, 1.11), (s * 0.3, 0, 1.108), (s * 0.48, 0, 1.107),
                                 (s * 0.64, 0, 1.107), (s * 0.76, 0, 1.107)],
                                [(0.098, 0.098), (0.09, 0.09), (0.082, 0.08), (0.062, 0.06), (0.05, 0.048)],
                                up=(0, 0, 1), name="sleeve"))
        parts.append(chibi.ellipsoid((s * 0.23, 0.0, 1.12), (0.09, 0.1, 0.075), name="deltoid", segs=(16, 12)))
        # The rolled-up jacket cuff just above the elbow.
        parts.append(chibi.hem_ring((s * 0.53, 0, 1.107), (0.084, 0.082), 0.024, name="roll", axis="X"))
        parts.append(chibi.hem_ring((s * 0.755, 0, 1.107), (0.047, 0.045), 0.008, name="cuff", axis="X"))
    # Jacket skirt to the hips, with a hem.
    parts.append(chibi.limb([(0, 0, 0.66), (0, 0, 0.58), (0, 0, 0.51)],
                            [(0.255, 0.185), (0.265, 0.19), (0.272, 0.196)], up=(0, -1, 0), name="skirt"))
    parts.append(chibi.hem_ring((0, 0, 0.51), (0.272, 0.196), 0.01, name="hem", axis="Z"))
    jacket = chibi.fuse(parts, "Jacket", voxel=0.0065, faces=26000)
    for s in (-1, 1):
        chibi.cut_open(jacket, (s * 0.772, 0, 0), (s, 0, 0))
    chibi.cut_open(jacket, (0, 0, 0.502), (0, 0, -1))
    for s in (-1, 1):
        chibi.fold(jacket, (s * 0.18, -0.06, 1.0), (0.12, 0.18, 0.14), 0.01, radial_axis=(0, 1, 0), count=5,
                   twist=0.4 * s, seed=61 + s)
        chibi.fold(jacket, (s * 0.6, 0, 1.107), (0.12, 0.1, 0.1), 0.007, wavelength=0.04, across=(1, 0, 0),
                   twist=0.6, seed=63 + s)
    chibi.fold(jacket, (0, -0.06, 0.74), (0.3, 0.22, 0.14), 0.009, wavelength=0.06, across=(0, 0, 1), twist=1.2,
               seed=65)

    def colour(pos, normal):
        mark = badge(pos, normal)
        if mark is not None:
            return mark
        ax = abs(pos.x)
        if ax > 0.555:
            # The top's black sleeve, with soft folds.
            return common.lerp(TOP, TOP_LIGHT, max(0.0, math.sin(ax * 70) * 0.35))
        if ax > 0.505:
            return common.lerp(JACKET, JACKET_DARK, 0.35)      # the rolled cuff
        # The open front: a strip of the black top down the middle, with
        # the jacket's zip edges either side.
        if pos.y < -0.05 and pos.z > 0.53:
            if ax < 0.068:
                return common.lerp(TOP, TOP_LIGHT, max(0.0, math.sin(pos.z * 90) * 0.25))
            if ax < 0.08:
                return JACKET_DARK                         # the zip edges
        if pos.z < 0.525:
            return JACKET_DARK                                 # hem band
        fold = math.sin(pos.x * 30 - pos.z * 22) * max(0.0, 0.95 - pos.z) * 1.6
        pit = math.exp(-((ax - 0.17) / 0.05) ** 2 - ((pos.z - 1.0) / 0.08) ** 2)
        c = common.lerp(JACKET, JACKET_DARK, max(0.0, min(0.5, fold * 0.45 + pit * 0.5)))
        return common.lerp(c, (0.88, 0.92, 0.5), max(0.0, min(0.25, -fold * 0.25)))
    common.color_by(jacket, colour)
    common.grime(jacket, MUD, lambda p, n: 0.0 if badge(p, n) else
                 max(0.0, noise.noise(p * 9.0 + Vector((2, 7, 1))) - 0.45) * 0.25)
    return jacket


def trousers_piece():
    """Charcoal cargo trousers, straight legs down into the boots."""
    parts = [chibi.ellipsoid((0, 0, 0.55), (0.235, 0.165, 0.11), name="hips")]
    for s in (-1, 1):
        # Tapering from the hip to the boot, in a slight A stance.
        parts.append(chibi.limb([(s * 0.12, 0, 0.56), (s * 0.145, -0.005, 0.42), (s * 0.155, 0.0, 0.3),
                                 (s * 0.155, 0.008, 0.22), (s * 0.155, 0.012, 0.13)],
                                [(0.122, 0.122), (0.112, 0.114), (0.094, 0.098), (0.084, 0.088), (0.082, 0.086)],
                                up=(0, -1, 0), name="leg"))
    parts.append(chibi.ellipsoid((0, 0.0, 0.47), (0.13, 0.13, 0.08), name="crotch"))
    trousers = chibi.fuse(parts, "Trousers", voxel=0.0095)
    chibi.cut_open(trousers, (0, 0, 0.14), (0, 0, -1))
    for s in (-1, 1):
        chibi.fold(trousers, (s * 0.13, -0.02, 0.33), (0.12, 0.14, 0.04), 0.009, wavelength=0.05,
                   across=(0, 0, 1), twist=0.8 * s, seed=71 + s)
        chibi.fold(trousers, (s * 0.13, 0.01, 0.22), (0.1, 0.1, 0.04), 0.01, radial_axis=(0, 0, 1), count=8,
                   seed=73 + s)
    chibi.fold(trousers, (0, -0.1, 0.48), (0.14, 0.18, 0.08), 0.008, radial_axis=(0, 1, 0), count=4, seed=75)

    def colour(pos, normal):
        seam = abs(abs(pos.x) - 0.15) > 0.105 and abs(normal.x) > 0.8
        fold = max(0.0, math.sin(pos.z * 60 + pos.x * 8)) * max(0.0, 0.38 - pos.z) * 3
        c = common.lerp(TROUSERS, TROUSERS_DARK, min(0.5, fold * 0.5))
        return common.lerp(c, TROUSERS_DARK, 0.4) if seam else c
    common.color_by(trousers, colour, smooth=False)
    common.grime(trousers, MUD, lambda p, n: max(0.0, (0.3 - p.z) / 0.15) * 0.4 +
                 max(0.0, noise.noise(p * 12.0) - 0.4) * 0.6)
    return trousers


def pockets_and_belt():
    """Rigid details: cargo pockets on both thighs, chest pockets with
    flaps, the leather belt and buckle, and the black collar of the top."""
    parts = []
    for s, bone in ((1, "upperleg.l"), (-1, "upperleg.r")):
        # Short in rest space: the leg stretch (x3.1) makes it a tall pocket.
        pocket = chibi.box((0.032, 0.12, 0.055), (s * 0.262, -0.005, 0.4), bevel=0.01, name="cargo")
        common.color_by(pocket, lambda p, n: TROUSERS_DARK if p.z > 0.416 else TROUSERS, smooth=False)
        parts.append((pocket, bone))
        snap = chibi.cylinder((s * 0.28, -0.005, 0.418), 0.009, 0.006, name="snap", axis="X", segments=8)
        common.set_color(snap, BRASS)
        parts.append((snap, bone))
    for s in (-1, 1):
        flap = chibi.box((0.11, 0.02, 0.05), (s * 0.12, -0.195, 1.02), bevel=0.01, name="chestpocket")
        common.color_by(flap, lambda p, n: JACKET_DARK if p.z > 1.03 else JACKET, smooth=False)
        parts.append((flap, "chest"))
        button = chibi.cylinder((s * 0.12, -0.208, 1.035), 0.008, 0.006, name="button", axis="Y", segments=8)
        common.set_color(button, BRASS)
        parts.append((button, "chest"))
    belt = chibi.torus((0, 0, 0.62), 0.252, 0.017, name="belt", segs=(40, 6))
    for v in belt.data.vertices:
        v.co.y *= 0.8
    common.color_by(belt, lambda p, n: common.lerp(LEATHER, (0.1, 0.05, 0.02), 0.25 if int(p.x * 40) % 2 else 0.0),
                    smooth=False)
    parts.append((belt, "hips"))
    parts.append((chibi.buckle((0, -0.21, 0.62), (0, -1, 0), width=0.06, height=0.045, colour=BRASS), "hips"))
    collar = chibi.torus((0, 0, 1.2), 0.07, 0.014, name="collar")
    common.set_color(collar, TOP)
    parts.append((collar, "chest"))
    # The jacket's turned-down collar, open at the front under the scarf.
    lapel = chibi.torus((0, 0.015, 1.165), 0.135, 0.028, name="lapel", segs=(32, 8))
    for v in lapel.data.vertices:
        front = max(0.0, -v.co.y / 0.135)
        v.co.z -= 0.05 * front ** 2
    common.color_by(lapel, lambda p, n: JACKET_DARK if n.z < -0.2 else JACKET)
    parts.append((lapel, "chest"))
    return parts


def scarf_piece():
    """The tan scarf: a soft lumpy wrap round the neck with a short tail
    tucked down the front (the sheet)."""
    puffs = []
    # Wrapped twice, high up the neck to the jaw (on the sheet it hides
    # the neck completely).
    for ring_z, rx, ry, size in ((1.2, 0.1, 0.09, 1.0), (1.27, 0.085, 0.078, 0.9), (1.33, 0.075, 0.07, 0.75)):
        for k in range(12):
            a = k / 12 * math.tau + ring_z * 3.0
            puffs.append(chibi.ellipsoid((math.cos(a) * rx, math.sin(a) * ry, ring_z + 0.012 * math.sin(a * 2)),
                                         (0.066 * size, 0.06 * size, 0.05 * size), name="wrap", segs=(12, 8)))
    # A loose loop drooping at the front, and two tails hanging down.
    for k in range(6):
        t = k / 5
        puffs.append(chibi.ellipsoid((0.06 - 0.12 * t, -0.11 - 0.02 * math.sin(t * math.pi), 1.15 - 0.06 * math.sin(t * math.pi)),
                                     (0.05, 0.04, 0.045), name="loop", segs=(12, 8)))
    puffs.append(chibi.ellipsoid((0.04, -0.12, 1.07), (0.055, 0.03, 0.08), name="tail", segs=(12, 10)))
    puffs.append(chibi.ellipsoid((-0.02, -0.115, 1.03), (0.045, 0.026, 0.09), name="tail", segs=(12, 10)))
    scarf = chibi.fuse(puffs, "scarf", voxel=0.008, smooth=2, faces=3200)
    chibi.fold(scarf, (0, 0, 1.2), (0.16, 0.16, 0.06), 0.008, radial_axis=(0, 0, 1), count=12, seed=81)
    common.color_by(scarf, lambda p, n: common.lerp(SCARF, SCARF_DARK, max(0.0, -n.z) * 0.5 +
                                                    max(0.0, noise.noise(p * 12.0)) * 0.2))
    return scarf


def hands_and_feet():
    rigid = []
    for h, bone in chibi.hands(SKIN, sculpted=True, crease=SKIN_SHADE, size=0.86):
        rigid.append((h, bone))
    for s, bone in ((1, "foot.l"), (-1, "foot.r")):
        for part in chibi.sculpted_boot(s, BOOT, SOLE, BOOT_TOE, LACE, scale=1.22, height=0.78,
                                        collar=(0.32, 0.2, 0.1)):
            common.grime(part, MUD, lambda p, n: max(0.0, (0.1 - p.z) / 0.08) * 0.7 +
                         max(0.0, noise.noise(p * 26.0) - 0.3) * 0.8)
            for v in part.data.vertices:
                v.co.x -= s * 0.015         # under her trouser legs (x 0.155)
            rigid.append((part, bone))
    return rigid


# ----------------------------------------------------------------- head

def wavy(parts, root, up, controls, width, wave, side, thickness=0.42, steps=9, sharp=False, twist=0.0, tier=1,
          ring=8):
    """A wavy lock (as Nela's): the centreline wiggles as it falls.
    tier 0 = primary mass (darker roots), 1 = secondary, 2 = flyaway."""
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


def hair_cap():
    """A full, rounded hair mass over the crown and down the back and
    sides of the head (the sheet's hair has a lot of volume), open for
    the face."""
    c, r = HEAD.c, HEAD.r
    shell_r = (r.x + 0.05, r.y + 0.045, r.z + 0.04)
    shell = chibi.ellipsoid(c + Vector((0, 0.02, 0.015)), shell_r, name="hairshell", segs=(44, 30))
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    kill = []
    for v in bm.verts:
        d = v.co - c
        d = Vector((d.x / shell_r[0], d.y / shell_r[1], d.z / shell_r[2]))
        if not (d.z > 0.5 or (d.y > -0.35 and d.z > -0.3) or (d.y > 0.25 and d.z > -0.75)):
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(shell.data)
    bm.free()
    mod = shell.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.03
    common.apply_all_modifiers(shell)
    common.shade_smooth(shell)
    common.color_by(shell, chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, c, scale=5.0, strands=40))
    return shell


def bun_base():
    """A loose bun low on the back of her head (the sheet's turnaround)."""
    p, n = HEAD.point(math.pi, -0.25, 0.05)
    return p + Vector((0.0, 0.03, 0.0))


def low_bun():
    """The messy bun: a lumpy twist with loops, and wisps springing out."""
    parts = []
    base = bun_base()
    rng = random.Random(17)
    puffs = [chibi.ellipsoid(base + Vector(o), rad, name="bun", segs=(16, 10))
             for o, rad in (((0, 0.04, 0.0), (0.11, 0.09, 0.095)), ((0.06, 0.07, 0.035), (0.07, 0.06, 0.06)),
                            ((-0.06, 0.06, -0.025), (0.07, 0.06, 0.06)), ((0.0, 0.1, 0.03), (0.06, 0.055, 0.055)),
                            ((0.03, 0.05, -0.07), (0.055, 0.05, 0.05)))]
    bun = chibi.fuse(puffs, "bun", voxel=0.01, smooth=2, faces=2000)
    common.color_by(bun, chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, base, scale=12.0, strands=22))
    parts.append(bun)
    # Loops of hair wrapped round the bun.
    for k in range(0):
        a = k / 5 * math.tau + 0.4
        root = base + Vector((math.cos(a) * 0.08, 0.06, math.sin(a) * 0.08))
        side = Vector((-math.sin(a), 0, math.cos(a)))
        wavy(parts, root, Vector((0, 1, 0)), [root + side * 0.06 + Vector((0, 0.04, 0)),
                                              root + side * 0.11 - Vector((math.cos(a), 0, math.sin(a))) * 0.03,
                                              root + side * 0.13 - Vector((math.cos(a), 0, math.sin(a))) * 0.08],
             0.035, 0.005, Vector((0, 1, 0)), thickness=0.45, steps=7, tier=0)
    for k in range(6):
        a = k / 6 * math.tau + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(a), 0.35, math.sin(a))).normalized()
        root = base + Vector((0, 0.07, 0)) + out * 0.06
        side = out.cross(F).normalized()
        L = rng.uniform(0.06, 0.11)
        wavy(parts, root, side, [root + out * L * 0.5, root + out * L * 0.9 - U * 0.03,
                                 root + out * L - U * 0.09 + side * 0.03],
             rng.uniform(0.012, 0.02), 0.014, side, thickness=0.3, steps=7, sharp=True, tier=2)
    return parts


def hair():
    """Long wavy golden hair as on the sheet: swept back from a side
    parting over a full crown into a loose low bun; soft side-swept
    bangs; lots of wavy locks falling round the sides and back to the
    shoulders, the front ones framing her cheeks and curling out at the
    jaw; flyaways all round."""
    parts = [hair_cap()]
    rng = random.Random(5)
    base = bun_base()

    def pulled(yaw, pitch, width, tier, lift=0.01):
        """A lock from the hairline lying along the skull back to the bun."""
        root, n = HEAD.point(yaw, pitch, lift)
        mids = []
        for t in (0.35, 0.7):
            q, qn = HEAD.point(yaw * (1 - t) + math.copysign(math.pi, yaw) * t, pitch * (1 - t) - 0.2 * t,
                               lift + 0.025 + 0.02 * math.sin(t * math.pi))
            mids.append(q)
        side = (mids[0] - root).cross(n).normalized()
        wavy(parts, root, n, mids + [base + (root - base).normalized() * 0.06], width, 0.008, side,
             thickness=(0.4, 0.34, 0.3)[tier], steps=10, sharp=tier > 0, twist=rng.uniform(-0.3, 0.3), tier=tier,
             ring=10 if tier == 0 else 8)

    for k in range(16):
        yaw = -math.pi + (k + 0.5) / 16 * math.tau
        if abs(yaw) < 0.95:
            continue
        pulled(yaw, 0.3 + 0.12 * (k % 3), 0.075, 0, lift=0.03)
    for k in range(26):
        yaw = rng.choice((-1, 1)) * rng.uniform(1.1, 2.9)
        pulled(yaw, rng.uniform(0.2, 0.6), rng.uniform(0.035, 0.05), 1, lift=0.035)

    # Side-swept bangs: from a parting over her left eye, sweeping across
    # the forehead to her right and down past the temple.
    # Each lock is draped over the head surface: parting -> forehead -> temple.
    for k, (yaw0, yaw1, pitch1, width) in enumerate(((0.36, -0.2, 0.55, 0.05), (0.32, -0.45, 0.48, 0.05),
                                                     (0.28, -0.7, 0.4, 0.046), (0.24, -0.95, 0.3, 0.042),
                                                     (0.2, -1.15, 0.18, 0.038), (0.42, 0.75, 0.42, 0.04),
                                                     (0.46, 0.95, 0.3, 0.036))):
        root, n = HEAD.point(yaw0, 0.98, 0.035)
        mid, _ = HEAD.point((yaw0 + yaw1) * 0.5, (0.98 + pitch1) * 0.5 + 0.08, 0.06)
        end, _ = HEAD.point(yaw1, pitch1, 0.045)
        side = (end - root).cross(n).normalized()
        wavy(parts, root, n, [root.lerp(mid, 0.5) + n * 0.02, mid, end], width, 0.008, side,
             thickness=0.34, steps=10, sharp=True, twist=rng.uniform(-0.2, 0.2), tier=1)

    # The long wavy fall round the sides and back, layered: under-layer
    # behind the ears, then the side curtains, then face-framing locks.
    for side in (-1, 1):
        out = Vector((side, 0, 0))
        for k in range(9):
            yaw = side * (1.15 + k * 0.16)
            pitch = rng.uniform(0.0, 0.35)
            root, n = HEAD.point(yaw, pitch, 0.04)
            back = Vector((0, 1, 0)) * (0.02 + k * 0.012)
            length = rng.uniform(0.3, 0.42)
            flare = 0.02 + 0.012 * (k % 3)
            wavy(parts, root, n, [root + out * flare - U * length * 0.3 + back,
                                  root + out * (flare + 0.02) - U * length * 0.65 + back * 1.5,
                                  root + out * flare - U * length + back * 2.0],
                 rng.uniform(0.045, 0.06), 0.035, F, thickness=0.42, steps=12, sharp=True,
                 twist=side * rng.uniform(0.2, 0.6), tier=k % 2)
        # Face-framing locks: from the temples, round the cheek, curling
        # out at the jaw and on over the collarbone.
        for k, (yaw, pitch, length, width) in enumerate(((0.78, 0.45, 0.36, 0.042), (0.9, 0.35, 0.44, 0.046),
                                                         (1.0, 0.25, 0.48, 0.04))):
            root, n = HEAD.point(side * yaw, pitch, 0.03)
            wavy(parts, root, n, [root + out * 0.015 - U * length * 0.3 + F * 0.03,
                                  root + out * 0.035 - U * length * 0.62 + F * 0.03,
                                  root + out * 0.04 - U * length - F * 0.04], width, 0.03, F,
                 thickness=0.4, steps=12, sharp=True, twist=side * 0.5, tier=1)
    # Under the bun, the back hair falls loose to the shoulder blades.
    for k in range(9):
        yaw = math.pi + (k - 4) * 0.2
        root, n = HEAD.point(yaw, -0.35, 0.04)
        flat = Vector((n.x, n.y, 0)).normalized()
        length = rng.uniform(0.3, 0.45)
        wavy(parts, root, n, [root - U * length * 0.35 + flat * 0.05, root - U * length * 0.7 + flat * 0.06,
                              root - U * length + flat * 0.04], rng.uniform(0.05, 0.065), 0.03,
             Vector((1, 0, 0)) * rng.choice((-1, 1)), thickness=0.42, steps=11, sharp=True, tier=k % 2)
    # Flyaways: thin strands curling off the mass (the soft messy outline).
    for k in range(12):
        yaw = rng.uniform(-3.0, 3.0)
        if abs(yaw) < 0.8:
            yaw += 0.8 * math.copysign(1, yaw)
        root, n = HEAD.point(yaw, rng.uniform(0.1, 0.8), 0.05)
        side = Vector((math.cos(yaw), math.sin(yaw), 0)) * rng.choice((-1, 1))
        curl = (side * 0.7 - U * rng.uniform(0.4, 0.8)).normalized()
        length = rng.uniform(0.08, 0.14)
        wavy(parts, root, n, [root + n * length * 0.25 + curl * length * 0.45,
                              root + n * length * 0.3 + curl * length * 0.9 + side * 0.015,
                              root + n * length * 0.1 + curl * length * 1.1 + side * 0.04],
             rng.uniform(0.01, 0.016), 0.02, side, thickness=0.3, steps=9, sharp=True, tier=2)
    parts += low_bun()
    return parts


def head_piece():
    face_paint.paint_face(FACE, FACE_PNG)
    head = head_loft.build_head(HEAD, FACE, LOFT, SKIN, SKIN_SHADE, BLUSH)
    chibi.face_uv(head, HEAD, FACE)
    ear_parts = [head_loft.ear(HEAD, side, yaw=1.5, pitch=-0.15, size=0.95, tilt=0.3, colour=SKIN, shade=SKIN_SHADE)
                 for side in (-1, 1)]
    for part in ear_parts:
        chibi.no_face_uv(part)
    hair_parts = hair()
    chibi.report([head] + ear_parts + hair_parts)
    hair_obj = common.join(hair_parts, "Mum_Hair")
    chibi.decimate_tris(hair_obj, 28000)
    head = common.join([head] + ear_parts, "Mum_Head")
    # A grown-up's head: smaller on the body, set down onto the neck.
    to_adult = Matrix.Translation(HEAD.c - Vector((0, 0, HEAD_DROP))) @ Matrix.Scale(HEAD_SCALE, 4) \
        @ Matrix.Translation(-HEAD.c)
    for obj in (head, hair_obj):
        obj.data.transform(to_adult)
        obj.data.update()
    return head, hair_obj


# ----------------------------------------------------------------- gear

def tin_mug(center):
    """The camp mug clipped to her pack on a red carabiner (the sheet)."""
    c = Vector(center)
    parts = []
    cup = chibi.cylinder(c, 0.045, 0.08, name="mug", segments=18, bevel=0.004)
    common.color_by(cup, lambda p, n: TIN_DARK if n.z > 0.9 or abs(n.y) < 0.2 and p.x < c.x else TIN, smooth=False)
    parts.append(cup)
    rim = chibi.torus(c + Vector((0, 0, 0.04)), 0.045, 0.005, name="rim", segs=(18, 5))
    common.set_color(rim, common.lerp(TIN, (1, 1, 1), 0.3))
    parts.append(rim)
    handle = chibi.torus(c + Vector((0.055, 0, 0.0)), 0.026, 0.006, name="handle", axis="Y", segs=(14, 5))
    common.set_color(handle, TIN)
    parts.append(handle)
    clip = chibi.torus(c + Vector((0.06, 0, 0.06)), 0.024, 0.006, name="carabiner", axis="Y", segs=(14, 5))
    for v in clip.data.vertices:
        v.co.z = c.z + 0.06 + (v.co.z - c.z - 0.06) * 1.5
    common.set_color(clip, CARABINER)
    parts.append(clip)
    return parts


def backpack():
    """Her olive canvas ranger pack: a flap with leather trim, a front
    pocket, two leather straps with brass buckles, the blue bedroll
    strapped on top, the tin mug on its side, and padded shoulder straps
    with a sternum strap."""
    parts = []
    canvas = lambda p, n: common.lerp(PACK, PACK_DARK, max(0.0, -n.z) * 0.5 +
                                      max(0.0, noise.noise(p * 14.0) - 0.2) * 0.5)
    bag = chibi.fuse([chibi.box((0.44, 0.24, 0.52), (0, 0.35, 0.86), bevel=0.09, name="pack", segments=4),
                      chibi.ellipsoid((0, 0.39, 0.74), (0.21, 0.12, 0.15), name="sag")], "pack", voxel=0.008,
                     faces=5000)
    chibi.fold(bag, (0, 0.43, 0.93), (0.24, 0.18, 0.26), 0.006, wavelength=0.07, across=(-0.3, 0, 1), twist=1.0,
               seed=91)
    common.color_by(bag, canvas)
    parts.append(bag)
    flap = chibi.box((0.44, 0.26, 0.05), (0, 0.335, 1.13), bevel=0.022, name="flap", segments=3)
    for v in flap.data.vertices:
        front = max(0.0, (v.co.y - 0.36) / 0.11)
        v.co.z -= 0.08 * front ** 2
    common.color_by(flap, lambda p, n: LEATHER if p.y > 0.44 or abs(p.x) > 0.2 else common.lerp(canvas(p, n), PACK_DARK, 0.3))
    parts.append(flap)
    pocket = chibi.box((0.28, 0.08, 0.22), (0, 0.49, 0.8), bevel=0.03, name="pocket", segments=3)
    common.color_by(pocket, lambda p, n: LEATHER if p.z > 0.88 else canvas(p, n))
    parts.append(pocket)
    for sx in (-0.1, 0.1):
        path = [Vector((sx, 0.39, 1.15)), Vector((sx, 0.47, 1.1)), Vector((sx, 0.53, 0.98)), Vector((sx, 0.54, 0.84)),
                Vector((sx, 0.53, 0.72))]
        st = chibi.webbing(path, [(0, 0, 1), (0, 0.6, 0.8), (0, 1, 0.1), (0, 1, 0), (0, 1, 0)], width=0.02,
                           thick=0.007, name="packstrap")
        common.set_color(st, LEATHER)
        parts.append(st)
        parts.append(chibi.buckle((sx, 0.545, 0.95), (0, 1, 0), width=0.045, height=0.036, colour=BRASS))
    roll_c = (0.0, 0.35, 1.17)
    parts.append(chibi.bedroll(roll_c, 0.5, 0.075, BEDROLL, LEATHER))
    parts += chibi.bedroll_detail(roll_c, 0.5, 0.075, BEDROLL, LEATHER, metal=BRASS)
    parts += tin_mug((0.26, 0.36, 0.86))
    parts += chibi.straps(LEATHER, top_y=0.22, front_y=-0.225, xs=(-0.15, 0.15), shoulder_z=1.21, bottom_z=0.74,
                          width=0.03, thick=0.01, metal=BRASS)
    chest = chibi.webbing([(-0.17, -0.23, 0.97), (0, -0.245, 0.97), (0.17, -0.23, 0.97)], [(0, -1, 0)] * 3,
                          width=0.012, thick=0.006, name="sternum")
    common.set_color(chest, LEATHER)
    parts.append(chest)
    parts.append(chibi.buckle((0, -0.252, 0.97), (0, -1, 0), width=0.04, height=0.032, colour=BRASS))
    return parts


# ----------------------------------------------------------------- clips

def wave_clip(rig):
    """Wave: her right hand up by her head, the forearm swinging side to
    side, the left arm relaxed, a little lean and a nod. Cyclic."""
    rest = rig_anims.arms(down=72, elbow_l=14, elbow_r=0) + rig_anims.legs(wide=3) + rig_anims.torso(
        spine=-2, chest=0, head=4)

    def pose(swing, nod):
        return rest + rig_anims.P(upperarm_r=[("Y", 72 + 22)], lowerarm_r=[("Y", swing)],
                                  head=[("Y", -3), ("X", nod)], spine=[("Y", 3)])
    keys = [(0, pose(45, 0)), (6, pose(80, -3)), (12, pose(45, 0)), (18, pose(80, -3)), (24, pose(45, 0))]
    return rig_anims.action(rig, "Wave", keys, cyclic=True)


def measure_against_sheet(rig, body, head, hair_obj):
    """MEASURE=1: pose her standing with the arms down (as on the sheet's
    turnaround), print her landmarks as fractions of her height and
    render front and side silhouettes (art/lib/measure.py)."""
    from lib import measure
    rest = rig_anims.arms(down=80, elbow_l=6, elbow_r=6) + rig_anims.legs(wide=2) + rig_anims.torso(
        spine=0, chest=0, head=0)
    rig_anims.action(rig, "Measure", [(0, rest), (1, rest)])
    rig.data.pose_position = "POSE"
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()

    def bone_z(name):
        return (rig.matrix_world @ rig.pose.bones[name].head).z
    knee = bone_z("lowerleg.l")
    hip = bone_z("upperleg.l")
    shoulder = bone_z("upperarm.l")
    heights = {"shoulders": shoulder + 0.06, "belt": PROP.z(0.62), "crotch": PROP.z(0.47), "knees": knee}
    marks = measure.landmarks([body, hair_obj], head, heights)
    top = marks["height_m"]
    # Shoulder width with the arms hanging (as drawn); the others in the
    # rest pose, so the hands at her sides don't count.
    marks.update(measure.widths([body], {"w_shoulders": (shoulder - 0.04, None)}, top))
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    marks.update(measure.widths([body], {"w_chest": (PROP.z(0.9), None), "w_hips": (PROP.z(0.53), None),
                                         "w_thigh": (PROP.z(0.4), 1)}, top))
    rig.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    sheet = {"head": 0.173, "chin": 0.827, "shoulders": 0.755, "belt": 0.54, "crotch": 0.474, "knees": 0.27,
             "w_shoulders": 0.255, "w_chest": 0.216, "w_hips": 0.216, "w_thigh": 0.1}
    print("measure: %-12s %7s %7s %7s" % ("landmark", "model", "sheet", "diff"))
    for key, value in marks.items():
        ref = sheet.get(key)
        print("measure: %-12s %7.3f %7s %7s" % (key, value, "%.3f" % ref if ref else "-",
                                                 "%+.3f" % (value - ref) if ref else ""))
    out = os.environ.get("ART_PREVIEW_DIR", os.path.join(common.ROOT, "build", "art_previews"))
    for view in ("front", "side"):
        measure.silhouette([body, head, hair_obj], os.path.join(out, "mum_sil_%s.png" % view), view)


def build():
    rig = chibi.load_rig()
    soft = [skin_piece(), jacket_piece(), trousers_piece()]
    rigid = hands_and_feet() + pockets_and_belt()
    # Brass compass on her left shoulder strap (the sheet's detail).
    for part in chibi.compass((0.17, -0.235, 0.86), GOLD, neck_z=None, radius=0.035):
        rigid.append((part, "chest"))
    for part in backpack():
        rigid.append((part, "chest"))
    rigid.append((scarf_piece(), "chest"))
    head, hair_obj = head_piece()
    if os.environ.get("HEAD_ONLY"):
        # Face and hair iteration (~20 s): no body, no bake.
        from lib import preview
        chibi.quick_material(head, overlay=(FACE_PNG, "FaceUV"))
        chibi.quick_material(hair_obj)
        preview.render([head, hair_obj], "mum_head", elevation=6, azimuth=10, size=512)
        preview.render([head, hair_obj], "mum_head34", elevation=10, azimuth=40, size=512)
        preview.render([head, hair_obj], "mum_head_back", elevation=15, azimuth=160, size=384)
        return
    PROP.stretch_rig(rig)
    body = chibi.finish(rig, soft, rigid, "Mum", prop=PROP)
    PROP.stretch_mesh(head)
    PROP.stretch_mesh(hair_obj)
    for obj, bone in ((head, "head"), (hair_obj, "head")):
        chibi.rigid(obj, bone)
        obj.parent = rig
        obj.modifiers.new("Armature", "ARMATURE").object = rig
    idle = bpy.data.actions.get("Idle")
    wave_clip(rig)
    rig.animation_data.action = idle

    meshes = [body, head, hair_obj]
    if os.environ.get("MEASURE"):
        measure_against_sheet(rig, body, head, hair_obj)
        return
    highs = {}
    if not os.environ.get("HIGH_POLY"):
        chibi.report(meshes)
        budget = {body: 21000, head: 4500, hair_obj: 10000}
        highs = {mesh: chibi.lowpoly(mesh, tris) for mesh, tris in budget.items()}

    if os.environ.get("SCULPT"):
        print("mum tris:", common.triangle_count(meshes))
        sculpt_previews(rig, meshes, "mum", ("Walking_A", 8), ("Wave", 6))
        return
    if chibi.quick_mode():
        for mesh in meshes:
            chibi.quick_material(mesh, overlay=(FACE_PNG, "FaceUV") if mesh is head else None)
        print("mum tris:", common.triangle_count(meshes))
        render_previews(rig, meshes, head, "mum", ("Walking_A", 8), ("Wave", 6), ("Cheer", 12),
                        *[(clip, 10) for clip in os.environ.get("EXTRA_CLIPS", "").split(",") if clip])
        return
    params = dict(size=1024, ao_distance=0.18, ao_strength=0.6, edge_strength=0.3, edge_radius=0.012,
                  noise_scale=6.0, stroke_strength=0.08, light=(1.12, 1.04, 0.95), shadow=(0.45, 0.38, 0.58),
                  foot_darken=0.32, foot_height=0.9, key_light=(-0.4, -0.6, 0.8), key_strength=0.55,
                  curvature_tint=((0.72, 0.55, 0.5), (1.1, 1.08, 1.12), 0.85))
    for mesh in meshes:
        extra = dict(ao_strength=0.4, ao_distance=0.05, overlay=(FACE_PNG, "FaceUV"), cavity=0.25,
                     shadow=(0.84, 0.58, 0.5), light=(1.12, 1.03, 0.94), key_strength=0.35,
                     curvature_tint=((0.9, 0.7, 0.64), (1.05, 1.03, 1.02), 0.45)) \
            if mesh is head else dict(cavity=0.3)
        paint_bake.paint(mesh, source="attribute", high=highs.get(mesh), **dict(params, **extra))
    rig.data.pose_position = "POSE"
    for mesh in meshes:
        # The fused body had invalid faces ("Mesh Mum is not valid" from
        # the exporter), which came out in Godot as a stray black strip.
        if mesh.data.validate(clean_customdata=False):
            print("mum: repaired mesh data on", mesh.name)
    common.export_glb(os.path.join(common.OUT_DIR, "mum.glb"), [rig] + meshes, animations=True, image_format="WEBP")
    print("mum tris:", common.triangle_count(meshes))
    render_previews(rig, meshes, head, "mum", ("Walking_A", 8), ("Wave", 6), ("Cheer", 12))


if __name__ == "__main__":
    build()
