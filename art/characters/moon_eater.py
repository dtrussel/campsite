"""Moon-Eater: the Chapter 2 boss, a hulking golem of planks and stones.

Feature 038, after the team's character sheet
art/reference/concept-2026-10/15_moon_eater_character_sheet.webp:
- a hunched, top-heavy, ape-like heap: a barrel chest of weathered,
  crooked planks over a dark core, a hump of boulders and a moss mantle
  across the shoulders, short legs of piled boulders;
- long arms: a plank pauldron and a shoulder boulder, an upper arm of
  lashed logs, a fat forearm of planks wrapped in rope, and a huge fist
  of rounded wooden blocks with moss on the knuckles;
- a small crate-like head set low and forward: crooked upright planks,
  a heavy brow plank, two amber eyes (one bigger) in dark sockets, moss
  and a sprig on top;
- in its chest a round window of golden moonlight with a pale crescent,
  framed by plank segments and wedged stones, and its hoard floating in
  it (a little chair, a teddy, a pocket watch, stars, a key);
- a red plaid scarf round the neck with a hanging tail, lanterns, brass
  bells and a hanging pocket watch, saplings, fence pickets and branches
  growing out of its back.

It is rigid, like a golem should be: no skeleton. The GLB holds one node
per moving part, each with its origin at its pivot, and Godot's
MoonEaterVisual (game/scripts/mobs/moon_eater_visual.gd) swings them with
tweens:
  Body (hips, legs, trunk; leaned forward from the hips)
    Body_Window, Body_Moon, Body_Glow   emissive (Godot drives them)
    Hoard                               the lost things in the window
  Head (pivot at the neck)  + Head_Eyes
  ArmL, ArmR (pivots at the shoulders, hanging straight down) + ArmR_Glow
Positions are written in Godot axes (x right, y up, z front) through
g(); LEAN, HIP, WINDOW, WINDOW_TILT and the pivots match the script.

Run: .venv-blender/bin/python art/characters/moon_eater.py
QUICK=1 renders clay views without baking (shape review)."""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

from lib import common, detail, paint_bake, preview  # noqa: E402
from props.camp import _clamp, _vertex_colours, board, dense_box, revolve, rope_loop, rope_tube, stone  # noqa: E402

WOOD = (0.56, 0.42, 0.3)
WOOD_LIGHT = (0.74, 0.6, 0.44)
WOOD_DARK = (0.31, 0.22, 0.15)
WOOD_GREY = (0.5, 0.45, 0.4)
CORE = (0.16, 0.11, 0.09)
STONE = (0.42, 0.39, 0.36)
STONE_LIGHT = (0.56, 0.51, 0.45)
STONE_DARK = (0.24, 0.22, 0.21)
MOSS = (0.33, 0.44, 0.15)
MOSS_LIGHT = (0.47, 0.57, 0.2)
MOSS_DARK = (0.22, 0.32, 0.1)
LEAF = (0.27, 0.45, 0.15)
LEAF_LIGHT = (0.45, 0.6, 0.22)
ROPE = (0.78, 0.64, 0.42)
PLAID = (0.74, 0.16, 0.13)
PLAID_DARK = (0.42, 0.08, 0.08)
PLAID_LINE = (0.95, 0.78, 0.45)
BRASS = (0.86, 0.64, 0.3)
BRASS_DARK = (0.5, 0.34, 0.14)
IRON = (0.24, 0.22, 0.24)
TOY = (0.74, 0.48, 0.26)
TOY_LIGHT = (0.9, 0.72, 0.5)
CREAM = (0.95, 0.88, 0.7)
GLOW = (1.0, 0.66, 0.3)
EYE = (1.0, 0.8, 0.42)
WINDOW_GLOW = (1.0, 0.74, 0.34)
MOON = (1.0, 0.94, 0.8)

## Godot units: the stand-in is ~5 m tall here (the scene scales it by 0.72).
LEAN = 0.2
HIP = Vector((0.0, 1.45, 0.0))
WINDOW = Vector((0.0, 2.3, 1.55))
WINDOW_TILT = -0.55
WINDOW_RADIUS = 0.8
NECK = Vector((0.0, 4.0, 1.1))
FACE_TILT = -0.3
SHOULDER = Vector((1.7, 3.7, 0.15))
FIST = Vector((0.25, -2.9, 0.25))

BUDGETS = {"Body": 11000, "ArmL": 3600, "ArmR": 3600, "Head": 4500, "Hoard": 900}
SIZES = {"Body": 1024, "ArmL": 1024, "ArmR": 1024, "Head": 1024, "Hoard": 256}

QUICK = bool(os.environ.get("QUICK"))
## HEAD_ONLY=1 builds just the head and renders close-ups (no export).
HEAD_ONLY = bool(os.environ.get("HEAD_ONLY"))
rng = random.Random(38)


# --- Axes and placement --------------------------------------------------------

def g(x, y=None, z=None):
    """Godot (x right, y up, z front) to Blender (x right, -y front, z up)."""
    if y is None:
        x, y, z = x
    return Vector((x, -z, y))


def rot_x(angle):
    """Godot's rotation about +X, as a Blender matrix (the axes coincide)."""
    return Matrix.Rotation(angle, 4, "X")


def lean(p):
    """Where a point of the upper body ends up after the forward lean."""
    v = Vector(p) - HIP
    c, s = math.cos(LEAN), math.sin(LEAN)
    return HIP + Vector((v.x, v.y * c - v.z * s, v.y * s + v.z * c))


def window_frame():
    """The window's centre, right, up and normal, in (unleaned) Godot axes."""
    c, s = math.cos(WINDOW_TILT), math.sin(WINDOW_TILT)
    return WINDOW, Vector((1, 0, 0)), Vector((0, c, s)), Vector((0, -s, c))


def orient(obj, at, along, normal):
    """Places obj (long axis local X, thickness local Z) at Godot `at`,
    its X along `along` and its Z along `normal`."""
    x = g(along).normalized()
    z = g(normal)
    z = (z - x * z.dot(x)).normalized()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    obj.matrix_world = Matrix.Translation(g(at)) @ m
    return obj


def jitter(v, amount):
    return Vector(v) + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * amount


def apply_all(obj):
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


# --- Pieces ----------------------------------------------------------------------

def plank(at, along, normal, length, width, thick=0.1, tone=None, step=0.05, carve=0.012):
    seed = rng.randint(0, 999)
    base, light, dark = tone or rng.choice([(WOOD, WOOD_LIGHT, WOOD_DARK), (WOOD, WOOD_LIGHT, WOOD_DARK),
                                            (WOOD_GREY, WOOD_LIGHT, WOOD_DARK), (WOOD_DARK, WOOD, CORE)])
    b = board((length, width, thick), seed=seed, base=base, light=light, dark=dark, bevel=min(0.03, thick * 0.3),
              step=step, warp=0.012, carve=carve)
    return orient(b, at, along, normal)


