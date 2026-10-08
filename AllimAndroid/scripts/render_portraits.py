"""Renders the stand-in portraits to PNGs for the Android app.

A straight port of Geolocation_v1.0.0/Theme/PortraitAvatar.swift, so a person
without a photo gets the same illustrated faces on both platforms. iOS draws
them at runtime; Android ships them as bundled assets instead, which saves
pulling in an SVG library for eight static pictures.

Run it again whenever the iOS drawing changes:

    pip install Pillow
    python scripts/render_portraits.py

Writes assets/images/portraits/portrait-0.png ... portrait-7.png. The order
matches the iOS `recipes` list; src/components/portraits.ts relies on it.
"""

import math
import os

from PIL import Image, ImageDraw

# Output size in pixels. Avatars draw at 92dp at the largest, so this stays
# sharp on an xxxhdpi screen.
OUTPUT = 384
# Drawn this many times larger, then scaled down, for smooth edges.
SUPERSAMPLE = 4
SIDE = OUTPUT * SUPERSAMPLE

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'images', 'portraits')


def rgb(r, g, b):
    return (round(r * 255), round(g * 255), round(b * 255))


def hex_color(value):
    return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)


def shade(color, factor):
    return tuple(round(c * factor) for c in color)


SKIN_TONES = [
    rgb(0.96, 0.82, 0.72),
    rgb(0.89, 0.71, 0.57),
    rgb(0.78, 0.58, 0.44),
    rgb(0.62, 0.43, 0.31),
    rgb(0.45, 0.30, 0.22),
]

HAIR_COLORS = [
    rgb(0.16, 0.12, 0.10),
    rgb(0.28, 0.18, 0.12),
    rgb(0.42, 0.28, 0.16),
    rgb(0.55, 0.38, 0.22),
    rgb(0.44, 0.20, 0.12),
    rgb(0.78, 0.62, 0.36),
    rgb(0.55, 0.54, 0.56),
]

CLOTHING_COLORS = [
    rgb(0.79, 0.45, 0.24),
    rgb(0.42, 0.51, 0.38),
    rgb(0.31, 0.38, 0.48),
    rgb(0.85, 0.80, 0.72),
    rgb(0.57, 0.34, 0.38),
    rgb(0.33, 0.33, 0.35),
]

BACKDROPS = [
    (hex_color(0xE7F4EC), hex_color(0xCFE8DA)),  # produce
    (hex_color(0xE7F0FA), hex_color(0xCFE0F3)),  # dairy
    (hex_color(0xF8EAE8), hex_color(0xEFD3CF)),  # meat
    (hex_color(0xF8EFDD), hex_color(0xEEDFBD)),  # pantry
    (hex_color(0xF8E9F0), hex_color(0xEED2E0)),  # snacks
    (hex_color(0xEEEBF8), hex_color(0xDCD6F0)),  # household
]

# (style, skin, hair, clothing, backdrop, glasses) — same order as iOS.
RECIPES = [
    ('buzz', 1, 0, 2, 0, False),
    ('short', 3, 1, 1, 4, False),
    ('curls', 0, 2, 4, 2, True),
    ('afro', 4, 0, 0, 1, False),
    ('bob', 2, 4, 5, 3, False),
    ('wavy', 1, 6, 3, 5, True),
    ('long', 0, 5, 2, 2, False),
    ('bun', 3, 3, 1, 3, False),
]

INK = hex_color(0x16191C)


# MARK: - Geometry helpers

def box(x, y, w, h):
    return (x * SIDE, y * SIDE, (x + w) * SIDE, (y + h) * SIDE)


def point(x, y):
    return (x * SIDE, y * SIDE)


def rounded(draw, rect, radius, fill=None, outline=None, width=0):
    x0, y0, x1, y1 = rect
    # UIBezierPath clamps the corner radius to half the shorter side.
    r = min(radius * SIDE, (x1 - x0) / 2, (y1 - y0) / 2)
    draw.rounded_rectangle(rect, radius=r, fill=fill, outline=outline, width=width)


