"""Shadow Imp: the main night mob, a cheeky little purple imp on the
KayKit Skeleton_Minion rig. Its own clips come from
characters/imp_anims.py (feature 028).

Feature 028 remodel, after the concept in
.features/028-imp-remodel/reference/concept.png, built in the order the
team asked for:
1. Silhouette: a big round head, large pointed bat ears with magenta
   insides, curved cream horns curling at the tips, a spiky crest, small
   bat wings, and a long S-curling tail with a magenta arrow tip; thick
   thighs and long feet for a bent-legged crouch.
2. Face: oversized cream-yellow glowing eyes with black slit pupils in
   shallow sockets, magenta brow markings, a small snout, a cheeky grin
   with two little fangs.
3. Paint: deep purple with darker shading, a lavender belly, magenta
   stripes on the arms, legs and tail, darker spiky marks down the back,
   cream claws.
A high-to-low bake: the dense sculpt carries the paint onto a ~7.5k
triangle game mesh. HIGH_POLY=1 keeps the dense mesh.

The module also holds the rig helpers the other creatures import
(DEFORM, bone_points, curved_tube, rigid).
Output: game/assets/custom/shadow_imp.glb"""

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

BODY = (0.3, 0.13, 0.52)
BODY_DARK = (0.15, 0.05, 0.3)
BODY_LIGHT = (0.42, 0.22, 0.66)
BELLY = (0.62, 0.46, 0.84)
STRIPE = (0.8, 0.22, 0.72)
MEMBRANE = (0.84, 0.2, 0.62)
MEMBRANE_DARK = (0.5, 0.1, 0.45)
INNER_EAR = (0.88, 0.28, 0.68)
HORN = (0.94, 0.86, 0.74)
HORN_TIP = (0.74, 0.62, 0.58)
MOUTH = (0.24, 0.04, 0.16)
TONGUE = (0.86, 0.36, 0.5)
FANG = (1.0, 0.97, 0.92)
EYE = (1.0, 0.86, 0.45)
PUPIL = (0.05, 0.02, 0.06)
CLAW = (0.95, 0.9, 0.8)
TUFT = (0.24, 0.1, 0.44)

## Triangle budget of the game mesh (imps <= 12k with the eyes).
BODY_BUDGET = 7500

DEFORM = {"root", "hips", "spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
          "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "upperleg.l", "lowerleg.l", "foot.l", "toes.l",
          "upperleg.r", "lowerleg.r", "foot.r", "toes.r"}

HEAD_C = Vector((0, -0.03, 1.52))
EYE_X = 0.19
EYE_Z = 1.6
MOUTH_Z = 1.37

# bone -> (radius at head, radius at tail): thick thighs, long feet.
BODY_RADII = {
    "upperleg": (0.21, 0.17), "lowerleg": (0.14, 0.14), "foot": (0.15, 0.13), "toes": (0.13, 0.08),
    "upperarm": (0.13, 0.115), "lowerarm": (0.11, 0.12), "wrist": (0.12, 0.12), "hand": (0.15, 0.1),
}


# ------------------------------------------------------------ helpers
# (imported by bramble_beast.py and mushroom_gremlin.py)

def bone_points(rig, name):
    b = rig.data.bones[name]
    return rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local


def curved_tube(points, radii, name):
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in points]
    for a, b in zip(verts, verts[1:]):
        bm.edges.new((a, b))
    obj = common.mesh_object(name, bm)
    obj.modifiers.new("Skin", "SKIN")
    bm2 = bmesh.new()
    bm2.from_mesh(obj.data)
    bm2.verts.ensure_lookup_table()
    layer = bm2.verts.layers.skin.verify()
    for v, r in zip(bm2.verts, radii):
        v[layer].radius = (r, r)
    bm2.verts[0][layer].use_root = True
    bm2.to_mesh(obj.data)
    bm2.free()
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    return obj


def rigid(obj, bone):
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


