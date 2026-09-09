#!/usr/bin/env python3
"""Draw the 1024px App Store icon.

The first icon was the whole round seal from the website shrunk onto maroon:
at home-screen size the curved "Wings, Hotdogs, Hamburgers & More" line turned
to noise and the name was small. This one keeps what reads at 60px — the flame
grill from the seal, large, over a warm glow — and re-sets PINZ GRILL in Oswald
(the brand headline face) at full resolution instead of upscaling the 496px
raster's lettering. The seal itself is untouched in the app (hero, site).

Source: ../assets/logo.png (the transparent seal from pinzgrill.com; the CDN
has no larger copy). Oswald is under the SIL OFL, scripts/fonts/OFL.txt.

    ~/.venvs/spendcap/bin/python scripts/make_icon.py
"""
import pathlib
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT.parent / "assets" / "logo.png"
FONT = ROOT / "scripts" / "fonts" / "Oswald.ttf"
OUT = ROOT / "PinzGrill" / "Assets.xcassets" / "AppIcon.appiconset" / "icon.png"
PREVIEW = ROOT / "marketing" / "icon-rounded.png"
SIZE = 1024
MAROON, DEEP, FLAME = (0x3A, 0x0A, 0x1C), (0x24, 0x04, 0x10), (0xE4, 0x46, 0x1B)


def flames_from_seal() -> Image.Image:
    """Everything above the name band: flames + grill bowl."""
    src = Image.open(SRC).convert("RGBA")
    alpha = src.split()[3]
    w, h = src.size
    widths = []
    for y in range(h):
        xs = [x for x in range(w) if alpha.getpixel((x, y)) > 40]
        widths.append((max(xs) - min(xs)) if xs else 0)
    top = next(y for y, ww in enumerate(widths) if ww > 0)
    band_top = next(y for y, ww in enumerate(widths) if ww >= 430)   # the band spans the seal
    part = src.crop((0, top, w, band_top - 2))
    return part.crop(part.getbbox())


def main() -> None:
    icon = Image.new("RGBA", (SIZE, SIZE), MAROON + (255,))
    px = icon.load()
    for y in range(SIZE):
        t = y / (SIZE - 1)
        c = tuple(round(MAROON[i] + (DEEP[i] - MAROON[i]) * t) for i in range(3)) + (255,)
        for x in range(SIZE):
            px[x, y] = c
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((SIZE * 0.15, SIZE * 0.02, SIZE * 0.85, SIZE * 0.62), fill=FLAME + (110,))
    icon.alpha_composite(glow.filter(ImageFilter.GaussianBlur(SIZE * 0.12)))

    flames = flames_from_seal()
    tw = int(SIZE * 0.82)
    flames = flames.resize((tw, int(flames.height * tw / flames.width)), Image.LANCZOS)
    flames = flames.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    icon.alpha_composite(flames, ((SIZE - tw) // 2, int(SIZE * 0.36 - flames.height / 2)))

    font = ImageFont.truetype(str(FONT), 196)
    try:
        font.set_variation_by_name("SemiBold")
    except Exception:
        pass
    draw = ImageDraw.Draw(icon)
    text = "PINZ GRILL"
    bb = draw.textbbox((0, 0), text, font=font)
    draw.text(((SIZE - (bb[2] - bb[0])) / 2 - bb[0], 700 - bb[1]), text, font=font, fill=(255, 255, 255, 255))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.convert("RGB").save(OUT, optimize=True)          # App icons must not carry alpha
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=229, fill=255)
    rounded = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rounded.paste(icon, mask=mask)
    rounded.save(PREVIEW)
    print(OUT, icon.size)


if __name__ == "__main__":
    main()
