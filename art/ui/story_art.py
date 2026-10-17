"""Story art (feature 043): Mum's portraits for the storybook, cut from
the team's character sheet (art/ui/source/mum_sheet.png, also kept as
art/reference/concept-2026-10/14_mum_character_sheet.webp).

- game/assets/ui/story/mum.png: the default portrait (smiling).
- game/assets/ui/story/mum_<face>.png: one per expression on the sheet,
  picked per story line with the line's "face" key.

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


def main():
    sheet = Image.open(SOURCE).convert("RGB")
    os.makedirs(OUT, exist_ok=True)
    for name, (cx, cy, side) in FACES.items():
        image = bust(sheet, cx, cy, side)
        image.save(os.path.join(OUT, "mum_%s.png" % name))
        if name == DEFAULT:
            image.save(os.path.join(OUT, "mum.png"))
    print("story_art: %d faces -> %s" % (len(FACES), OUT))


if __name__ == "__main__":
    main()
