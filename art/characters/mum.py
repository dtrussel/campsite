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
JACKET = (0.74, 0.8, 0.24)
JACKET_DARK = (0.46, 0.52, 0.12)
TOP = (0.13, 0.13, 0.15)
TOP_LIGHT = (0.26, 0.26, 0.29)
SCARF = (0.66, 0.55, 0.42)
SCARF_DARK = (0.42, 0.33, 0.24)
TROUSERS = (0.24, 0.23, 0.25)
TROUSERS_DARK = (0.13, 0.12, 0.14)
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

PROP = chibi.Proportions(legs=3.1, spine=1.3, arms=1.5)
# The head is built at the kids' scale around HEAD (so the face kit's
# numbers fit), then scaled about its centre and set down onto the neck.
HEAD = chibi.HeadFrame((0, -0.01, 1.515), (0.215, 0.235, 0.25))
HEAD_SCALE = 0.74
HEAD_DROP = 0.05
FACE_PNG = os.path.join(common.ROOT, "build", "art_faces", "mum_face.png")
# From the sheet: a grown-up's face - the eyes higher and smaller than
# the kids', bright blue with a dark lash line, soft gold brows, a small
# straight nose, freckles over the nose and cheeks, and a warm closed-
# mouth smile with a hint of teeth.
FACE = face_paint.FaceLayout(
    size=0.32, eye_x=0.082, eye_z=-0.035, eye_w=0.046, eye_h=0.03, eye_tilt=0.02, lid=0.12, iris_r=0.025,
    look=(0.002, 0.003), iris=(0.36, 0.62, 0.95), iris_dark=(0.05, 0.16, 0.42), lash=(0.16, 0.08, 0.05),
    lash_width=0.01, wing=0.008, lower_lash=0.3, eyeshadow_alpha=0.08, socket=(0.82, 0.55, 0.48),
    socket_alpha=0.28, lid_fold=0.5, nose_shadow=0.16, nostril_alpha=0.25,
    brows=((0.03, 0.045, 0.01, 0.012), (0.03, 0.045, 0.01, 0.012)),
    brow_len=0.058, brow_colour=(0.68, 0.46, 0.22), brow_alpha=0.85, nose_z=-0.104, nose_w=0.014,
    mouth_z=-0.148, mouth_w=0.05, smile=5.5, smirk=0.0, open_mouth=0.006, lip_upper=0.003, lip_lower=0.006,
    lip_colour=(0.86, 0.46, 0.44), lip_dark=(0.5, 0.18, 0.18), tongue=(0.84, 0.38, 0.4), chin_z=-0.228,
    skin_shadow=(0.8, 0.48, 0.4), light_colour=(1.0, 0.9, 0.8), blush=(0.98, 0.46, 0.42), blush_alpha=0.38,
    blush_pos=(0.11, -0.105), contour=0.14, plane_light=1.0, face_half_w=0.19, catch2=0.8, flush_alpha=0.1,
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
    sections=tuple((z * (1.06 if z > 0 else 1.1), w * (0.88 if z > -0.1 else 0.84), f * 0.96, b * 0.94, sf, sb)
                   for z, w, f, b, sf, sb in _NELA_SECTIONS),
    nose_top=-0.06, nose_tip_z=-0.098, nose_base_z=-0.11, nose_h=0.018, nose_bridge_h=0.003,
    nose_w=(0.004, 0.009), nose_side=0.011, alae=0.003, cheek=0.006, cheek_pos=(0.105, -0.1),
    eye_inset=0.004, eye_plate=(1.2, 1.5), brow_shelf=0.004,
    upper_lip=0.003, lower_lip=0.004, chin=0.005, rings=90)

F, R, U = Vector((0, -1, 0)), Vector((-1, 0, 0)), Vector((0, 0, 1))  # forward, her right, up


# ---------------------------------------------------------------- body

