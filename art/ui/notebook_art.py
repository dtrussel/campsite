"""Mum's notebook (feature 047): a blank page of her ranger field journal
and a small sketch for each of her notes (docs/design/story.md, Mum's
notes), drawn as pencil and loose watercolour on cream paper.

The sketches are made from the team's own art, so they stay on model:
each cuts its subject out of a concept sheet (keyed against the sheet's
flat dark background) or a painting, and redraws it as a field sketch on
a torn, taped scrap of the notebook: pencil lines and hatching, a loose
watercolour wash that strays past the lines, a close-up inset where it
helps, and Mum's pencil marks (arrows, a size bar, little doodles; no
words, so nothing needs translating).

- game/assets/ui/story/notebook_page.webp: 1200x1600, the blank page.
- game/assets/ui/story/note_<n>.png: 512x512 with alpha, one per note in
  order (StoryCard shows it next to the note; the journal, 041, later).

Run with a Python that has Pillow, numpy and scikit-image, e.g.
.venv-blender/bin/python art/ui/notebook_art.py"""

import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from skimage import morphology
from skimage.filters import gaussian

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "ui", "story")
PAPER = (239, 226, 196)            # UiKit cream canvas, #efe2c4
RULE = (150, 168, 190)
MARGIN = (196, 96, 84)
GRAPHITE = (62, 52, 46)
SKETCH_SIZE = 512

LANTERN_SHEET = "reference/concept-2026-10/16_moon_lantern_sheet.webp"
MOON_EATER_SHEET = "reference/concept-2026-10/15_moon_eater_character_sheet.webp"

## One sketch per note, in order. Each is a list of studies drawn onto the
## scrap, then pencil marks (no words: nothing to translate, and the note
## says it). A study is (source under art/, crop box in source pixels, key,
## area on the 512 scrap it is fitted into, and optionally the source y of
## the sheet's floor, where the feet fade out):
## - key "bg": cut out against a sheet's flat dark background;
## - key "blue": only a bright blue moon crystal;
## - key "oval": a soft oval of the crop (for a painting or a close-up).
## "inset" studies get a loose pencil ring and an arrow to `point`, a spot
## on the main study as fractions of its box. "glow" spills a warm wash
## round a spot of the main study.
SKETCHES = [
    # 1: the rangers' old Moon Lantern, cold; the carved crescent close up.
    {"studies": [(LANTERN_SHEET, (15, 190, 190, 820), "bg", (150, 46, 300, 462)),
                 (LANTERN_SHEET, (1120, 200, 1230, 450), "oval", (322, 238, 446, 396))],
     "inset": {"point": (0.5, 0.74)},
     "marks": [("size_bar", 118, 70, 440), ("ground", 256, 452, 110), ("question", 380, 110, 22)]},
    # 2: bits of moon in the moss: three shards (the ones the kids hold up
    # in c2_2) nestled in a mossy tuft.
    {"studies": [(LANTERN_SHEET, (1100, 710, 1290, 832), "bg", (60, 300, 452, 456)),
                 ("ui/source/story/c2_2.webp", (1290, 130, 1470, 340), "blue", (150, 110, 270, 360)),
                 ("ui/source/story/c2_2.webp", (1720, 450, 1880, 670), "blue", (262, 200, 352, 380)),
                 ("ui/source/story/c2_2.webp", (1290, 130, 1470, 340), "blue", (96, 280, 160, 380))],
     "marks": [("sparkle", 104, 150, 16), ("sparkle", 410, 220, 12), ("sparkle", 380, 120, 9),
               ("crescent", 432, 80, 24), ("arrow", (420, 108), (350, 170), -0.3), ("ground", 256, 458, 170)]},
    # 3: the shadows are lost things, and cold: an imp, shivering.
    {"studies": [("reference/concept-2026-10/08_shadow_imp_concept.webp", (250, 150, 1160, 1300), "bg",
                  (70, 52, 442, 456), 1228)],
     "marks": [("snowflake", 92, 96, 22), ("snowflake", 430, 312, 16), ("shiver", 84, 300, 1),
               ("shiver", 440, 220, -1), ("ground", 256, 458, 130)]},
    # 4: gremlins carry shiny things into the Hollow: one, and a lost key.
    {"studies": [("reference/concept-2026-10/07_mushroom_goblin_concept.webp", (180, 500, 1026, 1572), "bg",
                  (52, 50, 392, 456), 1520)],
     "marks": [("key", 412, 392, 1.0), ("sparkle", 446, 352, 12), ("sparkle", 388, 352, 9),
               ("arrow", (350, 300), (400, 370), 0.35), ("ground", 220, 458, 140)]},
    # 5: near the old lantern the woods breathe easier: the lantern lit.
    {"studies": [(LANTERN_SHEET, (810, 220, 990, 820), "bg", (166, 50, 316, 462))],
     "glow": (0.5, 0.42, 150),
     "marks": [("rays", 0.5, 0.42, 96), ("ground", 256, 452, 120), ("leaf", 120, 420, 1), ("leaf", 380, 432, -1)]},
    # 6: something big in the Hollow eats light: just its eyes in the dark.
    {"studies": [("ui/source/story/c2_3.webp", (720, 140, 2060, 900), "oval", (36, 96, 476, 400))],
     "marks": [("trunk", 46, 40, 470), ("trunk", 470, 52, 466), ("question", 256, 448, 24)]},
    # 7: the big one is just lonely: the Moon-Eater, and the lost things in its chest.
    {"studies": [(MOON_EATER_SHEET, (515, 60, 695, 258), "bg", (40, 70, 340, 462)),
                 (MOON_EATER_SHEET, (300, 830, 560, 1050), "oval", (300, 52, 470, 222))],
     "inset": {"point": (0.5, 0.52)},
     "marks": [("crescent", 420, 300, 22), ("question", 112, 70, 22), ("ground", 196, 464, 140)]},
]


