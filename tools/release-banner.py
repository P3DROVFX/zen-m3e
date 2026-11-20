#!/usr/bin/env python3
"""Draws a release announcement banner (1920x1080) into assets/releases/.

Adapted from ii-tools' tools/make-release-banner.py: the same "feature drop" card (the
name huge and wide, a hairline subtitle, the highlights as chips, the version big in a
corner, an M3E shape holding the mark), in a dark honey palette over a halftone of dots
that grow where soft glows sit and blur out towards the edges — the blurred-gradient
dot texture of Google's newer Material visuals. Needs numpy and Pillow, and the mod's
fonts/GoogleSansFlex.ttf (put there by install.sh).

    python3 tools/release-banner.py
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "releases"
FONT = ROOT / "fonts" / "GoogleSansFlex.ttf"

VERSION = "1.2.0"
SUBTITLE = "Library Redesign"
HIGHLIGHTS = [
    "Toolbar on top",
    "Full-width content",
    "Follows glass",
    "Library button in every layout",
]
FOOTER = "github.com/P3DROVFX/zen-m3e"
CALL = "git pull and restart Zen"

W, H = 1920, 1080
S = 2  # drawn at twice the size, then scaled down: smooth curves and round dots

DEEP = np.array((16, 10, 5), float)      # near-black, warm
EMBER = np.array((74, 40, 8), float)     # the base gradient's warm end
HONEY = np.array((214, 128, 24), float)  # dark orange / honey: the glows
DOT = np.array((255, 196, 112), float)   # the halftone's light honey
LIGHT = (255, 205, 130)                  # shapes and the version
CREAM = (255, 240, 220)
INK = (40, 22, 4)

rng = np.random.default_rng(7)


def face(size, wght=400, wdth=100, rond=100, slnt=0):
    f = ImageFont.truetype(str(FONT), size)
    # By axis name: builds differ (google/fonts has no GRAD axis, end-4's has).
    want = {b"Optical Size": min(max(size / S, 6), 144), b"Width": wdth, b"Weight": wght,
            b"Grade": 0, b"Roundness": rond, b"Slant": slnt}
    f.set_variation_by_axes([want.get(a["name"], a["default"]) for a in f.get_variation_axes()])
    return f


def gauss(xs, ys, cx, cy, rx, ry):
    return np.exp(-(((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2))


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def fields(w, h):
    """The glow (colour) and the dot-size field: soft blobs, a band through the middle."""
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    glow = (gauss(xs, ys, w * 0.84, h * 0.58, w * 0.22, h * 0.26) * 1.0
            + gauss(xs, ys, w * 0.00, h * 0.18, w * 0.06, h * 0.45) * 0.85
            + gauss(xs, ys, w * 0.40, h * 0.62, w * 0.22, h * 0.10) * 0.35
            + gauss(xs, ys, w * 0.55, h * 1.08, w * 0.45, h * 0.18) * 0.55)
    size = (gauss(xs, ys, w * 0.60, h * 0.62, w * 0.42, h * 0.26)
            + gauss(xs, ys, w * 0.88, h * 0.46, w * 0.18, h * 0.32) * 0.8
            + gauss(xs, ys, w * 0.30, h * 0.90, w * 0.30, h * 0.16) * 0.6)
    # Slow ripples so the sizes swell and thin like a wave, not plain circles.
    size *= (0.72 + 0.16 * np.sin(xs / w * 9.0 + ys / h * 4.0)
             + 0.12 * np.sin(xs / w * 3.0 - ys / h * 6.5 + 1.3))
    return xs, ys, np.clip(glow, 0, 1), np.clip(size, 0, 1)


def background():
    w, h = W * S, H * S
    xs, ys, glow, size = fields(w, h)

    # Base: warm black, rising to ember towards the bottom right, honey where glows sit.
    t = np.clip(xs / w * 0.45 + ys / h * 0.65 - 0.2, 0, 1) ** 1.8
    base = DEEP + (EMBER - DEEP) * t[..., None]
    base += (HONEY - base) * (np.clip(glow, 0, 1) * 0.78)[..., None]
    # Vignette, mostly at the top so the name sits on the dark.
    vig = smoothstep(0.0, 0.55, ys / h) * 0.35 + 0.65
    base *= vig[..., None]
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")
    # The glows are soft: blur the whole gradient a lot.
    img = img.filter(ImageFilter.GaussianBlur(40 * S))

    # Halftone: a square grid, every dot's radius from the size field.
    step = 22 * S
    dots = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dots)
    rmax = step * 0.33
    for gy in range(step // 2, h, step):
        for gx in range(step // 2, w, step):
            v = size[gy, gx]
            r = rmax * v ** 1.2
            if r < 0.7 * S:
                continue
            a = int(255 * min(1.0, 0.25 + 0.9 * v))
            c = tuple(int(x) for x in DOT) + (a,)
            dd.ellipse((gx - r, gy - r, gx + r, gy + r), fill=c)
    dots_a = np.asarray(dots).astype(float)
    dots_a[..., 3] *= 0.5  # a texture, not a pattern on top
    dots = Image.fromarray(dots_a.astype(np.uint8))

    # Spread blur: sharp in the dense middle, melting into the glow towards the edges.
    # Blurred dots stay dots — soft discs, re-brightened so the blur doesn't erase them.
    def melt(radius, gain):
        b = np.asarray(dots.filter(ImageFilter.GaussianBlur(radius))).astype(float)
        b[..., 3] = np.clip(b[..., 3] * gain, 0, 255)
        return Image.fromarray(b.astype(np.uint8))
    soft = melt(2.5 * S, 1.5)
    softer = melt(5.5 * S, 2.4)
    focus = gauss(xs, ys, w * 0.58, h * 0.60, w * 0.26, h * 0.18)
    m1 = Image.fromarray((np.clip(1 - focus * 1.8, 0, 1) * 255).astype(np.uint8))
    m2 = Image.fromarray((smoothstep(0.35, 0.95, 1 - focus) * 255).astype(np.uint8))
    layer = Image.composite(soft, dots, m1)
    layer = Image.composite(softer, layer, m2)
    img.alpha_composite(layer)

    # A grain so the big blurs don't band.
    grain = rng.normal(0, 3.0, (h, w, 1))
    arr = np.asarray(img).astype(float)
    arr[..., :3] += grain
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def shape(cx, cy, r, fn, rot=0.0, n=720):
    pts = []
    for i in range(n):
        th = 2 * math.pi * i / n
        rr = r * fn(th)
        pts.append((cx + rr * math.cos(th + rot), cy + rr * math.sin(th + rot)))
    return pts


def cookie(lobes, depth):  # the same shape functions as build.py
    return lambda t: (1 - depth) + depth * (0.5 + 0.5 * math.cos(lobes * t))


def clover(lobes, depth):
    return lambda t: (1 - depth) + depth * abs(math.cos(lobes / 2 * t)) ** 0.6


def mark(img, cx, cy, r):
    """The mod's identity: a honey Cookie-12 holding the search badge's Clover-4."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon(shape(cx, cy, r, cookie(12, 0.08), -math.pi / 2), fill=LIGHT + (255,))
    d.polygon(shape(cx, cy, r * 0.62, clover(4, 0.32), math.pi / 4), fill=INK + (255,))
    # The magnifier the badge carries, in honey.
    ring, lw = r * 0.17, int(r * 0.075)
    ox, oy = cx - r * 0.05, cy - r * 0.05
    d.ellipse((ox - ring, oy - ring, ox + ring, oy + ring), outline=LIGHT + (255,), width=lw)
    k = ring / math.sqrt(2)
    d.line((ox + k, oy + k, ox + k + r * 0.15, oy + k + r * 0.15), fill=LIGHT + (255,), width=lw)
    for px, py in ((ox + k + r * 0.15, oy + k + r * 0.15),):
        d.ellipse((px - lw / 2, py - lw / 2, px + lw / 2, py + lw / 2), fill=LIGHT + (255,))
    img.alpha_composite(layer)


