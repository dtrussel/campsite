"""Mushroom Gremlin (feature 021): a small, quick thief that sneaks into
camp, grabs resources and runs. Built like the Shadow Imp on the KayKit
Skeleton_Minion rig, so it shares that rig's animations.

The body is a pale, stubby mushroom stem with short limbs; the head is
a big spotted purple cap (rigid on the head bone) with two glowing
eyes peeking from underneath, and it carries a patched loot sack on its
back. Output: game/assets/custom/mushroom_gremlin.glb"""

import math
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from characters.shadow_imp import DEFORM, bone_points, curved_tube, rigid  # noqa: E402

STEM = (0.93, 0.86, 0.72)
STEM_DARK = (0.72, 0.6, 0.48)
CAP = (0.52, 0.2, 0.62)
CAP_DARK = (0.3, 0.1, 0.4)
SPOT = (1.0, 0.95, 0.82)
GILLS = (0.85, 0.72, 0.62)
SACK = (0.66, 0.52, 0.32)
PATCH = (0.42, 0.55, 0.3)
EYE = (0.75, 1.0, 0.3)

BODY_RADII = {
    "upperleg": (0.14, 0.12), "lowerleg": (0.11, 0.12), "foot": (0.12, 0.11), "toes": (0.1, 0.06),
    "upperarm": (0.09, 0.08), "lowerarm": (0.08, 0.09), "wrist": (0.09, 0.09), "hand": (0.11, 0.07),
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
        ((0, 0.0, 0.55), 0.34, 2.0),                                   # round bottom
        ((0, -0.02, 0.85), 0.38, 2.0, "ELLIPSOID", (1.0, 0.95, 1.1)),  # stem-like belly
        ((0, 0.0, 1.12), 0.3, 2.0),                                    # neck
        ((0, -0.05, 1.35), 0.34, 2.0),                                 # face under the cap
    ]
    body = common.metaball_object("MushroomGremlin", elements, resolution=0.03, threshold=0.6)
    common.voxel_remesh(body, voxel=0.022, smooth_iterations=3)
    common.decimate(body, 3000)
    common.shade_smooth(body)

    def colour(pos, normal):
        n = noise.noise(pos * 6.0)
        c = common.lerp(STEM, STEM_DARK, max(0.0, min(1.0, 0.25 - normal.z * 0.3 + n * 0.3)))
        # A little mischievous grin.
        mouth_y = 1.27 + (pos.x ** 2) * 1.6
        if normal.y < -0.5 and abs(pos.x) < 0.16 and abs(pos.z - mouth_y) < 0.025:
            c = (0.2, 0.08, 0.1)
        return c
    common.color_by(body, colour)
    return body


def cap():
    """A big domed cap with a rolled rim, white spots and pale gills."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=0.62)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z *= 0.18
        else:
            v.co.z *= 0.72
        v.co.xy *= 1.0 + noise.noise(v.co * 3.0) * 0.05
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0.02, 1.52))
    obj = common.mesh_object("cap", bm)
    common.shade_smooth(obj)

    def colour(pos, normal):
        if normal.z < -0.3:
            ring = math.sin(math.atan2(pos.y, pos.x) * 18) > 0.2
            return GILLS if ring else common.lerp(GILLS, STEM_DARK, 0.4)
        spot = noise.noise(pos * 7.0)
        if spot > 0.32 and normal.z > 0.1:
            return SPOT
        return common.lerp(CAP, CAP_DARK, max(0.0, min(1.0, 0.4 - normal.z * 0.5 + noise.noise(pos * 3) * 0.3)))
    common.color_by(obj, colour, smooth=False)
    return obj


def sack():
    """A lumpy loot sack on its back with a green patch and a tie."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.3)
    for v in bm.verts:
        v.co.z *= 1.1
        v.co.y *= 0.8
        v.co += Vector((noise.noise(v.co * 4), noise.noise(v.co * 4 + Vector((3, 0, 0))), 0)) * 0.04
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0.05, 0.36, 0.95))
    bag = common.mesh_object("sack", bm)
    common.shade_smooth(bag)

    def colour(pos, normal):
        if normal.y > 0.6 and abs(pos.x - 0.12) < 0.1 and abs(pos.z - 0.9) < 0.1:
            return PATCH
        return common.lerp(SACK, STEM_DARK, max(0.0, min(1.0, 0.3 + noise.noise(pos * 9) * 0.5)))
    common.color_by(bag, colour, smooth=False)
    neck = curved_tube([Vector((0.05, 0.36, 1.26)), Vector((0.08, 0.3, 1.36)), Vector((0.02, 0.22, 1.4))], [0.07, 0.05, 0.035], "tie")
    common.set_color(neck, SACK)
    return [bag, neck]


def eyes():
    parts = []
    for side in (-1, 1):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.085)
        for v in bm.verts:
            v.co.y *= 0.5
            v.co.z *= 1.15
        bmesh.ops.translate(bm, verts=bm.verts, vec=(side * 0.13, -0.34, 1.4))
        parts.append(common.mesh_object("eye", bm))
    glow = common.join(parts, "MushroomGremlin_Eyes")
    common.shade_smooth(glow)
    paint_bake.flat_material(glow, EYE, emission=2.4, name="gremlin_eye_glow")
    return glow


def build():
    common.reset(21)
    bpy.ops.import_scene.gltf(filepath=os.path.join(common.KAYKIT, "skeletons", "Skeleton_Minion.glb"))
    rig = bpy.data.objects["Rig"]
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj)
    for bone in rig.data.bones:
        bone.use_deform = bone.name in DEFORM
    rig.data.pose_position = "REST"

    body = body_mesh(rig)
    common.select_only([body, rig])
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")

    extras = []
    head_cap = cap()
    rigid(head_cap, "head")
    extras.append(head_cap)
    for part in sack():
        rigid(part, "chest")
        extras.append(part)
    body = common.join([body] + extras, "MushroomGremlin")
    paint_bake.paint(body, size=1024, ao_distance=0.2, ao_strength=0.6, edge_strength=0.3, edge_radius=0.02,
                     noise_scale=6.0, light=(1.15, 1.08, 1.05), shadow=(0.45, 0.4, 0.55))

    eye = eyes()
    rigid(eye, "head")
    eye.parent = rig
    mod = eye.modifiers.new("Armature", "ARMATURE")
    mod.object = rig

    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "mushroom_gremlin.glb"), [rig, body, eye], animations=True)
    print("mushroom_gremlin tris:", common.triangle_count([body, eye]))

    rig.data.pose_position = "REST"
    preview.render([body, eye], "mushroom_gremlin", elevation=12, azimuth=float(os.environ.get("AZ", "25")))
    rig.data.pose_position = "POSE"
    for action_name, frame in (("Walking_D_Skeletons", 10),):
        action = bpy.data.actions.get(action_name)
        if action:
            rig.animation_data_create()
            rig.animation_data.action = action
            preview.render([body, eye], "mushroom_gremlin_" + action_name, frame=frame, elevation=12, azimuth=25, size=384)


if __name__ == "__main__":
    build()
