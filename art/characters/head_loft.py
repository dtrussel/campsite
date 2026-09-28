"""Drawn, planar game heads (feature 014).

How hand-painted game heads are made (LoL, Blizzard style): a simple
head shape that matches the concept's front and side silhouettes, with
broad planes that turn at a few defined corners, and the face *painted*
(eyes, lids, brows, lips, nostrils, painted light and shadow). This
module builds exactly that, procedurally:

  * a loft through horizontal sections; each section is a superellipse
    with its own half-width (front outline), front and back depth (side
    profile) and squareness - square sections give the flat face and
    side planes and the temple/cheek/jaw corners that read as "drawn";
  * a handful of deliberate forms on the face: a wedge nose (flat front
    plane, side planes, rounded tip, small alae), a flat inset plate per
    eye so the painted eyes sit in a soft socket shadow, a brow shelf,
    cheek planes, a slight lip ridge and chin plane.

Vertices crowd the face so the few forms stay crisp, then the mesh is
decimated to a game budget. Coordinates are head-local metres relative
to HeadFrame.c (x = the character's left, -y = forward, z = up).
"""

import math
from dataclasses import dataclass, field

import bmesh
import numpy as np

from lib import common
from characters import chibi


@dataclass
class HeadLoft:
    # Sections from the crown down: (z, half_width, front_depth, back_depth, square_front, square_back).
    # front_depth is the face surface at the centreline (negative y), back_depth the back of the skull.
    sections: tuple = ()
    # Nose wedge (heights above the face surface).
    nose_top: float = -0.045     # z where the bridge leaves the face
    nose_tip_z: float = -0.095
    nose_base_z: float = -0.108
    nose_h: float = 0.028        # tip protrusion
    nose_bridge_h: float = 0.004
    nose_w: tuple = (0.005, 0.01)       # flat front half-width: at the bridge, at the tip
    nose_side: float = 0.012             # width of each side plane
    alae: float = 0.008
    # Eye plates.
    eye_inset: float = 0.004
    eye_plate: tuple = (1.25, 1.7)       # plate half-size in eye half-widths / heights
    brow_shelf: float = 0.004
    # Cheeks, lips, chin.
    cheek: float = 0.006
    cheek_pos: tuple = (0.11, -0.085)
    upper_lip: float = 0.003
    lower_lip: float = 0.004
    chin: float = 0.004
    # Mesh.
    rings: int = 100
    segments: int = 96


def _interp_sections(S, z):
    """Catmull-Rom through the sections (smooth: no crease at each one)."""
    keys = [np.array(sec, float) for sec in S.sections]      # top -> bottom, z decreasing
    zs = [k[0] for k in keys]
    if z >= zs[0]:
        return keys[0][1:]
    if z <= zs[-1]:
        return keys[-1][1:]
    i = next(j for j in range(len(zs) - 1) if zs[j] >= z >= zs[j + 1])
    p0, p1, p2, p3 = keys[max(i - 1, 0)], keys[i], keys[i + 1], keys[min(i + 2, len(keys) - 1)]
    t = (zs[i] - z) / (zs[i] - zs[i + 1])
    t2, t3 = t * t, t * t * t
    v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
    return v[1:]


