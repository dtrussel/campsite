"""Clay contact sheet and GIF of one kid clip, from the game camera.

    .venv-blender/bin/python art/review/clip_sheet.py <kid> <state or clip> [options]

    .venv-blender/bin/python art/review/clip_sheet.py leo walk
    .venv-blender/bin/python art/review/clip_sheet.py nela Spellcast_Shoot --azimuth 90

Loads the committed model (game/assets/custom/<kid>.glb), so it shows
what the game plays; rebuild the kid first to review a clip in progress.
A state (idle, walk, move, attack, ...) is looked up in the kid's hero
data (game/resources/heroes/<kid>.tres); anything else is a clip name.
The kid is matte clay, seen from the gameplay camera's pitch (42 deg,
34 deg lens) and turned `--azimuth` degrees from facing the camera.

Walk and run travel over a checked ground (half-metre squares) at the
speed the game moves them (walk 1.6 m/s, the clip played at the game's
walk scale; run at the hero's move speed, the clip played at the game's
run scale), with the camera following,
so a sliding foot shows against the squares. `--travel 0` stands them
still; `--travel <m/s>` sets another speed. The build states (hammer,
tinker) hold the barrel mallet in place of the kid's prop, as the game
does.

Writes <out>/<kid>_<clip>.png (a strip of `--frames` frames, evenly
spread over the clip) and <out>/<kid>_<clip>.gif (every frame at the
game's play speed). <out> is build/clip_sheets/ unless `--out` says.

Options: --frames N (8), --size PX per frame (256), --azimuth DEG (35),
--travel M/S, --samples N (12), --out DIR.

--rekey keys the kid's hand-made clips (art/characters/hero_clips.py)
onto the committed model first, so a clip in progress can be reviewed
without rebuilding the kid (minutes for the bake); it also prints the
stick hand's height and the stick's pitch per frame.
"""

import argparse
import math
import os
import re
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from PIL import Image  # noqa: E402

from lib import common  # noqa: E402

GAME = os.path.join(common.ROOT, "game")
PITCH = 42.0  # CameraFollow.pitch_degrees
LENS_FOV = 34.0  # the gameplay camera's vertical field of view
WALK_SPEED = 1.6  # CharacterVisual.walk_speed
# The speed gameplay plays each action at (game/tools/clip_checks.gd).
PLAY_SPEEDS = {"attack": 1.5, "hit": 1.4, "death": 1.0, "getup": 1.0, "cheer": 1.2, "gather": 1.3,
               "chop": 1.5, "pick": 1.5, "tinker": 1.6, "hammer": 1.8}


# The build beat holds the barrel mallet (CharacterVisual.show_tool) and
# hides the kid's own prop; the sheet does the same for these states.
MALLET_STATES = ("hammer", "tinker")
TOOL_SCALE = 1.9  # CharacterVisual.TOOL_SCALE


def hold_mallet(rig, hidden, material):
    """Puts the build mallet in the right hand as the game does: on the
    hand slot, its glTF axes as the bone's (the handle along the slot's
    +Y, the barrel along +X), and hides the parts it replaces."""
    for obj in bpy.context.scene.objects:
        if obj.name in hidden:
            obj.hide_render = True
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(GAME, "assets", "custom", "hammer.glb"))
    holder = common.link(bpy.data.objects.new("mallet", None))
    for obj in bpy.data.objects:
        if obj in before or obj is holder:
            continue
        if obj.parent is None:
            obj.parent = holder
        if obj.type == "MESH":
            obj.data.materials.clear()
            obj.data.materials.append(material)
    # Blender's import turned the mallet Z-up; turn it back to glTF axes.
    holder.rotation_euler = (-math.pi * 0.5, 0, 0)
    holder.scale = (TOOL_SCALE,) * 3
    follow = holder.constraints.new("CHILD_OF")
    follow.target = rig
    follow.subtarget = "handslot.r"
    follow.set_inverse_pending = False
    follow.inverse_matrix.identity()


def hero_data(kid):
    """The kid's state -> clip map and the numbers the game moves it by."""
    path = os.path.join(GAME, "resources", "heroes", kid + ".tres")
    text = open(path).read() if os.path.exists(path) else ""
    clips = dict(re.findall(r'&"(\w+)": "([^"]+)"', text))

    def number(key, default):
        found = re.search(r"^%s = ([\d.]+)" % key, text, re.M)
        return float(found.group(1)) if found else default

    hidden = re.search(r"^tool_hidden_parts = PackedStringArray\((.*)\)", text, re.M)
    hidden = re.findall(r'"([^"]+)"', hidden.group(1)) if hidden else []
    return (clips, number("model_scale", 0.7), number("move_speed", 4.0), number("reference_speed", 7.0),
            number("walk_reference_speed", 0.0), hidden)


def clay(name, colour):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    return mat


