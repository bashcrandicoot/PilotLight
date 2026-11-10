#!/usr/bin/env python3
"""Offscreen review renders: pill, Settings (with Style picker), and each border style."""

from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
import importlib.util

_spec = importlib.util.spec_from_file_location("render_preview", ROOT / "Scripts" / "render-preview.py")
rp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rp)

OUT_PILL = ROOT / "review" / "pill-v2.png"
OUT_SETTINGS_LIGHT = ROOT / "review" / "settings-v2-light.png"
OUT_SETTINGS_DARK = ROOT / "review" / "settings-v2-dark.png"
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from asset_paths import font_dir

FONT_DIR = font_dir()

PRESETS = [
    ("Yellow", (0xFF, 0xD6, 0x0A)),
    ("Amber", (0xFF, 0x9F, 0x0A)),
    ("Blue", (0x0A, 0x84, 0xFF)),
    ("Green", (0x30, 0xD1, 0x58)),
    ("Pink", (0xFF, 0x37, 0x5F)),
    ("White", (0xFF, 0xFF, 0xFF)),
]

STYLES = [
    ("Soft Glow", "A soft bloom around the whole screen."),
    ("Pilot Line", "A thin rim and a tight halo around the edge."),
    ("Lamp", "A warm wash falling from the top, behind the pill."),
    ("Corners", "Soft lights tucked into the four corners."),
]


def font(name: str, size: float) -> ImageFont.FreeTypeFont:
    path = FONT_DIR / name
    if path.is_file():
        return ImageFont.truetype(str(path), size=size)
    return ImageFont.truetype(str(FONT_DIR / "SF-Pro-Text-Regular.otf"), size=size)


def measure(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont) -> tuple[float, float]:
    bbox = draw.textbbox((0, 0), text, font=fnt)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def assert_pill_fits(message: str, font_pt: float, scale: float = 4) -> None:
    fnt = rp.load_font(font_pt * scale)
    probe = ImageDraw.Draw(Image.new("RGBA", (4, 4)))
    text_w, text_h = measure(probe, message, fnt)
    if "…" in message or "..." in message:
        raise SystemExit(f"message itself contains an ellipsis: {message!r}")
    slot_x = (rp.PILL_LEADING_PAD + rp.PILL_ICON_SIZE + rp.PILL_ICON_GAP) * scale
    trailing = rp.PILL_TRAILING_PAD * scale
    width = slot_x + math.ceil(text_w) + trailing
    label_slot = width - slot_x - trailing
    if label_slot < text_w - 0.5:
        raise SystemExit(
            f"truncation at {font_pt} pt: text {text_w:.1f}px does not fit slot {label_slot:.1f}px"
        )
    content_h = max(rp.PILL_ICON_SIZE, text_h / scale)
    height = max(rp.PILL_HEIGHT, content_h + rp.PILL_VERTICAL_PAD) * scale
    if height < text_h + 4:
        raise SystemExit(f"vertical clip at {font_pt} pt: text {text_h:.1f} vs pill {height:.1f}")
    print(f"  ok  {font_pt:>5} pt  text={text_w/scale:.1f}pt  pill={width/scale:.1f}x{height/scale:.1f} pt")


