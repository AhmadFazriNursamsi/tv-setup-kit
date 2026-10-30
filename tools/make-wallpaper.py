#!/usr/bin/env python3
"""Susun 1-3 foto berdampingan menjadi wallpaper TV 1920x1080 tanpa memotong atau memperbesar.

Setiap foto diskalakan setinggi layar dan dipasang utuh; ruang yang tersisa diisi versi buram & gelap
dari foto itu sendiri. Data EXIF (termasuk lokasi GPS dari kamera HP) dibuang.

    python -I tools/make-wallpaper.py foto1.jpg foto2.jpg -o models/<model>/theme/wallpaper.jpg

Butuh Pillow (pip install pillow). Hasil di bawah ~300 KB agar ringan untuk TV RAM 1 GB.
"""
import argparse

from PIL import Image, ImageEnhance, ImageFilter, ImageOps

W, H = 1920, 1080
GAP = 12


def load(path):
    return ImageOps.exif_transpose(Image.open(path)).convert("RGB")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("photos", nargs="+", help="1-3 foto (JPG/PNG)")
    ap.add_argument("-o", "--out", default="wallpaper.jpg")
    ap.add_argument("--quality", type=int, default=82)
    args = ap.parse_args()
    if len(args.photos) > 3:
        ap.error("maksimal 3 foto agar tetap jelas di layar")

    photos = [load(p) for p in args.photos]
    # Tinggi bersama: setinggi layar, kecuali deretan foto jadi lebih lebar dari layar
    widths = [p.width / p.height for p in photos]
    h = min(H, int((W - GAP * (len(photos) - 1)) / sum(widths)))
    fitted = [p.resize((round(p.width * h / p.height), h), Image.LANCZOS) for p in photos]

    # Latar: tiap foto mengisi bagiannya sendiri, diburamkan dan digelapkan
    bg = Image.new("RGB", (W, H))
    slot = W // len(photos)
    for i, p in enumerate(photos):
        w = slot if i < len(photos) - 1 else W - slot * i
        bg.paste(ImageOps.fit(p, (w, H), Image.LANCZOS), (slot * i, 0))
    bg = ImageEnhance.Brightness(bg.filter(ImageFilter.GaussianBlur(40))).enhance(0.4)

    total = sum(f.width for f in fitted) + GAP * (len(fitted) - 1)
    x, y = (W - total) // 2, (H - h) // 2
    for f in fitted:
        bg.paste(f, (x, y))
        x += f.width + GAP

    # Tanpa argumen exif: metadata & GPS tidak ikut tersimpan
    bg.save(args.out, quality=args.quality, optimize=True, progressive=True)
    print(f"{args.out}: {W}x{H}, {len(photos)} foto setinggi {h}px")


if __name__ == "__main__":
    main()
