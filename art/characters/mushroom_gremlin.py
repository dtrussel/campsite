"""Mushroom Gremlin: a small, quick thief that sneaks into camp, grabs
resources and runs.

Feature 027 remodel, after the concept in
.features/027-gremlin-remodel/reference/concept.png: a cheeky mushroom
goblin rather than a walking mushroom.
- a big, wide conical cap (purple, darker mottling, cream blocky spots,
  pale pleated gills), tipped back a little so the face shows;
- the face under the cap: big amber glowing eyes with sly pupils,
  mischievous brows, a small hooked nose, a lopsided grin with one fang,
  freckles and blush;
- long pointed ears sticking out sideways, wider than the face;
- a slim, pale, spotted body with a small belly, long thin arms, big
  clawed hands, and long clawed feet;
- a satchel strap across the chest to a leaf pouch on the hip, a tiny
  mushroom peeking out;
- a high-to-low bake like the imp. HIGH_POLY=1 keeps the dense mesh.

Built on the KayKit Skeleton_Minion rig. The gremlin's own clips come
from characters/gremlin_anims.py. Output:
game/assets/custom/mushroom_gremlin.glb"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from characters import chibi  # noqa: E402
from characters.shadow_imp import DEFORM, bone_points, curved_tube, rigid  # noqa: E402
from characters.bramble_beast import _smooth01, leaf, place, surface_point  # noqa: E402

SKIN = (0.8, 0.75, 0.68)
SKIN_SHADE = (0.64, 0.58, 0.54)
SKIN_DARK = (0.6, 0.54, 0.5)
SPOT = (0.55, 0.42, 0.5)
BLUSH = (0.78, 0.5, 0.58)
NOSE = (0.74, 0.56, 0.42)
BROW = (0.36, 0.27, 0.26)
MOUTH = (0.28, 0.1, 0.14)
FANG = (1.0, 0.97, 0.9)
CLAW = (0.3, 0.22, 0.2)
INNER_EAR = (0.93, 0.7, 0.62)
CAP = (0.33, 0.08, 0.45)
CAP_DARK = (0.2, 0.04, 0.3)
CAP_LIGHT = (0.46, 0.16, 0.57)
CAP_SPOT = (0.95, 0.9, 0.76)
GILL = (0.86, 0.74, 0.7)
GILL_DARK = (0.66, 0.52, 0.52)
POUCH = (0.4, 0.48, 0.2)
POUCH_DARK = (0.26, 0.32, 0.12)
STRAP = (0.5, 0.42, 0.26)
EYE = (1.0, 0.62, 0.1)
PUPIL = (0.14, 0.06, 0.02)

## Triangle budget of the game mesh (with the eyes, 9k at most).
BODY_BUDGET = 7000

HEAD_C = Vector((0, -0.02, 1.42))
EYE_Z = 1.45
EYE_X = 0.12
MOUTH_Z = 1.3
CAP_BASE = 1.6
CAP_R = 0.48
CAP_H = 0.42
CAP_TILT = math.radians(-18)   # brim up at the front, so the face shows


# -------------------------------------------------------------- body

# Metaball radii: a lone ball's surface sits at about 0.58 of its radius
# (threshold 0.6, stiffness 2); chains of balls along a bone overlap and
# come out at about 0.7.
BODY_RADII = {
    "upperleg": (0.13, 0.1), "lowerleg": (0.095, 0.085), "foot": (0.092, 0.08), "toes": (0.075, 0.05),
    "upperarm": (0.095, 0.078), "lowerarm": (0.075, 0.07), "wrist": (0.078, 0.08), "hand": (0.098, 0.07),
}


def body_mesh(rig):
    elements = []
    for bone in rig.data.bones:
        key = bone.name.split(".")[0]
        if key not in BODY_RADII:
            continue
        r0, r1 = BODY_RADII[key]
        head, tail = bone_points(rig, bone.name)
        steps = max(2, int((tail - head).length / 0.025))
        for i in range(steps + 1):
            t = i / steps
            elements.append((head.lerp(tail, t), r0 + (r1 - r0) * t, 2.0))
    elements += [
        ((0, 0.02, 0.56), 0.3, 2.0, "ELLIPSOID", (1.15, 0.95, 0.9)),    # hips
        ((0, -0.04, 0.72), 0.32, 2.0, "ELLIPSOID", (1.0, 0.95, 1.05)),  # small belly
        ((0, 0.0, 0.93), 0.29, 2.0, "ELLIPSOID", (1.15, 0.85, 1.0)),    # narrow chest
        ((0.18, 0.0, 1.08), 0.14, 2.0),                                 # shoulders
        ((-0.18, 0.0, 1.08), 0.14, 2.0),
        ((0, 0.0, 1.16), 0.16, 2.0),                                    # neck
        (tuple(HEAD_C), 0.52, 2.0, "ELLIPSOID", (1.05, 0.95, 0.97)),    # big head
        ((0.14, -0.19, 1.34), 0.17, 1.6),                               # cheeks
        ((-0.14, -0.19, 1.34), 0.17, 1.6),
        ((0, -0.2, 1.27), 0.16, 1.6),                                   # chin
    ]
    for joint, r in (("lowerleg.l", 0.13), ("lowerleg.r", 0.13), ("lowerarm.l", 0.1), ("lowerarm.r", 0.1)):
        head, _tail = bone_points(rig, joint)
        elements.append((head, r, 1.2))
    body = common.metaball_object("MushroomGremlin", elements, resolution=0.02, threshold=0.6)
    common.voxel_remesh(body, voxel=0.011, smooth_iterations=3)
    return body


def _in_face(pos, normal):
    return normal.y < -0.15 and 1.18 < pos.z < 1.7 and abs(pos.x) < 0.3


def _brow_z(x):
    """Mischievous brows: low at the inner end, raised at the outer end."""
    ax = abs(x)
    return EYE_Z + 0.085 + (ax - EYE_X) * 0.45


def _mouth_z(x):
    """A lopsided grin, curling up on its left (+x)."""
    return MOUTH_Z + 3.0 * x * x + 0.12 * max(0.0, x)


def face_offset(pos, normal):
    if not _in_face(pos, normal):
        return 0.0
    front = _smooth01((-normal.y - 0.15) * 3.0)
    d = 0.0
    ax = abs(pos.x)
    # Shallow almond sockets.
    for side in (-1, 1):
        r = ((pos.x - side * EYE_X) / 0.095) ** 2 + ((pos.z - EYE_Z) / 0.07) ** 2
        if r < 1.5:
            d -= 0.03 * _smooth01((1.5 - r) / 1.0)
    # Brow ridges.
    if 0.03 < ax < 0.24:
        d += 0.022 * math.exp(-((pos.z - _brow_z(pos.x)) / 0.018) ** 2)
    # The grin.
    if -0.13 < pos.x < 0.16:
        d -= 0.018 * math.exp(-((pos.z - _mouth_z(pos.x)) / 0.016) ** 2)
    return d * front


def sculpt(body):
    mesh = body.data
    for v in mesh.vertices:
        v.co = v.co + v.normal * face_offset(v.co, v.normal)
    mesh.update()
    common.shade_smooth(body)


def colour_body(body):
    def colour(pos, normal):
        n = noise.noise(pos * 5.0)
        c = common.lerp(SKIN, SKIN_SHADE, _smooth01(0.3 - normal.z * 0.3 + n * 0.3))
        # Darker hands and feet.
        if abs(pos.x) > 0.74 or pos.z < 0.1:
            c = common.lerp(c, SKIN_DARK, 0.5)
        # Purple-brown spots on the shoulders, arms, legs and back.
        s = noise.noise(pos * 11.0 + Vector((3, 7, 1)))
        spotty = pos.y > -0.05 or abs(pos.x) > 0.25 or pos.z < 0.5
        if spotty and s > 0.38 and not _in_face(pos, normal):
            c = common.lerp(c, SPOT, _smooth01((s - 0.38) * 8.0) * 0.8)
        if _in_face(pos, normal):
            ax = abs(pos.x)
            # Blush and freckles on the cheeks.
            for side in (-1, 1):
                r = ((pos.x - side * 0.16) / 0.07) ** 2 + ((pos.z - 1.36) / 0.045) ** 2
                if r < 1.0:
                    c = common.lerp(c, BLUSH, (1.0 - r) * 0.55)
                    if noise.noise(pos * 60.0) > 0.45:
                        c = common.lerp(c, SPOT, 0.7)
            # Brows.
            if 0.035 < ax < 0.22:
                c = common.lerp(c, BROW, _smooth01((0.017 - abs(pos.z - _brow_z(pos.x))) / 0.008))
            # The grin.
            if -0.12 < pos.x < 0.15:
                ends = _smooth01(min(pos.x + 0.12, 0.15 - pos.x) / 0.03)
                c = common.lerp(c, MOUTH, _smooth01((0.014 - abs(pos.z - _mouth_z(pos.x))) / 0.007) * ends)
        return c
    common.color_by(body, colour)


# ------------------------------------------------------------ extras

def cap():
    """A wide conical cap with a rolled rim and pleated gills beneath."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=1.0)
    for v in bm.verts:
        rho = min(1.0, math.hypot(v.co.x, v.co.y))
        wob = 1.0 + noise.noise(v.co * 2.5) * 0.05
        if v.co.z >= 0:
            z = CAP_H * (1.0 - rho ** 1.7) ** 0.75
        else:
            z = -0.035 + 0.16 * (1.0 - rho ** 2)
        v.co = Vector((v.co.x * CAP_R * wob, v.co.y * CAP_R * wob, z))
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(CAP_TILT, 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0.03, CAP_BASE))
    obj = common.mesh_object("cap", bm)
    common.shade_smooth(obj)
    tilt_inv = Matrix.Rotation(-CAP_TILT, 3, "X")

    def colour(pos, normal):
        local = tilt_inv @ (pos - Vector((0, 0.03, CAP_BASE)))
        rho = math.hypot(local.x, local.y) / CAP_R
        ang = math.atan2(local.y, local.x)
        if local.z < 0.0 + 0.16 * (1 - rho ** 2) - 0.02 and (tilt_inv @ normal).z < 0.2:
            # Gills: radial pleats.
            pleat = math.sin(ang * 46.0)
            return common.lerp(GILL, GILL_DARK, _smooth01(0.3 + pleat * 0.5 + (1 - rho) * 0.4))
        m = noise.noise(pos * 4.0)
        c = common.lerp(CAP, CAP_DARK, _smooth01(0.4 + m * 0.9 - (tilt_inv @ normal).z * 0.3))
        if noise.noise(pos * 7.0 + Vector((9, 2, 4))) > 0.35:
            c = common.lerp(c, CAP_LIGHT, 0.45)
        # Blocky cream spots: a cell grid in (angle, height) space.
        cu = ang / math.tau * 10.0
        cv = rho * 3.2
        iu, iv = math.floor(cu), math.floor(cv)
        h = (math.sin(iu * 12.9898 + iv * 78.233) * 43758.5453) % 1.0
        if h > 0.5 and 0 < iv < 3:
            du, dv = cu - iu - 0.5, cv - iv - 0.5
            size = 0.27 + 0.05 * noise.noise(pos * 20.0)
            if max(abs(du), abs(dv) * 1.2) < size:
                c = CAP_SPOT
        return c
    common.color_by(obj, colour, smooth=False)
    return obj


