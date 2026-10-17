"""Proportion checks against a concept sheet (feature 043).

What works for an agent building a character from code is a closed,
*measured* loop: render the model from the sheet's view, compare it with
the reference in numbers, change the script, repeat. Judging renders by
eye alone drifts. This module does the measuring:

landmarks()   heights and widths of the posed (evaluated) meshes, as
              fractions of the total height - compare them with
              landmarks read off the sheet in the same units.
silhouette()  an orthographic flat-white silhouette from the front or
              side, height-normalised, for overlaying on the sheet.
"""

import math
import os

import bpy
from mathutils import Vector

from . import common


def _points(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    pts = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        ev = obj.evaluated_get(depsgraph)
        mesh = ev.to_mesh()
        mw = ev.matrix_world
        pts += [mw @ v.co for v in mesh.vertices]
        ev.to_mesh_clear()
    return pts


def width_at(points, z, band=0.02, x_limit=None):
    """Full width (x extent) of the points within `band` of height z;
    `x_limit` ignores points further out (the hanging arms)."""
    xs = [p.x for p in points if abs(p.z - z) <= band and (x_limit is None or abs(p.x) <= x_limit)]
    return (max(xs) - min(xs)) if xs else 0.0


def landmarks(body_objects, head_obj, heights):
    """Heights as fractions of the total height. `heights` maps names to
    z (metres) of the landmarks (the rig's joints) in the current pose."""
    pts = _points(body_objects + [head_obj])
    top = max(p.z for p in pts)
    head = _points([head_obj])
    chin = min(p.z for p in head if abs(p.x) < 0.03 and p.y < 0)
    crown = max(p.z for p in head)
    out = {"height_m": top, "head": (crown - chin) / top, "chin": chin / top}
    for name, z in heights.items():
        out[name] = z / top
    return out


def widths(body_objects, bands, top):
    """{name: (z, side)}: the full width at z (side None), or the width of
    one leg (side +1: the points with x > 0), as fractions of `top`."""
    pts = _points(body_objects)
    out = {}
    for name, (z, side) in bands.items():
        use = [p for p in pts if side is None or p.x * side > 0.0]
        out[name] = width_at(use, z) / top
    return out


def silhouette(objects, path, view="front", size=512):
    """Flat white on black, orthographic, fitted to the height."""
    scene = bpy.context.scene
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for p in _points(objects):
        lo = Vector(map(min, lo, p))
        hi = Vector(map(max, hi, p))
    height = hi.z - lo.z
    cam_data = bpy.data.cameras.new("measure_cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = height * 1.02
    cam = common.link(bpy.data.objects.new("measure_cam", cam_data))
    mid = (lo + hi) * 0.5
    if view == "front":
        cam.location = (mid.x, lo.y - 10.0, mid.z)
        cam.rotation_euler = (math.pi / 2, 0, 0)
    else:   # her left side
        cam.location = (hi.x + 10.0, mid.y, mid.z)
        cam.rotation_euler = (math.pi / 2, 0, math.pi / 2)
    scene.camera = cam
    # Cycles with a flat white emission override (Workbench needs EGL,
    # which headless containers lack).
    flat = bpy.data.materials.new("measure_flat")
    flat.use_nodes = True
    nodes = flat.node_tree.nodes
    nodes.clear()
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (1, 1, 1, 1)
    out = nodes.new("ShaderNodeOutputMaterial")
    flat.node_tree.links.new(emit.outputs[0], out.inputs[0])
    hidden = []
    for obj in scene.objects:
        if obj.type == "MESH" and obj not in objects and not obj.hide_render:
            obj.hide_render = True
            hidden.append(obj)
    bpy.context.view_layer.material_override = flat
    world = scene.world or bpy.data.worlds.new("measure_world")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 4
    scene.render.film_transparent = False
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.context.view_layer.material_override = None
    for obj in hidden:
        obj.hide_render = False
    bpy.data.objects.remove(cam)
    print("silhouette", path)
