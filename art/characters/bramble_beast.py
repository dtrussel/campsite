"""Bramble Beast (feature 018): a hulking, slow thicket-creature that
tears down fences. Built like the Shadow Imp on the KayKit
Skeleton_Minion rig, so it shares that rig's animations (awaken, walk,
punch, hit, collapse).

The body is metaballs along the deform bones, but gorilla-shaped: short
legs, a wide mossy hump, long arms ending in club-like fists, and a small
head sunk low between the shoulders. Rigid extras (thorns, moss tufts,
a leafy crown) are weighted 100% to their bone. Two ember eyes glow.
Output: game/assets/custom/bramble_beast.glb"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from characters.shadow_imp import DEFORM, bone_points, rigid  # noqa: E402

BARK = (0.4, 0.27, 0.16)
BARK_DARK = (0.2, 0.13, 0.08)
MOSS = (0.33, 0.52, 0.16)
MOSS_LIGHT = (0.55, 0.7, 0.24)
THORN = (0.86, 0.78, 0.6)
THORN_TIP = (0.45, 0.2, 0.14)
LEAF = (0.36, 0.6, 0.2)
LEAF_AUTUMN = (0.85, 0.5, 0.18)
EYE = (1.0, 0.45, 0.12)

# bone -> (radius at head, radius at tail): stumpy legs, huge forearms.
BODY_RADII = {
    "upperleg": (0.25, 0.22), "lowerleg": (0.22, 0.25), "foot": (0.23, 0.2), "toes": (0.19, 0.1),
    "upperarm": (0.2, 0.18), "lowerarm": (0.2, 0.3), "wrist": (0.33, 0.34), "hand": (0.35, 0.24),
}


def body_mesh(rig):
    elements = []
    for bone in rig.data.bones:
        key = bone.name.split(".")[0]
        if key not in BODY_RADII:
            continue
        r0, r1 = BODY_RADII[key]
        head, tail = bone_points(rig, bone.name)
        steps = max(2, int((tail - head).length / 0.05))
        for i in range(steps + 1):
            t = i / steps
            elements.append((head.lerp(tail, t), r0 + (r1 - r0) * t, 2.0))
    elements += [
        ((0, 0.02, 0.55), 0.42, 2.0),                                   # hips
        ((0, -0.02, 0.86), 0.55, 2.0, "ELLIPSOID", (1.05, 0.95, 1.0)),  # belly
        ((0, 0.06, 1.14), 0.6, 2.0, "ELLIPSOID", (1.4, 1.0, 0.85)),     # broad shoulders
        ((0, 0.22, 1.32), 0.46, 2.0),                                   # mossy hump
        ((0, -0.3, 1.42), 0.3, 2.0),                                    # low, sunk head
        ((0, -0.46, 1.3), 0.19, 2.0),                                   # heavy jaw
    ]
    body = common.metaball_object("BrambleBeast", elements, resolution=0.035, threshold=0.6)
    common.voxel_remesh(body, voxel=0.025, smooth_iterations=2)
    common.displace_noise(body, strength=0.03, scale=6.0, seed=3)
    common.decimate(body, 4200)
    common.shade_smooth(body)
    return body


def colour_body(body):
    def colour(pos, normal):
        n = noise.noise(pos * 5.0)
        streak = noise.noise(Vector((pos.x * 14.0, pos.y * 14.0, pos.z * 2.0)))
        c = common.lerp(BARK, BARK_DARK, max(0.0, min(1.0, 0.35 + streak * 0.6 - normal.z * 0.2)))
        # Moss grows over the up-facing back, shoulders and fists.
        moss = (normal.z - 0.35) * 3.0 + n * 1.2 + (0.4 if pos.y > 0.1 else 0.0)
        if moss > 0:
            c = common.lerp(c, common.lerp(MOSS, MOSS_LIGHT, max(0.0, min(1.0, 0.5 + n))), min(1.0, moss))
        # A dark hollow of a face.
        if pos.y < -0.48 and 1.2 < pos.z < 1.56 and abs(pos.x) < 0.25:
            c = common.lerp(c, BARK_DARK, 0.7)
        return c
    common.color_by(body, colour)


def thorn(base, direction, length, radius):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=radius, radius2=0.0, depth=length)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, length / 2))
    obj = common.mesh_object("thorn", bm)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    obj.location = base
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    def colour(pos, normal):
        t = (pos - base).length / length
        return common.lerp(THORN, THORN_TIP, max(0.0, min(1.0, t * 1.4 - 0.3)))
    common.color_by(obj, colour, smooth=False)
    return obj


def surface_point(body, origin, direction):
    """Where a ray from inside the body leaves its surface."""
    hit, loc, normal, _ = body.ray_cast(origin + direction * 2.0, -direction)
    return (loc, normal) if hit else (origin + direction * 0.5, direction)


def thorns(body, rig):
    """Thorns on the back and shoulders (chest), and on each forearm."""
    rng = random.Random(18)
    groups = {"chest": [], "lowerarm.l": [], "lowerarm.r": []}
    for i in range(24):
        a = rng.uniform(-1.2, 1.2)
        up = rng.uniform(0.2, 1.0)
        direction = Vector((math.sin(a) * 0.9, 0.55 + 0.5 * math.cos(a), up)).normalized()
        loc, normal = surface_point(body, Vector((0, 0.1, 1.15)), direction)
        groups["chest"].append(thorn(loc - normal * 0.02, normal.lerp(Vector((0, 0.3, 1)), 0.3),
                                     rng.uniform(0.2, 0.34), rng.uniform(0.045, 0.065)))
    for side, bone in ((1, "lowerarm.l"), (-1, "lowerarm.r")):
        head, tail = bone_points(rig, bone)
        for k in range(4):
            p = head.lerp(tail, 0.2 + k * 0.2)
            direction = Vector((side * 0.8, 0.5 * (1 if k % 2 else -0.2), 0.5)).normalized()
            loc, normal = surface_point(body, p, direction)
            groups[bone].append(thorn(loc - normal * 0.02, normal, 0.2, 0.04))
    return groups


def moss_tuft(center, size, seed):
    rng = random.Random(seed)
    parts = []
    for k in range(4):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=size * rng.uniform(0.6, 1.0))
        for v in bm.verts:
            v.co.z *= 0.55
        offset = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * size * 0.8
        bmesh.ops.translate(bm, verts=bm.verts, vec=center + offset)
        blob = common.mesh_object("moss", bm)
        common.set_color(blob, MOSS_LIGHT if k % 2 else MOSS)
        parts.append(blob)
    return parts


def leaf_crown():
    """A few broad leaves sprouting from the hump, one gone autumn-orange."""
    parts = []
    for k, (x, tilt, colour) in enumerate(((-0.2, -0.5, LEAF), (0.05, 0.0, LEAF_AUTUMN), (0.25, 0.5, LEAF))):
        bm = bmesh.new()
        bmesh.ops.create_circle(bm, cap_ends=True, segments=10, radius=0.16)
        for v in bm.verts:
            v.co.y *= 0.45
            v.co.x += 0.16
        leaf = common.mesh_object("leaf", bm)
        solid = leaf.modifiers.new("Solid", "SOLIDIFY")
        solid.thickness = 0.02
        common.apply_all_modifiers(leaf)
        leaf.rotation_euler = (math.radians(20), math.radians(-60 + tilt * 40), math.radians(90 + k * 25))
        leaf.location = (x, 0.28, 1.5)
        common.select_only([leaf])
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        common.set_color(leaf, colour)
        parts.append(leaf)
    return parts


def eyes():
    parts = []
    for side in (-1, 1):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=8, radius=0.06)
        for v in bm.verts:
            v.co.z *= 0.7
            v.co.y *= 0.5
        bmesh.ops.translate(bm, verts=bm.verts, vec=(side * 0.12, -0.58, 1.49))
        parts.append(common.mesh_object("eye", bm))
    glow = common.join(parts, "BrambleBeast_Eyes")
    common.shade_smooth(glow)
    paint_bake.flat_material(glow, EYE, emission=2.6, name="bramble_eye_glow")
    return glow


def build():
    common.reset(18)
    bpy.ops.import_scene.gltf(filepath=os.path.join(common.KAYKIT, "skeletons", "Skeleton_Minion.glb"))
    rig = bpy.data.objects["Rig"]
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj)
    for bone in rig.data.bones:
        bone.use_deform = bone.name in DEFORM
    rig.data.pose_position = "REST"

    body = body_mesh(rig)
    colour_body(body)
    thorn_groups = thorns(body, rig)
    common.select_only([body, rig])
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")

    extras = []
    for bone, parts in thorn_groups.items():
        for part in parts:
            rigid(part, bone)
            extras.append(part)
    for part in moss_tuft(Vector((0.34, 0.12, 1.4)), 0.12, 1) + moss_tuft(Vector((-0.3, 0.16, 1.42)), 0.11, 2) + leaf_crown():
        rigid(part, "chest")
        extras.append(part)
    body = common.join([body] + extras, "BrambleBeast")
    paint_bake.paint(body, size=1024, ao_distance=0.2, ao_strength=0.7, edge_strength=0.35, edge_radius=0.02,
                     noise_scale=6.0, light=(1.15, 1.08, 1.0), shadow=(0.45, 0.42, 0.4))

    eye = eyes()
    rigid(eye, "head")
    eye.parent = rig
    mod = eye.modifiers.new("Armature", "ARMATURE")
    mod.object = rig

    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "bramble_beast.glb"), [rig, body, eye], animations=True)
    print("bramble_beast tris:", common.triangle_count([body, eye]))

    rig.data.pose_position = "REST"
    preview.render([body, eye], "bramble_beast", elevation=12, azimuth=float(os.environ.get("AZ", "25")))
    rig.data.pose_position = "POSE"
    for action_name, frame in (("Walking_D_Skeletons", 10), ("Unarmed_Melee_Attack_Punch_A", 12)):
        action = bpy.data.actions.get(action_name)
        if action:
            rig.animation_data_create()
            rig.animation_data.action = action
            preview.render([body, eye], "bramble_beast_" + action_name, frame=frame, elevation=12, azimuth=25, size=384)


if __name__ == "__main__":
    build()
