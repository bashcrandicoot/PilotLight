#!/usr/bin/env python3
"""Offscreen strip of the pill at three text sizes, plus the menu-bar menu."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
import importlib.util

_spec = importlib.util.spec_from_file_location("render_preview", ROOT / "Scripts" / "render-preview.py")
rp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rp)

OUT_SIZES = ROOT / "review" / "pill-sizes.png"
OUT_MENU = ROOT / "review" / "menu-v2.png"
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from asset_paths import font_dir

FONT_DIR = font_dir()

SIZES = [
    (11.0, "Small"),
    (13.5, "Default"),
    (33.0, "Large (Accessibility)"),
]


def font(name: str, size: float) -> ImageFont.FreeTypeFont:
    path = FONT_DIR / name
    if path.is_file():
        return ImageFont.truetype(str(path), size=size)
    return ImageFont.truetype(str(FONT_DIR / "SF-Pro-Text-Regular.otf"), size=size)


def measure(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont) -> tuple[float, float]:
    bbox = draw.textbbox((0, 0), text, font=fnt)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def assert_pill_scales(message: str, font_pt: float, scale: float = 4) -> tuple[float, float, float]:
    if "…" in message or "..." in message:
        raise SystemExit(f"message itself contains an ellipsis: {message!r}")
    m = rp.pill_metrics(font_pt)
    fnt = rp.load_font(font_pt * scale)
    probe = ImageDraw.Draw(Image.new("RGBA", (4, 4)))
    text_w, text_h = measure(probe, message, fnt)
    slot = m["icon"] * scale + 0  # points later
    label_slot = math.ceil(text_w)  # the slot is sized to the text
    width_pt = m["leading"] + m["icon"] + m["gap"] + math.ceil(text_w) / scale + m["trailing"]
    content_h = max(m["icon"], text_h / scale)
    height_pt = max(m["height"], content_h + m["vertical"])
    if math.ceil(text_w) / scale > (width_pt - m["leading"] - m["icon"] - m["gap"] - m["trailing"]) + 0.05:
        raise SystemExit(f"truncation at {font_pt} pt")
    if height_pt + 0.01 < m["icon"] + 1:
        raise SystemExit(f"Ember clipped at {font_pt} pt: icon {m['icon']:.1f} vs height {height_pt:.1f}")
    if height_pt + 0.01 < text_h / scale:
        raise SystemExit(f"text clipped vertically at {font_pt} pt")
    ratio = height_pt / font_pt
    expected = rp.PILL_HEIGHT / rp.DESIGN_FONT_SIZE
    # Height is at least the design ratio; may be taller if the glyph is unusually tall.
    if ratio + 0.05 < expected:
        raise SystemExit(f"height did not scale at {font_pt} pt: {ratio:.3f} vs {expected:.3f}")
    print(
        f"  ok  {font_pt:>5} pt  pill={width_pt:.1f}x{height_pt:.1f} pt  "
        f"ember={m['icon']:.1f}  pad={m['leading']:.1f}/{m['trailing']:.1f}  halo={m['halo_extent']:.0f}"
    )
    return width_pt, height_pt, m["halo_extent"]


def render_pill_strip() -> Image.Image:
    message = rp.MESSAGE
    if message != "Grok is working":
        raise SystemExit(f"unexpected message: {message!r}")

    print("Pill scale checks (whole pill tracks the label size):")
    scale = 3
    pills = []
    captions = []
    heights = []
    for pt, name in SIZES:
        w, h, _halo = assert_pill_scales(message, pt)
        pills.append(rp.draw_pill(scale, font_pt=pt, message=message))
        captions.append(f"{name}  ·  {pt:g} pt")
        heights.append(h)
        if abs(pt - 13.5) < 0.01:
            default_h = h
    # Proportional check vs default
    for (pt, name), h in zip(SIZES, heights):
        expected = default_h * (pt / 13.5)
        if abs(h - expected) > 1.0 and h + 0.01 < expected:
            raise SystemExit(f"{name}: height {h:.1f} is not proportional to default {expected:.1f}")

    # Pack each pill in a column sized to itself so the large halo does not
    # blow out the small and default columns.
    gap = 28
    pad_x, pad_top, pad_bot = 64, 100, 80
    col_widths = [p.width + 16 for p in pills]
    width = pad_x * 2 + sum(col_widths) + gap * (len(pills) - 1)
    row_h = max(p.height for p in pills)
    height = pad_top + row_h + pad_bot
    sheet = Image.new("RGB", (width, height), (22, 16, 8))
    d = ImageDraw.Draw(sheet)
    title_font = font("SF-Pro-Text-Medium.otf", 36)
    cap_font = font("SF-Pro-Text-Regular.otf", 24)
    sub_font = font("SF-Pro-Text-Regular.otf", 20)
    title = "The whole pill scales with the text"
    tw, th = measure(d, title, title_font)
    d.text(((width - tw) / 2, 20), title, font=title_font, fill=(255, 248, 231))
    subtitle = "Height, padding, Ember, gap, and the capsule radius all follow the label size — no truncation"
    sw, sh = measure(d, subtitle, sub_font)
    d.text(((width - sw) / 2, 20 + th + 8), subtitle, font=sub_font, fill=(200, 180, 140))

    x = pad_x
    for pill, caption, col_w in zip(pills, captions, col_widths):
        cx = x + col_w // 2
        px = cx - pill.width // 2
        py = pad_top + (row_h - pill.height)
        sheet.paste(pill, (px, py), pill)
        nw, nh = measure(d, caption, cap_font)
        d.text((cx - nw / 2, pad_top + row_h + 16), caption, font=cap_font, fill=(255, 248, 231))
        x += col_w + gap

    # A review-friendly width; keep the relative sizes honest.
    max_w = 2200
    if sheet.width > max_w:
        ratio = max_w / sheet.width
        sheet = sheet.resize((max_w, max(1, int(sheet.height * ratio))), Image.Resampling.LANCZOS)
    return sheet


def render_menu(scale: int = 3) -> Image.Image:
    """Menu-bar menu, light appearance, Tip Jar just above Quit."""
    items = [
        ("Border: Off", "", "disabled"),
        ("—", "", "sep"),
        ("Hide Border Now", "", "disabled"),
        ("Show Test Border for 5s", "", "item"),
        ("—", "", "sep"),
        ("Quick Start…", "", "item"),
        ("Settings…", "⌘,", "item"),
        ("—", "", "sep"),
        ("Tip Jar", "", "item"),
        ("—", "", "sep"),
        ("Quit PilotLight", "⌘Q", "item"),
    ]

    # Light macOS menu
    menu_bg = (246, 246, 246)
    menu_stroke = (200, 200, 204)
    text = (29, 29, 31)
    disabled = (155, 155, 158)
    sep = (198, 198, 201)
    shortcut = (110, 110, 115)
    highlight = None  # no item selected
    page = (230, 230, 232)
    bar = (246, 246, 248)
    bar_line = (200, 200, 204)
    shadow = (0, 0, 0, 70)

    item_font = font("SF-Pro-Text-Regular.otf", 13 * scale)
    key_font = font("SF-Pro-Text-Regular.otf", 13 * scale)
    probe = ImageDraw.Draw(Image.new("RGB", (4, 4)))
    text_w = max(
        measure(probe, title, item_font)[0]
        for title, _key, kind in items
        if kind != "sep"
    )
    key_w = max((measure(probe, key, key_font)[0] for _t, key, kind in items if key), default=0)

    left_pad = 20 * scale
    right_pad = 16 * scale
    key_gap = 28 * scale
    menu_w = int(left_pad + text_w + (key_gap + key_w if key_w else 0) + right_pad)
    row_h = int(22 * scale)
    sep_h = int(11 * scale)
    rows = []
    y = int(5 * scale)
    for title, key, kind in items:
        h = sep_h if kind == "sep" else row_h
        rows.append((y, h, title, key, kind))
        y += h
    menu_h = y + int(5 * scale)

    # Canvas: short menu bar + menu, with drop shadow
    bar_h = int(25 * scale)
    margin = 48
    canvas_w = menu_w + margin * 2 + 20
    canvas_h = bar_h + menu_h + margin * 2
    canvas = Image.new("RGB", (canvas_w, canvas_h), page)
    rgba = canvas.convert("RGBA")

    # Menu bar
    bd = ImageDraw.Draw(rgba)
    bd.rectangle([0, margin, canvas_w, margin + bar_h], fill=bar + (255,))
    bd.line([(0, margin + bar_h - 1), (canvas_w, margin + bar_h - 1)], fill=bar_line, width=max(1, scale // 2))

    # Official Ember menu-bar template (black silhouette, eye cut-outs).
    icon_path = ROOT / "Resources" / "MenuIcon@2x.png"
    ember_icon = Image.open(icon_path).convert("RGBA")
    icon_target = int(16 * scale)
    ember_icon = ember_icon.resize((icon_target, icon_target), Image.Resampling.LANCZOS)
    icon_x = margin + int(10 * scale)
    icon_y = margin + (bar_h - ember_icon.height) // 2
    rgba.alpha_composite(ember_icon, (icon_x, icon_y))

    # Shadow
    sh = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    mx0 = margin
    my0 = margin + bar_h - int(2 * scale)
    sd.rounded_rectangle(
        [mx0 + 4, my0 + 6, mx0 + menu_w + 4, my0 + menu_h + 8],
        radius=8 * scale,
        fill=shadow,
    )
    sh = sh.filter(ImageFilter.GaussianBlur(radius=8))
    rgba = Image.alpha_composite(rgba, sh)

    menu = Image.new("RGBA", (menu_w, menu_h), (0, 0, 0, 0))
    md = ImageDraw.Draw(menu)
    md.rounded_rectangle([0, 0, menu_w - 1, menu_h - 1], radius=6 * scale, fill=menu_bg, outline=menu_stroke, width=max(1, scale // 2))
    for y0, h, title, key, kind in rows:
        if kind == "sep":
            mid = y0 + h // 2
            md.line([(8 * scale, mid), (menu_w - 8 * scale, mid)], fill=sep, width=max(1, scale // 2))
            continue
        fill = disabled if kind == "disabled" else text
        tw, th = measure(md, title, item_font)
        md.text((left_pad, y0 + (h - th) / 2 - scale * 0.4), title, font=item_font, fill=fill)
        if key:
            kw, kh = measure(md, key, key_font)
            md.text((menu_w - right_pad - kw, y0 + (h - kh) / 2 - scale * 0.4), key, font=key_font, fill=shortcut)

    rgba.paste(menu, (mx0, my0), menu)
    return rgba.convert("RGB")


def main() -> None:
    OUT_SIZES.parent.mkdir(parents=True, exist_ok=True)
    strip = render_pill_strip()
    strip.save(OUT_SIZES, "PNG", optimize=True)
    print(f"wrote {OUT_SIZES} {strip.size}")

    menu = render_menu()
    menu.save(OUT_MENU, "PNG", optimize=True)
    print(f"wrote {OUT_MENU} {menu.size}")


if __name__ == "__main__":
    main()
