"""Little golem: what is left of the Moon-Eater once it lets the moon go.

Features 047 and 048, after the team's sheet
art/reference/concept-2026-10/18_little_golem_sheet.webp: a knee-high,
chibi golem in the Moon-Eater's materials. A big head (0.42 of its
height): a rounded face of upright planks with deep-set, tall amber eyes,
a dot of a nose and a smile, under a shaggy bob of plank shingles, with a
round plank-slice "ear" on each side, two stick pegs and a sapling on
top. A shield-shaped trunk of planks, wide at the chest, with a big
golden window and a crescent in it; chunky arms of stones and planks that
hang to the hips; stubby legs of stacked round stones.

Like the Moon-Eater it is rigid: the GLB holds one node per moving part,
each with its origin at its pivot, and Godot's LittleGolem
(game/scripts/story/little_golem.gd) tweens them:
  Body (hips, legs and trunk; origin on the ground)  + Body_Window, Body_Moon
  Head (pivot at the chin, inside the trunk's top)   + Head_Eyes
  ArmL, ArmR (pivots at the shoulders)
Positions are in Godot axes (x right, y up, z front) through g().
About 0.75 m to the top of the cap.

Run: .venv-blender/bin/python art/characters/little_golem.py
QUICK=1 renders clay views without baking (shape review).
MEASURE=1 prints the model's landmarks against the sheet's and renders
front and side silhouettes (docs/design/character-modelling.md)."""

import math
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from characters import moon_eater as me  # noqa: E402
from characters.moon_eater import g  # noqa: E402
from lib import common, detail, paint_bake, preview  # noqa: E402

NECK = Vector((0.0, 0.42, 0.0))
SHOULDER = Vector((0.1, 0.385, 0.0))
FACE_Z = 0.1          # the face planks' mid-plane
FACE_TOP, CHIN = 0.645, 0.432
CAP_C = Vector((0.0, 0.6, 0.028))
CAP_R = Vector((0.11, 0.14, 0.094))
EYE_Y = 0.535
EYES = ((-0.038, EYE_Y, 0.029, 0.043, 0.0), (0.038, EYE_Y, 0.029, 0.043, 0.0))  # (x, y, rx, ry, tilt)
WINDOW = Vector((0.0, 0.29, 0.1))
WINDOW_R = 0.062
# Warmer than the Moon-Eater's weathered grey, like the sheet.
WARM = (0.64, 0.44, 0.27)
FACE_TONE = (WARM, (0.82, 0.62, 0.4), (0.36, 0.22, 0.12))
SHINGLE_TONES = (FACE_TONE, (me.WOOD, me.WOOD_LIGHT, me.WOOD_DARK), ((0.5, 0.34, 0.21), WARM, me.WOOD_DARK))
# Read off the sheet's front and side views (fractions of the height from
# the feet to the top of the cap; see .features/048-little-golem-pass).
SHEET = {"sticks_top": 1.14, "chin": 0.576, "shoulders": 0.555, "window": 0.39, "hips": 0.18, "hands": 0.15,
         "w_head": 0.47, "w_cap": 0.38, "w_face": 0.295, "w_trunk": 0.26, "w_arms": 0.51, "w_leg": 0.14,
         "d_head": 0.26, "d_trunk": 0.26}

BUDGETS = {"Body": 3000, "Head": 3200, "ArmL": 800, "ArmR": 800}
SIZES = {"Body": 512, "Head": 512, "ArmL": 256, "ArmR": 256}
QUICK = bool(os.environ.get("QUICK"))
MEASURE = bool(os.environ.get("MEASURE"))
## The parts behind each measured landmark (MEASURE=1).
GROUPS = {}


def mark(group, obj):
    GROUPS.setdefault(group, []).append(obj)
    return obj


def leaf(base, direction, length, width, seed):
    """A pointed leaf with a folded midrib, as a thin solid."""
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d)
    bm = bmesh.new()
    rows = []
    for i in range(9):
        t = i / 8
        w = width * math.sin(math.pi * t ** 0.8) * 0.5
        mid = base + d * (length * t) + up * (0.25 * width * math.sin(math.pi * t))
        rows.append([bm.verts.new(g(mid + side * (w * s) - up * (abs(s) * w * 0.35) + up * h))
                     for h in (0.0015, -0.0015) for s in (-1, 0, 1)])
    for i in range(8):
        a, b = rows[i], rows[i + 1]
        for k in (0, 1):
            bm.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
            bm.faces.new((a[3 + k + 1], a[3 + k], b[3 + k], b[3 + k + 1]))
    obj = common.mesh_object("leaf", bm)
    common.shade_smooth(obj)
    detail.colour_foliage(obj, me.MOSS_DARK, me.LEAF, me.LEAF_LIGHT, seed=seed)
    return obj


