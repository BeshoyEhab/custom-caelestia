#!/usr/bin/env python3
"""Precompute all variant/flavour colours and update scheme.json.

Called from QML after every scheme change so the ColourSelect page can show
real colour swatches instead of hardcoded approximations.
"""

from caelestia.utils.material import get_colours_for_image
from caelestia.utils.paths import atomic_dump, scheme_data_dir, scheme_path
from caelestia.utils.scheme import get_scheme, get_scheme_flavours, read_colours_from_file, scheme_variants
import os
from pathlib import Path


class _TempScheme:
    __slots__ = ("name", "flavour", "mode", "variant")

    def __init__(self, name, flavour, mode, variant):
        self.name = name
        self.flavour = flavour
        self.mode = mode
        self.variant = variant


def main():
    scheme = get_scheme()

    data = {
        "name": scheme.name,
        "flavour": scheme.flavour,
        "mode": scheme.mode,
        "variant": scheme.variant,
        "colours": scheme.colours,
    }

    if scheme.name == "dynamic":
        data["variantColours"] = {}
        for var in scheme_variants:
            if var == scheme.variant:
                data["variantColours"][var] = scheme.colours
            else:
                try:
                    temp = _TempScheme(scheme.name, scheme.flavour, scheme.mode, var)
                    data["variantColours"][var] = get_colours_for_image(scheme=temp)
                except Exception:
                    pass
    else:
        data["flavourColours"] = {}
        for flavour in get_scheme_flavours(scheme.name):
            flavours_dir = scheme_data_dir / scheme.name / flavour
            if not flavours_dir.is_dir():
                continue
            modes = [f.stem for f in flavours_dir.iterdir() if f.is_file()]
            mode = scheme.mode if scheme.mode in modes else (modes[0] if modes else None)
            if mode:
                path = (flavours_dir / mode).with_suffix(".txt")
                if path.exists():
                    data["flavourColours"][flavour] = read_colours_from_file(path)

    atomic_dump(scheme_path, data)
    qs_state = Path(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))) / "quickshell/caelestia/scheme.json"
    atomic_dump(qs_state, data)


if __name__ == "__main__":
    main()