def ear(side, body):
    """A long, flat, pointed ear sticking out sideways, drooping a little
    and curling up at the tip; the pink inner side faces forward."""
    length, width = 0.66, 0.25
    rows, cols = 12, 6
    bm = bmesh.new()
    grid = []
    for i in range(rows + 1):
        t = i / rows
        w = width * (1.0 - t) ** 0.85 * (0.75 + 0.5 * math.sin(math.pi * min(1.0, t * 1.6)))
        droop = -0.07 * t * t + 0.06 * max(0.0, t - 0.8) / 0.2 * t
        row = []
        for j in range(-cols, cols + 1):
            u = j / cols
            x = t * length
            z = u * w * 0.5 + droop + 0.03 * t
            y = -0.035 * (1 - u * u) * (1 - t)   # cupped toward the front
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for i in range(rows):
        for j in range(2 * cols):
            bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    obj = common.mesh_object("ear", bm)
    solid = obj.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = 0.03
    solid.offset = 0.0
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    loc, _n = surface_point(body, HEAD_C + Vector((0, 0.02, -0.03)), Vector((side, 0.05, 0.0)))
    base = loc - Vector((side * 0.05, 0, 0))
    # Mirror for the right ear, tip back a little and up.
    obj.scale = (side, 1, 1)
    obj.rotation_euler = (0, math.radians(-8 * side), math.radians(side * 12))
    obj.location = base
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if side < 0:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.flip_normals()
        bpy.ops.object.mode_set(mode="OBJECT")

    def colour(pos, normal):
        c = common.lerp(SKIN, SKIN_SHADE, _smooth01(0.3 - normal.z * 0.3))
        t = abs(pos.x - base.x) / length
        if normal.y < -0.3 and t < 0.8:
            c = common.lerp(c, INNER_EAR, _smooth01((0.8 - t) * 3.0) * 0.8)
        if noise.noise(pos * 14.0) > 0.42:
            c = common.lerp(c, SPOT, 0.6)
        return c
    common.color_by(obj, colour, smooth=False)
    return obj


