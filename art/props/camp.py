"""Camp props in the chunky, painted style: campfire (stones + teepee
logs), the cream A-frame tent with crossed poles (feature 031, after
the October concept art), stake fence, watch post, torch, woodpile,
crate, barrel and toadstools. Each prop is built from bevelled blocks,
logs and ropes, coloured per part, then painted-baked.

Run: python art/props/camp.py [prop ...]"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Euler, Matrix, Vector, noise  # noqa: E402

from lib import common, detail, paint_bake, preview  # noqa: E402
from nature.rocks import boulder  # noqa: E402

WOOD = (0.62, 0.4, 0.24)
WOOD_LIGHT = (0.8, 0.58, 0.34)
WOOD_DARK = (0.36, 0.22, 0.13)
BARK = (0.42, 0.27, 0.17)
END_GRAIN = (0.9, 0.7, 0.45)
CHAR = (0.12, 0.09, 0.08)
COBBLE = (0.4, 0.41, 0.43)
COBBLE_LIGHT = (0.62, 0.62, 0.61)
COBBLE_DARK = (0.22, 0.22, 0.24)
ROPE = (0.86, 0.74, 0.5)
IRON = (0.3, 0.32, 0.38)
CANVAS = (0.95, 0.88, 0.72)
STRIPE = (0.86, 0.26, 0.2)
CANVAS_SHADE = (0.8, 0.68, 0.5)
ROOF = (0.72, 0.22, 0.16)
ROOF_LIGHT = (0.92, 0.42, 0.24)


# --- Primitive builders -----------------------------------------------------

def _finish(obj, bevel=0.03, segments=2, smooth_angle=35):
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(30)
        common.apply_all_modifiers(obj)
    common.shade_smooth(obj, auto_angle=smooth_angle)
    return obj


def block(size, location=(0, 0, 0), rotation=(0, 0, 0), bevel=0.03, warp=0.0, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        if warp:
            v.co += Vector((noise.noise(v.co * 3 + Vector((seed, 0, 0))), noise.noise(v.co * 3 + Vector((0, seed, 0))), 0)) * warp
    obj = common.mesh_object("block", bm)
    _finish(obj, bevel)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def log(length, radius, location=(0, 0, 0), rotation=(0, 0, 0), segments=10, taper=0.9, seed=0):
    """A log along local X with bark sides and pale end grain."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius * taper, depth=length)
    for v in bm.verts:
        v.co.xy *= 1.0 + noise.noise(v.co * 4 + Vector((seed, seed, 0))) * 0.08
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    obj = common.mesh_object("log", bm)
    _finish(obj, bevel=radius * 0.18, segments=2, smooth_angle=50)

    def colour(pos, normal):
        if abs(normal.x) > 0.8:
            r = Vector((pos.y, pos.z)).length / radius
            return common.lerp(END_GRAIN, WOOD, (math.sin(r * 14.0) * 0.5 + 0.5) * 0.35 + r * 0.35)
        n = noise.noise(Vector((pos.x * 1.5, pos.y * 10.0, pos.z * 10.0)) + Vector((seed, 0, 0)))
        return common.lerp(BARK, WOOD, max(0.0, min(1.0, 0.45 + n * 0.8)))
    common.color_by(obj, colour, smooth=False)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def stake(height, radius, location=(0, 0, 0), tilt=(0, 0), seed=0):
    """A sharpened post: log body with a conical point."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=radius, radius2=radius * 0.95, depth=height)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, height / 2))
    top = [v for v in bm.verts if v.co.z > height - 0.001]
    bmesh.ops.pointmerge(bm, verts=top, merge_co=(0, 0, height + radius * 2.2))
    for v in bm.verts:
        v.co.xy *= 1.0 + noise.noise(v.co * 5 + Vector((seed, 0, 0))) * 0.1
    obj = common.mesh_object("stake", bm)
    _finish(obj, bevel=0.015, smooth_angle=45)

    def colour(pos, normal):
        if pos.z > height - radius * 0.2:
            return WOOD_LIGHT
        n = noise.noise(Vector((pos.x * 12, pos.y * 12, pos.z * 1.2 + seed)))
        return common.lerp(BARK, WOOD, max(0.0, min(1.0, 0.5 + n)))
    common.color_by(obj, colour, smooth=False)
    obj.rotation_euler = (tilt[0], tilt[1], 0)
    obj.location = location
    return obj


def rope_ring(radius, thickness, location, rotation=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, segments=12, radius=radius)
    obj = common.mesh_object("rope", bm)
    mod = obj.modifiers.new("Skin", "SKIN")
    bm2 = bmesh.new()
    bm2.from_mesh(obj.data)
    bm2.verts.ensure_lookup_table()
    layer = bm2.verts.layers.skin.verify()
    for v in bm2.verts:
        v[layer].radius = (thickness, thickness)
    bm2.to_mesh(obj.data)
    bm2.free()
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    common.set_color(obj, ROPE)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def colour_wood(obj, seed=0, base=WOOD, light=WOOD_LIGHT, dark=WOOD_DARK):
    def colour(pos, normal):
        grain = noise.noise(Vector((pos.x * 1.2, pos.y * 14.0, pos.z * 14.0)) + Vector((seed, 0, 0)))
        grain += noise.noise(Vector((pos.x * 14.0, pos.y * 1.2, pos.z * 14.0)) + Vector((0, seed, 0))) * 0.5
        c = common.lerp(base, light, max(0.0, min(1.0, 0.5 + grain * 0.6)))
        if grain < -0.35:
            c = common.lerp(c, dark, 0.6)
        return c
    common.color_by(obj, colour, smooth=False)


def flat(obj, colour):
    common.set_color(obj, colour)
    return obj


def finish_prop(parts, name, size=512, preview_elevation=35, **paint):
    obj = common.join(parts, name)
    params = dict(ao_distance=0.25, ao_strength=0.7, edge_strength=0.45, edge_radius=0.02, noise_scale=6.0)
    params.update(paint)
    paint_bake.paint(obj, size=size, **params)
    common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), [obj])
    print(name, "tris:", common.triangle_count([obj]))
    preview.render([obj], name, elevation=preview_elevation)
    return obj


# --- Dense detail helpers (feature 031 M6) ------------------------------------
# Dense meshes for detail.bake_prop: their look is baked into the texture of
# the decimated game mesh. log(), block() and stake() above are shared with
# other scripts and stay as they are.

IRON_DARK = (0.2, 0.2, 0.24)
RUST = (0.5, 0.3, 0.18)
CHAR_GREY = (0.32, 0.29, 0.28)
EMBER = (1.0, 0.56, 0.16)
EARTH = (0.32, 0.23, 0.15)
MOSS = (0.42, 0.48, 0.2)


def _clamp(t):
    return max(0.0, min(1.0, t))


def _apply(obj):
    """Bakes the object's transform into its mesh."""
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def place(obj, location=(0, 0, 0), rotation=(0, 0, 0)):
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def low_log(length, radius, location=(0, 0, 0), rotation=(0, 0, 0), segments=8, taper=1.0):
    """A bare low-poly cylinder along local X: a hand-made low twin for
    bake_prop_lows."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius * taper, depth=length)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    obj = common.mesh_object("low_log", bm)
    common.shade_smooth(obj, auto_angle=50)
    return place(obj, location, rotation)


def low_stake(height, radius, location=(0, 0, 0), tilt=(0, 0), segments=6, point=2.2):
    """bark_stake's low-poly twin: a prism with a pointed top."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=height)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, height / 2))
    top = [v for v in bm.verts if v.co.z > height - 0.001]
    for v in top:
        v.co.xy *= 0.94
    bmesh.ops.pointmerge(bm, verts=top, merge_co=(0, 0, height + radius * point))
    obj = common.mesh_object("low_stake", bm)
    common.shade_smooth(obj, auto_angle=50)
    return place(obj, location, (tilt[0], tilt[1], 0))


def _vertex_colours(obj, colours):
    """One sRGB colour per mesh vertex into 'Col'."""
    mesh = obj.data
    attr = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    lin = [common.srgb(c) for c in colours]
    for loop in mesh.loops:
        attr.data[loop.index].color = (*lin[loop.vertex_index], 1.0)
    mesh.color_attributes.active_color = attr


