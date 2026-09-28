"""The sibling: KayKit Mage upgraded into a little wizard. Subdivided,
rounder body with a bigger head, a huge floppy starry hat, a purple
cape, and a wand with a glowing star. Keeps the Mage rig and all
animations. Output: sibling.glb"""

import math
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

from lib import common, paint_bake, preview  # noqa: E402
from characters import kid_lib  # noqa: E402

HAT = (0.2, 0.26, 0.72)
HAT_DARK = (0.1, 0.12, 0.42)
STAR = (1.0, 0.86, 0.3)
BAND = (0.95, 0.72, 0.25)
CAPE = (0.55, 0.28, 0.72)
WAND = (0.5, 0.32, 0.18)
BODY_PARTS = ["Mage_ArmLeft", "Mage_ArmRight", "Mage_Body", "Mage_Head", "Mage_LegLeft", "Mage_LegRight"]


def wizard_hat(head_top, head_center):
    """Wide brim + tall cone that flops over near the tip."""
    parts = []
    brim_z = head_top - 0.18
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.68, radius2=0.62, depth=0.06)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        v.co.z += math.sin(a * 3) * 0.03  # wavy brim
    bmesh.ops.translate(bm, verts=bm.verts, vec=(head_center.x, head_center.y, brim_z))
    brim = common.mesh_object("brim", bm)
    common.shade_smooth(brim)
    common.set_color(brim, HAT_DARK)
    parts.append(brim)
    # Cone as a skin-tube along a bent spine.
    spine = []
    for i in range(7):
        t = i / 6
        bend = max(0.0, t - 0.45) ** 2 * 1.6
        spine.append(Vector((head_center.x - bend * 0.9, head_center.y + bend * 0.5, brim_z + 0.02 + t * 0.95 - bend * 0.35)))
    radii = [0.44 * (1 - t / 6) ** 0.85 + 0.02 for t in range(7)]
    cone = kid_lib.tube(spine, radii, "hat_cone", levels=2)

    def cone_colour(pos, normal):
        star = noise.noise(pos * 7.5)
        if star > 0.36:
            return STAR
        if pos.z < brim_z + 0.14:
            return BAND
        return common.lerp(HAT_DARK, HAT, max(0.0, min(1.0, 0.5 + normal.z * 0.5)))
    common.color_by(cone, cone_colour, smooth=False)
    parts.append(cone)
    # A little star charm at the flopped tip.
    tip = spine[-1]
    parts.append(star_mesh(tip + Vector((-0.02, 0, -0.1)), 0.09, STAR))
    return parts


def star_mesh(center, radius, colour, depth=0.04):
    bm = bmesh.new()
    ring = []
    for i in range(10):
        a = i / 10 * math.tau + math.pi / 2
        r = radius if i % 2 == 0 else radius * 0.45
        ring.append((math.cos(a) * r, math.sin(a) * r))
    front = [bm.verts.new((center.x + x, center.y - depth, center.z + y)) for x, y in ring]
    back = [bm.verts.new((center.x + x, center.y + depth, center.z + y)) for x, y in ring]
    cf = bm.verts.new((center.x, center.y - depth * 1.6, center.z))
    cb = bm.verts.new((center.x, center.y + depth * 1.6, center.z))
    for i in range(10):
        j = (i + 1) % 10
        bm.faces.new((cf, front[i], front[j]))
        bm.faces.new((cb, back[j], back[i]))
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = common.mesh_object("star", bm)
    common.set_color(obj, colour)
    return obj


def wand(rig):
    """Wand along the handslot.r bone (+Y) with a glowing star tip."""
    bone = rig.data.bones["handslot.r"]
    to_world = rig.matrix_world @ bone.matrix_local
    stick = kid_lib.tube([Vector((0, -0.12, 0)), Vector((0, 0.5, 0))], [0.035, 0.028], "wand", levels=1)
    common.color_by(stick, lambda p, n: BAND if -0.05 < p.y < 0.05 else WAND)
    stick.data.transform(to_world)
    glow = star_mesh(Vector((0, 0, 0)), 0.13, STAR, depth=0.035)
    # Star faces the side of the wand tip.
    glow.data.transform(Matrix.Translation((0, 0.58, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"))
    glow.data.transform(to_world)
    return stick, glow


def build():
    rig = kid_lib.load(os.path.join(common.KAYKIT, "adventurers", "Mage.glb"),
                       drop={"Spellbook", "Spellbook_open", "2H_Staff", "1H_Wand", "Mage_Hat"})
    bpy.context.view_layer.update()
    body_parts = [bpy.data.objects[n] for n in BODY_PARTS]
    for part in body_parts:
        kid_lib.texture_to_attribute(part)
        kid_lib.subdivide_skinned(part, 1)
    body = common.join(body_parts, "Sibling")
    kid_lib.scale_by_weight(body, rig, "head", 1.14, pivot_offset=(0, 0, 0.02))
    head_verts = [v.co for v in body.data.vertices if v.co.z > 1.3]
    head_top = max(c.z for c in head_verts)
    head_center = sum(head_verts, Vector()) / len(head_verts)

    # Cape: bone-parented rigid mesh -> recolour and bind to the chest.
    cape = bpy.data.objects["Mage_Cape"]
    cape.data.transform(cape.matrix_world)
    cape.parent = None
    cape.matrix_world = Matrix.Identity(4)
    kid_lib.texture_to_attribute(cape)
    kid_lib.recolor(cape, lambda c, p, n: CAPE)
    kid_lib.rigid_part(cape, rig, "chest")

    extras = [cape]
    for part in wizard_hat(head_top, head_center):
        kid_lib.rigid_part(part, rig, "head")
        extras.append(part)
    body = common.join([body] + extras, "Sibling")
    common.decimate(body, 5200)

    stick, glow = wand(rig)
    kid_lib.rigid_part(stick, rig, "handslot.r")
    kid_lib.rigid_part(glow, rig, "handslot.r")
    stick.name = "Sibling_Wand"

    kid_lib.paint_and_export(rig, [body, stick], "sibling_body_tmp")
    paint_bake.flat_material(glow, STAR, emission=3.0, name="wand_star_glow")
    glow.name = "Sibling_WandStar"
    rig.data.pose_position = "POSE"
    common.export_glb(os.path.join(common.OUT_DIR, "sibling.glb"), [rig, body, stick, glow], animations=True)
    tmp = os.path.join(common.OUT_DIR, "sibling_body_tmp.glb")
    if os.path.exists(tmp):
        os.remove(tmp)
    print("sibling tris:", common.triangle_count([body, stick, glow]))
    rig.data.pose_position = "REST"
    preview.render([body, stick, glow], "sibling", elevation=10, azimuth=25)
    rig.data.pose_position = "POSE"
    for action_name, frame in (("Running_A", 8), ("Spellcast_Shoot", 12)):
        rig.animation_data_create()
        rig.animation_data.action = bpy.data.actions.get(action_name)
        preview.render([body, stick, glow], "sibling_" + action_name, frame=frame, elevation=10, azimuth=25, size=384)


if __name__ == "__main__":
    build()