def skin_piece():
    """Only the neck shows (the top's sleeves and the trousers cover the
    rest); slim adult arms and legs inside help the auto-weights."""
    parts = [chibi.limb([(0, 0.0, 1.08), (0, 0.004, 1.25), (0, 0.006, 1.38)],
                        [(0.07, 0.066), (0.062, 0.06), (0.06, 0.058)], up=(0, -1, 0), name="neck")]
    for s in (-1, 1):
        xs = (0.24, 0.34, 0.45, 0.55, 0.65, 0.74, 0.78)
        rr = ((0.06, 0.062), (0.056, 0.056), (0.05, 0.05), (0.048, 0.046), (0.044, 0.04), (0.038, 0.034),
              (0.036, 0.032))
        parts.append(chibi.limb([(s * x, 0, 1.107) for x in xs], rr, up=(0, 0, 1), name="arm"))
        zs = (0.5, 0.42, 0.34, 0.27, 0.21, 0.16)
        rr = ((0.075, 0.075), (0.068, 0.068), (0.06, 0.062), (0.052, 0.056), (0.046, 0.05), (0.044, 0.048))
        parts.append(chibi.limb([(s * 0.12, 0.0, z) for z in zs], rr, up=(0, -1, 0), name="leg"))
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
        chibi.ellipsoid((0, 0, 1.0), (0.215, 0.16, 0.17), name="chest"),
        chibi.ellipsoid((0, -0.035, 0.97), (0.17, 0.1, 0.09), name="bust"),
        chibi.ellipsoid((0, 0, 0.8), (0.165, 0.13, 0.17), name="waist"),
        chibi.ellipsoid((0, 0, 0.63), (0.2, 0.15, 0.12), name="hipline"),
    ]
    for s in (-1, 1):
        # One sleeve along the whole arm: jacket to the elbow, top beyond.
        parts.append(chibi.limb([(s * 0.12, 0, 1.11), (s * 0.3, 0, 1.108), (s * 0.48, 0, 1.107),
                                 (s * 0.64, 0, 1.107), (s * 0.76, 0, 1.107)],
                                [(0.085, 0.085), (0.078, 0.078), (0.072, 0.07), (0.056, 0.054), (0.046, 0.044)],
                                up=(0, 0, 1), name="sleeve"))
        parts.append(chibi.ellipsoid((s * 0.19, 0.0, 1.12), (0.08, 0.09, 0.07), name="deltoid", segs=(16, 12)))
        # The rolled-up jacket cuff just above the elbow.
        parts.append(chibi.hem_ring((s * 0.47, 0, 1.107), (0.08, 0.078), 0.02, name="roll", axis="X"))
        parts.append(chibi.hem_ring((s * 0.755, 0, 1.107), (0.047, 0.045), 0.008, name="cuff", axis="X"))
    # Jacket skirt to the hips, with a hem.
    parts.append(chibi.limb([(0, 0, 0.66), (0, 0, 0.58), (0, 0, 0.51)],
                            [(0.21, 0.155), (0.222, 0.162), (0.228, 0.166)], up=(0, -1, 0), name="skirt"))
    parts.append(chibi.hem_ring((0, 0, 0.51), (0.228, 0.166), 0.01, name="hem", axis="Z"))
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
        if ax > 0.495:
            # The top's black sleeve, with soft folds.
            return common.lerp(TOP, TOP_LIGHT, max(0.0, math.sin(ax * 70) * 0.35))
        if ax > 0.44:
            return common.lerp(JACKET, JACKET_DARK, 0.35)      # the rolled cuff
        # The open front: a strip of the black top down the middle, with
        # the jacket's zip edges either side.
        if pos.y < -0.05 and pos.z > 0.6:
            if ax < 0.04:
                return TOP
            if ax < 0.05:
                return JACKET_DARK
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
    parts = [chibi.ellipsoid((0, 0, 0.55), (0.19, 0.135, 0.11), name="hips")]
    for s in (-1, 1):
        parts.append(chibi.limb([(s * 0.1, 0, 0.56), (s * 0.125, -0.005, 0.42), (s * 0.13, 0.0, 0.32),
                                 (s * 0.13, 0.008, 0.24), (s * 0.13, 0.012, 0.19)],
                                [(0.1, 0.1), (0.1, 0.1), (0.09, 0.092), (0.08, 0.084), (0.08, 0.084)],
                                up=(0, -1, 0), name="leg"))
    parts.append(chibi.ellipsoid((0, 0.0, 0.47), (0.11, 0.11, 0.08), name="crotch"))
    trousers = chibi.fuse(parts, "Trousers", voxel=0.0095)
    chibi.cut_open(trousers, (0, 0, 0.2), (0, 0, -1))
    for s in (-1, 1):
        chibi.fold(trousers, (s * 0.13, -0.02, 0.33), (0.12, 0.14, 0.04), 0.009, wavelength=0.05,
                   across=(0, 0, 1), twist=0.8 * s, seed=71 + s)
        chibi.fold(trousers, (s * 0.13, 0.01, 0.22), (0.1, 0.1, 0.04), 0.01, radial_axis=(0, 0, 1), count=8,
                   seed=73 + s)
    chibi.fold(trousers, (0, -0.1, 0.48), (0.14, 0.18, 0.08), 0.008, radial_axis=(0, 1, 0), count=4, seed=75)

    def colour(pos, normal):
        seam = abs(abs(pos.x) - 0.13) > 0.088 and abs(normal.x) > 0.8
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
        pocket = chibi.box((0.03, 0.12, 0.1), (s * 0.215, -0.005, 0.36), bevel=0.012, name="cargo")
        common.color_by(pocket, lambda p, n: TROUSERS_DARK if p.z > 0.395 else TROUSERS, smooth=False)
        parts.append((pocket, bone))
    for s in (-1, 1):
        flap = chibi.box((0.1, 0.02, 0.05), (s * 0.11, -0.165, 1.02), bevel=0.01, name="chestpocket")
        common.color_by(flap, lambda p, n: JACKET_DARK if p.z > 1.03 else JACKET, smooth=False)
        parts.append((flap, "chest"))
        button = chibi.cylinder((s * 0.11, -0.178, 1.035), 0.008, 0.006, name="button", axis="Y", segments=8)
        common.set_color(button, BRASS)
        parts.append((button, "chest"))
    belt = chibi.torus((0, 0, 0.64), 0.205, 0.016, name="belt", segs=(40, 6))
    for v in belt.data.vertices:
        v.co.y *= 0.8
    common.color_by(belt, lambda p, n: common.lerp(LEATHER, (0.1, 0.05, 0.02), 0.25 if int(p.x * 40) % 2 else 0.0),
                    smooth=False)
    parts.append((belt, "hips"))
    parts.append((chibi.buckle((0, -0.172, 0.64), (0, -1, 0), width=0.06, height=0.045, colour=BRASS), "hips"))
    collar = chibi.torus((0, 0, 1.2), 0.07, 0.014, name="collar")
    common.set_color(collar, TOP)
    parts.append((collar, "chest"))
    return parts