def paper(size, seed=0):
    """Cream paper with a soft fibre grain and a little uneven tone."""
    rng = np.random.default_rng(seed)
    w, h = size
    grain = rng.normal(0.0, 1.0, (h // 2, w // 2)).astype(np.float32)
    grain = np.asarray(Image.fromarray(((grain * 18) + 128).clip(0, 255).astype(np.uint8)).resize(size, Image.BILINEAR)
                       .filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) - 128
    blotch = np.asarray(Image.fromarray(rng.integers(0, 255, (8, 6), dtype=np.uint8)).resize(size, Image.BICUBIC)
                        .filter(ImageFilter.GaussianBlur(w / 12))).astype(np.float32) - 128
    base = np.array(PAPER, np.float32)[None, None, :]
    tone = (grain * 0.25 + blotch * 0.12)[..., None]
    return Image.fromarray((base + tone).clip(0, 255).astype(np.uint8))


def notebook_page():
    """The blank page: ruled lines, a red margin, a coffee ring, tape at the
    top corners and a pressed flower; the middle stays free for words."""
    w, h = 1200, 1600
    page = paper((w, h), seed=4)
    draw = ImageDraw.Draw(page, "RGBA")
    for y in range(260, h - 80, 64):
        draw.line([(60, y), (w - 60, y)], fill=RULE + (90,), width=2)
    draw.line([(170, 0), (170, h)], fill=MARGIN + (120,), width=3)
    # A coffee ring, lower right.
    for k in range(6):
        r = 120 + k * 1.5
        draw.ellipse((w - 330 - r, h - 360 - r, w - 330 + r, h - 360 + r), outline=(150, 100, 60, 26 + k * 6), width=3)
    # Tape on the top corners.
    for x, angle in ((150, 28), (w - 150, -28)):
        tape = Image.new("RGBA", (260, 70), (236, 222, 170, 150))
        tape = tape.rotate(angle, expand=True, resample=Image.BICUBIC)
        page.paste(tape, (x - tape.width // 2, 40 - tape.height // 2 + 30), tape)
    # A pressed flower, top right: five pale lupine-purple petals and a stem.
    cx, cy = w - 210, 170
    for k in range(5):
        a = k * 72
        petal = Image.new("RGBA", (60, 26), (0, 0, 0, 0))
        ImageDraw.Draw(petal).ellipse((0, 0, 59, 25), fill=(160, 128, 200, 150))
        petal = petal.rotate(a, expand=True, resample=Image.BICUBIC)
        dx, dy = np.cos(np.radians(a)) * 26, -np.sin(np.radians(a)) * 26
        page.paste(petal, (int(cx + dx - petal.width / 2), int(cy + dy - petal.height / 2)), petal)
    draw.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), fill=(222, 190, 90, 200))
    draw.line([(cx, cy + 12), (cx - 60, cy + 150)], fill=(110, 130, 70, 170), width=5)
    return page.filter(ImageFilter.GaussianBlur(0.4))


def key_mask(rgb, key):
    """A clean subject mask (0..1) for a crop."""
    a = rgb.astype(np.float32)
    h, w = a.shape[:2]
    if key == "oval":
        yy, xx = np.mgrid[0:h, 0:w]
        r = ((xx - w / 2) / (w * 0.48)) ** 2 + ((yy - h / 2) / (h * 0.48)) ** 2
        r += noise((h, w), max(8, min(h, w) // 10), h) * 0.18
        return np.clip((1.0 - r) * 3.0, 0, 1)
    if key == "blue":
        # Bright and blue: the crystal, not its halo or the hand holding it.
        hard = ((a[..., 2] - np.maximum(a[..., 0], a[..., 1]) * 0.85) > 14) & (a.mean(axis=2) > 150)
    else:
        border = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3),
                                 a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)])
        bg = np.median(border, axis=0)
        hard = np.linalg.norm(a - bg, axis=2) > 34
    hard = morphology.opening(hard, morphology.disk(1))
    hard = morphology.remove_small_objects(hard, max_size=h * w // 400)
    hard = morphology.remove_small_holes(hard, max_size=h * w // 50)
    return gaussian(hard.astype(np.float32), 1.0)


def place(canvas, cmask, lmask, source, box, key, area, floor=None):
    """Fits a study's subject into `area` of the canvas; returns where it
    landed (x0, y0, x1, y1). `floor` (a source y) fades the subject
    out over the sheet's ground strip. Cut-outs also go into `lmask`, which gets a
    silhouette line; an oval vignette does not."""
    crop = Image.open(source).convert("RGB").crop(box)
    rgb = np.asarray(crop)
    mask = key_mask(rgb, key)
    if floor is not None:
        # The feet fade out where the sheet's ground strip starts; Mum's
        # ground line goes under them instead.
        fade = np.clip((floor - box[1] - np.arange(mask.shape[0])) / 40.0, 0, 1)
        mask = mask * fade[:, None]
    ys, xs = np.nonzero(mask > 0.5)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgb, mask = rgb[y0:y1, x0:x1], mask[y0:y1, x0:x1]
    aw, ah = area[2] - area[0], area[3] - area[1]
    s = min(aw / rgb.shape[1], ah / rgb.shape[0])
    size = (max(1, int(rgb.shape[1] * s)), max(1, int(rgb.shape[0] * s)))
    rgb = np.asarray(Image.fromarray(rgb).resize(size, Image.LANCZOS)).astype(np.float32)
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).resize(size, Image.LANCZOS)) / 255.0
    px, py = area[0] + (aw - size[0]) // 2, area[3] - size[1]
    if key == "oval":
        py = area[1] + (ah - size[1]) // 2
    m = mask[..., None]
    region = canvas[py:py + size[1], px:px + size[0]]
    canvas[py:py + size[1], px:px + size[0]] = region * (1 - m) + rgb * m
    cmask[py:py + size[1], px:px + size[0]] = np.maximum(cmask[py:py + size[1], px:px + size[0]], mask)
    if key != "oval":
        lmask[py:py + size[1], px:px + size[0]] = np.maximum(lmask[py:py + size[1], px:px + size[0]], mask)
    return (px, py, px + size[0], py + size[1])


