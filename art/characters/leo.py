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
from characters import chibi  # noqa: E402

SKIN = (1.0, 0.8, 0.66)
SKIN_SHADE = (0.94, 0.66, 0.54)
BLUSH = (1.0, 0.56, 0.52)
HAIR_LIGHT = (1.0, 0.9, 0.58)
HAIR = (0.95, 0.76, 0.38)
HAIR_DARK = (0.72, 0.5, 0.22)
BROW = (0.62, 0.42, 0.2)
IRIS = (0.35, 0.68, 0.98)
IRIS_DARK = (0.1, 0.3, 0.62)
LASH = (0.2, 0.12, 0.08)
FRECKLE = (0.9, 0.6, 0.45)
TEE = (0.56, 0.76, 0.93)
TEE_DARK = (0.4, 0.6, 0.82)
BADGE = (0.16, 0.28, 0.52)
BADGE_TREE = (0.35, 0.68, 0.3)
SHORTS = (0.09, 0.4, 0.5)
SHORTS_DARK = (0.06, 0.28, 0.38)
LIME = (0.68, 0.88, 0.22)
SHORTS_LIGHT = (0.32, 0.68, 0.78)
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

HEAD = chibi.HeadFrame((0, -0.01, 1.64), (0.44, 0.41, 0.42))


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
    parts = [chibi.tube([(0, 0, 1.1), (0, 0, 1.34)], [0.085, 0.085], name="neck")]
    for s in (-1, 1):
        parts.append(chibi.tube([(s * 0.3, 0, 1.11), (s * 0.55, 0, 1.11), (s * 0.8, 0, 1.11)], [0.08, 0.074, 0.066],
                                name="arm"))
        parts.append(chibi.tube([(s * 0.16, 0, 0.46), (s * 0.17, -0.01, 0.29), (s * 0.17, 0.02, 0.14)],
                                [0.085, 0.082, 0.068], name="leg"))
    body = chibi.fuse(parts, "Skin", voxel=0.014, faces=1500)
    common.color_by(body, lambda p, n: common.lerp(SKIN, SKIN_SHADE, max(0.0, -n.z * 0.5)))
    return body


def shirt_piece():
    parts = [
        chibi.ellipsoid((0, 0, 1.0), (0.29, 0.22, 0.24), name="chest"),
        chibi.ellipsoid((0, -0.01, 0.78), (0.275, 0.225, 0.27), name="belly"),
    ]
    for s in (-1, 1):
        parts.append(chibi.tube([(s * 0.14, 0, 1.1), (s * 0.43, 0, 1.1)], [0.13, 0.118], name="sleeve", levels=2))
    shirt = chibi.fuse(parts, "Shirt", voxel=0.014, faces=2200)
    for s in (-1, 1):
        chibi.cut_open(shirt, (s * 0.41, 0, 0), (s, 0, 0))

    def colour(pos, normal):
        # Sleeve hem and a slightly darker, crumpled lower hem.
        if abs(pos.x) > 0.37:
            return TEE_DARK
        return TEE
    common.color_by(shirt, colour)
    return shirt


def shorts_piece():
    parts = [chibi.ellipsoid((0, 0, 0.58), (0.275, 0.215, 0.14), name="hips")]
    for s in (-1, 1):
        parts.append(chibi.tube([(s * 0.14, 0, 0.6), (s * 0.175, 0, 0.3)], [0.13, 0.128], name="shortleg", levels=2))
    shorts = chibi.fuse(parts, "Shorts", voxel=0.012, faces=2000)
    chibi.cut_open(shorts, (0, 0, 0.32), (0, 0, -1))

    def colour(pos, normal):
        z = pos.z
        if 0.4 < z < 0.43:
            return LIME
        if 0.445 < z < 0.46:
            return SHORTS_LIGHT
        if z < 0.35:
            return SHORTS_DARK  # hem
        if abs(normal.x) > 0.85 and z > 0.47:
            return SHORTS_LIGHT  # side panel
        return SHORTS
    common.color_by(shorts, colour)
    return shorts


