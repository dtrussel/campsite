"""Leo, the big brother (the player). Modelled from the concept art: messy
blond hair under a backwards navy cap, big blue eyes, freckles and a
grin; light-blue tee with a forest badge; teal board shorts with lime
stripes; grey socks and chunky hiking boots; a big camo backpack with a
navy bedroll, steel bottle and rope; a compass on a cord; and his
trusty walking stick. Built on the KayKit adventurer rig so all 76
animations work. Output: leo.glb"""

import math
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from characters import chibi, face_paint  # noqa: E402

SKIN = (0.96, 0.74, 0.6)
SKIN_SHADE = (0.8, 0.52, 0.42)
BLUSH = (1.0, 0.56, 0.52)
HAIR_LIGHT = (1.0, 0.84, 0.48)
HAIR = (0.86, 0.62, 0.28)
HAIR_DARK = (0.5, 0.32, 0.14)
BROW = (0.5, 0.32, 0.15)
IRIS = (0.28, 0.68, 0.92)
IRIS_DARK = (0.04, 0.24, 0.46)
TEAL = (0.12, 0.6, 0.58)
TEAL_DARK = (0.06, 0.38, 0.4)
WRAP = (0.95, 0.92, 0.84)
LASH = (0.2, 0.12, 0.08)
FRECKLE = (0.9, 0.6, 0.45)
TEE = (0.5, 0.66, 0.8)
TEE_DARK = (0.3, 0.44, 0.6)
BADGE = (0.16, 0.28, 0.52)
BADGE_TREE = (0.35, 0.68, 0.3)
SHORTS = (0.1, 0.34, 0.4)
SHORTS_DARK = (0.05, 0.2, 0.27)
LIME = (0.62, 0.78, 0.24)
SHORTS_LIGHT = (0.3, 0.56, 0.62)
SOCK = (0.72, 0.72, 0.74)
BOOT = (0.22, 0.28, 0.4)
BOOT_TOE = (0.5, 0.46, 0.4)
SOLE = (0.44, 0.34, 0.24)
LACE = (0.86, 0.84, 0.8)
BOOT_ACCENT = (0.85, 0.82, 0.22)
CAP = (0.13, 0.17, 0.32)
CAP_SEAM = (0.08, 0.1, 0.2)
CAMO = [(0.32, 0.4, 0.2), (0.22, 0.28, 0.14), (0.46, 0.44, 0.28)]
STRAP = (0.26, 0.2, 0.14)
BEDROLL = (0.16, 0.22, 0.42)
STEEL = (0.8, 0.82, 0.85)
ROPE = (0.82, 0.68, 0.44)
GOLD = (0.95, 0.74, 0.3)
BARK = (0.46, 0.3, 0.17)
BARK_LIGHT = (0.64, 0.46, 0.28)
LEAF = (0.4, 0.66, 0.26)
RED = (0.88, 0.2, 0.18)

HEAD = chibi.HeadFrame((0, -0.01, 1.56), (0.25, 0.245, 0.3))
PROP = chibi.Proportions(legs=1.85, spine=1.3, arms=1.25)
GLOVE = (0.3, 0.22, 0.18)
SHIN_WRAP = (0.34, 0.3, 0.28)
FACE_PNG = os.path.join(common.ROOT, "build", "art_faces", "leo_face.png")
# Ekko-style painted face: fairly small almond eyes under heavy, confident
# lids, thick brows (his left one cocked), a firm sly smirk, freckles and
# teal face-paint marks on the cheekbones.
FACE = face_paint.FaceLayout(
    size=0.3, eye_x=0.08, eye_z=-0.005, eye_w=0.039, eye_h=0.019, eye_tilt=0.1, lid=0.32, iris_r=0.017,
    look=(0.004, 0.0), iris=(0.32, 0.68, 0.92), iris_dark=(0.04, 0.22, 0.42), lash=(0.14, 0.08, 0.06),
    lash_width=0.008, wing=0.008, lower_lash=0.35, eyeshadow=(0.74, 0.5, 0.44), eyeshadow_alpha=0.25,
    socket=(0.62, 0.38, 0.32), brows=((0.03, 0.3, 0.014, 0.008), (0.018, 0.12, 0.014, 0.003)), brow_len=0.058,
    brow_colour=(0.3, 0.17, 0.08), nose_z=-0.078, nose_w=0.017, mouth_z=-0.142, mouth_w=0.036, smile=3.5,
    smirk=-0.12, lip_upper=0.0045, lip_lower=0.0065, lip_colour=(0.86, 0.56, 0.5), lip_dark=(0.52, 0.26, 0.22),
    chin_z=-0.235, skin_shadow=(0.58, 0.34, 0.28), blush_alpha=0.12, contour=0.6, blush_pos=(0.11, -0.07),
    freckles=[(0.035, -0.06), (0.05, -0.052), (0.063, -0.062), (0.028, -0.07), (-0.035, -0.06), (-0.05, -0.052),
              (-0.063, -0.062), (-0.028, -0.07), (0.012, -0.055), (-0.012, -0.055)],
    marks=[([(side * 0.098, -0.036), (side * 0.108, -0.066)], [0.007, 0.0015], (0.1, 0.62, 0.6), 0.95)
           for side in (-1, 1)] + [([(side * 0.12, -0.03), (side * 0.128, -0.052)], [0.005, 0.0012],
                                    (0.1, 0.62, 0.6), 0.9) for side in (-1, 1)])
