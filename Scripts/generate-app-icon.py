#!/usr/bin/env python3
"""Build Resources/AppIcon.iconset and Resources/AppIcon.icns from one 1024 PNG.

The source path is Resources/AppIcon-source.png by default, or
PILOTLIGHT_ICON_SOURCE. Drop in a new 1024×1024 PNG (squircle with
transparent corners, no extra mask) and re-run this script.

    python3 Scripts/generate-app-icon.py
    PILOTLIGHT_ICON_SOURCE=/path/to/icon-1024.png python3 Scripts/generate-app-icon.py
"""

from __future__ import annotations

import os
import struct
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "Resources" / "AppIcon-source.png"
ICONSET = ROOT / "Resources" / "AppIcon.iconset"
ICNS = ROOT / "Resources" / "AppIcon.icns"

# (filename, pixel size)
ICONSET_ENTRIES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

# Modern ICNS PNG types. iconutil is preferred on macOS when available.
ICNS_PNG_TYPES = [
    (16, b"icp4"),
    (32, b"icp5"),
    (64, b"icp6"),
    (128, b"ic07"),
    (256, b"ic08"),
    (512, b"ic09"),
    (1024, b"ic10"),
]


def source_path() -> Path:
    override = os.environ.get("PILOTLIGHT_ICON_SOURCE")
    path = Path(override).expanduser() if override else DEFAULT_SOURCE
    if not path.is_file():
        raise SystemExit(f"No source icon at {path}")
    return path


def write_iconset(src: Image.Image) -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    image = src.convert("RGBA")
    for name, size in ICONSET_ENTRIES:
        resized = image.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(ICONSET / name, "PNG")
        print(f"  {name} {size}x{size}")


def png_bytes(image: Image.Image, size: int) -> bytes:
    from io import BytesIO

    buf = BytesIO()
    image.resize((size, size), Image.Resampling.LANCZOS).save(buf, "PNG")
    return buf.getvalue()


def write_icns_python(src: Image.Image) -> None:
    chunks = []
    for size, tag in ICNS_PNG_TYPES:
        data = png_bytes(src, size)
        chunks.append(tag + struct.pack(">I", 8 + len(data)) + data)
    body = b"".join(chunks)
    ICNS.write_bytes(b"icns" + struct.pack(">I", 8 + len(body)) + body)
    print(f"wrote {ICNS} ({ICNS.stat().st_size} bytes)")


def write_icns_iconutil() -> bool:
    if sys.platform != "darwin":
        return False
    try:
        subprocess.run(
            ["iconutil", "-c", "icns", "-o", str(ICNS), str(ICONSET)],
            check=True,
            capture_output=True,
            text=True,
        )
        print(f"wrote {ICNS} via iconutil ({ICNS.stat().st_size} bytes)")
        return True
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"iconutil failed ({exc}); falling back to Python ICNS writer")
        return False


def main() -> None:
    src_path = source_path()
    print(f"source {src_path}")
    image = Image.open(src_path)
    print(f"  mode={image.mode} size={image.size}")
    write_iconset(image)
    if not write_icns_iconutil():
        write_icns_python(image)


if __name__ == "__main__":
    main()
