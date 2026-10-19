"""Mum's notebook (feature 047): a blank page of her ranger field journal
and a sketch for each of her notes (docs/design/story.md, Mum's notes).

The sketches are the team's painted pages, ink and watercolour on cream
paper with a ragged edge (art/ui/source/notebook/note_<n>.webp, 1024
square with alpha, one per note in order). This script tidies the matte
edge, scales them down and pins each to the card: a strip of tape, a
slight tilt and a soft shadow, so it reads on the dark wood.

- game/assets/ui/story/notebook_page.webp: 1200x1600, the blank page.
- game/assets/ui/story/note_<n>.png: 512x512 with alpha, one per note in
  order (StoryCard shows it next to the note; the journal, 041, later).

Run with any Python that has Pillow and numpy, e.g.
.venv-blender/bin/python art/ui/notebook_art.py"""

import glob
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "ui", "story")
SOURCE = os.path.join(ROOT, "art", "ui", "source", "notebook")
PAPER = (239, 226, 196)            # UiKit cream canvas, #efe2c4
RULE = (150, 168, 190)
MARGIN = (196, 96, 84)
SKETCH_SIZE = 512
MARGIN_PX = 22                     # room round the page for the tilt and shadow


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


def finish(sheet, seed):
    """Tape, a slight tilt and the drop shadow."""
    rng = random.Random(seed)
    tape = Image.new("RGBA", (150, 40), (238, 226, 178, 165))
    tape = tape.rotate(rng.uniform(-8, 8), expand=True, resample=Image.BICUBIC)
    sheet.alpha_composite(tape, (SKETCH_SIZE // 2 - tape.width // 2 + rng.randint(-30, 30), MARGIN_PX - 8))
    tilt = rng.choice((-1, 1)) * rng.uniform(1.5, 3.0)
    sheet = sheet.rotate(tilt, resample=Image.BICUBIC)
    shadow = Image.new("RGBA", sheet.size, (20, 12, 6, 0))
    shadow.putalpha(sheet.getchannel("A").point(lambda v: v * 0.5).filter(ImageFilter.GaussianBlur(6)))
    out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (4, 7))
    out.alpha_composite(sheet)
    return out


def sketch(path, seed):
    """One painted page, tidied and pinned for the card."""
    page = Image.open(path).convert("RGBA")
    # The matte edge has stray specks of paper; a median on the alpha drops
    # them and keeps the ragged edge, a touch of blur softens it.
    alpha = page.getchannel("A").filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(0.8))
    page.putalpha(alpha)
    inner = SKETCH_SIZE - 2 * MARGIN_PX
    page = page.resize((inner, inner), Image.LANCZOS)
    sheet = Image.new("RGBA", (SKETCH_SIZE, SKETCH_SIZE), (0, 0, 0, 0))
    sheet.alpha_composite(page, (MARGIN_PX, MARGIN_PX))
    return finish(sheet, seed)


def main():
    os.makedirs(OUT, exist_ok=True)
    notebook_page().save(os.path.join(OUT, "notebook_page.webp"), "WEBP", quality=88)
    pages = sorted(glob.glob(os.path.join(SOURCE, "note_*.webp")), key=lambda p: int(p.rsplit("_", 1)[1].split(".")[0]))
    for n, path in enumerate(pages, start=1):
        sketch(path, seed=n).save(os.path.join(OUT, "note_%d.png" % n))
    print("notebook_art: a page and %d sketches -> %s" % (len(pages), OUT))


if __name__ == "__main__":
    main()