FEATURES = dict(socket=0.016, eyeball=0.005, brow=0.016, nose=0.028, lips=0.007, chin=0.014, cheekbone=0.016)


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
    parts = [chibi.tube([(0, 0, 1.1), (0, 0.01, 1.4)], [0.075, 0.07], name="neck")]
    for s in (-1, 1):
        parts.append(chibi.tube([(s * 0.3, 0, 1.11), (s * 0.55, 0, 1.11), (s * 0.8, 0, 1.11)], [0.07, 0.066, 0.058],
                                name="arm"))
        parts.append(chibi.tube([(s * 0.16, 0, 0.46), (s * 0.17, -0.01, 0.29), (s * 0.17, 0.02, 0.14)],
                                [0.085, 0.082, 0.068], name="leg"))
    body = chibi.fuse(parts, "Skin", voxel=0.014, faces=1500)
    common.color_by(body, lambda p, n: common.lerp(SKIN, SKIN_SHADE, max(0.0, -n.z * 0.5)))
    return body


def shirt_piece():
    # Lean V-shaped torso: broader chest, narrower waist.
    parts = [
        chibi.ellipsoid((0, 0, 1.01), (0.27, 0.2, 0.23), name="chest"),
        chibi.ellipsoid((0, -0.005, 0.78), (0.225, 0.19, 0.27), name="belly"),
    ]
    for s in (-1, 1):
        parts.append(chibi.tube([(s * 0.14, 0, 1.1), (s * 0.41, 0, 1.1)], [0.12, 0.108], name="sleeve", levels=2))
    shirt = chibi.fuse(parts, "Shirt", voxel=0.013, faces=2200)
    for s in (-1, 1):
        chibi.cut_open(shirt, (s * 0.39, 0, 0), (s, 0, 0))

    def colour(pos, normal):
        if abs(pos.x) > 0.345:
            return TEE_DARK  # rolled sleeve cuff
        if pos.z < 0.6:
            return common.lerp(TEE, TEE_DARK, 0.5)  # hem band
        # Painted fabric folds: soft diagonal creases at the waist.
        fold = math.sin(pos.x * 38 + pos.z * 22) * max(0.0, 0.85 - pos.z) * 2.2
        return common.lerp(TEE, TEE_DARK, max(0.0, min(0.5, fold * 0.5)))
    common.color_by(shirt, colour)
    return shirt


def shorts_piece():
    parts = [chibi.ellipsoid((0, 0, 0.58), (0.24, 0.195, 0.14), name="hips")]
    for s in (-1, 1):
        parts.append(chibi.tube([(s * 0.13, 0, 0.6), (s * 0.18, 0, 0.27)], [0.13, 0.135], name="shortleg", levels=2))
    shorts = chibi.fuse(parts, "Shorts", voxel=0.012, faces=2000)
    chibi.cut_open(shorts, (0, 0, 0.285), (0, 0, -1))

    def colour(pos, normal):
        z = pos.z
        if 0.37 < z < 0.385:
            return LIME
        if 0.392 < z < 0.4:
            return SHORTS_LIGHT
        if z < 0.315:
            return SHORTS_DARK  # hem
        if abs(normal.x) > 0.85 and z > 0.46:
            return SHORTS_LIGHT  # side panel
        return SHORTS
    common.color_by(shorts, colour)
    return shorts