def _smooth01(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def _surface(body, origin, direction):
    """Where a ray from inside the body leaves its surface (and the
    outward normal there)."""
    direction = direction.normalized()
    hit, loc, normal, _ = body.ray_cast(origin, direction, distance=1.5)
    if not hit:
        return origin + direction * 0.3, direction
    if normal.dot(direction) < 0:
        normal = -normal
    return loc, normal


# --------------------------------------------------------------- body

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
        ((0, 0.0, 0.52), 0.38, 2.0),                                         # hips
        ((0, -0.06, 0.78), 0.46, 2.0, "ELLIPSOID", (1.0, 0.95, 1.05)),       # round belly
        ((0, -0.02, 1.03), 0.4, 2.0),                                        # chest
        ((0, 0.0, 1.18), 0.3, 2.0),                                          # neck
        (tuple(HEAD_C), 0.64, 2.0, "ELLIPSOID", (1.1, 0.98, 0.98)),          # big round head
        ((0, -0.24, 1.44), 0.3, 2.0),                                        # cheeks / muzzle
        ((0, -0.46, 1.46), 0.13, 1.4, "ELLIPSOID", (1.35, 0.9, 0.8)),        # small snout
        ((0, -0.36, 1.3), 0.13, 1.2),                                        # chin
    ]
    for joint, r in (("lowerleg.l", 0.14), ("lowerleg.r", 0.14), ("lowerarm.l", 0.11), ("lowerarm.r", 0.11)):
        head, _tail = bone_points(rig, joint)
        elements.append((head, r, 1.2))
    body = common.metaball_object("ShadowImp", elements, resolution=0.025, threshold=0.6)
    common.voxel_remesh(body, voxel=0.015, smooth_iterations=3)
    return body


def _mouth_z(x):
    """A cheeky grin curling up at both corners."""
    return MOUTH_Z + 2.4 * x * x


def _in_face(pos, normal):
    return normal.y < -0.2 and 1.22 < pos.z < 1.85 and abs(pos.x) < 0.42


def face_offset(pos, normal):
    if not _in_face(pos, normal):
        return 0.0
    front = _smooth01((-normal.y - 0.2) * 3.0)
    d = 0.0
    # Shallow round sockets for the big eyes.
    for side in (-1, 1):
        r = ((pos.x - side * EYE_X) / 0.13) ** 2 + ((pos.z - EYE_Z) / 0.13) ** 2
        if r < 1.2:
            d -= 0.012 * _smooth01((1.2 - r) / 0.8)
    # The grin.
    if abs(pos.x) < 0.22:
        d -= 0.02 * math.exp(-((pos.z - _mouth_z(pos.x)) / 0.016) ** 2) * _smooth01((0.22 - abs(pos.x)) / 0.04)
    # Nostrils on the snout.
    for side in (-1, 1):
        r = ((pos.x - side * 0.035) / 0.014) ** 2 + ((pos.z - 1.47) / 0.012) ** 2
        if r < 1.0 and pos.y < -0.5:
            d -= 0.012 * (1.0 - r)
    return d * front


def sculpt(body):
    mesh = body.data
    for v in mesh.vertices:
        v.co = v.co + v.normal * face_offset(v.co, v.normal)
    mesh.update()
    common.shade_smooth(body)