def badge():
    c = Vector((0.1, -0.24, 0.84))
    disc = chibi.cylinder(c, 0.055, 0.012, name="badge", axis="Y", segments=24, bevel=0.004)

    def colour(pos, normal):
        rel = pos - c
        r = math.hypot(rel.x, rel.z)
        if normal.y > -0.8 or r > 0.045:
            return BADGE
        # A little pine tree on a pale disc.
        if rel.z < 0.03 and abs(rel.x) < (0.03 - rel.z) * 0.55 and rel.z > -0.025:
            return BADGE_TREE
        return (0.92, 0.95, 0.98)
    common.color_by(badge_obj := disc, colour, smooth=False)
    return badge_obj


def hands_and_feet():
    rigid = []
    for h, bone in chibi.hands(SKIN, radius=0.088):
        rigid.append((h, bone))
    for s, bone in ((1, "foot.l"), (-1, "foot.r")):
        for part in chibi.boot(s, BOOT, SOLE, BOOT_TOE, LACE, accent=BOOT_ACCENT, scale=1.08):
            rigid.append((part, bone))
        sock = chibi.tube([(s * 0.17, 0.02, 0.26), (s * 0.17, 0.02, 0.14)], [0.078, 0.08], name="sock", levels=1)
        common.color_by(sock, lambda p, n: common.lerp(SOCK, (1, 1, 1), 0.25) if p.z > 0.235 else SOCK)
        rigid.append((sock, "lowerleg." + bone[-1]))
    return rigid


# ----------------------------------------------------------------- head

def hair_and_cap():
    c = HEAD.c
    parts = []
    colour = chibi.hair_colour(HAIR_LIGHT, HAIR, HAIR_DARK, c)
    # Hair shell: covers top, sides and back; open for the face.
    shell = chibi.ellipsoid(c + Vector((0, 0.012, 0.02)), (0.462, 0.435, 0.445), name="hairshell", segs=(36, 22))
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    kill = []
    for v in bm.verts:
        d = (v.co - c)
        d = Vector((d.x / 0.46, d.y / 0.43, d.z / 0.44))
        keep = d.z > 0.42 or (d.y > -0.3 and d.z > -0.15) or (d.y > 0.35 and d.z > -0.55)
        if not keep:
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(shell.data)
    bm.free()
    mod = shell.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.03
    common.apply_all_modifiers(shell)
    common.shade_smooth(shell)
    common.color_by(shell, colour)
    parts.append(shell)
    # Messy fringe sweeping to his right, locks over the ears, nape.
    locks = [
        # yaw, pitch, direction, length, radius, bend
        (-0.5, 0.46, (-0.55, -0.55, -0.6), 0.2, 0.06, (-0.05, -0.04, -0.03)),
        (-0.3, 0.54, (-0.4, -0.65, -0.6), 0.24, 0.07, (-0.07, -0.05, -0.02)),
        (-0.1, 0.58, (-0.3, -0.7, -0.62), 0.25, 0.07, (-0.06, -0.05, -0.03)),
        (0.1, 0.6, (-0.15, -0.75, -0.6), 0.23, 0.068, (-0.05, -0.05, -0.03)),
        (0.3, 0.56, (0.05, -0.75, -0.62), 0.21, 0.064, (0.0, -0.05, -0.02)),
        (0.5, 0.5, (0.4, -0.62, -0.6), 0.19, 0.06, (0.05, -0.03, -0.02)),
        (0.68, 0.42, (0.6, -0.45, -0.65), 0.17, 0.055, (0.04, -0.02, -0.02)),
        (-0.2, 0.7, (-0.3, -0.8, -0.5), 0.26, 0.07, (-0.05, -0.05, -0.02)),
        (0.2, 0.7, (0.1, -0.8, -0.55), 0.24, 0.07, (0.0, -0.05, -0.02)),
    ]
    for side in (-1, 1):
        for k, (yaw, pitch) in enumerate(((0.95, 0.3), (1.2, 0.18), (1.45, 0.1), (1.75, 0.12), (2.05, 0.1))):
            locks.append((side * yaw, pitch, (side * 0.5, 0.12 * k - 0.15, -0.85), 0.17 + 0.02 * (k % 2), 0.065,
                          (side * 0.05, 0.02, 0.0)))
    for yaw in (2.35, 2.7, 3.0, 3.28, 3.58, 3.93):
        locks.append((yaw, -0.08, (math.sin(yaw) * 0.35, 0.55, -0.8), 0.18, 0.07, (0, 0.06, 0.02)))
    for yaw, pitch, direction, length, radius, bend in locks:
        root, n = HEAD.point(yaw, pitch, 0.01)
        root = root - n * 0.02
        lock = chibi.curved_lock(root, direction, length, radius, bend, name="lock")
        chibi.flatten_along(lock, root, n, 0.6)
        common.color_by(lock, chibi.lock_colour(root, length, HAIR_LIGHT, HAIR, HAIR_DARK))
        parts.append(lock)

    # Backwards cap.
    cap_c = c + Vector((0, 0.015, 0.07))
    dome = chibi.ellipsoid(cap_c, (0.475, 0.455, 0.43), name="cap", segs=(40, 24))
    # Clean tilted cut: higher at the front (forehead), low at the back.
    normal = Vector((0, 0.36 / 0.455, 1 / 0.43)).normalized()
    bm = bmesh.new()
    bm.from_mesh(dome.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                           plane_co=cap_c + Vector((0, 0, 0.24 * 0.43)), plane_no=normal, clear_inner=True)
    bm.to_mesh(dome.data)
    bm.free()
    mod = dome.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.035
    common.apply_all_modifiers(dome)
    common.shade_smooth(dome)

    def cap_colour(pos, normal):
        rel = pos - cap_c
        a = math.atan2(rel.x, rel.y)
        seam = abs(((a / (math.tau / 6)) % 1.0) - 0.5) > 0.47 and rel.z > 0.12
        if seam:
            return CAP_SEAM
        return CAP
    common.color_by(dome, cap_colour, smooth=False)
    parts.append(dome)
    button = chibi.ellipsoid(cap_c + Vector((0, 0, 0.43)), (0.04, 0.04, 0.022), name="button", segs=(12, 8))
    common.set_color(button, CAP_SEAM)
    parts.append(button)
    # Brim sticking out behind, tilted slightly down.
    brim = chibi.ellipsoid((0, 0, 0), (0.3, 0.24, 0.022), name="brim", segs=(32, 10))
    for v in brim.data.vertices:
        v.co.z += (v.co.x ** 2) * -0.5  # curve the sides down
    brim.data.transform(Matrix.Translation(cap_c + Vector((0, 0.43, -0.02))) @ Matrix.Rotation(math.radians(-14), 4, "X"))

    def brim_colour(pos, normal):
        if normal.z < -0.3:
            return camo(pos, normal)
        return CAP
    common.color_by(brim, brim_colour, smooth=False)
    parts.append(brim)
    return parts


