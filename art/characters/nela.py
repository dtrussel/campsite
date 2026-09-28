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
from characters import chibi  # noqa: E402
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

HEAD = chibi.HeadFrame((0, -0.01, 1.6), (0.34, 0.32, 0.34))
PROP = chibi.Proportions(legs=1.15, spine=1.05, arms=1.0)


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
        chibi.ellipsoid((0, 0, 1.01), (0.24, 0.2, 0.21), name="chest"),
        chibi.ellipsoid((0, -0.03, 0.78), (0.28, 0.25, 0.27), name="belly"),
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
                                [0.15, 0.158, 0.118], name="pantleg", levels=2))
    pants = chibi.fuse(parts, "Pants", voxel=0.011, faces=5200)
    chibi.cut_open(pants, (0, 0, 0.175), (0, 0, -1))

    def colour(pos, normal):
        if pos.z < 0.225:
            return PANTS_DARK  # gathered cuff
        leg_x = 0.17 if pos.x > 0 else -0.17
        return folk_pattern(pos, leg_x)
    common.color_by(pants, colour, smooth=False)
    return pants


def cuffs():
    parts = []
    for s, bone in ((1, "lowerleg.l"), (-1, "lowerleg.r")):
        ring = chibi.torus((s * 0.175, 0.015, 0.2), 0.1, 0.03, name="cuff", segs=(22, 8))
        common.set_color(ring, PANTS_DARK)
        parts.append((ring, bone))
        sock = chibi.tube([(s * 0.17, 0.02, 0.22), (s * 0.17, 0.02, 0.13)], [0.074, 0.078], name="sock", levels=1)
        common.set_color(sock, SOCK)
        parts.append((sock, bone))
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


def curl_cloud():
    """A big soft cloud of curls around the sides, back and top: many
    overlapping balls fused into one shape (the face stays open)."""
    import random
    rnd = random.Random(5)
    c, r = HEAD.c, HEAD.r
    balls = []
    for pitch_i in range(9):
        pitch = -0.85 + pitch_i * 0.27
        count = max(4, int(15 * math.cos(pitch)))
        for k in range(count):
            yaw = -math.pi + (k + rnd.random() * 0.5) / count * math.tau
            # Keep the face open (and a little of the forehead for the bangs).
            if abs(yaw) < 1.0 and pitch < 0.62:
                continue
            if abs(yaw) < 1.35 and pitch < -0.3:
                continue
            p, n = HEAD.point(yaw, max(-0.6, pitch), 0.0)
            if pitch < -0.6:
                p = p + Vector((0, 0, (pitch + 0.6) * 0.25))  # hang lower at the back/sides
            size = 0.075 + rnd.random() * 0.035
            puff = 0.015 + 0.035 * max(0.0, 1.0 - abs(abs(yaw) - 1.6))  # widest at the sides
            balls.append(chibi.ellipsoid(p + n * (puff + size * 0.2), (size, size, size * 0.92), name="ball",
                                         segs=(14, 10)))
    balls.append(chibi.ellipsoid(c + Vector((0, 0.02, 0.02)), (r.x + 0.02, r.y + 0.03, r.z + 0.02), name="core",
                                 segs=(24, 16)))
    cloud = chibi.fuse(balls, "cloud", voxel=0.016, smooth=3, faces=3800)
    # Cut the face opening back out of the core.
    bm = bmesh.new()
    bm.from_mesh(cloud.data)
    kill = []
    for v in bm.verts:
        d = v.co - c
        d = Vector((d.x / r.x, d.y / r.y, d.z / r.z))
        if d.y < -0.55 and d.z < 0.6:
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(cloud.data)
    bm.free()
    common.shade_smooth(cloud)

    def colour(pos, normal):
        base = chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, c, scale=9.0, strands=40)(pos, normal)
        # Painted curl shading: darker between curls, sheen on their tops.
        n = noise.noise(pos * 18.0)
        return common.lerp(base, HAIR_DARK, max(0.0, -n) * 0.6) if n < 0 else common.lerp(base, HAIR_LIGHT, n * 0.5)
    common.color_by(cloud, colour)
    return cloud