def boulder(at, size, moss=0.25, rot=None):
    """A chiselled stone centred at Godot `at`; size is (width, height, depth)."""
    s = stone((size[0], size[2], size[1]), seed=rng.randint(0, 999), base=STONE, light=STONE_LIGHT, dark=STONE_DARK,
              moss=moss, subdiv=3)
    s.location = g(at) - Vector((0, 0, size[1] * 0.5))
    s.rotation_euler = rot or (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), rng.uniform(-math.pi, math.pi))
    return s


def wood_block(at, size, tone=WOOD, rot=None, round_=0.08, warp=0.02):
    """A rounded, weathered wooden block (the fist's fingers)."""
    seed = rng.randint(0, 999)
    b = dense_box(size, bevel=min(round_, min(size) * 0.45), step=0.04, warp=warp, seed=seed)
    off = Vector((seed, seed * 0.3, 0))

    def colour(pos, normal):
        n = noise.noise(Vector((pos.x * 3.0, pos.y * 12.0, pos.z * 3.0)) + off)
        c = common.lerp(tone, WOOD_LIGHT, _clamp(0.45 + n * 0.6))
        if n < -0.35:
            c = common.lerp(c, WOOD_DARK, 0.6)
        if normal.z > 0.55 and noise.noise(pos * 4.0 + off) > -0.1:
            c = common.lerp(c, MOSS, 0.7)
        return c
    common.color_by(b, colour)
    b.location = g(at)
    b.rotation_euler = rot or (0, 0, 0)
    return b


def blob(name, elements, colour, resolution=0.06, bumps=0.06, seed=0):
    """A metaball mass (Godot-axes ellipsoids: centre, radii), noisy."""
    els = [(g(c), max(r) * 1.0, 2.0, "ELLIPSOID", (r[0] / max(r), r[2] / max(r), r[1] / max(r))) for c, r in elements]
    obj = common.metaball_object(name, els, resolution=resolution)
    if bumps:
        common.displace_noise(obj, strength=bumps, scale=0.35, seed=seed)
    common.shade_smooth(obj)
    common.color_by(obj, colour)
    return obj


