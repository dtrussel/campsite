"""Bramble Beast: a hulking tree golem that tears down fences.

Feature 026 remodel, after the concept in
.features/026-bramble-remodel/reference/concept.png:
- a narrow waist under huge shoulders; long arms ending in giant log
  fists with end-grain rings; short trunk legs flaring into root toes;
- no separate head: an angry face (heavy brow, slanted glowing eyes in
  deep sockets, a carved grin) is sculpted into the top of the trunk;
- bark grain, knots and a V-grain on the chest, and a ragged moss mantle
  over the crown, shoulders and back, with patches on the knees and feet;
- twig antlers, a leaf crown with one autumn leaf, a berry cluster on
  the left shoulder, vines around the forearms and across the torso,
  and a few big thorns;
- a high-to-low bake like the imp (feature 022). HIGH_POLY=1 keeps the
  dense mesh.

Built on the KayKit Skeleton_Minion rig with the forearms lengthened. The
beast's own clips come from characters/beast_anims.py; the rig's stock
clips are dropped. Output: game/assets/custom/bramble_beast.glb"""

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

BARK = (0.42, 0.27, 0.15)
BARK_LIGHT = (0.58, 0.4, 0.24)
BARK_DARK = (0.2, 0.12, 0.07)
RING = (0.66, 0.48, 0.3)
MOSS = (0.31, 0.48, 0.11)
MOSS_LIGHT = (0.5, 0.64, 0.17)
MOSS_DARK = (0.2, 0.34, 0.08)
THORN = (0.84, 0.72, 0.52)
THORN_TIP = (0.5, 0.32, 0.18)
LEAF = (0.3, 0.58, 0.16)
LEAF_LIGHT = (0.5, 0.74, 0.24)
LEAF_AUTUMN = (0.95, 0.55, 0.12)
LEAF_AUTUMN_TIP = (0.85, 0.3, 0.08)
BERRY = (0.92, 0.3, 0.08)
VINE = (0.3, 0.45, 0.14)
EYE = (1.0, 0.82, 0.3)
SOCKET = (0.12, 0.07, 0.04)
MOUTH = (0.1, 0.05, 0.03)

## Triangle budget of the game mesh (with the eyes, 12k at most).
BODY_BUDGET = 9000
## How much longer the forearms are than the stock rig's.
ARM_STRETCH = 0.14
## How much further apart the legs stand (so they read as two trunks).
LEG_SPREAD = 0.07

FACE_Y = -0.42      # roughly where the face surface is
EYE_Z = 1.43
EYE_X = 0.13
MOUTH_Z = 1.26


# --------------------------------------------------------------- rig

def stretch_arms(rig, extra=ARM_STRETCH, spread=LEG_SPREAD):
    """Lengthens the forearms (every bone point beyond the elbow moves out
    by `extra`) and sets the legs further apart. Bone directions are
    kept, so rotations still work."""
    common.select_only([rig])
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")

    def shift(v):
        ax = abs(v.x)
        if v.z < 0.6 and ax > 0.1:
            return Vector((math.copysign(ax + spread, v.x), v.y, v.z))
        if ax <= 0.46 or v.z < 0.9:
            return v
        t = min(1.0, (ax - 0.45) / 0.26)
        return Vector((math.copysign(ax + extra * t, v.x), v.y, v.z))
    for eb in rig.data.edit_bones:
        roll = eb.roll
        eb.head, eb.tail = shift(eb.head.copy()), shift(eb.tail.copy())
        eb.roll = roll
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()


# -------------------------------------------------------------- body

# bone -> (radius at head, radius at tail): trunk legs, log forearms.
BODY_RADII = {
    "upperleg": (0.21, 0.19), "lowerleg": (0.19, 0.21), "foot": (0.21, 0.18), "toes": (0.14, 0.07),
    "upperarm": (0.22, 0.17), "lowerarm": (0.17, 0.25), "wrist": (0.28, 0.3), "hand": (0.31, 0.24),
}