def stick(base, direction, length, radius, seed):
    """A barked stick peg along `direction` from `base`."""
    s = detail.bark_log(length, radius, seed=seed, segments=12, taper=0.8)
    d = Vector(direction).normalized()
    return me.orient(s, base + d * (length * 0.5), d, d.orthogonal())


# --- Body ------------------------------------------------------------------------


def build_body():
    parts, window, moon = [], [], []
    # Stubby legs: a round stone over a wider foot stone each, splayed a
    # little; a flat stone across the hips under the trunk.
    for side in (-1, 1):
        parts.append(mark("legs", me.boulder(Vector((side * 0.064, 0.045, 0.012)), (0.11, 0.095, 0.125), moss=0.15)))
        parts.append(me.boulder(Vector((side * 0.058, 0.11, -0.002)), (0.1, 0.09, 0.1), moss=0.1))
    parts.append(me.boulder(Vector((0, 0.15, -0.004)), (0.17, 0.08, 0.14), moss=0.1))
    # The trunk: a dark core, wide at the chest and narrow at the hips,
    # with planks standing round it, leaning in towards the hips.
    parts.append(me.blob("trunk", [((0, 0.33, 0), (0.09, 0.075, 0.085)), ((0, 0.22, 0.0), (0.075, 0.08, 0.075)),
                                   ((0, 0.43, 0.0), (0.06, 0.035, 0.055))],
                         lambda p, n: me.CORE, resolution=0.012, bumps=0.004))
    n = 12
    for k in range(n):
        a = math.tau * (k + 0.5) / n + me.rng.uniform(-0.04, 0.04)
        out = Vector((math.sin(a) * 1.0, 0, math.cos(a)))
        if abs(math.sin(a)) < 0.3 and out.z > 0:
            continue        # the front is the window panel
        top, bottom = 0.412 + me.rng.uniform(-0.008, 0.006), 0.14 + me.rng.uniform(-0.008, 0.008)
        r_top, r_bottom = 0.092, 0.056
        p_top = Vector((out.x * r_top, top, out.z * r_top))
        p_bottom = Vector((out.x * r_bottom, bottom, out.z * r_bottom))
        along = p_top - p_bottom
        normal = out + Vector((0, (r_top - r_bottom) / along.length, 0))
        parts.append(mark("trunk", me.plank((p_top + p_bottom) * 0.5, along, normal, along.length, 0.062, thick=0.02,
                                            step=0.008, carve=0.003)))
    # The front panel: two short planks above and below the window, and
    # the window's wooden rim of short plank pieces.
    c, right, up, normal = WINDOW, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0.08, 1)).normalized()
    for y, length in ((0.39, 0.1), (0.185, 0.07)):
        parts.append(me.plank(Vector((0, y, 0.083 + (y - 0.2) * 0.12)), (1, 0, 0), (0, 0.1, 1), length, 0.045,
                              thick=0.022, step=0.008, carve=0.002))
    pieces = 10
    for k in range(pieces):
        a = math.tau * k / pieces + 0.15
        d = right * math.cos(a) + up * math.sin(a)
        tangent = right * -math.sin(a) + up * math.cos(a)
        parts.append(me.plank(c + d * (WINDOW_R + 0.011) - normal * 0.004, tangent, normal,
                              WINDOW_R * math.tau / pieces * 1.15, 0.024, thick=0.02, step=0.006, carve=0.0015,
                              tone=(me.WOOD_DARK, me.WOOD, me.CORE)))
    window.append(me.flat_disc(c - normal * 0.006, right, up, normal, WINDOW_R + 0.004))
    moon.append(me.crescent(c + normal * 0.002, right, up, normal, WINDOW_R * 0.72, WINDOW_R * 0.42))
    # A rope lashing round the shoulders and a few moss patches.
    parts.append(me.rope_ring(Vector((0, 0.392, 0)), (0, 1, 0.05), 0.093, thick=0.0065, wobble=0.004))
    parts.append(me.blob("moss", [((-0.06, 0.4, 0.06), (0.035, 0.012, 0.03)), ((0.07, 0.25, 0.05), (0.02, 0.025, 0.012)),
                                  ((0.05, 0.41, -0.05), (0.03, 0.012, 0.03))],
                         me.moss_colour(3), resolution=0.006, bumps=0.004, seed=3))
    return parts, window, moon