def colour_body(body):
    def colour(pos, normal):
        n = noise.noise(pos * 4.0)
        c = common.lerp(BODY, BODY_DARK, _smooth01(0.35 - normal.z * 0.35 + n * 0.3))
        c = common.lerp(c, BODY_LIGHT, _smooth01(noise.noise(pos * 7.0 + Vector((3, 1, 5))) - 0.2) * 0.35)
        ax = abs(pos.x)
        # Lavender belly and chest plate.
        if normal.y < -0.15 and pos.z < 1.2:
            belly = 1.0 - (pos.x / 0.3) ** 2 - ((pos.z - 0.84) / 0.34) ** 2
            if belly > 0:
                c = common.lerp(c, BELLY, min(1.0, belly * 2.2) * _smooth01((-normal.y - 0.15) * 3.0))
        # Magenta stripes: bands round the arms (T-pose: along x) and legs.
        if ax > 0.3 and pos.z > 0.9 and normal.z > -0.2:
            if math.sin(ax * 48.0) > 0.72:
                c = common.lerp(c, STRIPE, 0.8)
        if pos.z < 0.5 and pos.z > 0.12 and ax * normal.x * (1 if pos.x > 0 else -1) > 0.0:
            if math.sin(pos.z * 46.0) > 0.78 and abs(normal.x) > 0.35:
                c = common.lerp(c, STRIPE, 0.75)
        # Darker spiky chevrons down the back.
        if normal.y > 0.4 and 0.45 < pos.z < 1.25:
            v = pos.z * 9.0 + ax * 7.0
            if (v - math.floor(v)) < 0.28 and ax < 0.1 + 0.08 * (v - math.floor(v)):
                c = common.lerp(c, BODY_DARK, 0.8)
        if _in_face(pos, normal):
            # Magenta brow markings arcing over the eyes.
            for side in (-1, 1):
                dx, dz = pos.x - side * EYE_X, pos.z - EYE_Z
                r = math.hypot(dx / 1.0, dz / 1.0)
                if 0.175 < r < 0.21 and dz > 0.02 and side * dx > -0.06:
                    c = common.lerp(c, STRIPE, 0.85)
                # A thin darker rim round the eye.
                if 0.15 < r < 0.175:
                    c = common.lerp(c, BODY_DARK, 0.5)
            # The grin, with a pink tongue hint in the middle.
            if abs(pos.x) < 0.2:
                m = _smooth01((0.014 - abs(pos.z - _mouth_z(pos.x))) / 0.007) * _smooth01((0.2 - abs(pos.x)) / 0.03)
                c = common.lerp(c, MOUTH, m)
                if abs(pos.x - 0.03) < 0.05 and -0.02 < pos.z - _mouth_z(pos.x) < -0.004:
                    c = common.lerp(c, TONGUE, 0.8)
            # Nostrils.
            if pos.y < -0.5 and abs(abs(pos.x) - 0.035) < 0.012 and abs(pos.z - 1.47) < 0.01:
                c = BODY_DARK
        return c
    common.color_by(body, colour)


# ------------------------------------------------------------ extras

def horns(body):
    """Curved cream horns sweeping up and out, curling in at the tips."""
    parts = []
    for side in (-1, 1):
        base, _n = _surface(body, HEAD_C + Vector((side * 0.1, 0.02, 0.1)), Vector((side * 0.45, 0.1, 1.0)))
        base = base - Vector((0, 0, 0.04))
        pts = [base, base + Vector((side * 0.14, 0.03, 0.15)), base + Vector((side * 0.2, 0.09, 0.33)),
               base + Vector((side * 0.13, 0.16, 0.47)), base + Vector((side * 0.02, 0.17, 0.5))]
        horn = curved_tube(pts, [0.085, 0.07, 0.05, 0.03, 0.008], "horn")

        def colour(pos, normal, base=base):
            t = (pos - base).length / 0.55
            c = common.lerp(HORN, HORN_TIP, _smooth01(t * 1.4 - 0.4))
            if math.sin(t * 40.0) > 0.8:
                c = common.lerp(c, HORN_TIP, 0.4)
            return c
        common.color_by(horn, colour)
        parts.append(horn)
    return parts


def bat_ear(side, body):
    """A large, flat, pointed bat ear angled out and up, with a scalloped
    lower edge and a magenta inside facing forward."""
    length, width = 0.52, 0.34
    rows, cols = 14, 6
    bm = bmesh.new()
    grid = []
    for i in range(rows + 1):
        t = i / rows
        w = width * (1.0 - t) ** 0.9 * (0.8 + 0.4 * math.sin(math.pi * min(1.0, t * 1.4)))
        row = []
        for j in range(-cols, cols + 1):
            u = j / cols
            half = w * 0.5
            if u < 0:  # the lower edge is scalloped
                half *= 1.0 - 0.22 * abs(math.sin(t * math.pi * 2.5))
            y = -0.05 * (1 - u * u) * (1 - t)   # cupped toward the front
            row.append(bm.verts.new((t * length, y, u * half)))
        grid.append(row)
    for i in range(rows):
        for j in range(2 * cols):
            bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    obj = common.mesh_object("ear", bm)
    solid = obj.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = 0.035
    solid.offset = 0.0
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    loc, _n = _surface(body, HEAD_C + Vector((0, 0.02, 0.02)), Vector((side, 0.08, 0.25)))
    base = loc - Vector((side * 0.06, 0, 0))
    obj.scale = (side, 1, 1)
    # Out and up (about 32 degrees), swept back a touch.
    obj.rotation_euler = (0, math.radians(-32 * side), math.radians(side * 14))
    obj.location = base
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if side < 0:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.flip_normals()
        bpy.ops.object.mode_set(mode="OBJECT")

    def colour(pos, normal):
        t = (pos - base).length / length
        inner = normal.y < -0.3 and t < 0.85
        c = INNER_EAR if inner else common.lerp(BODY, BODY_DARK, _smooth01(0.3 - normal.z * 0.3))
        if inner and t > 0.7:
            c = common.lerp(c, BODY, 0.5)
        return c
    common.color_by(obj, colour, smooth=False)
    return obj