def body_mesh(rig):
    elements = []
    for bone in rig.data.bones:
        key = bone.name.split(".")[0]
        if key not in BODY_RADII:
            continue
        r0, r1 = BODY_RADII[key]
        head, tail = bone_points(rig, bone.name)
        steps = max(2, int((tail - head).length / 0.04))
        for i in range(steps + 1):
            t = i / steps
            elements.append((head.lerp(tail, t), r0 + (r1 - r0) * t, 2.0))
    elements += [
        ((0, 0.02, 0.6), 0.33, 2.0, "ELLIPSOID", (1.3, 0.9, 0.8)),      # hips
        ((0, 0.0, 0.8), 0.29, 2.0, "ELLIPSOID", (1.0, 0.85, 1.0)),      # narrower waist
        ((0, 0.03, 1.0), 0.44, 2.0, "ELLIPSOID", (1.25, 0.85, 0.95)),   # broad chest
        ((0.42, 0.04, 1.13), 0.3, 2.0),                                 # shoulder masses
        ((-0.42, 0.04, 1.13), 0.3, 2.0),
        ((0, 0.18, 1.2), 0.32, 2.0),                                    # hunched back
        ((0, -0.08, 1.36), 0.3, 2.0, "ELLIPSOID", (1.05, 0.95, 1.05)),  # face in the trunk
        ((0, -0.18, 1.29), 0.18, 1.4, "ELLIPSOID", (1.3, 0.9, 0.8)),    # muzzle and jaw
        ((0, 0.02, 1.52), 0.18, 1.4),                                   # crown
    ]
    # Root toes: three per foot, splayed forward and out along the ground.
    for side in (-1, 1):
        ankle = Vector((side * (0.17 + LEG_SPREAD), -0.02, 0.1))
        for spread in (-0.5, 0.0, 0.55):
            a = spread * side
            tip = Vector((side * (0.17 + LEG_SPREAD) + math.sin(a) * 0.26 + side * 0.04, -math.cos(a) * 0.3 - 0.02, 0.035))
            for i in range(6):
                t = i / 5
                elements.append((ankle.lerp(tip, t), 0.1 - 0.055 * t, 1.6))
    # Knees and elbows.
    for joint, r in (("lowerleg.l", 0.18), ("lowerleg.r", 0.18), ("lowerarm.l", 0.18), ("lowerarm.r", 0.18)):
        head, _tail = bone_points(rig, joint)
        elements.append((head, r, 1.2))
    body = common.metaball_object("BrambleBeast", elements, resolution=0.03, threshold=0.6)
    common.voxel_remesh(body, voxel=0.017, smooth_iterations=3)
    return body


