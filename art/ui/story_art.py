"""Story art (features 043 and 047): Mum's portraits for the storybook, cut
from the team's character sheet (art/ui/source/mum_sheet.png, also kept as
art/reference/concept-2026-10/14_mum_character_sheet.webp), the kids'
expression portraits, and the storybook paintings.

- game/assets/ui/story/mum.png: the default portrait (smiling).
- game/assets/ui/story/mum_<face>.png: one per expression on the sheet,
  picked per story line with the line's "face" key.
- game/assets/ui/story/<hero>_<face>.png: the kids' six expressions each
  (047): Nela's painted heads (art/ui/source/nela_<face>.webp) and faces
  cut from the storybook paintings (`KID_FACES`).
- game/assets/ui/story/story_<page>.webp: the team's storybook paintings
  (art/ui/source/story/<page>.webp, 2560x1440), 1600x900 for the intro
  and ending pages. The Chapter 2 intro's lantern is retouched cold
  (`cold_lantern`), and so is the one found in the Chapter 1 ending: the
  paintings showed it lit, the story says cold. Pages whose faces fell
  under the text band are lifted (`lift`).

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
## The kids' expressions (047): file -> (source, centre x, centre y,
## square side). Nela's surprised, worried and laugh were painted as heads
## (art/ui/source/<file>.webp, 1024 px); the rest are cut from the kids'
## faces in the storybook paintings (art/ui/source/story/, 2560x1440).
KID_FACES = {
    "nela_surprised": ("nela_surprised", 540, 530, 820),
    "nela_worried": ("nela_worried", 540, 530, 820),
    "nela_laugh": ("nela_laugh", 540, 530, 820),
    "nela_smile": ("story/c1_1", 1421, 717, 320),
    "nela_curious": ("story/c2_1_lit", 1450, 1060, 600),
    "nela_proud": ("story/c2_2", 2180, 880, 580),
    "leo_smile": ("story/c1_1", 730, 505, 380),
    "leo_curious": ("story/c2_1_lit", 980, 600, 660),
    "leo_laugh": ("story/c2_2", 960, 380, 650),
    "leo_surprised": ("story/c1_2", 810, 630, 660),
    "leo_worried": ("story/c1_4", 1190, 710, 480),
    "leo_proud": ("story/win_c2_2", 1800, 560, 580),
}
## Storybook pages (047): source name -> lift (shift, shrink), (0, 0) =
## as painted. Lifted where the text band would cover a face or the
## page's key prop.
PAINTINGS = {
    "c1_1": (0, 0), "c1_2": (0.0, 0.16), "c1_3": (0, 0), "c1_4": (0.08, 0.12),
    "c2_1": (0.16, 0.08), "c2_2": (0, 0), "c2_3": (0, 0),
    "win_c1_1": (0.12, 0.06), "win_c1_2": (0, 0),
    "win_c2_1": (0, 0), "win_c2_2": (0, 0), "win_c2_3": (0, 0),
}
PAINTING_SIZE = (1600, 900)
## Mum's lantern is cold where the story says so, but two paintings show
## it lit: its glass in the source (2560x1440), as centre x, centre y,
## half width, half height. The Chapter 2 intro's source is kept as
## c2_1_lit.webp; the Chapter 1 ending's flame becomes a glint of sun.
COLD_LANTERNS = {
    "c2_1": (1864, 512, 122, 130),
    "win_c1_1": (1448, 1248, 92, 66),
}
## How much darker the cold glass is than what is round it.
GLASS_DIM = 0.72


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
    """The kids' expressions, cut like Mum's."""
    count = 0
    for name, (source, cx, cy, side) in KID_FACES.items():
        path = os.path.join(ROOT, "art", "ui", "source", source + ".webp")
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


def lift(image, shift=0.0, shrink=0.0):
    """Raises what sits low in a painting out of the storybook's text band
    (the bottom third is shaded and carries the words): `shift` moves it up
    by that share of the height (the top edge is cropped), `shrink` scales it
    down from the top centre. The uncovered bottom and sides are the
    painting itself, blurred and darkened, under a feathered seam, and the
    text band's shade hides the rest."""
    if shift <= 0.0 and shrink <= 0.0:
        return image
    w, h = image.size
    back = image.filter(ImageFilter.GaussianBlur(w // 80))
    # Darker towards the bottom, where the text band's shade takes over.
    shade = Image.linear_gradient("L").resize((w, h)).point(lambda v: int(max(0, v - 90) * 1.4))
    back = Image.composite(Image.new("RGB", (w, h), (20, 12, 8)), back, shade)
    top = int(h * shift)
    front = image.crop((0, top, w, h))
    fw, fh = int(w * (1.0 - shrink)), int((h - top) * (1.0 - shrink))
    front = front.resize((fw, fh), Image.LANCZOS)
    # A soft seam on the sides (when shrunk) and the bottom.
    feather = max(8, w // 25)
    side = feather if shrink > 0.0 else -feather
    mask = Image.new("L", (fw, fh), 0)
    ImageDraw.Draw(mask).rectangle((side, -feather, fw - 1 - side, fh - 1 - feather), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(feather / 2.5))
    back.paste(front, ((w - fw) // 2, 0), mask)
    return back


def cold_lantern(image, glass_box):
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
    cx, cy, rx, ry = glass_box
    # A soft rounded box (the glass chimney), not a circle.
    d = np.abs((xx - cx) / rx) ** 4 + np.abs((yy - cy) / ry) ** 4
    glass = np.clip((1.0 - d) * 3.0, 0.0, 1.0)
    # Brass bars are darker than the glow: they keep most of their paint.
    bright = np.clip((lum - 95.0) / 90.0, 0.0, 1.0)
    weight = (glass * (0.25 + 0.75 * bright))[..., None]
    detail = np.clip(a - soft, -25.0, 4.0) * 0.3
    # The glass takes the colour of what is round it (canvas, moss), dimmed:
    # the mean of a ring just outside the mask, leaving out the bright glow.
    ring = (d > 1.2) & (d < 3.0) & (lum < 170)
    smoke = a[ring].mean(axis=0) * GLASS_DIM + detail
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
            source = source.replace("c2_1", "c2_1_lit")
        image = Image.open(source).convert("RGB")
        if page in COLD_LANTERNS:
            image = cold_lantern(image, COLD_LANTERNS[page])
        image = lift(crop_16_9(image), *amount).resize(PAINTING_SIZE, Image.LANCZOS)
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