def fangs(body):
    """Two little fangs poking down from the grin."""
    parts = []
    for side in (-1, 1):
        x = side * 0.085
        loc, normal = _surface(body, Vector((x, -0.2, _mouth_z(x))), Vector((0, -1, 0)))
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.022, radius2=0.0, depth=0.06)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi, 3, "X"))
        bmesh.ops.translate(bm, verts=bm.verts, vec=loc + normal * 0.008 + Vector((0, 0, -0.026)))
        fang = common.mesh_object("fang", bm)
        common.set_color(fang, FANG)
        parts.append(fang)
    return parts


def wings():
    """Small bat wings: three finger struts with a scalloped membrane,
    spread out and up from the shoulder blades."""
    parts = []
    tips = [(0.62, 0.42), (0.72, 0.14), (0.55, -0.16)]
    for side in (-1, 1):
        bm = bmesh.new()
        outline = [(0.0, 0.0), (0.22, 0.34)]
        for k, tip in enumerate(tips):
            outline.append(tip)
            if k < len(tips) - 1:
                nxt = tips[k + 1]
                outline.append(((tip[0] + nxt[0]) * 0.5 - 0.12, (tip[1] + nxt[1]) * 0.5 - 0.02))
        outline.append((0.18, -0.12))
        center = bm.verts.new((0, 0, 0))
        ring = [bm.verts.new((x, 0, z)) for x, z in outline]
        for a, b in zip(ring, ring[1:] + ring[:1]):
            bm.faces.new((center, a, b) if side > 0 else (center, b, a))
        rot = Matrix.Rotation(side * math.radians(28), 3, "Z") @ Matrix.Rotation(math.radians(-18), 3, "X")
        for v in bm.verts:
            v.co.x *= side
            v.co = rot @ v.co + Vector((side * 0.15, 0.27, 1.12))
        wing = common.mesh_object("wing", bm)
        solid = wing.modifiers.new("Solid", "SOLIDIFY")
        solid.thickness = 0.03
        common.apply_all_modifiers(wing)
        common.shade_smooth(wing, auto_angle=40)
        inv = rot.inverted()

        def colour(pos, normal, side=side, inv=inv):
            local = inv @ (pos - Vector((side * 0.15, 0.27, 1.12)))
            lx, lz = abs(local.x), local.z
            for tx, tz in tips:
                # Distance to the strut from the root to each finger tip.
                d = abs(lx * tz - lz * tx) / math.hypot(tx, tz)
                if d < 0.022 and lx * tx + lz * tz > 0:
                    return BODY_DARK
            if lx < 0.07:
                return BODY
            vein = abs(math.sin(math.atan2(lz, lx) * 14.0)) < 0.08
            return MEMBRANE_DARK if vein else common.lerp(MEMBRANE, MEMBRANE_DARK, _smooth01(lx * 1.2 - 0.5))
        common.color_by(wing, colour, smooth=False)
        parts.append(wing)
    return parts