def _slice(bm, size, step):
    """Even cuts along each axis of a centred box, so colour noise and the
    bake's cavity have vertices to work with."""
    for axis in range(3):
        n = max(1, int(round(size[axis] / step)))
        for k in range(1, n):
            co = [0.0, 0.0, 0.0]
            co[axis] = -size[axis] / 2 + size[axis] * k / n
            no = [0.0, 0.0, 0.0]
            no[axis] = 1.0
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no)


def dense_box(size, location=(0, 0, 0), rotation=(0, 0, 0), bevel=0.012, step=0.025, warp=0.0, seed=0):
    """A bevelled box cut into an even grid of about `step`."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=min(bevel, min(size) * 0.45), segments=2,
                        affect="EDGES", profile=0.5, clamp_overlap=True)
    _slice(bm, size, step)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges[:], dist=1e-5)
    if warp:
        for v in bm.verts:
            p = v.co * 3.0
            v.co += Vector((noise.noise(p + Vector((seed, 0, 0))), noise.noise(p + Vector((0, seed, 0))),
                            noise.noise(p + Vector((0, 0, seed))))) * warp
    obj = common.mesh_object("dense_box", bm)
    common.shade_smooth(obj, auto_angle=50)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def wood_colour(seed=0, base=WOOD, light=WOOD_LIGHT, dark=WOOD_DARK, along=0, knots=True):
    """Per-vertex grain running along local axis `along`, a knot now and
    then and paler end grain."""
    def colour(pos, normal):
        a, b, c = pos[along], pos[(along + 1) % 3], pos[(along + 2) % 3]
        g = noise.noise(Vector((a * 1.4 + seed * 3.1, b * 14.0, c * 14.0)))
        g += noise.noise(Vector((a * 0.5, b * 6.0 + seed, c * 6.0))) * 0.7
        col = common.lerp(base, light, _clamp(0.5 + g * 0.5))
        if g < -0.3:
            col = common.lerp(col, dark, _clamp((-0.3 - g) * 2.5) * 0.75)
        if knots:
            k = noise.noise(Vector((a * 5.0, b * 5.0, c * 5.0)) + Vector((seed * 1.7, 4.0, 0)))
            if k > 0.5:
                col = common.lerp(col, dark, _clamp((k - 0.5) * 6.0) * 0.8)
        if abs(normal[along]) > 0.8:
            col = common.lerp(col, END_GRAIN, 0.35)
        return col
    return colour


def board(size, location=(0, 0, 0), rotation=(0, 0, 0), seed=0, base=WOOD, light=WOOD_LIGHT, dark=WOOD_DARK,
          bevel=0.012, step=0.02, warp=0.004, knots=True, carve=0.0):
    """A dense board, long axis local X, with grain, knots and soft bevels.
    carve > 0 cuts weathered grain cracks that deep into the sides."""
    obj = dense_box(size, bevel=bevel, step=step, warp=warp, seed=seed)
    along = max(range(3), key=lambda i: size[i])
    if carve:
        for v in obj.data.vertices:
            a, b, c = v.co[along], v.co[(along + 1) % 3], v.co[(along + 2) % 3]
            g = noise.noise(Vector((a * 1.4 + seed * 3.1, b * 14.0, c * 14.0)))
            g += noise.noise(Vector((a * 0.5, b * 6.0 + seed, c * 6.0))) * 0.7
            if g < -0.35 and abs(v.normal[along]) < 0.5:
                v.co -= v.normal * carve * _clamp((-0.35 - g) * 3.0)
    common.color_by(obj, wood_colour(seed, base, light, dark, along=along, knots=knots), smooth=True)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def nail(location, normal=(0, -1, 0), radius=0.014, colour=IRON_DARK):
    """A domed iron nail head facing `normal`."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=radius)
    for v in bm.verts:
        v.co.z *= 0.45
    obj = common.mesh_object("nail", bm)
    common.shade_smooth(obj)
    common.set_color(obj, colour)
    obj.rotation_euler = Vector((0, 0, 1)).rotation_difference(Vector(normal)).to_euler()
    obj.location = location
    return obj


def bark_stake(height, radius, location=(0, 0, 0), tilt=(0, 0), seed=0, point=2.2, segments=40, groove=0.16):
    """stake() with real bark grooves and a knife-faceted, pale point."""
    tip = height + radius * point
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=1.0)
    side = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.5]
    bmesh.ops.subdivide_edges(bm, edges=side, cuts=max(8, min(90, int(tip / (radius * 0.2)))), use_grid_fill=True)
    facet = math.pi / 3

    def start(a):
        return height + noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, seed))) * radius * 0.5

    for v in bm.verts:
        z = (v.co.z + 0.5) * tip
        a = math.atan2(v.co.y, v.co.x)
        r = Vector((v.co.x, v.co.y)).length
        if r < 1e-6:
            v.co.z = z
            continue
        s = start(a)
        wobble = 1.0 + noise.noise(Vector((z * 2.0, seed, 0.5))) * 0.05
        if z <= s:
            cut = 1.0 - detail._ridge(detail._bark_point(a, z, radius, seed))
            rr = radius * (1.0 - cut * groove) * wobble
        else:
            t = (z - s) / max(tip - s, 1e-4)
            f = math.cos(facet / 2) / math.cos(((a + seed) % facet) - facet / 2)
            rr = radius * 0.94 * wobble * max(0.04, 1.0 - t) * f
        v.co = Vector((math.cos(a) * rr, math.sin(a) * rr, z))
    obj = common.mesh_object("bark_stake", bm)
    common.shade_smooth(obj, auto_angle=55)

    def colour(pos, normal):
        a = math.atan2(pos.y, pos.x)
        s = start(a)
        if pos.z > s - radius * 0.05:
            edge = abs(((a + seed) % facet) - facet / 2) / (facet / 2)
            n = noise.noise(Vector((pos.x * 30, pos.y * 30, pos.z * 8 + seed)))
            c = common.lerp(WOOD_LIGHT, END_GRAIN, _clamp(0.45 + n * 0.6))
            if edge > 0.82:
                c = common.lerp(c, WOOD, 0.5)
            return common.lerp(c, (0.6, 0.52, 0.42), _clamp((pos.z - tip + radius * 0.6) / (radius * 0.6)) * 0.5)
        ridge = detail._ridge(detail._bark_point(a, pos.z, radius, seed))
        strip = noise.noise(detail._bark_point(a, pos.z, radius, seed + 7) * 0.7) * 0.5 + 0.5
        c = common.lerp(detail.BARK, detail.BARK_LIGHT, strip * 0.75)
        c = common.lerp(detail.BARK_DARK, c, ridge)
        if pos.z < 0.16:
            c = common.lerp(c, EARTH, _clamp((0.16 - pos.z) / 0.16) * 0.6)
        return c
    common.color_by(obj, colour, smooth=True)
    obj.rotation_euler = (tilt[0], tilt[1], 0)
    obj.location = location
    return obj


