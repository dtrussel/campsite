"""Sculpted stylised heads (MOBA-style), procedurally.

The head starts as an ellipsoid whose vertices are redistributed so they
crowd the face (fine enough for eyelids and lip lines), then:

  1. skull shaping: occipital bulge, flatter face front, temples;
  2. cheek fat pads and cheekbones (pushed outward, radially);
  3. a jaw: a soft clamp gives a jaw-underside plane from the chin back
     to the jaw corners and narrows the lower face into a jaw line;
  4. facial features as displacement fields toward the viewer, driven
     by the *same* FaceLayout curves the painted face uses (so relief
     and paint line up): eye sockets, eyeballs, an upper-lid band with a
     crease, lower lids, brow masses, a constructed nose (bridge planes,
     tip, alae, nostrils), lips with an open-mouth cavity, mouth-corner
     pits, smile apples, philtrum, mentolabial fold and chin pad.

Everything is vectorised with numpy; units are metres, head-local
(x = the character's left, -y = forward, z = up). Fields use compact
smooth bumps so plane changes stay crisp where wanted.
"""

import math
from dataclasses import dataclass

import bmesh
import bpy
import numpy as np

from lib import common
from characters import chibi, face_paint


@dataclass
class HeadShape:
    # Skull
    occiput: float = 0.05          # back-of-head bulge (fraction of ry)
    face_flat: float = 0.1         # flatten the face front (fraction of ry)
    mid_face: float = 0.03         # lower/mid-face mass forward (a vertical, not dished, profile)
    forehead: float = 0.02         # rounded child forehead bulge
    temple: float = 0.006          # temple hollow depth (m)
    # Jaw and chin (head-local metres)
    jaw_w: float = 0.17            # half-width at the jaw corners
    jaw_y: float = 0.02            # jaw corner depth (0 = head centre)
    jaw_z: float = -0.17           # jaw corner height
    chin_w: float = 0.05           # half-width at the chin
    chin_z: float = -0.245         # chin bottom
    chin_fwd: float = 0.0          # extra chin push forward (m)
    jaw_soft: float = 0.012        # soft-clamp width: small = crisp jaw line
    jaw_top: float = -0.04         # the jaw narrowing fades out above this height
    # Cheeks (child fat pads) and cheekbones
    cheek: float = 0.014
    cheek_pos: tuple = (0.105, -0.095)
    cheek_size: tuple = (0.06, 0.055)
    cheekbone: float = 0.006
    # Eyes
    socket: float = 0.022          # socket depth
    eyeball: float = 0.016         # eyeball dome height back out of the socket
    lid: float = 0.006             # upper-lid band thickness
    lid_band: float = 0.008        # upper-lid band height (lid edge to crease)
    crease: float = 0.003
    lower_lid: float = 0.0025
    brow: float = 0.012
    # Nose
    bridge: float = 0.006          # bridge height between the eyes
    bridge_top: float = 0.3        # where the bridge starts, in eye heights above the eye centre
    tip: float = 0.03              # nose tip protrusion
    tip_lift: float = 0.004        # upturned tip (tip centre above nose_z)
    alae: float = 0.014
    nostril: float = 0.006
    # Mouth
    muzzle: float = 0.012          # the rounded mouth area in front of the teeth
    upper_lip: float = 0.005
    lower_lip: float = 0.007
    mouth_depth: float = 0.018     # open-mouth cavity depth
    corner: float = 0.005          # mouth-corner pits
    apple: float = 0.01            # smile cheeks beside the mouth corners
    philtrum: float = 0.0025
    mentolabial: float = 0.004
    chin_pad: float = 0.01


def _smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _bump(u, w, cu, cw, au, aw):
    """Compact smooth bump: 1 at the centre, 0 outside the ellipse."""
    d2 = ((u - cu) / au) ** 2 + ((w - cw) / aw) ** 2
    return np.clip(1.0 - d2, 0.0, 1.0) ** 2


def _ridge(dist, width):
    return np.clip(1.0 - (dist / width) ** 2, 0.0, 1.0) ** 2


