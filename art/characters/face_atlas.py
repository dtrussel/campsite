"""The face atlas: a painted head's eyes and mouth in every state the game
shows (face_paint.STATES: open, closed for a blink, happy, hurt, dazed),
so the game can blink a kid and change their expression without bones.

How it is made, in a kid's builder (see leo.py):

`face_atlas.paint_head(head, high, FACE, params, kid)` does it all in
place of the head's `paint_bake.paint` call:

1. `bake_cells`, just before the head's own paint bake. Each state's face is painted
   with face_paint (`expression`) and baked under the head's painted
   lighting (paint_bake's material, same AO, light and strokes) onto
   the front-projected face plane, so a cell matches the baked head
   around it. Only the window is kept: brows, eyes, nose and mouth. A
   blink is a state of its own (closed eyes over the neutral mouth),
   as the game blinks only a neutral face.
2. After `paint_bake.paint(head, ...)`, `finish`
   gives the head's front faces inside the window their own material
   (`<Name>_Face_painted`, the same texture) and the face-plane UVs as
   the second UV map (TEXCOORD_1, Godot's UV2), and writes
   `game/assets/custom/<kid>_face.webp` plus `<kid>_face.tres` (a
   FaceAtlas: the window, the cells and the states).

In the game the face surface's shader (painted_face.gdshader) replaces
the window with the cell of the state shown; the edges of a cell fade
into the baked head.
"""

import os

import bpy
import numpy as np
from PIL import Image

from lib import common, paint_bake
from characters import face_paint

# The atlas's texels per face-plane texel (face_paint.RES over the face).
SCALE = 0.6
PAD = 4
# A cell fades into the baked head over this border (face-plane metres).
FEATHER = 0.012
# Faces in front of the head's middle (-Y) take the face; the back of the
# head projects onto the same face-plane UVs. (By position, not normal:
# a mirrored half of a head can carry flipped normals.)


def _front(mesh):
    """A test for a polygon of `mesh` lying in the front half."""
    ys = [v.co.y for v in mesh.vertices]
    middle = (min(ys) + max(ys)) * 0.5
    return lambda poly: poly.center.y < middle


def window(L):
    """The face window: a rectangle (u0, v0, u1, v1) in face-plane metres,
    v up, roomy enough for every state's brows, eyes and mouth."""
    lift = 0.012 + 0.006  # the happy and dazed brows go up this much, plus their arch
    brow = max(dz + arch + thick for dz, _tilt, thick, arch in L.brows)
    eu = L.eye_x + L.eye_w + L.wing + 0.03
    return (-eu, L.mouth_z - 0.022 - L.lip_lower - 0.025, eu, L.eye_z + L.eye_h + brow + lift + 0.02)


def _plane_px(L, rect):
    """A face-plane rectangle as (left, top, right, bottom) pixels of a
    face_paint image (row 0 at the top)."""
    s = L.size
    k = face_paint.RES / (2 * s)
    u0, v0, u1, v1 = rect
    return (int(round((u0 + s) * k)), int(round((s - v1) * k)), int(round((u1 + s) * k)), int(round((s - v0) * k)))


def _in_window(uv, L, margin=0.0):
    """True if a FaceUV coordinate (0..1, v up) is inside the window."""
    s = L.size
    u, v = (uv[0] - 0.5) * 2 * s, (uv[1] - 0.5) * 2 * s
    r = window(L)
    return r[0] - margin <= u <= r[2] + margin and r[1] - margin <= v <= r[3] + margin


def paint_head(head, high, L, params, kid, states=face_paint.STATES):
    """Bakes `kid`'s face atlas and then paints the head (paint_bake.paint
    with `params`, from the dense copy `high` or None), and gives it the
    face surface. Returns the atlas path."""
    cells = bake_cells(head, high, L, params, states, name=kid)
    saved = save_face_uv(head)
    paint_bake.paint(head, source="attribute", high=high, **params)
    return finish(head, saved, L, cells, kid)