def _smooth01(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def _fist_axis(pos):
    """(side, distance from the forearm axis, how far along the fist)."""
    side = 1 if pos.x > 0 else -1
    return side, math.hypot(pos.y, pos.z - 1.11), abs(pos.x)


def face_offset(pos, normal):
    """Sculpted face: brow ridge, eye sockets, cheeks and a carved grin."""
    if normal.y > -0.2 or not 1.12 < pos.z < 1.62 or abs(pos.x) > 0.36:
        return 0.0
    front = _smooth01((-normal.y - 0.2) * 3.0)
    d = 0.0
    ax = abs(pos.x)
    # Angry brow: a heavy ridge dipping toward the middle.
    brow_z = EYE_Z + 0.075 + (ax - 0.02) * 0.25 - 0.03 * max(0.0, 0.08 - ax) / 0.08
    d += 0.05 * math.exp(-((pos.z - brow_z) / 0.035) ** 2) * _smooth01((0.3 - ax) / 0.08)
    # Deep, slanted sockets.
    for side in (-1, 1):
        ex = (pos.x - side * EYE_X) / 0.085
        ez = (pos.z - EYE_Z - (abs(pos.x) - EYE_X) * 0.35) / 0.055
        r = ex * ex + ez * ez
        if r < 1.6:
            d -= 0.055 * _smooth01((1.6 - r) / 1.2)
    # Cheeks under the eyes.
    for side in (-1, 1):
        r = ((pos.x - side * 0.17) / 0.09) ** 2 + ((pos.z - 1.33) / 0.06) ** 2
        d += 0.02 * math.exp(-r)
    # Wide grin with raised corners.
    mz = MOUTH_Z + (ax ** 2) * 1.6
    if ax < 0.22:
        d -= 0.035 * math.exp(-((pos.z - mz) / 0.02) ** 2) * _smooth01((0.22 - ax) / 0.05)
    return d * front


def grain_offset(pos, normal):
    """Bark ridges running along the limbs and trunk."""
    side, radial, along = _fist_axis(pos)
    if along > 0.5 and pos.z > 0.8:
        # Arms: grain runs along x.
        g = noise.noise(Vector((pos.x * 2.0, pos.y * 16.0, pos.z * 16.0)))
    else:
        g = noise.noise(Vector((pos.x * 16.0, pos.y * 16.0, pos.z * 2.2)))
    return 0.012 * g


def moss_mask(pos, normal):
    """Where the mantle and moss patches grow (0..1)."""
    n = noise.noise(pos * 5.0)
    ax = abs(pos.x)
    # Mantle: the crown, shoulders and upper back, down to a ragged edge
    # that drips lower on the back.
    angle = math.atan2(pos.x, pos.y + 0.001)
    drip = max(0.0, math.sin(angle * 11.0 + n * 3.0)) ** 3
    edge = 1.1 - 0.16 * drip - (0.1 if pos.y > 0.1 else 0.0) + n * 0.06
    mantle = 0.0
    if ax < 0.75:
        mantle = _smooth01((pos.z - edge) / 0.04) * _smooth01((0.66 - ax) / 0.12)
    # Keep the face bare (moss only above the brow).
    if normal.y < -0.35 and ax < 0.34 and pos.z < EYE_Z + 0.15:
        mantle = 0.0
    # Moss along the top of the arms and fists (rest pose: +z).
    arm = 0.0
    if ax > 0.5 and pos.z > 0.95:
        patch = noise.noise(pos * 3.0 + Vector((7, 2, 9)))
        arm = _smooth01((normal.z - 0.5) * 3.0) * _smooth01((patch + 0.05) * 5.0)
    # Patches on the knees and feet.
    low = 0.0
    if pos.z < 0.45:
        low = _smooth01((noise.noise(pos * 6.0 + Vector((5, 1, 3))) - 0.12) * 5.0) * _smooth01((normal.z + 0.4) * 2.0)
    return max(mantle, arm, low)


def sculpt(body):
    mesh = body.data
    mesh.calc_loop_triangles()
    for v in mesh.vertices:
        pos, normal = v.co.copy(), v.normal.copy()
        m = moss_mask(pos, normal)
        d = face_offset(pos, normal) + grain_offset(pos, normal) * (1.0 - m) + 0.025 * m
        v.co = pos + normal * d
    mesh.update()
    common.shade_smooth(body)


def colour_body(body):
    def colour(pos, normal):
        n = noise.noise(pos * 4.0)
        side, radial, along = _fist_axis(pos)
        arm = along > 0.5 and pos.z > 0.8
        if arm:
            streak = noise.noise(Vector((pos.x * 2.0, pos.y * 16.0, pos.z * 16.0)))
        else:
            streak = noise.noise(Vector((pos.x * 16.0, pos.y * 16.0, pos.z * 2.2)))
        c = common.lerp(BARK, BARK_DARK, _smooth01(0.3 + streak * 1.2 - normal.z * 0.15))
        c = common.lerp(c, BARK_LIGHT, _smooth01(streak * 2.0 - 0.5) * 0.7)
        # V-grain on the chest and back.
        if not arm and 0.65 < pos.z < 1.2 and abs(normal.y) > 0.4:
            v = (pos.z + abs(pos.x) * 0.9) * 9.0
            if (v - math.floor(v)) < 0.1:
                c = common.lerp(c, BARK_DARK, 0.55)
        # Knots with rings.
        for kc in ((0.2, -0.3, 0.8), (-0.24, 0.35, 0.95), (0.18, -0.2, 0.4), (-0.6, 0.0, 1.3)):
            r = (pos - Vector(kc)).length
            if r < 0.07:
                c = common.lerp(BARK_DARK, BARK_LIGHT, 0.5 + 0.5 * math.sin(r * 140.0))
        # End grain on the fists: a spiral of rings on the outer end.
        tip = 0.79 + ARM_STRETCH + 0.2
        if arm and side * normal.x > 0.45 and along > tip - 0.14:
            ang = math.atan2(pos.z - 1.11, pos.y)
            rings = math.sin(radial * 60.0 + ang * 0.6)
            c = common.lerp(RING, BARK, 0.35 + 0.35 * rings)
            if radial > 0.22:
                c = common.lerp(c, BARK_DARK, 0.5)
        # Moss.
        m = moss_mask(pos, normal)
        if m > 0:
            mc = common.lerp(MOSS, MOSS_LIGHT, _smooth01(0.5 + n + normal.z * 0.3))
            fleck = noise.noise(pos * 28.0)
            if fleck > 0.35:
                mc = MOSS_LIGHT
            c = common.lerp(c, mc, m)
        # The face: dark sockets, a darker grin, soft shade under the brow.
        if normal.y < -0.3 and abs(pos.x) < 0.34 and 1.15 < pos.z < 1.56:
            for s in (-1, 1):
                ex = (pos.x - s * EYE_X) / 0.09
                ez = (pos.z - EYE_Z - (abs(pos.x) - EYE_X) * 0.35) / 0.06
                r = ex * ex + ez * ez
                if r < 1.3:
                    c = common.lerp(c, SOCKET, _smooth01((1.3 - r) / 0.5) * 0.9)
            ax = abs(pos.x)
            mz = MOUTH_Z + (ax ** 2) * 1.6
            if ax < 0.21 and abs(pos.z - mz) < 0.022:
                c = MOUTH
        return c
    common.color_by(body, colour)


# ------------------------------------------------------------ extras

def surface_point(body, origin, direction):
    """Where a ray from inside the body leaves its surface."""
    direction = direction.normalized()
    hit, loc, normal, _ = body.ray_cast(origin, direction, distance=1.0)
    if not hit:
        return origin + direction * 0.3, direction
    if normal.dot(direction) < 0:
        normal = -normal
    return loc, normal


def thorn(base, direction, length, radius):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=radius, radius2=0.0, depth=length)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, length / 2))
    # A slight hook toward the tip.
    for v in bm.verts:
        t = v.co.z / length
        v.co.x += 0.25 * radius * t * t
    obj = common.mesh_object("thorn", bm)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    obj.location = base
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    common.shade_smooth(obj)

    def colour(pos, normal):
        t = (pos - base).length / length
        return common.lerp(THORN, THORN_TIP, _smooth01(t * 1.6 - 0.5))
    common.color_by(obj, colour, smooth=False)
    return obj


