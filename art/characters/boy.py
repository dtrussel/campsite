"""The boy: KayKit Rogue upgraded into a young camper hero. Subdivided,
rounder body with a bigger head and spiky hair tufts, a green scarf,
a camper's backpack with a red bedroll, and a chunky cartoon axe.
Keeps the Rogue rig and all 76 animations. Output: boy.glb"""

import math
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from lib import common, preview  # noqa: E402
from characters import kid_lib  # noqa: E402

HAIR = (0.86, 0.46, 0.18)
HAIR_DARK = (0.6, 0.28, 0.1)
SCARF = (0.2, 0.62, 0.32)
BAG = (0.58, 0.36, 0.2)
BAG_DARK = (0.38, 0.22, 0.12)
BEDROLL = (0.86, 0.24, 0.2)
STRAP = (0.3, 0.2, 0.14)
STEEL = (0.78, 0.82, 0.88)
HANDLE = (0.55, 0.34, 0.18)
WRAP = (0.2, 0.5, 0.75)
BODY_PARTS = ["Rogue_ArmLeft", "Rogue_ArmRight", "Rogue_Body", "Rogue_Head", "Rogue_LegLeft", "Rogue_LegRight"]


def hair_tufts(head_top):
    parts = []
    spots = [(0.0, 0.1, 0.0, 0.2), (0.16, 0.05, 0.25, 0.16), (-0.16, 0.05, -0.25, 0.16), (0.05, 0.25, 0.1, 0.15),
             (-0.08, -0.15, -0.35, 0.14), (0.1, -0.12, 0.35, 0.13)]
    for x, y, tilt, h in spots:
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=7, radius1=0.12, radius2=0.0, depth=h * 2.2)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, h * 1.1))
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0),
                         matrix=Matrix.Rotation(tilt, 3, "Y") @ Matrix.Rotation(-y * 1.2, 3, "X"))
        bmesh.ops.translate(bm, verts=bm.verts, vec=(x, y, head_top - 0.12))
        tuft = common.mesh_object("tuft", bm)
        common.shade_smooth(tuft, auto_angle=60)
        common.color_by(tuft, lambda p, n: common.lerp(HAIR_DARK, HAIR, max(0.0, min(1.0, (p.z - head_top + 0.1) * 3.0))))
        parts.append(tuft)
    return parts


def scarf():
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, segments=16, radius=0.27)
    obj = common.mesh_object("scarf", bm)
    obj.location = (0, -0.01, 1.2)
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True)
    obj.modifiers.new("Skin", "SKIN")
    bm2 = bmesh.new()
    bm2.from_mesh(obj.data)
    layer = bm2.verts.layers.skin.verify()
    for v in bm2.verts:
        v[layer].radius = (0.085, 0.07)
    bm2.to_mesh(obj.data)
    bm2.free()
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    tail = kid_lib.tube([Vector((0.12, -0.26, 1.18)), Vector((0.18, -0.34, 1.02)), Vector((0.22, -0.36, 0.86))],
                       [0.07, 0.06, 0.05], "scarf_tail")
    scarf_obj = common.join([obj, tail], "scarf")
    common.color_by(scarf_obj, lambda p, n: SCARF if (math.sin(p.z * 40) > -0.6) else (0.92, 0.9, 0.7))
    return scarf_obj


def backpack():
    parts = []
    bag = kid_lib.rounded_box((0.52, 0.26, 0.56), (0, 0.36, 0.86), bevel=0.08, name="bag")
    common.color_by(bag, lambda p, n: BAG if n.y < 0.5 or p.z < 0.98 else BAG_DARK)
    parts.append(bag)
    flap = kid_lib.rounded_box((0.54, 0.28, 0.18), (0, 0.37, 1.09), bevel=0.06, name="flap")
    common.set_color(flap, BAG_DARK)
    parts.append(flap)
    pocket = kid_lib.rounded_box((0.3, 0.1, 0.2), (0, 0.51, 0.78), bevel=0.04, name="pocket")
    common.set_color(pocket, BAG_DARK)
    parts.append(pocket)
    roll = kid_lib.tube([Vector((-0.34, 0.36, 1.24)), Vector((0.34, 0.36, 1.24))], [0.11, 0.11], "bedroll", levels=2)
    common.color_by(roll, lambda p, n: BEDROLL if abs(p.x) < 0.24 or abs(p.x) > 0.3 else STRAP)
    parts.append(roll)
    for sx in (-0.17, 0.17):
        strap = kid_lib.tube([Vector((sx, 0.24, 1.14)), Vector((sx * 1.1, -0.2, 1.16)), Vector((sx * 1.2, -0.26, 0.9))],
                             [0.03, 0.03, 0.03], "strap", levels=0)
        common.set_color(strap, STRAP)
        parts.append(strap)
    return parts


