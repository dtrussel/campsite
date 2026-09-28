"""Quick Cycles preview renders of an asset for visual review."""

import math
import os

import bpy
from mathutils import Vector

from . import common


def render(objects, name, size=512, elevation=35.0, azimuth=35.0, samples=24, frame=None):
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

    # Bounds of the evaluated objects.
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
    center = (lo + hi) * 0.5
    radius = max((hi - lo).length * 0.5, 0.1)

    world = bpy.data.worlds.new("preview") if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.35, 0.45, 0.55, 1)
    bg.inputs["Strength"].default_value = 0.6

    cam_data = bpy.data.cameras.new("preview_cam")
    cam_data.lens = 50
    cam = common.link(bpy.data.objects.new("preview_cam", cam_data))
    el = math.radians(elevation)
    az = math.radians(azimuth)
    distance = radius / math.tan(cam_data.angle * 0.5) * 0.85
    cam.location = center + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * distance
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    sun_data = bpy.data.lights.new("preview_sun", "SUN")
    sun_data.energy = 2.5
    sun = common.link(bpy.data.objects.new("preview_sun", sun_data))
    sun.rotation_euler = (math.radians(40), 0, math.radians(30))

    scene.render.filepath = os.path.join(common.PREVIEW_DIR, name + ".png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    bpy.data.objects.remove(sun)
    print("preview", scene.render.filepath)