def render_pill_sheet() -> Image.Image:
    message = rp.MESSAGE
    if message != "Grok is working":
        raise SystemExit(f"unexpected message: {message!r}")

    print("Pill fit checks (Ember + label, no truncation):")
    sizes = [13.5, 16, 21, 27, 33]
    for pt in sizes:
        assert_pill_fits(message, pt)

    desktop = rp.compose(intensity=0.55, style="softGlow")

    scale = 3
    pills = []
    labels = []
    for pt in sizes:
        pills.append(rp.draw_pill(scale, font_pt=pt, message=message))
        labels.append(f"{pt:g} pt")

    margin = 36
    gap = 12
    label_h = 28
    ladder_h = margin + max(p.height for p in pills) + label_h + margin
    width = desktop.width
    total_w = sum(p.width for p in pills) + gap * (len(pills) - 1)
    sheet = Image.new("RGB", (width, desktop.height + ladder_h), (18, 12, 6))
    sheet.paste(desktop, (0, 0))
    d = ImageDraw.Draw(sheet)
    y0 = desktop.height
    d.rectangle((0, y0, width, y0 + ladder_h), fill=(22, 16, 8))
    caption_font = font("SF-Pro-Text-Medium.otf", 18)
    title = "Same label at larger system text sizes — no truncation"
    tw, th = measure(d, title, caption_font)
    d.text(((width - tw) / 2, y0 + 10), title, font=caption_font, fill=(255, 248, 231))

    row_top = y0 + 38
    avail = width - 48
    if total_w > avail:
        fit = avail / total_w
        pills = [
            p.resize((max(1, int(p.width * fit)), max(1, int(p.height * fit))), Image.Resampling.LANCZOS)
            for p in pills
        ]
        total_w = sum(p.width for p in pills) + gap * (len(pills) - 1)
    x = (width - total_w) // 2
    max_h = max(p.height for p in pills)
    name_font = font("SF-Pro-Text-Regular.otf", 14)
    for p, name in zip(pills, labels):
        py = row_top + (max_h - p.height)
        sheet.paste(p, (x, py), p)
        nw, nh = measure(d, name, name_font)
        d.text((x + (p.width - nw) / 2, row_top + max_h + 2), name, font=name_font, fill=(200, 180, 140))
        x += p.width + gap
    return sheet


def _load_weight(weight: str, size: float) -> ImageFont.FreeTypeFont:
    mapping = {
        "regular": "SF-Pro-Text-Regular.otf",
        "medium": "SF-Pro-Text-Medium.otf",
        "semibold": "SF-Pro-Text-Semibold.otf",
        "bold": "SF-Pro-Text-Bold.otf",
    }
    return font(mapping[weight], size)