def badge():
    c = Vector((0.085, -0.215, 0.86))
    disc = chibi.cylinder(c, 0.05, 0.012, name="badge", axis="Y", segments=24, bevel=0.004)

    def colour(pos, normal):
        rel = pos - c
        r = math.hypot(rel.x, rel.z)
        if normal.y > -0.8 or r > 0.04:
            return BADGE
        if rel.z < 0.027 and abs(rel.x) < (0.027 - rel.z) * 0.55 and rel.z > -0.022:
            return BADGE_TREE
        return (0.92, 0.95, 0.98)
    common.color_by(disc, colour, smooth=False)
    return disc


def hands_and_feet():
    rigid = []
    for h, bone in chibi.hands(SKIN, radius=0.092):
        # Fingerless gloves (Ekko): leather over the palm, skin fingertips.
        common.color_by(h, lambda p, n: SKIN if abs(p.x) > 0.905 else GLOVE, smooth=False)
        rigid.append((h, bone))
    for s, bone in ((1, "foot.l"), (-1, "foot.r")):
        for part in chibi.boot(s, BOOT, SOLE, BOOT_TOE, LACE, accent=BOOT_ACCENT, scale=1.3):
            rigid.append((part, bone))
        sock = chibi.tube([(s * 0.17, 0.02, 0.27), (s * 0.17, 0.02, 0.14)], [0.07, 0.074], name="sock", levels=1)
        common.set_color(sock, SOCK)
        rigid.append((sock, "lowerleg." + bone[-1]))
        # Shin wraps criss-crossing above the shoes (Ekko).
        for k in range(4):
            z = 0.17 + k * 0.03
            ring = chibi.torus((s * 0.17, 0.02, z), 0.076, 0.011, name="shinwrap", segs=(16, 6))
            ring.data.transform(Matrix.Translation((s * 0.17, 0.02, z)) @ Matrix.Rotation(0.25 * (-1) ** k, 4, "X")
                                @ Matrix.Translation((-s * 0.17, -0.02, -z)))
            common.set_color(ring, SHIN_WRAP)
            rigid.append((ring, "lowerleg." + bone[-1]))
    return rigid


def accessories():
    """Ekko-flavoured street details on the artwork's outfit: a teal
    neckerchief knotted at the side, bandage wraps on both forearms, a
    lime wrist band and one teal knee pad (asymmetry reads as attitude)."""
    rigid = []
    kerchief = chibi.tube([(0.11 * math.cos(a), 0.1 * math.sin(a) - 0.01, 1.2 - 0.03 * math.sin(a))
                           for a in [k / 12 * math.tau for k in range(13)]], [0.03] * 13, name="kerchief", levels=1)
    knot = chibi.ellipsoid((-0.085, -0.085, 1.16), (0.04, 0.035, 0.035), name="knot", segs=(12, 8))
    tails = [chibi.curved_lock((-0.09, -0.1, 1.15), d, 0.12, 0.035, bend=(0, -0.02, 0.01), name="tail")
             for d in ((-0.3, -0.4, -1.0), (0.15, -0.5, -1.0))]
    for part in [kerchief, knot] + tails:
        common.color_by(part, lambda p, n: common.lerp(TEAL, TEAL_DARK, max(0.0, -n.z) * 0.6))
        rigid.append((part, "chest"))
    for side, bone in ((1, "lowerarm.l"), (-1, "lowerarm.r")):
        for k in range(6):
            x = 0.5 + k * 0.042
            ring = chibi.torus((side * x, 0, 1.11), 0.064, 0.013, name="wrap", axis="X", segs=(16, 6))
            ring.data.transform(Matrix.Translation((side * x, 0, 1.11)) @ Matrix.Rotation(0.18 * (-1) ** k, 4, "Z")
                                @ Matrix.Translation((-side * x, 0, -1.11)))
            common.set_color(ring, WRAP)
            rigid.append((ring, bone))
    band = chibi.torus((0.77, 0, 1.11), 0.066, 0.02, name="band", axis="X", segs=(16, 6))
    common.set_color(band, LIME)
    rigid.append((band, "lowerarm.l"))
    pad = chibi.ellipsoid((-0.17, -0.075, 0.27), (0.075, 0.035, 0.06), name="kneepad", segs=(14, 8))
    common.color_by(pad, lambda p, n: TEAL if n.y < -0.3 else TEAL_DARK, smooth=False)
    rigid.append((pad, "lowerleg.r"))
    return rigid