def ball(centre, radii, colour):
    """A plain ellipsoid at Godot `centre` with Godot radii."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[2], v.co.z * radii[1])) + g(centre)
    obj = common.mesh_object("ball", bm)
    common.shade_smooth(obj)
    common.set_color(obj, colour)
    return obj


def moss_colour(seed):
    off = Vector((seed * 2.3, seed, 0))

    def colour(pos, normal):
        n = noise.noise(pos * 2.5 + off) + noise.noise(pos * 9.0 + off) * 0.4
        c = common.lerp(MOSS_DARK, MOSS, _clamp(0.5 + n))
        if normal.z > 0.5 and n > 0.2:
            c = common.lerp(c, MOSS_LIGHT, _clamp((n - 0.2) * 2.0))
        return c
    return colour


def rope(points, thick=0.035):
    return rope_tube([g(p) for p in points], thick, base=ROPE)


def rope_ring(centre, axis, radius, thick=0.04, wobble=0.06):
    """A crooked lashing round `axis` (Godot) at `centre`."""
    axis = Vector(axis).normalized()
    u = axis.orthogonal().normalized()
    v = axis.cross(u)
    pts = []
    for i in range(40):
        a = math.tau * i / 40
        r = radius * (1.0 + noise.noise(Vector((a, centre.y, 3.0))) * 0.08)
        pts.append(Vector(centre) + (u * math.cos(a) + v * math.sin(a)) * r + axis * math.sin(a * 2 + 1.0) * wobble)
    return rope_tube([g(p) for p in pts], thick, closed=True, base=ROPE)


def flat_disc(centre, right, up, normal, radius, segments=40):
    bm = bmesh.new()
    mid = bm.verts.new(g(centre))
    ring = [bm.verts.new(g(centre + (right * math.cos(a) + up * math.sin(a)) * radius))
            for a in (math.tau * i / segments for i in range(segments))]
    for i in range(segments):
        bm.faces.new((mid, ring[i], ring[(i + 1) % segments]))
    obj = common.mesh_object("disc", bm)
    _face(obj, g(normal))
    return obj


def _face(obj, normal):
    """Flips the faces so they point along `normal` (Blender axes)."""
    if obj.data.polygons and obj.data.polygons[0].normal.dot(normal) < 0:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bm.to_mesh(obj.data)
        bm.free()


def crescent(centre, right, up, normal, radius, width, start=1.9, end=4.4, steps=28):
    """A tapering moon crescent: a ribbon along an arc, widest mid-way."""
    bm = bmesh.new()
    rows = []
    for i in range(steps + 1):
        t = i / steps
        a = start + (end - start) * t
        w = width * math.sin(math.pi * t) + 0.004
        d = right * math.cos(a) + up * math.sin(a)
        rows.append((bm.verts.new(g(centre + d * radius)), bm.verts.new(g(centre + d * (radius - w)))))
    for i in range(steps):
        a0, b0 = rows[i]
        a1, b1 = rows[i + 1]
        bm.faces.new((a0, a1, b1, b0))
    obj = common.mesh_object("crescent", bm)
    _face(obj, g(normal))
    return obj


def lantern(at, metal=BRASS):
    """A small hanging lantern: (painted parts, glass)."""
    parts = []
    top = revolve([(0.0, 0.15), (0.17, 0.15), (0.16, 0.18), (0.05, 0.28), (0.0, 0.3)], 12, name="cap")
    bottom = revolve([(0.0, -0.17), (0.15, -0.17), (0.15, -0.13), (0.0, -0.13)], 12, name="base")
    for p in (top, bottom):
        common.set_color(p, IRON)
        p.location = g(at)
        parts.append(p)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        post = dense_box((0.025, 0.025, 0.3), step=0.05, bevel=0.005)
        common.set_color(post, IRON)
        post.location = g(at) + Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.0))
        parts.append(post)
    ring = rope_loop(0.04, 0.012, location=g(at) + Vector((0, 0, 0.36)), rotation=(math.pi / 2, 0, 0), base=metal,
                     strands=0)
    parts.append(ring)
    glass = dense_box((0.2, 0.2, 0.28), step=0.1, bevel=0.02)
    glass.location = g(at)
    return parts, glass


def chain(a, b, link=0.06):
    """Little iron links from a to b (Godot)."""
    a, b = Vector(a), Vector(b)
    n = max(2, int((b - a).length / (link * 1.4)))
    links = []
    for i in range(n):
        p = a.lerp(b, (i + 0.5) / n)
        ring = rope_loop(link * 0.5, link * 0.14, base=IRON, strands=0)
        d = g(b - a).normalized()
        u = d.orthogonal().normalized()
        side = u if i % 2 == 0 else d.cross(u)
        # The link's ring lies along the chain; alternate links turn 90 degrees.
        ring.matrix_world = Matrix.Translation(g(p)) @ Vector((0, 0, 1)).rotation_difference(side).to_matrix().to_4x4()
        links.append(ring)
    return links


def bell(at):
    b = revolve([(0.0, -0.1), (0.13, -0.1), (0.14, -0.08), (0.1, -0.02), (0.07, 0.08), (0.04, 0.15), (0.0, 0.16)], 16,
                name="bell")
    common.color_by(b, lambda p, n: common.lerp(BRASS_DARK, BRASS, _clamp(0.4 + n.z * 0.4 + p.z * 2.0)))
    b.location = g(at)
    return b


def ribbon(points, width, thick, colour_fn, twist=0.0, up=(0, 0, 1)):
    """A cloth strip along Godot points: `colour_fn(u, v)` paints the plaid
    (u along in metres, v across 0..1)."""
    pts = [g(p) for p in points]
    up = Vector(up)
    bm = bmesh.new()
    colours = []
    rows = []
    along = 0.0
    for i, p in enumerate(pts):
        if i:
            along += (p - pts[i - 1]).length
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(up)
        if side.length < 1e-4:
            side = t.orthogonal()
        side.normalize()
        side = Matrix.Rotation(twist * i / max(1, len(pts) - 1), 3, t) @ side
        nrm = side.cross(t).normalized()
        w = width(i / max(1, len(pts) - 1)) if callable(width) else width
        row = []
        for k in range(5):
            v = k / 4
            q = p + side * (v - 0.5) * w
            row.append(bm.verts.new(q + nrm * thick * 0.5))
            colours.append(colour_fn(along, v))
        for k in range(5):
            v = k / 4
            q = p + side * (v - 0.5) * w
            row.append(bm.verts.new(q - nrm * thick * 0.5))
            colours.append(common.lerp(colour_fn(along, v), PLAID_DARK, 0.4))
        rows.append(row)
    for i in range(len(rows) - 1):
        a, b = rows[i], rows[i + 1]
        for k in range(4):
            bm.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
            bm.faces.new((a[5 + k], b[5 + k], b[6 + k], a[6 + k]))
        bm.faces.new((a[0], b[0], b[5], a[5]))
        bm.faces.new((a[4], a[9], b[9], b[4]))
    obj = common.mesh_object("cloth", bm)
    common.shade_smooth(obj)
    _vertex_colours(obj, colours)
    return obj


def plaid(u, v):
    c = PLAID
    if (u * 6.0) % 1.0 < 0.3 or (v * 3.0) % 1.0 < 0.3:
        c = common.lerp(c, PLAID_DARK, 0.6)
    if abs((u * 6.0) % 1.0 - 0.65) < 0.05 or abs((v * 3.0) % 1.0 - 0.7) < 0.06:
        c = common.lerp(c, PLAID_LINE, 0.7)
    return c


def star(centre, right, up, size):
    bm = bmesh.new()
    pts = []
    for i in range(10):
        a = math.pi / 2 + math.tau * i / 10
        r = size if i % 2 == 0 else size * 0.45
        pts.append(centre + (right * math.cos(a) + up * math.sin(a)) * r)
    top = [bm.verts.new(g(p)) for p in pts]
    bm.faces.new(top)
    obj = common.mesh_object("star", bm)
    mod = obj.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.03
    common.apply_all_modifiers(obj)
    common.set_color(obj, CREAM)
    return obj


def sapling(base, height, seed):
    parts = []
    trunk = detail.bark_log(height, 0.05, seed=seed, segments=24, taper=0.5)
    orient(trunk, base + Vector((0, height * 0.5, 0)), (rng.uniform(-0.15, 0.15), 1, rng.uniform(-0.15, 0.15)), (0, 0, 1))
    parts.append(trunk)
    for k, (dx, dy, dz, r) in enumerate([(0, 1.0, 0, 0.3), (0.2, 0.78, 0.1, 0.22), (-0.18, 0.72, -0.08, 0.2)]):
        clump = detail.leaf_clump(g(base + Vector((dx, height * dy, dz))), r, seed + k, tufts=12, subdivisions=3)
        detail.colour_foliage(clump, MOSS_DARK, LEAF, LEAF_LIGHT, seed=seed + k)
        parts.append(clump)
    return parts


# --- Parts -------------------------------------------------------------------------

CHEST_C = Vector((0.0, 2.6, 0.05))
CHEST_R = Vector((1.38, 1.28, 1.1))


def chest_point(az, el, out=0.0):
    """A point on the chest ellipsoid (az 0 = front), its normal, and its
    vertical and around tangents."""
    d = Vector((math.cos(el) * math.sin(az), math.sin(el), math.cos(el) * math.cos(az)))
    n = Vector((d.x / CHEST_R.x, d.y / CHEST_R.y, d.z / CHEST_R.z)).normalized()
    p = CHEST_C + Vector((d.x * CHEST_R.x, d.y * CHEST_R.y, d.z * CHEST_R.z)) + n * out
    up = Vector((-math.sin(el) * math.sin(az) * CHEST_R.x, math.cos(el) * CHEST_R.y,
                 -math.sin(el) * math.cos(az) * CHEST_R.z)).normalized()
    around = Vector((math.cos(az) * CHEST_R.x, 0.0, -math.sin(az) * CHEST_R.z)).normalized()
    return p, n, up, around


def in_window(p):
    c, right, up, normal = window_frame()
    d = p - c
    return abs(d.dot(normal)) < 0.8 and (d - normal * d.dot(normal)).length < WINDOW_RADIUS + 0.28


def build_body():
    """(painted upper-body parts, legs, window glow parts, glass parts, hoard parts)."""
    upper, legs, glass = [], [], []

    # The dark core everything is nailed onto: chest, shoulder hump, hips.
    upper.append(blob("core", [(CHEST_C, CHEST_R * 0.97), ((0, 3.72, -0.2), (1.85, 0.72, 1.05)),
                               ((0, 1.6, 0.0), (1.05, 0.55, 0.85)), ((0, 3.3, 0.55), (0.75, 0.5, 0.6))],
                      lambda p, n: common.lerp(CORE, WOOD_DARK, _clamp(0.4 + noise.noise(p * 3.0)))))

    # Crooked staves round the barrel chest, two per column so they follow
    # its curve, leaving the window clear.
    az = -math.pi
    while az < math.pi:
        width = rng.uniform(0.34, 0.5)
        for el, length in ((0.38, rng.uniform(1.0, 1.3)), (-0.32, rng.uniform(0.95, 1.25))):
            p, n, up, around = chest_point(az + rng.uniform(-0.04, 0.04), el + rng.uniform(-0.06, 0.06), 0.05)
            if in_window(p):
                continue
            tilt = rng.uniform(-0.22, 0.22)
            upper.append(plank(p, up * math.cos(tilt) + around * math.sin(tilt), n, length, width,
                               thick=rng.uniform(0.08, 0.12)))
        az += width / CHEST_R.x * 0.92
    # A belt of planks round the top of the chest, and one at the waist.
    for el, count, out in ((0.86, 9, 0.1), (-0.78, 8, 0.12)):
        for k in range(count):
            a = -math.pi + math.tau * (k + rng.uniform(0, 0.4)) / count
            p, n, up, around = chest_point(a, el, out)
            if in_window(p):
                continue
            upper.append(plank(p, around + up * rng.uniform(-0.25, 0.25), n, rng.uniform(0.8, 1.1), rng.uniform(0.28, 0.38),
                               thick=0.09))
    # A couple of braces nailed across.
    for a, el, ang in ((1.2, 0.1, 0.9), (-1.35, -0.1, -0.8), (2.6, 0.2, 0.6)):
        p, n, up, around = chest_point(a, el, 0.15)
        upper.append(plank(p, up * math.cos(ang) + around * math.sin(ang), n, 1.4, 0.24, thick=0.08,
                           tone=(WOOD_DARK, WOOD, CORE)))

    # The chest window: plank segments round a dark rim, stones wedged in.
    c, right, up, normal = window_frame()
    rim = rope_loop(WINDOW_RADIUS + 0.1, 0.13, base=common.lerp(CORE, WOOD_DARK, 0.4), strands=0)
    orient(rim, c, right, normal)
    upper.append(rim)
    a = rng.uniform(0, 1)
    while a < math.tau + 0.2:
        length = rng.uniform(0.5, 0.8)
        mid = a + length / (WINDOW_RADIUS + 0.14) * 0.5
        d = right * math.cos(mid) + up * math.sin(mid)
        t = right * -math.sin(mid) + up * math.cos(mid)
        spin = rng.uniform(-0.12, 0.12)
        upper.append(plank(c + d * (WINDOW_RADIUS + rng.uniform(0.1, 0.18)) + normal * rng.uniform(0.03, 0.12),
                           t * math.cos(spin) + d * math.sin(spin), normal + d * rng.uniform(0.2, 0.5),
                           length, rng.uniform(0.22, 0.32), thick=rng.uniform(0.1, 0.16)))
        a += length / (WINDOW_RADIUS + 0.14) * rng.uniform(0.8, 0.95)
    # A few short boards nailed across the frame.
    for a in (0.9, 2.9, 4.7):
        d = right * math.cos(a) + up * math.sin(a)
        upper.append(plank(c + d * (WINDOW_RADIUS + 0.15) + normal * 0.18, d, normal, 0.5, 0.16, thick=0.07,
                           tone=(WOOD_DARK, WOOD, CORE)))
    for a in (0.5, 2.2, 3.9, 5.3):
        d = right * math.cos(a) + up * math.sin(a)
        upper.append(boulder(c + d * (WINDOW_RADIUS + 0.2) + normal * 0.16, (0.32, 0.26, 0.26), moss=0.1))

    # Glow: the golden window and its crescent (Godot drives both).
    window = flat_disc(c - normal * 0.02, right, up, normal, WINDOW_RADIUS + 0.02)
    moon = crescent(c + normal * 0.0, right, up, normal, 0.34, 0.15)
    moon.location = g(normal * 0.005)

    # Its hoard, floating in the light.
    hoard = build_hoard(c + normal * 0.08, right, up, normal)

    # A hump of boulders across the shoulders and back, a moss mantle on top.
    for at, size in (((-1.05, 3.85, -0.2), (1.0, 0.75, 0.95)), ((1.05, 3.88, -0.2), (1.05, 0.78, 0.95)),
                     ((0.0, 4.02, -0.5), (1.2, 0.8, 0.95)), ((-0.5, 3.7, -0.95), (0.9, 0.7, 0.7)),
                     ((0.55, 3.72, -0.9), (0.85, 0.65, 0.75)), ((-0.1, 3.3, -1.05), (0.8, 0.6, 0.55))):
        upper.append(boulder(at, size, moss=0.45))
    # Moss in ragged patches, not a lawn: the stones and planks show between.
    mantle = blob("moss", [((-1.1, 4.22, -0.25), (0.5, 0.2, 0.45)), ((-0.35, 4.32, -0.55), (0.45, 0.18, 0.4)),
                           ((0.75, 4.25, -0.2), (0.42, 0.18, 0.4)), ((0.2, 4.2, -1.0), (0.4, 0.16, 0.3)),
                           ((-1.45, 3.95, 0.1), (0.3, 0.18, 0.3))],
                  moss_colour(1), resolution=0.04, bumps=0.08, seed=4)
    upper.append(mantle)
    upper += sapling(Vector((-1.1, 4.3, -0.4)), 0.75, 11)
    upper += sapling(Vector((0.85, 4.3, -0.75)), 0.55, 17)
    # Fence pickets and crossed sticks poking out of the back.
    for at, tilt in (((0.25, 4.6, -0.95), 0.12), ((0.55, 4.5, -1.0), -0.1), ((-0.45, 4.45, -1.05), 0.2)):
        upper.append(plank(Vector(at), (math.sin(tilt), 1, -0.15), (0, 0, -1), 0.95, 0.15, thick=0.05,
                           tone=(WOOD_GREY, WOOD_LIGHT, WOOD_DARK)))
    upper.append(plank(Vector((0.4, 4.7, -1.02)), (1, 0.1, 0), (0, 0, -1), 0.7, 0.1, thick=0.05))
    for at, d in (((-0.95, 4.4, -0.85), (-0.5, 1.0, -0.4)), ((1.3, 4.2, -0.5), (0.6, 1.0, -0.3))):
        stick = detail.bark_log(1.1, 0.035, seed=rng.randint(0, 99), segments=16, taper=0.5)
        orient(stick, Vector(at), d, (0, 0, 1))
        upper.append(stick)

    # A red plaid scarf round the neck, its tail hanging down the chest.
    neck = [(math.sin(a) * 0.78, 3.62 + 0.05 * math.cos(a * 2.0), 0.55 + math.cos(a) * 0.6)
            for a in (math.tau * i / 28 for i in range(29))]
    upper.append(ribbon(neck, 0.32, 0.07, plaid, up=(0, 0, 1)))
    tail = [(0.55, 3.55, 1.12), (0.72, 3.25, 1.24), (0.86, 2.95, 1.26), (0.95, 2.62, 1.2), (1.0, 2.36, 1.12)]
    upper.append(ribbon(tail, lambda t: 0.36 - 0.06 * t, 0.06, plaid, twist=0.3, up=(1, 0, 0)))

    # Lanterns, bells and a pocket watch hanging off it.
    for at, top in (((-1.42, 3.2, 0.95), (-1.35, 3.62, 0.85)), ((1.2, 1.65, 1.0), (1.12, 2.05, 0.92))):
        parts, glass_part = lantern(Vector(at))
        upper += parts + chain(Vector(at) + Vector((0, 0.4, 0)), Vector(top))
        glass.append(glass_part)
    upper.append(bell(Vector((1.55, 3.3, 0.6))))
    upper.append(bell(Vector((-1.15, 1.75, 0.92))))
    watch = detail.bark_log(0.04, 0.12, segments=24, seed=5)
    common.color_by(watch, lambda p, n: CREAM if abs(n.x) > 0.8 else BRASS)
    orient(watch, Vector((-0.62, 2.62, 1.38)), (0, 0, 1), (1, 0, 0))
    upper.append(watch)
    upper += chain(Vector((-0.62, 2.76, 1.36)), Vector((-0.5, 3.35, 1.2)), link=0.05)

    # Hips: a lintel of stones and a plank belt.
    for at, size in (((-0.55, 1.45, 0.05), (0.95, 0.55, 0.95)), ((0.55, 1.42, 0.0), (0.95, 0.55, 0.95)),
                     ((0.0, 1.5, -0.35), (0.8, 0.5, 0.7))):
        legs.append(boulder(at, size, moss=0.1))
    # Short legs of piled boulders on broad, flat feet.
    for side in (-1.0, 1.0):
        legs.append(boulder((0.8 * side, 0.25, 0.12), (1.2, 0.5, 1.35), moss=0.2))
        legs.append(boulder((0.76 * side + rng.uniform(-0.05, 0.05), 0.7, 0.0), (0.95, 0.55, 0.9), moss=0.15))
        legs.append(boulder((0.72 * side, 1.08, -0.02), (0.88, 0.5, 0.85), moss=0.1))
        for k in range(3):
            legs.append(boulder((0.8 * side + (k - 1) * 0.32, 0.18, 0.75), (0.3, 0.3, 0.32), moss=0.3))
    return upper, legs, [window], [moon], glass, hoard


def build_hoard(c, right, up, normal):
    """The lost things in the window, around Godot point c."""
    parts = []

    def at(x, y, z=0.0):
        return c + right * x + up * y + normal * z
    # A little chair, tipped over.
    chair_tone = (WOOD_DARK, WOOD, CORE)
    seat_c, tip = at(-0.32, -0.12, 0.05), 0.4
    ax = right * math.cos(tip) + up * math.sin(tip)
    ay = up * math.cos(tip) - right * math.sin(tip)
    parts.append(plank(seat_c, ax, normal, 0.3, 0.26, thick=0.04, tone=chair_tone, step=0.03, carve=0.0))
    parts.append(plank(seat_c + ay * 0.17 - normal * 0.1, ax, normal, 0.3, 0.3, thick=0.04, tone=chair_tone, step=0.03,
                       carve=0.0))
    for sx in (-0.12, 0.12):
        for sz in (-0.1, 0.1):
            parts.append(plank(seat_c + ax * sx - ay * 0.13 + normal * sz, ay, normal, 0.24, 0.035, thick=0.035,
                               tone=chair_tone, step=0.03, carve=0.0))
    # A teddy.
    t = at(0.34, -0.3, 0.06)
    for off, radii, tone in ((Vector((0, 0, 0)), (0.12, 0.14, 0.1), TOY), (up * 0.2, (0.1, 0.09, 0.09), TOY),
                             (up * 0.18 + normal * 0.08, (0.045, 0.035, 0.035), TOY_LIGHT)):
        parts.append(ball(t + off, radii, tone))
    for sx in (-1, 1):
        parts.append(ball(t + up * 0.28 + right * 0.07 * sx, (0.04, 0.04, 0.03), TOY))
        parts.append(ball(t + up * 0.03 + right * 0.13 * sx, (0.04, 0.07, 0.04), TOY))
        parts.append(ball(t - up * 0.12 + right * 0.07 * sx + normal * 0.04, (0.05, 0.05, 0.05), TOY))
    # A pocket watch and a key.
    watch = detail.bark_log(0.035, 0.1, segments=24, seed=9)
    common.color_by(watch, lambda p, n: CREAM if abs(n.x) > 0.8 else BRASS)
    orient(watch, at(0.08, 0.36, 0.04), normal, right)
    parts.append(watch)
    key = detail.bark_log(0.32, 0.018, segments=8, seed=2)
    common.color_by(key, lambda p, n: BRASS)
    orient(key, at(-0.05, -0.5, 0.05), right * 0.9 + up * 0.4, normal)
    parts.append(key)
    parts.append(rope_loop(0.05, 0.015, location=g(at(-0.22, -0.58, 0.05)), base=BRASS, strands=0))
    for x, y, s in ((-0.5, 0.3, 0.07), (0.5, 0.2, 0.06), (-0.15, 0.55, 0.05), (0.55, -0.15, 0.05), (-0.58, -0.35, 0.04)):
        parts.append(star(at(x, y, 0.03), right, up, s))
    return parts


FACE_EYES = (
    # (centre x, y, half-width, half-height, tilt): the big eye is on the
    # viewer's left (-x); the small one sits lower, near the other edge.
    (-0.17, 0.14, 0.15, 0.1, 0.12),
    (0.25, 0.08, 0.1, 0.075, -0.2),
)
## How far the face planks sit in front of the neck pivot.
FACE_Z = 0.42


def carve_eyes(mask):
    """Carves the eye holes into the joined face planks (head-local Godot
    axes): an almond bowl per eye, a soot-dark cavity, a raised brow
    ridge above it and a darker lid line, so the eyes sit deep in the
    wood like the sheet's."""
    mesh = mask.data
    attr = mesh.color_attributes.get("Col")
    depth = 0.11
    weights = []
    for v in mesh.vertices:
        x, y, z = v.co.x, v.co.z, -v.co.y
        best, ridge = 0.0, 0.0
        for cx, cy, rx, ry, tilt in FACE_EYES:
            dx, dy = x - cx, y - cy
            ca, sa = math.cos(tilt), math.sin(tilt)
            u, w = (dx * ca + dy * sa) / rx, (-dx * sa + dy * ca) / ry
            e = u * u + w * w
            front = z > FACE_Z - 0.03
            if front and e < 1.0:
                best = max(best, 1.0 - e)
            elif front and e < 2.2 and w > 0.2:
                ridge = max(ridge, (1.0 - abs(e - 1.5) / 0.7) * min(1.0, w))
        if best > 0:
            v.co.y += depth * math.sqrt(best) + 0.02
        if ridge > 0:
            v.co.y -= 0.035 * ridge
        weights.append((best, ridge))
    soot = common.srgb(CORE)
    ember = common.srgb((0.45, 0.2, 0.08))
    for loop in mesh.loops:
        best, ridge = weights[loop.vertex_index]
        c = attr.data[loop.index].color
        if best > 0:
            t = min(1.0, best * 4.0)
            target = tuple(soot[k] + (ember[k] - soot[k]) * best for k in range(3))
            attr.data[loop.index].color = (*(c[k] + (target[k] - c[k]) * t for k in range(3)), 1.0)
        elif ridge > 0:
            attr.data[loop.index].color = (*(c[k] * (1.0 - 0.35 * ridge) for k in range(3)), 1.0)


