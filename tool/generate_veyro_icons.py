#!/usr/bin/env python3
"""Render the Veyro vector master into the checked-in native and web icons.

Run with Pillow and resvg-py installed: python3 tool/generate_veyro_icons.py
"""

import io
import json
from pathlib import Path

from resvg_py import svg_to_bytes
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024
SVG = ROOT / "assets/brand/veyro_mark.svg"
MARK = Image.open(io.BytesIO(svg_to_bytes(svg_path=str(SVG), width=SIZE, height=SIZE, skip_system_fonts=True))).convert("RGBA")


def place(mark, scale, bg=None):
    canvas = Image.new("RGBA", (SIZE, SIZE), bg or (0, 0, 0, 0))
    side = round(SIZE * scale)
    canvas.alpha_composite(mark.resize((side, side), Image.Resampling.LANCZOS), ((SIZE - side) // 2,) * 2)
    return canvas


def tile(scale, rounded):
    template = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
      <defs>
        <linearGradient id="base" x2="1" y2="1" gradientUnits="objectBoundingBox">
          <stop stop-color="#170c31"/><stop offset=".56" stop-color="#0c0719"/><stop offset="1" stop-color="#21113e"/>
        </linearGradient>
        <radialGradient id="top" cx=".09" cy="-.09" r=".86">
          <stop stop-color="#9837ff"/><stop offset=".48" stop-color="#6020e7" stop-opacity=".36"/><stop offset="1" stop-color="#191022" stop-opacity="0"/>
        </radialGradient>
        <radialGradient id="bottom" cx=".95" cy="1.05" r=".59">
          <stop stop-color="#852ffe" stop-opacity=".78"/><stop offset="1" stop-color="#1e053e" stop-opacity="0"/>
        </radialGradient>
      </defs>
      <rect width="512" height="512" fill="url(#base)"/>
      <rect width="512" height="512" fill="url(#top)"/>
      <rect width="512" height="512" fill="url(#bottom)"/>
    </svg>"""
    canvas = Image.open(io.BytesIO(svg_to_bytes(svg_string=template, width=SIZE, height=SIZE, skip_system_fonts=True))).convert("RGBA")
    canvas.alpha_composite(place(MARK, scale))
    if rounded:
        # Draw at the master size; smaller icon exports are antialiased on resize.
        alpha = Image.new("L", canvas.size)
        ImageDraw.Draw(alpha).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=222, fill=255)
        canvas.putalpha(alpha)
    return canvas


def save(image, relative, side, opaque=False):
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    thumb = image.resize((side, side), Image.Resampling.LANCZOS)
    (thumb.convert("RGB") if opaque else thumb).save(path, optimize=True)


def app_icon_set(folder, image, opaque=False):
    root = ROOT / folder
    for spec in json.loads((root / "Contents.json").read_text())["images"]:
        if "filename" not in spec:
            continue
        side = round(float(spec["size"].split("x")[0]) * int(spec["scale"].strip("x")))
        save(image, root / spec["filename"], side, opaque=opaque)


rounded = tile(1, True)
store = tile(1, False)
maskable = tile(.79, False)
foreground = place(MARK, .68)
splash = place(MARK, .94)
save(MARK, "assets/brand/veyro_mark.png", 512)
save(MARK, "web/icons/veyro-mark.png", 256)
save(rounded, "web/favicon.png", 64)
for side in (192, 512):
    save(rounded, f"web/icons/Icon-{side}.png", side)
    save(maskable, f"web/icons/Icon-maskable-{side}.png", side, opaque=True)
for suffix, size in zip(("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"), (48, 72, 96, 144, 192)):
    save(rounded, f"android/app/src/main/res/mipmap-{suffix}/ic_launcher.png", size)
    save(foreground, f"android/app/src/main/res/drawable-{suffix}/veyro_icon_foreground.png", size * 108 // 48)
    save(splash, f"android/app/src/main/res/drawable-{suffix}/veyro_launch_mark.png", size * 2)
app_icon_set("ios/Runner/Assets.xcassets/AppIcon.appiconset", store, opaque=True)
app_icon_set("macos/Runner/Assets.xcassets/AppIcon.appiconset", rounded)
for index, suffix in enumerate(("", "@2x", "@3x"), start=1):
    save(MARK, f"ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png", 140 * index)
rounded.save(ROOT / "windows/runner/resources/app_icon.ico", sizes=[(n, n) for n in (16, 24, 32, 48, 64, 128, 256)])