def render_settings_window(dark: bool, scale: int = 3) -> Image.Image:
    """Content 440x340 plus a 28 pt title bar, matching SettingsWindowController."""
    cw, ch = 440, 340
    title_h_pt = 28
    w, content_h, title_h = cw * scale, ch * scale, title_h_pt * scale
    h = title_h + content_h

    if dark:
        bg = (45, 45, 48)
        title_bg = (53, 53, 56)
        text = (235, 235, 237)
        secondary = (152, 152, 157)
        hairline = (70, 70, 74)
        track = (90, 90, 94)
        fill = (10, 132, 255)
        knob = (255, 255, 255)
        button_bg = (90, 90, 94)
        button_text = (235, 235, 237)
        button_stroke = (110, 110, 116)
        recessed_bg = (70, 70, 74)
        ring = (235, 235, 237)
        white_edge = (160, 160, 165)
        shadow = (0, 0, 0, 170)
        page = (28, 28, 30)
        seg_track = (70, 70, 74)
        seg_selected = (90, 90, 94)
        seg_divider = (55, 55, 58)
    else:
        bg = (236, 236, 236)
        title_bg = (242, 242, 242)
        text = (29, 29, 31)
        secondary = (110, 110, 115)
        hairline = (210, 210, 212)
        track = (200, 200, 204)
        fill = (0, 122, 255)
        knob = (255, 255, 255)
        button_bg = (255, 255, 255)
        button_text = (29, 29, 31)
        button_stroke = (200, 200, 204)
        recessed_bg = (232, 232, 234)
        ring = (29, 29, 31)
        white_edge = (180, 180, 185)
        shadow = (0, 0, 0, 80)
        page = (230, 230, 232)
        seg_track = (228, 228, 230)
        seg_selected = (255, 255, 255)
        seg_divider = (206, 206, 210)

    traffic = ((255, 95, 86), (255, 189, 46), (39, 201, 63))
    pad = 48
    canvas = Image.new("RGB", (w + pad * 2, h + pad * 2), page)
    rgba = canvas.convert("RGBA")

    sh = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle(
        [pad, pad + 6, pad + w, pad + h + 8],
        radius=12 * scale // 2 + 2,
        fill=shadow,
    )
    sh = sh.filter(ImageFilter.GaussianBlur(radius=10))
    rgba = Image.alpha_composite(rgba, sh)

    win = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    wd = ImageDraw.Draw(win)
    wd.rounded_rectangle([0, 0, w - 1, h - 1], radius=10 * scale, fill=bg)
    title_img = Image.new("RGBA", (w, title_h + 12 * scale), title_bg + (255,))
    tmask = Image.new("L", title_img.size, 0)
    ImageDraw.Draw(tmask).rounded_rectangle(
        [0, 0, w - 1, title_h + 40 * scale],
        radius=10 * scale,
        fill=255,
    )
    title_img.putalpha(tmask)
    cropped = title_img.crop((0, 0, w, title_h))
    win.paste(cropped, (0, 0), cropped)
    wd = ImageDraw.Draw(win)
    wd.line([(0, title_h - 1), (w, title_h - 1)], fill=hairline, width=max(1, scale // 2))

    r = int(6 * scale)
    gap = int(8 * scale)
    x0 = int(16 * scale)
    cy = title_h // 2
    for i, color in enumerate(traffic):
        x = x0 + i * (2 * r + gap)
        wd.ellipse([x - r, cy - r, x + r, cy + r], fill=color)

    title_font = _load_weight("semibold", 13 * scale)
    tw, th = measure(wd, "PilotLight Settings", title_font)
    wd.text(((w - tw) / 2, (title_h - th) / 2 - scale), "PilotLight Settings", font=title_font, fill=text)

    ox, oy = 0, title_h
    s = scale

    def pt(x, y):
        return ox + int(x * s), oy + int(y * s)

    caption_font = _load_weight("medium", 13 * s)
    small_font = _load_weight("regular", 11 * s)
    mono_font = _load_weight("regular", 12 * s)
    button_font = _load_weight("regular", 13 * s)
    seg_font = _load_weight("medium", 11 * s)

    # Style
    y = 20
    wd.text(pt(20, y), "Style", font=caption_font, fill=text)
    y = 20 + 16 + 10
    seg_x, seg_w, seg_h = 20, 96 * 4, 24
    wd.rounded_rectangle(
        [*pt(seg_x, y), *pt(seg_x + seg_w, y + seg_h)],
        radius=int(6 * s),
        fill=seg_track,
    )
    selected = 0
    for i, (name, _blurb) in enumerate(STYLES):
        sx = seg_x + i * 96
        if i == selected:
            inset = 1.5
            wd.rounded_rectangle(
                [*pt(sx + inset, y + inset), *pt(sx + 96 - inset, y + seg_h - inset)],
                radius=int(5 * s),
                fill=seg_selected,
            )
        elif i > 0:
            div_x = sx
            wd.line(
                [*pt(div_x, y + 5), *pt(div_x, y + seg_h - 5)],
                fill=seg_divider,
                width=max(1, s // 2),
            )
        nw, nh = measure(wd, name, seg_font)
        wd.text(
            pt(sx + (96 - nw / s) / 2, y + (seg_h - nh / s) / 2 - 0.4),
            name,
            font=seg_font,
            fill=text,
        )

    y = y + seg_h + 6
    wd.text(pt(20, y), STYLES[selected][1], font=small_font, fill=secondary)

    y = y + 14 + 18
    wd.text(pt(20, y), "Glow color", font=caption_font, fill=text)

    row_top = y + 16 + 12
    row_left, row_right = 20, 420
    count = len(PRESETS)
    swatch_w, swatch_h = 44, 54
    span = row_right - row_left
    spacing = (span - count * swatch_w) / (count - 1) if count > 1 else 0
    diameter = 22
    for i, (name, rgb) in enumerate(PRESETS):
        sx = row_left + i * (swatch_w + spacing)
        sy = row_top
        cx = sx + swatch_w / 2
        cy_s = sy + (swatch_h - 18 - diameter) + diameter / 2
        if i == 0:
            ring_r = (diameter / 2) + 4
            wd.ellipse(
                [*pt(cx - ring_r, cy_s - ring_r), *pt(cx + ring_r, cy_s + ring_r)],
                outline=ring,
                width=max(2, int(2 * s)),
            )
        rbox = [*pt(cx - diameter / 2, cy_s - diameter / 2), *pt(cx + diameter / 2, cy_s + diameter / 2)]
        wd.ellipse(rbox, fill=rgb)
        if name == "White":
            wd.ellipse(rbox, outline=white_edge, width=max(1, s))
        nw, nh = measure(wd, name, small_font)
        tx = sx + (swatch_w - nw / s) / 2
        ty = sy + swatch_h - (nh / s)
        wd.text(pt(tx, ty), name, font=small_font, fill=secondary)

    intensity_y = row_top + swatch_h + 22
    wd.text(pt(20, intensity_y), "Glow intensity", font=caption_font, fill=text)
    percent = "55%"
    pw, ph = measure(wd, percent, mono_font)
    wd.text(pt(420 - pw / s, intensity_y), percent, font=mono_font, fill=secondary)

    slider_y = intensity_y + 16 + 10
    slider_x0, slider_x1 = 20, 420
    slider_cy = slider_y + 8
    track_h = 3
    wd.rounded_rectangle(
        [*pt(slider_x0, slider_cy - track_h / 2), *pt(slider_x1, slider_cy + track_h / 2)],
        radius=int(1.5 * s),
        fill=track,
    )
    t = (0.55 - 0.25) / (1.0 - 0.25)
    knob_x = slider_x0 + t * (slider_x1 - slider_x0)
    wd.rounded_rectangle(
        [*pt(slider_x0, slider_cy - track_h / 2), *pt(knob_x, slider_cy + track_h / 2)],
        radius=int(1.5 * s),
        fill=fill,
    )
    kr = 8
    wd.ellipse(
        [*pt(knob_x - kr, slider_cy - kr), *pt(knob_x + kr, slider_cy + kr)],
        fill=knob,
        outline=hairline,
        width=max(1, s // 2),
    )

    labels_y = slider_y + 16 + 4
    wd.text(pt(20, labels_y), "Softer", font=small_font, fill=secondary)
    sw, _sh = measure(wd, "Stronger", small_font)
    wd.text(pt(420 - sw / s, labels_y), "Stronger", font=small_font, fill=secondary)

    preview_top = labels_y + 14 + 16
    btn_h = 21

    def draw_button(label: str, right: float | None, left: float | None, recessed: bool = False):
        lw, lh = measure(wd, label, button_font if not recessed else small_font)
        pad_x = 22 if not recessed else 14
        btn_w = lw / s + pad_x
        if right is not None:
            btn_x = right - btn_w
        else:
            btn_x = left or 20
        fill_c = recessed_bg if recessed else button_bg
        stroke = button_stroke
        font_c = button_text
        used_font = small_font if recessed else button_font
        lw, lh = measure(wd, label, used_font)
        wd.rounded_rectangle(
            [*pt(btn_x, preview_top), *pt(btn_x + btn_w, preview_top + btn_h)],
            radius=int(5 * s),
            fill=fill_c,
            outline=stroke,
            width=max(1, s),
        )
        wd.text(
            pt(btn_x + (btn_w - lw / s) / 2, preview_top + (btn_h - lh / s) / 2 - 0.5),
            label,
            font=used_font,
            fill=font_c,
        )

    draw_button("Reset", right=None, left=20, recessed=True)
    draw_button("Preview", right=420, left=None, recessed=False)

    rgba.paste(win, (pad, pad), win)
    return rgba.convert("RGB")


def main() -> None:
    OUT_PILL.parent.mkdir(parents=True, exist_ok=True)
    pill = render_pill_sheet()
    pill.save(OUT_PILL, "PNG", optimize=True)
    print(f"wrote {OUT_PILL} {pill.size}")

    light = render_settings_window(dark=False)
    light.save(OUT_SETTINGS_LIGHT, "PNG", optimize=True)
    print(f"wrote {OUT_SETTINGS_LIGHT} {light.size}")

    dark = render_settings_window(dark=True)
    dark.save(OUT_SETTINGS_DARK, "PNG", optimize=True)
    print(f"wrote {OUT_SETTINGS_DARK} {dark.size}")

    for style, filename in rp.STYLE_FILENAMES.items():
        path = ROOT / "review" / filename
        image = rp.compose(intensity=0.55, style=style)
        image.save(path, "PNG", optimize=True)
        print(f"wrote {path} {image.size} style={style}")


if __name__ == "__main__":
    main()
