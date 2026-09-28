"""Hand-painted faces, the League of Legends way: the eyes, brows, nose
shading and lips are *painted into the texture* (not modelled or stuck
on), on top of a head whose sculpt uses the same FaceLayout, so paint
and relief line up.

The painting happens in numpy in a front-projected "face plane":
u = x - head_centre.x and v = z - head_centre.z (metres). The image
covers [-size, size] on both axes; its border stays transparent, so any
mesh without real face UVs samples nothing.
"""

import math
import os
from dataclasses import dataclass, field

import numpy as np

RES = 1024


@dataclass
class FaceLayout:
    size: float = 0.36            # half-extent of the painted square (m)
    eye_x: float = 0.085          # eye centre, left/right
    eye_z: float = 0.0            # eye centre height
    eye_w: float = 0.036          # half-width of the eye opening
    eye_h: float = 0.018          # half-height
    eye_tilt: float = 0.12        # outer corner lift (dv per du)
    lid: float = 0.2              # 0 open ... 0.5 heavy, half-lidded
    iris_r: float = 0.015
    look: tuple = (0.0, 0.0)      # iris offset (u toward his left, v up)
    iris: tuple = (0.3, 0.62, 0.9)
    iris_dark: tuple = (0.05, 0.2, 0.42)
    lash: tuple = (0.12, 0.07, 0.06)
    lash_width: float = 0.007
    wing: float = 0.01
    lower_lash: float = 0.4       # opacity
    eyeshadow: tuple = (0.62, 0.38, 0.36)
    eyeshadow_alpha: float = 0.35
    socket: tuple = (0.72, 0.46, 0.4)
    brows: tuple = ((0.05, 0.12, 0.009, 0.006), (0.05, 0.12, 0.009, 0.006))  # (dz, tilt, thick, arch) left, right
    brow_len: float = 0.05
    brow_colour: tuple = (0.45, 0.3, 0.16)
    nose_z: float = -0.075
    nose_w: float = 0.018
    mouth_z: float = -0.14
    mouth_w: float = 0.04
    smile: float = 6.0            # mouth line curvature (v = smile * u^2)
    smirk: float = 0.0            # >0 raises his left corner, <0 his right
    lip_upper: float = 0.008
    lip_lower: float = 0.011
    lip_colour: tuple = (0.78, 0.44, 0.4)
    lip_dark: tuple = (0.5, 0.22, 0.2)
    open_mouth: float = 0.0       # 0 closed, >0 shows teeth (m)
    chin_z: float = -0.22
    skin_shadow: tuple = (0.7, 0.44, 0.38)
    blush: tuple = (1.0, 0.5, 0.48)
    blush_alpha: float = 0.25
    blush_pos: tuple = (0.12, -0.08)
    freckles: list = field(default_factory=list)
    freckle_colour: tuple = (0.72, 0.42, 0.28)
    marks: list = field(default_factory=list)   # [(points, widths, rgb, alpha)]
    brow_alpha: float = 0.9
    socket_alpha: float = 0.5
    contour: float = 0.35         # painted cheek/jaw/temple shading strength
    highlight: tuple = (1.0, 0.9, 0.8)


def _grid(layout):
    s = layout.size
    ax = (np.arange(RES) + 0.5) / RES * 2 * s - s
    u, v = np.meshgrid(ax, -ax)  # row 0 = top (+v)
    return u.astype(np.float32), v.astype(np.float32), 2 * s / RES


def _over(canvas, rgb, alpha):
    """Straight-alpha 'over' compositing onto an RGBA canvas."""
    a = np.clip(alpha, 0.0, 1.0).astype(np.float32)
    rgb = np.asarray(rgb, dtype=np.float32)
    if rgb.ndim == 1:
        rgb = np.broadcast_to(rgb, canvas[..., :3].shape)
    base_a = canvas[..., 3]
    out_a = a + base_a * (1.0 - a)
    safe = np.where(out_a > 1e-6, out_a, 1.0)[..., None]
    canvas[..., :3] = (rgb * a[..., None] + canvas[..., :3] * (base_a * (1.0 - a))[..., None]) / safe
    canvas[..., 3] = out_a


def _soft_ellipse(u, v, cu, cv, a, b, softness=1.0):
    d = np.sqrt(((u - cu) / a) ** 2 + ((v - cv) / b) ** 2)
    return np.clip(1.0 - d, 0.0, 1.0) ** softness


def _aa(dist, px):
    """Coverage from a signed distance (positive inside)."""
    return np.clip(dist / px + 0.5, 0.0, 1.0)


