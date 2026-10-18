"""Story art (features 043 and 047): Mum's portraits for the storybook, cut
from the team's character sheet (art/ui/source/mum_sheet.png, also kept as
art/reference/concept-2026-10/14_mum_character_sheet.webp), the kids'
expression portraits, and the storybook paintings.

- game/assets/ui/story/mum.png: the default portrait (smiling).
- game/assets/ui/story/mum_<face>.png: one per expression on the sheet,
  picked per story line with the line's "face" key.
- game/assets/ui/story/<hero>_<face>.png: the kids' expressions, cut from
  art/ui/source/<hero>_<face>.webp (047; Nela's surprised, worried and
  laugh so far).
- game/assets/ui/story/story_<page>.webp: the team's storybook paintings
  (art/ui/source/story/<page>.webp, 2560x1440), 1600x900 for the intro
  and ending pages. The Chapter 2 intro's lantern is retouched cold
  (`cold_lantern`): the painting showed it lit, the story says cold.

Each is a round 192 px bust with a soft edge and a brass ring, the same
round shape as the kids' portraits. Run with any Python that has
Pillow, e.g. .venv-blender/bin/python art/ui/story_art.py"""

import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "art", "ui", "source", "mum_sheet.png")
OUT = os.path.join(ROOT, "game", "assets", "ui", "story")
SIZE = 192
BRASS = (201, 150, 74, 255)        # UiKit.COLOR_BRASS
INK = (40, 24, 14, 255)            # UiKit.COLOR_INK

## Expression heads on the sheet: face -> (centre x, centre y, square side).
FACES = {
    "smile": (1130, 122, 150),
    "curious": (1285, 122, 150),
    "laugh": (1442, 122, 150),
    "surprised": (1130, 318, 150),
    "worried": (1288, 318, 150),
    "proud": (1442, 318, 150),
}
DEFAULT = "smile"
## The kids' expressions (047): file -> (centre x, centre y, square side)
## on the 1024 px source.
KID_FACES = {
    "nela_surprised": (540, 530, 820),
    "nela_worried": (540, 530, 820),
    "nela_laugh": (540, 530, 820),
}
## Storybook pages (047): source name -> lift (0 = as painted).
PAINTINGS = {
    "c1_1": 0.0, "c1_2": 0.0, "c1_3": 0.0, "c1_4": 0.0,
    "c2_1": 0.0, "c2_2": 0.0, "c2_3": 0.0,
    "win_c1_1": 0.0, "win_c1_2": 0.0,
    "win_c2_1": 0.0, "win_c2_2": 0.0, "win_c2_3": 0.0,
}
PAINTING_SIZE = (1600, 900)
## Mum's lantern glass in the Chapter 2 intro source (2560x1440):
## centre x, centre y, half width, half height.
LANTERN_GLASS = (1864, 512, 122, 130)
## Dim, smoky glass with the shaded canvas behind it.
GLASS_COLOUR = (118, 92, 66)


