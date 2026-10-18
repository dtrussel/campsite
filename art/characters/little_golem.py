"""Little golem: what is left of the Moon-Eater once it lets the moon go.

Feature 047, after the team's sheet
art/reference/concept-2026-10/18_little_golem_sheet.webp: a knee-high,
chibi golem in the Moon-Eater's materials. A big round head of weathered
planks under a shaggy cap of plank shingles, with two big amber eyes,
a sapling sprout and a couple of stick pegs on top; a barrel body of
planks over round stones, lashed with rope, with a small golden window
and a crescent in its chest; stubby stone legs and short arms of a plank
and a round stone fist.

Like the Moon-Eater it is rigid: the GLB holds one node per moving part,
each with its origin at its pivot, and Godot's LittleGolem
(game/scripts/story/little_golem.gd) tweens them:
  Body (hips, legs and trunk; origin on the ground)  + Body_Window
  Head (pivot at the neck)                           + Head_Eyes
  ArmL, ArmR (pivots at the shoulders)
Positions are in Godot axes (x right, y up, z front) through g().
About 0.75 m tall.

Run: .venv-blender/bin/python art/characters/little_golem.py
QUICK=1 renders clay views without baking (shape review)."""

import math
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from characters import moon_eater as me  # noqa: E402
from characters.moon_eater import g  # noqa: E402
from props.camp import wood_colour  # noqa: E402
from lib import common, detail, paint_bake, preview  # noqa: E402

NECK = Vector((0.0, 0.47, 0.0))
SHOULDER = Vector((0.18, 0.42, 0.0))
BODY_Y, BODY_R, BODY_H = 0.3, 0.16, 0.3
HEAD_C = Vector((0.0, 0.64, 0.02))
HEAD_R = Vector((0.2, 0.18, 0.17))
WINDOW = Vector((0.0, 0.31, BODY_R + 0.035))
EYES = ((-0.075, 0.035), (0.075, 0.04))  # (x, radius)

BUDGETS = {"Body": 2600, "Head": 2400, "ArmL": 500, "ArmR": 500}
SIZES = {"Body": 512, "Head": 512, "ArmL": 256, "ArmR": 256}
QUICK = bool(os.environ.get("QUICK"))


def build_body():
    parts, window = [], []
    # Stubby legs: a stack of two round stones each.
    for side in (-1, 1):
        parts.append(me.boulder(Vector((side * 0.085, 0.06, 0.01)), (0.13, 0.11, 0.14), moss=0.2))
        parts.append(me.boulder(Vector((side * 0.08, 0.14, 0.0)), (0.11, 0.09, 0.11), moss=0.1))
    # The barrel: planks standing round a dark core, a little crooked.
    core = me.ball(Vector((0, BODY_Y, 0)), (BODY_R * 0.92, BODY_H * 0.5, BODY_R * 0.88), me.CORE)
    parts.append(core)
    n = 11
    for k in range(n):
        a = math.tau * k / n + me.rng.uniform(-0.05, 0.05)
        out = Vector((math.sin(a), 0, math.cos(a)))
        at = Vector((0, BODY_Y + me.rng.uniform(-0.01, 0.015), 0)) + out * BODY_R
        if abs(a - math.tau) < 0.5 or a < 0.5:   # leave the front open for the window
            at.y -= 0.0
        parts.append(me.plank(at, (me.rng.uniform(-0.06, 0.06), 1, 0), out, BODY_H + me.rng.uniform(-0.02, 0.03),
                              0.105, thick=0.03, step=0.02, carve=0.004))
    # Round stones bulging at the belly sides and on the shoulders.
    for side in (-1, 1):
        parts.append(me.boulder(Vector((side * 0.15, BODY_Y - 0.08, 0.03)), (0.1, 0.09, 0.1), moss=0.15))
        parts.append(me.boulder(Vector((side * 0.13, BODY_Y + 0.14, -0.02)), (0.1, 0.07, 0.1), moss=0.5))
    for y in (BODY_Y - 0.1, BODY_Y + 0.1):
        parts.append(me.rope_ring(Vector((0, y, 0)), (0, 1, 0), BODY_R + 0.02, thick=0.009, wobble=0.008))
    # The chest window: a wooden ring with the warm glow and a crescent in it.
    c, right, up, normal = WINDOW, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    frame = me.rope_ring(c, normal, 0.062, thick=0.014, wobble=0.003)
    parts.append(frame)
    window.append(me.flat_disc(c - normal * 0.004, right, up, normal, 0.058))
    window.append(me.crescent(c + normal * 0.002, right, up, normal, 0.042, 0.02))
    return parts, window


def sprout(base, seed):
    """A little sapling: a twig and two leaves."""
    parts = []
    twig = detail.bark_log(0.07, 0.008, seed=seed, segments=10, taper=0.6)
    me.orient(twig, base + Vector((0, 0.035, 0)), (0.2, 1, 0), (0, 0, 1))
    parts.append(twig)
    for k, (dx, dy, r) in enumerate(((-0.025, 0.07, 0.03), (0.03, 0.06, 0.026))):
        clump = detail.leaf_clump(g(base + Vector((dx, dy, 0))), r, seed + k, tufts=5, subdivisions=2)
        detail.colour_foliage(clump, me.MOSS_DARK, me.LEAF, me.LEAF_LIGHT, seed=seed + k)
        parts.append(clump)
    return parts