def nose(body):
    """A small hooked nose: out from the face, then down."""
    loc, normal = surface_point(body, HEAD_C + Vector((0, 0, 0.0)), Vector((0, -1, -0.05)))
    base = loc - normal * 0.02
    pts = [base, base + Vector((0, -0.06, 0.005)), base + Vector((0, -0.095, -0.03)), base + Vector((0, -0.085, -0.065))]
    obj = curved_tube(pts, [0.045, 0.04, 0.03, 0.014], "nose")

    def colour(pos, n):
        return common.lerp(NOSE, SKIN_SHADE, _smooth01(-n.z * 0.6 + 0.1))
    common.color_by(obj, colour, smooth=False)
    return obj


def fang(body):
    """One little fang poking down from the grin (its left side)."""
    x = 0.075
    loc, normal = surface_point(body, Vector((x, -0.05, _mouth_z(x))), Vector((0, -1, 0)))
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.014, radius2=0.0, depth=0.04)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi, 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=loc + normal * 0.006 + Vector((0, 0, -0.018)))
    obj = common.mesh_object("fang", bm)
    common.set_color(obj, FANG)
    return obj


def claw(tip, direction, length=0.04, radius=0.012):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=radius, radius2=0.0, depth=length)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, length / 2))
    obj = common.mesh_object("claw", bm)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    obj.location = tip
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    common.set_color(obj, CLAW)
    return obj