def tail():
    """A long tail dipping behind and curling up in an S, ending in a
    magenta arrow tip, with magenta bands."""
    pts = [Vector(p) for p in ((0, 0.26, 0.55), (0.02, 0.48, 0.4), (0.1, 0.7, 0.34), (0.2, 0.88, 0.44),
                               (0.24, 0.98, 0.66), (0.2, 0.96, 0.9), (0.12, 0.88, 1.04))]
    radii = [0.075, 0.062, 0.054, 0.046, 0.04, 0.034, 0.028]
    t = curved_tube(pts, radii, "tail")
    total = sum((b - a).length for a, b in zip(pts, pts[1:]))

    def along(pos):
        best, acc, best_s = 1e9, 0.0, 0.0
        for a, b in zip(pts, pts[1:]):
            seg = b - a
            k = max(0.0, min(1.0, (pos - a).dot(seg) / seg.length_squared))
            d = (a + seg * k - pos).length
            if d < best:
                best, best_s = d, acc + seg.length * k
            acc += seg.length
        return best_s / total

    def tail_colour(pos, normal):
        s = along(pos)
        c = common.lerp(BODY, BODY_DARK, _smooth01(0.3 - normal.z * 0.3))
        if s > 0.15 and math.sin(s * 70.0) > 0.7:
            c = common.lerp(c, STRIPE, 0.8)
        return c
    common.color_by(t, tail_colour, smooth=False)
    # Arrow tip, lying in the plane of the curl, pointing along the tail.
    end, prev = pts[-1], pts[-2]
    fwd = (end - prev).normalized()
    side = Vector((1, 0, 0)).cross(fwd)
    side = fwd.cross(Vector((0, 1, 0))).normalized() if side.length < 1e-3 else side.normalized()
    side = fwd.cross(side).normalized()
    shape = [(0.0, -0.02), (0.1, -0.06), (0.03, 0.02), (0.0, 0.2), (-0.03, 0.02), (-0.1, -0.06)]
    bm = bmesh.new()
    verts = [bm.verts.new(end + side * sx + fwd * sy) for sx, sy in shape]
    bm.faces.new(verts)
    tip = common.mesh_object("arrow", bm)
    solid = tip.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = 0.035
    solid.offset = 0.0
    common.apply_all_modifiers(tip)
    common.set_color(tip, MEMBRANE)
    return [t, tip]


def claws(rig):
    """Three cream claws per hand and foot, each rigid on its bone."""
    groups = []
    for bone in ("hand.l", "hand.r", "toes.l", "toes.r"):
        head, tail_ = bone_points(rig, bone)
        direction = (tail_ - head).normalized()
        side = Vector((1 if bone.endswith(".l") else -1, 0, 0))
        across = direction.cross(Vector((0, 0, 1))).normalized() if abs(direction.z) < 0.9 else side
        parts = []
        for k in (-1, 0, 1):
            base = tail_ + across * k * 0.06 - direction * 0.03
            if bone.startswith("toes"):
                base = tail_ + across * k * 0.07 + Vector((0, -0.02, -0.03))
                point = Vector((0, -1, -0.3)).normalized()
            else:
                point = (direction + Vector((0, -0.4, -0.3))).normalized()
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.03, radius2=0.0, depth=0.1)
            bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.05))
            claw = common.mesh_object("claw", bm)
            claw.rotation_mode = "QUATERNION"
            claw.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(point)
            claw.location = base
            common.select_only([claw])
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            common.set_color(claw, CLAW)
            parts.append(claw)
        groups.append((common.join(parts, "claws_" + bone), bone))
    return groups


def head_tuft(body):
    """A spiky crest between the horns, swept back."""
    parts = []
    rng = random.Random(28)
    for k, (x, lean) in enumerate(((-0.14, -0.35), (-0.06, -0.12), (0.02, 0.0), (0.1, 0.15), (0.16, 0.35),
                                   (-0.02, 0.05))):
        top, _n = _surface(body, Vector((x, 0.02 + 0.06 * (k == 5), 1.55)), Vector((x * 0.6, 0.15 + 0.2 * (k == 5), 1.0)))
        base = top - Vector((0, 0, 0.05))
        length = rng.uniform(0.22, 0.3)
        pts = [tuple(base), (base.x + lean * 0.25, base.y + 0.08, base.z + length * 0.6),
               (base.x + lean * 0.45, base.y + 0.2, base.z + length)]
        clump = chibi.hair_clump(pts, [0.09, 0.06, 0.0], 0.55, (0, -0.4, 1.0), name="tuft", sharp=True)
        common.set_color(clump, TUFT)
        parts.append(clump)
    return common.join(parts, "tuft")