def thorns(body, rig):
    """Big thorns along the shoulders and forearm ridges, and on the back."""
    out = []
    for side in (-1, 1):
        s = "l" if side > 0 else "r"
        for bone, ts, lengths in (("upperarm." + s, (0.35, 0.8), (0.24, 0.3)),
                                  ("lowerarm." + s, (0.3, 0.75), (0.22, 0.26)),
                                  ("hand." + s, (0.2,), (0.2,))):
            head, tail = bone_points(rig, bone)
            for t, length in zip(ts, lengths):
                p = head.lerp(tail, t)
                direction = Vector((side * 0.35, 0.3, 1.0))
                loc, normal = surface_point(body, p, direction)
                aim = normal.lerp(Vector((side * 0.4, 0.2, 1.0)).normalized(), 0.5)
                out.append((thorn(loc - normal * 0.03, aim, length, length * 0.26), bone))
    for x, z, length in ((-0.18, 1.3, 0.2), (0.16, 1.2, 0.22), (0.0, 1.0, 0.18)):
        loc, normal = surface_point(body, Vector((x, 0.1, z)), Vector((x * 0.6, 1.0, 0.35)))
        out.append((thorn(loc - normal * 0.03, normal.lerp(Vector((0, 0.5, 1)), 0.3), length, length * 0.25), "chest"))
    return out