def build_head():
    """Head parts in head-local Godot axes (origin at the neck pivot, before
    the lean and face tilt), plus the eyes. After the sheet's close-ups:
    a tall, slightly convex mask of upright planks with tight dark gaps,
    jagged plank ends at the chin, almond eye holes carved deep into the
    wood and glowing from inside (the right one bigger), a nailed patch
    plank on each cheek, and planks, moss and a sprig rising behind the
    top like a hood."""
    parts = []
    parts.append(blob("skull", [((0, 0.02, 0.0), (0.42, 0.55, 0.38))], lambda p, n: CORE, resolution=0.04, bumps=0.03))
    # The mask: five upright planks on a gentle arc, tops roughly level,
    # bottoms ragged.
    mask = []
    xs = [-0.38, -0.19, 0.0, 0.19, 0.38]
    tops = [0.42, 0.53, 0.57, 0.54, 0.44]
    bottoms = [-0.46, -0.53, -0.6, -0.55, -0.47]
    for x, top, bottom in zip(xs, tops, bottoms):
        top += rng.uniform(-0.03, 0.03)
        bottom += rng.uniform(-0.05, 0.05)
        a = x / 0.95
        n = Vector((math.sin(a), 0.0, math.cos(a)))
        at = Vector((math.sin(a) * 0.95, (top + bottom) * 0.5, FACE_Z - 0.95 + math.cos(a) * 0.95 + rng.uniform(-0.01, 0.015)))
        mask.append(plank(at, (rng.uniform(-0.025, 0.025), 1, 0), n, top - bottom, rng.uniform(0.175, 0.185), thick=0.12,
                          step=0.02, carve=0.02, tone=(WOOD_GREY, (0.8, 0.74, 0.64), (0.24, 0.19, 0.15))))
    face = common.join(mask, "mask")
    apply_all(face)
    carve_eyes(face)
    parts.append(face)
    # Nailed patch planks across the cheeks.
    for at, ang, length in (((-0.5, 0.1, FACE_Z - 0.04), 0.25, 0.24),):
        parts.append(plank(Vector(at), (math.cos(ang), math.sin(ang), 0), (0, 0, 1), length, 0.09, thick=0.04, step=0.02,
                           tone=(WOOD_DARK, WOOD, CORE)))
    # Sides of the head: a plank each, set back.
    for side in (-1, 1):
        parts.append(plank(Vector((0.44 * side, -0.05, 0.05)), (0, 1, 0.1), (side, 0, 0.3), 0.8, 0.32, thick=0.1, step=0.04))
    # A hood of planks leaning back over the top, moss and a sprig on it.
    for k, x in enumerate((-0.3, -0.1, 0.1, 0.3)):
        ang = rng.uniform(-0.12, 0.12)
        drop = 0.12 * (abs(x) / 0.3) ** 2
        parts.append(plank(Vector((x, 0.5 - drop + 0.02 * (k % 2), 0.02)), (math.sin(ang), 0.25, -1.0),
                           (x * 0.8, 1, 0.25), 0.72, 0.21, thick=0.08, step=0.04))
    parts.append(blob("moss", [((-0.08, 0.56, 0.3), (0.3, 0.09, 0.17)), ((0.26, 0.48, 0.25), (0.16, 0.08, 0.14)),
                               ((0.05, 0.52, 0.05), (0.3, 0.08, 0.2))],
                      moss_colour(7), resolution=0.025, bumps=0.04, seed=7))
    sprig = detail.leaf_clump(g(Vector((-0.32, 0.74, -0.15))), 0.13, 23, tufts=8, subdivisions=3)
    detail.colour_foliage(sprig, MOSS_DARK, LEAF, LEAF_LIGHT, seed=23)
    parts.append(sprig)
    # The glow sits inside each carved hole.
    eyes = []
    for cx, cy, rx, ry, tilt in FACE_EYES:
        eye = ball(Vector((0, 0, 0)), (rx * 0.8, ry * 0.72, 0.02), EYE)
        eye.rotation_euler = (0, -tilt, 0)  # a roll in the face plane (Godot +Z is Blender -Y)
        # Just behind the plank faces: the decimated game mesh keeps only a
        # shallow bowl, so a deeper glow would hide behind it.
        eye.location = g(Vector((cx, cy - ry * 0.12, FACE_Z + 0.03)))
        eyes.append(eye)
    return parts, eyes