def face():
    parts = []
    for side in (-1, 1):
        parts += chibi.eye(HEAD, side * 0.36, -0.08, side, IRIS, IRIS_DARK, LASH, size=1.0, look=(0.004, 0.012),
                           name="eye")
        parts.append(chibi.brow(HEAD, side * 0.37, 0.19, side, BROW))
    parts += chibi.smile(HEAD, -0.4, 0.075, 0.042, 0.004, curve=2.0)
    for yaw, pitch in ((-0.2, -0.22), (-0.26, -0.28), (-0.15, -0.3), (-0.32, -0.2), (0.2, -0.22), (0.26, -0.28),
                       (0.15, -0.3), (0.32, -0.2), (-0.06, -0.16), (0.06, -0.16)):
        parts.append(HEAD.ellipse(yaw, pitch, 0.0065, 0.006, 0.004, FRECKLE, name="freckle", nu=6, nv=2))
    parts.append(chibi.nose(HEAD, SKIN, pitch=-0.2))
    return parts


def head_piece():
    parts = [chibi.head_mesh(HEAD, SKIN, SKIN_SHADE, BLUSH)]
    parts += chibi.ears(HEAD, SKIN, BLUSH)
    parts += face()
    parts += hair_and_cap()
    chibi.report(parts)
    return common.join(parts, "Leo_Head")


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
    parts += chibi.straps(STRAP, top_y=0.26, front_y=-0.245, xs=(-0.15, 0.15), shoulder_z=1.21, bottom_z=0.74)
    sternum = chibi.box((0.34, 0.02, 0.028), (0, -0.25, 1.06), bevel=0.006, name="sternum")
    common.set_color(sternum, STRAP)
    parts.append(sternum)
    return parts