def loft(head, L, S, name="head"):
    c = np.array(head.c)
    z_top, z_bot = S.sections[0][0], S.sections[-1][0]
    # Ring heights: most rings across the face band (brow to chin), so the
    # small forms (nose, lips, eye plates) resolve without folding.
    f_top, f_bot = L.eye_z + 0.06, L.chin_z - 0.004
    n_top = int(S.rings * 0.2)
    n_bot = int(S.rings * 0.1)
    n_face = S.rings - n_top - n_bot
    zs = np.concatenate([np.linspace(z_top, f_top, n_top, endpoint=False),
                         np.linspace(f_top, f_bot, n_face, endpoint=False),
                         np.linspace(f_bot, z_bot, n_bot)])
    # Angles: 0 = front (-y); vertices crowd the front.
    u = np.linspace(-math.pi, math.pi, S.segments, endpoint=False)
    ang = u - 0.8 * np.sin(u)

    bm = bmesh.new()
    rings = []
    for z in zs:
        w, yf, yb, nf, nb = _interp_sections(S, z)
        ring = []
        for a in ang:
            ca, sa = math.cos(a), math.sin(a)   # ca > 0: front half
            n = nf if ca > 0 else nb
            depth = -yf if ca > 0 else yb
            x = w * math.copysign(abs(sa) ** (2.0 / n), sa)
            y = -depth * math.copysign(abs(ca) ** (2.0 / n), ca)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    top = bm.verts.new((0.0, 0.0, z_top + 0.004))
    bottom = bm.verts.new((0.0, 0.0, z_bot - 0.002))
    m = len(ang)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(m):
            bm.faces.new((r0[k], r0[(k + 1) % m], r1[(k + 1) % m], r1[k]))
    for k in range(m):
        bm.faces.new((top, rings[0][(k + 1) % m], rings[0][k]))
        bm.faces.new((bottom, rings[-1][k], rings[-1][(k + 1) % m]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = common.mesh_object(name, bm)

    # --- the few deliberate facial forms (toward the viewer: -y) -----------
    me = obj.data
    n = len(me.vertices)
    co = np.empty(n * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(n, 3)
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    front = np.clip((-y - 0.08) / 0.08, 0.0, 1.0)
    dy = np.zeros(n)

    def smooth(e0, e1, v):
        tt = np.clip((v - e0) / (e1 - e0), 0.0, 1.0)
        return tt * tt * (3 - 2 * tt)

    # Nose wedge: a flat front plane between two side planes, rising from
    # a low bridge to an upturned tip, then a crisp under-plane.
    tb = np.clip((S.nose_top - z) / (S.nose_top - S.nose_tip_z), 0.0, 1.0)
    h = S.nose_bridge_h + (S.nose_h - S.nose_bridge_h) * tb ** 1.6
    below = smooth(S.nose_base_z - 0.01, S.nose_tip_z + 0.004, z)    # 0 under the nose .. 1 at the tip
    above = smooth(S.nose_top + 0.01, S.nose_top, z)
    a = S.nose_w[0] + (S.nose_w[1] - S.nose_w[0]) * tb
    across = np.clip((a + S.nose_side - np.abs(x)) / S.nose_side, 0.0, 1.0)
    dy += h * across * below * above
    tip = np.clip(1.0 - (x / (S.nose_w[1] * 2.0)) ** 2 - ((z - S.nose_tip_z) / 0.014) ** 2, 0.0, 1.0)
    dy += S.nose_h * 0.3 * tip ** 1.5
    for side in (-1, 1):
        ala = np.clip(1.0 - ((x - side * (S.nose_w[1] + S.nose_side * 0.6)) / 0.011) ** 2
                      - ((z - S.nose_base_z - 0.004) / 0.008) ** 2, 0.0, 1.0)
        dy += S.alae * ala ** 1.5
    # Cheek planes.
    for side in (-1, 1):
        ck = np.clip(1.0 - ((x - side * S.cheek_pos[0]) / 0.06) ** 2 - ((z - S.cheek_pos[1]) / 0.05) ** 2, 0.0, 1.0)
        dy += S.cheek * ck ** 2
    # Lips and chin: slight ridges across the mouth width.
    lipw = np.clip(1.0 - (x / (L.mouth_w * 1.15)) ** 2, 0.0, 1.0)
    line = L.mouth_z + L.smile * np.clip(x, -L.mouth_w, L.mouth_w) ** 2
    dy += S.upper_lip * np.clip(1.0 - ((z - line - 0.006) / 0.007) ** 2, 0.0, 1.0) * lipw
    dy += S.lower_lip * np.clip(1.0 - ((z - line + L.open_mouth + 0.008) / 0.009) ** 2, 0.0, 1.0) * lipw
    dy -= 0.0015 * np.clip(1.0 - ((z - line + L.open_mouth * 0.5) / 0.0035) ** 2, 0.0, 1.0) * lipw
    chin_z = L.chin_z + 0.025
    dy += S.chin * np.clip(1.0 - (x / 0.04) ** 2 - ((z - chin_z) / 0.025) ** 2, 0.0, 1.0)
    co[:, 1] -= dy * front
    y = co[:, 1]

    # Eye plates: flatten each eye area onto a slightly inset plane, so the
    # painted eye sits in a soft socket shadow under a brow shelf.
    for side in (-1, 1):
        ex = side * L.eye_x
        du = (x - ex) / (L.eye_w * S.eye_plate[0])
        dv = (z - L.eye_z) / (L.eye_h * S.eye_plate[1])
        mask = smooth(1.0, 0.35, np.sqrt(du * du + dv * dv)) * front
        y = y + S.eye_inset * mask
        shelf = smooth(L.eye_z + L.eye_h * 1.9, L.eye_z + L.eye_h * 1.3, z) * smooth(L.eye_z + L.eye_h * 4.0,
                                                                                         L.eye_z + L.eye_h * 2.4, z)
        shelf *= np.clip(1.0 - ((x - ex) / (L.eye_w * 1.6)) ** 2, 0.0, 1.0)
        y = y - S.brow_shelf * shelf * front
    co[:, 1] = y
    me.vertices.foreach_set("co", (co + c).ravel())
    me.update()
    return obj


def build_head(head, L, S, skin, skin_shade, blush, name="head"):
    obj = loft(head, L, S, name=name)   # a clean loft grid: no decimation (it folds the nose)
    common.shade_smooth(obj)
    head.bind(obj)
    common.color_by(obj, lambda p, nrm: common.lerp(skin, skin_shade, max(0.0, min(1.0, -nrm.z * 0.7))))
    return obj
