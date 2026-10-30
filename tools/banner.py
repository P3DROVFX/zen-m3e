#!/usr/bin/env python3
"""Render assets/hero-banner.jpg from docs/screenshots/showcase.png.

Bento layout like the ii-icon-pack hero: a title card with chips, two stat cards, the
showcase screenshot, and close-ups cropped from that same screenshot. Colours are the
dark palette from colors.css (falling back to the built-in amber palette); type is
Google Sans Flex with its width / weight / slant axes.

usage: tools/banner.py [OUT]
"""
import pathlib
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets" / "hero-banner.jpg"
SHOT = ROOT / "docs" / "screenshots" / "showcase.png"
FONT = ROOT / "fonts" / "GoogleSansFlex.ttf"
W, H = 2400, 1480
PAD, GAP = 40, 24


def palette():
    src = (ROOT / "colors.css") if (ROOT / "colors.css").exists() else (ROOT / "src" / "00-palette.css")
    text = src.read_text()
    roles = dict(re.findall(r"--m3-dark-([a-z-]+):\s*(#[0-9a-fA-F]{6})", text))
    return {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) for k, v in roles.items()}


C = palette()


def font(size, wght=400, wdth=100, slnt=0, rond=100):
    f = ImageFont.truetype(str(FONT), size)
    # By axis name: builds differ (google/fonts has no GRAD axis, end-4's has).
    want = {b"Optical Size": min(max(size, 6), 144), b"Width": wdth, b"Weight": wght,
            b"Grade": 0, b"Roundness": rond, b"Slant": slnt}
    f.set_variation_by_axes([want.get(a["name"], a["default"]) for a in f.get_variation_axes()])
    return f


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *img.size), radius, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out


def card(draw, box, fill, radius=44):
    draw.rounded_rectangle(box, radius, fill=fill)


def chip(draw, x, y, text, fill, ink):
    f = font(22, 820, 118)
    tw = draw.textlength(text, font=f)
    draw.rounded_rectangle((x, y, x + tw + 36, y + 44), 22, fill=fill)
    draw.text((x + 18, y + 22), text, font=f, fill=ink, anchor="lm")
    return x + tw + 36 + 12


def scallop(size, lobes=10, depth=0.2):
    """A soft-burst ornament, like the shell's clipped shapes."""
    import math
    pts = []
    for i in range(360):
        t = 2 * math.pi * i / 360
        r = (1 - depth) + depth * (0.5 + 0.5 * math.cos(lobes * t))
        pts.append((size / 2 + size / 2 * r * math.cos(t - math.pi / 2), size / 2 + size / 2 * r * math.sin(t - math.pi / 2)))
    return pts