def _soft_min(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def _soft_max(a, b, k):
    return -_soft_min(-a, -b, k)


def _warped_sphere(name, nu=320, nv=240, front_bias=0.6, face_pitch_bias=0.45):
    """A UV sphere whose vertices crowd the front (yaw 0 = -Y) and the
    face band, so small facial forms resolve without a huge mesh."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=nu, v_segments=nv, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co
        yaw = math.atan2(x, -y)
        pitch = math.asin(max(-1.0, min(1.0, z)))
        yaw = yaw - front_bias * math.sin(yaw)
        # Denser around the equator (the face band), sparser at the poles.
        pitch = pitch - face_pitch_bias * math.sin(2 * pitch) / 2
        v.co = (math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    obj = common.mesh_object(name, bm)
    return obj


def _polyline_dist(u, w, pts):
    best = np.full(u.shape, 1e9)
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        dx, dy = x1 - x0, y1 - y0
        seg = dx * dx + dy * dy or 1e-12
        t = np.clip(((u - x0) * dx + (w - y0) * dy) / seg, 0.0, 1.0)
        best = np.minimum(best, np.hypot(u - (x0 + t * dx), w - (y0 + t * dy)))
    return best


def sculpt(head, L, S, name="head"):
    """Returns the sculpted head mesh (untriangulated, not yet coloured)."""
    obj = _warped_sphere(name)
    mesh = obj.data
    n = len(mesh.vertices)
    co = np.empty(n * 3)
    mesh.vertices.foreach_get("co", co)
    d = co.reshape(n, 3)                      # unit directions
    r = np.array(head.r)
    p = d * r                                  # ellipsoid, head-local
    nx, ny, nz = d[:, 0], d[:, 1], d[:, 2]
    front = np.clip(-ny, 0.0, 1.0)

    # --- 1. skull ---------------------------------------------------------
    back = np.clip(ny, 0.0, 1.0)
    occ = S.occiput * r[1] * back ** 1.5 * np.exp(-((nz - 0.15) / 0.55) ** 2)
    p[:, 1] += occ
    p[:, 2] += occ * 0.3
    # A flatter face front, strongest across the mid-face.
    flat = S.face_flat * r[1] * front ** 2 * np.exp(-((nz + 0.2) / 0.6) ** 2)
    p[:, 1] += flat
    u, w = p[:, 0], p[:, 2]
    # Mid/lower-face mass (maxilla + mandible) so the mouth and chin don't
    # fall back along the ellipsoid.
    p[:, 1] -= S.mid_face * _bump(u, w, 0.0, L.mouth_z + 0.01, 0.17, 0.15) ** 0.7 * front
    p[:, 1] -= S.forehead * _bump(u, w, 0.0, L.eye_z + 0.14, 0.22, 0.15) * front

    # --- 2. cheeks, cheekbones, temples (radial) ---------------------------
    radial = np.zeros(n)
    for side in (-1, 1):
        cx, cz = S.cheek_pos
        radial += S.cheek * _bump(u, w, side * cx, cz, *S.cheek_size) * front ** 0.5
        radial += S.cheekbone * _bump(u, w, side * (L.eye_x + L.eye_w * 0.9), L.eye_z - L.eye_h - 0.02, 0.05,
                                      0.022) * front ** 0.5
        radial -= S.temple * _bump(u, w, side * (L.eye_x + L.eye_w + 0.05), L.eye_z + 0.05, 0.04, 0.05)
    p += d * radial[:, None]

    # --- 3. jaw ------------------------------------------------------------
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    chin_y = -r[1] * 0.9
    t = np.clip((y - S.jaw_y) / (chin_y - S.jaw_y), 0.0, 1.0)
    # Jaw-underside plane from the jaw corners down to the chin.
    floor = S.jaw_z + (S.chin_z - S.jaw_z) * t ** 1.2
    z_new = _soft_max(z, floor, S.jaw_soft)
    lower = _smoothstep(S.jaw_top, S.jaw_top - 0.1, z)       # 0 above jaw_top .. 1 well below
    # Narrow the lower face toward the chin (jaw line), front half only.
    limit = S.jaw_w + (S.chin_w - S.jaw_w) * t ** 1.1
    fronthalf = _smoothstep(S.jaw_y + 0.06, S.jaw_y - 0.02, y)
    ax = np.abs(x)
    ax_new = ax + (_soft_min(ax, limit, S.jaw_soft * 1.5) - ax) * lower * fronthalf
    p[:, 0] = np.sign(x) * ax_new
    p[:, 2] = z + (z_new - z) * fronthalf
    # Chin forward.
    p[:, 1] -= S.chin_fwd * _bump(p[:, 0], p[:, 2], 0.0, S.chin_z + 0.035, 0.07, 0.06) * front

    # --- 4. features (toward the viewer) ------------------------------------
    u, w = p[:, 0], p[:, 2]
    dy = np.zeros(n)
    for side in (-1, 1):
        ex = side * L.eye_x
        top, bottom = face_paint._eye_curves(L, side)
        du = (u - ex) * side
        dv = w - L.eye_z
        env = np.clip(1.0 - (du / (L.eye_w * 1.12)) ** 2, 0.0, 1.0)
        # Socket, then the eyeball dome back out of it.
        dy -= S.socket * _bump(u, w, ex - side * L.eye_w * 0.1, L.eye_z + L.eye_h * 0.9, L.eye_w * 1.6, L.eye_h * 1.9)
        dy += S.eyeball * _bump(u, w, ex, L.eye_z + L.eye_h * 0.1, L.eye_w * 1.55, L.eye_h * 2.0)
        # Upper-lid band: thickest at the lid edge, ends at a crease.
        above = dv - top(du)
        band = (1.0 - _smoothstep(S.lid_band * 0.6, S.lid_band, above)) * _smoothstep(-0.003, 0.0, above)
        dy += S.lid * band * env ** 0.5
        dy -= S.crease * _ridge(above - S.lid_band, 0.0035) * env
        # Lower lid roll.
        below = bottom(du) - dv
        dy += S.lower_lid * _ridge(below - 0.0015, 0.004) * env
        # Brow mass, fading toward the temple.
        dy += S.brow * _bump(u, w, ex - side * 0.004, L.eye_z + L.eye_h + 0.03, L.eye_w * 1.55, 0.028)

    # Nose: bridge (angular trapezoid section), tip, alae, nostrils.
    tip_w = L.nose_z + S.tip_lift
    top_w = L.eye_z + L.eye_h * S.bridge_top
    tb = np.clip((top_w - w) / max(1e-4, top_w - tip_w), 0.0, 1.0)
    half = 0.009 + (L.nose_w * 0.75 - 0.009) * tb
    section = np.clip((half - np.abs(u)) / (half * 0.55), 0.0, 1.0)
    section = section * section * (3 - 2 * section)
    height = S.bridge + (S.tip * 0.72 - S.bridge) * tb ** 1.6
    under = _smoothstep(tip_w - 0.014, tip_w - 0.002, w)       # sharp drop under the tip
    dy += height * section * (w <= top_w + 0.01) * under
    dy += S.tip * 0.35 * _bump(u, w, 0.0, tip_w, L.nose_w * 0.9, L.nose_w * 0.85)
    for side in (-1, 1):
        dy += S.alae * _bump(u, w, side * L.nose_w * 1.0, L.nose_z - 0.003, L.nose_w * 0.6, L.nose_w * 0.55)
        dy -= S.nostril * _bump(u, w, side * L.nose_w * 0.5, L.nose_z - 0.009, 0.005, 0.0032)

    # Mouth.
    def line(xx):
        xx = np.clip(xx, -L.mouth_w, L.mouth_w)
        return L.mouth_z + L.smile * xx * xx + L.smirk * xx

    lipw = np.clip(1.0 - (u / (L.mouth_w * 1.08)) ** 2, 0.0, 1.0)
    a = w - line(u)                 # + above the mouth line
    b = -a                          # + below
    dy += S.muzzle * _bump(u, w, 0.0, L.mouth_z + 0.005, L.mouth_w * 1.7, 0.055)
    dy += S.upper_lip * _ridge(a - 0.004, 0.0065) * lipw ** 0.5
    opening = L.open_mouth * lipw ** 0.6
    dy += S.lower_lip * _ridge(b - opening - 0.0065, 0.0075) * lipw ** 0.6
    if L.open_mouth > 0:
        inside = _smoothstep(-0.0012, 0.0012, np.minimum(b, opening - b)) * (lipw > 0.02)
        dy -= S.mouth_depth * inside
    else:
        dy -= 0.004 * _ridge(a, 0.0022) * lipw
    for side in (-1, 1):
        cw = float(line(np.float64(side * L.mouth_w)))
        dy -= S.corner * _bump(u, w, side * L.mouth_w * 1.04, cw - L.open_mouth * 0.2, 0.0075, 0.0085)
        dy += S.apple * _bump(u, w, side * (L.mouth_w + 0.032), cw + 0.03, 0.036, 0.032)
    phil = (w > line(u) + 0.006) & (w < L.nose_z - 0.012)
    dy -= S.philtrum * _ridge(u, 0.0045) * phil
    dy += S.philtrum * 0.6 * (_ridge(np.abs(u) - 0.0065, 0.003)) * phil
    dy -= S.mentolabial * _ridge(b - opening - 0.018, 0.0055) * lipw ** 0.5
    dy += S.chin_pad * _bump(u, w, 0.0, S.chin_z + 0.032, 0.036, 0.03)

    face = np.clip((-p[:, 1] / r[1] - 0.2) / 0.45, 0.0, 1.0)
    p[:, 1] -= dy * face
    mesh.vertices.foreach_set("co", (p + np.array(head.c)).ravel())
    mesh.update()
    return obj


def build_head(head, L, S, skin, skin_shade, blush, tris=24000, name="head", blush_pts=None, blush_size=0.05):
    """Sculpts, decimates, binds the HeadFrame and colours the head."""
    obj = sculpt(head, L, S, name=name)
    chibi.decimate_tris(obj, tris)
    common.shade_smooth(obj)
    head.bind(obj)
    pts = blush_pts or []

    def colour(pos, normal):
        c = common.lerp(skin, skin_shade, max(0.0, min(1.0, -normal.z * 0.7)))
        for ch in pts:
            dist = (pos - ch).length
            if dist < blush_size:
                c = common.lerp(c, blush, (1.0 - dist / blush_size) ** 1.5 * 0.5)
        return c
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
