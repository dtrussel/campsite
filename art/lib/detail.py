"""Dense surface detail for props (feature 031, milestone 6).

Props used to be coloured per face on their game-budget mesh, so detail
was capped by the triangle budget (and decimation smeared the colours,
D7). Here a prop is modelled dense: bark grooves, growth rings, plank
seams, tile rows. That dense copy is painted, then baked onto the
decimated game mesh (paint_bake's high-to-low path, as for the kids).
Detail lives in the texture; the silhouette stays in the budget.

bake_prop(parts, name, budget)  join, decimate, high-to-low paint, export
bark_log(...)                   a dense log: bark ridges and end rings
plank(...)                      a dense board: grain, knots, worn edges
"""

import math
import os

import bmesh
from mathutils import Matrix, Vector, noise

from . import common, paint_bake, preview

BARK = (0.42, 0.27, 0.17)
BARK_DARK = (0.2, 0.12, 0.08)
BARK_LIGHT = (0.58, 0.4, 0.25)
SEAT = (0.74, 0.55, 0.34)
END_GRAIN = (0.92, 0.72, 0.46)
RING = (0.72, 0.48, 0.28)


def decimate_tris(obj, target):
    """Collapse-decimates to about `target` triangles."""
    for _ in range(3):
        tris = common.triangle_count([obj])
        if tris <= target * 1.08:
            return
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = target / tris
        common.apply_all_modifiers(obj)


def bake_prop(parts, name, budget, size=512, preview_elevation=35, ray=0.05, extra=(), **paint):
    """Joins `parts` into the dense prop, keeps a copy as the bake source,
    decimates the prop to `budget` triangles and paints the dense copy's
    look onto it. `extra` objects (e.g. emissive glass) export alongside.
    `ray` is how far the bake looks for the dense surface: at least the
    depth of the deepest carved detail."""
    obj = common.join(parts, name)
    high = obj.copy()
    high.data = obj.data.copy()
    high.name = name + "_high"
    obj.users_collection[0].objects.link(high)
    high.hide_render = True
    dense = common.triangle_count([high])
    decimate_tris(obj, budget)
    params = dict(ao_distance=0.25, ao_strength=0.7, edge_strength=0.45, edge_radius=0.02, noise_scale=6.0,
                  cavity=0.6, max_ray_distance=ray, cage_extrusion=ray * 0.5)
    params.update(paint)
    paint_bake.paint_direct(obj, high, size=size, **params)
    objects = [obj] + list(extra)
    common.export_glb(os.path.join(common.OUT_DIR, name + ".glb"), objects)
    print(name, "tris:", common.triangle_count(objects), "(dense %d)" % dense)
    preview.render(objects, name, elevation=preview_elevation)
    return obj


def _bark_point(angle, along, radius, seed):
    """Bark noise space: ~12 ridges around the log, long along it."""
    return Vector((math.cos(angle) * 3.6, math.sin(angle) * 3.6, along * 0.28 / max(radius, 0.05) + seed))


def _ridge(p):
    """0 in a crack, 1 on a ridge: sharp-bottomed valleys."""
    return min(1.0, abs(noise.noise(p)) * 6.0)