def _stroke(u, v, points, widths, px, soft=0.0):
    """Coverage of a tapered brush stroke along a polyline."""
    best = np.full(u.shape, 1e9, dtype=np.float32)
    for i in range(len(points) - 1):
        (x0, y0), (x1, y1) = points[i], points[i + 1]
        w0, w1 = widths[i], widths[i + 1]
        dx, dy = x1 - x0, y1 - y0
        seg = dx * dx + dy * dy or 1e-9
        t = np.clip(((u - x0) * dx + (v - y0) * dy) / seg, 0.0, 1.0)
        px_, py_ = x0 + t * dx, y0 + t * dy
        d = np.sqrt((u - px_) ** 2 + (v - py_) ** 2) - (w0 + (w1 - w0) * t) * 0.5
        best = np.minimum(best, d)
    if soft:
        return np.clip(1.0 - (best + soft) / (2 * soft), 0.0, 1.0)
    return _aa(-best, px)


def _eye_curves(layout, side):
    """top(du), bottom(du) of the eye opening, du measured from the eye
    centre with + pointing outward (toward the temple)."""
    w, h, lid, tilt = layout.eye_w, layout.eye_h, layout.lid, layout.eye_tilt

    def top(du):
        t = np.clip(1.0 - (du / w) ** 2, 0.0, 1.0)
        # Almond: the peak sits toward the inner corner; heavy lids flatten it.
        skew = 1.0 + 0.25 * (-du / w)
        return h * (1.0 - lid) * t ** (0.6 + lid) * skew + tilt * du

    def bottom(du):
        t = np.clip(1.0 - (du / w) ** 2, 0.0, 1.0)
        return -h * 0.7 * t ** 0.8 + tilt * du
    return top, bottom