def build_arm(side):
    """Arm parts in arm-local Godot axes (origin at the shoulder pivot,
    hanging straight down), plus glass."""
    parts, glass = [], []
    s = side
    # Shoulder boulder and a plank pauldron over it.
    parts.append(boulder((0.12 * s, -0.05, 0.0), (0.95, 0.85, 0.9), moss=0.35))
    for k in range(4):
        a = -0.9 + k * 0.55
        n = Vector((math.sin(a) * s, math.cos(a), 0.0))
        along = Vector((math.cos(a) * s, -math.sin(a), 0.0))
        parts.append(plank(Vector((0.15 * s, 0.05, -0.35 + k * 0.25)) + n * 0.5, along, n, 0.9, 0.3, thick=0.09))
    parts.append(rope_ring(Vector((0.12 * s, -0.1, 0.0)), (1, -0.3 * s, 0), 0.55, thick=0.04))
    # Upper arm: three lashed logs.
    for k, (dx, dz) in enumerate(((-0.15, -0.08), (0.15, -0.08), (0.0, 0.16))):
        log = detail.bark_log(1.35, rng.uniform(0.15, 0.19), seed=k + (10 if s > 0 else 20), segments=40, taper=0.92)
        orient(log, Vector((0.15 * s + dx, -0.95, 0.05 + dz)), (rng.uniform(-0.08, 0.08), 1, rng.uniform(-0.08, 0.08)),
               (0, 0, 1))
        parts.append(log)
    for y in (-0.62, -1.18):
        parts.append(rope_ring(Vector((0.15 * s, y, 0.05)), (0.1 * s, 1, 0.1), 0.34, thick=0.045))
    # Elbow boulder.
    parts.append(boulder((0.18 * s, -1.5, 0.05), (0.62, 0.48, 0.6), moss=0.2))
    # Forearm: a fat bundle of planks, bent forward and widening toward
    # the fist, loosely roped.
    axis_top, axis_bottom = Vector((0.18 * s, -1.58, 0.12)), Vector((0.26 * s, -2.36, 0.42))
    axis = (axis_bottom - axis_top).normalized()
    u = (Vector((1, 0, 0)) - axis * axis.x).normalized()
    v = axis.cross(u)
    parts.append(blob("forearm_core", [(axis_top.lerp(axis_bottom, 0.5), (0.36, 0.5, 0.36))],
                      lambda p, n: CORE, resolution=0.05, bumps=0.03))
    for k in range(9):
        a = math.tau * k / 9 + rng.uniform(-0.15, 0.15)
        d = u * math.cos(a) + v * math.sin(a)
        top = axis_top + d * rng.uniform(0.26, 0.32)
        bottom = axis_bottom + d * rng.uniform(0.38, 0.46)
        parts.append(plank((top + bottom) * 0.5 + axis * rng.uniform(-0.06, 0.06), bottom - top, d,
                           rng.uniform(0.85, 1.05), rng.uniform(0.22, 0.3), thick=rng.uniform(0.08, 0.12)))
    pts = []
    for i in range(50):
        t = i / 49
        a = t * math.tau * 1.7 + 0.6
        rr = (0.4 + 0.1 * t) * (1.0 + noise.noise(Vector((t * 4.0, s, 1.0))) * 0.1)
        pts.append(axis_top.lerp(axis_bottom, 0.15 + 0.7 * t + noise.noise(Vector((t * 3.0, s, 5.0))) * 0.05)
                   + (u * math.cos(a) + v * math.sin(a)) * rr)
    parts.append(rope(pts, 0.05))
    # A huge clenched fist of rounded, weathered wooden blocks: a palm,
    # four curled fingers of three blocks each, a thumb, moss on top.
    f = Vector((FIST.x * s, FIST.y, FIST.z))
    parts.append(wood_block(f, (1.15, 0.95, 0.95), tone=WOOD, round_=0.24, warp=0.05))
    for i, (width, drop) in enumerate(((0.33, 0.0), (0.31, 0.03), (0.3, 0.06), (0.26, 0.12))):
        x = (-0.45 + 0.3 * i + rng.uniform(-0.02, 0.02)) * s
        y0 = -drop + rng.uniform(-0.04, 0.04)
        parts.append(wood_block(f + Vector((x, 0.12 + y0, 0.52)), (width, 0.42, 0.36), tone=WOOD_GREY, round_=0.12,
                                rot=(0.25 + rng.uniform(-0.1, 0.1), 0, rng.uniform(-0.08, 0.08)), warp=0.03))
        parts.append(wood_block(f + Vector((x, -0.26 + y0, 0.56)), (width * 0.95, 0.36, 0.36), tone=WOOD, round_=0.12,
                                rot=(0.75 + rng.uniform(-0.1, 0.1), 0, rng.uniform(-0.08, 0.08)), warp=0.03))
        parts.append(wood_block(f + Vector((x, -0.5 + y0, 0.28)), (width * 0.9, 0.26, 0.34), tone=WOOD_GREY, round_=0.1,
                                rot=(1.35, 0, rng.uniform(-0.1, 0.1)), warp=0.03))
    parts.append(wood_block(f + Vector((-0.6 * s, -0.12, 0.36)), (0.32, 0.5, 0.36), tone=WOOD, round_=0.12,
                            rot=(0.3, 0.25 * s, 0.45 * s), warp=0.03))
    parts.append(blob("fist_moss", [(f + Vector((0.05 * s, 0.5, 0.0)), (0.55, 0.14, 0.5)),
                                    (f + Vector((-0.2 * s, 0.42, 0.45)), (0.35, 0.1, 0.25))], moss_colour(3 + side),
                      resolution=0.03, bumps=0.05, seed=8))
    parts.append(rope_ring(f + Vector((0, 0.42, -0.05)), (0, 1, 0.15), 0.6, thick=0.05, wobble=0.1))
    # Something hanging off each arm: a lantern on the right, a bell on the left.
    if s > 0:
        p, gl = lantern(Vector((0.62, -1.1, 0.35)))
        parts += p + chain(Vector((0.62, -0.7, 0.35)), Vector((0.42, -0.62, 0.25)))
        glass.append(gl)
    else:
        parts.append(bell(Vector((-0.58, -2.05, 0.5))))
        parts += chain(Vector((-0.58, -1.88, 0.5)), Vector((-0.45, -1.7, 0.4)))
    return parts, glass