def hair():
    c = HEAD.c
    parts = [curl_cloud()]
    # Curly bangs: short clumps that hook back up at the tips.
    for k, (yaw, length, width) in enumerate(((-0.6, 0.9, 0.06), (-0.34, 1.1, 0.072), (-0.1, 0.8, 0.066),
                                               (0.16, 1.15, 0.074), (0.42, 0.95, 0.066), (0.64, 0.8, 0.056))):
        root, n = HEAD.point(yaw, 0.74, -0.005)
        side = Vector((math.sin(yaw) + 0.25, 0, 0))
        controls = [root + F * 0.09 + U * 0.02 + side * 0.03,
                    root + F * 0.09 - U * 0.13 * length + side * 0.06,
                    root + F * 0.14 - U * 0.14 * length + side * 0.09,
                    root + F * 0.13 - U * 0.07 * length + side * 0.1]
        clump(parts, root, n, controls, width)
    # Springy corkscrew curls hanging at her sides.
    for side in (-1, 1):
        for yaw, drop in ((1.25, 0.2), (1.6, 0.26), (1.95, 0.22)):
            root, n = HEAD.point(side * yaw, -0.45, 0.06)
            out = Vector((side, 0, 0))
            controls = [root - U * drop * 0.3 + out * 0.07, root - U * drop * 0.6 - out * 0.02,
                        root - U * drop * 0.85 + out * 0.07, root - U * drop + out * 0.02]
            clump(parts, root, n, controls, 0.06)
    # Flyaways.
    for yaw, pitch, d in ((-1.0, 0.95, (-0.14, 0.02, 0.1)), (1.1, 0.9, (0.14, 0.04, 0.08)), (0.4, 1.2, (0.06, -0.04, 0.12))):
        root, n = HEAD.point(yaw, pitch, 0.05)
        dv = Vector(d)
        clump(parts, root, n, [root + dv * 0.5 + U * 0.03, root + dv, root + dv * 1.2 - U * 0.04], 0.028)
    # Top bun with a pink scrunchie.
    root, n = HEAD.point(math.pi, 1.05, 0.08)
    bun_c = root + n * 0.1
    bun = chibi.fuse([chibi.ellipsoid(bun_c + Vector(o), (0.075, 0.075, 0.07), name="bun", segs=(16, 10))
                      for o in ((0, 0, 0), (0.05, 0.02, 0.03), (-0.05, 0.01, 0.02), (0, -0.04, 0.05))],
                     "bun", voxel=0.012, smooth=1, faces=900)
    common.color_by(bun, chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, bun_c, scale=12.0, strands=18))
    parts.append(bun)
    tie = chibi.torus((0, 0, 0), 0.06, 0.026, name="tie", segs=(18, 8))
    for v in tie.data.vertices:
        v.co.z += 0.006 * math.sin(math.atan2(v.co.y, v.co.x) * 7)  # scrunched
    tie.data.transform(Matrix.Translation(root + n * 0.03) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4())
    common.set_color(tie, TIE)
    parts.append(tie)
    return parts


def face():
    parts = []
    for side in (-1, 1):
        parts += chibi.almond_eye(HEAD, side * 0.37, -0.1, side, 0.066, 0.056, IRIS, IRIS_DARK, LASH, tilt=0.02,
                                  iris_r=0.047, look=(0.0, 0.006), lower_lid=(0.8, 0.45, 0.45), flicks=2, name="eye")
        parts.append(chibi.brow(HEAD, side * 0.37, 0.34, side, BROW, width=0.065, arch=0.02, thick=0.012, tilt=-0.08))
    parts += chibi.smile(HEAD, -0.5, 0.058, 0.042, 0.004, curve=3.2)
    parts.append(chibi.nose(HEAD, SKIN, pitch=-0.3))
    for side in (-1, 1):
        p, n = HEAD.point(side * 1.5, -0.15)
        e = chibi.ellipsoid(p + n * 0.01, (0.035, 0.03, 0.05), name="ear", segs=(14, 8))
        common.set_color(e, SKIN)
        parts.append(e)
    return parts