def bake_cells(low, high, L, params, states=face_paint.STATES, name="face"):
    """Paints and bakes every state's face on the dense head `high` (the
    copy chibi.lowpoly made of `low`, or None for `low` itself), lit as paint_bake.paint lights the
    head with `params`. Returns {state: RGB float array of the face plane,
    row 0 at the top}."""
    own = high is None
    high = high or low
    mesh = high.data
    mesh.uv_layers.new(name="FaceBake")
    # Fetched after the new layer: adding one moves the layers' data.
    face_uv = mesh.uv_layers["FaceUV"]
    bake_uv = mesh.uv_layers["FaceBake"]
    mesh.uv_layers.active = bake_uv  # the bake writes through the active UVs
    front = _front(mesh)
    for poly in mesh.polygons:
        loops = list(poly.loop_indices)
        keep = front(poly) and any(_in_window(face_uv.data[i].uv, L, margin=0.03) for i in loops)
        for i in loops:
            bake_uv.data[i].uv = face_uv.data[i].uv if keep else (0.0, 0.0)
    p = dict(paint_bake.DEFAULTS)
    p.update(params)
    scene = bpy.context.scene
    scene.cycles.samples = p["samples"]
    scene.render.bake.margin = 24  # past the jaw line, so the cell has no dark rim
    scene.render.bake.margin_type = "EXTEND"
    scene.render.bake.use_selected_to_active = False
    if not own:
        low.hide_render = True
        high.hide_render = False
    old_materials = [slot.material for slot in high.material_slots]
    out = {}
    folder = os.path.join(common.ROOT, "build", "art_faces")
    for state in states:
        png = os.path.join(folder, "%s_%s.png" % (name, state))
        face_paint.paint_face(face_paint.expression(L, state), png)
        bake_mat = paint_bake._build_bake_material(high, "attribute", dict(p, overlay=(png, "FaceUV")))
        image = bpy.data.images.new("%s_%s_cell" % (name, state), face_paint.RES, face_paint.RES, alpha=False)
        target = bake_mat.node_tree.nodes.new("ShaderNodeTexImage")
        target.image = image
        bake_mat.node_tree.nodes.active = target
        uv_node = bake_mat.node_tree.nodes.new("ShaderNodeUVMap")
        uv_node.uv_map = "FaceBake"
        bake_mat.node_tree.links.new(uv_node.outputs["UV"], target.inputs["Vector"])
        mesh.materials.clear()
        mesh.materials.append(bake_mat)
        common.select_only([high])
        bpy.ops.object.bake(type="EMIT")
        pixels = np.array(image.pixels[:], dtype=np.float32).reshape(face_paint.RES, face_paint.RES, 4)
        out[state] = pixels[::-1, :, :3].copy()
        bpy.data.images.remove(image)
        bpy.data.materials.remove(bake_mat)
    mesh.materials.clear()
    for material in old_materials:
        mesh.materials.append(material)
    mesh.uv_layers.remove(mesh.uv_layers["FaceBake"])
    mesh.uv_layers.active = mesh.uv_layers["FaceUV"]
    scene.render.bake.margin_type = "ADJACENT_FACES"
    if not own:
        high.hide_render = True
        low.hide_render = False
    return out


def save_face_uv(obj):
    """The FaceUV coordinates of `obj`'s loops, to put back after the
    paint bake (which keeps only its own UVs)."""
    layer = obj.data.uv_layers["FaceUV"]
    return [tuple(d.uv) for d in layer.data]


def finish(obj, saved_uv, L, cells, kid):
    """After the head's paint bake: the face surface and its UVs on `obj`
    (see the module docstring), and the atlas files for `kid`. Returns
    the atlas path."""
    mesh = obj.data
    layer = mesh.uv_layers.new(name="FaceUV")
    for i, uv in enumerate(saved_uv):
        layer.data[i].uv = uv
    mesh.uv_layers["PaintUV"].active_render = True
    mesh.uv_layers.active = mesh.uv_layers["PaintUV"]
    base = mesh.materials[0]
    face = base.copy()
    face.name = obj.name.replace("_Head", "") + "_Face_painted"
    mesh.materials.append(face)
    faces = 0
    front = _front(mesh)
    for poly in mesh.polygons:
        if front(poly) and any(_in_window(layer.data[i].uv, L) for i in poly.loop_indices):
            poly.material_index = 1
            faces += 1
    print("%s: %d faces take the face atlas" % (obj.name, faces))
    return _write_atlas(L, cells, kid, obj.name, face.name)