def twig(points, radii, name="twig"):
    obj = curved_tube([Vector(p) for p in points], radii, name)

    def colour(pos, normal):
        return common.lerp(BARK_LIGHT, BARK_DARK, _smooth01(0.4 + noise.noise(pos * 20.0) * 0.8 - normal.z * 0.2))
    common.color_by(obj, colour, smooth=False)
    return obj


def antlers(body):
    """Two gnarled twig antlers with a side branch, rooted on the crown."""
    parts = []
    for side in (-1, 1):
        loc, _n = surface_point(body, Vector((side * 0.14, 0.0, 1.45)), Vector((side * 0.5, 0.1, 1.0)))
        base = loc - Vector((0, 0, 0.03))
        mid = base + Vector((side * 0.13, 0.03, 0.12))
        top = mid + Vector((side * 0.12, 0.06, 0.12))
        parts.append(twig([base, mid, top, top + Vector((side * 0.02, 0.02, 0.07))], [0.045, 0.035, 0.022, 0.006], "antler"))
        fork = base.lerp(mid, 0.7)
        parts.append(twig([fork, fork + Vector((side * 0.02, -0.05, 0.1)), fork + Vector((-side * 0.02, -0.07, 0.17))],
                          [0.025, 0.016, 0.004], "antler_fork"))
    return parts


def leaf(length, width, colour_base, colour_tip, name="leaf"):
    """A broad leaf with a midrib, lying along +x, tip up-curled."""
    bm = bmesh.new()
    rows, cols = 7, 4
    verts = []
    for i in range(rows + 1):
        t = i / rows
        half = width * math.sin(math.pi * min(1.0, t * 1.05)) ** 0.8 * 0.5
        row = []
        for j in range(-cols, cols + 1):
            u = j / cols
            x = t * length
            y = u * half
            z = 0.25 * length * t * t - 0.12 * abs(u) * half   # curled up, cupped
            row.append(bm.verts.new((x, y, z)))
        verts.append(row)
    for i in range(rows):
        for j in range(2 * cols):
            bm.faces.new((verts[i][j], verts[i][j + 1], verts[i + 1][j + 1], verts[i + 1][j]))
    obj = common.mesh_object(name, bm)
    solid = obj.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = 0.012
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)

    def colour(pos, normal):
        t = pos.x / length
        c = common.lerp(colour_base, colour_tip, _smooth01(t * 1.3 - 0.2))
        if abs(pos.y) < 0.006 + 0.004 * (1 - t):
            c = common.lerp(c, (0.9, 0.85, 0.5), 0.5)
        return c
    common.color_by(obj, colour, smooth=False)
    return obj


def place(obj, location, yaw=0.0, pitch=0.0, roll=0.0):
    obj.rotation_euler = (roll, pitch, yaw)
    obj.location = location
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def leaf_crown(body):
    """Broad leaves fanned on the crown, the tallest one autumn orange."""
    loc, _n = surface_point(body, Vector((0, 0.0, 1.45)), Vector((0, 0.1, 1.0)))
    base = loc - Vector((0, 0, 0.02))
    parts = []
    spec = [  # yaw (deg), pitch (deg: negative = up), length, width, autumn
        (100, -62, 0.34, 0.17, True),
        (50, -32, 0.32, 0.18, False), (130, -32, 0.32, 0.18, False),
        (5, -15, 0.3, 0.17, False), (175, -15, 0.3, 0.17, False),
        (-60, -12, 0.26, 0.15, False), (-120, -12, 0.26, 0.15, False),
    ]
    for yaw, pitch, length, width, autumn in spec:
        if autumn:
            lf = leaf(length, width, LEAF_AUTUMN, LEAF_AUTUMN_TIP, "leaf_autumn")
        else:
            lf = leaf(length, width, LEAF, LEAF_LIGHT)
        # Leaves point outward from the crown (yaw 90 = back, -90 = front).
        parts.append(place(lf, base, yaw=math.radians(yaw), pitch=math.radians(pitch)))
    return parts


