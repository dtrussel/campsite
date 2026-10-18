"""Mum's notebook (feature 047): a blank page of her ranger field journal
and a small sketch for each of her notes (docs/design/story.md, Mum's
notes), drawn as pencil and loose watercolour on cream paper.

The sketches are made from the team's own art, so they stay on model:
each takes a crop of a storybook painting or a concept sheet and turns it
into a field sketch (pencil lines from the edges, a pale washed-out
colour, paper grain, a ragged soft edge on transparency).

- game/assets/ui/story/notebook_page.webp: 1200x1600, the blank page.
- game/assets/ui/story/note_<n>.png: 512x512 with alpha, one per note in
  order (StoryCard shows it next to the note; the journal, 041, later).

Run with any Python that has Pillow and numpy, e.g.
.venv-blender/bin/python art/ui/notebook_art.py"""

import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "ui", "story")
PAPER = (239, 226, 196)            # UiKit cream canvas, #efe2c4
RULE = (150, 168, 190)
MARGIN = (196, 96, 84)
GRAPHITE = (62, 52, 46)
SKETCH_SIZE = 512

## Note n -> (source under art/, crop box as fractions x0, y0, x1, y1).
SKETCHES = [
    # 1: the rangers' old Moon Lantern.
    ("reference/concept-2026-10/16_moon_lantern_sheet.webp", (0.0, 0.18, 0.15, 0.8)),
    # 2: bits of moon in the moss.
    ("ui/source/story/c2_2.webp", (0.49, 0.48, 0.71, 0.87)),
    # 3: the shadows are lost things, and cold (an imp at the treeline).
    ("ui/source/story/c1_4.webp", (0.83, 0.42, 1.0, 0.76)),
    # 4: gremlins carry shiny things into the Hollow.
    ("ui/source/loading_gremlin.png", (0.47, 0.04, 0.83, 0.66)),
    # 5: near the old lantern the woods breathe easier.
    ("reference/concept-2026-10/16_moon_lantern_sheet.webp", (0.52, 0.18, 0.67, 0.8)),
    # 6: something big in the Hollow eats light.
    ("ui/source/story/c2_3.webp", (0.18, 0.08, 0.82, 0.95)),
    # 7: the big one is just lonely.
    ("reference/concept-2026-10/15_moon_eater_character_sheet.webp", (0.13, 0.03, 0.37, 0.52)),
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


def sketch(source, box, seed):
    """A field sketch of the crop: pencil lines, a pale wash, paper."""
    image = Image.open(source).convert("RGB")
    w, h = image.size
    crop = image.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))
    # Square it on the paper, keeping the whole subject.
    side = max(crop.size)
    square = Image.new("RGB", (side, side), PAPER)
    square.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2))
    fill = Image.new("L", (side, side), 0)
    ImageDraw.Draw(fill).rectangle(((side - crop.width) // 2, (side - crop.height) // 2,
                                    (side + crop.width) // 2, (side + crop.height) // 2), fill=255)
    size = (SKETCH_SIZE, SKETCH_SIZE)
    square = square.resize(size, Image.LANCZOS)
    fill = fill.resize(size, Image.LANCZOS)

    grey = ImageOps.grayscale(square)
    # Pencil: the difference of two blurs, so edges become soft graphite lines.
    fine = np.asarray(grey.filter(ImageFilter.GaussianBlur(1.0))).astype(np.float32)
    wide = np.asarray(grey.filter(ImageFilter.GaussianBlur(3.5))).astype(np.float32)
    lines = np.clip((wide - fine) * 6.0, 0, 255)
    lines = np.clip(lines - 14, 0, 255) / 255.0
    # Hatching in the shadows: diagonal strokes where the picture is dark.
    yy, xx = np.mgrid[0:SKETCH_SIZE, 0:SKETCH_SIZE]
    dark = np.clip((75.0 - fine) / 75.0, 0, 1)
    hatch = ((xx + yy) % 7 < 1.2) * dark * 0.35
    pencil = np.clip(lines + hatch, 0, 1)[..., None]

    # Watercolour: flattened, softened, washed-out colour that pools a bit.
    wash = square.filter(ImageFilter.GaussianBlur(3)).quantize(10).convert("RGB")
    wash = wash.filter(ImageFilter.ModeFilter(7)).filter(ImageFilter.GaussianBlur(1.5))
    wash = np.asarray(wash).astype(np.float32)
    grey_wash = wash.mean(axis=2, keepdims=True)
    # Lifted, as a wash is: the darks never go below a mid tone.
    wash = grey_wash + (wash - grey_wash) * 1.1
    wash = 70.0 + wash * 0.75
    sheet = np.asarray(paper(size, seed=seed)).astype(np.float32)
    tinted = sheet * (wash / 255.0) ** 0.9
    tinted = sheet * 0.15 + tinted * 0.85
    out = tinted * (1.0 - pencil * 0.85) + np.array(GRAPHITE, np.float32) * pencil * 0.85

    # A ragged, soft-edged vignette: a sketch on the page, not a photo.
    rng = random.Random(seed)
    blob = Image.new("L", size, 0)
    d = ImageDraw.Draw(blob)
    pts = []
    for k in range(28):
        a = np.pi * 2 * k / 28
        r = SKETCH_SIZE * (0.43 + rng.uniform(-0.035, 0.035))
        pts.append((SKETCH_SIZE / 2 + np.cos(a) * r, SKETCH_SIZE / 2 + np.sin(a) * r * 0.95))
    d.polygon(pts, fill=255)
    blob = blob.filter(ImageFilter.GaussianBlur(14))
    alpha = ImageChops.multiply(blob, fill.filter(ImageFilter.GaussianBlur(10)))
    result = Image.fromarray(out.clip(0, 255).astype(np.uint8)).convert("RGBA")
    result.putalpha(alpha)
    return result


def main():
    os.makedirs(OUT, exist_ok=True)
    notebook_page().save(os.path.join(OUT, "notebook_page.webp"), "WEBP", quality=88)
    for n, (source, box) in enumerate(SKETCHES, start=1):
        sketch(os.path.join(ROOT, "art", source), box, seed=n).save(os.path.join(OUT, "note_%d.png" % n))
    print("notebook_art: a page and %d sketches -> %s" % (len(SKETCHES), OUT))


if __name__ == "__main__":
    main()
