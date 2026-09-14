#!/usr/bin/env python3
"""Generates the Shankh Alarm launcher icon foreground layer + a plain app icon.

Recreates the look of the original Android project's vector drawable
(rising sun + golden conch spiral + sound-blast rays) as a raster PNG,
since Flutter's launcher-icon tooling needs raster assets.
"""
import math
from PIL import Image, ImageDraw

SIZE = 1024
CX, CY = SIZE // 2, SIZE // 2

SAFFRON = (255, 153, 51, 255)
CREAM = (255, 248, 237, 255)
GOLD = (212, 175, 55, 255)
MAROON = (74, 16, 16, 255)
INK = (34, 22, 11, 255)


def make_foreground():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Sun disc, upper portion of the safe zone.
    sun_cx, sun_cy, sun_r = CX, CY - 195, 92
    for ang_deg in range(0, 360, 45):
        ang = math.radians(ang_deg)
        x1 = sun_cx + math.cos(ang) * (sun_r + 22)
        y1 = sun_cy + math.sin(ang) * (sun_r + 22)
        x2 = sun_cx + math.cos(ang) * (sun_r + 58)
        y2 = sun_cy + math.sin(ang) * (sun_r + 58)
        d.line([(x1, y1), (x2, y2)], fill=CREAM, width=20)
    d.ellipse(
        [sun_cx - sun_r, sun_cy - sun_r, sun_cx + sun_r, sun_cy + sun_r],
        fill=CREAM,
    )

    # Conch (shankh) body: a bold logarithmic spiral, filled thick, gold,
    # outlined in ink so it reads clearly against the saffron background.
    spiral_cx, spiral_cy = CX, CY + 175
    a, b = 22.0, 0.24
    turns = 1.65
    steps = 500
    outer_pts = []
    inner_pts = []
    thickness_start, thickness_end = 100.0, 12.0
    for i in range(steps + 1):
        t = i / steps
        theta = t * turns * 2 * math.pi
        r = a * math.exp(b * theta)
        thickness = thickness_start + (thickness_end - thickness_start) * (t ** 0.7)
        x = spiral_cx + r * math.cos(theta)
        y = spiral_cy + r * math.sin(theta) * 0.9
        nx, ny = math.cos(theta), math.sin(theta) * 0.9
        norm = math.hypot(nx, ny) or 1.0
        nx, ny = nx / norm, ny / norm
        outer_pts.append((x + nx * thickness, y + ny * thickness))
        inner_pts.append((x - nx * thickness, y - ny * thickness))
    polygon = outer_pts + inner_pts[::-1]
    d.polygon(polygon, fill=GOLD, outline=INK, width=6)
    # Inner whorl line for a bit of shell texture.
    whorl = []
    for i in range(0, steps + 1, 2):
        t = i / steps
        theta = t * turns * 2 * math.pi
        r = a * math.exp(b * theta) * 0.4
        x = spiral_cx + r * math.cos(theta)
        y = spiral_cy + r * math.sin(theta) * 0.9
        whorl.append((x, y))
    d.line(whorl, fill=INK, width=7, joint="curve")

    # Small sound-blast rays flaring from the conch's open (wide) mouth.
    mouth = outer_pts[0]
    mdx, mdy = math.cos(0), math.sin(0) * 0.9
    for offset, length in [(-34, 95), (0, 120), (34, 95)]:
        perp = (-mdy, mdx)
        base_c = (mouth[0] + perp[0] * offset * 0.35, mouth[1] + perp[1] * offset * 0.35)
        tip = (base_c[0] + mdx * length, base_c[1] + mdy * length)
        base1 = (base_c[0] + perp[0] * 16, base_c[1] + perp[1] * 16)
        base2 = (base_c[0] - perp[0] * 16, base_c[1] - perp[1] * 16)
        d.polygon([base1, base2, tip], fill=MAROON)

    return img


def compose_square(fg, bg_color):
    base = Image.new("RGBA", (SIZE, SIZE), bg_color)
    base.alpha_composite(fg)
    return base


if __name__ == "__main__":
    fg = make_foreground()
    fg.save("design/icon_foreground.png")
    compose_square(fg, SAFFRON).save("design/icon_full.png")
    print("wrote design/icon_foreground.png and design/icon_full.png")
