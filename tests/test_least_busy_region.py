"""TDD tests for shell/scripts/least_busy_region.py.

Finds the least/most busy (flat/noisy) region of a wallpaper so the desktop
clock can be auto-placed there. Contract under test:

    python3 least_busy_region.py --screen-width W --screen-height H \
        --width CW --height CH [--pad P] [--mode crop|fit|stretch] \
        [--busiest] IMAGE
    -> single-line JSON {"center_x": int, "center_y": int, "variance": float}
       (screen coordinates of the chosen window's centre)

Exit 0 on success, 1 on unreadable image, 2 on bad args.
"""

import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

SCRIPT = Path(__file__).resolve().parent.parent / "shell" / "scripts" / "least_busy_region.py"


def run_cli(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True)


def cli_for(image: Path, screen_w: int, screen_h: int, win_w: int, win_h: int,
            pad: int = 20, mode: str = "crop", busiest: bool = False) -> subprocess.CompletedProcess:
    args = [
        "--screen-width", str(screen_w), "--screen-height", str(screen_h),
        "--width", str(win_w), "--height", str(win_h),
        "--pad", str(pad), "--mode", mode,
    ]
    if busiest:
        args.append("--busiest")
    args.append(str(image))
    return run_cli(*args)


def parse(proc: subprocess.CompletedProcess) -> dict:
    assert proc.returncode == 0, f"stderr: {proc.stderr}"
    data = json.loads(proc.stdout)
    assert set(data) >= {"center_x", "center_y", "variance"}
    return data


def noise_image(w: int, h: int, seed: int = 42) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.integers(0, 256, size=(h, w), dtype=np.uint8)


def save(arr: np.ndarray, path: Path) -> Path:
    Image.fromarray(arr, mode="L").save(path)
    return path


def patch(img: np.ndarray, x: int, y: int, w: int, h: int, value: int = 128) -> None:
    img[y:y + h, x:x + w] = value


def test_script_exists():
    assert SCRIPT.is_file(), f"missing {SCRIPT}"


def test_json_contract(tmp_path):
    img = save(noise_image(1600, 900), tmp_path / "n.png")
    data = parse(cli_for(img, 1600, 900, 200, 200))
    assert isinstance(data["center_x"], int)
    assert isinstance(data["center_y"], int)
    assert isinstance(data["variance"], (int, float))


def test_finds_flat_region(tmp_path):
    arr = noise_image(1600, 900)
    patch(arr, 1100, 600, 200, 200)  # flat patch == window size -> unique argmin
    img = save(arr, tmp_path / "flat.png")
    data = parse(cli_for(img, 1600, 900, 200, 200))
    assert abs(data["center_x"] - 1200) <= 30, data
    assert abs(data["center_y"] - 700) <= 30, data
    assert data["variance"] < 100, data


def test_finds_busy_region(tmp_path):
    arr = np.full((900, 1600), 128, dtype=np.uint8)
    patch(arr, 300, 200, 200, 200, value=0)
    arr[200:400, 300:500] = noise_image(200, 200, seed=7)  # unique noisy patch
    img = save(arr, tmp_path / "busy.png")
    data = parse(cli_for(img, 1600, 900, 200, 200, busiest=True))
    assert abs(data["center_x"] - 400) <= 30, data
    assert abs(data["center_y"] - 300) <= 30, data


def test_crop_mode_uses_visible_area(tmp_path):
    # 3200x900 image on 1600x900 screen: crop keeps image x in [800, 2400].
    # Flat patch sits just inside the visible crop -> must be found there.
    arr = noise_image(3200, 900, seed=3)
    patch(arr, 1000, 400, 200, 200)
    img = save(arr, tmp_path / "wide.png")
    data = parse(cli_for(img, 1600, 900, 200, 200, mode="crop"))
    assert abs(data["center_x"] - 300) <= 30, data   # image 1100 -> screen 300
    assert abs(data["center_y"] - 500) <= 30, data


def test_fit_mode_letterboxes_content(tmp_path):
    # Same wide image with fit: scale 0.5 -> rendered 1600x450 letterboxed
    # with flat 225px black bars top/bottom. The 200px window + 20 pad fits
    # inside those bars, so the emptiest window sits in the top bar -- proof
    # the fit geometry (scale + centring), not the raw image, was analysed.
    arr = noise_image(3200, 900, seed=3)
    patch(arr, 1000, 400, 200, 200)
    img = save(arr, tmp_path / "wide.png")
    data = parse(cli_for(img, 1600, 900, 200, 200, mode="fit"))
    assert 20 <= data["center_y"] - 100 <= 225 - 200, data
    assert data["variance"] < 100, data


def test_stretch_mode_maps_patch(tmp_path):
    arr = noise_image(3200, 900, seed=3)
    patch(arr, 1000, 400, 200, 200)
    img = save(arr, tmp_path / "wide.png")
    data = parse(cli_for(img, 1600, 900, 200, 200, mode="stretch"))
    # Patch maps to screen (500,400)-(600,600): the 200px window over-covers
    # it horizontally, so all fully-covering windows tie (~500-600 centre).
    assert abs(data["center_x"] - 550) <= 80, data
    assert abs(data["center_y"] - 500) <= 80, data


def test_window_respects_pad_inset(tmp_path):
    img = save(noise_image(800, 600, seed=11), tmp_path / "n2.png")
    data = parse(cli_for(img, 800, 600, 300, 200, pad=40))
    assert 40 <= data["center_x"] - 150, data
    assert data["center_x"] + 150 <= 800 - 40, data
    assert 40 <= data["center_y"] - 100, data
    assert data["center_y"] + 100 <= 600 - 40, data


def test_oversized_window_still_valid(tmp_path):
    img = save(noise_image(800, 600, seed=5), tmp_path / "n3.png")
    data = parse(cli_for(img, 800, 600, 900, 700, pad=10))
    assert 0 <= data["center_x"] <= 800, data
    assert 0 <= data["center_y"] <= 600, data


def test_unreadable_image_fails(tmp_path):
    missing = tmp_path / "nope.png"
    proc = cli_for(missing, 1600, 900, 200, 200)
    assert proc.returncode == 1, proc
    assert proc.stdout.strip() == ""


def test_bad_args_fail(tmp_path):
    img = save(noise_image(64, 64, seed=1), tmp_path / "tiny.png")
    proc = run_cli("--screen-width", "1600", str(img))
    assert proc.returncode == 2, proc
    assert "usage:" in proc.stderr, proc.stderr  # argparse rejected, not a python crash
