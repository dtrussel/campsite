"""Hand-painted, seamlessly tiling ground textures (LoL style): lush
painted grass, a packed-dirt clearing and an autumn leaf-litter forest
floor. Painted with numpy (brush stamps with wrap-around), not
rendered, so every texture tiles perfectly. No bpy needed; run with the
Blender venv's python for numpy.

Output: game/assets/custom/ground_{grass,dirt,leaves}.png"""

import math
import os
import struct
import zlib

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "game", "assets", "custom")
PREVIEW_DIR = os.environ.get("ART_PREVIEW_DIR", os.path.join(ROOT, "build", "art_previews"))
SIZE = 1024


def rgb(*c):
    return np.array(c, dtype=np.float32)


def write_png(path, image):
    """image: HxWx3 float 0..1 (sRGB)."""
    data = (np.clip(image, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    h, w, _ = data.shape
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def tile_noise(rng, beta=3.0, size=SIZE, low_cut=1.0):
    """Periodic 1/f^beta noise in 0..1 (tiles by construction)."""
    white = rng.standard_normal((size, size))
    f = np.fft.fftfreq(size) * size
    fx, fy = np.meshgrid(f, f)
    radius = np.sqrt(fx * fx + fy * fy)
    radius[0, 0] = 1.0
    amp = 1.0 / np.power(np.maximum(radius, low_cut), beta / 2.0)
    amp[0, 0] = 0.0
    field = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    field -= field.min()
    return (field / field.max()).astype(np.float32)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def blend(canvas, x0, y0, colour, alpha):
    """Alpha-blends an hxw patch (colour hxwx3 or 3, alpha hxw) at (x0, y0), wrapping."""
    h, w = alpha.shape
    ys = (np.arange(h) + int(y0)) % canvas.shape[0]
    xs = (np.arange(w) + int(x0)) % canvas.shape[1]
    region = canvas[np.ix_(ys, xs)]
    a = alpha[..., None]
    canvas[np.ix_(ys, xs)] = region * (1.0 - a) + colour * a


def stroke(canvas, cx, cy, angle, length, width, base, tip, opacity=1.0, taper=0.85):
    """A tapered brush stroke from (cx, cy) toward angle, colour base->tip."""
    pad = int(math.ceil(width)) + 2
    dx, dy = math.cos(angle), math.sin(angle)
    ex, ey = cx + dx * length, cy + dy * length
    x0, x1 = int(math.floor(min(cx, ex))) - pad, int(math.ceil(max(cx, ex))) + pad
    y0, y1 = int(math.floor(min(cy, ey))) - pad, int(math.ceil(max(cy, ey))) + pad
    gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
    rx, ry = gx - cx, gy - cy
    t = np.clip((rx * dx + ry * dy) / length, 0.0, 1.0)
    px, py = rx - dx * t * length, ry - dy * t * length
    dist = np.sqrt(px * px + py * py)
    half = width * 0.5 * (1.0 - t * taper) + 0.35
    alpha = np.clip(half - dist + 0.5, 0.0, 1.0) * opacity
    colour = base[None, None, :] * (1.0 - t[..., None]) + tip[None, None, :] * t[..., None]
    blend(canvas, x0, y0, colour, alpha.astype(np.float32))


def blob(canvas, cx, cy, rx, ry, colour, opacity=1.0, softness=0.35, angle=0.0, light=None):
    """Soft ellipse. light=(lit colour, shadow colour) shades it like a pebble."""
    r = max(rx, ry)
    x0, y0 = int(cx - r) - 2, int(cy - r) - 2
    size = int(2 * r) + 5
    gx, gy = np.meshgrid(np.arange(x0, x0 + size) + 0.5, np.arange(y0, y0 + size) + 0.5)
    ca, sa = math.cos(angle), math.sin(angle)
    lx = ((gx - cx) * ca + (gy - cy) * sa) / rx
    ly = (-(gx - cx) * sa + (gy - cy) * ca) / ry
    d = np.sqrt(lx * lx + ly * ly)
    alpha = np.clip((1.0 - d) / max(softness, 1e-3), 0.0, 1.0) * opacity
    col = np.broadcast_to(colour, (size, size, 3)).copy()
    if light is not None:
        lit, shade = light
        # Light from the top-left: -x, -y in texture space.
        k = np.clip(0.5 - ((gx - cx) / rx + (gy - cy) / ry) * 0.45, 0.0, 1.0)[..., None]
        col = shade * (1 - k) + colour * k
        col = np.where(k > 0.82, col * 0.4 + lit * 0.6, col)
    blend(canvas, x0, y0, col, alpha.astype(np.float32))


def leaf(canvas, rng, cx, cy, size, colour):
    angle = rng.uniform(0, math.tau)
    blob(canvas, cx + 1.5, cy + 2.0, size, size * 0.5, rgb(0, 0, 0) + colour * 0.35, opacity=0.35, angle=angle, softness=0.6)
    blob(canvas, cx, cy, size, size * 0.45, colour, angle=angle, softness=0.25)
    # Midrib.
    stroke(canvas, cx - math.cos(angle) * size * 0.8, cy - math.sin(angle) * size * 0.8, angle, size * 1.6, 1.2,
           colour * 0.7, colour * 0.9, opacity=0.6, taper=0.2)


def palette_lerp(stops, t):
    """stops: list of (t, colour). t: HxW array."""
    out = np.zeros(t.shape + (3,), dtype=np.float32)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        k = np.clip((t - t0) / (t1 - t0), 0.0, 1.0)[..., None]
        inside = ((t >= t0) & (t <= t1))[..., None]
        out = np.where(inside, c0 * (1 - k) + c1 * k, out)
    out = np.where((t < stops[0][0])[..., None], stops[0][1], out)
    out = np.where((t > stops[-1][0])[..., None], stops[-1][1], out)
    return out


def grass(seed=11):
    rng = np.random.default_rng(seed)
    macro = tile_noise(rng, 3.2)
    mid = tile_noise(rng, 2.2, low_cut=6.0)
    t = np.clip(macro * 0.75 + mid * 0.35 - 0.05, 0, 1)
    canvas = palette_lerp([(0.0, rgb(0.16, 0.34, 0.14)), (0.4, rgb(0.28, 0.5, 0.19)), (0.7, rgb(0.42, 0.62, 0.23)),
                           (1.0, rgb(0.6, 0.72, 0.3))], t)
    # Painted clumps: soft darker undersides with sunlit tops.
    for _ in range(420):
        x, y = rng.uniform(0, SIZE, 2)
        r = rng.uniform(18, 46)
        local = canvas[int(y) % SIZE, int(x) % SIZE]
        blob(canvas, x + r * 0.25, y + r * 0.3, r, r * 0.8, local * 0.72, opacity=0.5, softness=0.9)
        blob(canvas, x - r * 0.15, y - r * 0.2, r * 0.75, r * 0.6, np.minimum(local * 1.18 + 0.02, 1), opacity=0.45,
             softness=0.9)
    # Blades: tapered strokes, dark base to sunny tip, leaning "up".
    for _ in range(9000):
        x, y = rng.uniform(0, SIZE, 2)
        local = canvas[int(y) % SIZE, int(x) % SIZE].copy()
        angle = -math.pi / 2 + rng.normal(0, 0.45)
        length = rng.uniform(14, 34)
        base = local * rng.uniform(0.6, 0.85)
        tip = np.minimum(local * rng.uniform(1.1, 1.35) + rgb(0.05, 0.05, 0.0), 1.0)
        stroke(canvas, x, y, angle, length, rng.uniform(3.0, 5.5), base, tip, opacity=rng.uniform(0.55, 0.95))
    # Bright highlight flicks.
    for _ in range(1400):
        x, y = rng.uniform(0, SIZE, 2)
        stroke(canvas, x, y, -math.pi / 2 + rng.normal(0, 0.4), rng.uniform(8, 16), 2.5,
               rgb(0.55, 0.75, 0.3), rgb(0.85, 0.92, 0.5), opacity=0.55)
    # A few flower clusters (white daisies and yellow buttercups).
    for _ in range(26):
        cx, cy = rng.uniform(0, SIZE, 2)
        petal = rgb(1.0, 0.98, 0.92) if rng.random() < 0.55 else rgb(1.0, 0.85, 0.25)
        for _ in range(rng.integers(2, 5)):
            fx, fy = cx + rng.normal(0, 14), cy + rng.normal(0, 14)
            blob(canvas, fx + 1.5, fy + 2, 6, 6, rgb(0.1, 0.25, 0.1), opacity=0.4)
            for k in range(5):
                a = k / 5 * math.tau
                blob(canvas, fx + math.cos(a) * 3.2, fy + math.sin(a) * 3.2, 2.6, 2.6, petal, softness=0.3)
            blob(canvas, fx, fy, 1.8, 1.8, rgb(1.0, 0.7, 0.15), softness=0.3)
    return canvas


def dirt(seed=23):
    rng = np.random.default_rng(seed)
    macro = tile_noise(rng, 3.0)
    mid = tile_noise(rng, 2.0, low_cut=8.0)
    t = np.clip(macro * 0.7 + mid * 0.4 - 0.05, 0, 1)
    canvas = palette_lerp([(0.0, rgb(0.34, 0.24, 0.16)), (0.45, rgb(0.5, 0.37, 0.24)), (0.8, rgb(0.62, 0.48, 0.32)),
                           (1.0, rgb(0.72, 0.58, 0.4))], t)
    # Broad sideways brush strokes of packed earth.
    for _ in range(2600):
        x, y = rng.uniform(0, SIZE, 2)
        local = canvas[int(y) % SIZE, int(x) % SIZE]
        k = rng.uniform(0.85, 1.15)
        stroke(canvas, x, y, rng.normal(0, 0.25), rng.uniform(20, 60), rng.uniform(4, 10), local * k, local * k * 1.04,
               opacity=0.35, taper=0.4)
    # Twigs.
    for _ in range(30):
        x, y = rng.uniform(0, SIZE, 2)
        stroke(canvas, x + 1.5, y + 2, rng.uniform(0, math.tau), rng.uniform(22, 46), 3.5, rgb(0.2, 0.13, 0.08),
               rgb(0.2, 0.13, 0.08), opacity=0.35, taper=0.3)
        stroke(canvas, x, y, rng.uniform(0, math.tau), rng.uniform(22, 46), 3.0, rgb(0.42, 0.28, 0.16),
               rgb(0.55, 0.38, 0.22), opacity=0.9, taper=0.3)
    # Pebbles: cast shadow, then a lit stone.
    for _ in range(170):
        x, y = rng.uniform(0, SIZE, 2)
        r = rng.uniform(3.5, 11) if rng.random() < 0.85 else rng.uniform(12, 20)
        a = rng.uniform(0, math.pi)
        stone = rgb(0.58, 0.54, 0.5) * rng.uniform(0.85, 1.15) + rgb(0.04, 0.02, 0.0) * rng.uniform(-1, 1)
        blob(canvas, x + r * 0.35, y + r * 0.45, r * 1.05, r * 0.8, rgb(0.2, 0.14, 0.1), opacity=0.55, angle=a, softness=0.6)
        blob(canvas, x, y, r, r * 0.75, stone, angle=a, softness=0.25,
             light=(rgb(0.9, 0.88, 0.82), stone * 0.55 + rgb(0.02, 0.0, 0.05)))
    # A handful of fallen autumn leaves.
    for _ in range(22):
        x, y = rng.uniform(0, SIZE, 2)
        colour = [rgb(0.9, 0.45, 0.12), rgb(0.78, 0.22, 0.12), rgb(0.95, 0.7, 0.2)][rng.integers(0, 3)]
        leaf(canvas, rng, x, y, rng.uniform(7, 11), colour * rng.uniform(0.85, 1.05))
    return canvas


def leaves(seed=37):
    rng = np.random.default_rng(seed)
    macro = tile_noise(rng, 3.0)
    t = macro
    canvas = palette_lerp([(0.0, rgb(0.2, 0.14, 0.1)), (0.5, rgb(0.3, 0.22, 0.13)), (1.0, rgb(0.36, 0.3, 0.14))], t)
    for _ in range(900):
        x, y = rng.uniform(0, SIZE, 2)
        stroke(canvas, x, y, -math.pi / 2 + rng.normal(0, 0.5), rng.uniform(10, 22), 3.5,
               rgb(0.18, 0.26, 0.12), rgb(0.35, 0.45, 0.18), opacity=0.7)
    colours = [rgb(0.86, 0.4, 0.12), rgb(0.72, 0.2, 0.12), rgb(0.93, 0.66, 0.2), rgb(0.55, 0.3, 0.14),
               rgb(0.62, 0.16, 0.2)]
    for _ in range(1300):
        x, y = rng.uniform(0, SIZE, 2)
        colour = colours[rng.integers(0, len(colours))] * rng.uniform(0.7, 1.05)
        leaf(canvas, rng, x, y, rng.uniform(7, 13), colour)
    return canvas


def build():
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    made = {}
    for name, fn in (("grass", grass), ("dirt", dirt), ("leaves", leaves)):
        image = fn()
        write_png(os.path.join(OUT_DIR, "ground_%s.png" % name), image)
        made[name] = image
        print("ground_%s.png" % name)
    # Preview: each texture tiled 2x2 so seams would show.
    row = np.concatenate([np.tile(made[n][::2, ::2], (2, 2, 1)) for n in ("grass", "dirt", "leaves")], axis=1)
    write_png(os.path.join(PREVIEW_DIR, "ground_textures.png"), row)


if __name__ == "__main__":
    build()
