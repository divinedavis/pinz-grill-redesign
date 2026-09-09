#!/usr/bin/env python3
"""Compose the App Store screenshots from the raw captures.

Input:  build.nosync/screenshots-raw/*.png from scripts/capture_screenshots.sh
        (1320x2868 iPhone 17 Pro Max frames).
Output: marketing/asc-screenshots/{1..5}.png at 1290x2796, the size the
        APP_IPHONE_67 slot accepts; asc_metadata.py uploads that folder.

Portfolio style: five panels, alternating brand colour and white, one short
headline per panel, the screen in a rounded device frame. Headlines are set in
Oswald, uppercase, like the site and the icon; maroon and flame orange are the
brand colours sampled from the seal.

    ~/.venvs/spendcap/bin/python scripts/asc_make_screenshots.py
"""
from __future__ import annotations
import pathlib, shutil, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "build.nosync" / "screenshots-raw"
OUT = ROOT / "marketing" / "asc-screenshots"
OSWALD = ROOT / "scripts" / "fonts" / "Oswald.ttf"
CANVAS = (1290, 2796)
MAROON, FLAME, WHITE, INK, SOFT = (0x3A, 0x0A, 0x1C), (0xE4, 0x46, 0x1B), (255, 255, 255), (0x1A, 0x10, 0x14), (0x6F, 0x5A, 0x52)

# (capture, headline, background, subline)
PANELS = [
    ("01-home",     "WINGS.\nBURGERS.\nPATTY MELTS.",  MAROON, "Order ahead from Pinz Grill on Broad River Road."),
    ("03-menu",     "THE FULL\nMENU, LIVE",             WHITE,  "Prices and sauces straight from the ordering system."),
    ("04-item",     "SAUCED\n8 WAYS",                   MAROON, "Pick your flavors, then check out in two taps."),
    ("05-order",    "PICKUP OR\nDELIVERY",              WHITE,  "Fees, minimums and today's hours before you order."),
    ("07-checkout", "PAY THE\nRESTAURANT",              MAROON, "Apple Pay and saved cards on Pinz Grill's own checkout."),
    ("06-info",     "HOURS, DIRECTIONS,\nCATERING",     MAROON, "Everything you need to know before you pull up."),
]


def oswald(size: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(OSWALD), size)
    try:
        f.set_variation_by_name("SemiBold")
    except Exception:
        pass
    return f


def body_font(size: int) -> ImageFont.FreeTypeFont:
    for p in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/HelveticaNeue.ttc", "/Library/Fonts/Arial.ttf"):
        if pathlib.Path(p).exists():
            f = ImageFont.truetype(p, size)
            try:
                f.set_variation_by_name("Semibold")
            except Exception:
                pass
            return f
    return ImageFont.load_default()


def composite(raw: Image.Image, headline: str, subline: str, bg: tuple, out: pathlib.Path) -> None:
    canvas = Image.new("RGB", CANVAS, bg)
    draw = ImageDraw.Draw(canvas)
    dark = bg != WHITE
    ink = WHITE if dark else MAROON
    sub_ink = (0xF3, 0xD9, 0xCF) if dark else SOFT

    x, y = 96, 150
    hf = oswald(150)
    for line in headline.split("\n"):
        draw.text((x, y), line, fill=ink, font=hf)
        y = draw.textbbox((x, y), line, font=hf)[3] + 2
    # Flame-orange rule under the headline, the site's accent.
    y += 26
    draw.rounded_rectangle((x, y, x + 140, y + 12), radius=6, fill=FLAME)
    y += 44
    bf = body_font(44)
    draw.text((x, y), subline, fill=sub_ink, font=bf)
    y += 44 + 64

    side, bezel = 120, 18
    frame_w = CANVAS[0] - 2 * side
    screen_w = frame_w - 2 * bezel
    screen_h = int(raw.height * screen_w / raw.width)
    frame = Image.new("RGBA", (frame_w, screen_h + 2 * bezel), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame_w, screen_h + 2 * bezel), radius=110, fill=INK)
    screen = raw.resize((screen_w, screen_h), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (screen_w, screen_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, screen_w, screen_h), radius=92, fill=255)
    screen.putalpha(mask)
    frame.paste(screen, (bezel, bezel), screen)
    canvas.paste(frame, (side, y), frame)

    if dark:
        wf = oswald(46)
        w = draw.textbbox((0, 0), "PINZ GRILL", font=wf)[2]
        draw.text((CANVAS[0] - 96 - w, 76), "PINZ GRILL", fill=WHITE, font=wf)
    canvas.save(out, format="PNG", optimize=True)


def main() -> int:
    raws = {p.stem: p for p in RAW.glob("*.png")}
    if not raws:
        raise SystemExit(f"no captures in {RAW}; run scripts/capture_screenshots.sh first")
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    n = 0
    for key, headline, bg, subline in PANELS:
        if n == 5:
            break
        src = raws.get(key)
        if not src:
            print(f"  ! no capture {key}; skipping"); continue
        n += 1
        composite(Image.open(src).convert("RGB"), headline, subline, bg, OUT / f"{n}.png")
        print(f"  ✓ {n}.png  ← {key}")
    print(f"{n} panel(s) in {OUT}")
    return 0 if n >= 3 else 1


if __name__ == "__main__":
    sys.exit(main())