def berries(body):
    """A cluster of red-orange berries with two leaves on the left shoulder."""
    loc, normal = surface_point(body, Vector((0.24, 0.0, 1.18)), Vector((0.35, -0.6, 0.7)))
    parts = []
    for k, off in enumerate(((0, 0, 0), (0.06, 0.01, 0.03), (0.02, -0.05, 0.05), (0.07, -0.03, -0.03), (-0.03, -0.04, -0.02))):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=0.045 if k else 0.05)
        bmesh.ops.translate(bm, verts=bm.verts, vec=loc + normal * 0.03 + Vector(off))
        b = common.mesh_object("berry", bm)
        common.shade_smooth(b)

        def colour(pos, n, centre=loc + normal * 0.03 + Vector(off)):
            hl = (n - Vector((-0.3, -0.5, 0.8)).normalized()).length < 0.5
            return (1.0, 0.7, 0.45) if hl else common.lerp(BERRY, (0.6, 0.12, 0.04), _smooth01(-n.z))
        common.color_by(b, colour, smooth=False)
        parts.append(b)
    for yaw, pitch in ((math.radians(-30), math.radians(-20)), (math.radians(40), math.radians(-35))):
        parts.append(place(leaf(0.18, 0.09, LEAF, LEAF_LIGHT), loc + normal * 0.02, yaw=yaw, pitch=pitch))
    return parts


def small_leaves_along(points, every=2, size=0.1, seed=1):
    rng = random.Random(seed)
    out = []
    for i in range(1, len(points) - 1, every):
        p = points[i]
        lf = leaf(size, size * 0.55, LEAF, LEAF_LIGHT, "vine_leaf")
        out.append(place(lf, p, yaw=rng.uniform(0, math.tau), pitch=rng.uniform(-0.6, 0.2)))
    return out


def vines(body, rig):
    """A vine spiralling around each forearm and one across the torso."""
    out = []
    for side in (-1, 1):
        s = "l" if side > 0 else "r"
        head, tail = bone_points(rig, "lowerarm." + s)
        _wh, wt = bone_points(rig, "wrist." + s)
        pts = []
        for i in range(13):
            t = i / 12
            p = head.lerp(wt, 0.05 + 0.95 * t)
            a = t * math.tau * 1.3 + (0.6 if side > 0 else 2.2)
            d = Vector((0, math.cos(a), math.sin(a)))
            loc, normal = surface_point(body, p, d)
            pts.append(loc + normal * 0.012)
        v = curved_tube(pts, [0.02] * len(pts), "vine")
        common.set_color(v, VINE)
        out.append((v, "lowerarm." + s))
        for lf in small_leaves_along(pts, 3, 0.1, seed=side + 5):
            out.append((lf, "lowerarm." + s))
    # Torso: from the left shoulder down across the chest to the right hip.
    pts = []
    for i in range(12):
        t = i / 11
        p = Vector((0.36 - 0.62 * t, 0.0, 1.12 - 0.5 * t))
        loc, normal = surface_point(body, p, Vector((0, -1, 0)))
        pts.append(loc + normal * 0.012)
    v = curved_tube(pts, [0.022] * len(pts), "vine")
    common.set_color(v, VINE)
    out.append((v, "chest"))
    for lf in small_leaves_along(pts, 3, 0.11, seed=9):
        out.append((lf, "chest"))
    return out


def moss_strands(body):
    """Short tufts hanging from the mantle's edge on the shoulders."""
    rng = random.Random(26)
    parts = []
    for k in range(16):
        a = rng.uniform(-2.6, 2.6)
        if abs(a) < 0.5:
            continue   # not over the face
        d = Vector((math.sin(a), math.cos(a), 0.15))
        loc, normal = surface_point(body, Vector((math.sin(a) * 0.1, 0.05, 1.08)), d)
        if abs(loc.x) > 0.42:
            continue   # the ray ran out along a T-posed arm
        length = rng.uniform(0.06, 0.12)
        pts = [loc + normal * 0.01, loc + normal * 0.03 + Vector((0, 0, -length * 0.6)), loc + normal * 0.02 + Vector((0, 0, -length))]
        t = curved_tube(pts, [0.035, 0.022, 0.004], "moss_strand")
        common.set_color(t, MOSS if k % 2 else MOSS_LIGHT)
        parts.append(t)
    return parts


