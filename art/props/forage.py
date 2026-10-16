"""Feature 017 props, in the same chunky painted style as camp.py:

- clay_pit / clay_pit_dug:     a mound of orange river clay with a spade
- mushrooms / mushrooms_picked: a mossy patch of brown forest mushrooms
- junk_pile / junk_pile_picked: an old camper's junk (crate, cans, wheel)
- snap_trap_base / snap_trap_jaw: a wooden snap trap (jaws animate in Godot)
- glow_lantern:                a stone-footed post with a caged glow crystal
- glow_shard:                  a small glowing crystal (imp drop pickup)
- hearth_ring:                 clay bricks around the campfire (Stone Hearth)

Run: python art/props/forage.py [prop ...]"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

from lib import common, detail, paint_bake, preview  # noqa: E402
from nature.rocks import boulder  # noqa: E402
from props.camp import (BARK as BARK_COL, END_GRAIN as END_GRAIN_COL, IRON, WOOD, WOOD_DARK, WOOD_LIGHT, block, colour_wood, log, rope_ring,  # noqa: E402
                        stake)

CLAY = (0.78, 0.42, 0.24)
CLAY_LIGHT = (0.9, 0.58, 0.36)
CLAY_WET = (0.5, 0.26, 0.16)
MOSS = (0.35, 0.55, 0.2)
MOSS_LIGHT = (0.55, 0.72, 0.28)
CAP = (0.55, 0.32, 0.18)
CAP_LIGHT = (0.74, 0.5, 0.28)
STEM = (0.96, 0.92, 0.8)
TIN = (0.62, 0.66, 0.7)
RUST = (0.62, 0.34, 0.2)
LABEL = (0.82, 0.24, 0.2)
GLOW = (0.45, 0.95, 1.0)
GLOW_DEEP = (0.55, 0.45, 1.0)


def finish_prop(parts, name, size=512, preview_elevation=35, budget=1400, **paint):
    """camp.finish_prop plus decimation to the prop triangle budget."""
    obj = common.join(parts, name)
    _decimate_to(obj, budget)
    params = dict(ao_distance=0.25, ao_strength=0.7, edge_strength=0.45, edge_radius=0.02, noise_scale=6.0)
    params.update(paint)
    paint_bake.paint(obj, size=size, **params)
    common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), [obj])
    print(name, "tris:", common.triangle_count([obj]))
    preview.render([obj], name, elevation=preview_elevation)
    return obj


def _decimate_to(obj, budget):
    tris = common.triangle_count([obj])
    if tris > budget:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = budget / tris
        common.apply_all_modifiers(obj)



# --- Dense detail helpers (feature 031 M6 detail pass) ----------------------

def densify(obj, density, max_cuts=20):
    """Subdivides edges longer than `density` (twice), so per-vertex
    colour and displacement noise have vertices to land on."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for _ in range(3):
        long_edges = [e for e in bm.edges if e.calc_length() > density * 1.5]
        if not long_edges:
            break
        longest = max(e.calc_length() for e in long_edges)
        bmesh.ops.subdivide_edges(bm, edges=long_edges, cuts=max(1, min(max_cuts, int(longest / density))),
                                  use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def displace(obj, fn):
    """Moves each vertex along its normal by fn(position, normal)."""
    mesh = obj.data
    # Read all normals first: writing a vertex marks normals dirty, and
    # reading one then recomputes them all (quadratic).
    data = [(v.co.copy(), v.normal.copy()) for v in mesh.vertices]
    flat = []
    for co, nrm in data:
        flat.extend(co + nrm * fn(co, nrm))
    mesh.vertices.foreach_set("co", flat)
    mesh.update()
    return obj


def dense_block(size, location=(0, 0, 0), rotation=(0, 0, 0), bevel=0.02, density=0.02, colour=None, dent=0.0,
                seed=0, smooth=True, warp=0.0):
    """A bevelled box, densified, with optional hammered dents, warp and
    a colour function."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    obj = common.mesh_object("dblock", bm)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = min(bevel, min(size) * 0.45)
        mod.segments = 2
        common.apply_all_modifiers(obj)
    densify(obj, density)
    if warp:
        for v in obj.data.vertices:
            v.co += Vector((noise.noise(v.co * 3 + Vector((seed, 0, 0))), noise.noise(v.co * 3 + Vector((0, seed, 0))),
                            noise.noise(v.co * 3 + Vector((0, 0, seed))) * 0.5)) * warp
    if dent:
        displace(obj, lambda p, n: -max(0.0, noise.noise(p * 14.0 + Vector((seed, seed, 0)))) * dent)
    common.shade_smooth(obj, auto_angle=40)
    if colour:
        common.color_by(obj, colour, smooth=smooth)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def iron_colour(seed=0, base=IRON, rust=0.35):
    """Hammered iron: mottled dark metal, rust blooms low and in the
    hollows, lighter worn crests."""
    light = common.lerp(base, (0.62, 0.64, 0.68), 0.55)
    dark = common.lerp(base, (0.08, 0.08, 0.1), 0.5)

    def colour(pos, normal):
        n = noise.noise(pos * 9.0 + Vector((seed, 0, 0))) + noise.noise(pos * 30.0) * 0.25
        c = common.lerp(dark, light, max(0.0, min(1.0, 0.4 + n * 0.35)))
        r = noise.noise(pos * 7.0 + Vector((0, seed, 3))) + noise.noise(pos * 31.0) * 0.3
        if r > 0.55 - rust:
            c = common.lerp(c, RUST, min(1.0, (r - 0.55 + rust) * 2.5) * 0.85)
        return c
    return colour


def rivets(points, radius=0.012, colour=IRON, seed=0):
    """Domed nail/rivet heads at `points` (facing +Z unless (point, normal))."""
    parts = []
    for i, pt in enumerate(points):
        loc, nrm = (pt if isinstance(pt[0], (tuple, list, Vector)) else (pt, (0, 0, 1)))
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=radius)
        for v in bm.verts:
            v.co.z = max(v.co.z, -radius * 0.2) * 0.6
        obj = common.mesh_object("rivet", bm)
        common.shade_smooth(obj)
        light = common.lerp(colour, (0.75, 0.75, 0.78), 0.45)
        common.color_by(obj, lambda p, n: common.lerp(colour, light, max(0.0, n.z)), smooth=True)
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(nrm).normalized())
        obj.location = loc
        common.apply_transform(obj)
        common.select_only([obj])
        bpy.ops.object.transform_apply(location=True)
        parts.append(obj)
    return common.join(parts, "rivets") if parts else None


def torus(major, minor, location=(0, 0, 0), rotation=(0, 0, 0), segments=64, tube=12, offset=None, colour=None):
    """A dense ring around local Z; offset(u, v) scales the tube radius
    (u around the ring, v around the tube, both 0..tau)."""
    bm = bmesh.new()
    rows = []
    for i in range(segments):
        u = i / segments * math.tau
        row = []
        for j in range(tube):
            w = j / tube * math.tau
            r = minor * (offset(u, w) if offset else 1.0)
            rr = major + math.cos(w) * r
            row.append(bm.verts.new((math.cos(u) * rr, math.sin(u) * rr, math.sin(w) * r)))
        rows.append(row)
    for i in range(segments):
        a, b = rows[i], rows[(i + 1) % segments]
        for j in range(tube):
            bm.faces.new((a[j], b[j], b[(j + 1) % tube], a[(j + 1) % tube]))
    bm.normal_update()
    obj = common.mesh_object("torus", bm)
    common.shade_smooth(obj)
    if colour:
        common.color_by(obj, colour, smooth=True)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


ROPE = (0.86, 0.74, 0.5)
ROPE_DARK = (0.52, 0.4, 0.24)


def twisted_rope(major, minor, location=(0, 0, 0), rotation=(0, 0, 0), strands=3, twist=None, segments=72):
    """A lashing of twisted rope: helical strand ridges with dark seams."""
    twist = twist or max(6, int(major * math.tau / (minor * 1.6)))

    def strand(u, w):
        return 1.0 - 0.22 * (1.0 - abs(math.cos((w * strands + u * twist) * 0.5)))
    ring = torus(major, minor, segments=segments, tube=12, offset=strand)

    def colour(pos, normal):
        r_major = Vector((pos.x, pos.y)).length
        d = Vector((r_major - major, pos.z)).length
        t = max(0.0, min(1.0, (d / minor - 0.78) / 0.22))
        fleck = noise.noise(pos * 60.0) * 0.5 + 0.5
        return common.lerp(ROPE_DARK, common.lerp(ROPE, (0.94, 0.86, 0.64), fleck * 0.4), t)
    common.color_by(ring, colour, smooth=True)
    ring.rotation_euler = rotation
    ring.location = location
    return ring


def dense_cylinder(radius, depth, location=(0, 0, 0), rotation=(0, 0, 0), segments=32, radius2=None, rings=None,
                   colour=None, bevel=0.0, cap=True):
    """A cylinder along local Z centred on the origin, with ring loops."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, segments=segments, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=depth)
    side = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > depth * 0.5]
    rings = rings if rings is not None else max(2, int(depth / (radius * math.tau / segments)))
    bmesh.ops.subdivide_edges(bm, edges=side, cuts=rings, use_grid_fill=True)
    obj = common.mesh_object("cyl", bm)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        common.apply_all_modifiers(obj)
    common.shade_smooth(obj, auto_angle=50)
    if colour:
        common.color_by(obj, colour, smooth=True)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def board(size, location=(0, 0, 0), rotation=(0, 0, 0), seed=0, base=WOOD, light=WOOD_LIGHT, dark=WOOD_DARK,
          bevel=0.012, density=0.008, knots=True, warp=0.0, seams=0, nails=()):
    """detail.plank's look with a controlled density (plank() re-cuts
    every pass, so small densities explode): grain along local X, knots,
    lighter worn edges. `seams` carves that many plank joints along Y on
    the top face; `nails` = local (x, y) nail spots on the top, dark-ringed."""
    obj = dense_block(size, bevel=bevel, density=density, warp=warp, seed=seed)
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    seam_ys = [-hy + size[1] * (k + 1) / (seams + 1) for k in range(seams)]
    for v in obj.data.vertices:
        v.co.z += noise.noise(Vector((v.co.x * 1.5, seed, 0))) * size[2] * 0.08
        for sy in seam_ys:
            if abs(v.co.y - sy) < density * 0.7 and v.co.z > hz * 0.5:
                v.co.z -= min(0.006, size[2] * 0.25)
    obj.data.update()
    knot_at = [Vector((((seed * 0.37) % 1.0 - 0.5) * size[0] * 0.7, ((seed * 0.61) % 1.0 - 0.5) * size[1] * 0.5, 0))]

    def colour(pos, normal):
        grain = noise.noise(Vector((pos.x * 2.0, pos.y * 40.0, pos.z * 40.0)) + Vector((seed, 0, 0)))
        grain += noise.noise(Vector((pos.x * 0.6, pos.y * 90.0, pos.z * 90.0)) + Vector((0, seed, 0))) * 0.6
        c = common.lerp(base, light, max(0.0, min(1.0, 0.5 + grain * 0.5)))
        if grain < -0.45:
            c = common.lerp(c, dark, 0.55)
        if knots:
            for k in knot_at:
                d = Vector((pos.x - k.x, (pos.y - k.y) * 2.5)).length
                if d < 0.05 and abs(normal.z) > 0.5:
                    c = common.lerp(c, dark, max(0.0, 1.0 - d / 0.05) * 0.9)
        for sy in seam_ys:
            if abs(pos.y - sy) < density * 1.2 and pos.z > 0:
                c = common.lerp(c, dark, 0.8)
        for nx, ny in nails:
            d = math.hypot(pos.x - nx, pos.y - ny)
            if d < 0.02 and pos.z > 0:
                c = common.lerp(c, dark, (1.0 - d / 0.02) * 0.35)
        edge = max(abs(pos.x) / hx, abs(pos.y) / hy, abs(pos.z) / hz)
        if edge > 0.93:
            c = common.lerp(c, light, 0.35)
        return c
    common.color_by(obj, colour, smooth=True)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def _place(obj, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1)):
    """Bakes the object's current transform into its mesh, then moves it."""
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.location = location
    obj.rotation_euler = rotation
    obj.scale = scale
    common.apply_transform(obj)
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True)
    return obj


