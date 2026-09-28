"""Building blocks for the hand-made chibi kids (Leo and Nela).

The kids are modelled from scratch on the KayKit adventurer rig (same
skeleton and 76 animations for Rogue and Mage), in rest pose (T-pose,
facing -Y, right hand at -X):

* **Soft clothing and skin** (shirt, shorts or pants, arms, legs) are
  unions of primitives, voxel-remeshed into one watertight piece each
  and auto-weighted to the rig. Separate pieces overlap like real
  clothes, so hems and sleeves read as crisp edges.
* **Rigid parts** (head, face, hair, cap, hands, boots, backpack, gear)
  are bound 100% to one bone.
* **The face** is painted with single-sided decals that sit just above
  the head surface: eyes with irises and highlights, brows, a smile,
  freckles. Single-sided means the ink outline does not ring them.
"""

import math
import os

import bpy  # noqa: F401  (must precede bmesh / mathutils)
import bmesh
from mathutils import Matrix, Quaternion, Vector, noise

from lib import common

DEFORM = {"root", "hips", "spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
          "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "upperleg.l", "lowerleg.l", "foot.l", "toes.l",
          "upperleg.r", "lowerleg.r", "foot.r", "toes.r"}


# ---------------------------------------------------------------- rig

def load_rig():
    common.reset(7)
    bpy.ops.import_scene.gltf(filepath=os.path.join(common.KAYKIT, "adventurers", "Rogue.glb"))
    rig = bpy.data.objects["Rig"]
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj)
    for bone in rig.data.bones:
        bone.use_deform = bone.name in DEFORM
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    return rig


class Proportions:
    """Longer legs / torso / arms than the chibi KayKit rig (LoL kid-
    champion proportions). Everything is modelled in the original rig
    space, then `remap` moves both the bones and the meshes. Bones keep
    their directions, so the rotation-driven animations still work."""

    FOOT_TOP, HIP_TOP, NECK = 0.15, 0.52, 1.22
    ARM_IN, ARM_OUT = 0.21, 0.79

    def __init__(self, legs=1.0, spine=1.0, arms=1.0):
        self.legs, self.spine, self.arms = legs, spine, arms

    def z(self, z):
        if z <= self.FOOT_TOP:
            return z
        hip = self.FOOT_TOP + (self.HIP_TOP - self.FOOT_TOP) * self.legs
        if z <= self.HIP_TOP:
            return self.FOOT_TOP + (z - self.FOOT_TOP) * self.legs
        neck = hip + (self.NECK - self.HIP_TOP) * self.spine
        if z <= self.NECK:
            return hip + (z - self.HIP_TOP) * self.spine
        return neck + (z - self.NECK)

    def x(self, x, z):
        ax = abs(x)
        if ax <= self.ARM_IN:
            return x
        stretched = self.ARM_IN + (min(ax, self.ARM_OUT) - self.ARM_IN) * self.arms + max(0.0, ax - self.ARM_OUT)
        w = max(0.0, min(1.0, (z - 0.88) / 0.1))
        w = w * w * (3 - 2 * w)
        return math.copysign(ax + (stretched - ax) * w, x)

    def remap(self, v):
        return Vector((self.x(v.x, v.z), v.y, self.z(v.z)))

    @property
    def lift(self):
        """How much higher the neck (and so the head) sits."""
        return self.z(self.NECK + 0.01) - (self.NECK + 0.01)

    def stretch_mesh(self, obj):
        mw = obj.matrix_world.copy()
        inv = mw.inverted()
        for v in obj.data.vertices:
            v.co = inv @ self.remap(mw @ v.co)
        obj.data.update()

    def stretch_rig(self, rig):
        common.select_only([rig])
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")
        inv = rig.matrix_world.inverted()
        for eb in rig.data.edit_bones:
            head = self.remap(rig.matrix_world @ eb.head)
            tail = self.remap(rig.matrix_world @ eb.tail)
            roll = eb.roll
            eb.head, eb.tail = inv @ head, inv @ tail
            eb.roll = roll
        bpy.ops.object.mode_set(mode="OBJECT")
        # Scale the hips/root translation keys with the legs so crouches
        # and hops still meet the ground.
        for action in bpy.data.actions:
            for fc in action.fcurves:
                if fc.data_path.endswith("location") and ('"hips"' in fc.data_path or '"root"' in fc.data_path):
                    for kp in fc.keyframe_points:
                        kp.co.y *= self.legs
                        kp.handle_left.y *= self.legs
                        kp.handle_right.y *= self.legs
        bpy.context.view_layer.update()


def idle_hand_height(rig, bone="handslot.r"):
    """World height of a bone in the first frame of Idle (e.g. how long
    a walking stick must be to reach the ground)."""
    rig.data.pose_position = "POSE"
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions.get("Idle")
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    z = (rig.matrix_world @ rig.pose.bones[bone].matrix).translation.z
    rig.animation_data.action = None
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    return z


def place_in_hand(objects, rig, bone, action="Idle", frame=1):
    """Props modelled in world space around where the hand is in the
    idle pose (e.g. a plush dangling below it) are moved into the rest
    pose, so that rigidly bound to `bone` they hang right in idle and
    swing with the arm. Call after the rig is stretched."""
    rest = rig.matrix_world @ rig.data.bones[bone].matrix_local
    rig.data.pose_position = "POSE"
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions.get(action)
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    posed = rig.matrix_world @ rig.pose.bones[bone].matrix
    rig.animation_data.action = None
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    m = rest @ posed.inverted()
    for obj in objects:
        obj.data.transform(m)
    return posed.translation.copy()


def idle_bone_position(rig, bone, action="Idle", frame=1):
    rig.data.pose_position = "POSE"
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions.get(action)
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    pos = (rig.matrix_world @ rig.pose.bones[bone].matrix).translation.copy()
    rig.animation_data.action = None
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    return pos


def bone_frame(rig, name):
    return rig.matrix_world @ rig.data.bones[name].matrix_local


def auto_skin(obj, rig):
    common.select_only([obj, rig])
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def rigid(obj, bone):
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    return obj


# ---------------------------------------------------------- primitives

def ellipsoid(center, radii, name="ell", segs=(32, 20), rot=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs[0], v_segments=segs[1], radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
    if rot is not None:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=rot)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(center))
    obj = common.mesh_object(name, bm)
    common.shade_smooth(obj)
    return obj


def tube(points, radii, name="tube", levels=1, sides=None):
    """Skin-modifier tube through points with per-point radii."""
    bm = bmesh.new()
    verts = [bm.verts.new(Vector(p)) for p in points]
    for a, b in zip(verts, verts[1:]):
        bm.edges.new((a, b))
    obj = common.mesh_object(name, bm)
    obj.modifiers.new("Skin", "SKIN")
    bm2 = bmesh.new()
    bm2.from_mesh(obj.data)
    bm2.verts.ensure_lookup_table()
    layer = bm2.verts.layers.skin.verify()
    for v, r in zip(bm2.verts, radii):
        rx, ry = (r, r) if not isinstance(r, (tuple, list)) else r
        v[layer].radius = (rx, ry)
    bm2.verts[0][layer].use_root = True
    bm2.to_mesh(obj.data)
    bm2.free()
    if levels:
        sub = obj.modifiers.new("Sub", "SUBSURF")
        sub.levels = levels
    common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    return obj


