"""Sculpted stylised heads (MOBA-style) as signed distance fields.

A head is blocked in the way a sculptor does it - from anatomical forms -
but every form is a distance field combined with a *smooth* union, so
forms flow into each other where they should (cheeks into jaw) and keep
crisp plane changes where the blend radius is small (lid rims, lips,
the jaw line):

  cranium and occiput, forehead, a face mask, zygomatic arches, cheek
  fat, jaw bars to a defined chin, the mouth mound (maxilla), a brow
  bar, a nose (bridge, tip ball, alae) with carved nostrils;
  then, placed on that surface by ray-marching: eye sockets carved in,
  eyeballs set behind the openings, upper/lower lid rims wrapping them,
  lips as volumes, and carved details - the mouth opening, corner pits,
  nasolabial folds, philtrum, lid creases and the mentolabial fold.

The surface is extracted with marching cubes (scikit-image) and
decimated. Coordinates are head-local metres relative to HeadFrame.c
(x = the character's left, -y = forward, z = up). Facial landmarks come
from the FaceLayout the painted face uses, so paint and forms line up.
"""

import math
from dataclasses import dataclass

import bmesh
import numpy as np
from mathutils import Vector

from lib import common
from characters import chibi, face_paint


@dataclass
class HeadShape:
    # Forms: (centre, radii) head-local; k = blend radius of the smooth union.
    cranium_off: tuple = (0.0, 0.0, 0.035)       # cranium radii are HeadFrame.r
    occiput: tuple = ((0.0, 0.1, 0.02), (0.17, 0.16, 0.17))
    forehead: tuple = None
    face: tuple = ((0.0, -0.07, -0.035), (0.18, 0.165, 0.205))
    zygoma: tuple = ((0.13, -0.125, -0.045), (0.055, 0.07, 0.028))
    cheek: tuple = ((0.1, -0.15, -0.1), (0.066, 0.075, 0.06))
    jaw: tuple = ((0.155, 0.03, -0.1), (0.14, -0.03, -0.165), (0.08, -0.155, -0.208), (0.03, -0.198, -0.228))
    jaw_r: tuple = (0.035, 0.032, 0.028, 0.022)
    chin: tuple = ((0.0, -0.208, -0.222), (0.038, 0.036, 0.032))
    muzzle: tuple = ((0.0, -0.172, -0.145), (0.06, 0.064, 0.055))
    brow: tuple = ((0.13, -0.195, 0.0), (0.065, -0.225, 0.012), (0.0, -0.232, 0.005))
    brow_r: float = 0.014
    k_big: float = 0.07        # cranium / forehead / face
    k_cheek: float = 0.035
    k_zygoma: float = 0.025
    k_jaw: float = 0.04
    k_chin: float = 0.02
    k_brow: float = 0.04
    # Nose.
    bridge_top: float = -0.02  # z where the bridge starts, between the eyes
    bridge_h: float = 0.004    # bridge height above the face there
    bridge_r: tuple = (0.008, 0.011)
    tip: float = 0.032         # tip protrusion above the face
    tip_r: tuple = (0.018, 0.017, 0.016)
    alae_r: float = 0.011
    nostril: tuple = (0.005, 0.006, 0.0035)
    # Eyes.
    socket: tuple = (1.3, 0.03, 1.4)     # under-brow shadow: x in eye_w, depth (m), z in eye_h
    socket_cut: float = 0.003
    socket_k: float = 0.012
    ball_depth: float = 0.022  # eyeball bulge depth (m)
    ball_r: float = 1.3        # eyeball radius in eye half-widths
    ball_back: float = 0.002    # bulge proud of the skin
    ball_k: float = 0.012  # eyeball front behind the original skin
    lid_r: float = 0.0055
    lower_lid_r: float = 0.0036
    lid_k: float = 0.004
    lower_lid_k: float = 0.009
    crease: float = 0.0008
    # Mouth.
    upper_lip_r: float = 0.006
    lower_lip_r: float = 0.0085
    lip_k: float = 0.004
    corner_r: float = 0.0045
    corner_depth: float = 0.0025
    mouth_depth: float = 0.014
    nasolabial: float = 0.0
    philtrum: float = 0.0008
    mentolabial: float = 0.0025
    # Mesh.
    voxel: float = 0.0022
    draft_voxel: float = 0.003     # SCULPT review renders


