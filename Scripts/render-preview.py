#!/usr/bin/env python3
"""Offscreen preview of PilotLight's glow overlay.

Uses the same inset-shadow approximation as Sources/PilotLight/Constants.swift
(GlowSpec) so this PNG is a faithful stand-in for the AppKit render. Saves
review/glow-v2.png at 1440x900, matching the approved mockup.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "review" / "glow-v2.png"
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from asset_paths import font_dir, grok_border_root

MOCKUP_HTML = grok_border_root() / "src" / "mockup.html"
APPROVED = grok_border_root() / "mockups" / "grok-border-glow-yellow.png"
EMBER_FILL = (0xE2, 0x5C, 0x3A, 255)
FONT_DIR = font_dir()

# Keep in sync with GlowSpec / GlowStyle in Constants.swift
BUILTIN_CORNER_RADIUS = 12.0
MAX_DISTANCE = 80.0
BAND_STEP = 2.0
# Approved pill measurements at 13.5 pt. Every length scales with the label size.
DESIGN_FONT_SIZE = 13.5
PILL_HEIGHT = 36
PILL_TOP_GAP = 11
PILL_ICON_SIZE = 26
MENU_BAR_HEIGHT = 25
MESSAGE = "Grok is working"
PILL_LEADING_PAD = 9
PILL_ICON_GAP = 9
PILL_TRAILING_PAD = 16
PILL_VERTICAL_PAD = 10
PILL_BORDER_WIDTH = 1
PILL_HIGHLIGHT_INSET = 14
PILL_HIGHLIGHT_HEIGHT = 1
PILL_HIGHLIGHT_DROP = 1.25
PILL_HALO_RADIUS = 14
PILL_SHADOW_RADIUS = 12
PILL_SHADOW_OFFSET = 3
PILL_OPTICAL_SHIFT = 0.5
LINE_INSET = 6.0
LINE_THICKNESS = 3.0

# Core, mid, outer — same ramps as GlowPreset.ramp
YELLOW_RAMP = (0xFFD60A, 0xFFB800, 0xF5A400)
STYLES = ("softGlow", "pilotLine", "lamp", "cornerLamps")
STYLE_FILENAMES = {
    "softGlow": "style-soft-glow.png",
    "pilotLine": "style-pilot-line.png",
    "lamp": "style-lamp.png",
    "cornerLamps": "style-corner-lamps.png",
}

DESIGN_W, DESIGN_H = 1440, 900


def pill_metrics(font_pt: float) -> dict[str, float]:
    """Swift PillMetrics: every length is font_pt / 13.5 times the design size."""
    k = max(font_pt, 1.0) / DESIGN_FONT_SIZE
    halo = PILL_HALO_RADIUS * k
    shadow = PILL_SHADOW_RADIUS * k
    offset = PILL_SHADOW_OFFSET * k
    return {
        "k": k,
        "height": PILL_HEIGHT * k,
        "icon": PILL_ICON_SIZE * k,
        "leading": PILL_LEADING_PAD * k,
        "gap": PILL_ICON_GAP * k,
        "trailing": PILL_TRAILING_PAD * k,
        "vertical": PILL_VERTICAL_PAD * k,
        "top_gap": PILL_TOP_GAP * k,
        "border": PILL_BORDER_WIDTH * k,
        "highlight_inset": PILL_HIGHLIGHT_INSET * k,
        "highlight_height": PILL_HIGHLIGHT_HEIGHT * k,
        "highlight_drop": PILL_HIGHLIGHT_DROP * k,
        "halo": halo,
        "shadow": shadow,
        "shadow_offset": offset,
        "optical": PILL_OPTICAL_SHIFT * k,
        "halo_extent": math.ceil(max(halo, shadow + offset) * 2),
    }


def shadow_alpha(distance: float, spread: float, blur: float, strength: float) -> float:
    if distance <= spread:
        return strength
    if distance >= spread + blur:
        return 0.0
    t = (distance - spread) / blur
    smooth = t * t * (3 - 2 * t)
    return strength * (1 - smooth)


def overlay(dst: list[float], hex_color: int, source_alpha: float) -> None:
    if source_alpha <= 0:
        return
    sr = ((hex_color >> 16) & 0xFF) / 255
    sg = ((hex_color >> 8) & 0xFF) / 255
    sb = (hex_color & 0xFF) / 255
    r, g, b, a = dst
    out_a = source_alpha + a * (1 - source_alpha)
    if out_a <= 0:
        return
    dst[0] = (sr * source_alpha + r * a * (1 - source_alpha)) / out_a
    dst[1] = (sg * source_alpha + g * a * (1 - source_alpha)) / out_a
    dst[2] = (sb * source_alpha + b * a * (1 - source_alpha)) / out_a
    dst[3] = out_a


def color_at(
    distance: float,
    intensity: float = 1.0,
    ramp: tuple[int, int, int] = YELLOW_RAMP,
) -> tuple[int, int, int, int]:
    dst = [0.0, 0.0, 0.0, 0.0]
    overlay(dst, ramp[2], shadow_alpha(distance, 16, 56, 0.28))
    overlay(dst, ramp[1], shadow_alpha(distance, 9, 30, 0.55))
    overlay(dst, ramp[0], shadow_alpha(distance, 3, 12, 0.88))
    overlay(dst, ramp[1], shadow_alpha(distance, 0, 6, 0.22))
    alpha = min(1.0, dst[3] * intensity)
    return (
        int(round(dst[0] * 255)),
        int(round(dst[1] * 255)),
        int(round(dst[2] * 255)),
        int(round(alpha * 255)),
    )


def make_bands(
    intensity: float = 1.0,
    ramp: tuple[int, int, int] = YELLOW_RAMP,
    max_distance: float = MAX_DISTANCE,
) -> list[tuple[float, float, tuple[int, int, int, int]]]:
    bands = []
    distance = 0.0
    while distance < max_distance:
        inner = distance + BAND_STEP
        rgba = color_at(distance + BAND_STEP / 2, intensity, ramp)
        if rgba[3] / 255 >= 0.008:
            bands.append((distance, inner, rgba))
        distance = inner
    return bands


def contour_radius(base_px: float, inset_px: float, rect_w: float, rect_h: float) -> float:
    grown = max(0.0, base_px + inset_px * 1.25)
    return min(grown, min(rect_w, rect_h) / 2)


def hex_rgb(value: int) -> tuple[float, float, float]:
    return ((value >> 16) & 0xFF) / 255, ((value >> 8) & 0xFF) / 255, (value & 0xFF) / 255


def draw_glow(
    size: tuple[int, int],
    radius: float,
    scale: float,
    intensity: float = 1.0,
    ramp: tuple[int, int, int] = YELLOW_RAMP,
    max_distance: float = MAX_DISTANCE,
) -> Image.Image:
    """Draw the rounded soft-glow bands at `scale` device pixels per point."""
    w, h = size
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    max_inset = min(w, h) / 2
    base_px = radius * scale
    for outer, inner, rgba in make_bands(intensity, ramp, max_distance):
        outer_px = min(outer * scale, max_inset)
        inner_px = min(inner * scale, max_inset)
        if inner_px <= outer_px:
            continue
        outer_rect = [outer_px, outer_px, w - 1 - outer_px, h - 1 - outer_px]
        inner_rect = [inner_px, inner_px, w - 1 - inner_px, h - 1 - inner_px]
        ow = outer_rect[2] - outer_rect[0]
        oh = outer_rect[3] - outer_rect[1]
        if ow <= 0 or oh <= 0:
            continue
        outer_r = contour_radius(base_px, outer_px, ow, oh)
        mask = Image.new("L", (w, h), 0)
        md = ImageDraw.Draw(mask)
        md.rounded_rectangle(outer_rect, radius=outer_r, fill=255)
        iw = inner_rect[2] - inner_rect[0]
        ih = inner_rect[3] - inner_rect[1]
        if iw > 0 and ih > 0:
            inner_r = contour_radius(base_px, inner_px, iw, ih)
            md.rounded_rectangle(inner_rect, radius=inner_r, fill=0)
        layer = Image.new("RGBA", (w, h), rgba)
        layer.putalpha(mask.point(lambda p, a=rgba[3]: p * a // 255))
        glow = Image.alpha_composite(glow, layer)
    return glow


def draw_pilot_line(
    size: tuple[int, int],
    radius: float,
    scale: float,
    intensity: float = 1.0,
    ramp: tuple[int, int, int] = YELLOW_RAMP,
    thickness: float = LINE_THICKNESS,
    inset: float = LINE_INSET,
) -> Image.Image:
    """A single solid line, inset from the bezel, with only a slight softness."""
    import numpy as np
    from PIL import ImageFilter

    w, h = size
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    center_inset = (inset + thickness / 2) * scale
    rect = [center_inset, center_inset, w - 1 - center_inset, h - 1 - center_inset]
    rw, rh = rect[2] - rect[0], rect[3] - rect[1]
    if rw <= 0 or rh <= 0:
        return canvas
    line_r = min(max(radius * scale - center_inset, 0), rw / 2, rh / 2)
    r, g, b = hex_rgb(ramp[0])
    alpha = min(1.0, max(0.0, intensity))
    rgb = (int(r * 255), int(g * 255), int(b * 255), int(alpha * 255))
    width_px = max(1, int(round(thickness * scale)))
    # Softness first, then the solid stroke on top.
    soft = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(soft).rounded_rectangle(
        rect,
        radius=line_r,
        outline=(int(r * 255), int(g * 255), int(b * 255), int(0.28 * alpha * 255)),
        width=width_px,
    )
    soft = soft.filter(ImageFilter.GaussianBlur(radius=max(0.6, 1.1 * scale / 2)))
    stroke = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(stroke).rounded_rectangle(
        rect,
        radius=line_r,
        outline=rgb,
        width=width_px,
    )
    return Image.alpha_composite(Image.alpha_composite(canvas, soft), stroke)



def draw_lamp(
    size: tuple[int, int],
    scale: float,
    intensity: float = 1.0,
    ramp: tuple[int, int, int] = YELLOW_RAMP,
) -> Image.Image:
    import numpy as np

    w, h = size
    height = max(1, int(round(150 * scale)))
    height = min(height, h)
    core = hex_rgb(ramp[0])
    mid = hex_rgb(ramp[1])
    stops_t = np.array([0.0, 0.45, 1.0], dtype=np.float32)
    stops_c = np.array(
        [
            [*core, min(1.0, 0.55 * intensity)],
            [*mid, min(1.0, 0.18 * intensity)],
            [*mid, 0.0],
        ],
        dtype=np.float32,
    )
    ys = np.linspace(0.0, 1.0, height, dtype=np.float32)
    col = np.vstack([np.interp(ys, stops_t, stops_c[:, i]) for i in range(4)]).T
    fade = np.interp(np.linspace(0.0, 1.0, w, dtype=np.float32), [0.0, 0.2, 0.8, 1.0], [0.0, 1.0, 1.0, 0.0])
    lamp = np.zeros((height, w, 4), dtype=np.float32)
    lamp[..., :3] = col[:, None, :3]
    lamp[..., 3] = col[:, None, 3] * fade[None, :]
    canvas = np.zeros((h, w, 4), dtype=np.float32)
    canvas[:height] = lamp
    return Image.fromarray(np.clip(canvas * 255, 0, 255).astype(np.uint8), "RGBA")


def draw_corner_lamps(
    size: tuple[int, int],
    scale: float,
    intensity: float = 1.0,
    ramp: tuple[int, int, int] = YELLOW_RAMP,
) -> Image.Image:
    import numpy as np

    w, h = size
    radius = 170 * scale
    rgb = np.array(hex_rgb(ramp[0]), dtype=np.float32)
    a0 = min(1.0, 0.62 * intensity)
    yy, xx = np.ogrid[:h, :w]
    acc = np.zeros((h, w, 4), dtype=np.float32)
    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        src_a = a0 * np.clip(1.0 - dist / radius, 0.0, 1.0)
        dst_a = acc[..., 3]
        out_a = src_a + dst_a * (1.0 - src_a)
        with np.errstate(invalid="ignore", divide="ignore"):
            for i in range(3):
                acc[..., i] = np.where(
                    out_a > 0,
                    (rgb[i] * src_a + acc[..., i] * dst_a * (1.0 - src_a)) / out_a,
                    0.0,
                )
        acc[..., 3] = out_a
    return Image.fromarray(np.clip(acc * 255, 0, 255).astype(np.uint8), "RGBA")


def draw_style(
    size: tuple[int, int],
    radius: float,
    scale: float,
    intensity: float = 1.0,
    style: str = "softGlow",
    ramp: tuple[int, int, int] = YELLOW_RAMP,
    thickness: float = LINE_THICKNESS,
) -> Image.Image:
    if style == "pilotLine":
        return draw_pilot_line(size, radius, scale, intensity, ramp, thickness)
    if style == "lamp":
        return draw_lamp(size, scale, intensity, ramp)
    if style == "cornerLamps":
        return draw_corner_lamps(size, scale, intensity, ramp)
    return draw_glow(size, radius, scale, intensity, ramp)


def load_desktop(scale: int) -> Image.Image:
    """Desktop scene without the old overlay, at device pixels."""
    target = (DESIGN_W * scale, DESIGN_H * scale)
    try:
        from playwright.sync_api import sync_playwright

        if MOCKUP_HTML.is_file():
            with sync_playwright() as p:
                browser = p.chromium.launch(
                    executable_path="/usr/bin/google-chrome-stable",
                    args=["--no-sandbox", "--disable-dev-shm-usage"],
                )
                context = browser.new_context(
                    viewport={"width": DESIGN_W, "height": DESIGN_H},
                    device_scale_factor=scale,
                )
                page = context.new_page()
                page.goto(f"file://{MOCKUP_HTML}?v=glow-yellow", wait_until="networkidle")
                page.evaluate(
                    """() => {
                        document.querySelectorAll('.glow-ring, .glow-bloom, .pill')
                            .forEach(el => el.remove());
                    }"""
                )
                page.evaluate("document.fonts.ready")
                page.wait_for_timeout(200)
                raw_path = ROOT / "review" / ".desktop-raw.png"
                raw_path.parent.mkdir(parents=True, exist_ok=True)
                page.screenshot(path=str(raw_path), type="png", omit_background=False)
                browser.close()
            img = Image.open(raw_path).convert("RGBA")
            raw_path.unlink(missing_ok=True)
            if img.size != target:
                img = img.resize(target, Image.Resampling.LANCZOS)
            print(f"desktop from mockup.html {img.size}")
            return img
    except Exception as exc:
        print(f"playwright desktop failed: {exc!r}")

    if APPROVED.is_file():
        img = Image.open(APPROVED).convert("RGBA")
        if img.size != target:
            img = img.resize(target, Image.Resampling.LANCZOS)
        # Heal the existing glow by stretching interior pixels outward so the
        # new overlay is not composited on top of the old one.
        print(f"desktop healed from approved mockup {img.size}")
        return heal_edges(img, margin=int(90 * scale))

    raise SystemExit("No desktop background available")


def heal_edges(img: Image.Image, margin: int) -> Image.Image:
    w, h = img.size
    out = img.copy()
    px = out.load()
    src = img.load()
    for y in range(h):
        for x in range(w):
            dx = min(x, w - 1 - x)
            dy = min(y, h - 1 - y)
            d = min(dx, dy)
            if d >= margin:
                continue
            if dx < dy:
                nx = margin if x < margin else w - 1 - margin
                px[x, y] = src[nx, y]
            else:
                ny = margin if y < margin else h - 1 - margin
                px[x, y] = src[x, ny]
    return out


def load_font(size: float) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        FONT_DIR / "SF-Pro-Text-Medium.otf",
        FONT_DIR / "SF-Pro-Text-Regular.otf",
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ]
    for path in candidates:
        if path.is_file():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()



def draw_ember(size: int) -> Image.Image:
    """Vector Ember at rest, 64×64 viewBox, same ellipses as PillBotView."""
    over = max(size * 4, 64)
    img = Image.new("RGBA", (over, over), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = over / 64.0

    def ellipse(cx, cy, rx, ry, fill):
        box = ((cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s)
        draw.ellipse(box, fill=fill)

    for cx, cy, rx, ry in (
        (20.0, 34.5, 16.2, 16.2),
        (44.0, 34.5, 16.2, 16.2),
        (32.0, 21.0, 15.2, 15.2),
        (32.0, 38.5, 21.5, 15.5),
    ):
        ellipse(cx, cy, rx, ry, EMBER_FILL)

    # Eyes: 7.4×15.8 capsules, tilted 10° clockwise around each centre.
    def capsule(cx, cy):
        layer = Image.new("RGBA", (over, over), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        box = ((cx - 3.7) * s, (cy - 7.9) * s, (cx + 3.7) * s, (cy + 7.9) * s)
        ld.rounded_rectangle(box, radius=3.7 * s, fill=(255, 255, 255, 255))
        # rotate around eye centre
        # PIL rotate is counter-clockwise, so 10° clockwise is -10.
        return layer.rotate(-10, resample=Image.Resampling.BICUBIC, center=(cx * s, cy * s))

    for cx, cy in ((25.0, 33.0), (39.0, 33.0)):
        img = Image.alpha_composite(img, capsule(cx, cy))

    return img.resize((size, size), Image.Resampling.LANCZOS)


def draw_pill(scale: float, font_pt: float = 13.5, message: str = MESSAGE) -> Image.Image:
    font = load_font(font_pt * scale)
    m = pill_metrics(font_pt)
    probe = ImageDraw.Draw(Image.new("RGBA", (4, 4)))
    bbox = probe.textbbox((0, 0), message, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    icon = max(1, int(round(m["icon"] * scale)))
    content_h = max(m["icon"], text_h / scale)
    height = int(round(max(m["height"], content_h + m["vertical"]) * scale))
    width = int(round((m["leading"] + m["icon"] + m["gap"]) * scale + math.ceil(text_w) + m["trailing"] * scale))
    pad = int(round(m["halo_extent"] * scale))
    canvas = Image.new("RGBA", (width + pad * 2, height + pad * 2), (0, 0, 0, 0))

    tr, tg, tb = hex_rgb(YELLOW_RAMP[0])
    body = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    for y in range(height):
        tfrac = y / max(1, height - 1)
        top = (0.10 + tr * 0.08, 0.07 + tg * 0.06, 0.03 + tb * 0.05, 0.92)
        bot = (0.06 + tr * 0.05, 0.04 + tg * 0.04, 0.02 + tb * 0.03, 0.94)
        r = int(255 * (top[0] * (1 - tfrac) + bot[0] * tfrac))
        g = int(255 * (top[1] * (1 - tfrac) + bot[1] * tfrac))
        b = int(255 * (top[2] * (1 - tfrac) + bot[2] * tfrac))
        a = int(255 * (top[3] * (1 - tfrac) + bot[3] * tfrac))
        bd.line([(0, y), (width, y)], fill=(r, g, b, a))
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width - 1, height - 1], radius=height / 2, fill=255)
    body.putalpha(mask)

    halo = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hx0, hy0 = pad, pad
    hd.rounded_rectangle(
        [hx0, hy0, hx0 + width - 1, hy0 + height - 1],
        radius=height / 2,
        fill=(int(tr * 255), int(tg * 255), int(tb * 255), int(0.7 * 0.55 * 255)),
    )
    halo = halo.filter(ImageFilter.GaussianBlur(radius=max(1, m["halo"] * scale / 2)))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    off = int(round(m["shadow_offset"] * scale))
    sd.rounded_rectangle(
        [hx0, hy0 + off, hx0 + width - 1, hy0 + height - 1 + off],
        radius=height / 2,
        fill=(int(tr * 0.45 * 255), int(tg * 0.28 * 255), int(tb * 0.10 * 255), int(0.42 * 255)),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(1, m["shadow"] * scale / 2)))

    canvas = Image.alpha_composite(canvas, shadow)
    canvas = Image.alpha_composite(canvas, halo)
    canvas.paste(body, (pad, pad), body)

    cd = ImageDraw.Draw(canvas)
    cd.rounded_rectangle(
        [pad, pad, pad + width - 1, pad + height - 1],
        radius=height / 2,
        outline=(int(tr * 255), int(tg * 255), int(tb * 255), int(0.58 * 255)),
        width=max(1, int(round(m["border"] * scale))),
    )
    hi_inset = int(round(m["highlight_inset"] * scale))
    hi_h = max(1, int(round(m["highlight_height"] * scale)))
    hi_y = pad + max(1, int(round((m["highlight_drop"] - m["highlight_height"]) * scale)))
    cd.rounded_rectangle(
        [pad + hi_inset, hi_y, pad + width - hi_inset, hi_y + hi_h],
        radius=max(1, hi_h / 2),
        fill=(
            int(min(1, tr + 0.15) * 255),
            int(min(1, tg + 0.12) * 255),
            int(min(1, tb + 0.08) * 255),
            int(0.22 * 255),
        ),
    )

    ember = draw_ember(icon)
    rx = pad + int(round(m["leading"] * scale))
    ry = pad + (height - icon) // 2
    canvas.paste(ember, (rx, ry), ember)

    text_x = pad + int(round((m["leading"] + m["icon"] + m["gap"]) * scale))
    text_y = pad + (height - text_h) / 2 - bbox[1] - m["optical"] * scale
    cd.text((text_x, text_y), message, font=font, fill=(255, 248, 231, 255))
    return canvas


def compose(intensity: float = 1.0, style: str = "softGlow", thickness: float = LINE_THICKNESS) -> Image.Image:
    scale = 2
    desktop = load_desktop(scale)
    glow = draw_style(desktop.size, BUILTIN_CORNER_RADIUS, scale, intensity, style, thickness=thickness)
    frame = Image.alpha_composite(desktop, glow)

    pill = draw_pill(scale)
    m = pill_metrics(DESIGN_FONT_SIZE)
    top = int((MENU_BAR_HEIGHT + m["top_gap"]) * scale)
    x = (frame.width - pill.width) // 2
    y = top - int(m["halo_extent"] * scale)  # pill image includes halo padding
    frame.alpha_composite(pill, (x, y))

    out = frame.convert("RGB").resize((DESIGN_W, DESIGN_H), Image.Resampling.LANCZOS)
    return out


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--intensity", type=float, default=0.55)
    parser.add_argument("--output", type=Path, default=ROOT / "review" / "glow-softer.png")
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image = compose(intensity=args.intensity)
    image.save(args.output, "PNG", optimize=True)
    print(f"wrote {args.output} {image.size} intensity={args.intensity}")


if __name__ == "__main__":
    main()