def checked_ground(scale):
    """A ground plane in half-metre (game) squares at model scale."""
    bpy.ops.mesh.primitive_plane_add(size=400)
    ground = bpy.context.active_object
    mat = bpy.data.materials.new("ground_checker")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    checker = nodes.new("ShaderNodeTexChecker")
    checker.inputs["Color1"].default_value = (0.11, 0.12, 0.11, 1)
    checker.inputs["Color2"].default_value = (0.17, 0.18, 0.17, 1)
    # 400 model units across; a square is 0.5 m in the game.
    checker.inputs["Scale"].default_value = 400 * scale / 0.5 / 2
    mat.node_tree.links.new(checker.outputs["Color"], nodes.get("Principled BSDF").inputs["Base Color"])
    nodes.get("Principled BSDF").inputs["Roughness"].default_value = 1.0
    ground.data.materials.append(mat)
    return ground


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("kid")
    parser.add_argument("clip")
    parser.add_argument("--frames", type=int, default=8)
    parser.add_argument("--size", type=int, default=256)
    parser.add_argument("--azimuth", type=float, default=35.0)
    parser.add_argument("--travel", type=float, default=None)
    parser.add_argument("--samples", type=int, default=12)
    parser.add_argument("--out", default=os.path.join(common.ROOT, "build", "clip_sheets"))
    parser.add_argument("--rekey", action="store_true")
    args = parser.parse_args()

    clips, model_scale, move_speed, reference_speed, walk_reference_speed, hidden = hero_data(args.kid)
    state = args.clip if args.clip in clips else None
    clip = clips.get(args.clip, args.clip)
    play = PLAY_SPEEDS.get(state, 1.0)
    travel = 0.0
    if state == "walk":
        travel = WALK_SPEED
        if walk_reference_speed > 0:  # CharacterVisual.walk_play_speed
            play = min(max(WALK_SPEED / walk_reference_speed, 0.5), 2.0)
    elif state == "move":
        travel = move_speed
        play = min(max(move_speed / reference_speed, 0.6), 1.4)  # CharacterVisual.run_play_speed
    if args.travel is not None:
        travel = args.travel

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(GAME, "assets", "custom", args.kid + ".glb"))
    rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    if args.rekey:
        from characters import hero_clips
        hero_clips.add_clips(rig, args.kid)
    action = bpy.data.actions.get(clip)
    if action is None:
        sys.exit("clip_sheet: %s has no clip '%s' (states: %s)" % (args.kid, clip, ", ".join(sorted(clips))))
    rig.animation_data_create()
    rig.animation_data.action = action
    body = clay("clip_clay", (0.42, 0.4, 0.38))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(body)

    scene = bpy.context.scene
    fps = scene.render.fps
    first, last = (int(round(f)) for f in action.frame_range)
    # The kid's root: turned to face `azimuth` from the camera, moving
    # along its facing. Godot's +Z (forward) is Blender's -Y.
    root = bpy.data.objects.new("kid_root", None)
    common.link(root)
    for obj in scene.objects:
        if obj.parent is None and obj is not root:
            obj.parent = root
    if state in MALLET_STATES:
        hold_mallet(rig, hidden, body)
    root.rotation_euler = (0, 0, math.radians(args.azimuth))
    forward = root.rotation_euler.to_matrix() @ Vector((0, -1, 0))
    checked_ground(model_scale)

    # Camera: the game's pitch and lens, north-up, following the kid.
    height = max(o.dimensions.z for o in meshes)
    cam_data = bpy.data.cameras.new("clip_cam")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle_y = math.radians(LENS_FOV)
    cam = common.link(bpy.data.objects.new("clip_cam", cam_data))
    pitch = math.radians(PITCH)
    distance = height * 0.85 / math.tan(cam_data.angle_y * 0.5)
    offset = Vector((0, -math.cos(pitch), math.sin(pitch))) * distance
    cam.rotation_euler = (math.pi * 0.5 - pitch, 0, 0)
    scene.camera = cam
    world = bpy.data.worlds.new("clip_world")
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.16, 0.17, 0.2, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.35
    scene.world = world
    for energy, rotation, colour in ((3.2, (35, -20, -35), (1.0, 0.96, 0.9)), (2.2, (-60, 0, 160), (0.75, 0.85, 1.0))):
        sun = common.link(bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")))
        sun.data.energy = energy
        sun.data.color = colour
        sun.rotation_euler = tuple(math.radians(r) for r in rotation)

    scene.render.engine = "CYCLES"
    scene.cycles.samples = args.samples
    scene.render.resolution_x = args.size
    scene.render.resolution_y = args.size
    scene.view_settings.view_transform = "Standard"
    os.makedirs(args.out, exist_ok=True)
    name = "%s_%s" % (args.kid, clip)
    frame_dir = os.path.join(args.out, name + "_frames")
    os.makedirs(frame_dir, exist_ok=True)
    images = []
    for frame in range(first, last + 1):
        seconds = (frame - first) / fps / play  # game time since the clip began
        root.location = forward * (travel * seconds / model_scale)
        cam.location = root.location + Vector((0, 0, height * 0.5)) + offset
        scene.frame_set(frame)
        if args.rekey:
            slot = rig.pose.bones["handslot.r"].matrix
            tip = slot.to_3x3().col[0]
            print("clip_sheet: frame %d  hand z %.2f y %.2f  stick tip dir (%.2f, %.2f, %.2f)"
                  % (frame, slot.translation.z, slot.translation.y, tip.x, tip.y, tip.z))
        scene.render.filepath = os.path.join(frame_dir, "%03d.png" % (frame - first))
        bpy.ops.render.render(write_still=True)
        images.append(Image.open(scene.render.filepath).convert("RGB"))

    count = min(args.frames, len(images))
    strip = Image.new("RGB", (args.size * count, args.size))
    for i in range(count):
        at = round(i * (len(images) - 1) / max(count - 1, 1))
        strip.paste(images[at], (i * args.size, 0))
    strip.save(os.path.join(args.out, name + ".png"))
    images[0].save(os.path.join(args.out, name + ".gif"), save_all=True, append_images=images[1:],
                   duration=round(1000.0 / fps / play), loop=0)
    print("clip_sheet: %s (%d frames, %.2f s at %.2fx, travel %.1f m/s) -> %s"
          % (name, len(images), (last - first) / fps / play, play, travel, args.out))


if __name__ == "__main__":
    main()