def limb(points, radii, up=(0, 0, 1), name="limb", ring=16, cap=True):
    """A lofted limb: elliptical sections along a polyline, per-point radii
    (w, d): w across `up` x tangent, d along the section's up direction.
    For stylised anatomy (flattened wrists, calf and forearm swells) that
    tubes can't do. Ends are capped (to be fused/remeshed afterwards)."""
    ups = [Vector(u).normalized() for u in up] if isinstance(up[0], (tuple, list, Vector)) else None
    up = Vector(up[0] if ups else up).normalized()
    pts = [Vector(p) for p in points]
    bm = bmesh.new()
    rings = []
    n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(n - 1, i + 1)] - pts[max(0, i - 1)]).normalized()
        b = t.cross(ups[i] if ups else up)
        if b.length < 1e-5:
            b = t.orthogonal()
        b.normalize()
        nrm = b.cross(t).normalized()
        rw, rd = radii[i] if isinstance(radii[i], (tuple, list)) else (radii[i], radii[i])
        rings.append([bm.verts.new(p + b * math.cos(k / ring * math.tau) * rw + nrm * math.sin(k / ring * math.tau) * rd)
                      for k in range(ring)])
    for a, c in zip(rings, rings[1:]):
        for k in range(ring):
            bm.faces.new((a[k], a[(k + 1) % ring], c[(k + 1) % ring], c[k]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = common.mesh_object(name, bm)
    common.shade_smooth(obj)
    return obj


def cylinder(center, radius, depth, name="cyl", segments=24, axis="Z", radius2=None, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(center))
    obj = common.mesh_object(name, bm)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        common.apply_all_modifiers(obj)
    common.shade_smooth(obj, auto_angle=40)
    return obj


def box(size, center, bevel=0.03, name="box", segments=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(center)
    obj = common.mesh_object(name, bm)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        common.apply_all_modifiers(obj)
    common.shade_smooth(obj, auto_angle=40)
    return obj


def torus(center, major, minor, name="torus", axis="Z", segs=(24, 8)):
    bm = bmesh.new()
    verts = []
    for i in range(segs[0]):
        a = i / segs[0] * math.tau
        ring = []
        for j in range(segs[1]):
            b = j / segs[1] * math.tau
            r = major + math.cos(b) * minor
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, math.sin(b) * minor)))
        verts.append(ring)
    for i in range(segs[0]):
        for j in range(segs[1]):
            a, b = verts[i][j], verts[(i + 1) % segs[0]][j]
            c, d = verts[(i + 1) % segs[0]][(j + 1) % segs[1]], verts[i][(j + 1) % segs[1]]
            bm.faces.new((a, b, c, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(center))
    obj = common.mesh_object(name, bm)
    common.shade_smooth(obj)
    return obj


def decimate_tris(obj, target):
    """Collapse-decimates to about `target` triangles."""
    for _ in range(3):
        tris = common.triangle_count([obj])
        if tris <= target * 1.08:
            return
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = target / tris
        common.apply_all_modifiers(obj)


def fuse(parts, name, voxel=0.014, smooth=2, faces=None):
    """Union of overlapping closed primitives -> one watertight mesh.
    faces: triangle budget."""
    obj = common.join(parts, name)
    common.voxel_remesh(obj, voxel=voxel, smooth_iterations=smooth)
    if faces:
        decimate_tris(obj, faces)
    common.shade_smooth(obj)
    return obj


def fold(obj, centre, radii, depth, wavelength=0.05, across=None, radial_axis=None, count=6, sharp=2.5,
         twist=0.0, seed=0):
    """Sculpts cloth folds into a mesh (MOBA style: crisp crests, soft
    valleys), along vertex normals, inside a soft ellipsoid region.
    across: ridges alternate along this direction (compression folds,
    sleeve rings). radial_axis: ridges radiate around this axis through
    `centre` (armpits, crotch, gathered cuffs). twist bends ridges."""
    import numpy as np
    mesh = obj.data
    n = len(mesh.vertices)
    co = np.empty(n * 3)
    nr = np.empty(n * 3)
    mesh.vertices.foreach_get("co", co)
    mesh.vertices.foreach_get("normal", nr)
    co = co.reshape(n, 3)
    nr = nr.reshape(n, 3)
    rel = co - np.array(centre)
    d2 = ((rel / np.array(radii)) ** 2).sum(1)
    mask = np.clip(1.0 - d2, 0.0, 1.0) ** 2
    rng = np.random.default_rng(seed)
    if radial_axis is not None:
        ax = np.array(Vector(radial_axis).normalized())
        ref = np.array(Vector(radial_axis).orthogonal().normalized())
        ref2 = np.cross(ax, ref)
        ang = np.arctan2(rel @ ref2, rel @ ref)
        dist = np.linalg.norm(rel - np.outer(rel @ ax, ax), axis=1)
        phase = ang * count + twist * dist / max(radii) * math.pi
        # Radiating folds fade in away from the pinch point.
        mask = mask * np.clip(dist / (min(radii) * 0.35), 0.0, 1.0)
    else:
        a = np.array(Vector(across).normalized())
        along = rel @ a
        side = np.linalg.norm(rel - np.outer(along, a), axis=1)
        phase = along / wavelength * math.tau + twist * np.sin(side / max(radii) * math.pi)
    phase = phase + rng.uniform(0, math.tau)
    wave = np.cos(phase)
    crest = np.clip(wave, 0.0, 1.0) ** sharp
    valley = np.clip(-wave, 0.0, 1.0) ** 1.2
    amp = 0.75 + 0.25 * np.sin(phase * 0.37 + 1.3)
    disp = depth * (crest - 0.35 * valley) * mask * amp
    mesh.vertices.foreach_set("co", (co + nr * disp[:, None]).ravel())
    mesh.update()


def hem_ring(center, radii, minor, name="hem", axis="Z", segs=(28, 8)):
    """A rolled hem: an elliptical torus (radii along the two in-plane axes)."""
    t = torus(center, 1.0, minor, name=name, axis=axis, segs=segs)
    c = Vector(center)
    ax = {"X": (1, 2), "Y": (0, 2), "Z": (0, 1)}[axis]
    for v in t.data.vertices:
        rel = v.co - c
        # Scale the ring (not the tube) to the ellipse radii.
        ring = Vector([rel[i] if i in ax else 0.0 for i in range(3)])
        L = ring.length or 1.0
        unit = ring / L
        tube = rel - unit * 1.0
        target = Vector([unit[i] * (radii[ax.index(i)] if i in ax else 0.0) for i in range(3)])
        v.co = c + target + tube
    t.data.update()
    return t


def cut_open(obj, point, normal):
    """Cuts a hem: removes everything past the plane. The cloth is left
    single-sided: the ink-outline pass draws its inside dark, which
    reads as the shadowed inside of a sleeve or trouser leg."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(point), plane_no=Vector(normal), clear_outer=True)
    bm.to_mesh(obj.data)
    bm.free()
    common.shade_smooth(obj)


def wavy_lock(root, direction, length, radius, side_vec, wave=0.03, waves=1.5, bend=(0, 0, 0), steps=5,
              name="lock", tip=0.012):
    """A tapered lock that ripples sideways (wavy hair)."""
    d = Vector(direction).normalized()
    side_vec = Vector(side_vec).normalized()
    bend = Vector(bend)
    points, radii = [], []
    for i in range(steps):
        t = i / (steps - 1)
        wobble = side_vec * math.sin(t * math.pi * 2 * waves) * wave * t
        points.append(Vector(root) + d * (length * t) + bend * (t * t) + wobble)
        radii.append(radius * (1.0 - t) ** 0.8 + tip * t)
    return tube(points, radii, name=name, levels=1)


def curved_lock(root, direction, length, radius, bend=(0, 0, 0), steps=4, name="lock", tip=0.012):
    """A tapered, bending hair lock / horn: root -> direction, bending."""
    d = Vector(direction).normalized()
    bend = Vector(bend)
    points, radii = [], []
    for i in range(steps):
        t = i / (steps - 1)
        points.append(Vector(root) + d * (length * t) + bend * (t * t))
        radii.append(radius * (1.0 - t) ** 0.9 + tip * t)
    return tube(points, radii, name=name, levels=1)


# --------------------------------------------------------------- face

class HeadFrame:
    """An ellipsoid head: maps (yaw, pitch) or face-plane (u, v) metres
    to surface points and normals. yaw 0 = straight ahead (-Y)."""

    def __init__(self, center, radii):
        self.c = Vector(center)
        self.r = Vector(radii)
        self.bvh = None

    def bind(self, obj):
        """Project onto a sculpted head mesh (ray-cast) from now on."""
        from mathutils.bvhtree import BVHTree
        mesh = obj.data
        verts = [obj.matrix_world @ v.co for v in mesh.vertices]
        polys = [tuple(p.vertices) for p in mesh.polygons]
        self.bvh = BVHTree.FromPolygons(verts, polys)

    def point(self, yaw, pitch, lift=0.0):
        d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
        p = self.c + Vector((d.x * self.r.x, d.y * self.r.y, d.z * self.r.z))
        n = Vector(((p.x - self.c.x) / self.r.x ** 2, (p.y - self.c.y) / self.r.y ** 2,
                    (p.z - self.c.z) / self.r.z ** 2)).normalized()
        if self.bvh is not None:
            origin = self.c + (p - self.c) * 3.0
            hit, normal, _, _ = self.bvh.ray_cast(origin, (self.c - origin).normalized())
            if hit is not None:
                if normal.dot(p - self.c) < 0:
                    normal = -normal
                return hit + normal * lift, normal
        return p + n * lift, n

    def uv_point(self, yaw0, pitch0, u, v, lift):
        pitch = pitch0 + v / self.r.z
        yaw = yaw0 + u / (self.r.x * max(0.3, math.cos(pitch)))
        return self.point(yaw, pitch, lift)

    def _finish(self, bm, name, colour_fn, per_face):
        # Single-sided: make every face point away from the head.
        for f in bm.faces:
            f.normal_update()
            if f.normal.dot(f.calc_center_median() - self.c) < 0:
                f.normal_flip()
        obj = common.mesh_object(name, bm)
        common.shade_smooth(obj)
        common.color_by(obj, colour_fn, smooth=not per_face)
        return obj

    def patch(self, yaw0, pitch0, u0, u1, bottom, top, lift, colour, name="decal", nu=16, nv=6, per_face=False):
        """Region between two curves v=bottom(u) and v=top(u), u in [u0,u1].
        colour: sRGB tuple, or fn(u, v) -> sRGB (evaluated per vertex)."""
        bm = bmesh.new()
        grid = []
        uv_of = {}
        for i in range(nu + 1):
            u = u0 + (u1 - u0) * i / nu
            row = []
            for j in range(nv + 1):
                v = bottom(u) + (top(u) - bottom(u)) * j / nv
                p, _ = self.uv_point(yaw0, pitch0, u, v, lift)
                vert = bm.verts.new(p)
                uv_of[vert] = (u, v)
                row.append(vert)
            grid.append(row)
        for i in range(nu):
            for j in range(nv):
                quad = (grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1])
                if len({q.co.to_tuple(6) for q in quad}) >= 3:
                    try:
                        bm.faces.new(quad)
                    except ValueError:
                        pass
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        lookup = {tuple(round(c, 5) for c in vert.co): uv for vert, uv in uv_of.items() if vert.is_valid}
        fn = colour if callable(colour) else (lambda u, v: colour)

        def colour_fn(pos, normal):
            uv = lookup.get(tuple(round(c, 5) for c in pos))
            return fn(*uv) if uv else fn(0.0, 0.0)
        return self._finish(bm, name, colour_fn, per_face)

    def ellipse(self, yaw0, pitch0, rx, ry, lift, colour, name="ellipse", du=0.0, dv=0.0, nu=12, nv=4):
        return self.patch(yaw0, pitch0, du - rx, du + rx,
                          lambda u: dv - ry * math.sqrt(max(0.0, 1 - ((u - du) / rx) ** 2)),
                          lambda u: dv + ry * math.sqrt(max(0.0, 1 - ((u - du) / rx) ** 2)),
                          lift, colour, name=name, nu=nu, nv=nv)

    def ribbon(self, yaw0, pitch0, points, widths, lift, colour, name="ribbon"):
        """A painted stroke along face-plane points with tapering widths."""
        bm = bmesh.new()
        left, right = [], []
        n = len(points)
        for i, (u, v) in enumerate(points):
            a = points[max(0, i - 1)]
            b = points[min(n - 1, i + 1)]
            tx, ty = b[0] - a[0], b[1] - a[1]
            length = math.hypot(tx, ty) or 1.0
            nx, ny = -ty / length, tx / length
            w = widths[i] * 0.5
            left.append(bm.verts.new(self.uv_point(yaw0, pitch0, u + nx * w, v + ny * w, lift)[0]))
            right.append(bm.verts.new(self.uv_point(yaw0, pitch0, u - nx * w, v - ny * w, lift)[0]))
        for i in range(n - 1):
            bm.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
        return self._finish(bm, name, lambda p, nrm: colour, per_face=True)


def eye(head, yaw, pitch, side, iris, iris_dark, lash, size=1.0, look=(0.0, 0.01), name="eye"):
    """A big cartoon eye: dark liner, white, gradient iris, pupil, two
    highlights and a thick upper lash line with a little flick."""
    parts = []
    rx, ry = 0.068 * size, 0.084 * size
    parts.append(head.ellipse(yaw, pitch, rx + 0.008, ry + 0.008, 0.003, lash, name=name + "_liner"))
    parts.append(head.ellipse(yaw, pitch, rx, ry, 0.005, (1.0, 1.0, 1.0), name=name + "_white"))
    ir = 0.05 * size
    iu, iv = look[0] * side * -1.0, look[1]

    def iris_colour(u, v):
        d = math.hypot(u - iu, v - iv) / ir
        t = max(0.0, min(1.0, (v - iv) / ir * 0.5 + 0.5))
        c = common.lerp(iris, iris_dark, t * 0.8)
        return common.lerp(c, iris_dark, max(0.0, (d - 0.72) / 0.28))
    parts.append(head.ellipse(yaw, pitch, ir, ir * 1.12, 0.0065, iris_colour, du=iu, dv=iv, name=name + "_iris", nv=5))
    parts.append(head.ellipse(yaw, pitch, ir * 0.5, ir * 0.56, 0.0078, (0.05, 0.06, 0.12), du=iu, dv=iv,
                              name=name + "_pupil"))
    parts.append(head.ellipse(yaw, pitch, ir * 0.36, ir * 0.36, 0.009, (1.0, 1.0, 1.0),
                              du=iu - ir * 0.3 * side * -1.0, dv=iv + ir * 0.38, name=name + "_hi"))
    parts.append(head.ellipse(yaw, pitch, ir * 0.16, ir * 0.16, 0.009, (1.0, 1.0, 1.0),
                              du=iu + ir * 0.38 * side * -1.0, dv=iv - ir * 0.4, name=name + "_hi2"))
    # Upper lash line hugging the top of the eye, with an outer flick.
    pts, widths = [], []
    for k in range(9):
        a = math.pi * (0.95 - 0.9 * k / 8)
        pts.append((math.cos(a) * (rx + 0.004), math.sin(a) * (ry + 0.004) * 0.92 + 0.004))
        widths.append(0.02 * size * (0.55 + 0.45 * math.sin(math.pi * k / 8)))
    outer = pts[0] if side > 0 else pts[-1]
    flick = (outer[0] + (0.028 if side > 0 else -0.028) * size * -1.0, outer[1] + 0.01)
    if side > 0:
        pts = [flick] + pts
        widths = [0.006] + widths
    else:
        pts = pts + [flick]
        widths = widths + [0.006]
    parts.append(head.ribbon(yaw, pitch, pts, widths, 0.0085, lash, name=name + "_lash"))
    return parts


def smile(head, pitch, width, depth, lift, lip=(0.5, 0.12, 0.14), inner=(0.35, 0.05, 0.1), teeth=True,
          tongue=(0.95, 0.45, 0.5), curve=2.2):
    """Open, happy mouth: a D shape with teeth on top and a tongue."""
    parts = []
    top = lambda u: curve * u * u * 0.6 + 0.002  # noqa: E731
    bottom = lambda u: -depth * math.sqrt(max(0.0, 1 - (u / width) ** 2)) + curve * u * u * 0.6  # noqa: E731
    parts.append(head.patch(0, pitch, -width - 0.006, width + 0.006,
                            lambda u: bottom(u * width / (width + 0.006)) - 0.006,
                            lambda u: top(u) + 0.006, lift, lip, name="mouth_lip", nu=20, nv=4))
    parts.append(head.patch(0, pitch, -width, width, bottom, top, lift + 0.002, inner, name="mouth", nu=20, nv=4))
    if teeth:
        parts.append(head.patch(0, pitch, -width * 0.7, width * 0.7,
                                lambda u: top(u) - depth * 0.3, top, lift + 0.004, (1.0, 0.98, 0.95),
                                name="teeth", nu=12, nv=2))
    tw = width * 0.5
    parts.append(head.patch(0, pitch, -tw, tw, lambda u: bottom(u) + 0.004,
                            lambda u: bottom(u) + depth * 0.45 * math.sqrt(max(0.0, 1 - (u / tw) ** 2)),
                            lift + 0.004, tongue, name="tongue", nu=12, nv=3))
    return parts


def brow(head, yaw, pitch, side, colour, width=0.075, arch=0.012, thick=0.018, tilt=0.0):
    """tilt > 0 raises the outer end (confident / cheeky)."""
    pts = []
    widths = []
    for k in range(7):
        t = k / 6
        u = (t - 0.5) * width
        v = arch * math.sin(math.pi * t) + (0.006 * (t - 0.5) * side * -1.0) + tilt * u * side
        pts.append((u, v))
        widths.append(thick * (0.4 + 0.6 * math.sin(math.pi * (0.2 + 0.7 * t))))
    return head.ribbon(yaw, pitch, pts, widths, 0.006, colour, name="brow")


def sculpt_head(head, skin, skin_shade, blush, jaw=0.3, chin_len=0.15, chin_fwd=0.08, cheeks=0.0,
                cheekbone=0.0, face_flat=0.08, back_flat=0.08, blush_yaw=0.62, blush_pitch=-0.3,
                blush_size=0.09, name="head", layout=None, features=None, tris=11000):
    """A stylised head: an egg-shaped cranium with the lower face
    tapered to a chin (jaw), the chin pulled down/forward, optional
    chubby cheeks or cheekbones, a flatter face plane and back. Binds
    the HeadFrame to it so the face decals follow the real surface."""
    obj = ellipsoid(head.c, head.r, name=name, segs=(176, 132) if layout else (48, 32))
    r = head.r
    for v in obj.data.vertices:
        rel = v.co - head.c
        nx, ny, nz = rel.x / r.x, rel.y / r.y, rel.z / r.z
        lower = max(0.0, -nz)
        front = max(0.0, -ny)
        # Jaw taper toward the chin.
        rel.x *= 1.0 - jaw * lower ** 1.4
        # Chin: longer and a little forward at the front centre.
        centre = max(0.0, 1.0 - abs(nx) * 1.6)
        rel.z -= chin_len * r.z * lower ** 2 * front ** 0.5 * centre
        rel.y -= chin_fwd * r.y * lower ** 2 * front * centre
        # Flatter face plane and back of the head.
        if ny < 0:
            rel.y *= 1.0 - face_flat * front ** 2
        else:
            rel.y *= 1.0 - back_flat * ny ** 2
        # Chubby cheeks (lower front sides) or cheekbones (mid sides).
        side = abs(nx)
        if cheeks:
            k = math.exp(-((nz + 0.35) ** 2) / 0.08) * math.exp(-((side - 0.65) ** 2) / 0.1) * front
            rel.x *= 1.0 + cheeks * k
            rel.y -= cheeks * 0.5 * k * r.y
        if cheekbone:
            k = math.exp(-((nz + 0.05) ** 2) / 0.03) * math.exp(-((side - 0.8) ** 2) / 0.05) * front
            rel.x *= 1.0 + cheekbone * k
        v.co = head.c + rel
    mod = obj.modifiers.new("Smooth", "SMOOTH")
    mod.iterations = 2
    mod.factor = 0.5
    common.apply_all_modifiers(obj)
    if layout is not None:
        sculpt_features(obj, head, layout, **(features or {}))
        decimate_tris(obj, tris)
    common.shade_smooth(obj)
    head.bind(obj)
    cheek_pts = [head.point(side * blush_yaw, blush_pitch)[0] for side in (-1, 1)]

    def colour(pos, normal):
        c = common.lerp(skin, skin_shade, max(0.0, min(1.0, -normal.z * 0.7)))
        for ch in cheek_pts:
            d = (pos - ch).length
            if d < blush_size:
                c = common.lerp(c, blush, (1.0 - d / blush_size) ** 1.5 * 0.7)
        return c
    common.color_by(obj, colour)
    return obj


def sculpt_features(obj, head, L, socket=0.012, eyeball=0.005, brow=0.01, nose=0.028, lips=0.008, chin=0.008,
                    cheekbone=0.0):
    """Carves LoL-style facial relief into the front of a head using the
    same FaceLayout as the painted face: eye sockets with a slight
    eyeball, brow ridge, nose bridge/tip/wings, lips, philtrum, chin and
    optional cheekbones. Displaces along -Y (toward the viewer)."""
    c, r = head.c, head.r

    def g(u, w, cu, cw, su, sw):
        return math.exp(-((u - cu) / su) ** 2 - ((w - cw) / sw) ** 2)

    for v in obj.data.vertices:
        rel = v.co - c
        front = max(0.0, min(1.0, (-rel.y / r.y - 0.35) / 0.4))
        if front <= 0.0:
            continue
        u, w = rel.x, rel.z
        d = 0.0
        for side in (-1, 1):
            ex = side * L.eye_x
            d -= socket * g(u, w, ex, L.eye_z + L.eye_h * 0.4, L.eye_w * 1.4, L.eye_h * 2.6)
            d += eyeball * g(u, w, ex, L.eye_z, L.eye_w * 0.95, L.eye_h * 1.2)
            d += brow * g(u, w, ex * 0.95, L.eye_z + L.eye_h * 2.8, L.eye_w * 1.7, L.eye_h * 1.1)
            d += nose * 0.35 * g(u, w, side * L.nose_w * 0.8, L.nose_z - 0.002, L.nose_w * 0.5, 0.01)
            if cheekbone:
                d += cheekbone * g(u, w, side * (L.eye_x + L.eye_w * 0.7), L.eye_z - 0.05, 0.04, 0.028)
        d += brow * 0.7 * g(u, w, 0.0, L.eye_z + L.eye_h * 2.2, L.eye_w * 0.8, L.eye_h * 1.2)
        span = max(0.02, L.eye_z - L.nose_z)
        d += nose * 0.55 * g(u, w, 0.0, (L.eye_z + L.nose_z) * 0.5, L.nose_w * 0.5, span * 0.55)
        d += nose * g(u, w, 0.0, L.nose_z + 0.004, L.nose_w * 0.75, 0.014)
        d -= 0.002 * g(u, w, 0.0, (L.nose_z + L.mouth_z) * 0.5, 0.006, 0.012)
        d += lips * g(u, w, 0.0, L.mouth_z + L.lip_upper * 0.6, L.mouth_w * 0.95, L.lip_upper * 1.3)
        d += lips * 1.2 * g(u, w, 0.0, L.mouth_z - L.lip_lower * 0.6, L.mouth_w * 0.85, L.lip_lower * 1.1)
        d -= lips * 0.5 * g(u, w, 0.0, L.mouth_z, L.mouth_w * 1.1, 0.003)
        d += chin * g(u, w, 0.0, L.chin_z + 0.02, 0.035, 0.03)
        v.co.y -= d * front
    obj.data.update()


def face_uv(obj, head, L, name="FaceUV"):
    """Front-projected UVs matching the face_paint image space."""
    mesh = obj.data
    layer = mesh.uv_layers.get(name) or mesh.uv_layers.new(name=name)
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        layer.data[loop.index].uv = (0.5 + (co.x - head.c.x) / (2 * L.size), 0.5 + (co.z - head.c.z) / (2 * L.size))


def no_face_uv(obj, name="FaceUV"):
    """Parts that must not receive face paint sample the empty corner."""
    mesh = obj.data
    layer = mesh.uv_layers.get(name) or mesh.uv_layers.new(name=name)
    for d in layer.data:
        d.uv = (0.002, 0.002)


def almond_eye(head, yaw, pitch, side, w, h, iris, iris_dark, lash, tilt=0.0, iris_r=None, look=(0.0, 0.0),
               lower_lid=(0.55, 0.32, 0.26), flicks=0, sclera=(0.99, 0.98, 0.96), name="eye", lid_drop=0.0,
               lid_scale=1.0, pupil=0.45, big_highlight=0.3):
    """A LoL-style almond eye: pointed corners, an arched top and flatter
    bottom, a big iris clipped to the eye shape, a thick tapered upper lid
    that wings past the outer corner, a thin lower lid and one highlight.
    side: +1 = the character's left eye (screen right). tilt > 0 lifts
    the outer corner."""
    out = side  # outward direction in face-plane u (the head is viewed from the front)
    ir = iris_r or h * 0.95

    def top(u):
        # lid_drop flattens the top: a heavy, half-lidded (cocky) look.
        t = max(0.0, 1.0 - (u / w) ** 2)
        return h * (1.0 - lid_drop) * t ** (0.62 + lid_drop) + tilt * u * out

    def bottom(u):
        t = max(0.0, 1.0 - (u / w) ** 2)
        return -h * 0.62 * t ** 0.85 + tilt * u * out

    parts = []
    parts.append(head.patch(yaw, pitch, -w - 0.006, w + 0.006, lambda u: bottom(u) - 0.005, lambda u: top(u) + 0.005,
                            0.003, lash, name=name + "_liner", nu=16, nv=3))
    parts.append(head.patch(yaw, pitch, -w, w, bottom, top, 0.005, sclera, name=name + "_white", nu=16, nv=4))
    iu, iv = look[0] * out, look[1]

    def iris_colour(u, v):
        d = math.hypot(u - iu, v - iv) / ir
        t = max(0.0, min(1.0, (v - iv) / ir * 0.5 + 0.5))
        c = common.lerp(iris, iris_dark, t * 0.85)
        return common.lerp(c, iris_dark, max(0.0, (d - 0.7) / 0.3))

    def clipped(radius, dz=0.0):
        lo, hi = max(-w, iu - radius), min(w, iu + radius)
        return (lo, hi,
                lambda u: max(bottom(u), iv - radius * math.sqrt(max(0.0, 1 - ((u - iu) / radius) ** 2))),
                lambda u: min(top(u), iv + radius * math.sqrt(max(0.0, 1 - ((u - iu) / radius) ** 2))))
    lo, hi, b, t = clipped(ir)
    parts.append(head.patch(yaw, pitch, lo, hi, b, t, 0.0065, iris_colour, name=name + "_iris", nu=12, nv=5))
    lo, hi, b, t = clipped(ir * pupil)
    parts.append(head.patch(yaw, pitch, lo, hi, b, t, 0.0078, (0.04, 0.05, 0.1), name=name + "_pupil", nu=8, nv=3))
    hr = ir * big_highlight
    parts.append(head.ellipse(yaw, pitch, hr, hr, 0.009, (1.0, 1.0, 1.0), du=iu - ir * 0.35 * out * -1.0,
                              dv=iv + ir * 0.35, name=name + "_hi", nu=8, nv=3))
    # Thick upper lid: tapered at the inner corner, winged at the outer.
    pts, widths = [], []
    for k in range(11):
        u = -w + 2 * w * k / 10
        uu = u * out  # inner (-) to outer (+)
        pts.append((u, top(u) + 0.004))
        widths.append((0.006 + 0.014 * max(0.0, min(1.0, (uu / w + 1.0) * 0.6))) * lid_scale)
    order = sorted(range(len(pts)), key=lambda i: pts[i][0] * out)
    pts = [pts[i] for i in order]
    widths = [widths[i] for i in order]
    wing = (pts[-1][0] + 0.022 * out, pts[-1][1] + 0.012 + tilt * 0.02)
    pts.append(wing)
    widths.append(0.004)
    parts.append(head.ribbon(yaw, pitch, pts, widths, 0.0085, lash, name=name + "_lid"))
    for f in range(flicks):
        base = pts[-3 - f * 2]
        parts.append(head.ribbon(yaw, pitch, [base, (base[0] + 0.014 * out, base[1] + 0.02)], [0.006, 0.002],
                                 0.0086, lash, name=name + "_lash"))
    # Thin lower lid on the outer half.
    lower = [(u, bottom(u) - 0.003) for u in [w * out * k / 6 for k in range(1, 7)]]
    lower.sort(key=lambda p: p[0] * out)
    parts.append(head.ribbon(yaw, pitch, lower, [0.004] * len(lower), 0.0082, lower_lid, name=name + "_lower"))
    return parts


def smirk(head, pitch, width, lift, lip=(0.55, 0.16, 0.16), inner=(0.32, 0.06, 0.09), side=-1, open_depth=0.018):
    """A confident lopsided grin: a curved mouth line rising to one side,
    open on that side with a flash of teeth."""
    parts = []
    curve = lambda u: 1.4 * u * u + 0.18 * u * side  # noqa: E731
    lo, hi = -width, width
    # Opening, biased to the raised side.
    cu = width * 0.25 * side

    def top(u):
        return curve(u) + 0.002

    def bottom(u):
        t = max(0.0, 1.0 - ((u - cu) / (width * 0.8)) ** 2)
        return curve(u) - open_depth * math.sqrt(t)
    parts.append(head.patch(0, pitch, lo, hi, lambda u: bottom(u) - 0.004, lambda u: top(u) + 0.003, lift, lip,
                            name="mouth_lip", nu=20, nv=3))
    parts.append(head.patch(0, pitch, lo * 0.95, hi * 0.95, bottom, top, lift + 0.002, inner, name="mouth", nu=20, nv=3))
    parts.append(head.patch(0, pitch, cu - width * 0.6, cu + width * 0.6, lambda u: top(u) - open_depth * 0.45, top,
                            lift + 0.004, (1.0, 0.98, 0.95), name="teeth", nu=10, nv=2))
    # Dimple crease at the raised corner.
    end = (hi * side if side > 0 else lo, curve(hi * side if side > 0 else lo))
    parts.append(head.ribbon(0, pitch, [end, (end[0] + 0.012 * side, end[1] + 0.014)], [0.005, 0.002], lift + 0.001,
                             (0.78, 0.45, 0.38), name="dimple"))
    return parts


def hair_clump(points, widths, thickness, up, name="clump", ring=8, crescent=0.45, sharp=False, twist=0.0):
    """A big sculpted LoL hair clump: a flattened, slightly cupped
    ribbon-tube along points, tapering to a sharp tip.
    widths/thickness: per point (or scalar thickness ratio).
    sharp: lens-shaped section pinched to crisp side edges, no subsurf
    (MOBA-style hard hair planes). twist: radians of roll along the clump."""
    up = Vector(up).normalized()
    bm = bmesh.new()
    rings = []
    n = len(points)
    pts = [Vector(p) for p in points]
    for i, p in enumerate(pts):
        t = (pts[min(n - 1, i + 1)] - pts[max(0, i - 1)]).normalized()
        b = t.cross(up)
        if b.length < 1e-4:
            b = t.orthogonal()
        b.normalize()
        nrm = b.cross(t).normalized()
        w = widths[i]
        th = w * (thickness if not isinstance(thickness, (list, tuple)) else thickness[i])
        if i == n - 1 or w < 1e-4:
            rings.append([bm.verts.new(p)])
            continue
        if twist:
            q = Quaternion(t, twist * i / max(1, n - 1))
            b = q @ b
            nrm = q @ nrm
        ring_verts = []
        for k in range(ring):
            a = k / ring * math.tau
            ca, sa = math.cos(a), math.sin(a)
            if sharp:
                # Lens: full thickness in the middle, pinched at the edges.
                lens = math.copysign(abs(sa) ** 1.6, sa)
                off = b * (ca * w) + nrm * (lens * th - crescent * th * ca * ca)
            else:
                off = b * (ca * w) + nrm * (sa * th - crescent * th * ca * ca)
            ring_verts.append(bm.verts.new(p + off))
        rings.append(ring_verts)
    for i in range(n - 1):
        a, c = rings[i], rings[i + 1]
        for k in range(ring):
            k2 = (k + 1) % ring
            if len(c) == 1:
                bm.faces.new((a[k], a[k2], c[0]))
            else:
                bm.faces.new((a[k], a[k2], c[k2], c[k]))
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = common.mesh_object(name, bm)
    if not sharp:
        sub = obj.modifiers.new("Sub", "SUBSURF")
        sub.levels = 1
        common.apply_all_modifiers(obj)
    common.shade_smooth(obj)
    return obj


def sweep(root, controls, steps=7):
    """Points along a quadratic/cubic Bezier from root through controls."""
    pts = [Vector(root)] + [Vector(c) for c in controls]
    out = []
    for i in range(steps):
        t = i / (steps - 1)
        work = [p.copy() for p in pts]
        while len(work) > 1:
            work = [work[j].lerp(work[j + 1], t) for j in range(len(work) - 1)]
        out.append(work[0])
    return out


def head_mesh(head, skin, skin_shade, blush, jaw=0.14, name="head"):
    """Round head ellipsoid, a little narrower at the jaw, with rosy
    cheeks painted into the vertex colours."""
    obj = ellipsoid(head.c, head.r, name=name, segs=(44, 28))
    for v in obj.data.vertices:
        rel = (v.co - head.c)
        t = max(0.0, -rel.z / head.r.z)
        v.co.x = head.c.x + rel.x * (1.0 - jaw * t * t)
        if rel.y < 0:
            v.co.y = head.c.y + rel.y * (1.0 - jaw * 0.5 * t * t)
    cheeks = [head.point(side * 0.62, -0.28)[0] for side in (-1, 1)]

    def colour(pos, normal):
        c = common.lerp(skin, skin_shade, max(0.0, min(1.0, -normal.z * 0.6)))
        for ch in cheeks:
            d = (pos - ch).length
            if d < 0.11:
                c = common.lerp(c, blush, (1.0 - d / 0.11) ** 1.4 * 0.75)
        return c
    common.color_by(obj, colour)
    return obj


def ears(head, skin, inner, yaw=1.45, pitch=-0.08):
    parts = []
    for side in (-1, 1):
        p, n = head.point(side * yaw, pitch)
        e = ellipsoid(p + n * 0.01, (0.05, 0.04, 0.075), name="ear", segs=(16, 10))
        common.color_by(e, lambda pos, nrm, n=n: inner if nrm.dot(n) > 0.6 else skin, smooth=False)
        parts.append(e)
    return parts


def nose(head, skin, pitch=-0.16):
    p, n = head.point(0, pitch)
    obj = ellipsoid(p - n * 0.004, (0.03, 0.024, 0.022), name="nose", segs=(16, 10))
    common.set_color(obj, skin)
    return obj


def flatten_along(obj, origin, direction, factor):
    """Squashes a mesh along one direction (e.g. a hair lock against the head)."""
    d = Vector(direction).normalized()
    o = Vector(origin)
    for v in obj.data.vertices:
        rel = v.co - o
        along = rel.dot(d)
        v.co = o + rel - d * along * (1.0 - factor)


def lock_colour(root, length, light, mid, dark):
    """Dark roots to sunny tips, with a little noise."""
    root = Vector(root)

    def colour(pos, normal):
        t = min(1.0, (pos - root).length / length)
        n = noise.noise(pos * 14.0) * 0.2
        t = max(0.0, min(1.0, t * 1.1 + n + normal.z * 0.15))
        return common.lerp(dark, mid, t / 0.45) if t < 0.45 else common.lerp(mid, light, (t - 0.45) / 0.55)
    return colour


def hair_colour(light, mid, dark, center, scale=6.0, strands=26):
    """Painted hair: lighter on top, with strand streaks running from
    the crown."""
    center = Vector(center)

    def colour(pos, normal):
        rel = pos - center
        a = math.atan2(rel.x, rel.y)
        n = noise.noise(pos * scale)
        streak = math.sin(a * strands + n * 4.0) * 0.5 + 0.5
        t = max(0.0, min(1.0, 0.45 + normal.z * 0.4 + (streak - 0.5) * 0.35 + n * 0.15))
        return common.lerp(dark, mid, min(1.0, t / 0.5)) if t < 0.5 else common.lerp(mid, light, (t - 0.5) / 0.5)
    return colour


# --------------------------------------------------------------- limbs

def sculpted_hand(side, skin, crease, size=1.0):
    """A stylised game hand in the T-pose (palm down, along +-X): a palm
    block with a thenar pad, fingers as two curled groups (index+middle,
    ring+little) that wrap the rig's grip slot, a two-segment thumb and
    knuckle bumps. No individual fingers - they'd be noise at game size."""
    s, k = side, size
    wx, z0 = 0.77, 1.107

    def X(x):
        return s * (wx + (x - wx) * k)
    parts = [limb([(X(0.765), 0, z0), (X(0.81), 0, z0 - 0.002), (X(0.858), 0, z0 - 0.004)],
                  [(0.046 * k, 0.026 * k), (0.056 * k, 0.027 * k), (0.058 * k, 0.024 * k)], up=(0, 0, 1),
                  name="palm")]
    parts.append(ellipsoid((X(0.805), -0.022 * k, z0 - 0.012), (0.03 * k, 0.022 * k, 0.018 * k), name="thenar",
                           segs=(12, 8)))
    for y, length, w in ((-0.016, 1.0, 0.03), (0.018, 0.88, 0.027)):
        pts = [(X(0.852), y * k, z0 - 0.004), (X(0.855 + 0.045 * length), y * k, z0 - 0.01),
               (X(0.86 + 0.07 * length), y * k, z0 - 0.034 * length), (X(0.852 + 0.07 * length), y * k,
                                                                        z0 - 0.058 * length)]
        parts.append(limb(pts, [(w * k * 0.62, 0.017 * k), (w * k * 0.6, 0.016 * k), (w * k * 0.55, 0.015 * k),
                                (w * k * 0.48, 0.013 * k)], up=(0, 1, 0), name="fingers"))
        parts.append(ellipsoid((X(0.855), y * k, z0 + 0.012 * k), (0.014 * k, w * k * 0.5, 0.009 * k), name="knuckle",
                               segs=(10, 6)))
    parts.append(limb([(X(0.79), -0.03 * k, z0 - 0.004), (X(0.825), -0.052 * k, z0 - 0.012),
                       (X(0.855), -0.062 * k, z0 - 0.03)], [(0.017 * k, 0.017 * k), (0.015 * k, 0.015 * k),
                                                           (0.012 * k, 0.012 * k)], up=(0, 0, 1), name="thumb"))
    h = fuse(parts, "hand", voxel=0.0035 * k, smooth=1, faces=2400)
    gap_x = X(0.9)

    def colour(p, n):
        c = skin
        # Painted crease between the finger groups and at the knuckles.
        if crease and abs(p.y - 0.001 * k) < 0.004 * k and abs(p.x) > abs(X(0.86)):
            c = common.lerp(skin, crease, 0.6)
        if crease and abs(abs(p.x) - abs(X(0.858))) < 0.004 * k and n.z > 0.3:
            c = common.lerp(c, crease, 0.35)
        return c
    common.color_by(h, colour)
    return h


def hands(skin, radius=0.075, mitten=False, crease=None, sculpted=False, size=1.0):
    """Ball hands; mitten=True gives a readable game hand instead: a flat
    palm, a curled finger mass and a strong thumb, with a painted
    knuckle crease (crease colour, sRGB)."""
    parts = []
    for side, bone in ((1, "hand.l"), (-1, "hand.r")):
        if sculpted:
            h = sculpted_hand(side, skin, crease, size)
        elif mitten:
            r = radius
            palm = ellipsoid((side * 0.84, -0.005, 1.11), (r * 0.95, r * 0.7, r * 0.95), name="hand")
            fingers = ellipsoid((side * (0.84 + r * 0.9), -0.012, 1.095), (r * 0.75, r * 0.62, r * 0.85),
                                name="fingers", rot=Matrix.Rotation(side * 0.35, 3, "Y"))
            thumb = ellipsoid((side * (0.84 + r * 0.25), -0.005 - r * 0.8, 1.12), (r * 0.5, r * 0.38, r * 0.38),
                              name="thumb", segs=(12, 8))
            h = fuse([palm, fingers, thumb], "hand", voxel=0.009, smooth=2, faces=560)
            knuckle = side * (0.84 + r * 0.55)
            common.color_by(h, lambda p, n, k=knuckle: common.lerp(skin, crease, 0.55)
                            if crease and abs(p.x - k) < r * 0.08 and n.z > -0.2 else skin)
        else:
            palm = ellipsoid((side * 0.855, -0.005, 1.105), (radius * 1.15, radius * 0.85, radius), name="hand")
            thumb = ellipsoid((side * 0.8, -0.065, 1.115), (0.03, 0.028, 0.035), name="thumb", segs=(12, 8))
            h = fuse([palm, thumb], "hand", voxel=0.01, smooth=2, faces=320)
            common.set_color(h, skin)
        parts.append((h, bone))
    return parts


def sculpted_boot(side, upper, sole, toe, lace, collar=None, scale=1.0, tread=None, eyelet=(0.75, 0.72, 0.65),
                  height=1.0):
    """A chunky stylised hiking boot: shaft, vamp and heel fused into one
    upper, a padded ankle collar, a tongue, a rubber toe cap, a thick sole
    with toe spring and a darker tread lip, and crossed laces with eyelets.
    Sharp-ish sole edges against the softer upper."""
    x = side * 0.17
    k = scale
    parts = []
    up_parts = [limb([(x, 0.012 * k, 0.215 * k), (x, 0.0, 0.14 * k), (x, -0.01 * k, 0.085 * k)],
                     [(0.078 * k, 0.086 * k), (0.086 * k, 0.098 * k), (0.092 * k, 0.108 * k)], up=(0, -1, 0),
                     name="shaft"),
                ellipsoid((x, -0.1 * k, 0.07 * k), (0.086 * k, 0.13 * k, 0.062 * k), name="vamp"),
                ellipsoid((x, 0.055 * k, 0.068 * k), (0.08 * k, 0.07 * k, 0.068 * k), name="heel")]
    body = fuse(up_parts, "boot", voxel=0.006 * k, smooth=2, faces=2600)

    def upper_colour(p, n):
        c = upper
        # Painted panel seam around the foot and a darker heel counter.
        if abs(p.z - 0.105 * k) < 0.006 * k:
            c = common.lerp(upper, (0, 0, 0), 0.35)
        if p.y > 0.06 * k and p.z < 0.13 * k:
            c = common.lerp(upper, (0, 0, 0), 0.2)
        return c
    common.color_by(body, upper_colour)
    parts.append(body)
    ring = hem_ring((x, 0.012 * k, 0.212 * k), (0.082 * k, 0.09 * k), 0.017 * k, name="collar")
    common.set_color(ring, collar or common.lerp(upper, (0, 0, 0), 0.25))
    parts.append(ring)
    tongue = ellipsoid((0, 0, 0), (0.038 * k, 0.012 * k, 0.06 * k), name="tongue", segs=(12, 8))
    tongue.data.transform(Matrix.Translation((x, -0.082 * k, 0.19 * k)) @ Matrix.Rotation(-0.35, 4, "X"))
    common.set_color(tongue, common.lerp(upper, (1, 1, 1), 0.08))
    parts.append(tongue)
    cap = ellipsoid((x, -0.175 * k, 0.058 * k), (0.082 * k, 0.07 * k, 0.05 * k), name="toecap", segs=(18, 12))
    common.set_color(cap, toe)
    parts.append(cap)
    # Thick sole with a toe spring, and a darker tread lip below it.
    for thick, grow, z, colour in ((0.042, 0.0, 0.028, sole), (0.02, 0.008, 0.01, tread or
                                                                common.lerp(sole, (0, 0, 0), 0.45))):
        slab = box((0.19 * k + grow, 0.35 * k + grow, thick * k), (x, -0.055 * k, z * k), bevel=0.012 * k,
                   name="sole", segments=2)
        for v in slab.data.vertices:
            front = max(0.0, (-v.co.y - 0.12 * k) / (0.11 * k))
            v.co.z += 0.03 * k * front ** 2
        common.color_by(slab, lambda p, n, c=colour: c if n.z > -0.5 else common.lerp(c, (0, 0, 0), 0.3),
                        smooth=False)
        parts.append(slab)
    # Laces: crossed bars up the tongue, with eyelets either side.
    for i in range(4):
        t = i / 3
        y = (-0.13 + 0.06 * t) * k
        zz = (0.105 + 0.1 * t) * k
        for sgn in (-1, 1):
            bar = box((0.07 * k, 0.012 * k, 0.012 * k), (x, y - 0.012 * k, zz), bevel=0.004 * k, name="lace",
                      segments=1)
            bar.data.transform(Matrix.Translation((x, y - 0.012 * k, zz)) @ Matrix.Rotation(sgn * 0.45, 4, "Y")
                               @ Matrix.Translation((-x, -(y - 0.012 * k), -zz)))
            common.set_color(bar, lace)
            parts.append(bar)
            eye = torus((x + sgn * 0.04 * k, y - 0.006 * k, zz), 0.009 * k, 0.003 * k, name="eyelet", axis="Y",
                        segs=(10, 4))
            common.set_color(eye, eyelet)
            parts.append(eye)
    if height != 1.0:
        # Mid-cut vs high-top: squash the boot vertically (the footprint stays).
        for part in parts:
            for v in part.data.vertices:
                v.co.z *= height
            part.data.update()
    return parts


def boot(side, upper, sole, toe, lace, accent=None, scale=1.0, cuff=None):
    """A chunky cartoon hiking boot for the foot on this side."""
    x = side * 0.17
    s = scale
    shaft = ellipsoid((x, 0.0, 0.12), (0.105 * s, 0.115 * s, 0.1 * s), name="shaft")
    toebox = ellipsoid((x, -0.13 * s, 0.075), (0.1 * s, 0.14 * s, 0.075 * s), name="toebox")
    body = fuse([shaft, toebox], "boot", voxel=0.012, smooth=2, faces=700)

    def colour(pos, normal):
        if pos.y < -0.17 * s and pos.z < 0.1:
            return toe
        if accent and normal.x * side > 0.7 and 0.07 < pos.z < 0.13:
            return accent
        return upper
    common.color_by(body, colour, smooth=False)
    parts = [body]
    sole_obj = box((0.19 * s, 0.3 * s, 0.05), (x, -0.07 * s, 0.022), bevel=0.02, name="sole")
    common.color_by(sole_obj, lambda p, n: sole if n.z > -0.5 else common.lerp(sole, (0, 0, 0), 0.35), smooth=False)
    parts.append(sole_obj)
    # Laces: little bars across the tongue.
    for k in range(3):
        z = 0.09 + k * 0.035
        y = -0.1 * s + k * 0.03
        bar = box((0.07 * s, 0.02, 0.014), (x, y - 0.02, z), bevel=0.005, name="lace", segments=1)
        common.set_color(bar, lace)
        parts.append(bar)
    if cuff:
        ring = torus((x, 0.0, 0.2), 0.085 * s, 0.024, name="cuff")
        common.set_color(ring, cuff)
        parts.append(ring)
    return parts


# ---------------------------------------------------------------- gear

def compass(center, gold, face=(0.98, 0.95, 0.85), needle=(0.9, 0.2, 0.15), cord=(0.35, 0.25, 0.15),
            neck_z=1.2, radius=0.05, lid=False):
    parts = []
    c = Vector(center)
    # Raised bezel ring around the glass.
    bezel = torus(c + Vector((0, -0.011, 0)), radius * 0.86, radius * 0.1, name="compass", axis="Y", segs=(24, 6))
    common.set_color(bezel, common.lerp(gold, (1, 1, 1), 0.2))
    parts.append(bezel)
    if lid:
        # Hinged lid standing open above the case (as in the art).
        cover = cylinder((0, 0, 0), radius, 0.012, name="compass", axis="Y", bevel=0.004)
        common.color_by(cover, lambda p, n: common.lerp(gold, (0, 0, 0), 0.35) if n.y < -0.9 else gold,
                        smooth=False)
        cover.data.transform(Matrix.Translation(c + Vector((0, 0.004, radius))) @ Matrix.Rotation(-1.9, 4, "X")
                             @ Matrix.Translation((0, 0, radius)))
        parts.append(cover)
    body = cylinder(c, radius, 0.022, name="compass", axis="Y", bevel=0.006)
    common.color_by(body, lambda p, n: face if n.y < -0.9 and (p - c).length < radius * 0.8 else gold, smooth=False)
    parts.append(body)
    loop = torus(c + Vector((0, 0, radius + 0.012)), 0.014, 0.005, name="loop", axis="Y", segs=(12, 6))
    common.set_color(loop, gold)
    parts.append(loop)
    for sign, col in ((1, needle), (-1, (0.2, 0.22, 0.3))):
        bm = bmesh.new()
        tip = bm.verts.new(c + Vector((0, -0.013, sign * radius * 0.7)))
        l = bm.verts.new(c + Vector((-0.01, -0.013, 0)))
        r = bm.verts.new(c + Vector((0.01, -0.013, 0)))
        bm.faces.new((tip, l, r) if sign > 0 else (tip, r, l))
        f = common.mesh_object("needle", bm)
        if f.data.polygons[0].normal.y > 0:
            f.data.flip_normals()
        common.set_color(f, col)
        parts.append(f)
    # Cord up around the neck.
    for side in (-1, 1):
        t = tube([c + Vector((0, 0, radius + 0.02)), Vector((side * 0.09, c.y + 0.04, neck_z - 0.04)),
                  Vector((side * 0.12, 0.0, neck_z + 0.02))], [0.007, 0.007, 0.007], name="cord", levels=0)
        common.set_color(t, cord)
        parts.append(t)
    return parts


def bedroll(center, length, radius, colour, tie, name="bedroll"):
    """A rolled mat lying along X, with the spiral showing on its ends."""
    c = Vector(center)
    roll = cylinder(c, radius, length, name=name, axis="X", segments=28, bevel=radius * 0.3)

    def colour_fn(pos, normal):
        rel = pos - c
        if abs(normal.x) > 0.8:
            r = math.hypot(rel.y, rel.z) / radius
            a = math.atan2(rel.z, rel.y)
            spiral = (r * 3.2 - a / math.tau) % 1.0
            return common.lerp(colour, (0.05, 0.05, 0.08), 0.55) if spiral < 0.22 else common.lerp(colour, (1, 1, 1), 0.12)
        if abs(abs(rel.x) - length * 0.28) < 0.022:
            return tie
        return colour
    common.color_by(roll, colour_fn, smooth=False)
    return roll


def bedroll_detail(center, length, radius, colour, strap, metal=(0.8, 0.72, 0.5), cinch_at=(-0.28, 0.28)):
    """Layered spiral rings on the bedroll ends and two cinch straps with
    buckles that pinch the roll."""
    c = Vector(center)
    parts = []
    for end in (-1, 1):
        for i, rr in enumerate((0.35, 0.6, 0.85)):
            ring = torus(c + Vector((end * (length / 2 + 0.002 * i), 0, 0)), radius * rr, radius * 0.08,
                         name="bedroll_ring", axis="X", segs=(24, 6))
            common.set_color(ring, common.lerp(colour, (0.05, 0.05, 0.08), 0.35 + 0.15 * i))
            parts.append(ring)
    for f in cinch_at:
        x = c.x + f * length
        loop = hem_ring((x, c.y, c.z), (radius * 1.04, radius * 1.04), radius * 0.13, name="cinch", axis="X",
                        segs=(28, 6))
        common.set_color(loop, strap)
        parts.append(loop)
        parts.append(buckle((x, c.y, c.z + radius * 1.12), (0, 0, 1), up=(0, -1, 0), width=radius * 0.5,
                            height=radius * 0.5, colour=metal, name="cinch_buckle"))
    return parts


def rope_coil(center, radius, colour, loops=4, axis="Y"):
    parts = []
    c = Vector(center)
    for k in range(loops):
        off = Vector((0, 0, 0))
        if axis == "Y":
            off = Vector((0, (k - loops / 2) * 0.018, -k * 0.012))
        else:
            off = Vector(((k - loops / 2) * 0.018, 0, -k * 0.012))
        ring = torus(c + off, radius + k * 0.006, 0.012, name="rope", axis=axis, segs=(20, 6))
        common.color_by(ring, lambda p, n: colour if noise.noise(p * 60) > -0.2 else common.lerp(colour, (0.3, 0.2, 0.1), 0.4),
                        smooth=False)
        parts.append(ring)
    return parts


def webbing(points, normals, width=0.036, thick=0.009, name="strap"):
    """A thick flat strap along a path; normals = the strap face's outward
    direction at each point (so it can wrap over a shoulder)."""
    return limb(points, [(width, thick)] * len(points), up=list(normals), name=name, ring=8)


def buckle(center, normal, up=(0, 0, 1), width=0.05, height=0.042, bar=0.007, colour=(0.8, 0.72, 0.5),
           name="buckle"):
    """A metal buckle: a rectangular frame with a centre bar and a prong,
    facing along `normal`."""
    nrm = Vector(normal).normalized()
    upv = (Vector(up) - nrm * Vector(up).dot(nrm)).normalized()
    side = upv.cross(nrm)
    rot = Matrix((side, upv, nrm)).transposed().to_4x4()
    parts = []
    for cx, cy, sx, sy in ((0, height / 2, width, bar), (0, -height / 2, width, bar), (width / 2, 0, bar, height),
                           (-width / 2, 0, bar, height), (0, 0, width, bar * 0.7)):
        b = box((sx, sy, bar * 1.2), (cx, cy, 0), bevel=bar * 0.35, name=name, segments=1)
        parts.append(b)
    prong = box((bar * 0.6, height * 0.5, bar * 0.8), (0, height * 0.22, bar * 0.4), bevel=bar * 0.2, name=name,
                segments=1)
    parts.append(prong)
    obj = common.join(parts, name)
    obj.data.transform(Matrix.Translation(Vector(center)) @ rot)
    common.color_by(obj, lambda p, n: colour if n.dot(nrm) > 0.3 else common.lerp(colour, (0, 0, 0), 0.4),
                    smooth=False)
    return obj


def straps(colour, top_y=0.22, front_y=-0.2, xs=(-0.15, 0.15), shoulder_z=1.2, bottom_z=0.78, width=0.035,
           thick=0.0, metal=(0.8, 0.72, 0.5), shoulder_r=0.13):
    """Backpack shoulder straps. thick > 0: real webbing that wraps over
    the shoulder (with padding), an adjuster slider and a buckle."""
    parts = []
    for sx in xs:
        pts = [Vector((sx, top_y, shoulder_z - 0.04)), Vector((sx * 1.05, 0.0, shoulder_z + 0.035)),
               Vector((sx * 1.1, front_y, shoulder_z - 0.02)), Vector((sx * 1.2, front_y - 0.02, bottom_z + 0.12)),
               Vector((sx * 1.6, 0.0, bottom_z))]
        if not thick:
            st = tube(pts, [(width, 0.014)] * 5, name="strap", levels=0)
            common.set_color(st, colour)
            parts.append(st)
            continue
        # Smooth path over the shoulder with outward normals.
        path = sweep(pts[0], pts[1:], steps=14)
        centre = Vector((sx * 0.6, 0.0, shoulder_z - shoulder_r))
        normals = []
        for q in path:
            out = q - centre
            out.x *= 0.3
            normals.append(out.normalized())
        pad = webbing(path, normals, width=width * 1.25, thick=thick * 1.8, name="strap")
        common.color_by(pad, lambda p, n: colour if abs(p.x - sx * 1.1) < width * 0.9 else common.lerp(colour, (0, 0, 0), 0.3))
        parts.append(pad)
        # Adjuster slider and buckle on the front run.
        mid = path[9]
        parts.append(buckle(mid + normals[9] * thick * 1.6, normals[9], up=(0, 0, 1), width=width * 1.5,
                            height=width * 0.9, colour=metal, name="slider"))
    return parts


def report(objects):
    """Prints the heaviest parts (triangle budget check)."""
    counts = {}
    for obj in objects:
        key = obj.name.split(".")[0]
        counts[key] = counts.get(key, 0) + common.triangle_count([obj])
    print("parts tris:", sorted(counts.items(), key=lambda kv: -kv[1])[:14])


def finish(rig, soft_pieces, rigid_pieces, name, prop=None, **paint):
    """Stretch to the character's proportions, auto-skin the soft pieces,
    bind the rigid ones and join. The rig must already be stretched."""
    report(list(soft_pieces) + [o for o, _ in rigid_pieces])
    if prop is not None:
        for obj in list(soft_pieces) + [o for o, _ in rigid_pieces]:
            prop.stretch_mesh(obj)
    for piece in soft_pieces:
        auto_skin(piece, rig)
    for obj, bone in rigid_pieces:
        rigid(obj, bone)
    body = common.join(list(soft_pieces) + [o for o, _ in rigid_pieces], name)
    # Drop zero-area faces left by squashed or coincident parts.
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges[:])
    bm.to_mesh(body.data)
    bm.free()
    if body.parent is None:
        body.parent = rig
    if not any(m.type == "ARMATURE" for m in body.modifiers):
        mod = body.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
    return body


def quick_material(obj, overlay=None):
    """Preview-only material showing the 'Col' attribute (no bake), plus
    an optional painted overlay (image_path, uv_name)."""
    from lib import paint_bake
    mat = bpy.data.materials.new(obj.name + "_quick")
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = tree.nodes.get("Principled BSDF")
    attr = tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    colour = attr.outputs["Color"]
    if overlay:
        geo = tree.nodes.new("ShaderNodeNewGeometry")
        colour = paint_bake.overlay_socket(tree, colour, geo, *overlay)
    tree.links.new(colour, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def quick_mode():
    return bool(os.environ.get("QUICK"))