def composite(canvas, color, mask, alpha=1.0):
    """Lays a flat colour over the canvas through a mask, at an overall alpha."""
    if alpha < 1.0:
        mask = mask.point(lambda v: round(v * alpha))
    canvas.paste(Image.new('RGB', canvas.size, color), (0, 0), mask)


def new_mask():
    return Image.new('L', (SIDE, SIDE), 0)


def stroke_line(draw, points, width):
    """A polyline with round caps and joins, as CoreGraphics strokes it."""
    draw.line(points, fill=255, width=round(width), joint='curve')
    r = width / 2
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=255)


# MARK: - Drawing

def draw_backdrop(canvas, center_color, edge_color):
    """A soft pool of light behind the head, rather than a flat wash."""
    # Computed at output size and scaled up: a gradient has no edges to alias.
    cx, cy = 0.5 * OUTPUT, 0.42 * OUTPUT
    radius = OUTPUT * 0.78
    mask = Image.new('L', (OUTPUT, OUTPUT))
    mask.putdata([
        min(255, round(math.hypot(x - cx, y - cy) / radius * 255))
        for y in range(OUTPUT) for x in range(OUTPUT)
    ])
    mask = mask.resize((SIDE, SIDE), Image.BILINEAR)
    canvas.paste(Image.new('RGB', canvas.size, center_color))
    composite(canvas, edge_color, mask)


def draw_neck_and_shoulders(draw, skin, clothing):
    rounded(draw, box(0.437, 0.545, 0.126, 0.25), 0.055, fill=shade(skin, 0.90))
    draw.ellipse(box(0.40, 0.50, 0.20, 0.13), fill=shade(skin, 0.82))

    rounded(draw, box(0.04, 0.76, 0.92, 0.45), 0.24, fill=clothing)

    # Collar: a darker crew neckline with the neck showing through it.
    draw.ellipse(box(0.355, 0.715, 0.29, 0.16), fill=shade(clothing, 0.86))
    draw.ellipse(box(0.383, 0.70, 0.234, 0.135), fill=shade(skin, 0.90))


def draw_back_hair(draw, style, hair):
    if style == 'curls':
        for step in range(7):
            angle = math.pi + math.pi * step / 6
            x = 0.5 + math.cos(angle) * 0.215
            y = 0.44 + math.sin(angle) * 0.245
            draw.ellipse(box(x - 0.088, y - 0.088, 0.176, 0.176), fill=hair)
    elif style == 'afro':
        draw.ellipse(box(0.195, 0.10, 0.61, 0.61), fill=hair)
    elif style == 'bob':
        rounded(draw, box(0.264, 0.30, 0.472, 0.35), 0.20, fill=hair)
    elif style == 'wavy':
        rounded(draw, box(0.258, 0.30, 0.484, 0.38), 0.20, fill=hair)
        for center_x in (0.31, 0.41, 0.59, 0.69):
            draw.ellipse(box(center_x - 0.06, 0.62, 0.12, 0.12), fill=hair)
    elif style == 'long':
        rounded(draw, box(0.262, 0.30, 0.476, 0.545), 0.20, fill=hair)
    elif style == 'bun':
        draw.ellipse(box(0.425, 0.108, 0.15, 0.15), fill=hair)


def draw_hair_cap(canvas, draw, style, hair, parts_left):
    """The hairline, clipped so it reads as hair over the skull, not a hat."""
    part = 0.012 if parts_left else -0.012

    hairline = 0.365 if style == 'buzz' else 0.385
    cap = box(0.315 + part, 0.208, 0.37, 0.42) if style == 'buzz' \
        else box(0.289 + part, 0.19, 0.422, 0.47)

    mask = new_mask()
    ImageDraw.Draw(mask).ellipse(cap, fill=255)
    ImageDraw.Draw(mask).rectangle((0, hairline * SIDE, SIDE, SIDE), fill=0)
    composite(canvas, hair, mask)

    if style not in ('buzz', 'afro'):
        rounded(draw, box(0.292, 0.345, 0.045, 0.112), 0.023, fill=hair)
        rounded(draw, box(0.663, 0.345, 0.045, 0.112), 0.023, fill=hair)