def mound(name, radius, height, seed, colour_fn, segments=18, rings=5):
    """A low, lumpy dome sitting on z = 0."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings * 2, radius=1.0)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0.0
        n = noise.noise(v.co * 2.2 + Vector((seed, seed * 0.5, 0)))
        v.co.x *= radius * (1 + n * 0.18)
        v.co.y *= radius * (1 + n * 0.18)
        v.co.z *= height * (1 + n * 0.3)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    obj = common.mesh_object(name, bm)
    common.shade_smooth(obj, auto_angle=40)
    common.color_by(obj, colour_fn)
    return obj


def disc(name, radius, colour, z=0.015, segments=16, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=segments, radius=radius)
    for v in bm.verts:
        v.co.xy *= 1.0 + noise.noise(v.co * 3 + Vector((seed, 0, 0))) * 0.2
    obj = common.mesh_object(name, bm)
    obj.location = (0, 0, z)
    common.select_only([obj])
    bpy.ops.object.transform_apply(location=True)
    common.set_color(obj, colour)
    return obj


def _clay_colour(seed):
    def colour(pos, normal):
        n = noise.noise(pos * 4.0 + Vector((seed, 0, 0)))
        c = common.lerp(CLAY, CLAY_LIGHT, max(0.0, min(1.0, 0.5 + n * 0.9)))
        # Wet, darker clay low down and in the dug hollow.
        if pos.z < 0.06:
            c = common.lerp(c, CLAY_WET, 0.6)
        return c
    return colour


def dense_mound(name, radius, height, seed, colour_fn, fine=0.0, fine_scale=12.0, subdiv=6, dig=None):
    """mound() with dense, even geometry (an icosphere, so no pole
    streaks): same lumpy footprint, plus fine surface lumps (`fine`,
    metres) and an optional dig(pos) -> depth."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.15], context="VERTS")
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0.0
        n = noise.noise(v.co * 2.2 + Vector((seed, seed * 0.5, 0)))
        v.co.x *= radius * (1 + n * 0.18)
        v.co.y *= radius * (1 + n * 0.18)
        v.co.z *= height * (1 + n * 0.3)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    for v in bm.verts:
        if v.co.z > 0.0005:
            k = min(1.0, v.co.z / (height * 0.25))
            v.co.z += noise.noise(v.co * fine_scale + Vector((0, seed, 7))) * fine * k
            if dig:
                v.co.z -= dig(v.co)
    obj = common.mesh_object(name, bm)
    common.shade_smooth(obj, auto_angle=60)
    common.color_by(obj, colour_fn, smooth=True)
    return obj


