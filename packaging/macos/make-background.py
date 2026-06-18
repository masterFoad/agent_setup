#!/usr/bin/env python3
"""Render the FOAD Dev Setup DMG window background.

Usage: make-background.py <output.png>
Requires Pillow. The DMG build script calls this and degrades to a plain
(unstyled) DMG if it is missing, so this is best-effort polish, not required.
"""
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 660, 420
BG_TOP = (24, 27, 38)      # deep slate
BG_BOTTOM = (38, 43, 64)
ACCENT = (122, 162, 255)   # soft blue
TEXT = (236, 239, 248)
MUTED = (150, 158, 184)
NOTE_BG = (44, 38, 24)     # warm strip for the Gatekeeper note
NOTE_TEXT = (240, 214, 150)


def load_font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def centered(draw, text, font, cx, y, fill):
    box = draw.textbbox((0, 0), text, font=font)
    w = box[2] - box[0]
    draw.text((cx - w / 2, y), text, font=font, fill=fill)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "background.png"
    img = Image.new("RGB", (W, H), BG_TOP)
    draw = ImageDraw.Draw(img)

    # vertical gradient
    for y in range(H):
        t = y / H
        r = int(BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t)
        g = int(BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t)
        b = int(BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    title = load_font(34, bold=True)
    sub = load_font(16)
    small = load_font(13)
    note = load_font(13)

    centered(draw, "FOAD Dev Setup", title, W / 2, 34, TEXT)
    centered(draw, "Double-click  “FOAD Dev Setup”  to begin",
             sub, W / 2, 80, ACCENT)

    # downward arrow toward the main icon (icon sits at y~250)
    ax = 175
    draw.line([(ax, 150), (ax, 196)], fill=ACCENT, width=3)
    draw.polygon([(ax - 9, 192), (ax + 9, 192), (ax, 208)], fill=ACCENT)

    # captions under the icon row
    centered(draw, "Start here", small, 175, 318, MUTED)
    centered(draw, "Read first", small, 485, 318, MUTED)

    # Gatekeeper note strip at the bottom
    strip_top = H - 56
    draw.rectangle([(0, strip_top), (W, H)], fill=NOTE_BG)
    centered(draw,
             "Blocked by macOS?  Right-click the icon, choose Open, then Open.",
             note, W / 2, strip_top + 10, NOTE_TEXT)
    centered(draw,
             "(Expected for an unsigned installer — it is safe.)",
             small, W / 2, strip_top + 32, MUTED)

    img.save(out, "PNG")
    print("wrote " + out)


if __name__ == "__main__":
    main()