def hands(rig):
    """Three long fingers and a thumb per hand, each with a dark claw."""
    out = []
    for side in (-1, 1):
        s = "l" if side > 0 else "r"
        _h, tip = bone_points(rig, "hand." + s)
        for k, dy in enumerate((-0.04, 0.0, 0.04)):
            root = tip + Vector((-side * 0.03, dy, 0.0))
            length = 0.11 if k == 1 else 0.095
            pts = [root, root + Vector((side * length * 0.55, dy * 0.3, -0.005)),
                   root + Vector((side * length, dy * 0.5, -0.035))]
            f = curved_tube(pts, [0.024, 0.019, 0.013], "finger")
            common.set_color(f, SKIN_DARK)
            out.append((f, "hand." + s))
            out.append((claw(pts[-1] - Vector((side * 0.004, 0, 0)), Vector((side * 0.35, 0, -1.0)), 0.04, 0.012), "hand." + s))
        root = tip + Vector((-side * 0.07, -0.045, -0.01))
        pts = [root, root + Vector((side * 0.02, -0.05, -0.01)), root + Vector((side * 0.035, -0.08, -0.03))]
        th = curved_tube(pts, [0.024, 0.018, 0.012], "thumb")
        common.set_color(th, SKIN_DARK)
        out.append((th, "hand." + s))
        out.append((claw(pts[-1], Vector((0.1 * side, -0.4, -1.0)), 0.035, 0.011), "hand." + s))
    return out