def chip_row(draw, x0, y0, max_x, label_font, chip_font):
    """'Highlights:' then cream pills that wrap like text."""
    pad_x, chip_h, gap = 26 * S, 66 * S, 14 * S
    draw.text((x0, y0 + chip_h / 2), "Highlights:", font=label_font, fill=CREAM, anchor="lm")
    x = x0 + draw.textlength("Highlights:", font=label_font) + 26 * S
    y = y0
    for text in HIGHLIGHTS:
        tw = draw.textlength(text, font=chip_font)
        cw = tw + pad_x * 2
        if x + cw > max_x:
            x, y = x0, y + chip_h + gap
        draw.rounded_rectangle((x, y, x + cw, y + chip_h), chip_h / 2, fill=CREAM)
        draw.text((x + cw / 2, y + chip_h / 2 + 1 * S), text, font=chip_font, fill=INK, anchor="mm")
        x += cw + gap
    return y + chip_h


def main():
    img = background()
    draw = ImageDraw.Draw(img)
    m = 96 * S

    mark(img, W * S - 250 * S, 250 * S, 190 * S)

    # Name and subtitle.
    draw.text((m - 6 * S, 78 * S), "zen-m3e", font=face(210 * S, wdth=132, wght=860), fill=CREAM, anchor="lt")
    draw.text((m, 318 * S), SUBTITLE, font=face(104 * S, wdth=151, wght=230, rond=0), fill=CREAM, anchor="lt")

    # Highlights: the left column, clear of the version in the right one.
    chip_row(draw, m, 500 * S, 1180 * S, face(40 * S, wdth=110, wght=820), face(32 * S, wdth=100, wght=520))

    # Footer pill: the mark and where to get it.
    fy, fh = H * S - m - 50 * S, 92 * S
    foot = face(36 * S, wdth=125, wght=560)
    fw = fh + 24 * S + draw.textlength(FOOTER, font=foot) + 44 * S
    draw.rounded_rectangle((m - 20 * S, fy, m - 20 * S + fw, fy + fh), fh / 2, fill=CREAM)
    small = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(small)
    scx, scy, sr = m - 10 * S + (fh - 20 * S) / 2, fy + fh / 2, (fh - 20 * S) / 2
    sd.polygon(shape(scx, scy, sr, cookie(12, 0.08), -math.pi / 2), fill=tuple(int(c) for c in HONEY) + (255,))
    sd.polygon(shape(scx, scy, sr * 0.6, clover(4, 0.32), math.pi / 4), fill=INK + (255,))
    img.alpha_composite(small)
    draw.text((m - 10 * S + fh + 14 * S, fy + fh / 2), FOOTER, font=foot, fill=(150, 82, 8), anchor="lm")

    # The version, big in the bottom right, and its line.
    right = W * S - m + 10 * S
    draw.text((right, H * S - m - 66 * S), "v" + VERSION, font=face(190 * S, wdth=132, wght=860), fill=LIGHT, anchor="rs")
    # The font has no arrow: draw one at the end of the line.
    ay = H * S - m + 16 * S
    ax1 = right - 8 * S
    ax0 = ax1 - 34 * S
    cy = ay - 15 * S
    draw.line((ax0, cy, ax1, cy), fill=CREAM, width=4 * S)
    draw.line((ax1 - 14 * S, cy - 13 * S, ax1, cy, ax1 - 14 * S, cy + 13 * S), fill=CREAM, width=4 * S, joint="curve")
    draw.text((ax0 - 16 * S, ay), CALL, font=face(38 * S, wdth=125, wght=520), fill=CREAM, anchor="rs")

    out = img.resize((W, H), Image.LANCZOS).convert("RGB")
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"zen-m3e-{VERSION}.png"
    out.save(path, optimize=True)
    print(path)


if __name__ == "__main__":
    main()