# ----------------------------------------------------------------- head

F, R, U = Vector((0, -1, 0)), Vector((-1, 0, 0)), Vector((0, 0, 1))  # forward, his right, up


def clump(parts, root, up, controls, width, length_ratio=None, thickness=0.55, colour=None, steps=7):
    pts = chibi.sweep(root, controls, steps=steps)
    widths = [width * (1.0 - (i / (steps - 1)) ** 1.6) * (0.85 + 0.3 * math.sin(math.pi * i / (steps - 1)))
              for i in range(steps)]
    widths[-1] = 0.0
    obj = chibi.hair_clump(pts, widths, thickness, up, name="clump")
    length = sum((pts[i + 1] - pts[i]).length for i in range(steps - 1))
    common.color_by(obj, colour or chibi.lock_colour(root, length, HAIR_LIGHT, HAIR, HAIR_DARK))
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

    # Ekko-style upswept quiff bursting out of the (pushed-back) cap's
    # front opening: big clumps rising up and curling back, tallest in
    # the middle, plus one rebel strand falling over his forehead.
    for k, (yaw, height, width) in enumerate(((0.42, 0.22, 0.075), (0.21, 0.31, 0.09), (0.0, 0.37, 0.095),
                                              (-0.2, 0.33, 0.09), (-0.4, 0.24, 0.078))):
        root, n = HEAD.point(yaw, 0.7, -0.014)
        lean = 0.04 + 0.03 * k  # the swoosh leans to his right, more on that side
        controls = [root + F * 0.08 + U * height * 0.4,
                    root + F * 0.03 + U * height * 0.9 + R * lean,
                    root - F * 0.12 + U * height * 0.95 + R * (lean + 0.08)]
        clump(parts, root, F, controls, width, thickness=0.62)
    # A couple of smaller spikes layered in front for depth.
    for yaw, height in ((0.14, 0.22), (-0.1, 0.2)):
        root, n = HEAD.point(yaw, 0.62, -0.01)
        clump(parts, root, F, [root + F * 0.08 + U * 0.08, root + F * 0.07 + U * height + R * 0.05,
                               root - F * 0.02 + U * (height + 0.02) + R * 0.12], 0.07, thickness=0.6)
    # Tight sides over the ears and a short nape, flicking out at the tips.
    for side in (-1, 1):
        out = Vector((side, 0, 0))
        for yaw in (1.35, 1.6, 1.85, 2.1):
            root, n = HEAD.point(side * yaw, 0.38, -0.01)
            back = Vector((0, 1, 0)) * (0.02 + 0.03 * (yaw - 1.35))
            clump(parts, root, n, [root - U * 0.05 + out * 0.02, root - U * 0.09 + out * 0.03 + back,
                                   root - U * 0.1 + out * 0.05 + back * 1.5], 0.055)
    for yaw in (2.45, 2.8, 3.14, 3.48, 3.83):
        root, n = HEAD.point(yaw, 0.1, -0.01)
        outv = (root - c)
        outv.z = 0
        outv.normalize()
        clump(parts, root, n, [root - U * 0.08 + outv * 0.02, root - U * 0.14 + outv * 0.05,
                               root - U * 0.15 + outv * 0.1], 0.065)

    # Backwards cap: snug crown, cut higher at the front.
    cap_c = c + Vector((0, 0.012, 0.035))
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
    tilt = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(-10), 4, "X") @ Matrix.Translation(-pivot)
    for obj in (dome, button, brim, strap):
        obj.data.transform(tilt)
    parts.append(strap)
    return parts