# --- Head ------------------------------------------------------------------------


def paint_smile(face):
    """A dot of a nose and a small smile, painted dark into the face's
    vertex colours and pressed in a hair."""
    mesh = face.data
    attr = mesh.color_attributes.get("Col")
    dark = common.srgb((0.16, 0.09, 0.05))
    near = {}
    for v in mesh.vertices:
        x, y, z = v.co.x, v.co.z, -v.co.y
        if z < FACE_Z:
            continue
        nose = math.hypot(x, (y - 0.493) * 1.2) / 0.0055
        r = math.hypot(x, y - 0.5)
        arc = abs(r - 0.024) / 0.0028 if y < 0.492 and abs(x) < 0.02 else 9.0
        t = max(0.0, 1.0 - min(nose, arc))
        if t > 0:
            near[v.index] = t
            v.co.y += 0.0015 * t
    for loop in mesh.loops:
        t = near.get(loop.vertex_index)
        if t:
            c = attr.data[loop.index].color
            attr.data[loop.index].color = (*(c[k] + (dark[k] - c[k]) * min(1.0, t * 1.6) for k in range(3)), 1.0)


def build_face():
    """Four upright planks on a gentle arc, outer ones shorter so the jaw
    is round, eye sockets carved in and the smile painted on."""
    planks = []
    for x, bottom in ((-0.081, CHIN + 0.03), (-0.027, CHIN), (0.027, CHIN + 0.002), (0.081, CHIN + 0.026)):
        a = x / 0.3
        normal = Vector((math.sin(a), 0, math.cos(a)))
        at = Vector((math.sin(a) * 0.3, (FACE_TOP + bottom) * 0.5, FACE_Z - 0.3 + math.cos(a) * 0.3))
        planks.append(me.plank(at, (me.rng.uniform(-0.02, 0.02), 1, 0), normal, FACE_TOP - bottom, 0.056, thick=0.03,
                               step=0.0035, carve=0.0025, tone=FACE_TONE))
    face = mark("face", common.join(planks, "face"))
    me.apply_all(face)
    me.carve_eyes(face, eyes=EYES, front_z=FACE_Z, depth=0.016, sink=0.004, ridge_depth=0.0)
    paint_smile(face)
    return face