def _clay_dense_colour(seed, wet_below=0.06, pebbles=True):
    """Clay with strata bands, scrapes, grit and embedded pebbles."""
    def colour(pos, normal):
        n = noise.noise(pos * 4.0 + Vector((seed, 0, 0)))
        c = common.lerp(CLAY, CLAY_LIGHT, max(0.0, min(1.0, 0.5 + n * 0.9)))
        band = math.sin(pos.z * 70.0 + noise.noise(pos * 3.0) * 4.0)
        if band > 0.6 and normal.z < 0.8:
            c = common.lerp(c, CLAY_LIGHT, 0.35)
        elif band < -0.75:
            c = common.lerp(c, CLAY_WET, 0.25)
        grit = noise.noise(pos * 70.0 + Vector((0, seed, 0)))
        if grit > 0.45:
            c = common.lerp(c, CLAY_WET, 0.35)
        if pebbles:
            peb = noise.noise(pos * 16.0 + Vector((seed * 3, 1, 0)))
            if peb > 0.62:
                c = common.lerp(c, common.lerp((0.5, 0.47, 0.44), (0.76, 0.72, 0.66), max(0.0, normal.z)),
                                min(1.0, (peb - 0.62) * 12))
        if wet_below > 0 and pos.z < wet_below:
            c = common.lerp(c, CLAY_WET, 0.6 * (1.0 - pos.z / wet_below))
        return c
    return colour


def clay_lump(seed, size, location):
    lump = boulder("lump%d" % seed, 400 + seed, (1.0, 0.9, 0.6), subdiv=2, jag=0.2, moss=False)
    densify(lump, 0.06)
    displace(lump, lambda p, n: noise.noise(p * 9.0 + Vector((seed, 0, 0))) * 0.03)
    common.color_by(lump, _clay_dense_colour(seed, wet_below=0.0, pebbles=False))
    return _place(lump, location, (0, 0, seed), (size, size, size))


def _wood_grain(seed, base=WOOD, light=WOOD_LIGHT, dark=WOOD_DARK, along="z"):
    """Fine grain streaks running along one axis (for dense handles)."""
    def colour(pos, normal):
        q = {"x": Vector((pos.x * 2.0, pos.y * 60.0, pos.z * 60.0)),
             "y": Vector((pos.x * 60.0, pos.y * 2.0, pos.z * 60.0)),
             "z": Vector((pos.x * 60.0, pos.y * 60.0, pos.z * 2.0))}[along]
        g = noise.noise(q + Vector((seed, 0, 0))) + noise.noise(q * 0.4) * 0.5
        c = common.lerp(base, light, max(0.0, min(1.0, 0.5 + g * 0.6)))
        if g < -0.4:
            c = common.lerp(c, dark, 0.6)
        return c
    return colour


def spade():
    handle = dense_cylinder(0.035, 0.9, location=(0, 0, 0.45), segments=20, radius2=0.032,
                            colour=_wood_grain(3))
    blade = dense_block((0.22, 0.04, 0.26), location=(0, 0, 0.0), bevel=0.015, density=0.012, dent=0.003, seed=3)

    def blade_colour(p, n):
        c = iron_colour(5, rust=0.2)(p, n)
        smear = noise.noise(p * 12.0 + Vector((2, 0, 0))) * 0.15
        if p.z < -0.02 + smear:
            c = common.lerp(c, CLAY_WET, 0.75)
        if abs(p.x) > 0.095 or p.z < -0.115:
            c = common.lerp(c, (0.78, 0.8, 0.82), 0.4)  # bright worn cutting edge
        return c
    common.color_by(blade, blade_colour)
    socket = dense_cylinder(0.042, 0.12, location=(0, 0, 0.16), segments=16, radius2=0.036,
                            colour=iron_colour(6))
    grip = dense_block((0.2, 0.05, 0.05), location=(0, 0, 0.9), bevel=0.018, density=0.01,
                       colour=_wood_grain(2, along="x"))
    parts = [handle, blade, socket, grip]
    joined = common.join(parts, "spade")
    return _place(joined, (0.32, -0.1, 0.18), (math.radians(18), math.radians(-12), 0.4))


def clay_pit():
    common.reset(21)
    sx, sy = -0.12, 0.1

    def dig(p):
        d = math.hypot(p.x - sx, p.y - sy) / 0.24
        return 0.07 * max(0.0, 1.0 - d * d) if d < 1 else 0.0
    base = _clay_dense_colour(1)

    def colour(p, n):
        c = base(p, n)
        d = math.hypot(p.x - sx, p.y - sy) / 0.24
        if d < 1.0:  # the dug scoop: wet, darker, with spade scrape marks
            scrape = math.sin((p.x * 0.8 + p.y) * 90.0) * 0.5 + 0.5
            c = common.lerp(c, CLAY_WET, 0.55 + 0.2 * scrape - 0.3 * max(0.0, d - 0.75) * 4)
        return c
    parts = [dense_mound("clay", 0.62, 0.42, 1, colour, fine=0.018, fine_scale=9.0, dig=dig)]
    for i, (x, y, s) in enumerate([(0.72, 0.3, 0.3), (-0.7, -0.3, 0.26), (0.1, 0.78, 0.22)]):
        parts.append(clay_lump(i, s, (x, y, 0)))
    parts.append(spade())
    detail.bake_prop(parts, "clay_pit", budget=1400, size=512, ray=0.04, edge_strength=0.3)


def clay_pit_dug():
    common.reset(22)
    wet = _clay_dense_colour(4, wet_below=1.0)

    def patch_colour(p, n):
        c = wet(p, n)
        r = Vector((p.x, p.y)).length
        puddle = noise.noise(p * 3.0 + Vector((0, 4, 0)))
        if puddle > 0.3 and r < 0.5:
            c = common.lerp(c, (0.34, 0.2, 0.14), 0.6)  # standing water / slick mud
        scrape = math.sin((p.x - p.y * 0.4) * 60.0 + noise.noise(p * 4.0) * 3.0)
        if scrape > 0.7:
            c = common.lerp(c, CLAY, 0.35)
        return c
    patch = dense_mound("patch", 0.72, 0.012, 4, patch_colour, fine=0.003, fine_scale=9.0)
    parts = [patch]
    parts.append(dense_mound("rim", 0.5, 0.08, 5, _clay_dense_colour(5, wet_below=0.03), fine=0.006, fine_scale=14.0))
    parts.append(clay_lump(7, 0.16, (0.55, 0.2, 0)))
    detail.bake_prop(parts, "clay_pit_dug", budget=710, size=512, ray=0.02, edge_strength=0.25)


def _moss_colour(seed):
    """Soft clumpy moss: gentle shade between tufts, sun-bleached tips,
    a few fallen leaves and bare earth at the fringe."""
    def colour(pos, normal):
        n = noise.noise(pos * 5.0 + Vector((seed, 0, 0)))
        tuft = noise.noise(pos * 16.0 + Vector((0, seed, 0)))
        c = common.lerp(MOSS, MOSS_LIGHT, max(0.0, min(1.0, 0.5 + n * 0.7 + tuft * 0.35)))
        if tuft < -0.45:
            c = common.lerp(c, (0.25, 0.4, 0.15), 0.35)
        leaf = noise.noise(pos * 9.0 + Vector((seed * 2, 5, 1)))
        if leaf > 0.62:
            c = common.lerp(c, (0.72, 0.46, 0.2), min(1.0, (leaf - 0.62) * 8) * 0.6)
        if pos.z < 0.012:
            c = common.lerp(c, (0.4, 0.3, 0.2), 0.5)
        return c
    return colour