def head_piece():
    head = chibi.sculpt_head(HEAD, SKIN, SKIN_SHADE, BLUSH, jaw=0.42, chin_len=0.1, chin_fwd=0.05, cheeks=0.14,
                             face_flat=0.06, blush_yaw=0.55, blush_pitch=-0.38, blush_size=0.1)
    parts = [head] + face() + hair()
    chibi.report(parts)
    return common.join(parts, "Nela_Head")


# ----------------------------------------------------------------- gear

def bunny():
    """Her plush bunny peeking out of the backpack (her right side)."""
    parts = []
    c = Vector((-0.17, 0.4, 1.36))
    head = chibi.ellipsoid(c, (0.1, 0.09, 0.09), name="bunny", segs=(20, 12))
    common.set_color(head, BUNNY)
    parts.append(head)
    muzzle = chibi.ellipsoid(c + Vector((0, -0.075, -0.02)), (0.05, 0.03, 0.035), name="bunny", segs=(14, 8))
    common.set_color(muzzle, (1.0, 0.95, 0.9))
    parts.append(muzzle)
    nose = chibi.ellipsoid(c + Vector((0, -0.105, 0.0)), (0.015, 0.01, 0.01), name="bunny_nose", segs=(8, 6))
    common.set_color(nose, BUNNY_INNER)
    parts.append(nose)
    for s in (-1, 1):
        eye = chibi.ellipsoid(c + Vector((s * 0.04, -0.078, 0.025)), (0.012, 0.008, 0.014), name="bunny_eye", segs=(8, 6))
        common.set_color(eye, (0.08, 0.05, 0.05))
        parts.append(eye)
        ear = chibi.ellipsoid((0, 0, 0.12), (0.032, 0.015, 0.12), name="bunny_ear", segs=(14, 8))
        common.color_by(ear, lambda p, n: BUNNY_INNER if n.y < -0.5 and abs(p.x) < 0.02 else BUNNY, smooth=False)
        ear.data.transform(Matrix.Translation(c + Vector((s * 0.045, 0.01, 0.05)))
                           @ Matrix.Rotation(s * -0.35 + (0.9 if s < 0 else 0.0), 4, "Y"))
        parts.append(ear)
    for part in parts:
        part.data.transform(Matrix.Translation(c) @ Matrix.Scale(1.35, 4) @ Matrix.Translation(-c))
        part.data.transform(Matrix.Translation((0, 0, 0.04)))
    return parts


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
    parts += bunny()
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
    head = head_piece()
    PROP.stretch_rig(rig)
    body = chibi.finish(rig, soft, rigid, "Nela", prop=PROP)
    PROP.stretch_mesh(head)
    lamp, glow = lantern(rig)
    for obj, bone in ((head, "head"), (lamp, "hand.r"), (glow, "hand.r")):
        chibi.rigid(obj, bone)
        obj.parent = rig
        obj.modifiers.new("Armature", "ARMATURE").object = rig

    meshes = [body, head, lamp]
    if chibi.quick_mode():
        for mesh in meshes:
            chibi.quick_material(mesh)
        paint_bake.flat_material(glow, GLOW, emission=3.0, name="lantern_glow")
        print("nela tris:", common.triangle_count(meshes + [glow]))
        render_previews(rig, meshes + [glow], head, "nela", ("Running_A", 8), ("Spellcast_Shoot", 12), ("PickUp", 12))
        return
    params = dict(size=1024, ao_distance=0.16, ao_strength=0.5, edge_strength=0.3, edge_radius=0.012,
                  noise_scale=6.0, stroke_strength=0.05, light=(1.14, 1.06, 0.96), shadow=(0.5, 0.44, 0.66),
                  foot_darken=0.32, foot_height=0.9)
    for mesh in meshes:
        # Softer occlusion on the head so the fringe doesn't smudge the face.
        extra = dict(ao_strength=0.28, ao_distance=0.08) if mesh is head else {}
        paint_bake.paint(mesh, source="attribute", **dict(params, **extra))
    paint_bake.flat_material(glow, GLOW, emission=3.0, name="lantern_glow")
    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "nela.glb"), [rig] + meshes + [glow], animations=True)
    print("nela tris:", common.triangle_count(meshes + [glow]))
    render_previews(rig, meshes + [glow], head, "nela", ("Running_A", 8), ("Spellcast_Shoot", 12), ("PickUp", 12))


if __name__ == "__main__":
    build()