def main():
    img = Image.new("RGB", (W, H), C["surface"])
    d = ImageDraw.Draw(img)
    shot = Image.open(SHOT).convert("RGB")

    # ---------- top row ----------
    top_h = 300
    stat_w = 400
    title_box = (PAD, PAD, W - PAD - 2 * (stat_w + GAP), PAD + top_h)
    card(d, title_box, C["surface-container-low"])

    # Ornament clipped by the title card.
    orn = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(orn)
    size = 520
    ox, oy = title_box[2] - 280, title_box[1] - 150
    od.polygon([(ox + x, oy + y) for x, y in scallop(size)], fill=(*C["primary-container"], 110))
    clip = Image.new("L", (W, H), 0)
    ImageDraw.Draw(clip).rounded_rectangle(title_box, 44, fill=255)
    img.paste(orn, (0, 0), Image.composite(orn.split()[3], Image.new("L", (W, H), 0), clip))
    d = ImageDraw.Draw(img)

    x = title_box[0] + 48
    y = title_box[1] + 42
    x = chip(d, x, y, "MATERIAL 3 EXPRESSIVE", C["primary"], C["on-primary"])
    x = chip(d, x, y, "ZEN BROWSER • SINE • MATUGEN", C["secondary-container"], C["on-secondary-container"])

    tx, ty = title_box[0] + 46, y + 128
    f_title = font(108, 860, 128)
    d.text((tx, ty), "zen-m3e", font=f_title, fill=C["on-surface"], anchor="ls")
    tx2 = tx + d.textlength("zen-m3e ", font=f_title)
    d.text((tx2, ty), "Expressive", font=font(108, 820, 112, slnt=-10), fill=C["primary"], anchor="ls")

    desc = ("A Sine mod that themes all of Zen — sidebar, search, menus, library, media — "
            "with live matugen colours, Google Sans Flex, shape morphs and spring motion.")
    f_desc = font(27, 460)
    max_w = title_box[2] - title_box[0] - 96 - 260      # keep clear of the ornament
    words, lines, line = desc.split(), [], ""
    for w_ in words:
        trial = (line + " " + w_).strip()
        if d.textlength(trial, font=f_desc) > max_w and line:
            lines.append(line); line = w_
        else:
            line = trial
    lines.append(line)
    for i, ln in enumerate(lines[:2]):
        d.text((title_box[0] + 48, ty + 50 + i * 36), ln, font=f_desc, fill=C["on-surface-variant"], anchor="ls")

    def stat(box, caption, big, sub1, sub2, fill, ink, ink2):
        card(d, box, fill)
        bx, by = box[0] + 40, box[1] + 50
        d.text((bx, by), caption, font=font(22, 820, 118), fill=ink2, anchor="ls")
        size = 92
        while size > 40 and d.textlength(big, font=font(size, 880, 120)) > box[2] - box[0] - 80:
            size -= 4
        d.text((bx, by + 118), big, font=font(size, 880, 120), fill=ink, anchor="ls")
        d.text((bx, by + 172), sub1, font=font(30, 760), fill=ink, anchor="ls")
        d.text((bx, by + 208), sub2, font=font(22, 520), fill=ink2, anchor="ls")

    s1 = (W - PAD - 2 * stat_w - GAP, PAD, W - PAD - stat_w - GAP, PAD + top_h)
    s2 = (W - PAD - stat_w, PAD, W - PAD, PAD + top_h)
    stat(s1, "LIVE COLOUR", "matugen", "Light · Dark", "Follows your wallpaper", C["primary"], C["on-primary"],
         tuple(int(a * 0.75 + b * 0.25) for a, b in zip(C["on-primary"], C["primary"])))
    stat(s2, "GLASS", "Mica", "Compositor blur", "Pages & video stay opaque", C["surface-container-high"],
         C["on-surface"], C["on-surface-variant"])

    # ---------- showcase ----------
    sy = PAD + top_h + GAP
    sh = H - sy - PAD
    frame = (PAD, sy, PAD + int(sh * shot.width / shot.height) + 2 * 28, sy + sh)
    card(d, frame, C["surface-container-low"])
    inner_h = sh - 2 * 28
    shot_s = shot.resize((int(inner_h * shot.width / shot.height), inner_h), Image.LANCZOS)
    img.paste(rounded(shot_s, 26), (frame[0] + 28, frame[1] + 28), rounded(shot_s, 26))

    # Close-ups from the same screenshot.
    col = (frame[2] + GAP, sy, W - PAD, sy + sh)
    cw = col[2] - col[0]
    sidebar = shot.crop((8, 190, 262, 548))        # PINNED · TABS
    media = shot.crop((10, 950, 262, 1016))         # contracted media card
    spaces = shot.crop((14, 1018, 262, 1056))       # foot: spaces chip + FAB

    def tile(box, crop, caption):
        card(d, box, C["surface-container-low"])
        d.text((box[0] + 32, box[1] + 46), caption, font=font(22, 820, 118), fill=C["on-surface-variant"], anchor="ls")
        aw, ah = box[2] - box[0] - 64, box[3] - box[1] - 96
        scale = min(aw / crop.width, ah / crop.height)
        c = crop.resize((int(crop.width * scale), int(crop.height * scale)), Image.LANCZOS)
        px = box[0] + (box[2] - box[0] - c.width) // 2
        py = box[1] + 70 + (ah - c.height) // 2
        r = rounded(c, int(20 * scale / 2))
        img.paste(r, (px, py), r)

    t1_h = int(sh * 0.58)
    tile((col[0], sy, col[2], sy + t1_h), sidebar, "GROUPED TABS · FOLDERS")
    t2_h = (sh - t1_h - GAP) // 2 + 20
    tile((col[0], sy + t1_h + GAP, col[2], sy + t1_h + GAP + t2_h), media, "MEDIA CARD")
    tile((col[0], sy + t1_h + 2 * GAP + t2_h, col[2], sy + sh), spaces, "SPACES")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, quality=90, optimize=True, progressive=True)
    print(OUT, img.size)


if __name__ == "__main__":
    main()