def scarf_piece():
    """The tan scarf: a soft lumpy wrap round the neck with a short tail
    tucked down the front (the sheet)."""
    puffs = []
    for k in range(10):
        a = k / 10 * math.tau
        puffs.append(chibi.ellipsoid((math.cos(a) * 0.085, math.sin(a) * 0.075, 1.205 + 0.012 * math.sin(a * 2)),
                                     (0.055, 0.05, 0.045), name="wrap", segs=(12, 8)))
    puffs.append(chibi.ellipsoid((0.02, -0.1, 1.14), (0.06, 0.035, 0.07), name="knot", segs=(12, 10)))
    puffs.append(chibi.ellipsoid((0.04, -0.11, 1.06), (0.045, 0.025, 0.06), name="tail", segs=(10, 8)))
    scarf = chibi.fuse(puffs, "scarf", voxel=0.008, smooth=2, faces=2400)
    chibi.fold(scarf, (0, 0, 1.2), (0.16, 0.16, 0.06), 0.008, radial_axis=(0, 0, 1), count=12, seed=81)
    common.color_by(scarf, lambda p, n: common.lerp(SCARF, SCARF_DARK, max(0.0, -n.z) * 0.6 +
                                                    max(0.0, noise.noise(p * 30.0)) * 0.3))
    return scarf