def rope_tube(points, thickness, closed=False, strands=3, base=ROPE, dark=None, seg=12, name="rope", spacing=None):
    """A laid rope along a polyline: `strands` twisted strands with dark
    grooves between them. strands=0 makes a plain smooth tube."""
    dark = dark or common.lerp(base, (0.28, 0.2, 0.13), 0.55)
    pts = [Vector(p) for p in points]
    if closed:
        pts.append(pts[0].copy())
    lengths = [0.0]
    for i in range(1, len(pts)):
        lengths.append(lengths[-1] + (pts[i] - pts[i - 1]).length)
    total = lengths[-1]
    n = max(2, int(total / (spacing or thickness * 0.5)))
    samples = []
    j = 0
    for k in range(n if closed else n + 1):
        s = total * k / n
        while j < len(pts) - 2 and lengths[j + 1] < s:
            j += 1
        span = lengths[j + 1] - lengths[j]
        samples.append(pts[j].lerp(pts[j + 1], (s - lengths[j]) / span if span > 0 else 0.0))
    m = len(samples)
    tangents = []
    for i in range(m):
        prev = samples[(i - 1) % m] if (closed or i > 0) else samples[i]
        nxt = samples[(i + 1) % m] if (closed or i < m - 1) else samples[i]
        tangents.append((nxt - prev).normalized())
    normal = tangents[0].orthogonal().normalized()
    lay = thickness * 7.0
    periods = max(1, round(total / lay))
    bm = bmesh.new()
    rings, colours = [], []
    for i, p in enumerate(samples):
        t = tangents[i]
        normal = (normal - t * normal.dot(t)).normalized()
        binormal = t.cross(normal)
        s = total * i / n
        ring = []
        for q in range(seg):
            phi = math.tau * q / seg
            if strands:
                g = 0.5 + 0.5 * math.cos(strands * (phi - math.tau * periods * s / total))
                r = thickness * (0.8 + 0.2 * math.sqrt(g))
                fibre = noise.noise(p * 90.0) * 0.12
                colours.append(common.lerp(dark, base, _clamp(0.3 + 0.7 * g + fibre)))
            else:
                r = thickness
                colours.append(base)
            ring.append(bm.verts.new(p + (normal * math.cos(phi) + binormal * math.sin(phi)) * r))
        rings.append(ring)
    for i in range(m if closed else m - 1):
        a, b = rings[i], rings[(i + 1) % m]
        for q in range(seg):
            w = (q + 1) % seg
            bm.faces.new((a[q], a[w], b[w], b[q]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bm.normal_update()
    obj = common.mesh_object(name, bm)
    # Outward normals: a ring's first face must point away from its axis.
    poly = obj.data.polygons[0]
    if poly.normal.dot(poly.center - samples[0]) < 0:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bm.to_mesh(obj.data)
        bm.free()
    common.shade_smooth(obj)
    _vertex_colours(obj, colours)
    return obj


def rope_loop(radius, thickness, location=(0, 0, 0), rotation=(0, 0, 0), squash=1.0, **kw):
    """A closed laid-rope ring in the local XY plane (rope_ring's detailed twin)."""
    pts = [(math.cos(a) * radius, math.sin(a) * radius * squash, 0)
           for a in (math.tau * i / 64 for i in range(64))]
    obj = rope_tube(pts, thickness, closed=True, **kw)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def helix(radius, z0, z1, turns, steps_per_turn=40, centre=(0, 0)):
    n = max(8, int(turns * steps_per_turn))
    return [(centre[0] + math.cos(math.tau * turns * k / n) * radius, centre[1] + math.sin(math.tau * turns * k / n) * radius,
             z0 + (z1 - z0) * k / n) for k in range(n + 1)]


def stone(size, location=(0, 0, 0), rotation=(0, 0, 0), seed=0, base=(0.6, 0.57, 0.54), light=(0.8, 0.73, 0.62),
          dark=(0.36, 0.33, 0.32), subdiv=3, moss=0.0, flat_bottom=True):
    """A dense, softly chiselled stone with speckles and pits, sitting on z = 0."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=0.5)
    off = Vector((seed * 1.7, seed * 0.3, seed * 2.9))
    for v in bm.verts:
        v.co *= 1.0 + noise.noise(v.co * 2.3 + off) * 0.16
    # Soft chisel: push the parts beyond a few planes back onto them.
    for _ in range(4):
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 1))).normalized()
        cut = rng.uniform(0.33, 0.42)
        for v in bm.verts:
            over = v.co.dot(d) - cut
            if over > 0:
                v.co -= d * over * 0.85
    for v in bm.verts:
        v.co += v.normal * noise.noise(v.co * 14.0 + off) * 0.012
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        if flat_bottom and v.co.z < -size[2] * 0.3:
            v.co.z = -size[2] * 0.3 + (v.co.z + size[2] * 0.3) * 0.15
    lowest = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= lowest
    obj = common.mesh_object("stone", bm)
    common.shade_smooth(obj, auto_angle=40)
    top = max(size[2], 0.01)

    def colour(pos, normal):
        n = noise.noise(pos * (2.5 / max(size)) + off)
        c = common.lerp(base, light, _clamp(0.5 + n * 0.9))
        speck = noise.noise(pos * (9.0 / max(size)) + off * 2)
        if speck > 0.35:
            c = common.lerp(c, dark, _clamp((speck - 0.35) * 4) * 0.5)
        elif speck < -0.45:
            c = common.lerp(c, light, 0.35)
        if moss and normal.z > 0.3:
            m = (normal.z - 0.3) * 2.0 + noise.noise(pos * (4.0 / max(size)) + off) * 1.2 - (1.0 - moss) * 1.5
            c = common.lerp(c, MOSS, _clamp(m) * 0.75)
        return c
    common.color_by(obj, colour, smooth=True)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def shingles(corners, rows, cols, normal, lift=0.03, arch=0.0, gap=0.01, overlap=0.3, seed=0, tones=(ROOF, ROOF_LIGHT),
             dark=(0.42, 0.14, 0.1), res=5, round_tabs=0.0, name="shingles"):
    """Overlapping courses of shingles or tiles over a quad face (A, B along
    the eave, D, C along the top; C == D for a pyramid face). Each piece is
    its own dense patch, its eave end lifted onto the course below (and
    `arch` bows it like a barrel tile), so courses and joints are real."""
    a, b, c, d = (Vector(p) for p in corners)
    normal = Vector(normal).normalized()
    rng = random.Random(seed)
    bm = bmesh.new()
    colours = []
    eave_w = (b - a).length
    gu = gap / max(eave_w, 1e-3) * 0.5
    for k in range(rows):
        t0 = k / rows
        t1 = min(1.0, (k + 1 + overlap) / rows)
        shift = 0.5 if k % 2 else 0.0
        for j in range(-1, cols):
            u0 = max(0.0, (j + shift) / cols)
            u1 = min(1.0, (j + 1 + shift) / cols)
            if u1 - u0 < 0.3 / cols:
                continue
            tone = rng.random()
            base = common.lerp(tones[0], tones[1], tone * 0.85)
            if rng.random() < 0.14:
                base = common.lerp(base, dark, 0.4)
            drop = rng.uniform(0.0, 0.12) / rows
            tilt = rng.uniform(-0.004, 0.004)
            grid = []
            for it in range(res + 1):
                tl = it / res
                row = []
                for iu in range(res + 1):
                    ul = iu / res
                    u = u0 + gu + (u1 - u0 - 2 * gu) * ul
                    lo = t0 - drop - round_tabs * math.sin(math.pi * ul) / rows
                    t = lo + (t1 - lo) * tl
                    p = (a.lerp(b, u)).lerp(d.lerp(c, u), t)
                    h = 0.006 + lift * (1.0 - tl) + arch * math.sin(math.pi * ul) + tilt * (ul - 0.5)
                    row.append(bm.verts.new(p + normal * h))
                    lich = noise.noise(p * 22.0 + Vector((seed, 0, 0)))
                    col = common.lerp(base, tones[1], 0.25 * (1.0 - tl))
                    if lich > 0.55:
                        col = common.lerp(col, (0.78, 0.74, 0.52), 0.45)
                    colours.append(common.lerp(col, dark, 0.35 * _clamp((tl - 0.6) * 2.5)))
                grid.append(row)
            for it in range(res):
                for iu in range(res):
                    bm.faces.new((grid[it][iu], grid[it][iu + 1], grid[it + 1][iu + 1], grid[it + 1][iu]))
    bm.normal_update()
    obj = common.mesh_object(name, bm)
    poly = obj.data.polygons[0]
    if poly.normal.dot(normal) < 0:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bm.to_mesh(obj.data)
        bm.free()
    common.shade_smooth(obj, auto_angle=50)
    _vertex_colours(obj, colours)
    return obj


def revolve(profile, segments, shape=None, name="lathe"):
    """Lathe: profile [(r, z), ...] (going up the outside) around Z; a point
    with r = 0 closes a cap. shape(angle, z, r) -> r carves the surface."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r < 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        ring = []
        for i in range(segments):
            ang = math.tau * i / segments
            rr = shape(ang, z, r) if shape else r
            ring.append(bm.verts.new((math.cos(ang) * rr, math.sin(ang) * rr, z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        r0, r1 = rings[k], rings[k + 1]
        for i in range(segments):
            j = (i + 1) % segments
            if len(r0) == 1:
                bm.faces.new((r0[0], r1[j], r1[i]))
            elif len(r1) == 1:
                bm.faces.new((r0[i], r0[j], r1[0]))
            else:
                bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    obj = common.mesh_object(name, bm)
    common.shade_smooth(obj, auto_angle=50)
    return obj


def low_disc(radius, z, segments=16):
    """An up-facing fan: the low twin of disc() for bake_prop_lows."""
    return revolve([(radius, z), (0.0, z)], segments, name="low_disc")


def disc(radius, z, step=0.02, name="disc"):
    """A flat, dense round disc facing up."""
    bm = bmesh.new()
    n = max(4, int(radius * 2 / step))
    bmesh.ops.create_grid(bm, x_segments=n, y_segments=n, size=radius * 1.02)
    for v in bm.verts:
        r = Vector((v.co.x, v.co.y)).length
        if r > radius:
            v.co.x *= radius / r
            v.co.y *= radius / r
        v.co.z = z
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=step * 0.25)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges[:], dist=1e-5)
    obj = common.mesh_object(name, bm)
    common.shade_smooth(obj)
    return obj


# --- Props -------------------------------------------------------------------

def campfire():
    """Ring of stones, a bark-log teepee charred at the tips, an ash bed
    with embers and charcoal."""
    common.reset(3)
    rng = random.Random(3)
    parts = []
    # M8: rounded grey cobbles of mixed sizes (were pale, chiselled boulders
    # that the budget turned into angular facets).
    count = 14
    for i in range(count):
        a = i / count * math.tau + rng.uniform(-0.06, 0.06)
        big = 1.0 if i % 3 else 1.18
        size = (rng.uniform(0.38, 0.46) * big, rng.uniform(0.3, 0.36) * big, rng.uniform(0.24, 0.3) * big)
        r = 0.88 + rng.uniform(-0.03, 0.04)
        s = stone(size, location=(math.cos(a) * r, math.sin(a) * r, -0.02), rotation=(0, 0, a + rng.uniform(-0.3, 0.3)),
                  seed=200 + i, base=COBBLE, light=COBBLE_LIGHT, dark=COBBLE_DARK, moss=0.25 if i % 4 == 1 else 0.0)
        _apply(s)

        def soot(p, n, a=a):
            inward = -(n.x * math.cos(a) + n.y * math.sin(a))
            low = 1.0 - p.z / 0.4
            return _clamp(inward * 1.4 - 0.2) * _clamp(low) * 0.8 + _clamp(noise.noise(p * 9.0 + Vector((i, 0, 0))) - 0.35) * 0.6
        common.grime(s, (0.17, 0.13, 0.11), soot)
        parts.append(s)
    for i in range(6):
        a = i / 6 * math.tau + 0.3
        lg = detail.bark_log(0.95, 0.11, seed=i + 2, segments=48, groove=0.14)
        lg.rotation_euler = (0, math.radians(-55), a + math.pi)
        lg.location = (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.36)
        _apply(lg)
        common.grime(lg, WOOD, lambda p, n: 0.25)

        def char(p, n):
            inner = (0.12 - Vector((p.x, p.y)).length) / 0.06
            top = (p.z - 0.6) / 0.08
            ragged = noise.noise(p * 14.0) * 0.6
            return _clamp(max(inner, top) + ragged)
        common.grime(lg, CHAR, char)
        common.grime(lg, (0.45, 0.42, 0.4), lambda p, n: _clamp(noise.noise(p * 22.0) * 3 - 0.6) *
                     _clamp(((p.z - 0.6) / 0.1)) * 0.6)
        parts.append(lg)
    # Ash bed: a low mound of grey ash, black charcoal and glowing embers.
    bed = disc(0.62, 0.0, step=0.02, name="ash")
    for v in bed.data.vertices:
        r = Vector((v.co.x, v.co.y)).length / 0.62
        v.co.z = 0.012 + 0.05 * (1 - r * r) + noise.noise(v.co * 9.0) * 0.008

    def ash(p, n):
        r = Vector((p.x, p.y)).length
        g = noise.noise(p * 7.0)
        c = common.lerp(CHAR, CHAR_GREY, _clamp(0.5 + g))
        fine = noise.noise(p * 20.0 + Vector((5, 0, 0)))
        if fine > 0.3:
            c = common.lerp(c, (0.62, 0.58, 0.55), 0.5)
        if r < 0.32 and noise.noise(p * 16.0 + Vector((0, 9, 0))) > 0.12:
            c = common.lerp(c, EMBER, _clamp((0.32 - r) / 0.12))
        return c
    common.color_by(bed, ash, smooth=True)
    low_bed = revolve([(0.62, 0.012), (0.35, 0.045), (0.0, 0.062)], 16, name="low_ash")
    for k in range(9):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.08, 0.4)
        chunk = stone((rng.uniform(0.07, 0.12), rng.uniform(0.05, 0.08), 0.04), seed=30 + k, subdiv=2,
                      base=CHAR, light=CHAR_GREY, dark=(0.05, 0.04, 0.04),
                      location=(math.cos(a) * r, math.sin(a) * r, 0.012), rotation=(0, 0, rng.uniform(0, 3)))
        if r < 0.28:
            common.grime(chunk, EMBER, lambda p, n: _clamp(noise.noise(p * 40.0) * 3 - 0.3) * 0.9)
        parts.append(chunk)
    detail.bake_prop_lows(parts, "campfire", budget=2800, lows=[low_bed], dense_only=[bed], size=1024, ray=0.08)


def _tri_grid(bm, a, b, c, n):
    """A triangle a-b-c split into n*n small triangles."""
    a, b, c = Vector(a), Vector(b), Vector(c)
    rows = []
    for j in range(n + 1):
        t = j / n
        p0, p1 = a.lerp(c, t), b.lerp(c, t)
        cnt = n - j
        rows.append([bm.verts.new(p0.lerp(p1, i / cnt) if cnt else p0) for i in range(cnt + 1)])
    for j in range(n):
        lo, hi = rows[j], rows[j + 1]
        for i in range(len(hi)):
            bm.faces.new((lo[i], lo[i + 1], hi[i]))
            if i + 1 < len(hi):
                bm.faces.new((lo[i + 1], hi[i + 1], hi[i]))


def _roll(length, radius, colour_fn, segments=36):
    """A dense cylinder along local X (rolled canvas, bedroll)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=length)
    side = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > length * 0.5]
    bmesh.ops.subdivide_edges(bm, edges=side, cuts=max(6, int(length / 0.025)), use_grid_fill=True)
    caps = [f for f in bm.faces if abs(f.normal.z) > 0.9]
    for cap in caps:
        region = [cap]
        for k in range(3):
            bmesh.ops.inset_region(bm, faces=region, thickness=radius * 0.25, depth=-radius * 0.04)
    for v in bm.verts:
        v.co.x *= 1.0 + noise.noise(v.co * 3.0) * 0.04
        v.co.y *= 1.0 + noise.noise(v.co * 3.0 + Vector((4, 0, 0))) * 0.04
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    obj = common.mesh_object("roll", bm)
    common.shade_smooth(obj, auto_angle=50)
    common.color_by(obj, colour_fn, smooth=True)
    return obj


def tent():
    """Cream A-frame tent: dense canvas with raised, stitched seams, a hem
    band and a patch; a front gable whose door panels are rolled back and
    tied along the doorway; a ground sheet, bedroll and pillow inside;
    crossed bark poles carrying a ridge pole; guy ropes to bark pegs."""
    common.reset(4)
    length, half_w, h, base = 2.2, 1.0, 1.55, 0.01
    door_w = 0.55  # half-width of the doorway at the ground
    front = -length / 2
    seam_x = [k / 1.8 for k in range(-1, 2)]

    def solid(bm, name):
        obj = common.mesh_object(name, bm)
        mod = obj.modifiers.new("Solidify", "SOLIDIFY")
        mod.thickness = 0.04
        common.apply_all_modifiers(obj)
        common.shade_smooth(obj, auto_angle=40)
        return obj

    def canvas_mesh(rows, cols, back, dense):
        bm = bmesh.new()
        grid = {}
        for side in (-1, 1):
            n_out = Vector((0, side * h, half_w)).normalized()
            for i in range(cols + 1):
                for j in range(rows + 1):
                    x = -length / 2 + length * i / cols
                    t = j / rows
                    y = side * half_w * t
                    z = h * (1 - t) + base
                    sag = math.sin(t * math.pi) * 0.08 * (1 - abs(x) / length)
                    flare = 0.05 * _clamp((t - 0.9) / 0.1)  # the hem kicks out onto the ground
                    p = Vector((x, y * (1 + sag * 0.5) + side * flare, z - sag))
                    if dense:
                        ds = min(abs(x - s) for s in seam_x)
                        raised = (0.008 * _clamp(1 - ds / 0.022) + 0.01 * _clamp((t - 0.9) / 0.02) +
                                  0.006 * _clamp((0.04 - t) / 0.02))
                        p += n_out * (raised + noise.noise(Vector((x * 3, t * 4, side))) * 0.012)
                    grid[(side, i, j)] = bm.verts.new(p)
        for side in (-1, 1):
            for i in range(cols):
                for j in range(rows):
                    quad = [grid[(side, i, j)], grid[(side, i + 1, j)], grid[(side, i + 1, j + 1)], grid[(side, i, j + 1)]]
                    if side < 0:
                        quad.reverse()
                    bm.faces.new(quad)
        _tri_grid(bm, (length / 2, -half_w, base), (length / 2, half_w, base), (length / 2, 0, h + base), back)
        return solid(bm, "canvas")

    def door_mesh(n):
        """The two front panels either side of a triangular doorway."""
        bm = bmesh.new()
        apex = (front, 0, h + base)
        for side in (-1, 1):
            a, b = (front, side * half_w, base), (front, side * door_w, base)
            _tri_grid(bm, *((b, a, apex) if side > 0 else (a, b, apex)), n)
        return solid(bm, "door")

    canvas, low_canvas = canvas_mesh(60, 110, 24, True), canvas_mesh(6, 8, 1, False)
    door, low_door = door_mesh(24), door_mesh(1)
    inside_centre = Vector((0, 0, h * 0.3))

    def canvas_colour(pos, normal):
        ds = min(abs(pos.x - s) for s in seam_x)
        side = 1 if pos.y > 0 else -1
        t = abs(pos.y) / half_w
        stain = noise.noise(Vector((pos.x * 1.5, pos.y * 1.5, pos.z * 3.0)))
        c = common.lerp(CANVAS, (0.98, 0.93, 0.8), _clamp(stain))
        c = common.lerp(c, CANVAS_SHADE, _clamp(-stain - 0.2) * 0.5)
        if normal.dot(pos - inside_centre) < 0:
            # The inside of the canvas: warm, shaded cloth seen through the door.
            return tuple(k * 0.5 for k in common.lerp(c, CANVAS_SHADE, 0.6))
        if ds < 0.02 and abs(pos.x) < length / 2 - 0.01:
            c = common.lerp(c, CANVAS_SHADE, 0.6)
        elif ds < 0.045 and abs(pos.x) < length / 2 - 0.01 and int(pos.z * 30) % 2 == 0:
            c = common.lerp(c, (0.55, 0.42, 0.3), 0.55)  # running stitches
        if side > 0 and 0.25 < pos.x < 0.62 and 0.36 < t < 0.6 and abs(pos.x) < length / 2 - 0.01:
            c = common.lerp(c, (0.84, 0.66, 0.46), 0.6)  # a sewn-on patch
            if min(pos.x - 0.25, 0.62 - pos.x) < 0.025 or min(t - 0.36, 0.6 - t) < 0.02:
                if int((pos.x + pos.z) * 32) % 2 == 0:
                    c = common.lerp(c, (0.45, 0.32, 0.22), 0.6)
        if pos.x < front + 0.05 and abs(abs(pos.y) - door_w * (1 - (pos.z - base) / h)) < 0.03:
            c = common.lerp(c, CANVAS_SHADE, 0.6)  # hemmed door edge
        if pos.z < 0.32:
            c = common.lerp(c, CANVAS_SHADE, 0.55 + 0.25 * _clamp((0.2 - pos.z) / 0.15))
            if pos.z < 0.18:
                c = common.lerp(c, EARTH, _clamp((0.18 - pos.z) / 0.12) * 0.4)
        return c
    common.color_by(canvas, canvas_colour, smooth=True)
    common.color_by(door, canvas_colour, smooth=True)
    parts = []

    def flap_colour(pos, normal):
        a = math.atan2(pos.z, pos.y)
        spiral = (a / math.tau + Vector((pos.y, pos.z)).length * 12.0) % 1.0
        c = common.lerp(CANVAS, CANVAS_SHADE, 0.45)
        if abs(normal.x) > 0.8 and spiral < 0.25:
            c = common.lerp(c, (0.6, 0.48, 0.34), 0.6)
        return common.lerp(c, CANVAS_SHADE, _clamp(noise.noise(pos * 6.0)) * 0.4)
    # Thin parts get hand-made low twins (collapse decimation tears them).
    dense, lows = [canvas, door], [low_canvas, low_door]
    for side in (-1, 1):
        # The door panel rolled back and tied along the doorway edge.
        top = Vector((front - 0.06, side * 0.08, h - 0.08))
        foot = Vector((front - 0.06, side * door_w * 0.96, 0.12))
        run = foot - top
        rot = Vector((1, 0, 0)).rotation_difference(run.normalized()).to_euler()
        loc = tuple(top.lerp(foot, 0.5))
        roll = _roll(run.length, 0.065, flap_colour)
        ties = [rope_loop(0.075, 0.013, location=(x, 0, 0), rotation=(0, math.radians(90), 0))
                for x in (-run.length * 0.25, run.length * 0.25)]
        roll = common.join([roll] + ties, "flap")
        place(roll, loc, rot)
        dense.append(roll)
        lows.append(low_log(run.length, 0.07, location=loc, rotation=rot, segments=8))
    sheet = block((length - 0.16, half_w * 1.7, 0.012), location=(0, 0, 0.006), bevel=0.004)
    common.set_color(sheet, (0.42, 0.36, 0.24))
    parts.append(sheet)

    def blanket(pos, normal):
        check = (int((pos.x + 1) * 9) + int((math.atan2(pos.z, pos.y) + 4) * 2.5)) % 2
        c = (0.36, 0.42, 0.62) if check else (0.3, 0.35, 0.54)
        if abs(pos.x) % 0.3 < 0.03:
            c = (0.78, 0.7, 0.5)
        return c
    bedroll = _roll(0.9, 0.16, blanket)
    straps = [rope_loop(0.165, 0.016, location=(x, 0, 0), rotation=(0, math.radians(90), 0), strands=0,
                        base=(0.42, 0.26, 0.16)) for x in (-0.25, 0.25)]
    bedroll = common.join([bedroll] + straps, "bedroll")
    place(bedroll, (-length / 2 + 0.6, 0.15, 0.2), (0, 0, math.pi / 2))
    dense.append(bedroll)
    lows.append(low_log(0.9, 0.165, rotation=(0, 0, math.pi / 2), location=(-length / 2 + 0.6, 0.15, 0.2),
                        segments=10))
    for step in (0.02, 0.09):
        pillow = dense_box((0.36, 0.5, 0.14), bevel=0.06, step=step)
        for v in pillow.data.vertices:
            puff = (1 - (v.co.x / 0.18) ** 2) * (1 - (v.co.y / 0.25) ** 2)
            v.co.z *= 0.7 + 0.5 * _clamp(puff)
        common.color_by(pillow, lambda p, n: (0.5, 0.28, 0.38) if abs(p.z) < 0.006 else
                        common.lerp((0.62, 0.36, 0.48), (0.72, 0.46, 0.56), _clamp(n.z)), smooth=True)
        pillow.location = (-length / 2 + 0.6, -0.38, 0.12)
        (dense if step < 0.05 else lows).append(pillow)
    # Crossed poles on each gable, meeting just above the ridge, carry a
    # ridge pole; a guy rope runs from the back crossing out to a peg (none
    # at the front, where it would cross the doorway).
    pole_r, lean = 0.05, math.radians(30)
    cross_z = h + base + 0.03
    foot_y = cross_z * math.tan(lean)
    pole_len = cross_z / math.cos(lean) + 0.32
    for x in (front - 0.05, length / 2 + 0.05):
        for side in (-1, 1):
            loc, tilt, seed = (x, side * foot_y, 0), (side * lean, 0), int(x * 10) + side
            dense.append(bark_stake(pole_len, pole_r, location=loc, tilt=tilt, seed=seed + 20, segments=24))
            lows.append(low_stake(pole_len, pole_r + 0.002, location=loc, tilt=tilt))
        if x < 0:
            continue
        peg = (x + 0.75, 0, 0)
        dense.append(bark_stake(0.28, 0.035, location=peg, seed=57, segments=20))
        lows.append(low_stake(0.28, 0.037, location=peg))
        a = Vector((x, 0, cross_z + 0.02))
        b = Vector((peg[0], 0, 0.26))
        mid = a.lerp(b, 0.5) - Vector((0, 0, 0.05))
        dense.append(rope_tube([a, mid, b], 0.011, seg=8))
        lows.append(rope_tube([a, mid, b], 0.012, strands=0, seg=4, spacing=0.08))
    ridge_z = h + base + 0.08  # resting on the canvas ridge, in the crossings
    ridge_len = length + 0.34
    ridge_loc, ridge_tilt = (-ridge_len / 2, 0, ridge_z), (0, math.pi / 2)
    dense.append(bark_stake(ridge_len, 0.042, location=ridge_loc, tilt=ridge_tilt, seed=61, segments=24, point=0.6))
    lows.append(low_stake(ridge_len, 0.044, location=ridge_loc, tilt=ridge_tilt, point=0.6))
    for sx in (-1, 1):
        for sy in (-1, 1):
            loc = (sx * length * 0.42, sy * (half_w + 0.35), 0)
            dense.append(bark_stake(0.28, 0.035, location=loc, seed=sx * 3 + sy + 40, segments=20))
            lows.append(low_stake(0.28, 0.037, location=loc))
            a = Vector((sx * length * 0.42, sy * half_w * 0.86, h * 0.14 + base + 0.01))
            b = Vector((sx * length * 0.42, sy * (half_w + 0.33), 0.3))
            mid = a.lerp(b, 0.5) - Vector((0, 0, 0.025))
            dense.append(rope_tube([a, mid, b], 0.011, seg=8))
            lows.append(rope_tube([a, mid, b], 0.012, strands=0, seg=4, spacing=0.08))
    detail.bake_prop_lows(parts, "tent", budget=1700, lows=lows, dense_only=dense, size=1024, ray=0.05,
                          edge_strength=0.25)


def fence():
    common.reset(5)
    rng = random.Random(5)
    parts = []
    count = 6
    span = 1.7
    for i in range(count):
        x = -span / 2 + span * i / (count - 1)
        h = 0.9 + (0.08 if i % 2 else 0.0) + rng.uniform(-0.03, 0.03)
        parts.append(bark_stake(h, 0.1, location=(x, 0, 0), tilt=(rng.uniform(-0.04, 0.04), rng.uniform(-0.05, 0.05)),
                                seed=i + 11))
    for z in (0.35, 0.8):
        rail = board((span + 0.15, 0.07, 0.1), location=(0, -0.1, z), rotation=(0, rng.uniform(-0.04, 0.04), 0),
                     seed=int(z * 10), warp=0.008, step=0.02)
        parts.append(rail)
        for i in range(count):
            x = -span / 2 + span * i / (count - 1)
            for dx in (-0.024, 0.024):
                parts.append(rope_loop(0.13, 0.02, (x + dx, -0.02, z), rotation=(rng.uniform(-0.1, 0.1), math.radians(90), 0),
                                       squash=0.92))
    detail.bake_prop(parts, "fence", budget=1500, size=512, preview_elevation=25, ray=0.03)


def watch_post():
    common.reset(6)
    parts = []
    w = 0.7
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = detail.bark_log(2.3, 0.08, location=(sx * w, sy * w, 1.15), seed=sx + sy * 2 + 5, segments=40)
            leg.rotation_euler = (sy * 0.06, math.radians(-90) + sx * 0.06, 0)
            parts.append(leg)
    # Deck: planks on two joists, nailed down.
    for x in (-0.6, 0.6):
        parts.append(board((0.1, 1.7, 0.08), location=(x, 0, 1.52), seed=int(x * 10) + 30, base=WOOD_DARK, light=WOOD))
    n = 7
    for k in range(n):
        y = -0.85 + (k + 0.5) * 1.7 / n
        parts.append(board((1.7 + (k % 2) * 0.05, 1.7 / n - 0.012, 0.06), location=(0.02 * (k % 3 - 1), y, 1.585),
                           seed=k + 3, warp=0.006))
        for x in (-0.6, 0.6):
            for dy in (-0.06, 0.06):
                parts.append(nail((x, y + dy, 1.617), (0, 0, 1), radius=0.012))
    # Railing: along X on the front and back, along Y on the sides.
    for k, (loc, rot) in enumerate((((0, 0.82, 2.1), 0), ((0, -0.82, 2.1), 0),
                                    ((0.82, 0, 2.1), math.pi / 2), ((-0.82, 0, 2.1), math.pi / 2))):
        parts.append(board((1.7, 0.07, 0.08), location=loc, rotation=(0, 0, rot), seed=k + 50))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(detail.bark_log(1.3, 0.05, rotation=(0, math.radians(-90), 0), location=(sx * 0.8, sy * 0.8, 2.25),
                                         seed=7 + sx + sy * 3, segments=28))
            parts.append(rope_loop(0.065, 0.014, (sx * 0.8, sy * 0.8, 2.1)))
    # Pyramid roof, covered in staggered courses of shingles.
    bm = bmesh.new()
    r = 1.3
    base_z = 2.85
    apex_z = base_z + 0.95
    corners = [bm.verts.new((sx * r, sy * r, base_z)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    apex = bm.verts.new((0, 0, apex_z))
    for i in range(4):
        bm.faces.new((corners[i], corners[(i + 1) % 4], apex))
    bm.faces.new(list(reversed(corners)))
    roof = common.mesh_object("roof", bm)
    solid = roof.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.1
    common.apply_all_modifiers(roof)
    bm = bmesh.new()
    bm.from_mesh(roof.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=12, use_grid_fill=True)
    bm.to_mesh(roof.data)
    bm.free()
    common.shade_smooth(roof, auto_angle=30)
    common.color_by(roof, lambda p, nrm: ROOF if nrm.z > -0.3 else common.lerp(WOOD_DARK, WOOD, _clamp(
        0.5 + noise.noise(p * Vector((2, 2, 30))))), smooth=True)
    parts.append(roof)
    pts = [(-r, -r), (r, -r), (r, r), (-r, r)]
    for i in range(4):
        a = Vector((*pts[i], base_z))
        b = Vector((*pts[(i + 1) % 4], base_z))
        top = Vector((0, 0, apex_z))
        nrm = (b - a).cross(top - a).normalized()
        a2 = a + (a - top).normalized() * 0.06
        b2 = b + (b - top).normalized() * 0.06
        parts.append(shingles((a2, b2, top, top), rows=8, cols=11, normal=nrm, lift=0.035, gap=0.014, seed=i + 60,
                              round_tabs=0.0, res=4))
    for k, (sy, sx) in enumerate(((-0.22, None), (0.22, None))):
        parts.append(detail.bark_log(1.8, 0.04, rotation=(0, math.radians(-72), 0), location=(-1.05, sy, 0.85),
                                     seed=9 + k, segments=24))
    for k in range(5):
        z = 0.25 + k * 0.3
        parts.append(detail.bark_log(0.5, 0.03, rotation=(0, 0, math.pi / 2), location=(-1.2 + z * 0.3, 0, z),
                                     seed=k + 70, segments=20))
    detail.bake_prop(parts, "watch_post", budget=1500, size=1024, preview_elevation=25, ray=0.05)


def torch():
    """Bark shaft, a rope-wrapped grip, an iron cup heaped with coals."""
    common.reset(7)
    parts = [detail.bark_log(1.0, 0.05, rotation=(0, math.radians(-90), 0), location=(0, 0, 0.5), taper=1.2, seed=1,
                             segments=32, groove=0.1)]
    common.grime(parts[0], (0.56, 0.36, 0.22), lambda p, n: 0.35)
    parts.append(rope_tube(helix(0.066, 0.79, 0.93, 5.5), 0.016, base=(0.82, 0.7, 0.52)))
    for k, z in enumerate((0.78, 0.945)):
        parts.append(rope_loop(0.068, 0.022, (0, 0, z), base=(0.66, 0.52, 0.38)))
    z0, z1 = 0.97, 1.11

    def cup_shape(a, z, r):
        return r * (1.0 + 0.012 * math.cos(a * 8))
    cup = revolve([(0.0, z0), (0.07, z0), (0.1, z0 + 0.04), (0.125, z0 + 0.08), (0.15, z1 - 0.012), (0.155, z1),
                   (0.135, z1 + 0.004), (0.13, z1 - 0.02)], 40, shape=cup_shape, name="cup")

    def iron(p, n):
        a = math.atan2(p.y, p.x)
        c = common.lerp((0.52, 0.54, 0.6), IRON, _clamp(0.5 + noise.noise(p * 30.0)))
        if abs(math.sin(a * 4)) < 0.12:
            c = common.lerp(c, IRON_DARK, 0.6)  # riveted straps
        if p.z < z0 + 0.03:
            c = common.lerp(c, RUST, 0.5)
        return c
    common.color_by(cup, iron, smooth=True)
    dense = [cup]
    lows = [revolve([(0.0, z0), (0.07, z0), (0.125, z0 + 0.08), (0.155, z1), (0.13, z1 + 0.002), (0.0, z1 + 0.002)], 16,
                    shape=cup_shape, name="low_cup")]
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 8
        rr = 0.142
        dense.append(nail((math.cos(a) * rr, math.sin(a) * rr, z1 - 0.025), (math.cos(a), math.sin(a), 0.3),
                          radius=0.011))
    bed = disc(0.13, z1 - 0.012, step=0.012, name="embers")

    def ember(p, n):
        g = noise.noise(p * 40.0)
        return common.lerp((1.0, 0.82, 0.3), (1.0, 0.5, 0.12), _clamp(0.5 + g))
    common.color_by(bed, ember, smooth=True)
    dense.append(bed)
    rng = random.Random(7)
    for k in range(7):
        a = k / 7 * math.tau + rng.uniform(-0.3, 0.3)
        r = 0.07 if k else 0.0
        coal = stone((0.075, 0.06, 0.045), seed=80 + k, subdiv=2, base=(0.18, 0.12, 0.1), light=(0.3, 0.2, 0.15),
                     dark=(0.08, 0.06, 0.05), location=(math.cos(a) * r, math.sin(a) * r, z1 - 0.042 + (0.01 if not k else 0)),
                     rotation=(0, 0, rng.uniform(0, 3)))
        common.grime(coal, EMBER, lambda p, n: _clamp(noise.noise(p * 45.0) * 3 - 0.2) * 0.95)
        dense.append(coal)
    detail.bake_prop_lows(parts, "torch", budget=900, lows=lows, dense_only=dense, size=512, preview_elevation=20,
                          ray=0.04)


def woodpile():
    common.reset(8)
    rng = random.Random(8)
    parts = []
    layers = [(3, 0.13), (2, 0.36), (1, 0.59)]
    for row, (count, z) in enumerate(layers):
        for i in range(count):
            y = (i - (count - 1) / 2) * 0.27
            parts.append(detail.bark_log(1.2 + rng.uniform(-0.1, 0.1), 0.13, location=(rng.uniform(-0.05, 0.05), y, z),
                                         rotation=(rng.uniform(0, 3), 0, rng.uniform(-0.04, 0.04)), seed=row * 3 + i + 1,
                                         taper=rng.uniform(0.86, 0.95), segments=72))
            common.grime(parts[-1], WOOD, lambda p, n: 0.22)
    detail.bake_prop(parts, "woodpile", budget=1200, size=512, ray=0.03)


def crate():
    """Plank crate: three boards a side, a planked lid, dark corner posts and
    rim boards, nail heads."""
    common.reset(9)
    rng = random.Random(9)
    core = block((0.74, 0.74, 0.62), location=(0, 0, 0.36), bevel=0.0)
    common.set_color(core, (0.16, 0.1, 0.07))
    parts = [core]
    for k, (nx, ny) in enumerate(((0, -1), (0, 1), (1, 0), (-1, 0))):
        for b in range(3):
            z = 0.11 + (b + 0.5) * 0.5 / 3
            along_x = nx == 0
            loc = (nx * 0.385, ny * 0.385, z)
            parts.append(board((0.66, 0.035, 0.155), location=loc, rotation=(0, 0, 0 if along_x else math.pi / 2),
                               seed=k * 3 + b + 1, warp=0.004))
    for z in (0.06, 0.66):
        for k, (dx, dy) in enumerate(((0, 0.37), (0, -0.37), (0.37, 0), (-0.37, 0))):
            along_x = dx == 0
            parts.append(board((0.84, 0.1, 0.1), location=(dx, dy, z), rotation=(0, 0, 0 if along_x else math.pi / 2),
                               seed=int(z * 10) + k + 20, base=WOOD_DARK, light=WOOD, bevel=0.018))
            for s in (-0.25, 0.0, 0.25):
                p = Vector((dx * 1.14 if not along_x else s, dy * 1.14 if along_x else s, z))
                parts.append(nail(p, (dx / 0.37 if dx else 0, dy / 0.37 if dy else 0, 0), radius=0.013))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(board((0.74, 0.1, 0.1), location=(sx * 0.37, sy * 0.37, 0.37), rotation=(0, math.radians(90), 0),
                               seed=sx * 2 + sy + 40, base=WOOD_DARK, light=WOOD, bevel=0.02))
    for k in range(4):
        y = -0.24 + k * 0.16
        parts.append(board((0.66, 0.15, 0.04), location=(rng.uniform(-0.01, 0.01), y, 0.675), seed=k + 60, warp=0.003))
    detail.bake_prop(parts, "crate", budget=1200, size=512, ray=0.03)


def barrel():
    """Bulging staved barrel: real stave joints, a chime rim over a planked
    head, riveted iron hoops."""
    common.reset(10)
    staves = 14
    rng = random.Random(10)
    offsets = [rng.uniform(-0.004, 0.004) for _ in range(staves)]

    def bulge(z):
        return 0.34 * (1.0 + 0.16 * (1 - ((z - 0.475) / 0.475) ** 2))

    def stave_shape(a, z, r):
        f = (a / math.tau * staves) % 1.0
        d = min(f, 1.0 - f)
        return r - 0.007 * _clamp(1 - d / 0.07) + offsets[int(a / math.tau * staves) % staves]
    top, rim = 0.95, 0.035
    profile = [(0.0, 0.0)] + [(bulge(top * k / 30), top * k / 30) for k in range(31)]
    profile += [(bulge(top) - rim, top), (bulge(top) - rim, top - 0.05)]
    body = revolve(profile, staves * 8, shape=stave_shape, name="barrel")

    def wood(p, n):
        a = math.atan2(p.y, p.x) % math.tau
        idx = int(a / math.tau * staves)
        f = (a / math.tau * staves) % 1.0
        tone = (idx * 0.618) % 1.0
        g = noise.noise(Vector((math.cos(a) * 6, math.sin(a) * 6, p.z * 2.0 + idx * 3)))
        g += noise.noise(Vector((f * 8.0 + idx * 5, idx, p.z * 1.2))) * 0.6
        c = common.lerp(WOOD, WOOD_LIGHT, _clamp(0.25 + tone * 0.4 + g * 0.35))
        if g < -0.4:
            c = common.lerp(c, WOOD_DARK, 0.5)
        if min(f, 1 - f) < 0.05:
            c = common.lerp(c, WOOD_DARK, 0.75)
        if p.z > top - 0.004 and n.z > 0.6:
            c = common.lerp(c, END_GRAIN, 0.5)
        if p.z < 0.08:
            c = common.lerp(c, EARTH, (0.08 - p.z) / 0.08 * 0.5)
        return c
    common.color_by(body, wood, smooth=True)
    parts = [body]
    head = disc(bulge(top) - rim + 0.01, top - 0.04, step=0.015, name="head")
    for v in head.data.vertices:
        f = (v.co.x / 0.11) % 1.0
        if min(f, 1 - f) < 0.07:
            v.co.z -= 0.006
    common.color_by(head, lambda p, n: common.lerp(WOOD_DARK, WOOD, 0.3) if min((p.x / 0.11) % 1.0, 1 - (p.x / 0.11) % 1.0) < 0.07
                    else wood_colour(int(p.x / 0.11) + 3, WOOD_LIGHT, (0.88, 0.68, 0.42), WOOD, along=1, knots=False)(p, n),
                    smooth=True)
    dense, lows = [head], [low_disc(bulge(top) - rim + 0.005, top - 0.04, 28)]
    for z in (0.06, 0.18, 0.77, 0.89):
        wide = z in (0.18, 0.77)
        hw = 0.035 if wide else 0.022
        z0, z1 = z - hw, z + hw
        hoop = revolve([(bulge(z0) - 0.006, z0), (bulge(z0) + 0.011, z0), (bulge(z) + 0.013, z), (bulge(z1) + 0.011, z1),
                        (bulge(z1) - 0.006, z1)], 112, name="hoop")
        common.color_by(hoop, lambda p, n: common.lerp(common.lerp(IRON, (0.5, 0.52, 0.58), _clamp(n.z + 0.3)), RUST,
                        _clamp(noise.noise(p * 25.0) * 2 - 0.3) * 0.6), smooth=True)
        parts.append(hoop)
        if wide:
            for k in range(6):
                a = k / 6 * math.tau + 0.2
                rr = bulge(z) + 0.014
                parts.append(nail((math.cos(a) * rr, math.sin(a) * rr, z), (math.cos(a), math.sin(a), 0), radius=0.013,
                                  colour=IRON_DARK))
    detail.bake_prop_lows(parts, "barrel", budget=1000, lows=lows, dense_only=dense, size=512, ray=0.03)


def toadstools():
    """Fly agarics: domed red caps with raised white warts, gilled
    undersides, fibrous stems with a skirt, a mossy foot."""
    common.reset(11)
    rng = random.Random(11)
    parts = []
    for i, (x, y, s) in enumerate([(0, 0, 1.0), (0.3, 0.15, 0.7), (-0.22, 0.25, 0.55)]):
        height = 0.32 * s
        rad = 0.07 * s
        stem = revolve([(0.0, 0.0), (rad * 1.35, 0.0), (rad * 1.15, height * 0.12)] +
                       [(rad * (1.0 - 0.18 * k / 8), height * (0.12 + 0.88 * k / 8)) for k in range(1, 9)] +
                       [(0.0, height * 1.0)], 32,
                       shape=lambda a, z, r, s=s: r * (1 + 0.04 * math.sin(a * 9 + z * 40)), name="stem")
        common.color_by(stem, lambda p, n, s=s: common.lerp((0.96, 0.92, 0.84), (0.82, 0.74, 0.62),
                        _clamp(noise.noise(Vector((p.x * 60 / s, p.y * 60 / s, p.z * 6))) * 0.8 + 0.2 -
                               p.z / (0.32 * s))), smooth=True)
        stem.location = (x, y, 0)
        parts.append(stem)
        skirt = revolve([(rad * 0.95, height * 0.78), (rad * 1.6, height * 0.66), (rad * 1.5, height * 0.62),
                         (rad * 0.95, height * 0.72)], 32, shape=lambda a, z, r: r * (1 + 0.08 * math.sin(a * 7)),
                        name="skirt")
        common.set_color(skirt, (0.97, 0.94, 0.86))
        skirt.location = (x, y, 0)
        parts.append(skirt)
        # Cap: a dense dome with real warts and radial gills below.
        cap_r = 0.22 * s
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=128, v_segments=56, radius=cap_r)
        warts = []
        while len(warts) < int(14 + 8 * s):
            d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.0, 1.0))).normalized()
            wr = rng.uniform(0.09, 0.15)
            if all(d.angle(o) > (wr + r2) * 1.3 for o, r2 in warts):
                warts.append((d, wr))
        for v in bm.verts:
            d = v.co.normalized()
            if v.co.z < 0:
                a = math.atan2(v.co.y, v.co.x)
                v.co.z *= 0.25
                ring = Vector((v.co.x, v.co.y)).length / cap_r
                if 0.3 < ring < 0.95:
                    v.co.z += abs(math.sin(a * 40)) * 0.006 * s
            else:
                bump = 0.0
                for wd, wr in warts:
                    ang = d.angle(wd)
                    if ang < wr:
                        bump = max(bump, (1 - (ang / wr) ** 2) ** 0.5)
                v.co *= 1.0 + bump * 0.045
            v.co.z *= 0.8
        bmesh.ops.translate(bm, verts=bm.verts, vec=(x, y, 0.32 * s))
        cap = common.mesh_object("cap", bm)
        common.shade_smooth(cap)
        centre = Vector((x, y, 0.32 * s))

        def colour(pos, normal, centre=centre, warts=warts, cap_r=cap_r):
            local = pos - centre
            if local.z < -0.002:
                a = math.atan2(local.y, local.x)
                ring = Vector((local.x, local.y)).length / cap_r
                gill = abs(math.sin(a * 40))
                c = common.lerp((0.86, 0.76, 0.62), (0.97, 0.9, 0.78), gill)
                return common.lerp(c, (0.88, 0.14, 0.12), _clamp((ring - 0.93) * 12))
            d = Vector((local.x, local.y, local.z / 0.8)).normalized()
            for wd, wr in warts:
                if d.angle(wd) < wr * 0.85:
                    return common.lerp((1.0, 0.96, 0.9), (0.9, 0.86, 0.78), _clamp(noise.noise(pos * 120.0)))
            up = _clamp(local.z / (cap_r * 0.8))
            c = common.lerp((0.97, 0.26, 0.15), (0.8, 0.12, 0.1), up)
            return common.lerp(c, (0.98, 0.42, 0.2), _clamp(noise.noise(pos * 25.0) - 0.3) * 0.4)
        common.color_by(cap, colour, smooth=True)
        parts.append(cap)
    detail.bake_prop(parts, "toadstools", budget=900, size=512, ray=0.02, edge_strength=0.2)


def hammer():
    """Feature 045: a kid-sized wooden mallet the heroes hold while they
    build. The grip sits at the origin with the handle up local Z (glTF +Y);
    the barrel head runs along X with iron bands at both faces."""
    common.reset(11)
    handle = revolve([(0.0, -0.07), (0.019, -0.07), (0.021, -0.055), (0.018, 0.02), (0.016, 0.2), (0.019, 0.27),
                      (0.0, 0.27)], 24, shape=lambda a, z, r: r * (1 + 0.04 * math.sin(a * 3 + z * 20)), name="handle")
    common.color_by(handle, wood_colour(3, base=WOOD_LIGHT, light=END_GRAIN, along=2, knots=False), smooth=True)
    parts = [handle]
    parts.append(rope_tube(helix(0.022, -0.045, 0.06, 6.5), 0.007, strands=0, base=(0.72, 0.28, 0.2), seg=8))
    head_z, half = 0.31, 0.085

    def barrel(a, z, r):
        return r * (1 + 0.02 * math.cos(a * 9))
    head = revolve([(0.0, -half), (0.05, -half), (0.056, -half + 0.012), (0.06, 0.0), (0.056, half - 0.012),
                    (0.05, half), (0.0, half)], 40, shape=barrel, name="head")
    common.color_by(head, wood_colour(8, along=2), smooth=True)
    head.rotation_euler = (0, math.radians(90), 0)
    head.location = (0, 0, head_z)
    parts.append(head)
    for end in (-1, 1):
        band = revolve([(0.058, -0.012), (0.061, -0.01), (0.061, 0.01), (0.058, 0.012)], 40, name="band")
        common.color_by(band, lambda p, n: common.lerp(IRON, (0.55, 0.56, 0.62), _clamp(0.5 + noise.noise(p * 40.0))),
                        smooth=True)
        band.rotation_euler = (0, math.radians(90), 0)
        band.location = (end * (half - 0.022), 0, head_z)
        parts.append(band)
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            n = Vector((0, math.cos(a), math.sin(a)))
            parts.append(nail(Vector((end * (half - 0.022), 0, head_z)) + n * 0.062, n, radius=0.008))
    detail.bake_prop(parts, "hammer", budget=500, size=256, ray=0.01, edge_strength=0.3, preview_elevation=20)


PROPS = {
    "campfire": campfire, "tent": tent, "fence": fence, "watch_post": watch_post, "torch": torch,
    "woodpile": woodpile, "crate": crate, "barrel": barrel, "toadstools": toadstools,
    "hammer": hammer,
}

if __name__ == "__main__":
    for name in (sys.argv[1:] or PROPS.keys()):
        random.seed(hash(name) & 0xFFFF)
        PROPS[name]()