def moss_bed(radius, seed):
    return dense_mound("moss", radius, 0.07, seed, _moss_colour(seed), fine=0.012, fine_scale=26.0)


def _stem_colour(seed, s):
    def colour(pos, normal):
        a = math.atan2(pos.y, pos.x)
        fib = noise.noise(Vector((math.cos(a) * 6, math.sin(a) * 6, pos.z * 3.0 / s + seed)))
        c = common.lerp(STEM, (0.98, 0.96, 0.88), max(0.0, fib))
        if fib < -0.3:
            c = common.lerp(c, (0.78, 0.7, 0.55), 0.6)
        if pos.z < 0.05 * s:
            c = common.lerp(c, (0.55, 0.45, 0.3), 0.6)  # soil-stained foot
        return c
    return colour


def mushroom(seed, s, location, lean=0.0):
    x, y, _ = location
    stem = dense_cylinder(0.075 * s, 0.34 * s, location=(0, 0, 0.17 * s), segments=24, radius2=0.056 * s,
                          colour=_stem_colour(seed, s))
    displace(stem, lambda p, n: noise.noise(p * 30.0 / s + Vector((seed, 0, 0))) * 0.006 * s)
    skirt = torus(0.062 * s, 0.012 * s, location=(0, 0, 0.27 * s), segments=32, tube=8,
                  offset=lambda u, w: 1.0 + 0.25 * math.sin(u * 9),
                  colour=lambda p, n: common.lerp((0.85, 0.78, 0.62), STEM, max(0.0, n.z)))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=0.2 * s)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z *= 0.2
        v.co.z *= 0.75
        a = math.atan2(v.co.y, v.co.x)
        wob = 1.0 + noise.noise(Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, seed))) * 0.08
        v.co.x *= wob
        v.co.y *= wob
        if v.co.z > 0:
            v.co.z += noise.noise(v.co * 18.0 / s + Vector((seed, 2, 0))) * 0.008 * s
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.33 * s))
    cap = common.mesh_object("cap", bm)
    common.shade_smooth(cap)

    def colour(pos, normal, s=s):
        r = Vector((pos.x, pos.y)).length / (0.2 * s)
        if normal.z < -0.2:
            a = math.atan2(pos.y, pos.x)
            gill = math.sin(a * 64.0) * 0.5 + 0.5
            c = common.lerp((0.94, 0.86, 0.68), (0.62, 0.5, 0.36), gill * 0.7 * min(1.0, r * 1.3))
            return c
        n = noise.noise(pos * 10.0 / s + Vector((seed, 0, 0)))
        c = common.lerp(CAP, CAP_LIGHT, max(0.0, min(1.0, 0.45 + n + (pos.z - 0.3 * s) * 2.0 / s)))
        spot = noise.noise(pos * 40.0 / s + Vector((0, seed, 3)))
        if spot > 0.45 and r < 0.85:
            c = common.lerp(c, (0.95, 0.86, 0.66), min(1.0, (spot - 0.45) * 5) * 0.8)  # pale scales
        if r > 0.9:
            c = common.lerp(c, (0.4, 0.22, 0.12), min(1.0, (r - 0.9) * 10) * 0.6)  # darker rim
        return c
    common.color_by(cap, colour, smooth=True)
    joined = common.join([stem, skirt, cap], "mushroom")
    return _place(joined, (x, y, 0), (lean, 0, seed * 1.3))


MUSHROOM_SPOTS = [(0, 0, 1.15, 0.0), (0.3, 0.14, 0.8, 0.2), (-0.26, 0.22, 0.7, -0.15),
                  (0.12, -0.32, 0.6, 0.15), (-0.3, -0.18, 0.5, -0.2)]


def mushrooms():
    common.reset(23)
    parts = [moss_bed(0.62, 1)]
    for i, (x, y, s, lean) in enumerate(MUSHROOM_SPOTS):
        parts.append(mushroom(i, s, (x, y, 0.03), lean))
    detail.bake_prop(parts, "mushrooms", budget=1400, size=512, ray=0.02, edge_strength=0.25)


def mushrooms_picked():
    common.reset(24)
    parts = [moss_bed(0.58, 3)]
    for i, (x, y) in enumerate([(0, 0), (0.28, 0.12), (-0.24, 0.2)]):
        def colour(p, n, i=i):
            if n.z > 0.7:  # fresh cut: pale flesh with a bruised ring
                r = Vector((p.x, p.y)).length / 0.05
                return common.lerp((0.98, 0.95, 0.84), (0.72, 0.6, 0.42), max(0.0, r - 0.6) * 2.0)
            return _stem_colour(i, 0.4)(p, n)
        nub = dense_cylinder(0.05, 0.08, location=(x, y, 0.08), segments=20, radius2=0.045, bevel=0.006)
        displace(nub, lambda p, n: noise.noise(p * 60.0) * 0.003)
        common.color_by(nub, colour)
        parts.append(nub)
    detail.bake_prop(parts, "mushrooms_picked", budget=968, size=512, ray=0.015, edge_strength=0.2)


DIRT = (0.45, 0.36, 0.26)


def _dirt_colour(seed):
    """Packed dirt: mottled earth, grit, pebbles and a few grass tufts."""
    def colour(pos, normal):
        n = noise.noise(pos * 4.0 + Vector((seed, 0, 0)))
        c = common.lerp(DIRT, (0.58, 0.47, 0.34), max(0.0, min(1.0, 0.5 + n * 0.8)))
        grit = noise.noise(pos * 45.0 + Vector((0, seed, 0)))
        if grit > 0.4:
            c = common.lerp(c, (0.32, 0.25, 0.18), 0.4)
        peb = noise.noise(pos * 14.0 + Vector((seed * 3, 2, 0)))
        if peb > 0.6:
            c = common.lerp(c, (0.66, 0.62, 0.56), min(1.0, (peb - 0.6) * 10))
        r = Vector((pos.x, pos.y)).length
        grass = noise.noise(pos * 7.0 + Vector((1, seed, 4)))
        if grass > 0.35 and r > 0.45:
            c = common.lerp(c, (0.42, 0.55, 0.22), min(1.0, (grass - 0.35) * 5) * 0.8)
        return c
    return colour


def dirt_patch(radius, seed):
    return dense_mound("dirt", radius, 0.025, seed, _dirt_colour(seed), fine=0.004, fine_scale=12.0)


def tin_can(seed, location, rotation):
    def colour(pos, normal):
        if abs(normal.z) > 0.8:
            r = Vector((pos.x, pos.y)).length
            ring = math.sin(r * 160.0) > 0.3
            c = common.lerp(TIN, (0.45, 0.48, 0.52), 0.4 if ring else 0.0)
            return common.lerp(c, RUST, max(0.0, noise.noise(pos * 25 + Vector((seed, 0, 0)))) * 1.2)
        if abs(pos.z) < 0.055:  # paper label, torn and faded at one edge
            tear = noise.noise(pos * 12 + Vector((0, seed, 0)))
            if tear > 0.35:
                return common.lerp(TIN, RUST, 0.4)
            stripe = abs(pos.z) > 0.04
            return (0.95, 0.88, 0.7) if stripe else common.lerp(LABEL, (0.9, 0.4, 0.3), max(0.0, tear))
        return common.lerp(TIN, RUST, max(0.0, min(1.0, noise.noise(pos * 20 + Vector((seed, 0, 0))) * 1.5)))
    can = dense_cylinder(0.09, 0.2, segments=28, rings=24, bevel=0.008)
    displace(can, lambda p, n: (0.004 * math.sin(p.z * 150.0) if abs(n.z) < 0.5 and abs(p.z) > 0.06 else 0.0)
             - max(0.0, noise.noise(p * 8.0 + Vector((seed, 1, 0))) - 0.3) * 0.03)
    common.color_by(can, colour)
    return _place(can, location, rotation)