def paint_face(layout, path):
    u, v, px = _grid(layout)
    canvas = np.zeros((RES, RES, 4), dtype=np.float32)
    L = layout

    # --- painted contours: LoL faces carry their lighting in the paint ---
    for side in (-1, 1):
        # Hollow under the cheekbone, temple and jaw side shading.
        _over(canvas, L.skin_shadow, L.contour * _stroke(u, v, [(side * (L.eye_x + L.eye_w * 1.3), L.eye_z - 0.05),
                                                                 (side * (L.eye_x * 0.75), L.mouth_z + 0.01)],
                                                          [0.03, 0.018], px, soft=0.018))
        _over(canvas, L.skin_shadow, L.contour * 0.8 * _soft_ellipse(u, v, side * (L.eye_x + L.eye_w * 1.9),
                                                                     L.eye_z + 0.03, 0.03, 0.06, 1.3))
        _over(canvas, L.skin_shadow, L.contour * 0.9 * _stroke(u, v, [(side * (L.eye_x * 1.25), L.mouth_z - 0.01),
                                                                       (side * L.mouth_w * 1.1, L.chin_z + 0.005)],
                                                                [0.03, 0.02], px, soft=0.02))
        # Under-brow shadow and a cheekbone highlight.
        _over(canvas, L.skin_shadow, L.contour * 0.8 * _soft_ellipse(u, v, side * L.eye_x, L.eye_z + L.eye_h * 1.8,
                                                                     L.eye_w * 1.3, L.eye_h * 0.9, 1.1))
        _over(canvas, L.highlight, L.contour * 0.6 * _soft_ellipse(u, v, side * (L.eye_x + 0.01), L.eye_z - 0.04,
                                                                   0.022, 0.012, 1.4))
    # Highlights down the nose bridge, on the forehead and chin.
    _over(canvas, L.highlight, L.contour * 0.7 * _stroke(u, v, [(0.0, L.eye_z + 0.005), (0.0, L.nose_z + 0.008)],
                                                          [0.006, 0.008], px, soft=0.005))
    _over(canvas, L.highlight, L.contour * 0.5 * _soft_ellipse(u, v, 0.0, L.eye_z + 0.075, 0.05, 0.03, 1.4))
    _over(canvas, L.highlight, L.contour * 0.5 * _soft_ellipse(u, v, 0.0, L.chin_z + 0.025, 0.018, 0.012, 1.3))

    # --- soft skin shading painted around the features -----------------
    for side in (-1, 1):
        ex = side * L.eye_x
        # Eye-socket shadow and eyeshadow on the upper lid.
        _over(canvas, L.socket, L.socket_alpha * _soft_ellipse(u, v, ex, L.eye_z + L.eye_h * 0.4, L.eye_w * 1.6,
                                                        L.eye_h * 2.6, 1.4))
        _over(canvas, L.eyeshadow, L.eyeshadow_alpha * _soft_ellipse(u, v, ex + side * L.eye_w * 0.15,
                                                                     L.eye_z + L.eye_h * 1.2, L.eye_w * 1.3,
                                                                     L.eye_h * 1.5, 1.2))
        # Cheek blush.
        _over(canvas, L.blush, L.blush_alpha * _soft_ellipse(u, v, side * L.blush_pos[0], L.blush_pos[1],
                                                             0.045, 0.03, 1.5))
    # Nose: shadow down one side of the bridge and under the tip.
    _over(canvas, L.skin_shadow, 0.6 * _stroke(u, v, [(L.nose_w * 0.9, L.eye_z - L.eye_h),
                                                        (L.nose_w * 1.1, L.nose_z + 0.005)],
                                                [0.008, 0.012], px, soft=0.006))
    _over(canvas, L.skin_shadow, 0.45 * _soft_ellipse(u, v, 0.0, L.nose_z - 0.012, L.nose_w * 1.4, 0.008, 1.2))
    for side in (-1, 1):
        _over(canvas, L.lip_dark, 0.55 * _soft_ellipse(u, v, side * L.nose_w * 0.55, L.nose_z - 0.006, 0.0055,
                                                       0.0035, 0.8))
    _over(canvas, (1.0, 0.92, 0.85), 0.35 * _soft_ellipse(u, v, 0.0, L.nose_z + 0.004, 0.008, 0.007, 1.2))
    # Philtrum and under-lip / chin shading.
    _over(canvas, L.skin_shadow, 0.2 * _soft_ellipse(u, v, 0.0, (L.nose_z + L.mouth_z) * 0.5, 0.006, 0.014))
    _over(canvas, L.skin_shadow, 0.3 * _soft_ellipse(u, v, 0.0, L.mouth_z - L.lip_lower - 0.01, L.mouth_w * 0.7,
                                                     0.009, 1.2))

    # --- eyes ------------------------------------------------------------
    for side in (-1, 1):
        ex = side * L.eye_x
        top, bottom = _eye_curves(L, side)
        du = (u - ex) * side  # outward positive
        dv = v - L.eye_z
        inside_top = top(du) - dv
        inside_bottom = dv - bottom(du)
        inside_side = L.eye_w - np.abs(du)
        open_d = np.minimum(np.minimum(inside_top, inside_bottom), inside_side)
        eye_a = _aa(open_d, px)
        # Sclera, shaded by the lid at the top.
        lid_shade = np.clip(1.0 - inside_top / (L.eye_h * 0.9), 0.0, 1.0)
        sclera = np.stack([0.97 - 0.3 * lid_shade, 0.95 - 0.33 * lid_shade, 0.93 - 0.3 * lid_shade], -1)
        _over(canvas, sclera, eye_a)
        # Iris with a dark limbal ring, lighter bottom, pupil, catchlight.
        iu = ex + side * L.look[0]
        iv = L.eye_z + L.look[1]
        r = np.sqrt((u - iu) ** 2 + (v - iv) ** 2) / L.iris_r
        low = np.clip((iv - v) / L.iris_r * 0.5 + 0.5, 0.0, 1.0)
        base = np.array(L.iris_dark, np.float32) * (1 - low[..., None]) + np.array(L.iris, np.float32) * low[..., None]
        ring = np.clip((r - 0.72) / 0.28, 0.0, 1.0)[..., None]
        iris_rgb = base * (1 - ring) + np.array(L.iris_dark, np.float32) * 0.6 * ring
        # Lid shadow falls on the iris too.
        iris_rgb = iris_rgb * (1.0 - 0.45 * lid_shade[..., None])
        _over(canvas, iris_rgb, _aa((1.0 - r) * L.iris_r, px) * eye_a)
        pr = np.sqrt((u - iu) ** 2 + (v - iv) ** 2) / (L.iris_r * 0.45)
        _over(canvas, (0.03, 0.03, 0.05), _aa((1.0 - pr) * L.iris_r * 0.45, px) * eye_a)
        hu, hv = iu - side * L.iris_r * 0.3, iv + L.iris_r * 0.35
        _over(canvas, (1.0, 1.0, 1.0), _aa((1.0 - np.sqrt(((u - hu) / (L.iris_r * 0.28)) ** 2 +
                                                          ((v - hv) / (L.iris_r * 0.24)) ** 2)) * L.iris_r * 0.25, px)
              * eye_a)
        # Upper lash line: thick, tapering in, with a wing at the outer corner.
        n = 14
        pts, widths = [], []
        for k in range(n + 1):
            d = -L.eye_w + 2 * L.eye_w * k / n
            pts.append((ex + side * d, L.eye_z + float(top(np.float32(d))) + L.lash_width * 0.25))
            widths.append(L.lash_width * (0.35 + 0.65 * min(1.0, (d / L.eye_w + 1.0) * 0.7)))
        pts.append((ex + side * (L.eye_w + L.wing), L.eye_z + float(top(np.float32(L.eye_w))) + L.wing * 0.7))
        widths.append(L.lash_width * 0.15)
        _over(canvas, L.lash, _stroke(u, v, pts, widths, px))
        # Lid crease above.
        crease = [(ex + side * d, L.eye_z + float(top(np.float32(d))) + L.eye_h * 0.9)
                  for d in np.linspace(-L.eye_w * 0.7, L.eye_w * 0.9, 8)]
        _over(canvas, L.socket, 0.55 * _stroke(u, v, crease, [0.0025] * len(crease), px, soft=0.002))
        # Lower lash, outer two thirds.
        lower = [(ex + side * d, L.eye_z + float(bottom(np.float32(d))) - 0.0015)
                 for d in np.linspace(-L.eye_w * 0.3, L.eye_w * 0.95, 8)]
        _over(canvas, L.lash, L.lower_lash * _stroke(u, v, lower, [0.0018] * len(lower), px))

    # --- brows -------------------------------------------------------------
    for i, side in enumerate((1, -1)):
        dz, tilt, thick, arch = L.brows[0 if side > 0 else 1]
        bx = side * L.eye_x
        by = L.eye_z + L.eye_h + dz
        for offset in (-0.0015, 0.0, 0.0015):
            pts, widths = [], []
            for k in range(9):
                t = k / 8
                d = (t - 0.35) * L.brow_len
                pts.append((bx + side * d, by + arch * math.sin(math.pi * min(1.0, t * 1.2)) + tilt * d + offset))
                widths.append(thick * (1.0 - t) ** 0.6 * (0.6 + 0.4 * math.sin(math.pi * min(1.0, t + 0.2))) + 0.001)
            _over(canvas, L.brow_colour, L.brow_alpha * 0.6 * _stroke(u, v, pts, widths, px))

    # --- mouth -------------------------------------------------------------
    def line(x):
        return L.mouth_z + L.smile * x * x + L.smirk * x

    xs = np.linspace(-L.mouth_w, L.mouth_w, 17)
    # Lips: upper (darker, bow-shaped) and lower (fuller, with a highlight).
    mu = u
    lipw = np.clip(1.0 - (mu / (L.mouth_w * 1.05)) ** 2, 0.0, 1.0)
    bow = L.lip_upper * lipw ** 0.7 * (1.0 + 0.35 * np.exp(-(np.abs(mu) - L.mouth_w * 0.25) ** 2 / 0.00006))
    upper_top = line(mu) + bow
    upper = np.minimum(upper_top - v, v - line(mu))
    _over(canvas, L.lip_dark,
          _aa(upper, px) * (np.abs(mu) < L.mouth_w * 1.05))
    lower_bottom = line(mu) - L.lip_lower * lipw ** 0.8 - L.open_mouth
    lower = np.minimum(line(mu) - L.open_mouth - v, v - lower_bottom)
    _over(canvas, L.lip_colour, _aa(lower, px) * (np.abs(mu) < L.mouth_w * 1.05))
    _over(canvas, (1.0, 0.85, 0.8), 0.35 * _soft_ellipse(u, v, L.mouth_w * 0.15, line(0.0) - L.open_mouth -
                                                         L.lip_lower * 0.45, L.mouth_w * 0.35, L.lip_lower * 0.22))
    if L.open_mouth > 0:
        opening = np.minimum(line(mu) - v, v - (line(mu) - L.open_mouth * lipw ** 0.6))
        _over(canvas, (0.3, 0.07, 0.08), _aa(opening, px) * (np.abs(mu) < L.mouth_w))
        teeth = np.minimum(line(mu) - v, v - (line(mu) - L.open_mouth * 0.45 * lipw ** 0.6))
        _over(canvas, (0.97, 0.95, 0.9), _aa(teeth, px) * (np.abs(mu) < L.mouth_w * 0.8))
    pts = [(x, line(x)) for x in xs]
    _over(canvas, L.lip_dark, _stroke(u, v, pts, [0.0022] * len(pts), px))
    for side in (-1, 1):
        cx = side * L.mouth_w
        _over(canvas, L.skin_shadow, 0.5 * _soft_ellipse(u, v, cx * 1.05, line(cx) + 0.002, 0.006, 0.006, 1.2))

    # --- freckles and face-paint marks --------------------------------------
    for (fu, fv) in L.freckles:
        _over(canvas, L.freckle_colour, 0.6 * _soft_ellipse(u, v, fu, fv, 0.0035, 0.003, 0.7))
    for points, widths, rgb, alpha in L.marks:
        _over(canvas, rgb, alpha * _stroke(u, v, points, widths, px))

    # Keep a transparent border (non-face meshes sample the corner).
    canvas[:8, :, 3] = canvas[-8:, :, 3] = 0
    canvas[:, :8, 3] = canvas[:, -8:, 3] = 0
    _write_rgba(path, canvas)
    return path


def _write_rgba(path, image):
    import struct
    import zlib
    data = (np.clip(image, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    h, w, _ = data.shape
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