def eyes(body):
    """Slanted, angry almond eyes set into the sockets (a raycast finds
    the socket floor, so they never float in front of the face)."""
    parts = []
    for side in (-1, 1):
        loc, normal = surface_point(body, Vector((side * EYE_X, -0.1, EYE_Z)), Vector((side * 0.15, -1.0, 0.05)))
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.048)
        for v in bm.verts:
            v.co.x *= 1.35
            v.co.z *= 0.8 - 0.25 * abs(v.co.x) / 0.08
            v.co.y *= 0.45
        # Inner corners low: an angry slant.
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(side * math.radians(20), 3, "Y"))
        bmesh.ops.translate(bm, verts=bm.verts, vec=loc + normal * 0.01)
        parts.append(common.mesh_object("eye", bm))
    glow = common.join(parts, "BrambleBeast_Eyes")
    common.shade_smooth(glow)
    paint_bake.flat_material(glow, EYE, emission=2.0, name="bramble_eye_glow")
    return glow


# ------------------------------------------------------------- build

def build():
    common.reset(26)
    bpy.ops.import_scene.gltf(filepath=os.path.join(common.KAYKIT, "skeletons", "Skeleton_Minion.glb"))
    rig = bpy.data.objects["Rig"]
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj)
    for bone in rig.data.bones:
        bone.use_deform = bone.name in DEFORM
    rig.data.pose_position = "REST"
    stretch_arms(rig)

    body = body_mesh(rig)
    sculpt(body)
    colour_body(body)

    rigid_parts = thorns(body, rig) + vines(body, rig)
    rigid_parts += [(p, "head") for p in antlers(body) + leaf_crown(body)]
    rigid_parts += [(p, "chest") for p in berries(body) + moss_strands(body)]
    eye = eyes(body)

    common.select_only([body, rig])
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    extras = []
    for part, bone in rigid_parts:
        rigid(part, bone)
        extras.append(part)
    body = common.join([body] + extras, "BrambleBeast")
    high = None if os.environ.get("HIGH_POLY") else chibi.lowpoly(body, BODY_BUDGET)
    paint_bake.paint(body, size=1024, ao_distance=0.25, ao_strength=0.7, edge_strength=0.35, edge_radius=0.018,
                     noise_scale=6.0, stroke_strength=0.08, cavity=0.2, light=(1.15, 1.08, 1.0),
                     shadow=(0.42, 0.4, 0.38), high=high)

    rigid(eye, "head")
    eye.parent = rig
    mod = eye.modifiers.new("Armature", "ARMATURE")
    mod.object = rig

    # The beast's own clips replace the rig's stock ones.
    from characters import beast_anims
    beast_anims.build_actions(rig)

    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "bramble_beast.glb"), [rig, body, eye], animations=True)
    print("bramble_beast tris:", common.triangle_count([body, eye]))

    if os.environ.get("CLAY"):
        rig.data.pose_position = "REST"
        preview.render_clay([body, eye], "bramble_beast")
        rig.data.pose_position = "POSE"
    rig.animation_data_create()
    for action_name, frame, az in (("Beast_Idle", 1, -25), ("Beast_Idle", 1, 90), ("Beast_Idle", 1, 180)):
        rig.animation_data.action = bpy.data.actions.get(action_name)
        preview.render([body, eye], "bramble_beast_%s_%d" % (action_name, az), frame=frame, elevation=10, azimuth=az)
    for action_name, frames in beast_anims.PREVIEW_FRAMES.items():
        rig.animation_data.action = bpy.data.actions.get(action_name)
        for frame in frames:
            preview.render([body, eye], "bramble_beast_%s_%02d" % (action_name, frame), frame=frame, elevation=10,
                           azimuth=-35, size=320, samples=12)


if __name__ == "__main__":
    build()