def cart_wheel(location, rotation):
    """A broken cart wheel: wooden felloes in an iron tyre, six spokes."""
    rim = torus(0.34, 0.04, segments=72, tube=12, offset=lambda u, w: 1.0 + 0.05 * math.sin(u * 3),
                colour=_wood_grain(5, base=WOOD_DARK, light=WOOD, along="z"))
    # Felloe joints: dark cuts every 60 degrees.
    common.grime(rim, (0.15, 0.09, 0.05), lambda p, n: 1.0 if abs(math.sin(math.atan2(p.y, p.x) * 3 + 0.5)) < 0.04 else 0.0)
    tyre = torus(0.375, 0.012, segments=72, tube=8, colour=iron_colour(7, rust=0.45))
    for v in tyre.data.vertices:
        v.co.z *= 2.4
    parts = [rim, tyre]
    parts.append(dense_cylinder(0.07, 0.14, segments=20, colour=_wood_grain(6, base=WOOD_DARK, light=WOOD),
                                bevel=0.01))
    parts.append(dense_cylinder(0.075, 0.03, location=(0, 0, 0.05), segments=20, colour=iron_colour(8)))
    for k in range(6):
        a = k / 6 * math.tau
        spoke = dense_block((0.3, 0.035, 0.035), location=(math.cos(a) * 0.17, math.sin(a) * 0.17, 0), rotation=(0, 0, a),
                            bevel=0.01, density=0.01, colour=_wood_grain(k, along="x"))
        parts.append(spoke)
    wheel = common.join(parts, "wheel")
    return _place(wheel, location, rotation)


def broken_crate(seed, location, rotation):
    parts = []
    for k in range(3):  # three planks left of one side, and a leaning lid plank
        parts.append(board((0.7, 0.16, 0.05), location=(0, 0.3, 0.1 + k * 0.19), rotation=(math.pi / 2, 0, 0),
                           seed=seed + k, bevel=0.015, warp=0.01, nails=[(-0.32, 0), (0.32, 0)]))
    for sx in (-1, 1):
        parts.append(board((0.6, 0.08, 0.08), location=(sx * 0.32, 0.3, 0.3), rotation=(0, math.pi / 2, 0),
                           seed=seed + sx + 5, base=WOOD_DARK, light=WOOD, knots=False))
    parts.append(rivets([((sx * 0.32, 0.27, 0.1 + k * 0.19), (0, -1, 0)) for sx in (-1, 1) for k in range(3)], 0.011))
    side = board((0.5, 0.6, 0.05), location=(-0.32, 0.0, 0.25), rotation=(0, math.pi / 2, 0), seed=seed + 7, seams=2,
                 warp=0.015)
    parts.append(side)
    lid = board((0.75, 0.3, 0.05), location=(0.2, -0.25, 0.18), rotation=(math.radians(35), 0, 0.3), seed=seed + 9,
                base=WOOD_LIGHT, light=(0.88, 0.7, 0.46), seams=1, nails=[(-0.33, -0.07), (-0.33, 0.07)])
    parts.append(lid)
    crate = common.join(parts, "broken_crate")
    return _place(crate, location, rotation)


def pipe(location, rotation):
    obj = dense_cylinder(0.05, 0.7, segments=16, rings=40, cap=False)
    bend = obj.modifiers.new("Bend", "SIMPLE_DEFORM")
    bend.deform_method = "BEND"
    bend.angle = math.radians(60)
    bend.deform_axis = "X"
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj, auto_angle=50)
    common.color_by(obj, iron_colour(11, rust=0.6))
    return _place(obj, location, rotation)


def junk_pile():
    common.reset(25)
    parts = [dirt_patch(0.78, 5)]
    parts.append(broken_crate(1, (0.05, 0.05, 0), (0, 0, 0.3)))
    parts.append(cart_wheel((-0.45, -0.25, 0.22), (math.radians(70), 0, 0.6)))
    parts.append(tin_can(1, (0.45, -0.35, 0.09), (0, 0, 0)))
    parts.append(tin_can(2, (0.55, -0.1, 0.07), (math.radians(90), 0, 1.0)))
    parts.append(pipe((0.35, 0.45, 0.08), (math.radians(90), 0, 2.2)))
    detail.bake_prop(parts, "junk_pile", budget=1400, size=512, ray=0.03, edge_strength=0.4)


def junk_pile_picked():
    common.reset(26)
    parts = [dirt_patch(0.74, 6)]
    for k in range(3):
        parts.append(board((0.6, 0.14, 0.04), location=(random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3),
                                                         0.03 + k * 0.045),
                           rotation=(0, 0, random.uniform(0, math.pi)), seed=k, bevel=0.012,
                           nails=[(-0.26, 0.0)] if k != 1 else ()))
    parts.append(tin_can(3, (0.4, 0.3, 0.07), (math.radians(90), 0, 0.2)))
    detail.bake_prop(parts, "junk_pile_picked", budget=700, size=512, ray=0.02, edge_strength=0.35)


def snap_trap_base():
    """Three nailed boards, an iron hinge bar with pin and rivets, a brass
    trigger plate and a tether stake. Jaws pivot at (+-0.05, z 0.1)."""
    common.reset(27)
    parts = []
    for k, y in enumerate((-0.234, 0.0, 0.234)):
        parts.append(board((0.9, 0.228, 0.07 - k % 2 * 0.004), location=(0, y, 0.035 - k % 2 * 0.002),
                           seed=k * 3 + 1, bevel=0.012, nails=[(sx * 0.4, dy) for sx in (-1, 1) for dy in (-0.05, 0.05)]))
    nails = [(sx * 0.4, y + dy, 0.068 - (k % 2) * 0.006) for sx in (-1, 1) for k, y in enumerate((-0.234, 0.0, 0.234))
             for dy in (-0.05, 0.05)]
    parts.append(rivets(nails, 0.011))
    for sx in (-1, 1):  # hinge blocks
        parts.append(dense_block((0.12, 0.62, 0.08), location=(sx * 0.05, 0, 0.1), bevel=0.015, density=0.015,
                                 colour=iron_colour(sx + 3), dent=0.002, seed=sx))
        parts.append(rivets([(sx * 0.05, y, 0.14) for y in (-0.26, -0.13, 0.13, 0.26)], 0.012))
    # Hinge pins along each jaw axis, poking out at the ends.
    for sx in (-1, 1):
        parts.append(dense_cylinder(0.018, 0.68, location=(sx * 0.05, 0, 0.1), rotation=(math.pi / 2, 0, 0),
                                    segments=12, rings=12, colour=iron_colour(sx + 9, rust=0.15)))
    pad = dense_block((0.22, 0.22, 0.03), location=(0, 0, 0.085), bevel=0.01, density=0.012,
                      colour=lambda p, n: common.lerp((0.9, 0.72, 0.3), (0.66, 0.46, 0.18),
                                                      max(0.0, noise.noise(p * 25.0)) * 1.4))
    parts.append(pad)
    peg = stake(0.25, 0.04, location=(0.5, 0.3, -0.05), seed=2)
    densify(peg, 0.012)
    common.color_by(peg, lambda p, n: (common.lerp((0.36, 0.22, 0.13), WOOD_LIGHT, min(1.0, (p.z - 0.17) * 12))
                                       if p.z > 0.17 else
                                       common.lerp(BARK_COL, WOOD, max(0.0, min(1.0, 0.5 + noise.noise(
                                           Vector((p.x * 40, p.y * 40, p.z * 4))))))))
    parts.append(peg)
    parts.append(twisted_rope(0.03, 0.009, location=(0.5, 0.3, 0.09), segments=40))
    detail.bake_prop(parts, "snap_trap_base", budget=1000, size=512, ray=0.02, edge_strength=0.35)