# --- distance-field primitives (vectorised over (N, 3) points) --------------

def _ell(P, c, r):
    q = (P - np.asarray(c)) / np.asarray(r)
    k0 = np.linalg.norm(q, axis=1)
    k1 = np.linalg.norm(q / np.asarray(r), axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def _chain(P, pts, radii):
    """Tapered capsule chain through pts with per-point radii."""
    d = np.full(len(P), 1e9)
    for (a, b), (ra, rb) in zip(zip(pts[:-1], pts[1:]), zip(radii[:-1], radii[1:])):
        a, b = np.asarray(a), np.asarray(b)
        ab = b - a
        t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
        dist = np.linalg.norm(P - (a + t[:, None] * ab), axis=1) - (ra + (rb - ra) * t)
        d = np.minimum(d, dist)
    return d


def _smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def _ssub(a, b, k):
    """a minus b, smoothly."""
    return -_smin(-a, b, k)


class Prim:
    """A distance function with an axis-aligned bounding box."""

    def __init__(self, fn, lo, hi):
        self.fn, self.lo, self.hi = fn, np.asarray(lo, float), np.asarray(hi, float)


class Field:
    """An ordered list of (op, primitive, k); evaluate() folds them. Each
    primitive is only evaluated inside its box grown by the blend radius
    plus `margin` - outside it can't move the zero level set."""

    margin = 0.008

    def __init__(self):
        self.ops = []

    def add(self, prim, k=0.0):
        self.ops.append(("add", prim, k))

    def sub(self, prim, k=0.0):
        self.ops.append(("sub", prim, k))

    def evaluate(self, P):
        d = np.full(len(P), 1e3)
        plo, phi = P.min(0), P.max(0)
        for op, prim, k in self.ops:
            grow = k + self.margin
            lo, hi = prim.lo - grow, prim.hi + grow
            if np.any(hi < plo) or np.any(lo > phi):
                continue
            m = np.all((P >= lo) & (P <= hi), axis=1)
            if not m.any():
                continue
            idx = np.nonzero(m)[0]
            v = prim.fn(P[idx])
            d[idx] = _smin(d[idx], v, k) if op == "add" else _ssub(d[idx], v, k)
        return d

    def front_y(self, x, z, y0=-0.45, y1=0.1, step=0.0008):
        """y where a ray along +y at (x, z) first enters the surface."""
        ys = np.arange(y0, y1, step)
        P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
        d = self.evaluate(P)
        inside = np.nonzero(d < 0)[0]
        if not len(inside):
            return None
        i = inside[0]
        if i == 0:
            return ys[0]
        return ys[i - 1] + (ys[i] - ys[i - 1]) * d[i - 1] / (d[i - 1] - d[i])


def ell(c, r):
    c, r = np.asarray(c, float), np.asarray(r, float)
    return Prim(lambda P: _ell(P, c, r), c - r, c + r)


def chain(pts, radii):
    arr = np.asarray(pts, float)
    big = max(radii)
    return Prim(lambda P: _chain(P, pts, radii), arr.min(0) - big, arr.max(0) + big)


def carve_y(surface_y, radius, depth):
    """Centre y for a carving primitive of `radius` that cuts `depth` into
    a surface at `surface_y` (the primitive sits mostly in front)."""
    return surface_y - radius + depth


def _mirror(q, side):
    return (side * q[0], q[1], q[2])


def build_field(head, L, S):
    F = Field()
    r = tuple(head.r)
    F.add(ell(S.cranium_off, r))
    F.add(ell(*S.occiput), S.k_big)
    if S.forehead:
        F.add(ell(*S.forehead), S.k_big)
    F.add(ell(*S.face), S.k_big)
    F.add(ell(*S.muzzle), S.k_cheek)
    for side in (-1, 1):
        F.add(ell(_mirror(S.zygoma[0], side), S.zygoma[1]), S.k_zygoma)
        F.add(ell(_mirror(S.cheek[0], side), S.cheek[1]), S.k_cheek)
        F.add(chain([_mirror(q, side) for q in S.jaw], S.jaw_r), S.k_jaw)
    F.add(ell(*S.chin), S.k_chin)
    brow = [_mirror(q, -1) for q in S.brow] + list(reversed(S.brow[:-1]))
    F.add(chain(brow, [S.brow_r] * len(brow)), S.k_brow)

    # Nose, standing on the face.
    tip_z = L.nose_z + 0.004
    y_top = F.front_y(0.0, S.bridge_top)
    y_tip = F.front_y(0.0, tip_z)
    F.add(chain([(0.0, y_top - S.bridge_h + S.bridge_r[0], S.bridge_top),
                 (0.0, y_tip - S.tip * 0.72 + S.bridge_r[1], tip_z + 0.012)], S.bridge_r), 0.012)
    F.add(ell((0.0, y_tip - S.tip + S.tip_r[1], tip_z), S.tip_r), 0.01)
    for side in (-1, 1):
        ya = F.front_y(side * L.nose_w * 1.1, L.nose_z - 0.002)
        F.add(ell((side * L.nose_w * 1.05, ya - S.alae_r * 0.45, L.nose_z - 0.002), (S.alae_r,) * 3), 0.008)
    for side in (-1, 1):
        F.sub(ell((side * L.nose_w * 0.52, y_tip - S.tip * 0.45, L.nose_z - 0.011), S.nostril), 0.003)

    # Eyes, the stylised-game way: a shallow shadow under the brow, the
    # eyeball as a soft bulge continuous with the face (the painted eye sits
    # on it), a crisp upper-lid fold and a subtle lower-lid roll.
    for side in (-1, 1):
        ex = side * L.eye_x
        skin = F.front_y(ex, L.eye_z)
        # Under-brow shadow: a well-proportioned volume sunk so it only
        # carves `socket_cut` (flat ellipsoids break the distance estimate).
        F.sub(ell((ex - side * L.eye_w * 0.15, carve_y(skin, S.socket[1], S.socket_cut), L.eye_z + L.eye_h * 1.2),
                  (L.eye_w * S.socket[0], S.socket[1], L.eye_h * S.socket[2])), S.socket_k)
        globe = (L.eye_w * S.ball_r, S.ball_depth, L.eye_h * S.ball_r * 1.4)
        centre = (ex, skin - S.ball_back + globe[1], L.eye_z + L.eye_h * 0.1)
        F.add(ell(centre, globe), S.ball_k)

        def on_ball(x, z, lift, centre=centre, globe=globe):
            q = 1.0 - ((x - centre[0]) / globe[0]) ** 2 - ((z - centre[2]) / globe[2]) ** 2
            return centre[1] - globe[1] * math.sqrt(max(q, 0.0)) - lift
        top, bottom = face_paint._eye_curves(L, side)
        for curve, rad, off, kk in ((top, S.lid_r, 0.0012, S.lid_k), (bottom, S.lower_lid_r, -0.0008, S.lower_lid_k)):
            pts, radii = [], []
            for k in range(13):
                d = -L.eye_w * 1.03 + 2.06 * L.eye_w * k / 12
                x = ex + side * d
                z = L.eye_z + float(curve(np.float64(d))) + off
                taper = 0.6 + 0.4 * math.sin(math.pi * k / 12) ** 0.6
                pts.append((x, on_ball(x, z, rad * 0.25), z))
                radii.append(rad * taper)
            F.add(chain(pts, radii), kk)
        # Lid crease above the rim.
        pts = []
        for k in range(9):
            d = -L.eye_w * 0.85 + 1.8 * L.eye_w * k / 8
            x = ex + side * d
            z = L.eye_z + float(top(np.float64(d))) + L.eye_h * 0.62
            y = F.front_y(x, z)
            if y is not None:
                pts.append((x, carve_y(y, 0.003, S.crease), z))
        if len(pts) > 1 and S.crease > 0:
            F.sub(chain(pts, [0.003] * len(pts)), 0.004)

    # Lips on the muzzle, then the carved mouth.
    def line(x):
        x = max(-L.mouth_w, min(L.mouth_w, x))
        return L.mouth_z + L.smile * x * x + L.smirk * x

    for rad, dz in ((S.upper_lip_r, S.upper_lip_r * 0.7), (S.lower_lip_r, -(L.open_mouth + S.lower_lip_r * 0.8))):
        pts, radii = [], []
        for k in range(15):
            x = -L.mouth_w * 1.04 + 2.08 * L.mouth_w * k / 14
            z = line(x) + dz
            y = F.front_y(x, z)
            taper = 0.3 + 0.7 * math.sin(math.pi * k / 14) ** 0.6
            pts.append((x, y + rad * 0.55 * taper, z))
            radii.append(rad * taper)
        F.add(chain(pts, radii), S.lip_k)
    pts, radii = [], []
    for k in range(13):
        x = -L.mouth_w * 0.98 + 1.96 * L.mouth_w * k / 12
        z = line(x) - L.open_mouth * 0.5
        y = F.front_y(x, z)
        taper = 0.7 + 0.3 * math.sin(math.pi * k / 12) ** 0.5
        rad = max(0.0042, L.open_mouth * 0.6) * taper
        pts.append((x, y, z))
        radii.append(rad)
    # A slot along the mouth line, then the cavity behind it.
    F.sub(chain([(q[0], carve_y(q[1], rr, rr * 1.2), q[2]) for q, rr in zip(pts, radii)], radii), 0.003)
    if L.open_mouth > 0:
        F.sub(chain([(q[0] * 0.85, q[1] + S.mouth_depth * 0.5, q[2]) for q in pts],
                    [rr * 1.3 for rr in radii]), 0.004)
    for side in (-1, 1):
        cz = line(side * L.mouth_w)
        y = F.front_y(side * L.mouth_w * 1.08, cz)
        F.sub(ell((side * L.mouth_w * 1.08, carve_y(y, S.corner_r, S.corner_depth), cz - L.open_mouth * 0.3),
                  (S.corner_r,) * 3), 0.004)
        # Nasolabial fold from beside the ala toward the mouth corner.
        path = [(side * L.nose_w * 2.1, L.nose_z + 0.006), (side * (L.mouth_w + 0.012), cz + 0.014),
                (side * (L.mouth_w + 0.017), cz - 0.012)]
        pts = []
        for i in range(len(path) - 1):
            for t in np.linspace(0, 1, 5, endpoint=i == len(path) - 2):
                x = path[i][0] + (path[i + 1][0] - path[i][0]) * t
                z = path[i][1] + (path[i + 1][1] - path[i][1]) * t
                y = F.front_y(x, z)
                if y is not None:
                    pts.append((x, carve_y(y, 0.008, S.nasolabial), z))
        if len(pts) > 1 and S.nasolabial > 0:
            F.sub(chain(pts, [0.008] * len(pts)), 0.012)
    y = F.front_y(0.0, (L.nose_z + line(0.0)) * 0.5)
    F.sub(chain([(0.0, carve_y(y, 0.0034, S.philtrum), L.nose_z - 0.014),
                 (0.0, carve_y(y, 0.0034, S.philtrum), line(0.0) + 0.008)],
                [0.0034, 0.0034]), 0.004)
    pts = []
    for k in range(7):
        x = -L.mouth_w * 0.7 + 1.4 * L.mouth_w * k / 6
        z = line(x) - L.open_mouth - S.lower_lip_r * 2.2 - 0.006
        y = F.front_y(x, z)
        if y is not None:
            pts.append((x, carve_y(y, 0.006, S.mentolabial), z))
    if len(pts) > 1:
        F.sub(chain(pts, [0.006] * len(pts)), 0.008)
    return F


def sculpt(head, L, S, name="head"):
    from skimage.measure import marching_cubes
    F = build_field(head, L, S)
    r = np.array(head.r)
    lo = np.array([-r[0] - 0.05, -r[1] - 0.1, -r[2] - 0.08])
    hi = np.array([r[0] + 0.05, r[1] + 0.12, r[2] + 0.08])
    import os
    v = S.draft_voxel if os.environ.get("HEAD_DRAFT") else S.voxel
    nx, ny, nz = (np.ceil((hi - lo) / v)).astype(int) + 1
    xs = lo[0] + np.arange(nx) * v
    ys = lo[1] + np.arange(ny) * v
    zs = lo[2] + np.arange(nz) * v
    vol = np.empty((nx, ny, nz), dtype=np.float32)
    X, Y = np.meshgrid(xs, ys, indexing="ij")
    for k, z in enumerate(zs):
        P = np.stack([X.ravel(), Y.ravel(), np.full(X.size, z)], 1)
        vol[:, :, k] = F.evaluate(P).reshape(nx, ny)
    verts, faces, _, _ = marching_cubes(vol, level=0.0, spacing=(v, v, v))
    verts = verts + lo + np.array(head.c)
    bm = bmesh.new()
    bv = [bm.verts.new(tuple(p)) for p in verts]
    for f in faces:
        try:
            bm.faces.new((bv[f[0]], bv[f[1]], bv[f[2]]))
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=v * 0.05)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = common.mesh_object(name, bm)
    return obj


