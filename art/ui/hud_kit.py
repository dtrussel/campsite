"""HUD kit (feature 033): the "campcraft" UI pieces, drawn procedurally.

Dark walnut plates with plank grain, a brass rim and corner rivets; a
cream canvas inset and banner ribbon; bevelled brass slot frames; wood
buttons. All are 9-slice textures that UiKit wraps in StyleBoxTexture,
written to game/assets/ui/hud/.

Each piece is drawn at 4x and downsampled for smooth edges. Seeded, so
re-running gives the same files. Run with any Python that has Pillow,
e.g. .venv-blender/bin/python art/ui/hud_kit.py"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "ui", "hud")
SS = 4  # supersampling

WOOD = (58, 36, 22)
WOOD_LIGHT = (92, 60, 36)
WOOD_DARK = (34, 20, 12)
BRASS = (201, 151, 74)
BRASS_LIGHT = (246, 214, 140)
BRASS_DARK = (112, 74, 32)
CANVAS = (239, 226, 196)
CANVAS_DARK = (196, 170, 128)
INK = (40, 24, 14)


def _rr(draw, box, radius, **kw):
    draw.rounded_rectangle([int(v) for v in box], radius=int(radius), **kw)


def _grain(size, base, light, dark, seed, alpha=255, plank=None):
    """Horizontal wood grain: streaks, knots and plank seams."""
    w, h = size
    rnd = random.Random(seed)
    img = Image.new("RGBA", size, base + (alpha,))
    lines = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lines)
    for _ in range(int(h / SS * 1.6)):
        y = rnd.uniform(0, h)
        tone = light if rnd.random() < 0.5 else dark
        a = rnd.randint(40, 110)
        width = rnd.uniform(0.6, 1.8) * SS
        pts = []
        x = 0.0
        wobble = rnd.uniform(0, 6.28)
        while x <= w:
            pts.append((x, y + 1.6 * SS * math.sin(x / (w * 0.21) + wobble)))
            x += w / 24
        d.line(pts, fill=tone + (a,), width=int(width))
    if plank:
        for y in plank:
            d.line([(0, y * h), (w, y * h)], fill=WOOD_DARK + (200,), width=int(1.4 * SS))
            d.line([(0, y * h + 1.4 * SS), (w, y * h + 1.4 * SS)], fill=light + (70,), width=int(SS))
    img = Image.alpha_composite(img, lines)
    return img.filter(ImageFilter.GaussianBlur(SS * 0.35))


def _mask(size, box, radius):
    m = Image.new("L", size, 0)
    _rr(ImageDraw.Draw(m), box, radius, fill=255)
    return m


def _rivet(draw, c, r):
    x, y = c
    draw.ellipse([x - r - SS, y - r - SS, x + r + SS, y + r + SS], fill=INK + (200,))
    draw.ellipse([x - r, y - r, x + r, y + r], fill=BRASS_DARK + (255,))
    draw.ellipse([x - r * 0.75, y - r * 0.85, x + r * 0.55, y + r * 0.45], fill=BRASS + (255,))
    draw.ellipse([x - r * 0.45, y - r * 0.6, x - r * 0.05, y - r * 0.2], fill=BRASS_LIGHT + (255,))


def _framed(px, radius, border, fill_img, rivets=True, fill_alpha=235):
    """Wood (or any fill) inside a rounded brass rim, at SS scale."""
    s = px * SS
    size = (s, s)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = radius * SS
    b = border * SS
    # Outer ink line, brass rim with a lit top edge.
    _rr(d, (0, 0, s - 1, s - 1), r, fill=INK + (255,))
    _rr(d, (SS, SS, s - 1 - SS, s - 1 - SS), r - SS, fill=BRASS_DARK + (255,))
    _rr(d, (SS, SS, s - 1 - SS, s - 1 - SS * 2), r - SS, fill=BRASS + (255,))
    _rr(d, (SS * 2, SS * 1.5, s - 1 - SS * 2, s * 0.5), r - SS * 2, fill=BRASS_LIGHT + (120,))
    _rr(d, (SS * 2, SS * 2, s - 1 - SS * 2, s - 1 - SS * 2), r - SS * 2, fill=BRASS + (255,))
    # Inner bevel and the fill.
    inner = (b - SS, b - SS, s - 1 - b + SS, s - 1 - b + SS)
    _rr(d, inner, max(r - b, SS), fill=INK + (255,))
    box = (b, b, s - 1 - b, s - 1 - b)
    fill = fill_img.copy()
    fill.putalpha(Image.eval(fill.getchannel("A"), lambda v: v * fill_alpha // 255))
    img.paste(Image.new("RGBA", size, (0, 0, 0, 0)), (0, 0), _mask(size, box, max(r - b, SS)))
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    layer.paste(fill, (0, 0), _mask(size, box, max(r - b, SS)))
    img = Image.alpha_composite(img, layer)
    # Inner shadow under the top rim.
    shade = Image.new("RGBA", size, (0, 0, 0, 0))
    _rr(ImageDraw.Draw(shade), (b, b, s - 1 - b, b + SS * 3), SS, fill=INK + (110,))
    shade = shade.filter(ImageFilter.GaussianBlur(SS * 1.2))
    shade.putalpha(Image.composite(shade.getchannel("A"), Image.new("L", size, 0), _mask(size, box, max(r - b, SS))))
    img = Image.alpha_composite(img, shade)
    if rivets:
        d = ImageDraw.Draw(img)
        o = b * 0.5 + SS * 0.5
        for c in [(o + r * 0.3, o + r * 0.3), (s - o - r * 0.3, o + r * 0.3),
                  (o + r * 0.3, s - o - r * 0.3), (s - o - r * 0.3, s - o - r * 0.3)]:
            _rivet(d, c, SS * 2.2)
    return img


def _save(img, name):
    img = img.resize((img.width // SS, img.height // SS), Image.LANCZOS)
    path = os.path.join(OUT, name)
    img.save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT), img.size)


def plate():
    s = 96 * SS
    wood = _grain((s, s), WOOD, WOOD_LIGHT, WOOD_DARK, 7, plank=[0.34, 0.67])
    _save(_framed(96, 12, 5, wood, fill_alpha=232), "plate.png")


def slot():
    s = 64 * SS
    recess = _grain((s, s), (44, 28, 18), (70, 46, 28), (26, 15, 9), 11)
    # Darker centre so icons pop.
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([s * 0.15, s * 0.15, s * 0.85, s * 0.85], fill=(20, 12, 7, 120))
    recess = Image.alpha_composite(recess, glow.filter(ImageFilter.GaussianBlur(s * 0.08)))
    _save(_framed(64, 8, 4, recess, rivets=False, fill_alpha=245), "slot.png")


def button(name, base, light, rim_glow=None):
    s = 96 * SS
    wood = _grain((s, s), base, light, WOOD_DARK, 19)
    img = _framed(96, 10, 4, wood, rivets=True, fill_alpha=245)
    if rim_glow:
        g = Image.new("RGBA", img.size, (0, 0, 0, 0))
        _rr(ImageDraw.Draw(g), (SS * 6, SS * 6, s - SS * 6, s - SS * 6), SS * 6, outline=rim_glow + (190,), width=SS * 3)
        img = Image.alpha_composite(img, g.filter(ImageFilter.GaussianBlur(SS * 2)))
    _save(img, name)


def canvas():
    """Cream canvas with a stitched border (tooltips, badges)."""
    s = 64 * SS
    rnd = random.Random(3)
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _rr(d, (0, 0, s - 1, s - 1), SS * 8, fill=INK + (255,))
    _rr(d, (SS, SS, s - 1 - SS, s - 1 - SS), SS * 7, fill=CANVAS + (255,))
    weave = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    wd = ImageDraw.Draw(weave)
    for i in range(0, s, SS * 2):
        wd.line([(i, 0), (i, s)], fill=CANVAS_DARK + (rnd.randint(18, 40),), width=SS // 2)
        wd.line([(0, i), (s, i)], fill=CANVAS_DARK + (rnd.randint(18, 40),), width=SS // 2)
    weave.putalpha(Image.composite(weave.getchannel("A"), Image.new("L", (s, s), 0), _mask((s, s), (SS, SS, s - SS, s - SS), SS * 7)))
    img = Image.alpha_composite(img, weave)
    d = ImageDraw.Draw(img)
    m = SS * 5
    for x in range(int(m + SS * 2), int(s - m - SS * 2), SS * 4):
        d.line([(x, m), (x + SS * 2, m)], fill=CANVAS_DARK + (255,), width=SS)
        d.line([(x, s - m), (x + SS * 2, s - m)], fill=CANVAS_DARK + (255,), width=SS)
        d.line([(m, x), (m, x + SS * 2)], fill=CANVAS_DARK + (255,), width=SS)
        d.line([(s - m, x), (s - m, x + SS * 2)], fill=CANVAS_DARK + (255,), width=SS)
    _save(img, "canvas.png")


def ribbon():
    """Canvas banner with swallowtail ends; 9-slice on x only."""
    w, h = 192 * SS, 64 * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    tail = 34 * SS
    top, bot = 10 * SS, h - 10 * SS
    # Folded tails, a step lower and darker.
    for side in (0, 1):
        x0 = 0 if side == 0 else w - tail
        x1 = tail if side == 0 else w
        notch = x0 + 12 * SS if side == 0 else x1 - 12 * SS
        outer = x0 if side == 0 else x1
        inner = x1 if side == 0 else x0
        pts = [(outer, top + 8 * SS), (inner, top + 8 * SS), (inner, bot + 6 * SS), (outer, bot + 6 * SS),
               (notch, (top + bot) / 2 + 7 * SS)]
        d.polygon(pts, fill=INK + (255,))
        shrink = [(p[0] + (SS * 1.5 if p[0] == outer and side == 0 else -SS * 1.5 if p[0] == outer else 0),
                   p[1]) for p in pts]
        d.polygon([(x, y + (SS * 1.5 if y < (top + bot) / 2 else -SS * 1.5)) for x, y in shrink], fill=CANVAS_DARK + (255,))
    body = (tail - 8 * SS, top, w - tail + 8 * SS, bot)
    _rr(d, body, SS * 3, fill=INK + (255,))
    _rr(d, (body[0] + SS * 1.5, body[1] + SS * 1.5, body[2] - SS * 1.5, body[3] - SS * 1.5), SS * 2, fill=CANVAS + (255,))
    # Brass stitching and a soft lower shade.
    for x in range(int(body[0] + 8 * SS), int(body[2] - 8 * SS), SS * 5):
        d.line([(x, body[1] + 5 * SS), (x + SS * 2.5, body[1] + 5 * SS)], fill=BRASS + (255,), width=SS)
        d.line([(x, body[3] - 5 * SS), (x + SS * 2.5, body[3] - 5 * SS)], fill=BRASS + (255,), width=SS)
    shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shade).rectangle([body[0] + SS * 2, (top + bot) * 0.62, body[2] - SS * 2, body[3] - SS * 2], fill=CANVAS_DARK + (110,))
    img = Image.alpha_composite(img, shade.filter(ImageFilter.GaussianBlur(SS * 3)))
    _save(img, "ribbon.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    plate()
    slot()
    canvas()
    ribbon()
    button("button.png", (66, 42, 25), (100, 66, 40))
    button("button_hover.png", (92, 60, 34), (130, 88, 52), rim_glow=(255, 190, 90))
    button("button_pressed.png", (40, 25, 15), (62, 40, 24))


if __name__ == "__main__":
    main()