def bust(sheet, cx, cy, side):
    half = side // 2
    face = sheet.crop((cx - half, cy - half, cx + half, cy + half)).resize((SIZE, SIZE), Image.LANCZOS)
    scale = 4
    mask = Image.new("L", (SIZE * scale, SIZE * scale), 0)
    ImageDraw.Draw(mask).ellipse((6 * scale, 6 * scale, (SIZE - 6) * scale, (SIZE - 6) * scale), fill=255)
    mask = mask.resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(face, (0, 0), mask)
    ring = Image.new("RGBA", (SIZE * scale, SIZE * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ring)
    draw.ellipse((3 * scale, 3 * scale, (SIZE - 3) * scale, (SIZE - 3) * scale), outline=INK, width=7 * scale)
    draw.ellipse((4 * scale, 4 * scale, (SIZE - 4) * scale, (SIZE - 4) * scale), outline=BRASS, width=4 * scale)
    ring = ring.resize((SIZE, SIZE), Image.LANCZOS)
    return Image.alpha_composite(out, ring)


def kid_faces():
    """The kids' expressions: one 1024 px head per file, cut like Mum's."""
    count = 0
    for name, (cx, cy, side) in KID_FACES.items():
        path = os.path.join(ROOT, "art", "ui", "source", name + ".webp")
        if not os.path.exists(path):
            continue
        bust(Image.open(path).convert("RGB"), cx, cy, side).save(os.path.join(OUT, name + ".png"))
        count += 1
    return count


def crop_16_9(image):
    w, h = image.size
    if w / h > 16 / 9:
        nw = int(h * 16 / 9)
        left = (w - nw) // 2
        return image.crop((left, 0, left + nw, h))
    nh = int(w * 9 / 16)
    top = (h - nh) // 2
    return image.crop((0, top, w, top + nh))


def lift(image, amount):
    """Zooms in by `amount`, anchored at the top, so what sat low in the
    painting rises out of the storybook's text band."""
    if amount <= 0.0:
        return image
    w, h = image.size
    cw, ch = int(w / (1.0 + amount)), int(h / (1.0 + amount))
    left = (w - cw) // 2
    return image.crop((left, h - ch - int((h - ch) * 0.15), left + cw, h - int((h - ch) * 0.15))).resize((w, h), Image.LANCZOS)


def cold_lantern(image):
    """Puts out Mum's lantern in the Chapter 2 intro painting: inside the
    glass, the flame and its glow become dim, smoky glass with the canvas
    showing through; the brass bars and rims stay. The warm halo round it
    is calmed too."""
    import numpy as np
    from PIL import ImageFilter
    a = np.asarray(image).astype(np.float32)
    soft = np.asarray(image.filter(ImageFilter.GaussianBlur(6))).astype(np.float32)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    lum = a @ np.array([0.299, 0.587, 0.114], np.float32)
    cx, cy, rx, ry = LANTERN_GLASS
    # A soft rounded box (the glass chimney), not a circle.
    d = np.abs((xx - cx) / rx) ** 4 + np.abs((yy - cy) / ry) ** 4
    glass = np.clip((1.0 - d) * 3.0, 0.0, 1.0)
    # Brass bars are darker than the glow: they keep most of their paint.
    bright = np.clip((lum - 95.0) / 90.0, 0.0, 1.0)
    weight = (glass * (0.25 + 0.75 * bright))[..., None]
    detail = np.clip(a - soft, -40.0, 10.0) * 0.45
    smoke = np.array(GLASS_COLOUR, np.float32) + detail
    a = a * (1.0 - weight) + smoke * weight
    # The glow it threw on the canvas behind: a soft falloff, a little dimmer.
    halo = np.clip(1.0 - np.sqrt(((xx - cx) / (rx * 2.6)) ** 2 + ((yy - cy) / (ry * 1.8)) ** 2), 0.0, 1.0) ** 1.5
    a = a * (1.0 - 0.18 * halo[..., None] * (1.0 - glass[..., None]))
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def paintings():
    count = 0
    for page, amount in PAINTINGS.items():
        source = os.path.join(ROOT, "art", "ui", "source", "story", page + ".webp")
        if page == "c2_1":
            image = cold_lantern(Image.open(source.replace("c2_1", "c2_1_lit")).convert("RGB"))
        else:
            image = Image.open(source).convert("RGB")
        image = lift(crop_16_9(image), amount).resize(PAINTING_SIZE, Image.LANCZOS)
        image.save(os.path.join(OUT, "story_%s.webp" % page), "WEBP", quality=90)
        count += 1
    return count


def main():
    sheet = Image.open(SOURCE).convert("RGB")
    os.makedirs(OUT, exist_ok=True)
    for name, (cx, cy, side) in FACES.items():
        image = bust(sheet, cx, cy, side)
        image.save(os.path.join(OUT, "mum_%s.png" % name))
        if name == DEFAULT:
            image.save(os.path.join(OUT, "mum.png"))
    kids = kid_faces()
    pages = paintings()
    print("story_art: %d of Mum's faces, %d kids' faces, %d paintings -> %s" % (len(FACES), kids, pages, OUT))


if __name__ == "__main__":
    main()