def draw_cheek(canvas, skin, rect):
    """A blush that fades out at its edge."""
    warm = shade(skin, 0.90)
    x0, y0, x1, y1 = (round(v) for v in rect)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    radius = (x1 - x0) / 2

    mask = new_mask()
    pixels = mask.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / radius
            if d < 1:
                pixels[x, y] = round(255 * 0.45 * (1 - d))
    composite(canvas, warm, mask)


def draw_face(canvas, draw, skin, hair, glasses):
    draw_cheek(canvas, skin, box(0.352, 0.478, 0.085, 0.055))
    draw_cheek(canvas, skin, box(0.563, 0.478, 0.085, 0.055))

    # Brows.
    brow = shade(hair, 0.80)
    rounded(draw, box(0.396, 0.401, 0.062, 0.014), 0.008, fill=brow)
    rounded(draw, box(0.542, 0.401, 0.062, 0.014), 0.008, fill=brow)

    # Eyes.
    draw.ellipse(box(0.408, 0.434, 0.038, 0.048), fill=INK)
    draw.ellipse(box(0.554, 0.434, 0.038, 0.048), fill=INK)

    # Nose: a shaded line rather than an outline.
    mask = new_mask()
    stroke_line(ImageDraw.Draw(mask), [point(0.5, 0.487), point(0.5, 0.517)], SIDE * 0.012)
    composite(canvas, shade(skin, 0.78), mask)

    # Mouth: a quadratic curve, sampled into a polyline.
    (sx, sy), (ex, ey), (qx, qy) = point(0.449, 0.552), point(0.551, 0.552), point(0.5, 0.596)
    curve = []
    for i in range(41):
        t = i / 40
        curve.append((
            (1 - t) ** 2 * sx + 2 * (1 - t) * t * qx + t ** 2 * ex,
            (1 - t) ** 2 * sy + 2 * (1 - t) * t * qy + t ** 2 * ey,
        ))
    mask = new_mask()
    stroke_line(ImageDraw.Draw(mask), curve, SIDE * 0.015)
    composite(canvas, INK, mask, alpha=0.85)

    if glasses:
        width = SIDE * 0.012
        mask = new_mask()
        mask_draw = ImageDraw.Draw(mask)
        # CoreGraphics centres a stroke on the path; Pillow draws it inside the
        # rect, so grow each lens by half the line.
        half = width / 2
        for lens in (box(0.368, 0.412, 0.114, 0.094), box(0.518, 0.412, 0.114, 0.094)):
            x0, y0, x1, y1 = lens
            mask_draw.rounded_rectangle(
                (x0 - half, y0 - half, x1 + half, y1 + half),
                radius=0.032 * SIDE + half, outline=255, width=round(width),
            )
        stroke_line(mask_draw, [point(0.482, 0.452), point(0.518, 0.452)], width)
        composite(canvas, INK, mask, alpha=0.75)


def render(variant):
    style, skin_i, hair_i, clothing_i, backdrop_i, glasses = RECIPES[variant]
    skin = SKIN_TONES[skin_i]
    hair = HAIR_COLORS[hair_i]
    clothing = CLOTHING_COLORS[clothing_i]
    backdrop = BACKDROPS[backdrop_i]

    canvas = Image.new('RGB', (SIDE, SIDE))
    draw_backdrop(canvas, *backdrop)
    draw = ImageDraw.Draw(canvas)
    draw_neck_and_shoulders(draw, skin, clothing)
    draw_back_hair(draw, style, hair)

    # Ears, then the head over them.
    draw.ellipse(box(0.281, 0.428, 0.053, 0.075), fill=skin)
    draw.ellipse(box(0.666, 0.428, 0.053, 0.075), fill=skin)
    draw.ellipse(box(0.307, 0.205, 0.386, 0.47), fill=skin)

    draw_hair_cap(canvas, draw, style, hair, parts_left=variant % 2 == 0)
    draw_face(canvas, draw, skin, hair, glasses)

    return canvas.resize((OUTPUT, OUTPUT), Image.LANCZOS)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for variant in range(len(RECIPES)):
        path = os.path.join(OUT_DIR, f'portrait-{variant}.png')
        render(variant).save(path, optimize=True)
        print(f'{path}  ({RECIPES[variant][0]})')


if __name__ == '__main__':
    main()