def build_debris():
    """Loose pieces for the falling-apart ending: planks, boulders, logs and
    fist blocks, each laid where it sits on the standing golem (unleaned
    Godot axes). Godot hides them until the golem collapses, then drops
    them into a pile."""
    parts = []
    for az, el, length, width in ((0.9, 0.3, 1.2, 0.42), (-1.0, 0.35, 1.1, 0.4), (1.6, -0.3, 1.0, 0.38),
                                  (-1.7, -0.25, 1.15, 0.44), (2.5, 0.4, 1.25, 0.4), (-2.6, 0.1, 0.9, 0.36),
                                  (0.6, -0.6, 0.85, 0.32), (-0.5, 0.75, 0.8, 0.3)):
        p, n, up, around = chest_point(az, el, 0.12)
        parts.append(plank(p, up, n, length, width, thick=0.1))
    for at, size in (((-1.0, 3.9, -0.1), (0.8, 0.6, 0.7)), ((1.0, 3.95, -0.2), (0.75, 0.6, 0.75)),
                     ((0.0, 4.05, -0.5), (0.85, 0.65, 0.7)), ((0.5, 1.45, 0.1), (0.7, 0.45, 0.65))):
        parts.append(boulder(at, size, moss=0.35))
    for side in (-1.0, 1.0):
        log = detail.bark_log(1.2, 0.18, seed=40 + int(side), segments=40, taper=0.92)
        orient(log, Vector((1.85 * side, 2.8, 0.1)), (0.1 * side, 1, 0), (0, 0, 1))
        parts.append(log)
        parts.append(wood_block(Vector((1.95 * side, 0.85, 0.45)), (0.7, 0.6, 0.6), tone=WOOD, round_=0.16, warp=0.04))
        parts.append(wood_block(Vector((1.7 * side, 0.55, 0.85)), (0.3, 0.4, 0.34), tone=WOOD_GREY, round_=0.1))
    return parts