def axe(rig):
    """Chunky cartoon axe, built in the handslot.r bone's frame the way
    KayKit weapons are: handle along the bone's +Y, blade toward -X."""
    bone = rig.data.bones["handslot.r"]
    to_world = rig.matrix_world @ bone.matrix_local
    parts = []
    handle = kid_lib.tube([Vector((0, -0.22, 0)), Vector((0, 0.35, 0)), Vector((0, 0.86, 0))],
                          [0.05, 0.046, 0.044], "handle", levels=1)
    common.color_by(handle, lambda p, n: WRAP if -0.12 < p.y < 0.12 else (HANDLE if p.y < 0.8 else (0.4, 0.25, 0.14)))
    parts.append(handle)
    # Blade: a thick crescent wedge on the -X side of the handle top.
    bm = bmesh.new()
    outline = [(0.02, 0.62), (-0.2, 0.55), (-0.36, 0.5), (-0.44, 0.7), (-0.36, 0.92), (-0.2, 0.86), (0.02, 0.84)]
    front = [bm.verts.new((x, y, 0.07)) for x, y in outline]
    back = [bm.verts.new((x, y, -0.07)) for x, y in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(len(front)):
        j = (i + 1) % len(front)
        bm.faces.new((front[j], front[i], back[i], back[j]))
    for v in front + back:
        if v.co.x < -0.33:
            v.co.z *= 0.2  # sharp edge
    # Butt of the axe on the other side.
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    blade = common.mesh_object("blade", bm)
    bev = blade.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.02
    bev.segments = 2
    common.apply_all_modifiers(blade)
    common.shade_smooth(blade, auto_angle=40)
    common.color_by(blade, lambda p, n: (0.98, 0.99, 1.0) if p.x < -0.36 else STEEL, smooth=False)
    parts.append(blade)
    butt = kid_lib.rounded_box((0.14, 0.2, 0.12), (0.08, 0.73, 0), bevel=0.03, name="butt")
    common.set_color(butt, (0.55, 0.58, 0.64))
    parts.append(butt)
    weapon = common.join(parts, "axe")
    weapon.data.transform(to_world)
    return weapon


def build():
    rig = kid_lib.load(os.path.join(common.KAYKIT, "adventurers", "Rogue.glb"),
                       drop={"1H_Crossbow", "2H_Crossbow", "Knife", "Knife_Offhand", "Throwable", "Rogue_Cape"})
    bpy.context.view_layer.update()
    body_parts = [bpy.data.objects[n] for n in BODY_PARTS]
    for part in body_parts:
        kid_lib.texture_to_attribute(part)
        kid_lib.subdivide_skinned(part, 1)
    body = common.join(body_parts, "Boy")
    kid_lib.scale_by_weight(body, rig, "head", 1.14, pivot_offset=(0, 0, 0.02))
    # Warm auburn hair to match the tufts.
    kid_lib.recolor(body, lambda c, p, n: HAIR if (p.z > 1.55 and c[0] > c[2] * 1.3 and c[1] < 0.3 and c[0] < 0.6) else None)
    head_top = max(v.co.z for v in body.data.vertices)

    extras = []
    for tuft in hair_tufts(head_top):
        kid_lib.rigid_part(tuft, rig, "head")
        extras.append(tuft)
    s = scarf()
    kid_lib.rigid_part(s, rig, "chest")
    extras.append(s)
    for part in backpack():
        kid_lib.rigid_part(part, rig, "chest")
        extras.append(part)
    body = common.join([body] + extras, "Boy")
    common.decimate(body, 5200)

    weapon = axe(rig)
    kid_lib.rigid_part(weapon, rig, "handslot.r")
    weapon.name = "Boy_Axe"

    kid_lib.paint_and_export(rig, [body, weapon], "boy")
    rig.data.pose_position = "REST"
    preview.render([body, weapon], "boy", elevation=10, azimuth=25)
    rig.data.pose_position = "POSE"
    for action_name, frame in (("Running_A", 8), ("1H_Melee_Attack_Chop", 14)):
        action = bpy.data.actions.get(action_name)
        rig.animation_data_create()
        rig.animation_data.action = action
        preview.render([body, weapon], "boy_" + action_name, frame=frame, elevation=10, azimuth=25, size=384)


if __name__ == "__main__":
    build()