def snap_trap_jaw():
    """One jaw, hinged on its local origin, lying open along +X."""
    common.reset(28)
    bar = board((0.4, 0.6, 0.05), location=(0.2, 0, 0.025), seed=5, base=WOOD_DARK, light=WOOD,
                dark=(0.22, 0.13, 0.08), bevel=0.012, seams=1)
    parts = [bar]
    # An iron strap along the hinge edge, riveted through.
    parts.append(dense_block((0.1, 0.6, 0.012), location=(0.06, 0, 0.054), bevel=0.004, density=0.015,
                             colour=iron_colour(4), dent=0.0015, seed=4))
    parts.append(rivets([(0.06, y, 0.06) for y in (-0.24, -0.08, 0.08, 0.24)], 0.01))
    for k in range(5):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.045, radius2=0.0, depth=0.14)
        tooth = common.mesh_object("tooth", bm)
        densify(tooth, 0.008)
        _place(tooth, (0.4, -0.24 + k * 0.12, 0.08), (0, 0, math.pi / 4))

        def colour(p, n, k=k):
            t = max(0.0, min(1.0, (p.z - 0.02) / 0.13))
            c = common.lerp((0.55, 0.5, 0.46), (0.95, 0.93, 0.88), t ** 0.7)
            return common.lerp(c, RUST, max(0.0, noise.noise(p * 30.0 + Vector((k, 0, 0)))) * (1.0 - t) * 0.7)
        common.color_by(tooth, colour)
        parts.append(tooth)
    detail.bake_prop(parts, "snap_trap_jaw", budget=400, size=512, ray=0.015, edge_strength=0.3)


def glow_crystal(seed, height, radius, location, tilt):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=radius, radius2=radius * 0.8, depth=height)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, height / 2))
    tip = [v for v in bm.verts if v.co.z > height - 0.001]
    bmesh.ops.pointmerge(bm, verts=tip, merge_co=(0, 0, height + radius * 1.5))
    crystal = common.mesh_object("crystal%d" % seed, bm)
    return _place(crystal, location, (tilt[0], tilt[1], seed))


GLOW_PALE = (0.82, 1.0, 1.0)
GLOW_MID = (0.3, 0.78, 0.98)


def _glow_group(specs, name):
    """Glowing crystals, faceted in three emissive tones (pale tips,
    alternating cyan sides) so the gem reads even unshaded."""
    crystals = [glow_crystal(i, *spec) for i, spec in enumerate(specs)]
    glow = common.join(crystals, name)
    mats = [paint_bake.flat_material(glow, GLOW, emission=2.4, name="glow_crystal_glow")]
    for colour, tag in ((GLOW_MID, "mid"), (GLOW_PALE, "pale")):
        mat = bpy.data.materials.new("glow_crystal_glow_" + tag)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*colour, 1)
        bsdf.inputs["Roughness"].default_value = 0.6
        bsdf.inputs["Emission Color"].default_value = (*colour, 1)
        bsdf.inputs["Emission Strength"].default_value = 2.4
        glow.data.materials.append(mat)
    for poly in glow.data.polygons:
        if poly.normal.z > 0.55:
            poly.material_index = 2
        elif poly.normal.z > -0.5:
            a = math.atan2(poly.normal.y, poly.normal.x)
            poly.material_index = 1 if int((a + math.pi) / (math.tau / 6) + 0.5) % 2 else 0
    return glow


def glow_shard():
    common.reset(29)
    glow = _glow_group([(0.34, 0.07, (0, 0, 0), (0.1, 0.0)), (0.24, 0.055, (0.08, 0.04, 0), (0.5, 0.2)),
                        (0.2, 0.05, (-0.07, 0.03, 0), (-0.45, 0.1))], "glow_shard")
    common.export_glb(os.path.join(common.OUT_DIR, "glow_shard.glb"), [glow])
    print("glow_shard tris:", common.triangle_count([glow]))
    preview.render([glow], "glow_shard", elevation=20)


def _stone_foot(i, scale):
    s = boulder("foot%d" % i, 500 + i, (1.0, 0.85, 0.6), subdiv=2, jag=0.25, moss=True)
    densify(s, 0.08)
    displace(s, lambda p, n: -max(0.0, noise.noise(p * 12.0 + Vector((i, 0, 0)))) * 0.03)
    return s


def glow_lantern():
    common.reset(30)
    parts = []
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        s = _stone_foot(i, 0.5)
        parts.append(_place(s, (math.cos(a) * 0.2, math.sin(a) * 0.2, 0), (0, 0, a), (0.5, 0.5, 0.5)))
    parts.append(detail.bark_log(1.6, 0.07, location=(0, 0, 0.8), rotation=(0, math.radians(-90), 0), taper=0.85,
                                 seed=4, segments=48))
    parts.append(board((0.5, 0.06, 0.06), location=(0.2, 0, 1.55), seed=3, bevel=0.012, knots=False,
                       nails=[(-0.02, 0.0)]))
    # Iron cage hanging from the arm.
    cx, cz = 0.38, 1.18
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(dense_block((0.025, 0.025, 0.36), location=(cx + sx * 0.1, sy * 0.1, cz), bevel=0.006,
                                     density=0.01, colour=iron_colour(sx + 2 * sy + 3), dent=0.002, seed=sx + sy * 3))
    for k, z in enumerate((cz - 0.18, cz + 0.18)):
        parts.append(dense_block((0.26, 0.26, 0.035), location=(cx, 0, z), bevel=0.01, density=0.01,
                                 colour=iron_colour(k + 7), dent=0.003, seed=k + 7))
        parts.append(rivets([(cx + sx * 0.1, sy * 0.1, z + 0.0175) for sx in (-1, 1) for sy in (-1, 1)], 0.01))
    # A little peaked cap on the top plate.
    cap = dense_cylinder(0.11, 0.06, location=(cx, 0, cz + 0.225), segments=4, radius2=0.03, rings=6,
                         colour=iron_colour(12))
    cap.rotation_euler = (0, 0, math.pi / 4)
    parts.append(cap)
    parts.append(torus(0.05, 0.012, location=(cx, 0, 1.43), rotation=(math.pi / 2, 0, 0), segments=32, tube=8,
                       colour=iron_colour(13)))
    glow = _glow_group([(0.22, 0.05, (cx, 0, cz - 0.14), (0.05, 0.0)), (0.16, 0.04, (cx + 0.04, 0.03, cz - 0.14), (0.4, 0.2)),
                        (0.14, 0.035, (cx - 0.05, -0.02, cz - 0.14), (-0.35, 0.1))], "glow_lantern_crystal")
    detail.bake_prop(parts, "glow_lantern", budget=1300, size=512, ray=0.03, extra=[glow], preview_elevation=25,
                     edge_strength=0.4)


