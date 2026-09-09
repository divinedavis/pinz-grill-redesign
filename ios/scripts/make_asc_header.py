#!/usr/bin/env python3
"""Header / Search Results creative asset for the App Store product page:
the hero wings photo, darkened to maroon, the seal's flame grill and the
PINZ GRILL wordmark, plus one line. 1280x720 and 5244x2950 (Apple's two
accepted sizes) into marketing/asc-header/. Upload is browser-only:
App Store Connect → Distribution → Product Page → Header and Search Results.

    ~/.venvs/spendcap/bin/python scripts/make_asc_header.py
"""
import pathlib, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from make_icon import flames_from_seal, FONT, MAROON  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
PHOTO = ROOT.parent / "assets" / "hero-wings.jpg"
OUT = ROOT / "marketing" / "asc-header"


def oswald(size, weight="SemiBold"):
    f = ImageFont.truetype(str(FONT), size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def banner(w: int, h: int) -> Image.Image:
    photo = Image.open(PHOTO).convert("RGB")
    s = max(w / photo.width, h / photo.height)
    photo = photo.resize((int(photo.width * s) + 1, int(photo.height * s) + 1), Image.LANCZOS)
    photo = photo.crop(((photo.width - w) // 2, (photo.height - h) // 2, (photo.width - w) // 2 + w, (photo.height - h) // 2 + h))
    tint = Image.new("RGB", (w, h), MAROON)
    im = Image.blend(photo, tint, 0.68).convert("RGBA")
    # Left-to-right fade so the wordmark sits on solid brand colour.
    grad = Image.new("L", (w, 1))
    for x in range(w):
        grad.putpixel((x, 0), int(245 * max(0.0, 1 - x / (w * 0.70))))
    im.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", (w, h), MAROON).split(), grad.resize((w, h)))))

    flames = flames_from_seal()
    fh = int(h * 0.50)
    flames = flames.resize((int(flames.width * fh / flames.height), fh), Image.LANCZOS).filter(ImageFilter.UnsharpMask(2, 60, 2))
    fx = int(w * 0.055)
    im.alpha_composite(flames, (fx, int(h * 0.10)))
    d = ImageDraw.Draw(im)
    f1 = oswald(int(h * 0.20))
    d.text((fx, int(h * 0.60)), "PINZ GRILL", font=f1, fill=(255, 255, 255, 255))
    f2 = oswald(int(h * 0.075), "Regular")
    d.text((fx + 6, int(h * 0.60) + int(h * 0.215)), "WINGS · BURGERS · PIZZA · ORDER AHEAD", font=f2, fill=(0xF3, 0xD9, 0xCF, 255))
    return im.convert("RGB")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for w, h in ((1280, 720), (5244, 2950)):
        banner(w, h).save(OUT / f"header-{w}x{h}.png", optimize=True)
        print(OUT / f"header-{w}x{h}.png")
