#!/usr/bin/env python
"""Prepare a phone photo as a square RGBA foreground image for Stable Zero123."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops


def remove_background(image: Image.Image) -> Image.Image:
    try:
        from rembg import remove
    except ImportError as exc:
        raise RuntimeError(
            "rembg is not installed. Install it with `python -m pip install rembg`, "
            "or pass an already background-removed PNG with alpha."
        ) from exc

    return remove(image.convert("RGBA"))


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    if image.mode != "RGBA":
        return image.getbbox() or (0, 0, image.width, image.height)
    alpha = image.getchannel("A")
    return alpha.getbbox() or (0, 0, image.width, image.height)


def trim_near_white_background(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    r, g, b, _ = rgba.split()
    mask = ImageChops.lighter(
        ImageChops.lighter(
            r.point(lambda p: 255 if p < threshold else 0),
            g.point(lambda p: 255 if p < threshold else 0),
        ),
        b.point(lambda p: 255 if p < threshold else 0),
    )
    rgba.putalpha(mask)
    return rgba


def trim_near_black_background(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    r, g, b, _ = rgba.split()
    mask = ImageChops.lighter(
        ImageChops.lighter(
            r.point(lambda p: 255 if p > threshold else 0),
            g.point(lambda p: 255 if p > threshold else 0),
        ),
        b.point(lambda p: 255 if p > threshold else 0),
    )
    rgba.putalpha(mask)
    return rgba


def remove_checkerboard_background(image: Image.Image, tolerance: int) -> Image.Image:
    rgba = image.convert("RGBA")
    rgb = rgba.convert("RGB")
    w, h = rgb.size
    samples = [
        rgb.getpixel((0, 0)),
        rgb.getpixel((min(w - 1, 30), 0)),
        rgb.getpixel((0, min(h - 1, 30))),
        rgb.getpixel((w - 1, 0)),
        rgb.getpixel((0, h - 1)),
        rgb.getpixel((w - 1, h - 1)),
    ]
    # Keep the two most different corner colors as the checkerboard palette.
    c0 = samples[0]
    c1 = max(samples[1:], key=lambda c: sum((int(c[i]) - int(c0[i])) ** 2 for i in range(3)))
    pixels = rgb.load()
    alpha = Image.new("L", rgb.size, 255)
    alpha_pixels = alpha.load()
    tol2 = tolerance * tolerance * 3
    for y in range(h):
        for x in range(w):
            p = pixels[x, y]
            d0 = sum((int(p[i]) - int(c0[i])) ** 2 for i in range(3))
            d1 = sum((int(p[i]) - int(c1[i])) ** 2 for i in range(3))
            if d0 <= tol2 or d1 <= tol2:
                alpha_pixels[x, y] = 0
    rgba.putalpha(alpha)
    return rgba


def make_square_canvas(image: Image.Image, size: int, padding: float) -> Image.Image:
    bbox = alpha_bbox(image)
    cropped = image.crop(bbox).convert("RGBA")
    target = max(1, int(size * (1.0 - padding * 2.0)))
    scale = min(target / cropped.width, target / cropped.height)
    new_size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    resized = cropped.resize(new_size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = ((size - resized.width) // 2, (size - resized.height) // 2)
    canvas.alpha_composite(resized, offset)
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Input phone photo or foreground PNG.")
    parser.add_argument("output", type=Path, help="Output square RGBA PNG.")
    parser.add_argument("--size", type=int, default=512, help="Output image size. Default: 512.")
    parser.add_argument("--padding", type=float, default=0.08, help="Canvas padding ratio. Default: 0.08.")
    parser.add_argument("--remove-bg", action="store_true", help="Use rembg to remove the background.")
    parser.add_argument(
        "--white-bg-threshold",
        type=int,
        default=0,
        help="Treat pixels darker than this value in any RGB channel as foreground; useful for near-white backgrounds.",
    )
    parser.add_argument(
        "--black-bg-threshold",
        type=int,
        default=0,
        help="Treat pixels brighter than this value in any RGB channel as foreground; useful for near-black backgrounds.",
    )
    parser.add_argument(
        "--checkerboard-bg",
        action="store_true",
        help="Remove a baked light/dark checkerboard background by sampling corner colors.",
    )
    parser.add_argument(
        "--checker-tolerance",
        type=int,
        default=22,
        help="RGB tolerance for --checkerboard-bg. Default: 22.",
    )
    args = parser.parse_args()

    image = Image.open(args.input)
    if args.remove_bg:
        image = remove_background(image)
    elif image.mode != "RGBA":
        image = image.convert("RGBA")
    if (not args.remove_bg) and args.white_bg_threshold > 0:
        image = trim_near_white_background(image, args.white_bg_threshold)
    if (not args.remove_bg) and args.black_bg_threshold > 0:
        image = trim_near_black_background(image, args.black_bg_threshold)
    if (not args.remove_bg) and args.checkerboard_bg:
        image = remove_checkerboard_background(image, args.checker_tolerance)

    output = make_square_canvas(image, args.size, args.padding)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)
    print(f"Saved {args.output}")


if __name__ == "__main__":
    main()