def finish_debris(parts, matrix):
    """Bakes the debris as one object, then splits it into its loose pieces
    (one shared texture) under an empty `Debris`."""
    obj = common.join(parts, "Debris_all")
    apply_all(obj)
    obj.data.transform(matrix)
    if not QUICK:
        high = obj.copy()
        high.data = obj.data.copy()
        obj.users_collection[0].objects.link(high)
        high.hide_render = True
        detail.decimate_tris(obj, 3000)
        paint_bake.paint_direct(obj, high, name="moon_eater_debris", size=512, ao_distance=0.3, ao_strength=0.7,
                                edge_strength=0.4, edge_radius=0.02, noise_scale=6.0, cavity=0.6, max_ray_distance=0.06,
                                cage_extrusion=0.03)
    common.select_only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    pieces = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    root = common.link(bpy.data.objects.new("Debris", None))
    kept = []
    for k, piece in enumerate(sorted(pieces, key=lambda o: -len(o.data.polygons))):
        if len(piece.data.polygons) < 12:
            data = piece.data
            bpy.data.objects.remove(piece)
            bpy.data.meshes.remove(data)
            continue
        common.select_only([piece])
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        piece.name = "Debris_%02d" % len(kept)
        world = piece.matrix_world.copy()
        piece.parent = root
        piece.matrix_world = world
        kept.append(piece)
    print("Debris pieces:", len(kept), "tris:", common.triangle_count(kept))
    return root, kept