def bark_log(length, radius, location=(0, 0, 0), rotation=(0, 0, 0), taper=0.9, seed=0,
             segments=96, groove=0.12, cut_ends=True, adze=0.0):
    """A dense log along local X: vertical bark ridges with dark cracks,
    a lighter worn top, and sawn ends with growth rings and a bark rim."""
    bm = bmesh.new()
    rings_along = max(6, min(120, int(length / (radius * 0.08))))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius * taper,
                          depth=length)
    side = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > length * 0.5]
    bmesh.ops.subdivide_edges(bm, edges=side, cuts=rings_along, use_grid_fill=True)
    # Concentric rings on the sawn ends, so growth rings and the bark rim
    # have vertices to colour.
    caps = [f for f in bm.faces if abs(f.normal.z) > 0.9]
    for cap in caps:
        region = [cap]
        for k in range(4):
            res = bmesh.ops.inset_region(bm, faces=region, thickness=radius * (0.12 if k == 0 else 0.2), depth=0.0)
            region = [f for f in region if f.is_valid]
    bm.normal_update()
    half = length * 0.5
    for v in bm.verts:
        r = Vector((v.co.x, v.co.y)).length
        on_end = abs(abs(v.co.z) - half) < 1e-4 and r < radius * 0.97 * (taper if v.co.z > 0 else 1.0)
        a = math.atan2(v.co.y, v.co.x)
        wobble = 1.0 + noise.noise(Vector((v.co.z * 2.0, seed, 0))) * 0.06
        planed = adze and v.co.x < -radius * adze * 0.92
        if not on_end and r > 1e-6 and not planed:
            cut = 1.0 - _ridge(_bark_point(a, v.co.z, radius, seed))
            depth = cut * groove * radius
            scale = (r - depth) / r * wobble
            v.co.x *= scale
            v.co.y *= scale
        elif on_end:
            v.co.x *= wobble
            v.co.y *= wobble
            if cut_ends:
                # A slightly domed, saw-marked face.
                v.co.z += math.copysign(noise.noise(Vector((v.co.x * 9, v.co.y * 9, seed))) * radius * 0.04, v.co.z)
    if adze:
        # The build's -X becomes up after the rotation below.
        for v in bm.verts:
            v.co.x = max(v.co.x, -radius * adze)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    obj = common.mesh_object("bark_log", bm)
    common.shade_smooth(obj, auto_angle=60)
    end_r = radius

    def colour(pos, normal):
        rr = Vector((pos.y, pos.z)).length
        if abs(normal.x) > 0.75:
            t = rr / end_r
            if t > 0.86:
                return BARK_DARK
            rings = math.sin(t * 34.0 + noise.noise(Vector((pos.y * 6, pos.z * 6, seed))) * 2.0) * 0.5 + 0.5
            c = common.lerp(END_GRAIN, RING, rings * 0.45 + t * 0.3)
            if t < 0.1:
                c = common.lerp(c, RING, 0.6)
            return c
        if adze and normal.z > 0.9 and pos.z > end_r * adze * 0.9:
            grain = noise.noise(Vector((pos.x * 2.0, pos.y * 40.0, seed)))
            return common.lerp(SEAT, BARK_LIGHT, max(0.0, grain) * 0.8)
        # Undo the build rotation: (x, y, z) here was (z, y, -x) when built.
        ridge = _ridge(_bark_point(math.atan2(pos.y, -pos.z), pos.x, end_r, seed))
        fleck = noise.noise(Vector((pos.x * 30.0, pos.y * 30.0, pos.z * 30.0))) * 0.5 + 0.5
        strip = noise.noise(_bark_point(math.atan2(pos.y, -pos.z), pos.x, end_r, seed + 7) * 0.7) * 0.5 + 0.5
        c = common.lerp(BARK, BARK_LIGHT, strip * 0.8 * (0.6 + 0.4 * fleck))
        c = common.lerp(BARK_DARK, c, ridge)
        moss = noise.noise(Vector((pos.x * 2.0, pos.y * 3.0, pos.z * 3.0 + seed))) * 0.5 + 0.5
        if normal.z < -0.2 and moss > 0.6:
            c = common.lerp(c, (0.36, 0.42, 0.18), 0.5)
        return c
    common.color_by(obj, colour, smooth=True)
    obj.rotation_euler = rotation
    obj.location = location
    return obj


def plank(size, location=(0, 0, 0), rotation=(0, 0, 0), seed=0, base=(0.62, 0.4, 0.24),
          light=(0.8, 0.58, 0.34), dark=(0.36, 0.22, 0.13), bevel=0.012, density=0.025, knots=True):
    """A dense board (long axis local X): fine grain streaks, a knot or
    two, soft bevelled and lighter worn edges."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    obj = common.mesh_object("plank", bm)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = min(bevel, min(size) * 0.3)
    mod.segments = 2
    common.apply_all_modifiers(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    cuts = int(max(size) / density)
    for _ in range(2):
        long_edges = [e for e in bm.edges if (e.verts[0].co - e.verts[1].co).length > density * 1.5]
        if not long_edges:
            break
        bmesh.ops.subdivide_edges(bm, edges=long_edges, cuts=min(cuts, 24), use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    for v in obj.data.vertices:
        v.co.z += noise.noise(Vector((v.co.x * 1.5, seed, 0))) * size[2] * 0.08
    common.shade_smooth(obj, auto_angle=40)
    knot_at = [Vector((((seed * 0.37) % 1.0 - 0.5) * size[0] * 0.7, ((seed * 0.61) % 1.0 - 0.5) * size[1] * 0.5, 0))]
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5

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
        edge = max(abs(pos.x) / hx, abs(pos.y) / hy, abs(pos.z) / hz) if hx and hy and hz else 0
        if edge > 0.93:
            c = common.lerp(c, light, 0.35)
        return c
    common.color_by(obj, colour, smooth=True)
    obj.rotation_euler = rotation
    obj.location = location
    return obj
