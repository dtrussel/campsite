"""Key art (feature 029): the team's painted illustration of Leo and Nela
at sunset, prepared for the game.

- game/assets/ui/key_art.webp: 1600x900, centre-cropped to 16:9; a
  loading screen's background. loading_imp/beast/gremlin.webp likewise
  (feature 030: the team's paintings of each monster).
- game/assets/ui/boot_splash.png: 1280x720 with the gold "CAMPSITE"
  logo baked into the sky (the engine's boot splash can't draw text).
  Same look as the title screen's logo: Cinzel bold, gold, dark outline.

Source: art/ui/source/key_art.png. Run with any Python that has Pillow,
e.g. .venv-blender/bin/python art/ui/key_art.py"""

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "art", "ui", "source", "key_art.png")
OUT = os.path.join(ROOT, "game", "assets", "ui")
FONT = os.path.join(ROOT, "game", "assets", "fonts", "Cinzel.ttf")
## Extra loading-screen paintings in art/ui/source/ (feature 030).
LOADING = ("loading_imp", "loading_beast", "loading_gremlin")

GOLD = (199, 171, 110)          # UiKit.COLOR_GOLD
GOLD_LIGHT = (240, 230, 209)
OUTLINE = (13, 8, 3)


def crop_16_9(image):
    w, h = image.size
    if w / h > 16 / 9:
        nw = int(h * 16 / 9)
        left = (w - nw) // 2
        return image.crop((left, 0, left + nw, h))
    nh = int(w * 9 / 16)
    top = (h - nh) // 2
    return image.crop((0, top, w, top + nh))


def logo_font(size):
    font = ImageFont.truetype(FONT, size)
    try:
        font.set_variation_by_axes([700])   # Cinzel is a variable font
    except (OSError, AttributeError, ValueError):
        pass
    return font


def draw_logo(image, text="CAMPSITE"):
    w, h = image.size
    font = logo_font(int(h * 0.105))
    draw = ImageDraw.Draw(image)
    box = draw.textbbox((0, 0), text, font=font, stroke_width=0)
    tw, th = box[2] - box[0], box[3] - box[1]
    # In the open sky on the right, above the peaks (clear of Leo's cap).
    x = int(w * 0.72 - tw / 2) - box[0]
    y = int(h * 0.035) - box[1]
    # Soft dark glow behind the letters so they read over bright clouds.
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).text((x, y), text, font=font, fill=(0, 0, 0, 170),
                              stroke_width=int(h * 0.014), stroke_fill=(0, 0, 0, 170))
    glow = glow.filter(ImageFilter.GaussianBlur(h * 0.012))
    image.alpha_composite(glow)
    draw = ImageDraw.Draw(image)
    draw.text((x, y), text, font=font, fill=GOLD, stroke_width=max(2, int(h * 0.008)), stroke_fill=OUTLINE)
    # A lighter top half, like the title screen's gilded look.
    shine = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shine).text((x, y), text, font=font, fill=GOLD_LIGHT + (110,))
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rectangle((0, 0, w, y + box[1] + th * 0.45), fill=255)
    image.paste(Image.alpha_composite(image, shine), (0, 0), mask)
    return image


def main():
    os.makedirs(OUT, exist_ok=True)
    art = crop_16_9(Image.open(SOURCE).convert("RGB"))
    art.resize((1600, 900), Image.LANCZOS).save(os.path.join(OUT, "key_art.webp"), quality=88, method=6)
    # More loading-screen paintings (feature 030), one per monster.
    for name in LOADING:
        extra = crop_16_9(Image.open(os.path.join(ROOT, "art", "ui", "source", name + ".png")).convert("RGB"))
        extra.resize((1600, 900), Image.LANCZOS).save(os.path.join(OUT, name + ".webp"), quality=88, method=6)
    splash = art.resize((1280, 720), Image.LANCZOS).convert("RGBA")
    splash = draw_logo(splash)
    splash.convert("RGB").save(os.path.join(OUT, "boot_splash.png"), optimize=True)
    for name in ["key_art.webp", "boot_splash.png"] + [n + ".webp" for n in LOADING]:
        path = os.path.join(OUT, name)
        print("wrote", os.path.relpath(path, ROOT), os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    main()
