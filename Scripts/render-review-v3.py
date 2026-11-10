#!/usr/bin/env python3
"""Settings v3 and the revised Pilot Line review renders."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
import importlib.util

_spec = importlib.util.spec_from_file_location("render_preview", ROOT / "Scripts" / "render-preview.py")
rp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rp)

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
    ("Pilot Line", "A clean line around the screen, inset from the edge."),
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


def _load_weight(weight: str, size: float) -> ImageFont.FreeTypeFont:
    mapping = {
        "regular": "SF-Pro-Text-Regular.otf",
        "medium": "SF-Pro-Text-Medium.otf",
        "semibold": "SF-Pro-Text-Semibold.otf",
    }
    return font(mapping[weight], size)


def render_settings(dark: bool, selected_style: int = 0, thickness_pt: int = 3, scale: int = 3, tip_jar: bool = False) -> Image.Image:
    """480-wide Settings window. Thickness row only when Pilot Line is selected."""
    show_thickness = selected_style == 1
    cw = 480
    title_h_pt = 28
    # Content height from the Swift stack.
    # margin 20 + style cap 16 + 8 + seg 24 + 6 + blurb 14 + 16 + color 16 + 8 + swatch 54
    # + (thickness: 16 + 16 + 8 + 22 + 4 + 14) + 16 + intens 16 + 8 + slider 22 + 4 + 14
    # + 16 + buttons 21 + 20
    content_h_pt = 20 + 16 + 8 + 24 + 6 + 14 + 16 + 16 + 8 + 54
    content_h_pt += 16 + 16 + 8 + 22 + 4 + 14  # intensity block (section gap included)
    content_h_pt += 16 + 21 + 20  # buttons
    if show_thickness:
        content_h_pt += 16 + 16 + 8 + 22 + 4 + 14

    w, content_h, title_h = cw * scale, int(content_h_pt * scale), title_h_pt * scale
    h = title_h + content_h
    margin = 20

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
        default_btn = (10, 132, 255)
        default_text = (255, 255, 255)
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
        default_btn = (0, 122, 255)
        default_text = (255, 255, 255)
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

    # Traffic lights: close only (zoom and miniaturize hidden)
    r = int(6 * scale)
    cx = int(16 * scale)
    cy = title_h // 2
    wd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=traffic[0])
    # Dim the hidden buttons so the title bar still looks like a standard window
    # with only Close enabled — draw them faded.
    gap = int(8 * scale)
    for i, color in enumerate(traffic[1:], start=1):
        x = cx + i * (2 * r + gap)
        faded = tuple(int(c * 0.45 + (bg[j] * 0.55)) for j, c in enumerate(color))
        wd.ellipse([x - r, cy - r, x + r, cy + r], fill=faded)

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

    y = 20
    wd.text(pt(margin, y), "Style", font=caption_font, fill=text)
    y = 20 + 16 + 8
    inner = cw - margin * 2
    seg_h = 24
    wd.rounded_rectangle(
        [*pt(margin, y), *pt(margin + inner, y + seg_h)],
        radius=int(6 * s),
        fill=seg_track,
    )
    seg_w = inner / 4
    for i, (name, _blurb) in enumerate(STYLES):
        sx = margin + i * seg_w
        if i == selected_style:
            inset = 1.5
            wd.rounded_rectangle(
                [*pt(sx + inset, y + inset), *pt(sx + seg_w - inset, y + seg_h - inset)],
                radius=int(5 * s),
                fill=seg_selected,
            )
        elif i > 0:
            wd.line(
                [*pt(sx, y + 5), *pt(sx, y + seg_h - 5)],
                fill=seg_divider,
                width=max(1, s // 2),
            )
        nw, nh = measure(wd, name, seg_font)
        wd.text(
            pt(sx + (seg_w - nw / s) / 2, y + (seg_h - nh / s) / 2 - 0.4),
            name,
            font=seg_font,
            fill=text,
        )

    y = y + seg_h + 6
    wd.text(pt(margin, y), STYLES[selected_style][1], font=small_font, fill=secondary)

    y = y + 14 + 16
    wd.text(pt(margin, y), "Glow color", font=caption_font, fill=text)

    row_top = y + 16 + 8
    row_left, row_right = margin, cw - margin
    count = len(PRESETS)
    swatch_w, swatch_h = 44, 54
    span = row_right - row_left
    spacing = (span - count * swatch_w) / (count - 1) if count > 1 else 0
    diameter = 22
    for i, (name, rgb) in enumerate(PRESETS):
        sx = row_left + i * (swatch_w + spacing)
        sy = row_top
        cxp = sx + swatch_w / 2
        cy_s = sy + (swatch_h - 18 - diameter) + diameter / 2
        if i == 0:
            ring_r = (diameter / 2) + 4
            wd.ellipse(
                [*pt(cxp - ring_r, cy_s - ring_r), *pt(cxp + ring_r, cy_s + ring_r)],
                outline=ring,
                width=max(2, int(2 * s)),
            )
        rbox = [*pt(cxp - diameter / 2, cy_s - diameter / 2), *pt(cxp + diameter / 2, cy_s + diameter / 2)]
        wd.ellipse(rbox, fill=rgb)
        if name == "White":
            wd.ellipse(rbox, outline=white_edge, width=max(1, s))
        nw, nh = measure(wd, name, small_font)
        tx = sx + (swatch_w - nw / s) / 2
        ty = sy + swatch_h - (nh / s)
        wd.text(pt(tx, ty), name, font=small_font, fill=secondary)

    y = row_top + swatch_h

    def draw_slider_block(y0: float, caption: str, value: str, t: float, left_l: str, right_l: str) -> float:
        y0 = y0 + 16
        wd.text(pt(margin, y0), caption, font=caption_font, fill=text)
        vw, _vh = measure(wd, value, mono_font)
        wd.text(pt(cw - margin - vw / s, y0), value, font=mono_font, fill=secondary)
        slider_y = y0 + 16 + 8
        slider_x0, slider_x1 = margin, cw - margin
        slider_cy = slider_y + 8
        track_h = 3
        wd.rounded_rectangle(
            [*pt(slider_x0, slider_cy - track_h / 2), *pt(slider_x1, slider_cy + track_h / 2)],
            radius=int(1.5 * s),
            fill=track,
        )
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
        wd.text(pt(margin, labels_y), left_l, font=small_font, fill=secondary)
        sw, _sh = measure(wd, right_l, small_font)
        wd.text(pt(cw - margin - sw / s, labels_y), right_l, font=small_font, fill=secondary)
        return labels_y + 14

    if show_thickness:
        # 1...8, default 3 → t = (3-1)/(8-1) = 2/7
        t = (thickness_pt - 1) / 7
        y = draw_slider_block(y, "Line thickness", f"{thickness_pt} pt", t, "Thinner", "Thicker")

    y = draw_slider_block(y, "Glow intensity", "55%", (0.55 - 0.25) / (1.0 - 0.25), "Softer", "Stronger")

    btn_top = y + 16
    btn_h = 21

    def draw_button(label: str, x: float, accent: bool = False) -> float:
        lw, lh = measure(wd, label, button_font)
        btn_w = lw / s + 28
        fill_c = default_btn if accent else button_bg
        stroke = default_btn if accent else button_stroke
        font_c = default_text if accent else button_text
        wd.rounded_rectangle(
            [*pt(x, btn_top), *pt(x + btn_w, btn_top + btn_h)],
            radius=int(5 * s),
            fill=fill_c,
            outline=stroke,
            width=max(1, s),
        )
        wd.text(
            pt(x + (btn_w - lw / s) / 2, btn_top + (btn_h - lh / s) / 2 - 0.5),
            label,
            font=button_font,
            fill=font_c,
        )
        return btn_w

    if tip_jar:
        tip_w = draw_button("Tip Jar", margin, accent=False)
        draw_button("Reset", margin + tip_w + 12, accent=False)
    else:
        draw_button("Reset", margin, accent=False)
    # Preview is the default (right, accent)
    plw, _ = measure(wd, "Preview", button_font)
    preview_w = plw / s + 28
    draw_button("Preview", cw - margin - preview_w, accent=True)

    rgba.paste(win, (pad, pad), win)
    return rgba.convert("RGB")


def save_style(desktop: Image.Image, thickness: float, path: Path) -> None:
    scale = 2
    glow = rp.draw_style(
        desktop.size,
        rp.BUILTIN_CORNER_RADIUS,
        scale,
        0.55,
        "pilotLine",
        thickness=thickness,
    )
    frame = Image.alpha_composite(desktop, glow)
    pill = rp.draw_pill(scale)
    m = rp.pill_metrics(rp.DESIGN_FONT_SIZE)
    top = int((rp.MENU_BAR_HEIGHT + m["top_gap"]) * scale)
    x = (frame.width - pill.width) // 2
    y = top - int(m["halo_extent"] * scale)
    frame.alpha_composite(pill, (x, y))
    out = frame.convert("RGB").resize((rp.DESIGN_W, rp.DESIGN_H), Image.Resampling.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path, "PNG", optimize=True)
    print(f"wrote {path} {out.size} thickness={thickness}")


def main() -> None:
    review = ROOT / "review"
    review.mkdir(parents=True, exist_ok=True)

    light = render_settings(dark=False, selected_style=0)
    light.save(review / "settings-v3-light.png", "PNG", optimize=True)
    print(f"wrote {review / 'settings-v3-light.png'} {light.size}")

    dark = render_settings(dark=True, selected_style=0)
    dark.save(review / "settings-v3-dark.png", "PNG", optimize=True)
    print(f"wrote {review / 'settings-v3-dark.png'} {dark.size}")

    pilot = render_settings(dark=False, selected_style=1, thickness_pt=3)
    pilot.save(review / "settings-v3-pilotline.png", "PNG", optimize=True)
    print(f"wrote {review / 'settings-v3-pilotline.png'} {pilot.size}")

    desktop = rp.load_desktop(2)
    save_style(desktop, 3, review / "style-pilot-line-v2.png")
    save_style(desktop, 8, review / "style-pilot-line-v2-thick.png")

    v4_light = render_settings(dark=False, selected_style=0, tip_jar=True)
    v4_light.save(review / "settings-v4-light.png", "PNG", optimize=True)
    print(f"wrote {review / 'settings-v4-light.png'} {v4_light.size}")

    v4_dark = render_settings(dark=True, selected_style=0, tip_jar=True)
    v4_dark.save(review / "settings-v4-dark.png", "PNG", optimize=True)
    print(f"wrote {review / 'settings-v4-dark.png'} {v4_dark.size}")


if __name__ == "__main__":
    main()