# --- Bake and export --------------------------------------------------------------

def finish(parts, name, matrix=None, location=None):
    """Joins a part's pieces, applies `matrix` (Blender axes) to its
    vertices, moves its origin to `location` (Godot) and paints it."""
    obj = common.join(parts, name)
    apply_all(obj)
    if matrix is not None:
        obj.data.transform(matrix)
    if location is not None:
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
    paint_bake.paint_direct(obj, high, name="moon_eater_" + name.lower(), size=SIZES[name], ao_distance=0.3,
                            ao_strength=0.75, edge_strength=0.4, edge_radius=0.02, noise_scale=6.0, cavity=0.6,
                            max_ray_distance=0.06, cage_extrusion=0.03)
    print(name, "tris:", common.triangle_count([obj]), "(dense %d)" % dense)
    return obj


def glow(parts, name, colour, strength, parent, matrix=None):
    obj = common.join(parts, name)
    apply_all(obj)
    if matrix is not None:
        obj.data.transform(matrix)
    obj.data.transform(Matrix.Translation(-parent.location))
    paint_bake.flat_material(obj, colour, emission=strength, name="moon_eater_" + name.lower() + "_painted")
    obj.parent = parent
    obj.location = (0, 0, 0)
    return obj


def main():
    common.reset(38)
    if HEAD_ONLY:
        head_parts, eye_parts = build_head()
        head = finish(head_parts, "Head", location=Vector((0, 0, 0)))
        eyes = glow(eye_parts, "Head_Eyes", EYE, 3.0, head)
        if QUICK:
            preview.render_clay([head, eyes], "moon_eater_head", views=preview.FACE_VIEWS, zoom=0.9)
        else:
            preview.render([head, eyes], "moon_eater_head", elevation=5, azimuth=0)
            preview.render([head, eyes], "moon_eater_head_34", elevation=8, azimuth=30)
        return
    lean_m = Matrix.Translation(g(HIP)) @ rot_x(LEAN) @ Matrix.Translation(-g(HIP))

    upper, legs, window, moon, glass, hoard = build_body()
    body_upper = common.join(upper, "BodyUpper")
    apply_all(body_upper)
    body_upper.data.transform(lean_m)
    body = finish([body_upper] + legs, "Body", location=Vector((0, 0, 0)))
    glows = [glow(window, "Body_Window", WINDOW_GLOW, 2.0, body, lean_m),
             glow(moon, "Body_Moon", MOON, 2.5, body, lean_m),
             glow(glass, "Body_Glow", GLOW, 2.5, body, lean_m)]
    c, right, up, normal = window_frame()
    hoard_obj = finish(hoard, "Hoard", matrix=lean_m, location=lean(c))
    hoard_obj.parent = body

    head_parts, eye_parts = build_head()
    neck = lean(NECK)
    head_m = Matrix.Translation(g(neck)) @ rot_x(LEAN + FACE_TILT)
    bpy.context.view_layer.update()  # pieces placed by location/rotation must have fresh matrices
    for o in head_parts + eye_parts:
        o.matrix_world = head_m @ o.matrix_world
    head = finish(head_parts, "Head", location=neck)
    glows.append(glow(eye_parts, "Head_Eyes", EYE, 3.0, head))

    arms = []
    for side, name in ((-1.0, "ArmL"), (1.0, "ArmR")):
        pivot = lean(Vector((SHOULDER.x * side, SHOULDER.y, SHOULDER.z)))
        parts, glass_parts = build_arm(side)
        m = Matrix.Translation(g(pivot))
        bpy.context.view_layer.update()
        for o in parts + glass_parts:
            o.matrix_world = m @ o.matrix_world
        arm = finish(parts, name, location=pivot)
        arms.append(arm)
        if glass_parts:
            glows.append(glow(glass_parts, name + "_Glow", GLOW, 2.5, arm))

    debris, pieces = finish_debris(build_debris(), lean_m)

    objects = [body, hoard_obj, head] + arms + glows + [debris] + pieces
    for o in [body, hoard_obj, head] + arms + glows:
        print("%-12s origin %s" % (o.name, tuple(round(v, 3) for v in o.matrix_world.translation)))
    print("total tris:", common.triangle_count(objects))
    if QUICK:
        preview.render_clay(objects, "moon_eater")
        return
    common.export_glb(os.path.join(common.OUT_DIR, "moon_eater.glb"), objects, image_format="WEBP")
    preview.render(objects, "moon_eater", elevation=12, azimuth=20)
    preview.render(objects, "moon_eater_game", elevation=50, azimuth=10)


if __name__ == "__main__":
    main()