def hands_and_feet():
    rigid = []
    for h, bone in chibi.hands(SKIN, sculpted=True, crease=SKIN_SHADE, size=0.86):
        rigid.append((h, bone))
    for s, bone in ((1, "foot.l"), (-1, "foot.r")):
        for part in chibi.sculpted_boot(s, BOOT, SOLE, BOOT_TOE, LACE, scale=0.98, height=0.85,
                                        collar=(0.32, 0.2, 0.1)):
            common.grime(part, MUD, lambda p, n: max(0.0, (0.1 - p.z) / 0.08) * 0.7 +
                         max(0.0, noise.noise(p * 26.0) - 0.3) * 0.8)
            for v in part.data.vertices:
                v.co.x -= s * 0.04          # her feet sit under narrower hips than the kids'
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
    c, r = HEAD.c, HEAD.r
    shell_r = (r.x + 0.035, r.y + 0.035, r.z + 0.03)
    shell = chibi.ellipsoid(c + Vector((0, 0.012, 0.012)), shell_r, name="hairshell", segs=(40, 26))
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    kill = []
    for v in bm.verts:
        d = v.co - c
        d = Vector((d.x / shell_r[0], d.y / shell_r[1], d.z / shell_r[2]))
        if not (d.z > 0.5 or (d.y > -0.3 and d.z > -0.25) or (d.y > 0.3 and d.z > -0.6)):
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(shell.data)
    bm.free()
    mod = shell.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.022
    common.apply_all_modifiers(shell)
    common.shade_smooth(shell)
    common.color_by(shell, chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, c, scale=5.0, strands=34))
    return shell


def bun_base():
    """A loose bun low on the back of her head (the sheet's turnaround)."""
    p, n = HEAD.point(math.pi, -0.3, 0.03)
    return p + Vector((0.0, 0.03, 0.0))


def low_bun():
    parts = []
    base = bun_base()
    rng = random.Random(17)
    puffs = [chibi.ellipsoid(base + Vector(o), rad, name="bun", segs=(16, 10))
             for o, rad in (((0, 0.04, 0.0), (0.095, 0.08, 0.085)), ((0.05, 0.06, 0.03), (0.06, 0.055, 0.055)),
                            ((-0.05, 0.05, -0.02), (0.06, 0.055, 0.055)), ((0.0, 0.09, 0.02), (0.055, 0.05, 0.05)))]
    bun = chibi.fuse(puffs, "bun", voxel=0.01, smooth=2, faces=1600)
    common.color_by(bun, chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, base, scale=12.0, strands=18))
    parts.append(bun)
    for k in range(9):
        a = k / 9 * math.tau + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(a), 0.3, math.sin(a))).normalized()
        root = base + Vector((0, 0.06, 0)) + out * 0.05
        side = out.cross(F).normalized()
        L = rng.uniform(0.08, 0.15)
        wavy(parts, root, side, [root + out * L * 0.5, root + out * L * 0.9 - U * 0.03,
                                 root + out * L - U * 0.08 + side * 0.03],
             rng.uniform(0.012, 0.02), 0.012, side, thickness=0.3, steps=7, sharp=True, tier=2)
    return parts