def hearth_ring():
    """Clay bricks laid in a ring just outside the campfire stones: chipped,
    fired unevenly, sooted on the faces toward the fire."""
    common.reset(31)
    parts = []
    count = 16

    def brick(size, seed, angle, radius, z):
        # M8: hand-made, uneven bricks: sizes, angles and firing vary.
        jit = random.Random(seed)
        size = (size[0] * jit.uniform(0.88, 1.1), size[1] * jit.uniform(0.9, 1.08), size[2] * jit.uniform(0.9, 1.1))
        b = dense_block(size, location=(0, 0, z), bevel=0.024, density=0.012, warp=0.02, seed=seed)
        displace(b, lambda p, n: -max(0.0, noise.noise(p * 9.0 + Vector((seed, 0, 0))) - 0.25) * 0.05)
        _place(b, (math.cos(angle) * radius, math.sin(angle) * radius, 0),
               (jit.uniform(-0.05, 0.05), jit.uniform(-0.06, 0.06), angle + math.pi / 2 + jit.uniform(-0.12, 0.12)))
        fired = noise.noise(Vector((seed * 1.7, 0.3, 0.2))) * 0.5 + 0.5
        burnt = jit.random() < 0.3
        clay = _clay_dense_colour(seed, wet_below=0.0, pebbles=False)

        def colour(p, n):
            c = clay(p, n)
            c = common.lerp(c, (0.6, 0.27, 0.16), fired * 0.5)
            c = common.lerp(c, (0.62, 0.5, 0.42), 0.18)  # a little dustier than raw clay
            if burnt:
                c = common.lerp(c, (0.3, 0.17, 0.12), 0.45)
            chip = noise.noise(p * 9.0 + Vector((seed, 0, 0)))
            if chip > 0.35:
                c = common.lerp(c, CLAY_LIGHT, 0.4)  # fresh chipped clay
            inward = -(p.x * n.x + p.y * n.y) / max(0.01, Vector((p.x, p.y)).length)
            soot = max(0.0, inward) * 0.8 + max(0.0, n.z) * 0.25 * max(0.0, noise.noise(p * 5.0 + Vector((0, seed, 0))))
            soot *= max(0.0, min(1.0, 0.6 + noise.noise(p * 7.0 + Vector((seed, 2, 0)))))
            return common.lerp(c, (0.16, 0.11, 0.09), min(0.8, soot))
        common.color_by(b, colour)
        return b
    for i in range(count):
        a = i / count * math.tau
        parts.append(brick((0.3, 0.16, 0.14), i, a, 1.12, 0.07))
        if i % 2 == 0:  # a second, staggered course on every other brick
            parts.append(brick((0.26, 0.15, 0.12), i + 50, a + math.pi / count, 1.12, 0.2))
    detail.bake_prop(parts, "hearth_ring", budget=1400, size=512, ray=0.03, edge_strength=0.35)


# --- Feature 019: wall, storage crate, crafting table -----------------------

STONE_GREY = (0.62, 0.6, 0.58)


def _stone_block(seed, size, location):
    rock = boulder("wallstone%d" % seed, 700 + seed, (1.0, 0.7, 0.6), subdiv=2, jag=0.12, moss=seed % 3 == 0)
    densify(rock, 0.06)
    # Chisel pits and a few tooled grooves on the face.
    displace(rock, lambda p, n: -max(0.0, noise.noise(p * 14.0 + Vector((seed, 0, 0))) - 0.15) * 0.04
             - (0.012 if abs(math.sin(p.x * 40.0 + p.z * 13.0 + seed)) < 0.08 and n.y < -0.5 else 0.0))
    return _place(rock, location, (0, 0, random.uniform(-0.1, 0.1)), size)


def _mortar_colour(seed):
    clay = _clay_dense_colour(seed, wet_below=0.0)

    def colour(p, n):
        c = clay(p, n)
        straw = noise.noise(Vector((p.x * 30.0, p.y * 30.0, p.z * 4.0)) + Vector((seed, 0, 0)))
        if straw > 0.55:
            c = common.lerp(c, (0.86, 0.74, 0.42), 0.6)  # straw in the daub
        return c
    return colour


def reinforced_wall():
    """Three courses of fitted stones on a clay footing, capped with a
    lashed log: the fence's sturdy big brother (same 1.7 m span)."""
    common.reset(32)
    parts = []
    parts.append(dense_block((1.8, 0.42, 0.14), location=(0, 0, 0.07), bevel=0.03, warp=0.02, seed=1, density=0.015,
                             colour=_clay_dense_colour(1, wet_below=0.03), dent=0.01))
    # Clay mortar core, so the gaps between stones read as packed clay.
    parts.append(dense_block((1.62, 0.12, 0.85), location=(0, 0, 0.55), bevel=0.03, warp=0.02, seed=2, density=0.02,
                             colour=_mortar_colour(2), dent=0.01))
    seed = 0
    for row, z in enumerate((0.14, 0.44, 0.74)):
        count = 4 if row % 2 == 0 else 3
        width = 1.7 / count
        for i in range(count):
            x = -0.85 + width * (i + 0.5)
            parts.append(_stone_block(seed, (width * 1.5, 0.8, 0.72), (x, 0, z - 0.02)))
            seed += 1
    parts.append(detail.bark_log(1.85, 0.1, location=(0, 0, 1.1), seed=5, segments=64))
    for x in (-0.6, 0.0, 0.6):
        parts.append(twisted_rope(0.12, 0.022, (x, 0, 1.1), rotation=(0, math.radians(90), 0)))
    detail.bake_prop(parts, "reinforced_wall", budget=1400, size=512, ray=0.04, preview_elevation=25,
                     edge_strength=0.4)


def _plank_wall_colour(seed, pitch=0.15, base=WOOD, light=WOOD_LIGHT, dark=WOOD_DARK, z0=0.0):
    """Horizontal planks on the sides of a box: grain runs level, dark
    seams every `pitch` metres."""
    def colour(p, n):
        q = Vector((p.x * 2.5, p.y * 2.5, p.z * 50.0)) + Vector((seed, 0, 0))
        g = noise.noise(q) + noise.noise(q * Vector((0.5, 0.5, 2.0))) * 0.5
        row = math.floor((p.z - z0) / pitch)
        c = common.lerp(base, light, max(0.0, min(1.0, 0.5 + g * 0.5 + ((row * 0.37) % 1.0 - 0.5) * 0.4)))
        if g < -0.45:
            c = common.lerp(c, dark, 0.5)
        f = ((p.z - z0) / pitch) % 1.0
        if abs(n.z) < 0.6 and (f < 0.06 or f > 0.94):
            c = common.lerp(c, (0.18, 0.1, 0.06), 0.75)
        return c
    return colour


