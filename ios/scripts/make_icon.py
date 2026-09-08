#!/usr/bin/env python3
"""Build the 1024px App Store icon from the site's logo: the logo on the
brand maroon, with the white photo background removed by flood-filling
from the corners (so the white inside the letters survives).

Needs Pillow: ~/.venvs/penciled/bin/python3 scripts/make_icon.py
"""
import pathlib
from PIL import Image, ImageDraw

root = pathlib.Path(__file__).resolve().parent.parent
src = Image.open(root.parent / "assets" / "logo.png").convert("RGBA")
w, h = src.size
# Make the exterior white transparent: flood from every corner with a tolerance.
for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
    ImageDraw.floodfill(src, corner, (0, 0, 0, 0), thresh=40)
bbox = src.getbbox()
logo = src.crop(bbox)

SIZE = 1024
icon = Image.new("RGBA", (SIZE, SIZE), (0x3A, 0x0A, 0x1C, 255))
target = int(SIZE * 0.86)
scale = min(target / logo.width, target / logo.height)
logo = logo.resize((int(logo.width * scale), int(logo.height * scale)), Image.LANCZOS)
icon.alpha_composite(logo, ((SIZE - logo.width) // 2, (SIZE - logo.height) // 2))
out = root / "PinzGrill" / "Assets.xcassets" / "AppIcon.appiconset" / "icon.png"
icon.convert("RGB").save(out, optimize=True)   # App icons must not carry alpha
print(out, icon.size)
