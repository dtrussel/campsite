"""Shadow Imp: a brand-new cute-spooky creature built on the KayKit
Skeleton_Minion rig so it keeps all of that rig's animations (awaken
from the ground, walk, punch, hit, collapse...).

The body is generated from the rig itself: metaball capsules along each
deform bone (big round head, pot belly, stubby limbs), voxel-remeshed
and auto-weighted. Rigid extras (horns, ears, fangs, bat wings, spade
tail) are weighted 100% to their bone. Eyes are a separate glowing
mesh. Output: game/assets/custom/shadow_imp.glb"""

import math
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402

BODY = (0.34, 0.19, 0.55)
BODY_DARK = (0.18, 0.09, 0.32)
BELLY = (0.66, 0.46, 0.86)
HORN = (0.97, 0.9, 0.74)
HORN_TIP = (0.55, 0.42, 0.5)
MEMBRANE = (0.72, 0.22, 0.62)
MOUTH = (0.1, 0.02, 0.1)
FANG = (1.0, 0.97, 0.92)
EYE = (1.0, 0.8, 0.2)

DEFORM = {"root", "hips", "spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
          "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "upperleg.l", "lowerleg.l", "foot.l", "toes.l",
          "upperleg.r", "lowerleg.r", "foot.r", "toes.r"}

# bone -> (radius at head, radius at tail)
BODY_RADII = {
    "upperleg": (0.19, 0.16), "lowerleg": (0.15, 0.15), "foot": (0.15, 0.14), "toes": (0.13, 0.08),
    "upperarm": (0.13, 0.115), "lowerarm": (0.11, 0.12), "wrist": (0.12, 0.12), "hand": (0.15, 0.1),
}


def bone_points(rig, name):
    b = rig.data.bones[name]
    return rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local


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
    # Torso: hips, pot belly, chest, and a big round head.
    elements += [
        ((0, 0.0, 0.52), 0.38, 2.0),
        ((0, -0.07, 0.78), 0.5, 2.0, "ELLIPSOID", (1.0, 0.95, 1.05)),
        ((0, -0.02, 1.03), 0.4, 2.0),
        ((0, 0.0, 1.18), 0.32, 2.0),
        ((0, -0.03, 1.52), 0.62, 2.0, "ELLIPSOID", (1.12, 1.0, 0.95)),
        ((0, -0.2, 1.42), 0.34, 2.0),  # muzzle / cheeks
    ]
    body = common.metaball_object("ShadowImp", elements, resolution=0.035, threshold=0.6)
    common.voxel_remesh(body, voxel=0.025, smooth_iterations=3)
    common.decimate(body, 3600)
    common.shade_smooth(body)
    return body


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


def horns():
    parts = []
    for side in (-1, 1):
        pts = [Vector((side * 0.22, 0.02, 1.68)), Vector((side * 0.33, 0.05, 1.86)), Vector((side * 0.48, 0.1, 1.98)),
               Vector((side * 0.62, 0.16, 1.98))]
        horn = curved_tube(pts, [0.1, 0.075, 0.045, 0.012], "horn")

        def colour(pos, normal):
            t = (abs(pos.x) - 0.22) / 0.4
            return common.lerp(HORN, HORN_TIP, max(0.0, min(1.0, t * 1.3 - 0.2)))
        common.color_by(horn, colour)
        parts.append(horn)
    return parts


def ears():
    parts = []
    for side in (-1, 1):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.12, radius2=0.0, depth=0.32)
        for v in bm.verts:
            v.co.y *= 0.45  # flatten
        # Point sideways and a little up.
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.16))  # base at origin
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(side * math.radians(68), 3, "Y"))
        bmesh.ops.translate(bm, verts=bm.verts, vec=(side * 0.55, 0.03, 1.6))
        ear = common.mesh_object("ear", bm)
        common.shade_smooth(ear, auto_angle=50)

        def colour(pos, normal):
            return common.lerp(BODY, MEMBRANE, 0.55) if normal.y < -0.3 else BODY
        common.color_by(ear, colour, smooth=False)
        parts.append(ear)
    return parts


def fangs():
    parts = []
    for side in (-1, 1):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.035, radius2=0.0, depth=0.08)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi, 3, "X"))
        bmesh.ops.translate(bm, verts=bm.verts, vec=(side * 0.11, -0.575, 1.3))
        fang = common.mesh_object("fang", bm)
        common.set_color(fang, FANG)
        parts.append(fang)
    return parts


def wings():
    """Small bat wings: three finger struts with a scalloped membrane,
    swept back from the shoulder blades."""
    parts = []
    for side in (-1, 1):
        bm = bmesh.new()
        tips = [(0.62, 0.34), (0.66, 0.08), (0.46, -0.18)]
        outline = [(0.0, 0.0), (0.2, 0.3)]
        for k, tip in enumerate(tips):
            outline.append(tip)
            if k < len(tips) - 1:
                nxt = tips[k + 1]
                # Scallop between finger tips: pull the midpoint inward.
                outline.append(((tip[0] + nxt[0]) * 0.5 - 0.1, (tip[1] + nxt[1]) * 0.5 - 0.02))
        outline.append((0.16, -0.1))
        center = bm.verts.new((0, 0, 0))
        ring = [bm.verts.new((x, 0, z)) for x, z in outline]
        for a, b in zip(ring, ring[1:] + ring[:1]):
            bm.faces.new((center, a, b) if side > 0 else (center, b, a))
        # Sweep back and tilt up, then place at the shoulder blade.
        rot = Matrix.Rotation(side * math.radians(35), 3, "Z") @ Matrix.Rotation(math.radians(-20), 3, "X")
        for v in bm.verts:
            v.co.x *= side
            v.co = rot @ v.co + Vector((side * 0.16, 0.26, 1.14))
        wing = common.mesh_object("wing", bm)
        solid = wing.modifiers.new("Solid", "SOLIDIFY")
        solid.thickness = 0.035
        common.apply_all_modifiers(wing)
        common.shade_smooth(wing, auto_angle=40)

        def colour(pos, normal, side=side):
            local = abs(pos.x) - 0.16
            strut = any(abs(local * 1.0 - t[0] * 0.8) < 0.02 for t in tips)
            return BODY_DARK if (strut or local < 0.08) else MEMBRANE
        common.color_by(wing, colour, smooth=False)
        parts.append(wing)
    return parts