def storage_crate():
    """A big lidded chest with rope bands and an iron latch."""
    common.reset(33)
    body = dense_block((1.1, 0.75, 0.6), location=(0, 0, 0.3), bevel=0.04, density=0.012)
    pitch = 0.15
    displace(body, lambda p, n: -0.007 if abs(n.z) < 0.6 and ((p.z + 0.3) / pitch % 1.0 < 0.05
                                                               or (p.z + 0.3) / pitch % 1.0 > 0.95) else 0.0)
    common.color_by(body, _plank_wall_colour(2, pitch, z0=-0.3))
    parts = [body]
    lid = board((1.16, 0.8, 0.14), location=(0, 0, 0.67), seed=4, base=WOOD_DARK, light=WOOD, bevel=0.04,
                density=0.012, seams=3, warp=0.008)
    parts.append(lid)
    for x in (-0.36, 0.36):
        band = board((0.76, 0.82, 0.08), location=(x, 0, 0.37), rotation=(0, math.pi / 2, 0), seed=int(x * 10) + 6,
                     base=WOOD_DARK, light=WOOD, bevel=0.02, knots=False)
        parts.append(band)
        nails = [((x, -0.415, z), (0, -1, 0)) for z in (0.12, 0.32, 0.52)]
        nails += [((x, 0.415, z), (0, 1, 0)) for z in (0.12, 0.32, 0.52)]
        nails += [((x, y, 0.752), (0, 0, 1)) for y in (-0.28, 0.0, 0.28)]
        parts.append(rivets(nails, 0.014))
    parts.append(dense_block((0.14, 0.05, 0.16), location=(0, -0.41, 0.56), bevel=0.015, density=0.01,
                             colour=iron_colour(3), dent=0.003, seed=3))
    parts.append(rivets([((sx * 0.045, -0.437, z), (0, -1, 0)) for sx in (-1, 1) for z in (0.51, 0.61)], 0.011))
    parts.append(torus(0.035, 0.009, location=(0, -0.44, 0.49), rotation=(0, 0, 0), segments=24, tube=8,
                       colour=iron_colour(5)))
    for side in (-1, 1):
        parts.append(twisted_rope(0.08, 0.02, (side * 0.57, 0, 0.42), rotation=(0, math.radians(90), 0)))
    detail.bake_prop(parts, "storage_crate", budget=1344, size=512, ray=0.03, edge_strength=0.45)


def crafting_table():
    """A sturdy workbench with a saw, a mallet and a vise."""
    common.reset(34)
    parts = []
    top = board((1.3, 0.65, 0.1), location=(0, 0, 0.78), seed=1, base=WOOD_LIGHT, light=(0.9, 0.7, 0.46), bevel=0.02,
                density=0.01, seams=3, warp=0.006, nails=[(sx * 0.6, y) for sx in (-1, 1) for y in (-0.24, -0.08, 0.08, 0.24)])
    # Work stains: a dark ring from a pot, scorch, and nicks.
    common.grime(top, (0.36, 0.22, 0.12), lambda p, n: (0.55 if n.z > 0.5 and abs(math.hypot(p.x - 0.35, p.y + 0.15) - 0.07)
                                                        < 0.008 else 0.0)
                 + (0.4 if n.z > 0.5 and abs(math.sin(p.x * 31.0 + p.y * 7.0)) < 0.02
                    and noise.noise(p * 6.0) > 0.2 else 0.0))
    parts.append(top)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(board((0.74, 0.1, 0.1), location=(sx * 0.55, sy * 0.24, 0.37), rotation=(0, math.pi / 2, 0),
                               seed=sx + sy * 2 + 4, base=WOOD_DARK, light=WOOD, bevel=0.015, knots=False))
    parts.append(board((1.15, 0.5, 0.05), location=(0, 0, 0.2), seed=7, bevel=0.015, seams=2))
    # Vise: an iron body, a jaw, and a screw bar with knobs.
    vise_c = iron_colour(9)
    parts.append(dense_block((0.18, 0.16, 0.16), location=(0.58, -0.3, 0.8), bevel=0.015, density=0.01, colour=vise_c,
                             dent=0.003, seed=9))
    parts.append(dense_block((0.18, 0.04, 0.1), location=(0.58, -0.39, 0.83), bevel=0.01, density=0.01,
                             colour=iron_colour(10), seed=10))
    parts.append(dense_cylinder(0.012, 0.2, location=(0.58, -0.42, 0.8), rotation=(0, math.pi / 2, 0), segments=10,
                                colour=iron_colour(11, rust=0.15)))
    parts.append(rivets([((0.58 + sx * 0.06, -0.41, 0.86), (0, -1, 0)) for sx in (-1, 1)], 0.012))
    # Saw: a toothed steel blade with a wooden grip.
    saw = dense_block((0.5, 0.12, 0.01), location=(0, 0, 0), bevel=0.0, density=0.006)
    for v in saw.data.vertices:
        if v.co.y < -0.055:
            v.co.y -= 0.012 * abs(((v.co.x * 60.0) % 1.0) - 0.5) * 2.0
    common.color_by(saw, lambda p, n: common.lerp((0.6, 0.62, 0.66), (0.86, 0.88, 0.9),
                                                  max(0.0, min(1.0, 0.5 + noise.noise(p * Vector((4, 40, 4))) * 0.6)))
                    if p.y > -0.05 else (0.9, 0.92, 0.94))
    saw.location = (-0.25, 0.05, 0.84)
    parts.append(saw)
    parts.append(dense_block((0.12, 0.08, 0.04), location=(-0.55, 0.05, 0.855), bevel=0.012, density=0.008,
                             colour=_wood_grain(8, along="x")))
    parts.append(rivets([(-0.53, 0.05, 0.876), (-0.57, 0.05, 0.876)], 0.007))
    # Mallet: a turned head with end grain, on a slim handle.
    head = dense_cylinder(0.06, 0.2, location=(0.2, 0.15, 0.89), rotation=(0, math.pi / 2, 0), segments=24,
                          bevel=0.01)

    def head_colour(p, n):
        if abs(n.z) > 0.8:
            r = Vector((p.x, p.y)).length / 0.06
            return common.lerp(END_GRAIN_COL, WOOD, (math.sin(r * 16.0) * 0.5 + 0.5) * 0.35 + r * 0.3)
        return _wood_grain(9, base=WOOD, light=WOOD_LIGHT, along="z")(p, n)
    common.color_by(head, head_colour)
    parts.append(head)
    parts.append(dense_cylinder(0.02, 0.3, location=(0.2, -0.02, 0.86), rotation=(math.pi / 2, 0, 0), segments=12,
                                colour=_wood_grain(10, base=WOOD_LIGHT, light=(0.9, 0.7, 0.46))))
    for k in range(3):
        parts.append(board((0.5, 0.12, 0.04), location=(0.05, 0.05, 0.25 + k * 0.045), rotation=(0, 0, 0.1 * k),
                           seed=11 + k, bevel=0.01))
    detail.bake_prop(parts, "crafting_table", budget=1400, size=512, ray=0.03, edge_strength=0.4)


PROPS = {
    "clay_pit": clay_pit, "clay_pit_dug": clay_pit_dug, "mushrooms": mushrooms, "mushrooms_picked": mushrooms_picked,
    "junk_pile": junk_pile, "junk_pile_picked": junk_pile_picked, "snap_trap_base": snap_trap_base,
    "snap_trap_jaw": snap_trap_jaw, "glow_shard": glow_shard, "glow_lantern": glow_lantern, "hearth_ring": hearth_ring,
    "reinforced_wall": reinforced_wall, "storage_crate": storage_crate, "crafting_table": crafting_table,
}

if __name__ == "__main__":
    for name in (sys.argv[1:] or PROPS.keys()):
        random.seed(hash(name) & 0xFFFF)
        PROPS[name]()