def build_head():
    parts, eyes = [], []
    # A wooden back of the head behind the face.
    back = me.ball(Vector((0, 0.55, 0.01)), (0.1, 0.11, 0.09), me.WOOD_DARK)
    parts.append(mark("head", back))
    parts.append(build_face())
    # The shaggy bob: rings of plank shingles hanging from the crown, long
    # over the sides and the back, a short fringe over the brow.
    parts.append(me.ball(CAP_C + Vector((0, 0.01, 0)), CAP_R * 0.93, me.WOOD_DARK))
    rings = ((0.25, 12, 0.11, 0.055), (0.7, 9, 0.08, 0.055), (1.15, 5, 0.055, 0.05))
    for ring, (elev, count, length, width) in enumerate(rings):
        for k in range(count):
            az = math.tau * k / count + ring * 0.3 + me.rng.uniform(-0.06, 0.06)
            e = elev + me.rng.uniform(-0.05, 0.05)
            ce, se, ca, sa = math.cos(e), math.sin(e), math.cos(az), math.sin(az)
            top = CAP_C + Vector((CAP_R.x * sa * ce, CAP_R.y * se, CAP_R.z * ca * ce))
            normal = Vector((sa * ce / CAP_R.x, se / CAP_R.y, ca * ce / CAP_R.z)).normalized()
            down = Vector((sa * se * CAP_R.x, -ce * CAP_R.y, ca * se * CAP_R.z)).normalized()
            down = (down + normal * 0.08).normalized()      # a little shaggy
            front = max(0.0, ca) ** 1.5 if ring == 0 else 0.0
            ln = length * (1.0 - 0.8 * front) * me.rng.uniform(0.9, 1.1)
            parts.append(mark("cap", me.plank(top + down * (ln * 0.5 - 0.012) + normal * 0.006, down, normal, ln,
                                              width, thick=0.016, step=0.007, carve=0.002,
                                              tone=me.rng.choice(SHINGLE_TONES))))
    crown = CAP_C + Vector((0, CAP_R.y, 0))
    for k, (dx, dz, ang) in enumerate(((-0.02, 0.01, 0.4), (0.025, -0.01, -0.5))):
        parts.append(me.plank(crown + Vector((dx, 0.004, dz)), (math.cos(ang), 0.1, math.sin(ang)), (0, 1, 0), 0.075,
                              0.05, thick=0.016, step=0.007))
    parts.append(me.blob("moss", [((-0.04, 0.745, 0.03), (0.035, 0.01, 0.03)), ((0.05, 0.73, -0.03), (0.03, 0.01, 0.03)),
                                  ((-0.1, 0.69, 0.04), (0.02, 0.008, 0.02))],
                         me.moss_colour(5), resolution=0.006, bumps=0.004, seed=5))
    # The ears: a thick plank slice on each side, facing out and a little
    # forward, with its rings showing.
    for side in (-1, 1):
        normal = Vector((side, 0.0, 0.32)).normalized()
        ear = detail.bark_log(0.032, 0.078, seed=11 + side, segments=32, taper=1.0)
        me.orient(ear, Vector((side * 0.132, 0.51, 0.01)), normal, Vector((0, 0, 1)) - normal * normal.z)
        parts.append(mark("ears", ear))
    # Stick pegs and the sapling on top.
    parts.append(stick(crown + Vector((0.03, -0.01, -0.01)), (0.18, 1, -0.05), 0.11, 0.011, 31))
    parts.append(stick(crown + Vector((-0.07, -0.025, -0.01)), (-0.45, 1, 0), 0.065, 0.009, 32))
    parts.append(stick(crown + Vector((0.085, -0.03, 0.0)), (0.55, 1, 0.1), 0.05, 0.008, 33))
    stem = crown + Vector((-0.045, -0.005, 0.02))
    parts.append(stick(stem, (-0.15, 1, 0.05), 0.075, 0.0035, 34))
    tip = stem + Vector((-0.15, 1, 0.05)).normalized() * 0.075
    for k, (d, ln) in enumerate((((-1, 0.6, 0.2), 0.05), ((1, 0.7, 0.15), 0.048), ((-0.2, 1, 0.1), 0.04))):
        at = tip - Vector((-0.15, 1, 0.05)).normalized() * (0.022 * (k < 2))
        parts.append(leaf(at, d, ln, ln * 0.5, 40 + k))
    # The eyes: tall amber glows in the carved sockets, a dark pupil and a
    # small highlight in front.
    front = Vector((0, 0, 1))
    for x, y, rx, ry, _ in EYES:
        z = FACE_Z + 0.015 - 0.3 * (1 - math.cos(x / 0.3)) - 0.008
        eye = me.flat_disc(Vector((0, 0, 0)), Vector((1, 0, 0)), Vector((0, 1, 0)), front, 1.0, segments=28)
        eye.data.transform(Matrix.Diagonal((rx * 0.92, 1.0, ry * 0.92, 1.0)))
        eye.location = g(Vector((x, y, z)))
        eyes.append(eye)
        pupil = me.ball(Vector((x * 1.12, y - 0.006, z + 0.002)), (rx * 0.4, ry * 0.4, 0.002), (0.12, 0.06, 0.03))
        parts.append(pupil)
        parts.append(me.ball(Vector((x * 1.12 - 0.006, y + 0.006, z + 0.004)), (0.0045, 0.0055, 0.0015), me.CREAM))
    return parts, eyes


# --- Arms ------------------------------------------------------------------------


def build_arm(side):
    """Pivot-local: a stone shoulder, a plank upper arm with a rope wrap,
    a stone forearm with a plank over it and a round stone hand."""
    parts = []
    parts.append(me.boulder(Vector((side * 0.03, -0.015, 0.0)), (0.095, 0.085, 0.1), moss=0.35))
    parts.append(me.plank(Vector((side * 0.035, -0.085, 0.008)), (side * 0.12, 1, 0), (side, 0, 0.35), 0.11, 0.07,
                          thick=0.04, step=0.008, carve=0.003))
    parts.append(me.rope_ring(Vector((side * 0.035, -0.075, 0.008)), (side * 0.1, 1, 0), 0.04, thick=0.0055,
                              wobble=0.003))
    parts.append(me.boulder(Vector((side * 0.04, -0.158, 0.012)), (0.09, 0.1, 0.095), moss=0.1))
    parts.append(me.plank(Vector((side * 0.06, -0.16, 0.016)), (0, 1, 0), (side, 0, 0.2), 0.09, 0.045, thick=0.018,
                          step=0.007, carve=0.002))
    parts.append(me.boulder(Vector((side * 0.038, -0.232, 0.02)), (0.088, 0.08, 0.09), moss=0.05))
    return parts