def _fill(rgb, passes=64):
    """Grows the baked colours into the unbaked (black) texels past the
    head's outline, so filtering never pulls a dark rim onto the jaw."""
    rgb = rgb.copy()
    known = rgb.sum(axis=2) > 1e-4
    for _ in range(passes):
        if known.all():
            break
        total = np.zeros_like(rgb)
        count = np.zeros(known.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx), axis=(0, 1))
            total += np.roll(rgb, (dy, dx), axis=(0, 1)) * k[..., None]
            count += k
        grow = ~known & (count > 0)
        rgb[grow] = total[grow] / count[grow][:, None]
        known = known | grow
    return rgb


def _cell(L, plane, rect):
    """One window of a baked face plane, scaled to the atlas, with the
    feathered alpha."""
    left, top, right, bottom = _plane_px(L, rect)
    rgb = _fill(np.clip(plane[top:bottom, left:right], 0.0, 1.0))
    crop = Image.fromarray((rgb * 255 + 0.5).astype(np.uint8))
    w = max(1, int(round((right - left) * SCALE)))
    h = max(1, int(round((bottom - top) * SCALE)))
    crop = crop.resize((w, h), Image.LANCZOS)
    px = FEATHER * face_paint.RES / (2 * L.size) * SCALE
    x = np.minimum(np.arange(w) + 0.5, w - np.arange(w) - 0.5) / px
    y = np.minimum(np.arange(h) + 0.5, h - np.arange(h) - 0.5) / px
    ramp = np.clip(np.minimum.outer(y, x), 0.0, 1.0)
    alpha = (ramp * ramp * (3 - 2 * ramp) * 255 + 0.5).astype(np.uint8)
    rgba = np.dstack([np.asarray(crop), alpha])
    return Image.fromarray(rgba, "RGBA")


def _write_atlas(L, cells, kid, mesh_name, material_name):
    states = list(cells)
    rect = window(L)
    tiles = [_cell(L, cells[state], rect) for state in states]
    cw, ch = tiles[0].size
    columns = 2 if len(tiles) > 2 else 1
    rows = (len(tiles) + columns - 1) // columns
    width = PAD + (cw + PAD) * columns
    height = PAD + (ch + PAD) * rows
    atlas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    origins = []
    for i, tile in enumerate(tiles):
        x, y = PAD + (i % columns) * (cw + PAD), PAD + (i // columns) * (ch + PAD)
        atlas.paste(tile, (x, y))
        origins.append((x / width, y / height))
    path = os.path.join(common.OUT_DIR, kid + "_face.webp")
    if os.environ.get("BAKE_SIZE") and not os.environ.get("DRAFT_EXPORT"):
        print("draft bake (BAKE_SIZE): not writing", os.path.relpath(path, common.ROOT))
        return path
    atlas.save(path, "WEBP", quality=92, method=6)
    s = L.size
    plane = ((rect[0] + s) / (2 * s), (s - rect[3]) / (2 * s), (rect[2] - rect[0]) / (2 * s), (rect[3] - rect[1]) / (2 * s))
    tres = os.path.join(common.OUT_DIR, kid + "_face.tres")
    with open(tres, "w") as f:
        f.write('[gd_resource type="Resource" script_class="FaceAtlas" load_steps=3 format=3]\n\n')
        f.write('[ext_resource type="Script" path="res://scripts/characters/face_atlas.gd" id="1_script"]\n')
        f.write('[ext_resource type="Texture2D" path="res://assets/custom/%s_face.webp" id="2_atlas"]\n\n' % kid)
        f.write("[resource]\n")
        f.write('script = ExtResource("1_script")\n')
        f.write('texture = ExtResource("2_atlas")\n')
        f.write('mesh = "%s"\n' % mesh_name)
        f.write('material = "%s"\n' % material_name)
        f.write("states = PackedStringArray(%s)\n" % ", ".join('"%s"' % state for state in states))
        f.write("window = Rect2(%.6f, %.6f, %.6f, %.6f)\n" % plane)
        f.write("cell_size = Vector2(%.6f, %.6f)\n" % (cw / width, ch / height))
        f.write("cell_origins = PackedVector2Array(%s)\n" % ", ".join("%.6f, %.6f" % o for o in origins))
    print("face atlas: %s (%dx%d, %d states)" % (os.path.relpath(path, common.ROOT), width, height, len(states)))
    return path