def ears():
    parts = []
    for side in (-1, 1):
        p, n = HEAD.point(side * 1.5, -0.08)
        e = chibi.ellipsoid((0, 0, 0), (0.024, 0.038, 0.052), name="ear", segs=(16, 10))
        e.data.transform(Matrix.Translation(p + n * 0.012) @ Matrix.Rotation(side * -0.35, 4, "Z")
                         @ Matrix.Rotation(-0.25, 4, "X"))
        common.color_by(e, lambda pos, nrm, n=n: SKIN_SHADE if nrm.dot(n) > 0.6 else SKIN, smooth=False)
        parts.append(e)
    return parts


def head_piece():
    face_paint.paint_face(FACE, FACE_PNG)
    head = chibi.sculpt_head(HEAD, SKIN, SKIN_SHADE, BLUSH, jaw=0.17, chin_len=0.08, chin_fwd=0.1,
                             cheekbone=0.12, face_flat=0.14, blush_yaw=0.5, blush_pitch=-0.3, blush_size=0.01,
                             layout=FACE, features=FEATURES)
    chibi.face_uv(head, HEAD, FACE)
    ear_parts = ears()
    for part in ear_parts:
        chibi.no_face_uv(part)
    hair = hair_and_cap()
    chibi.report([head] + ear_parts + hair)
    # Separate textures: the face gets most of the head's texels.
    return common.join([head] + ear_parts, "Leo_Head"), common.join(hair, "Leo_Hair")


# ----------------------------------------------------------------- gear

def backpack():
    parts = []
    bag = chibi.box((0.54, 0.3, 0.62), (0, 0.41, 0.94), bevel=0.1, name="pack")
    common.color_by(bag, camo, smooth=False)
    parts.append(bag)
    flap = chibi.box((0.56, 0.33, 0.14), (0, 0.415, 1.23), bevel=0.05, name="flap")
    common.color_by(flap, lambda p, n: common.lerp(camo(p, n), (0.1, 0.12, 0.06), 0.35), smooth=False)
    parts.append(flap)
    pocket = chibi.box((0.36, 0.1, 0.26), (0, 0.58, 0.82), bevel=0.04, name="pocket")
    common.color_by(pocket, camo, smooth=False)
    parts.append(pocket)
    for sx in (-0.13, 0.13):
        buckle = chibi.box((0.05, 0.14, 0.2), (sx, 0.6, 1.05), bevel=0.01, name="buckle")
        common.color_by(buckle, lambda p, n: (0.1, 0.1, 0.1) if 1.0 < p.z < 1.03 else STRAP, smooth=False)
        parts.append(buckle)
    parts.append(chibi.bedroll((0, 0.4, 1.38), 0.66, 0.105, BEDROLL, STRAP))
    bottle = chibi.cylinder((0.31, 0.42, 0.84), 0.062, 0.25, name="bottle", bevel=0.02)
    common.color_by(bottle, lambda p, n: (0.2, 0.2, 0.22) if p.z > 0.94 else
                    ((0.3, 0.32, 0.36) if 0.8 < p.z < 0.86 and n.x > 0.5 else STEEL), smooth=False)
    parts.append(bottle)
    parts += chibi.rope_coil((-0.32, 0.4, 0.84), 0.1, ROPE, loops=4, axis="X")
    clip = chibi.torus((-0.33, 0.36, 1.0), 0.035, 0.009, name="carabiner", axis="X", segs=(14, 6))
    common.set_color(clip, RED)
    parts.append(clip)
    parts += chibi.straps(STRAP, top_y=0.22, front_y=-0.215, xs=(-0.15, 0.15), shoulder_z=1.21, bottom_z=0.74)
    sternum = chibi.box((0.32, 0.02, 0.028), (0, -0.215, 1.06), bevel=0.006, name="sternum")
    common.set_color(sternum, STRAP)
    parts.append(sternum)
    return parts