def hair():
    """Long wavy hair as on the sheet: swept back from a side parting into
    a loose low bun, long locks framing her face and falling over her
    shoulders to the chest, loose locks at the nape and flyaways."""
    parts = [hair_cap()]
    rng = random.Random(5)
    base = bun_base()

    def pulled(yaw, pitch, width, tier, lift=0.01):
        root, n = HEAD.point(yaw, pitch, lift)
        mids = []
        for t in (0.35, 0.7):
            q, qn = HEAD.point(yaw * (1 - t) + math.copysign(math.pi, yaw) * t, pitch * (1 - t) - 0.05 * t,
                               lift + 0.012 + 0.012 * t)
            mids.append(q)
        side = (mids[0] - root).cross(n).normalized()
        wavy(parts, root, n, mids + [base + (root - base).normalized() * 0.05], width, 0.01, side,
             thickness=(0.42, 0.36, 0.3)[tier], steps=9, sharp=tier > 0, twist=rng.uniform(-0.3, 0.3), tier=tier,
             ring=10 if tier == 0 else 8)

    for k in range(12):
        yaw = -math.pi + (k + 0.5) / 12 * math.tau
        if abs(yaw) < 0.9:
            continue
        pulled(yaw, 0.3 + 0.12 * (k % 3), 0.1, 0, lift=0.012)
    for k in range(28):
        yaw = rng.choice((-1, 1)) * rng.uniform(0.9, 2.9)
        pulled(yaw, rng.uniform(0.25, 0.8), rng.uniform(0.04, 0.06), 1, lift=0.024)
    # A soft side-swept fringe from a parting on her left.
    for yaw, drop, fan, width in ((0.42, 0.09, -0.12, 0.034), (0.25, 0.07, -0.14, 0.03), (0.08, 0.06, -0.16, 0.028),
                                  (-0.1, 0.07, -0.12, 0.026), (-0.3, 0.1, -0.06, 0.026), (-0.5, 0.13, -0.02, 0.024)):
        root, n = HEAD.point(yaw + 0.1, 0.82, 0.006)
        side = Vector((-math.cos(yaw), -math.sin(yaw), 0))
        wavy(parts, root, F, [root + F * 0.05 + U * 0.02, root + F * 0.065 - U * drop * 0.5 - side * fan * 0.5,
                              root + F * 0.05 - U * drop - side * fan * 1.3], width, 0.01, side,
             thickness=0.3, sharp=True, twist=rng.uniform(-0.3, 0.3), tier=2)
    # Long face-framing locks from the temples, falling past the jaw
    # over the shoulders to the chest (they reach below the neck, so the
    # body stretch lengthens them with her torso).
    for side in (-1, 1):
        out = Vector((side, 0, 0))
        for k, (yaw, length, width, fwd) in enumerate(((0.85, 0.5, 0.045, -0.06), (1.0, 0.6, 0.05, -0.01),
                                                       (1.2, 0.55, 0.04, 0.04), (1.45, 0.5, 0.045, 0.08))):
            root, n = HEAD.point(side * yaw, 0.3 - 0.07 * k, 0.012)
            wavy(parts, root, n, [root + out * 0.05 - U * length * 0.3 + F * 0.01,
                                  root + out * 0.12 - U * length * 0.65 - F * fwd,
                                  root + out * 0.16 - U * length - F * fwd * 1.6], width * 1.3, 0.04, F,
                 thickness=0.4, steps=11, sharp=True, twist=side * 0.4, tier=1)
    # Loose locks at the nape under the bun.
    for k, yaw in enumerate((2.55, 2.8, 3.05, 3.3, 3.55, 3.8)):
        root, n = HEAD.point(yaw, -0.2, 0.012)
        flat = Vector((n.x, n.y, 0)).normalized()
        length = rng.uniform(0.12, 0.2)
        wavy(parts, root, n, [root - U * length * 0.4 + flat * 0.02, root - U * length * 0.85 + flat * 0.04,
                              root - U * length + flat * 0.06], rng.uniform(0.03, 0.045), 0.015,
             Vector((1, 0, 0)) * rng.choice((-1, 1)), thickness=0.36, sharp=True, tier=1)
    for k in range(18):
        yaw = rng.uniform(-3.0, 3.0)
        if abs(yaw) < 0.8:
            yaw += 0.8 * math.copysign(1, yaw)
        root, n = HEAD.point(yaw, rng.uniform(0.15, 0.9), 0.026)
        side = Vector((math.cos(yaw), math.sin(yaw), 0)) * rng.choice((-1, 1))
        curl = (side * 0.7 - U * rng.uniform(0.4, 0.8)).normalized()
        length = rng.uniform(0.08, 0.13)
        wavy(parts, root, n, [root + n * length * 0.25 + curl * length * 0.45,
                              root + n * length * 0.3 + curl * length * 0.9 + side * 0.015,
                              root + n * length * 0.1 + curl * length * 1.1 + side * 0.04],
             rng.uniform(0.01, 0.015), 0.018, side, thickness=0.3, steps=9, sharp=True, tier=2)
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
    bag = chibi.fuse([chibi.box((0.42, 0.22, 0.42), (0, 0.33, 0.93), bevel=0.09, name="pack", segments=4),
                      chibi.ellipsoid((0, 0.37, 0.84), (0.2, 0.11, 0.14), name="sag")], "pack", voxel=0.008,
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
    pocket = chibi.box((0.26, 0.08, 0.2), (0, 0.46, 0.86), bevel=0.03, name="pocket", segments=3)
    common.color_by(pocket, lambda p, n: LEATHER if p.z > 0.93 else canvas(p, n))
    parts.append(pocket)
    for sx in (-0.1, 0.1):
        path = [Vector((sx, 0.37, 1.15)), Vector((sx, 0.44, 1.1)), Vector((sx, 0.5, 0.98)), Vector((sx, 0.51, 0.84)),
                Vector((sx, 0.5, 0.76))]
        st = chibi.webbing(path, [(0, 0, 1), (0, 0.6, 0.8), (0, 1, 0.1), (0, 1, 0), (0, 1, 0)], width=0.02,
                           thick=0.007, name="packstrap")
        common.set_color(st, LEATHER)
        parts.append(st)
        parts.append(chibi.buckle((sx, 0.515, 0.95), (0, 1, 0), width=0.045, height=0.036, colour=BRASS))
    roll_c = (0.0, 0.33, 1.22)
    parts.append(chibi.bedroll(roll_c, 0.5, 0.075, BEDROLL, LEATHER))
    parts += chibi.bedroll_detail(roll_c, 0.5, 0.075, BEDROLL, LEATHER, metal=BRASS)
    parts += tin_mug((0.26, 0.36, 0.86))
    parts += chibi.straps(LEATHER, top_y=0.2, front_y=-0.19, xs=(-0.13, 0.13), shoulder_z=1.21, bottom_z=0.74,
                          width=0.03, thick=0.01, metal=BRASS)
    chest = chibi.webbing([(-0.15, -0.2, 0.97), (0, -0.215, 0.97), (0.15, -0.2, 0.97)], [(0, -1, 0)] * 3,
                          width=0.012, thick=0.006, name="sternum")
    common.set_color(chest, LEATHER)
    parts.append(chest)
    parts.append(chibi.buckle((0, -0.222, 0.97), (0, -1, 0), width=0.04, height=0.032, colour=BRASS))
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


def build():
    rig = chibi.load_rig()
    soft = [skin_piece(), jacket_piece(), trousers_piece()]
    rigid = hands_and_feet() + pockets_and_belt()
    # Brass compass on her left shoulder strap (the sheet's detail).
    for part in chibi.compass((0.15, -0.205, 0.86), GOLD, neck_z=None, radius=0.035):
        rigid.append((part, "chest"))
    for part in backpack():
        rigid.append((part, "chest"))
    rigid.append((scarf_piece(), "chest"))
    head, hair_obj = head_piece()
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
        render_previews(rig, meshes, head, "mum", ("Walking_A", 8), ("Wave", 6), ("Cheer", 12))
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
    common.export_glb(os.path.join(common.OUT_DIR, "mum.glb"), [rig] + meshes, animations=True, image_format="WEBP")
    print("mum tris:", common.triangle_count(meshes))
    render_previews(rig, meshes, head, "mum", ("Walking_A", 8), ("Wave", 6), ("Cheer", 12))


if __name__ == "__main__":
    build()