def stick(rig):
    """Walking stick in the handslot.r frame: its local +X points down
    to the ground in the idle pose."""
    to_world = chibi.bone_frame(rig, "handslot.r")
    pts, radii = [], []
    for k in range(9):
        t = k / 8
        x = -0.4 + t * 1.05
        wob = Vector((0, noise.noise(Vector((t * 3, 1, 0))) * 0.03, noise.noise(Vector((t * 3, 5, 0))) * 0.03))
        pts.append(Vector((x, 0, 0)) + wob)
        radii.append(0.036 - t * 0.008)
    shaft = chibi.tube(pts, radii, name="stick", levels=1)
    knob = chibi.ellipsoid(pts[0] + Vector((-0.02, 0, 0)), (0.05, 0.045, 0.045), name="knob", segs=(12, 8))
    body = common.join([shaft, knob], "stick")
    common.color_by(body, lambda p, n: BARK_LIGHT if noise.noise(Vector((p.x * 30, p.y * 4, p.z * 4))) > 0.25 else BARK,
                    smooth=False)
    parts = [body]
    for x in (-0.06, -0.02, 0.07):
        wrap = chibi.torus((x, 0, 0), 0.038, 0.01, name="wrap", axis="X", segs=(14, 6))
        common.set_color(wrap, ROPE)
        parts.append(wrap)
    for x, ang in ((-0.3, 0.6), (-0.24, -0.9)):
        leaf = chibi.ellipsoid((0, 0.06, 0), (0.022, 0.05, 0.006), name="leaf", segs=(10, 6))
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
    for part in chibi.compass((0, -0.255, 0.98), GOLD, neck_z=1.22):
        rigid.append((part, "chest"))
    for part in backpack():
        rigid.append((part, "chest"))
    collar = chibi.torus((0, 0, 1.2), 0.1, 0.024, name="collar")
    common.set_color(collar, TEE_DARK)
    rigid.append((collar, "chest"))
    body = chibi.finish(rig, soft, rigid, "Leo")
    head = head_piece()
    chibi.rigid(head, "head")
    head.parent = rig
    head.modifiers.new("Armature", "ARMATURE").object = rig
    walking_stick = stick(rig)
    chibi.rigid(walking_stick, "hand.r")
    walking_stick.parent = rig
    walking_stick.modifiers.new("Armature", "ARMATURE").object = rig

    meshes = [body, head, walking_stick]
    if chibi.quick_mode():
        for mesh in meshes:
            chibi.quick_material(mesh)
        print("leo tris:", common.triangle_count(meshes))
        render_previews(rig, meshes, head, "leo", ("1H_Melee_Attack_Chop", 14))
        return
    params = dict(size=1024, ao_distance=0.16, ao_strength=0.5, edge_strength=0.3, edge_radius=0.012,
                  noise_scale=6.0, stroke_strength=0.05, light=(1.1, 1.05, 0.98), shadow=(0.55, 0.5, 0.7))
    for mesh in meshes:
        # Softer occlusion on the head so the fringe doesn't smudge the face.
        extra = dict(ao_strength=0.28, ao_distance=0.08) if mesh is head else {}
        paint_bake.paint(mesh, source="attribute", **dict(params, **extra))
    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "leo.glb"), [rig] + meshes, animations=True)
    print("leo tris:", common.triangle_count(meshes))
    render_previews(rig, meshes, head, "leo", ("Running_A", 8), ("1H_Melee_Attack_Chop", 14))


def render_previews(rig, meshes, head, name, *actions):
    rig.data.pose_position = "REST"
    preview.render(meshes, name, elevation=10, azimuth=25)
    preview.render([head], name + "_face", elevation=4, azimuth=12, size=384)
    preview.render(meshes, name + "_back", elevation=15, azimuth=160, size=384)
    rig.data.pose_position = "POSE"
    rig.animation_data_create()
    for action_name, frame in (("Idle", 1),) + actions:
        rig.animation_data.action = bpy.data.actions.get(action_name)
        preview.render(meshes, name + "_" + action_name, frame=frame, elevation=10, azimuth=25, size=384)


if __name__ == "__main__":
    build()
