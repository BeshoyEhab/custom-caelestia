#!/usr/bin/env python3
"""Find the least or most busy (flat or noisy) region of a wallpaper.

Powers desktop clock auto-placement (background.desktopClock.position =
"auto-empty" / "auto-full"). QML passes the screen size, the clock's
bounding box, the padding inset and the wallpaper fill mode; we simulate how
the wallpaper is rendered onto the screen, then slide a window of the
clock's size across it and report the centre of the window with the lowest
(or, with --busiest, the highest) grayscale variance.

Prints one line of JSON:
    {"center_x": <int>, "center_y": <int>, "variance": <float>}
in screen coordinates. Exit codes: 0 ok, 1 unreadable image, 2 bad args.
"""

import argparse
import json
import sys

import numpy as np
from PIL import Image

# Downsample target width. Placement only needs ~pixel accuracy, and the
# integral-image search is O(analysis pixels) either way.
ANALYSIS_WIDTH = 960


def load_gray(path: str) -> Image.Image:
    """Load as 8-bit grayscale, compositing transparency onto black."""
    with Image.open(path) as im:
        im.load()
        if im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in im.info):
            rgba = im.convert("RGBA")
            bg = Image.new("RGB", im.size, (0, 0, 0))
            bg.paste(rgba, mask=rgba.getchannel("A"))
            return bg.convert("L")
        return im.convert("L")


def render_to_screen(img: Image.Image, sw: int, sh: int, mode: str) -> Image.Image:
    """Mirror QML's Image fill modes (Wallpaper.qml wallpaperFillMode)."""
    iw, ih = img.size
    if mode == "stretch":
        return img.resize((sw, sh), Image.LANCZOS)
    if mode == "crop":  # PreserveAspectCrop: fill, centred, cropped
        s = max(sw / iw, sh / ih)
        nw, nh = max(sw, round(iw * s)), max(sh, round(ih * s))
        r = img.resize((nw, nh), Image.LANCZOS)
        x0, y0 = (nw - sw) // 2, (nh - sh) // 2
        return r.crop((x0, y0, x0 + sw, y0 + sh))
    # fit: PreserveAspectFit -> fit inside, centred, black bars
    s = min(sw / iw, sh / ih)
    nw, nh = max(1, round(iw * s)), max(1, round(ih * s))
    canvas = Image.new("L", (sw, sh), 0)
    canvas.paste(img.resize((nw, nh), Image.LANCZOS), ((sw - nw) // 2, (sh - nh) // 2))
    return canvas


def best_window(arr: np.ndarray, win_w: int, win_h: int, pad: int, busiest: bool):
    """Variance search via integral images; returns (x, y, w, h, variance)."""
    H, W = arr.shape
    h, w = min(win_h, H), min(win_w, W)
    pad_y = min(pad, (H - h) // 2)
    pad_x = min(pad, (W - w) // 2)

    ii = np.zeros((H + 1, W + 1))
    ii[1:, 1:] = arr.cumsum(0).cumsum(1)
    ii2 = np.zeros((H + 1, W + 1))
    ii2[1:, 1:] = (arr * arr).cumsum(0).cumsum(1)

    s1 = ii[h:, w:] - ii[:-h, w:] - ii[h:, :-w] + ii[:-h, :-w]
    s2 = ii2[h:, w:] - ii2[:-h, w:] - ii2[h:, :-w] + ii2[:-h, :-w]
    n = h * w
    var = s2 / n - (s1 / n) ** 2

    sub = var[pad_y:H - h - pad_y + 1, pad_x:W - w - pad_x + 1]
    idx = int(np.argmax(sub) if busiest else np.argmin(sub))
    y = pad_y + idx // sub.shape[1]
    x = pad_x + idx % sub.shape[1]
    return x, y, w, h, float(sub.flat[idx])


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("image", help="wallpaper file (path)")
    p.add_argument("--screen-width", type=int, required=True)
    p.add_argument("--screen-height", type=int, required=True)
    p.add_argument("--width", type=int, required=True, help="search window width (clock box)")
    p.add_argument("--height", type=int, required=True, help="search window height (clock box)")
    p.add_argument("--pad", type=int, default=0, help="inset from each screen edge")
    p.add_argument("--mode", choices=("crop", "fit", "stretch"), default="crop")
    p.add_argument("--busiest", action="store_true", help="maximise instead of minimise variance")
    args = p.parse_args(argv)

    if args.screen_width <= 0 or args.screen_height <= 0 or args.width <= 0 or args.height <= 0:
        p.error("screen/window dimensions must be positive")

    try:
        gray = load_gray(args.image)
    except OSError as e:
        print(f"least_busy_region: cannot read {args.image}: {e}", file=sys.stderr)
        return 1

    screen = render_to_screen(gray, args.screen_width, args.screen_height, args.mode)

    f = max(1, -(-args.screen_width // ANALYSIS_WIDTH))  # ceil division
    aw, ah = max(1, screen.width // f), max(1, screen.height // f)
    small = screen.resize((aw, ah), Image.BOX) if f > 1 else screen
    arr = np.asarray(small, dtype=np.float64)

    x, y, w, h, var = best_window(
        arr,
        max(1, round(args.width / f)),
        max(1, round(args.height / f)),
        max(0, round(args.pad / f)),
        args.busiest,
    )
    print(json.dumps({
        "center_x": int(round((x + w / 2) * f)),
        "center_y": int(round((y + h / 2) * f)),
        "variance": round(max(var, 0.0), 3),
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