def tail():
    pts = [Vector((0, 0.3, 0.5)), Vector((0, 0.55, 0.42)), Vector((0, 0.75, 0.55)), Vector((0, 0.83, 0.78))]
    t = curved_tube(pts, [0.09, 0.07, 0.05, 0.035], "tail")
    common.set_color(t, BODY)
    bm = bmesh.new()
    spade = [bm.verts.new(p) for p in ((0, 0.83, 0.76), (0.13, 0.85, 0.88), (0, 0.87, 1.06), (-0.13, 0.85, 0.88))]
    bm.faces.new(spade)
    tip = common.mesh_object("spade", bm)
    solid = tip.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = 0.04
    common.apply_all_modifiers(tip)
    common.set_color(tip, MEMBRANE)
    return [t, tip]


def eyes():
    parts = []
    pupils = []
    for side in (-1, 1):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=10, radius=0.15)
        for v in bm.verts:
            v.co.z *= 1.2
            v.co.y *= 0.55
        bmesh.ops.translate(bm, verts=bm.verts, vec=(side * 0.22, -0.56, 1.56))
        parts.append(common.mesh_object("eye", bm))
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=8, radius=0.065)
        for v in bm.verts:
            v.co.z *= 1.5
            v.co.y *= 0.5
        bmesh.ops.translate(bm, verts=bm.verts, vec=(side * 0.2, -0.625, 1.54))
        pupils.append(common.mesh_object("pupil", bm))
    glow = common.join(parts, "ShadowImp_Eyes")
    common.shade_smooth(glow)
    paint_bake.flat_material(glow, EYE, emission=2.2, name="imp_eye_glow")
    dark = common.join(pupils, "ShadowImp_Pupils")
    common.shade_smooth(dark)
    paint_bake.flat_material(dark, (0.05, 0.02, 0.06), name="imp_pupil")
    return [glow, dark]


def colour_body(body):
    def colour(pos, normal):
        n = noise.noise(pos * 4.0)
        c = common.lerp(BODY, BODY_DARK, max(0.0, min(1.0, 0.3 - normal.z * 0.4 + n * 0.25)))
        # Pale belly on the front of the torso.
        if 0.4 < pos.z < 1.15 and abs(pos.x) < 0.4 and normal.y < -0.35:
            c = common.lerp(c, BELLY, min(1.0, (-normal.y - 0.35) * 2.5))
        # Dark hands and feet.
        if abs(pos.x) > 0.76 or pos.z < 0.18:
            c = common.lerp(c, BODY_DARK, 0.65)
        # A wide grin.
        mouth_y = 1.33 + (pos.x ** 2) * 1.2
        if normal.y < -0.5 and abs(pos.x) < 0.24 and abs(pos.z - mouth_y) < 0.035:
            c = MOUTH
        return c
    common.color_by(body, colour)


def rigid(obj, bone):
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


def build():
    common.reset(66)
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
    common.select_only([body, rig])
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")

    extras = []
    for part in horns() + ears() + fangs():
        rigid(part, "head")
        extras.append(part)
    for part in wings():
        rigid(part, "chest")
        extras.append(part)
    for part in tail():
        rigid(part, "hips")
        extras.append(part)
    body = common.join([body] + extras, "ShadowImp")
    paint_bake.paint(body, size=1024, ao_distance=0.2, ao_strength=0.65, edge_strength=0.3, edge_radius=0.02,
                     noise_scale=5.0, light=(1.15, 1.05, 1.1), shadow=(0.45, 0.4, 0.62))

    eye_parts = eyes()
    for obj in eye_parts:
        rigid(obj, "head")
        obj.parent = rig
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
    eye = common.join(eye_parts, "ShadowImp_Eyes")

    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "shadow_imp.glb"), [rig, body, eye], animations=True)
    print("shadow_imp tris:", common.triangle_count([body, eye]))

    rig.data.pose_position = "REST"
    preview.render([body, eye], "shadow_imp", elevation=12, azimuth=20)
    rig.data.pose_position = "POSE"
    for action_name, frame in (("Walking_D_Skeletons", 10), ("Unarmed_Melee_Attack_Punch_A", 12), ("Skeletons_Awaken_Floor", 30)):
        action = bpy.data.actions.get(action_name)
        if action:
            rig.animation_data_create()
            rig.animation_data.action = action
            preview.render([body, eye], "shadow_imp_" + action_name, frame=frame, elevation=12, azimuth=20, size=384)


if __name__ == "__main__":
    build()
