"""Quick Cycles preview renders of an asset for visual review.

render()            the painted/coloured asset as it will look.
render_clay()       sculpt review: matte grey clay, strong key + rim light,
                    several views. Judges forms, not paint.
render_silhouette() black fill on white at game size: is the outline
                    readable and interesting from a distance?
"""

import math
import os

import bpy
from mathutils import Vector

from . import common


def _bounds(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in objects:
        if obj.type != "MESH":
            continue
        ev = obj.evaluated_get(depsgraph)
        for corner in ev.bound_box:
            w = ev.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def _sun(name, energy, rotation, colour=(1, 1, 1)):
    data = bpy.data.lights.new(name, "SUN")
    data.energy = energy
    data.color = colour
    sun = common.link(bpy.data.objects.new(name, data))
    sun.rotation_euler = rotation
    return sun


def _shoot(objects, name, size, elevation, azimuth, samples, frame, background, bg_strength, lights, override,
           ortho=False, zoom=0.85):
    os.makedirs(common.PREVIEW_DIR, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    if frame is not None:
        scene.frame_set(frame)
    lo, hi = _bounds(objects)
    center = (lo + hi) * 0.5
    radius = max((hi - lo).length * 0.5, 0.1)

    world = bpy.data.worlds.new("preview") if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (*background, 1)
    bg.inputs["Strength"].default_value = bg_strength

    cam_data = bpy.data.cameras.new("preview_cam")
    cam_data.lens = 50
    if ortho:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = (hi - lo).z * 1.08
    cam = common.link(bpy.data.objects.new("preview_cam", cam_data))
    el = math.radians(elevation)
    az = math.radians(azimuth)
    distance = radius / math.tan(cam_data.angle * 0.5) * zoom
    cam.location = center + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * distance
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    # Hide everything that isn't being shot (other previews share the scene).
    shown = {o.name for o in objects}
    hidden = [o for o in scene.objects if o.type == "MESH" and o.name not in shown and not o.hide_render]
    for o in hidden:
        o.hide_render = True
    layer = bpy.context.view_layer
    layer.material_override = override
    suns = [_sun("preview_sun%d" % i, *light) for i, light in enumerate(lights)]
    scene.render.filepath = os.path.join(common.PREVIEW_DIR, name + ".png")
    bpy.ops.render.render(write_still=True)
    layer.material_override = None
    for o in hidden:
        o.hide_render = False
    for obj in [cam] + suns:
        bpy.data.objects.remove(obj)
    print("preview", scene.render.filepath)


def render(objects, name, size=512, elevation=35.0, azimuth=35.0, samples=24, frame=None):
    _shoot(objects, name, size, elevation, azimuth, samples, frame, (0.35, 0.45, 0.55), 0.6,
           [(2.5, (math.radians(40), 0, math.radians(30)))], None)


def _clay_material():
    mat = bpy.data.materials.get("preview_clay")
    if mat is None:
        mat = bpy.data.materials.new("preview_clay")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (0.42, 0.4, 0.38, 1)
        bsdf.inputs["Roughness"].default_value = 1.0
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
    return mat


# (suffix, azimuth, elevation) for the standard sculpt review.
BODY_VIEWS = (("front", 0, 6), ("34", 35, 8), ("side", 90, 4), ("back", 180, 10))
FACE_VIEWS = (("front", 0, 3), ("34", 32, 4), ("side", -90, 2))


def render_clay(objects, name, views=BODY_VIEWS, size=640, frame=None, zoom=0.85):
    """Matte clay with a warm top-left key and a cool back rim, so plane
    changes, folds and landmarks read the way the painted bake will."""
    lights = [(3.2, (math.radians(35), math.radians(-20), math.radians(-35)), (1.0, 0.96, 0.9)),
              (2.2, (math.radians(-60), 0, math.radians(160)), (0.75, 0.85, 1.0))]
    for suffix, az, el in views:
        _shoot(objects, "%s_clay_%s" % (name, suffix), size, el, az, 32, frame, (0.16, 0.17, 0.2), 0.35, lights,
               _clay_material(), zoom=zoom)


def render_silhouette(objects, name, azimuths=(0, 35, 90, 180), size=128):
    """Flat black shapes on white at roughly in-game size."""
    mat = bpy.data.materials.get("preview_black") or bpy.data.materials.new("preview_black")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    for az in azimuths:
        _shoot(objects, "%s_sil_%d" % (name, az), size, 8, az, 4, None, (1, 1, 1), 1.0, [], mat, ortho=True)