def stick(rig, down):
    """Knotty walking stick in the handslot.r frame: local +X points down
    in the idle pose; `down` is the hand's height, so it reaches the
    ground. A carved knob on top, rope grip and two leaves."""
    to_world = chibi.bone_frame(rig, "handslot.r")
    top = 0.55
    pts, radii = [], []
    for k in range(11):
        t = k / 10
        x = -top + t * (top + down)
        wob = Vector((0, noise.noise(Vector((t * 4, 1, 0))) * 0.035, noise.noise(Vector((t * 4, 5, 0))) * 0.035))
        pts.append(Vector((x, 0, 0)) + wob)
        knot = 0.008 if k in (3, 6, 8) else 0.0
        radii.append(0.036 - t * 0.01 + knot)
    shaft = chibi.tube(pts, radii, name="stick", levels=1)
    knob = chibi.ellipsoid(pts[0] + Vector((-0.04, 0, 0)), (0.08, 0.058, 0.058), name="knob", segs=(16, 12))
    spur = chibi.curved_lock(pts[2], (-0.5, 0.7, 0.2), 0.12, 0.018, name="spur")
    body = common.join([shaft, knob, spur], "stick")
    common.color_by(body, lambda p, n: BARK_LIGHT if noise.noise(Vector((p.x * 30, p.y * 4, p.z * 4))) > 0.2 else BARK,
                    smooth=False)
    parts = [body]
    for x in (-0.07, -0.03, 0.01, 0.08):
        wrap = chibi.torus((x, 0, 0), 0.04, 0.011, name="wrap", axis="X", segs=(14, 6))
        common.set_color(wrap, ROPE)
        parts.append(wrap)
    for x, ang in ((pts[1].x, 0.6), (pts[2].x + 0.03, -0.9)):
        leaf = chibi.ellipsoid((0, 0.07, 0), (0.026, 0.06, 0.007), name="leaf", segs=(10, 6))
        leaf.data.transform(Matrix.Translation((x, 0, 0)) @ Matrix.Rotation(ang, 4, "X"))
        common.set_color(leaf, LEAF)
        parts.append(leaf)
    obj = common.join(parts, "Leo_Stick")
    obj.data.transform(to_world)
    return obj


def build():
    rig = chibi.load_rig()
    soft = [skin_piece(), shirt_piece(), shorts_piece()]
    rigid = hands_and_feet()
    rigid.append((badge(), "chest"))
    for part in chibi.compass((0, -0.228, 0.98), GOLD, neck_z=1.22, radius=0.042):
        rigid.append((part, "chest"))
    rigid += accessories()
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
    if chibi.quick_mode():
        for mesh in meshes:
            chibi.quick_material(mesh, overlay=(FACE_PNG, "FaceUV") if mesh is head else None)
        print("leo tris:", common.triangle_count(meshes))
        render_previews(rig, meshes, head, "leo", ("Running_A", 8), ("1H_Melee_Attack_Chop", 14), ("PickUp", 12), ("Death_A", 40))
        return
    params = dict(size=1024, ao_distance=0.18, ao_strength=0.65, edge_strength=0.3, edge_radius=0.012,
                  noise_scale=6.0, stroke_strength=0.08, light=(1.12, 1.04, 0.94), shadow=(0.42, 0.36, 0.55),
                  foot_darken=0.4, foot_height=1.1, key_light=(-0.4, -0.6, 0.8), key_strength=0.45)
    for mesh in meshes:
        # Softer occlusion on the head so the fringe doesn't smudge the face.
        extra = dict(ao_strength=0.45, ao_distance=0.05, overlay=(FACE_PNG, "FaceUV"), cavity=0.3) \
            if mesh is head else dict(cavity=0.2)
        paint_bake.paint(mesh, source="attribute", **dict(params, **extra))
    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "leo.glb"), [rig] + meshes, animations=True)
    print("leo tris:", common.triangle_count(meshes))
    render_previews(rig, meshes, head, "leo", ("Running_A", 8), ("1H_Melee_Attack_Chop", 14))


def render_previews(rig, meshes, head, name, *actions):
    rig.data.pose_position = "REST"
    preview.render(meshes, name, elevation=10, azimuth=25)
    preview.render([head], name + "_face", elevation=4, azimuth=12, size=512)
    preview.render(meshes, name + "_back", elevation=15, azimuth=160, size=384)
    rig.data.pose_position = "POSE"
    rig.animation_data_create()
    for action_name, frame in (("Idle", 1),) + actions:
        rig.animation_data.action = bpy.data.actions.get(action_name)
        preview.render(meshes, name + "_" + action_name, frame=frame, elevation=10, azimuth=25, size=384)


if __name__ == "__main__":
    build()