def toes(rig):
    """Three long toes per foot with dark claws."""
    out = []
    for side in (-1, 1):
        s = "l" if side > 0 else "r"
        head, tail = bone_points(rig, "toes." + s)
        for dx in (-0.045, 0.0, 0.045):
            root = head.lerp(tail, 0.4) + Vector((dx, 0, 0.0))
            pts = [root, root + Vector((dx * 0.4, -0.08, -0.005)), root + Vector((dx * 0.6, -0.14, -0.012))]
            t = curved_tube(pts, [0.03, 0.025, 0.018], "toe")
            common.set_color(t, SKIN_DARK)
            out.append((t, "toes." + s))
            out.append((claw(pts[-1] + Vector((0, -0.01, 0.0)), Vector((0, -1.0, -0.35)), 0.04, 0.014), "toes." + s))
    return out


def satchel(body):
    """A strap over the right shoulder, across the chest, to a leaf pouch
    on the left hip with a tiny mushroom peeking out."""
    parts = []
    strap_pts = []
    for i in range(10):
        t = i / 9
        p = Vector((-0.15 + 0.36 * t, 0.0, 1.08 - 0.46 * t))
        loc, normal = surface_point(body, p * Vector((0.3, 0, 1)) + Vector((0, 0, 0)), Vector((p.x, -1.0, 0.0)))
        strap_pts.append(loc + normal * 0.012)
    back = []
    for i in range(6):
        t = i / 5
        p = Vector((-0.15 + 0.3 * t, 0.0, 1.08 - 0.4 * t))
        loc, normal = surface_point(body, p * Vector((0.3, 0, 1)), Vector((p.x, 1.0, 0.0)))
        back.append(loc + normal * 0.012)
    top, _n = surface_point(body, Vector((-0.12, 0.0, 1.0)), Vector((-0.2, 0.0, 1.0)))
    strap = curved_tube(list(reversed(back)) + [top + Vector((0, 0, 0.01))] + strap_pts, [0.014] * (len(back) + 1 + len(strap_pts)), "strap")
    common.set_color(strap, STRAP)
    parts.append(strap)
    # The pouch: a lumpy leaf bag with a darker vein and flap.
    loc, normal = surface_point(body, Vector((0.1, -0.02, 0.6)), Vector((1.0, -0.35, 0.0)))
    centre = loc + normal * 0.045
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=10, radius=0.1)
    for v in bm.verts:
        v.co.y *= 0.65
        v.co.z *= 0.9 if v.co.z > 0 else 1.1
        v.co += Vector((noise.noise(v.co * 8), 0, noise.noise(v.co * 8 + Vector((4, 0, 0))))) * 0.012
    bmesh.ops.translate(bm, verts=bm.verts, vec=centre)
    pouch = common.mesh_object("pouch", bm)
    common.shade_smooth(pouch)

    def colour(pos, n):
        rel = pos - centre
        c = common.lerp(POUCH, POUCH_DARK, _smooth01(0.3 - n.z * 0.4 + noise.noise(pos * 12) * 0.3))
        if abs(rel.x * 0.4 + rel.z * 0.9) < 0.006 or (rel.z > 0.03 and abs(math.sin(rel.x * 60)) < 0.12):
            c = common.lerp(c, POUCH_DARK, 0.7)
        return c
    common.color_by(pouch, colour, smooth=False)
    parts.append(pouch)
    # A tiny purple mushroom peeking out of the top.
    stem_base = centre + Vector((0.01, 0.0, 0.06))
    stem = curved_tube([stem_base, stem_base + Vector((0.005, 0, 0.05))], [0.016, 0.014], "shroom_stem")
    common.set_color(stem, SKIN)
    parts.append(stem)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.04)
    for v in bm.verts:
        v.co.z = max(v.co.z, -0.005) * 0.8
    bmesh.ops.translate(bm, verts=bm.verts, vec=stem_base + Vector((0.005, 0, 0.05)))
    tiny = common.mesh_object("shroom_cap", bm)
    common.shade_smooth(tiny)
    common.color_by(tiny, lambda p, n: CAP_SPOT if noise.noise(p * 70) > 0.4 else CAP, smooth=False)
    parts.append(tiny)
    return parts


