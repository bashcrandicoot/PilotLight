"""Portable locations for brand assets and SF Pro fonts.

Override with PILOTLIGHT_BRAND, GROK_BORDER_ROOT, or SF_PRO_FONT_DIR
when the defaults (a sibling brand folder, or standard font directories)
do not apply.
"""

from __future__ import annotations

import os
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPTS_DIR.parent


def _existing(candidates: list[Path]) -> Path | None:
    for path in candidates:
        if path.exists():
            return path
    return None


def brand_root() -> Path:
    override = os.environ.get("PILOTLIGHT_BRAND")
    if override:
        return Path(override).expanduser()
    found = _existing([
        REPO_ROOT.parent / "pilotlight-brand",
        Path.home() / "Developer" / "pilotlight-brand",
    ])
    return found if found is not None else REPO_ROOT.parent / "pilotlight-brand"


def grok_border_root() -> Path:
    override = os.environ.get("GROK_BORDER_ROOT")
    if override:
        return Path(override).expanduser()
    found = _existing([
        REPO_ROOT.parent / "grok-border",
        Path.home() / "Developer" / "grok-border",
    ])
    return found if found is not None else REPO_ROOT.parent / "grok-border"


def font_dir() -> Path:
    override = os.environ.get("SF_PRO_FONT_DIR")
    if override:
        return Path(override).expanduser()
    found = _existing([
        Path.home() / ".local" / "share" / "fonts" / "SF-Pro",
        Path.home() / "Library" / "Fonts" / "SF-Pro",
        Path("/Library/Fonts/SF-Pro"),
    ])
    return found if found is not None else Path.home() / ".local" / "share" / "fonts" / "SF-Pro"


def menubar_source() -> Path:
    override = os.environ.get("PILOTLIGHT_MENUBAR_SOURCE")
    if override:
        return Path(override).expanduser()
    return brand_root() / "icon" / "menubar"


def ember_svg() -> Path:
    return brand_root() / "bot" / "ember" / "ember.svg"