def noise(shape, scale, seed):
    """Smooth value noise in -1..1."""
    rng = np.random.default_rng(seed)
    small = rng.uniform(-1, 1, (max(2, shape[0] // scale), max(2, shape[1] // scale))).astype(np.float32)
    big = Image.fromarray(((small + 1) * 127.5).astype(np.uint8)).resize((shape[1], shape[0]), Image.BICUBIC)
    return np.asarray(big).astype(np.float32) / 127.5 - 1


def render(rgb, mask, lmask, seed):
    """Pencil and watercolour from a composed colour study and its mask:
    returns (wash multiplier HxWx3, pencil darkness HxW)."""
    shape = mask.shape
    grey = (rgb @ np.array([0.3, 0.59, 0.11], np.float32)) / 255.0
    inside = mask > 0.5
    lo, hi = np.percentile(grey[inside], [3, 97])
    g = np.clip((grey - lo) / max(hi - lo, 1e-3), 0, 1)
    g = g * inside + (1 - inside) * 1.0
    g = gaussian(g, 0.6)
    # Pencil lines: a thresholded difference of Gaussians (XDoG-ish), so the
    # weight swells along strong edges and fades on soft ones.
    fine, wide = gaussian(g, 1.0), gaussian(g, 2.4)
    lines = np.clip((wide - fine) * 9.0 - 0.06, 0, 1) ** 0.8
    # The silhouette, a firmer line, with a little hand wobble.
    edge = np.clip(gaussian(lmask, 1.2) - gaussian(lmask, 3.0), 0, 1) * 3.2
    wob = noise(shape, 24, seed) * 2.0
    edge = np.roll(edge, (int(wob.mean() > 0), 1), axis=(0, 1)) * 0.5 + edge * 0.5
    lines = np.maximum(lines, np.clip(edge, 0, 1) * (0.75 + 0.25 * noise(shape, 10, seed + 1)))
    # A second, fainter pass a pixel off, as a quick sketch has.
    lines = np.maximum(lines, np.roll(lines, (1, -1), axis=(0, 1)) * 0.35)
    # Hatching where it is dark, crossed in the deepest darks; strokes break up.
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
    dark = np.clip((0.55 - g) / 0.55, 0, 1) * inside
    breaks = noise(shape, 6, seed + 2) > -0.35
    hatch = (((xx + yy) % 6) < 1.3) * breaks * np.clip(dark * 1.4, 0, 1) * 0.55
    cross = (((xx - yy) % 7) < 1.1) * breaks * np.clip((dark - 0.5) * 2.0, 0, 1) * 0.45
    pencil = np.clip(lines + hatch + cross, 0, 1)

    # Watercolour: flattened colour, lifted towards the paper, a bit brighter.
    flat = Image.fromarray(rgb.clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))
    flat = flat.quantize(12).convert("RGB").filter(ImageFilter.ModeFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
    c = np.asarray(flat).astype(np.float32) / 255.0
    mean = c.mean(axis=2, keepdims=True)
    c = np.clip(mean + (c - mean) * 1.35, 0, 1)
    # Dark subjects keep their colour, not their darkness: graphite does that.
    level = np.clip(c.max(axis=2, keepdims=True), 0.25, 1)
    c = c / level * (0.55 + 0.45 * level)
    wash = 1.0 - 0.6 * (1.0 - np.clip(c, 0, 1))
    # The wash strays a little past the lines and pools at its edges.
    spread = gaussian(mask, 3.0) + noise(shape, 14, seed + 3) * 0.22
    wmask = np.roll((spread > 0.45).astype(np.float32), (-2, 3), axis=(0, 1))
    wmask = gaussian(wmask, 1.0)
    pool = np.clip(wmask - gaussian(wmask, 4.0), 0, 1) * 1.4
    grain = 1.0 - 0.07 * (noise(shape, 2, seed + 4) * 0.5 + 0.5) * wmask
    wash = 1.0 - (1.0 - wash) * wmask[..., None] * (1.0 + pool[..., None]) * 0.95
    return wash * grain[..., None], pencil


def glow_wash(shape, cx, cy, r, seed):
    """A warm watercolour bloom: soft, ragged, pooled at the rim."""
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
    d = np.hypot(xx - cx, yy - cy) / r + noise(shape, 18, seed) * 0.12
    bloom = np.clip(1.0 - d, 0, 1) ** 0.8
    rim = np.clip(1.0 - np.abs(d - 0.92) * 8, 0, 1) * 0.3
    tint = 1.0 - (1.0 - np.array([250, 206, 112], np.float32) / 255.0)[None, None, :]
    return 1.0 - (1.0 - tint) * (bloom + rim)[..., None] * 0.9


class Pencil:
    """Loose pencil marks: every stroke wobbles and is gone over twice."""

    def __init__(self, image, seed):
        self.draw = ImageDraw.Draw(image, "RGBA")
        self.rng = random.Random(seed)

    def stroke(self, pts, width=3, alpha=170):
        for k in range(2):
            j = 1.4 if k else 0.6
            wobbly = [(x + self.rng.uniform(-j, j), y + self.rng.uniform(-j, j)) for x, y in pts]
            self.draw.line(wobbly, fill=GRAPHITE + (alpha if k == 0 else alpha // 2,), width=width - k, joint="curve")

    def curve(self, p0, p1, bend, n=16):
        (x0, y0), (x1, y1) = p0, p1
        mx, my = (x0 + x1) / 2 - (y1 - y0) * bend, (y0 + y1) / 2 + (x1 - x0) * bend
        return [((1 - t) ** 2 * x0 + 2 * (1 - t) * t * mx + t * t * x1,
                 (1 - t) ** 2 * y0 + 2 * (1 - t) * t * my + t * t * y1) for t in np.linspace(0, 1, n)]

    def arrow(self, p0, p1, bend=0.2):
        pts = self.curve(p0, p1, bend)
        self.stroke(pts)
        (ax, ay), (bx, by) = pts[-3], pts[-1]
        a = np.arctan2(by - ay, bx - ax)
        for s in (2.6, -2.6):
            self.stroke([(bx + np.cos(a + s) * 14, by + np.sin(a + s) * 14), (bx, by)])

    def ring(self, box):
        x0, y0, x1, y1 = box
        cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2 + 8, (y1 - y0) / 2 + 8
        start = self.rng.uniform(0, np.pi * 2)
        pts = [(cx + np.cos(start + t) * rx * (1 + 0.04 * np.sin(t * 3)), cy + np.sin(start + t) * ry)
               for t in np.linspace(0, np.pi * 2.15, 48)]
        self.stroke(pts, width=3, alpha=150)

    def size_bar(self, x, y0, y1):
        self.stroke([(x, y0), (x, y1)], width=2, alpha=140)
        for y in (y0, y1):
            self.stroke([(x - 9, y), (x + 9, y)], width=2, alpha=140)
        # A small kid figure for scale, the way the concept sheets show it.
        self.stroke([(x - 22, y1), (x - 22, y1 - 48)], width=2, alpha=120)
        self.draw.ellipse((x - 30, y1 - 66, x - 14, y1 - 50), outline=GRAPHITE + (120,), width=2)

    def ground(self, cx, y, half):
        x = cx - half
        while x < cx + half:
            step = self.rng.uniform(14, 34)
            self.stroke([(x, y + self.rng.uniform(-2, 2)), (x + step, y + self.rng.uniform(-2, 2))], width=2, alpha=120)
            x += step + self.rng.uniform(4, 12)

    def question(self, cx, cy, s):
        pts = [(cx + np.cos(a) * s * 0.6, cy - s * 0.4 + np.sin(a) * s * 0.55) for a in np.linspace(-3.0, 1.2, 14)]
        pts += [(cx + 2, cy + s * 0.35)]
        self.stroke(pts, width=3)
        self.draw.ellipse((cx - 2, cy + s * 0.75, cx + 4, cy + s * 0.75 + 6), fill=GRAPHITE + (170,))

    def crescent(self, cx, cy, r):
        outer = [(cx + np.cos(a) * r, cy + np.sin(a) * r) for a in np.linspace(0.9, 5.4, 20)]
        inner = [(cx + r * 0.45 + np.cos(a) * r * 0.75, cy + np.sin(a) * r * 0.8) for a in np.linspace(4.2, 2.1, 14)]
        self.stroke(outer + inner + outer[:1], width=2)

    def sparkle(self, cx, cy, r):
        self.stroke([(cx - r, cy), (cx + r, cy)], width=2)
        self.stroke([(cx, cy - r), (cx, cy + r)], width=2)

    def snowflake(self, cx, cy, r):
        for k in range(3):
            a = k * np.pi / 3 + 0.2
            dx, dy = np.cos(a) * r, np.sin(a) * r
            self.stroke([(cx - dx, cy - dy), (cx + dx, cy + dy)], width=2, alpha=150)

    def shiver(self, x, y, side):
        for k in range(3):
            pts = [(x + side * (k * 8 + np.sin(t * 9) * 2.5), y - 20 + t * 40) for t in np.linspace(0, 1, 10)]
            self.stroke(pts, width=2, alpha=130)

    def key(self, cx, cy, s):
        self.draw.ellipse((cx - 12 * s, cy - 12 * s, cx + 12 * s, cy + 12 * s), outline=GRAPHITE + (170,), width=3)
        self.stroke([(cx + 12 * s, cy), (cx + 44 * s, cy)])
        self.stroke([(cx + 34 * s, cy), (cx + 34 * s, cy + 10 * s)], width=2)
        self.stroke([(cx + 42 * s, cy), (cx + 42 * s, cy + 8 * s)], width=2)

    def rays(self, cx, cy, r):
        for k in range(14):
            a = k * np.pi * 2 / 14 + self.rng.uniform(-0.1, 0.1)
            if 1.0 < a < 2.1:   # not down over the plinth
                continue
            r0, r1 = r * 0.82, r * self.rng.uniform(1.0, 1.15)
            self.stroke([(cx + np.cos(a) * r0, cy + np.sin(a) * r0), (cx + np.cos(a) * r1, cy + np.sin(a) * r1)],
                        width=2, alpha=120)

    def leaf(self, x, y, side):
        self.stroke([(x, y), (x + side * 18, y - 30)], width=2, alpha=130)
        left = self.curve((x + side * 6, y - 10), (x + side * 28, y - 34), 0.35, 8)
        right = self.curve((x + side * 28, y - 34), (x + side * 6, y - 10), 0.35, 8)
        self.stroke(left + right, width=2, alpha=130)

    def trunk(self, x, y0, y1):
        for dx in (-10, 10):
            self.stroke([(x + dx + self.rng.uniform(-3, 3), y) for y in np.linspace(y0, y1, 8)], width=2, alpha=110)


def scrap(seed):
    """A torn notebook scrap: cream paper with faint rules, a torn edge,
    tape at the top and a soft shadow, all with alpha."""
    rng = random.Random(seed)
    size = (SKETCH_SIZE, SKETCH_SIZE)
    sheet = paper(size, seed=seed + 20).convert("RGBA")
    draw = ImageDraw.Draw(sheet, "RGBA")
    for y in range(78, SKETCH_SIZE - 20, 34):
        draw.line([(0, y), (SKETCH_SIZE, y)], fill=RULE + (55,), width=1)
    edge = []
    lo, hi = 20, SKETCH_SIZE - 20
    for (x0, y0), (x1, y1) in (((lo, lo), (hi, lo)), ((hi, lo), (hi, hi)), ((hi, hi), (lo, hi)), ((lo, hi), (lo, lo))):
        for t in np.linspace(0, 1, 40, endpoint=False):
            j = 2.5 if (x0 == x1) else 4.0
            edge.append((x0 + (x1 - x0) * t + rng.uniform(-j, j), y0 + (y1 - y0) * t + rng.uniform(-j, j)))
    alpha = Image.new("L", size, 0)
    ImageDraw.Draw(alpha).polygon(edge, fill=255)
    return sheet, alpha.filter(ImageFilter.GaussianBlur(0.6))


def finish(sheet, alpha, seed):
    """Tape, a slight tilt and the drop shadow."""
    rng = random.Random(seed)
    sheet.putalpha(alpha)
    tape = Image.new("RGBA", (150, 40), (238, 226, 178, 165))
    tape = tape.rotate(rng.uniform(-8, 8), expand=True, resample=Image.BICUBIC)
    sheet.alpha_composite(tape, (SKETCH_SIZE // 2 - tape.width // 2 + rng.randint(-30, 30), 4))
    tilt = rng.choice((-1, 1)) * rng.uniform(1.5, 3.0)
    sheet = sheet.rotate(tilt, resample=Image.BICUBIC)
    shadow = Image.new("RGBA", sheet.size, (20, 12, 6, 0))
    shadow.putalpha(sheet.getchannel("A").point(lambda v: v * 0.5).filter(ImageFilter.GaussianBlur(6)))
    out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (4, 7))
    out.alpha_composite(sheet)
    return out


def sketch(spec, seed):
    """One note's sketch on a scrap of notebook paper."""
    shape = (SKETCH_SIZE, SKETCH_SIZE)
    canvas = np.full(shape + (3,), 255.0, np.float32)
    cmask = np.zeros(shape, np.float32)
    lmask = np.zeros(shape, np.float32)
    boxes = [place(canvas, cmask, lmask, os.path.join(ROOT, "art", study[0]), *study[1:])
             for study in spec["studies"]]
    wash, pencil = render(canvas, cmask, lmask, seed)
    sheet, alpha = scrap(seed)
    out = np.asarray(sheet.convert("RGB")).astype(np.float32) * wash
    main = boxes[0]
    if "glow" in spec:
        fx, fy, r = spec["glow"]
        out *= glow_wash(shape, main[0] + (main[2] - main[0]) * fx, main[1] + (main[3] - main[1]) * fy, r, seed)
    out = out * (1.0 - pencil[..., None] * 0.88) + np.array(GRAPHITE, np.float32) * pencil[..., None] * 0.88
    sheet = Image.fromarray(out.clip(0, 255).astype(np.uint8)).convert("RGBA")
    hand = Pencil(sheet, seed)
    if "inset" in spec:
        inset = boxes[1]
        hand.ring(inset)
        fx, fy = spec["inset"]["point"]
        target = (main[0] + (main[2] - main[0]) * fx, main[1] + (main[3] - main[1]) * fy)
        start = (inset[0] - 6, (inset[1] + inset[3]) / 2 + 20)
        hand.arrow(start, (target[0] + 18, target[1]), 0.25)
    for mark in spec.get("marks", []):
        kind, args = mark[0], list(mark[1:])
        if kind == "rays":
            fx, fy, r = args
            args = [main[0] + (main[2] - main[0]) * fx, main[1] + (main[3] - main[1]) * fy, r]
        getattr(hand, kind)(*args)
    return finish(sheet, alpha, seed)


def main():
    os.makedirs(OUT, exist_ok=True)
    notebook_page().save(os.path.join(OUT, "notebook_page.webp"), "WEBP", quality=88)
    for n, spec in enumerate(SKETCHES, start=1):
        sketch(spec, seed=n).save(os.path.join(OUT, "note_%d.png" % n))
    print("notebook_art: a page and %d sketches -> %s" % (len(SKETCHES), OUT))


if __name__ == "__main__":
    main()
