#!/usr/bin/env python3
"""Review stills for the refined Ember bun in the pill and Quick Start."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import importlib.util

from asset_paths import brand_root, font_dir
from ember_geometry import (
    EMBER_RGBA,
    EYE_H,
    EYE_W,
    LEGACY_EYE_CENTERS,
    LEGACY_EYE_H,
    LEGACY_EYE_W,
    LEGACY_LOBES,
    LOBES,
    eye_centers,
)

_spec = importlib.util.spec_from_file_location("render_preview", ROOT / "Scripts" / "render-preview.py")
rp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rp)

OUT_PILL = ROOT / "review" / "pill-v3.png"
OUT_COMPARE = ROOT / "review" / "ember-old-new-master.png"
MASTER = brand_root() / "icon" / "ember-character-refined-600.png"
FONT_DIR = font_dir()
SPACE = Path(
    "/usr/share/fonts/truetype/sand-box/google/Space Grotesk/SpaceGrotesk-VariableFont_wght.ttf"
)


def font(size: int, weight: int = 600) -> ImageFont.FreeTypeFont:
    if SPACE.is_file():
        f = ImageFont.truetype(str(SPACE), size)
        try:
            f.set_variation_by_axes([weight])
        except Exception:
            pass
        return f
    for name in ("SF-Pro-Text-Semibold.otf", "SF-Pro-Text-Regular.otf"):
        path = FONT_DIR / name
        if path.is_file():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def draw_bun(
    size: int,
    lobes,
    centers,
    eye_w: float,
    eye_h: float,
) -> Image.Image:
    over = max(size * 4, 256)
    img = Image.new("RGBA", (over, over), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = over / 64.0

    def ellipse(cx, cy, rx, ry, fill):
        draw.ellipse(((cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s), fill=fill)

    for cx, cy, rx, ry in lobes:
        ellipse(cx, cy, rx, ry, EMBER_RGBA)

    hw, hh = eye_w / 2, eye_h / 2
    for cx, cy in centers:
        layer = Image.new("RGBA", (over, over), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        box = ((cx - hw) * s, (cy - hh) * s, (cx + hw) * s, (cy + hh) * s)
        ld.rounded_rectangle(box, radius=hw * s, fill=(255, 255, 255, 255))
        layer = layer.rotate(-10, resample=Image.Resampling.BICUBIC, center=(cx * s, cy * s))
        img = Image.alpha_composite(img, layer)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def render_pill_v3() -> Image.Image:
    scale = 4
    pill = rp.draw_pill(scale)
    # Dark teal-night field, generous crop around the pill.
    import numpy as np
    pad_x, pad_y = 80, 64
    w = pill.width + pad_x * 2
    h = pill.height + pad_y * 2
    yy = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    top = np.array((0x0B, 0x2A, 0x33), dtype=np.float32)
    bot = np.array((0x13, 0x4A, 0x52), dtype=np.float32)
    rgb = np.repeat(top + (bot - top) * yy, w, axis=1).astype(np.uint8)
    bg = Image.fromarray(rgb, "RGB").convert("RGBA")
    bg.alpha_composite(pill, (pad_x, pad_y))
    return bg.convert("RGB")


def render_compare() -> Image.Image:
    cell = 600
    gap = 48
    label_h = 72
    pad = 56
    cols = 3
    width = pad * 2 + cols * cell + (cols - 1) * gap
    height = pad * 2 + cell + label_h
    sheet = Image.new("RGB", (width, height), (16, 16, 18))
    draw = ImageDraw.Draw(sheet)
    title = font(22, 600)
    captions = (
        "Original pill bun",
        "New pill Ember",
        "Brandy's refined master",
    )
    images = [
        draw_bun(cell, LEGACY_LOBES, LEGACY_EYE_CENTERS, LEGACY_EYE_W, LEGACY_EYE_H),
        draw_bun(cell, LOBES, eye_centers(), EYE_W, EYE_H),
    ]
    if not MASTER.is_file():
        raise SystemExit(f"missing refined master at {MASTER}")
    master = Image.open(MASTER).convert("RGBA")
    # Fit into the 600 square, keep aspect, centered.
    mw, mh = master.size
    scale = min(cell / mw, cell / mh)
    fitted = master.resize((int(mw * scale), int(mh * scale)), Image.Resampling.LANCZOS)
    slot = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    slot.paste(fitted, ((cell - fitted.width) // 2, (cell - fitted.height) // 2), fitted)
    images.append(slot)

    for i, (im, caption) in enumerate(zip(images, captions)):
        x = pad + i * (cell + gap)
        y = pad
        sheet.paste(im, (x, y), im if im.mode == "RGBA" else None)
        tw = draw.textbbox((0, 0), caption, font=title)[2]
        draw.text(
            (x + (cell - tw) / 2, y + cell + 18),
            caption,
            font=title,
            fill=(236, 236, 238),
        )
    return sheet


def main() -> None:
    OUT_PILL.parent.mkdir(parents=True, exist_ok=True)
    pill = render_pill_v3()
    pill.save(OUT_PILL, "PNG")
    print(f"wrote {OUT_PILL} {pill.size[0]}x{pill.size[1]}")
    compare = render_compare()
    compare.save(OUT_COMPARE, "PNG")
    print(f"wrote {OUT_COMPARE} {compare.size[0]}x{compare.size[1]}")


if __name__ == "__main__":
    main()