# --- Assembly --------------------------------------------------------------------


def finish(parts, name, location):
    """Joins a part's pieces, moves its origin to `location` (Godot) and
    paints it."""
    obj = common.join(parts, name)
    me.apply_all(obj)
    obj.data.validate()
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
    paint_bake.paint_direct(obj, high, name="little_golem_" + name.lower(), size=SIZES[name], ao_distance=0.05,
                            ao_strength=0.7, edge_strength=0.4, edge_radius=0.004, noise_scale=24.0, cavity=0.6,
                            max_ray_distance=0.015, cage_extrusion=0.008)
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


def measure_against_sheet(objs):
    """Landmarks of the unjoined parts (GROUPS) as fractions of the cap's
    height, next to the sheet's, and front and side silhouettes."""
    from lib import measure
    bpy.context.view_layer.update()

    def pts(objs):
        out = []
        for o in objs:
            out += [o.matrix_world @ v.co for v in o.data.vertices]
        return out
    groups = GROUPS
    cap = pts(groups["cap"])
    top = max(p.z for p in cap)
    every = pts(objs)
    head = pts(groups["head"] + groups["cap"] + groups["ears"] + groups["face"])
    trunk = pts(groups["trunk"])
    arms = pts(groups["arms"])
    legs = [p for p in pts(groups["legs"]) if p.x > 0]

    def span(ps, axis):
        return (max(p[axis] for p in ps) - min(p[axis] for p in ps)) / top
    model = {
        "sticks_top": max(p.z for p in every) / top,
        "chin": min(p.z for p in pts(groups["face"])) / top,
        "shoulders": max(p.z for p in trunk) / top,
        "window": WINDOW.y / top,
        "hips": min(p.z for p in trunk) / top,
        "hands": min(p.z for p in arms) / top,
        "w_head": span(head, 0), "w_cap": span(cap, 0), "w_face": span(pts(groups["face"]), 0),
        "w_trunk": measure.width_at(trunk, WINDOW.y, band=0.01) / top,
        "w_arms": span(arms + trunk, 0), "w_leg": span(legs, 0),
        "d_head": span(head, 1), "d_trunk": span(trunk, 1),
    }
    print("measure: height to cap top %.3f m" % top)
    print("measure: %-12s %7s %7s %7s" % ("landmark", "model", "sheet", "diff"))
    for key, want in SHEET.items():
        print("measure: %-12s %7.3f %7.3f %+7.3f" % (key, model[key], want, model[key] - want))
    measure.silhouette(objs, os.path.join(common.PREVIEW_DIR, "little_golem_sil_front.png"), "front")
    measure.silhouette(objs, os.path.join(common.PREVIEW_DIR, "little_golem_sil_side.png"), "side")


def main():
    common.reset(47)
    me.rng.seed(47)
    body_parts, window, moon = build_body()
    head_parts, eye_parts = build_head()
    arm_parts = {}
    for side, name in ((-1.0, "ArmL"), (1.0, "ArmR")):
        pivot = Vector((SHOULDER.x * side, SHOULDER.y, SHOULDER.z))
        parts = [mark("arms", o) for o in build_arm(side)]
        bpy.context.view_layer.update()
        for o in parts:
            o.matrix_world = Matrix.Translation(g(pivot)) @ o.matrix_world
        arm_parts[name] = (pivot, parts)
    if MEASURE:
        measure_against_sheet(body_parts + head_parts + sum((p for _, p in arm_parts.values()), []))
        return
    body = finish(body_parts, "Body", Vector((0, 0, 0)))
    glows = [glow(window, "Body_Window", me.WINDOW_GLOW, 1.4, body), glow(moon, "Body_Moon", me.MOON, 3.0, body)]
    head = finish(head_parts, "Head", NECK)
    glows.append(glow(eye_parts, "Head_Eyes", me.EYE, 3.0, head))
    arms = [finish(parts, name, pivot) for name, (pivot, parts) in arm_parts.items()]
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