def build_head(head, L, S, skin, skin_shade, blush, tris=30000, name="head", blush_pts=None, blush_size=0.05):
    """Sculpts, decimates, binds the HeadFrame and colours the head."""
    obj = sculpt(head, L, S, name=name)
    chibi.decimate_tris(obj, tris)
    common.shade_smooth(obj)
    head.bind(obj)
    pts = blush_pts or []

    def colour(pos, normal):
        cc = common.lerp(skin, skin_shade, max(0.0, min(1.0, -normal.z * 0.7)))
        for ch in pts:
            dist = (pos - ch).length
            if dist < blush_size:
                cc = common.lerp(cc, blush, (1.0 - dist / blush_size) ** 1.5 * 0.5)
        return cc
    common.color_by(obj, colour)
    return obj

def ear(head, side, yaw=1.52, pitch=-0.12, size=1.0, tilt=0.35, out=0.018, colour=None, shade=None):
    """A stylised sculpted ear: a flattened shell with a rolled helix rim,
    a cupped concha and a small tragus, angled back and out."""
    from mathutils import Matrix, Vector
    s = size
    # Local frame: X out from the head, Y back, Z up.
    outline = [(0.0, -0.012 * s, -0.038 * s), (0.0, -0.022 * s, -0.008 * s), (0.0, -0.02 * s, 0.026 * s),
               (0.0, 0.0, 0.046 * s), (0.0, 0.022 * s, 0.036 * s), (0.0, 0.03 * s, 0.006 * s),
               (0.0, 0.022 * s, -0.026 * s), (0.0, 0.006 * s, -0.05 * s), (0.0, -0.01 * s, -0.056 * s)]
    shell = chibi.ellipsoid((0.004 * s, 0.004 * s, -0.004 * s), (0.012 * s, 0.028 * s, 0.05 * s), name="ear",
                            segs=(20, 14))
    rim = chibi.tube([Vector(q) + Vector((0.008 * s, 0, 0)) for q in outline],
                     [0.008 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.008 * s, 0.009 * s, 0.01 * s],
                     name="ear", levels=1)
    tragus = chibi.ellipsoid((0.006 * s, -0.016 * s, -0.012 * s), (0.008 * s, 0.006 * s, 0.009 * s), name="ear",
                             segs=(10, 8))
    obj = chibi.fuse([shell, rim, tragus], "ear", voxel=0.0028 * s, smooth=1, faces=1400)
    # Cup the concha (the bowl inside the rim).
    for v in obj.data.vertices:
        k = math.exp(-((v.co.y - 0.004 * s) / (0.012 * s)) ** 2 - ((v.co.z + 0.006 * s) / (0.02 * s)) ** 2)
        if v.co.x > 0.004 * s:
            v.co.x -= 0.009 * s * k
    obj.data.update()
    p, n = head.point(side * yaw, pitch)
    rot = Matrix.Rotation(side * -tilt, 4, "Z") @ Matrix.Rotation(-0.2, 4, "X")
    if side < 0:
        obj.data.transform(Matrix.Scale(-1, 4, (1, 0, 0)))
        obj.data.flip_normals()
    obj.data.transform(Matrix.Translation(p + n * out * 0.3) @ rot)
    common.shade_smooth(obj)
    if colour:
        common.color_by(obj, lambda pos, nrm: common.lerp(colour, shade or colour,
                                                          max(0.0, min(1.0, -nrm.z * 0.5 + 0.3))))
    return obj