def eyes(body):
    """Oversized eyes with black slit pupils, set in the sockets. As in the
    concept they are slightly squinted: a little flatter, with the upper
    lid sloping down toward the nose for a cheeky look."""
    glows, pupils = [], []
    for side in (-1, 1):
        loc, normal = _surface(body, HEAD_C + Vector((side * 0.08, 0, EYE_Z - HEAD_C.z)), Vector((side * 0.42, -1.0, 0.1)))
        rot = Vector((0, -1, 0)).rotation_difference(normal).to_matrix()
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.16)
        for v in bm.verts:
            v.co.y *= 0.42
            v.co.z *= 0.88
            # The squint: a straight upper lid, low at the inner corner.
            t = max(-1.0, min(1.0, side * v.co.x / 0.16))
            lid = 0.075 + 0.04 * t
            if v.co.z > lid:
                v.co.z = lid + (v.co.z - lid) * 0.15
        bmesh.ops.transform(bm, verts=bm.verts, matrix=rot.to_4x4())
        bmesh.ops.translate(bm, verts=bm.verts, vec=loc + normal * 0.005)
        glows.append(common.mesh_object("eye", bm))
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=10, radius=0.09)
        for v in bm.verts:
            v.co.x *= 0.26   # a vertical slit, short enough to fit under the lid
            v.co.z *= 0.85
            v.co.y *= 0.3
        bmesh.ops.transform(bm, verts=bm.verts, matrix=rot.to_4x4())
        # Pupils sit a little toward the nose: looking at you.
        bmesh.ops.translate(bm, verts=bm.verts, vec=loc + normal * 0.078 - Vector((side * 0.025, 0, 0.03)))
        pupils.append(common.mesh_object("pupil", bm))
    glow = common.join(glows, "ShadowImp_Eyes")
    common.shade_smooth(glow)
    paint_bake.flat_material(glow, EYE, emission=1.5, name="imp_eye_glow")
    dark = common.join(pupils, "ShadowImp_Pupils")
    common.shade_smooth(dark)
    paint_bake.flat_material(dark, PUPIL, name="imp_pupil")
    return [glow, dark]


# -------------------------------------------------------------- build

def build():
    common.reset(28)
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

    rigid_parts = [(p, "head") for p in horns(body) + [bat_ear(-1, body), bat_ear(1, body), head_tuft(body)] + fangs(body)]
    rigid_parts += [(p, "chest") for p in wings()]
    rigid_parts += [(p, "hips") for p in tail()]
    rigid_parts += claws(rig)
    eye_parts = eyes(body)

    common.select_only([body, rig])
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    extras = []
    for part, bone in rigid_parts:
        rigid(part, bone)
        extras.append(part)
    body = common.join([body] + extras, "ShadowImp")
    high = None if os.environ.get("HIGH_POLY") else chibi.lowpoly(body, BODY_BUDGET)
    paint_bake.paint(body, size=1024, ao_distance=0.2, ao_strength=0.6, edge_strength=0.3, edge_radius=0.015,
                     noise_scale=5.0, stroke_strength=0.08, cavity=0.2, light=(1.15, 1.05, 1.1),
                     shadow=(0.45, 0.4, 0.62), high=high)

    for obj in eye_parts:
        rigid(obj, "head")
        obj.parent = rig
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
    eye = common.join(eye_parts, "ShadowImp_Eyes")

    from characters import imp_anims
    imp_anims.build_actions(rig)

    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "shadow_imp.glb"), [rig, body, eye], animations=True)
    print("shadow_imp tris:", common.triangle_count([body, eye]))

    if os.environ.get("CLAY"):
        rig.data.pose_position = "REST"
        preview.render_clay([body, eye], "shadow_imp")
        rig.data.pose_position = "POSE"
    rig.animation_data_create()
    for az in (-25, 90, 180):
        rig.animation_data.action = bpy.data.actions.get("Imp_Idle")
        preview.render([body, eye], "shadow_imp_idle_%d" % az, frame=1, elevation=8, azimuth=az)
    for action_name, frames in imp_anims.PREVIEW_FRAMES.items():
        rig.animation_data.action = bpy.data.actions.get(action_name)
        for frame in frames:
            preview.render([body, eye], "shadow_imp_%s_%02d" % (action_name, frame), frame=frame, elevation=10,
                           azimuth=-35, size=320, samples=12)


if __name__ == "__main__":
    build()