def eyes(body):
    """Big amber almond eyes with round pupils glancing to the side."""
    glows, pupils = [], []
    for side in (-1, 1):
        loc, normal = surface_point(body, Vector((side * EYE_X * 0.6, -0.05, EYE_Z)), Vector((side * 0.25, -1.0, 0.0)))
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.07)
        for v in bm.verts:
            v.co.x *= 1.2
            v.co.z *= 1.0 - 0.3 * abs(v.co.x) / 0.084
            v.co.y *= 0.45
        # Outer corners up a touch: sly, not angry.
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(side * math.radians(-10), 3, "Y"))
        bmesh.ops.translate(bm, verts=bm.verts, vec=loc + normal * 0.004)
        glows.append(common.mesh_object("eye", bm))
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=8, radius=0.034)
        for v in bm.verts:
            v.co.y *= 0.4
        # Both pupils glance to its left (+x): up to something.
        bmesh.ops.translate(bm, verts=bm.verts, vec=loc + normal * 0.03 + Vector((0.03, 0, -0.004)))
        pupils.append(common.mesh_object("pupil", bm))
    glow = common.join(glows, "MushroomGremlin_Eyes")
    common.shade_smooth(glow)
    paint_bake.flat_material(glow, EYE, emission=3.2, name="gremlin_eye_glow")
    dark = common.join(pupils, "MushroomGremlin_Pupils")
    common.shade_smooth(dark)
    paint_bake.flat_material(dark, PUPIL, name="gremlin_pupil")
    return [glow, dark]


# ------------------------------------------------------------- build

def build():
    common.reset(27)
    bpy.ops.import_scene.gltf(filepath=os.path.join(common.KAYKIT, "skeletons", "Skeleton_Minion.glb"))
    rig = bpy.data.objects["Rig"]
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj)
    for bone in rig.data.bones:
        bone.use_deform = bone.name in DEFORM
    rig.data.pose_position = "REST"

    body = body_mesh(rig)
    sculpt(body)
    colour_body(body)

    rigid_parts = [(p, "head") for p in [cap(), ear(-1, body), ear(1, body), nose(body), fang(body)]]
    rigid_parts += hands(rig) + toes(rig)
    sat = satchel(body)
    rigid_parts += [(sat[0], "chest")] + [(p, "hips") for p in sat[1:]]
    eye_parts = eyes(body)

    common.select_only([body, rig])
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    extras = []
    for part, bone in rigid_parts:
        rigid(part, bone)
        extras.append(part)
    body = common.join([body] + extras, "MushroomGremlin")
    high = None if os.environ.get("HIGH_POLY") else chibi.lowpoly(body, BODY_BUDGET)
    paint_bake.paint(body, size=1024, ao_distance=0.15, ao_strength=0.6, edge_strength=0.3, edge_radius=0.012,
                     noise_scale=6.0, stroke_strength=0.08, cavity=0.2, light=(1.15, 1.08, 1.05),
                     shadow=(0.45, 0.4, 0.55), high=high)

    for obj in eye_parts:
        rigid(obj, "head")
        obj.parent = rig
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
    eye = common.join(eye_parts, "MushroomGremlin_Eyes")

    from characters import gremlin_anims
    gremlin_anims.build_actions(rig)

    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "mushroom_gremlin.glb"), [rig, body, eye], animations=True)
    print("mushroom_gremlin tris:", common.triangle_count([body, eye]))

    if os.environ.get("CLAY"):
        rig.data.pose_position = "REST"
        preview.render_clay([body, eye], "mushroom_gremlin")
        rig.data.pose_position = "POSE"
    rig.animation_data_create()
    for az in (-25, 90, 180):
        rig.animation_data.action = bpy.data.actions.get("Gremlin_Idle")
        preview.render([body, eye], "mushroom_gremlin_idle_%d" % az, frame=1, elevation=8, azimuth=az)
    for action_name, frames in gremlin_anims.PREVIEW_FRAMES.items():
        rig.animation_data.action = bpy.data.actions.get(action_name)
        for frame in frames:
            preview.render([body, eye], "mushroom_gremlin_%s_%02d" % (action_name, frame), frame=frame, elevation=10,
                           azimuth=-35, size=320, samples=12)


if __name__ == "__main__":
    build()
