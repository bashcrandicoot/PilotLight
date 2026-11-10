#!/usr/bin/env python3
"""Copy official Ember menu-bar template images into Resources.

The app icon is built separately by generate-app-icon.py from
Resources/AppIcon-source.png. This script must not touch the icon.

    python3 Scripts/generate-assets.py
    PILOTLIGHT_MENUBAR_SOURCE=/path/to/menubar python3 Scripts/generate-assets.py

Expected in the source folder:
    ember-menubar.svg
    ember-menubar-18.png      (18×18 template, @1×)
    ember-menubar-18@2x.png   (36×36 template, @2×)
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"

import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from asset_paths import menubar_source
DEFAULT_SOURCE = menubar_source()

FILES = [
    ("ember-menubar-18.png", "MenuIcon.png"),
    ("ember-menubar-18@2x.png", "MenuIcon@2x.png"),
    ("ember-menubar.svg", "ember-menubar.svg"),
]

# Leftovers from the retired cream-robot assets.
STALE = ["Robot.png", "Robot@2x.png", "robot.svg"]


def source_dir() -> Path:
    override = os.environ.get("PILOTLIGHT_MENUBAR_SOURCE")
    path = Path(override).expanduser() if override else DEFAULT_SOURCE
    if not path.is_dir():
        raise SystemExit(f"No menu-bar source folder at {path}")
    return path


def main() -> None:
    src = source_dir()
    RESOURCES.mkdir(parents=True, exist_ok=True)
    for src_name, dest_name in FILES:
        origin = src / src_name
        if not origin.is_file():
            raise SystemExit(f"Missing {origin}")
        dest = RESOURCES / dest_name
        shutil.copy2(origin, dest)
        print(f"copied {origin} -> {dest}")
    for name in STALE:
        stale = RESOURCES / name
        if stale.exists():
            stale.unlink()
            print(f"removed {stale}")


if __name__ == "__main__":
    main()