def build_head():
    parts, eyes = [], []
    # A round wooden face: a ball with vertical grain.
    face = me.ball(HEAD_C, HEAD_R, me.WOOD)
    common.color_by(face, wood_colour(4, base=me.WOOD_LIGHT, light=me.CREAM, dark=me.WOOD, along=2, knots=True))
    parts.append(face)
    # The shaggy cap: plank shingles in rings over the crown and the back,
    # the lowest ring hanging over the brow.
    for ring, (rise, count, length) in enumerate(((0.06, 13, 0.12), (0.12, 10, 0.1), (0.165, 6, 0.08))):
        for k in range(count):
            a = math.tau * k / count + ring * 0.25
            out = Vector((math.sin(a), 0, math.cos(a)))
            # Shorter at the front, so the face and eyes show.
            front = max(0.0, out.z)
            at = HEAD_C + Vector((out.x * HEAD_R.x * (1.0 - ring * 0.28), rise - front * 0.025,
                                  out.z * HEAD_R.z * (1.0 - ring * 0.28)))
            down = (out * (0.55 + ring * 0.2) - Vector((0, 1, 0))).normalized()
            parts.append(me.plank(at - down * 0.03, down, out + Vector((0, 0.8, 0)), length * (1.0 - front * 0.35),
                                  0.065, thick=0.022, step=0.012, carve=0.003))
    top = HEAD_C + Vector((0, HEAD_R.y + 0.02, 0))
    parts.append(me.plank(top + Vector((0, 0.01, 0)), (1, 0, 0), (0, 1, 0), 0.12, 0.08, thick=0.025, step=0.012))
    # Stick pegs and the sprout on top.
    for side, h in ((-1, 0.07), (1, 0.05)):
        parts.append(me.wood_block(top + Vector((side * 0.045, h * 0.5 + 0.02, -0.02)), (0.026, 0.026, h), round_=0.008,
                                   warp=0.003))
    parts += sprout(top + Vector((0.01, 0.02, 0.02)), 7)
    # Big amber eyes with dark pupils.
    front = Vector((0, 0, 1))
    for x, r in EYES:
        z = HEAD_R.z * math.sqrt(max(0.0, 1 - (x / HEAD_R.x) ** 2 - 0.01))
        at = HEAD_C + Vector((x, -0.01, z + 0.004))
        eyes.append(me.flat_disc(at, Vector((1, 0, 0)), Vector((0, 1, 0)), front, r))
        parts.append(me.rope_ring(at, front, r + 0.005, thick=0.006, wobble=0.0))
        pupil = me.flat_disc(at + Vector((0.0, -0.004, 0.003)), Vector((1, 0, 0)), Vector((0, 1, 0)), front, r * 0.45)
        common.set_color(pupil, (0.12, 0.07, 0.04))
        parts.append(pupil)
    return parts, eyes


def build_arm(side):
    parts = []
    upper = me.plank(Vector((side * 0.035, -0.06, 0.0)), (0, 1, 0), (side, 0, 0.3), 0.13, 0.09, thick=0.065, step=0.02)
    parts.append(upper)
    parts.append(me.rope_ring(Vector((side * 0.035, -0.04, 0.0)), (0, 1, 0), 0.055, thick=0.008, wobble=0.004))
    parts.append(me.boulder(Vector((side * 0.04, -0.16, 0.01)), (0.11, 0.1, 0.11), moss=0.1))
    return parts


def finish(parts, name, location):
    """Joins a part's pieces, moves its origin to `location` (Godot) and
    paints it."""
    obj = common.join(parts, name)
    me.apply_all(obj)
    obj.data.transform(Matrix.Translation(-g(location)))
    obj.location = g(location)
    if QUICK:
        return obj
    high = obj.copy()
    high.data = obj.data.copy()
    high.name = name + "_high"
    obj.users_collection[0].objects.link(high)
    high.hide_render = True
    dense = common.triangle_count([high])
    detail.decimate_tris(obj, BUDGETS[name])
    paint_bake.paint_direct(obj, high, name="little_golem_" + name.lower(), size=SIZES[name], ao_distance=0.08,
                            ao_strength=0.7, edge_strength=0.4, edge_radius=0.006, noise_scale=18.0, cavity=0.6,
                            max_ray_distance=0.02, cage_extrusion=0.01)
    print(name, "tris:", common.triangle_count([obj]), "(dense %d)" % dense)
    return obj


def glow(parts, name, colour, strength, parent):
    obj = common.join(parts, name)
    me.apply_all(obj)
    obj.data.transform(Matrix.Translation(-parent.location))
    paint_bake.flat_material(obj, colour, emission=strength, name="little_golem_" + name.lower() + "_painted")
    obj.parent = parent
    obj.location = (0, 0, 0)
    return obj


def main():
    common.reset(47)
    me.rng.seed(47)
    body_parts, window = build_body()
    body = finish(body_parts, "Body", Vector((0, 0, 0)))
    glows = [glow(window, "Body_Window", me.WINDOW_GLOW, 2.0, body)]
    head_parts, eye_parts = build_head()
    head = finish(head_parts, "Head", NECK)
    glows.append(glow(eye_parts, "Head_Eyes", me.EYE, 3.0, head))
    arms = []
    for side, name in ((-1.0, "ArmL"), (1.0, "ArmR")):
        pivot = Vector((SHOULDER.x * side, SHOULDER.y, SHOULDER.z))
        parts = build_arm(side)
        bpy.context.view_layer.update()
        for o in parts:
            o.matrix_world = Matrix.Translation(g(pivot)) @ o.matrix_world
        arms.append(finish(parts, name, pivot))
    objects = [body, head] + arms + glows
    print("total tris:", common.triangle_count(objects))
    if QUICK:
        preview.render_clay(objects, "little_golem", zoom=0.9)
        return
    common.export_glb(os.path.join(common.OUT_DIR, "little_golem.glb"), objects, image_format="WEBP")
    preview.render(objects, "little_golem", elevation=10, azimuth=25)
    preview.render(objects, "little_golem_game", elevation=50, azimuth=10)


if __name__ == "__main__":
    main()
