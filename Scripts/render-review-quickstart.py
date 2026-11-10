#!/usr/bin/env python3
"""Offscreen Quick Start walkthrough pages, light and dark."""

from __future__ import annotations

import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from ember_happy import draw_happy_ember

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "review"

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

INSTRUCTION = (
    "Before you control my Mac, run `~/bin/pilotlight on`. During long work, run "
    "`~/bin/pilotlight ping` at least every 15 minutes. When you're done, run "
    "`~/bin/pilotlight off`, even if something failed. For a single command, you "
    "can wrap it instead: `~/bin/pilotlight run -- <command>`."
)

COMMANDS = [
    "~/bin/pilotlight on        Show the border",
    "~/bin/pilotlight status    on, off or stale",
    "~/bin/pilotlight ping      Keep it alive during long work",
    "~/bin/pilotlight off       Hide it, even after a failure",
    "~/bin/pilotlight run --    Run a command, always turn it off",
]

WELCOME_TITLE = "See when your Mac is busy with a bot."
WELCOME_BODY = (
    "PilotLight draws a soft glow around your screen, plus a pill that reads "
    "“Grok is working”, while an agent is using your Mac. Clicks, scrolling "
    "and typing pass straight through it."
)
HOW_BODY = (
    "The border shows while a bot is working on your Mac. If the flag at "
    "~/.grok-working isn’t touched for 20 minutes, PilotLight hides the border "
    "so a crashed agent can’t leave it stuck. Ping at least every 15 minutes "
    "on long jobs."
)
TELL_INTRO = (
    "PilotLight doesn’t detect agents on its own. Paste this into Grok, or any "
    "agent that can run commands on your Mac:"
)
TRY_HINT = (
    "The test preview lasts 5 seconds and doesn’t leave the flag behind. "
    "You can also use the command line:"
)
YOURS_BODY = (
    "Style, color and intensity live in Settings. Pick a glow style, a color, "
    "and how strong it looks."
)
THANKS_TITLE = "Thanks for trying PilotLight!"
THANKS_BODY = "It's free, and it's made by bashframes. Tips help keep it going."


def font(name: str, size: float) -> ImageFont.FreeTypeFont:
    path = FONT_DIR / name
    if path.is_file():
        return ImageFont.truetype(str(path), size=size)
    return ImageFont.truetype(str(FONT_DIR / "SF-Pro-Text-Regular.otf"), size=size)


def load(weight: str, size: float, mono: bool = False) -> ImageFont.FreeTypeFont:
    if mono:
        candidates = [
            FONT_DIR / "SF-Mono-Regular.otf",
            Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
        ]
        for path in candidates:
            if path.is_file():
                return ImageFont.truetype(str(path), size=size)
    mapping = {
        "regular": "SF-Pro-Text-Regular.otf",
        "medium": "SF-Pro-Text-Medium.otf",
        "semibold": "SF-Pro-Text-Semibold.otf",
        "bold": "SF-Pro-Text-Bold.otf",
        "bold-display": "SF-Pro-Display-Bold.otf",
    }
    name = mapping.get(weight, mapping["regular"])
    path = FONT_DIR / name
    if path.is_file():
        return font(name, size)
    return font("SF-Pro-Text-Regular.otf", size)


def measure(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont) -> tuple[float, float]:
    bbox = draw.textbbox((0, 0), text, font=fnt)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont, width: float) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for word in words:
        trial = word if not cur else f"{cur} {word}"
        if measure(draw, trial, fnt)[0] <= width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def palette(dark: bool) -> dict:
    if dark:
        return dict(
            bg=(45, 45, 48),
            title_bg=(53, 53, 56),
            text=(235, 235, 237),
            secondary=(152, 152, 157),
            hairline=(70, 70, 74),
            box=(56, 56, 59),
            box_stroke=(80, 80, 84),
            button_bg=(90, 90, 94),
            button_text=(235, 235, 237),
            button_stroke=(110, 110, 116),
            default_btn=(10, 132, 255),
            default_text=(255, 255, 255),
            fill=(10, 132, 255),
            ring=(235, 235, 237),
            white_edge=(160, 160, 165),
            shadow=(0, 0, 0, 170),
            page=(28, 28, 30),
            dot=(110, 110, 115),
            recessed=(70, 70, 74),
        )
    return dict(
        bg=(236, 236, 236),
        title_bg=(242, 242, 242),
        text=(29, 29, 31),
        secondary=(110, 110, 115),
        hairline=(210, 210, 212),
        box=(255, 255, 255),
        box_stroke=(200, 200, 204),
        button_bg=(255, 255, 255),
        button_text=(29, 29, 31),
        button_stroke=(200, 200, 204),
        default_btn=(0, 122, 255),
        default_text=(255, 255, 255),
        fill=(0, 122, 255),
        ring=(29, 29, 31),
        white_edge=(180, 180, 185),
        shadow=(0, 0, 0, 80),
        page=(230, 230, 232),
        dot=(180, 180, 185),
        recessed=(228, 228, 230),
    )


def rounded_button(draw, box, fill, stroke, radius, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=stroke, width=width)


def text_button(draw, cx, cy, label, fnt, fill, text_color, stroke, scale, default=False, min_w=None):
    tw, th = measure(draw, label, fnt)
    pad_x = int(12 * scale)
    pad_y = int(4 * scale)
    w = max(int(tw + pad_x * 2), int((min_w or 0) * scale))
    h = int(th + pad_y * 2)
    x0 = int(cx)
    y0 = int(cy - h / 2)
    r = int(6 * scale)
    if default:
        rounded_button(draw, [x0, y0, x0 + w, y0 + h], fill, fill, r)
    else:
        rounded_button(draw, [x0, y0, x0 + w, y0 + h], fill, stroke, r)
    draw.text((x0 + (w - tw) / 2, y0 + (h - th) / 2 - 0.5 * scale), label, font=fnt, fill=text_color)
    return w, h


def draw_chrome(win, pal, scale, title, title_h, w, h):
    wd = ImageDraw.Draw(win)
    wd.rounded_rectangle([0, 0, w - 1, h - 1], radius=10 * scale, fill=pal["bg"])
    title_img = Image.new("RGBA", (w, title_h + 12 * scale), pal["title_bg"] + (255,))
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
    wd.line([(0, title_h - 1), (w, title_h - 1)], fill=pal["hairline"], width=max(1, scale // 2))

    traffic = ((255, 95, 86), (255, 189, 46), (39, 201, 63))
    r = int(6 * scale)
    cx = int(16 * scale)
    cy = title_h // 2
    wd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=traffic[0])
    gap = int(8 * scale)
    bg = pal["bg"]
    for i, color in enumerate(traffic[1:], start=1):
        x = cx + i * (2 * r + gap)
        faded = tuple(int(c * 0.45 + (bg[j] * 0.55)) for j, c in enumerate(color))
        wd.ellipse([x - r, cy - r, x + r, cy + r], fill=faded)

    title_font = load("semibold", 13 * scale)
    tw, th = measure(wd, title, title_font)
    wd.text(((w - tw) / 2, (title_h - th) / 2 - scale), title, font=title_font, fill=pal["text"])
    return wd


def draw_glow_demo(size: tuple[int, int], scale: int) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    inset = int(10 * scale)
    screen = [inset, inset, w - inset - 1, h - inset - 1]
    radius = int(8 * scale)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rounded_rectangle(screen, radius=radius, outline=(255, 214, 10, 160), width=int(3 * scale))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=int(5 * scale)))
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(screen, radius=radius, fill=(46, 41, 36, 255))
    inner = [screen[0] + 3 * scale, screen[1] + 3 * scale, screen[2] - 3 * scale, screen[3] - 3 * scale]
    d.rounded_rectangle(inner, radius=int(6 * scale), outline=(255, 214, 10, 180), width=max(1, int(1.5 * scale)))
    # Mini working pill — gold rim, Ember, and a text sliver.
    pw, ph = int(88 * scale), int(16 * scale)
    px = (w - pw) // 2
    py = screen[1] + int(8 * scale)
    d.rounded_rectangle([px, py, px + pw, py + ph], radius=ph // 2, fill=(31, 20, 10, 242))
    d.rounded_rectangle([px, py, px + pw, py + ph], radius=ph // 2, outline=(255, 214, 10, 180), width=max(1, scale))
    er = int(5 * scale)
    ex = px + int(5 * scale) + er
    ey = py + ph // 2
    d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(226, 92, 58, 255))
    bar_x = ex + er + int(3 * scale)
    bar_w = pw - (bar_x - px) - int(8 * scale)
    bar_h = int(4 * scale)
    d.rounded_rectangle(
        [bar_x, ey - bar_h // 2, bar_x + bar_w, ey + bar_h // 2],
        radius=int(2 * scale),
        fill=(255, 248, 231, 235),
    )
    return img


def render_page(index: int, dark: bool, scale: int = 3) -> Image.Image:
    pal = palette(dark)
    cw, ch, title_h_pt = 460, 380, 28
    w, content_h, title_h = cw * scale, ch * scale, title_h_pt * scale
    h = title_h + content_h
    footer_h = 52 * scale
    dots_h = 16 * scale
    dots_gap = 10 * scale
    page_bottom = title_h + content_h - footer_h - dots_gap - dots_h - 4 * scale
    page_top = title_h

    pad = 48
    canvas = Image.new("RGB", (w + pad * 2, h + pad * 2), pal["page"])
    rgba = canvas.convert("RGBA")
    sh = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle(
        [pad, pad + 6, pad + w, pad + h + 8],
        radius=12 * scale // 2 + 2,
        fill=pal["shadow"],
    )
    sh = sh.filter(ImageFilter.GaussianBlur(radius=10))
    rgba = Image.alpha_composite(rgba, sh)

    win = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    wd = draw_chrome(win, pal, scale, "PilotLight Quick Start", title_h, w, h)

    heading = load("bold-display", 20 * scale)
    if FONT_DIR.joinpath("SF-Pro-Display-Bold.otf").is_file() is False:
        heading = load("bold", 20 * scale)
    body_f = load("regular", 13 * scale)
    small_f = load("regular", 12 * scale)
    hint_f = load("regular", 12.5 * scale)
    mono_f = load("regular", 10.5 * scale, mono=True)
    button_f = load("regular", 13 * scale)
    tip_f = load("regular", 11 * scale)
    title_btn = load("regular", 13 * scale)

    def text_block(x, y, text, fnt, color, width, align="left", leading=1.28):
        lines = wrap(wd, text, fnt, width)
        _, th = measure(wd, "Ag", fnt)
        line_h = th * leading
        for i, line in enumerate(lines):
            tw, _ = measure(wd, line, fnt)
            lx = x if align == "left" else x + (width - tw) / 2
            wd.text((lx, y + i * line_h), line, font=fnt, fill=color)
        return len(lines) * line_h

    # Footer
    fy0 = title_h + content_h - footer_h
    wd.line([(0, fy0), (w, fy0)], fill=pal["hairline"], width=max(1, scale // 2))
    back_label = "Back"
    next_label = "Done" if index == 5 else "Next"
    # Back on the left
    bw, bh = text_button(
        wd,
        20 * scale,
        fy0 + footer_h / 2 + 1 * scale,
        back_label,
        button_f,
        pal["button_bg"],
        pal["button_text"] if index > 0 else tuple(int(a * 0.45 + b * 0.55) for a, b in zip(pal["button_text"], pal["bg"])),
        pal["button_stroke"],
        scale,
        default=False,
        min_w=72,
    )
    if index == 0:
        # fade the back button by overlaying a translucent bg
        overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        # already used faded text; also drop fill contrast by painting a veil
        x0, y0 = 20 * scale, int(fy0 + footer_h / 2 + 1 * scale - bh / 2)
        veil = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        vd = ImageDraw.Draw(veil)
        vd.rounded_rectangle([x0, y0, x0 + bw, y0 + bh], radius=int(6 * scale), fill=pal["bg"] + (90,))
        win.paste(Image.alpha_composite(win, veil))
        wd = ImageDraw.Draw(win)

    # Next / Done on the right, default (blue)
    tw, _ = measure(wd, next_label, button_f)
    nw = max(int(tw + 24 * scale), int(72 * scale))
    nh = int(measure(wd, "Ag", button_f)[1] + 8 * scale)
    nx = w - 20 * scale - nw
    ny = int(fy0 + footer_h / 2 + 1 * scale - nh / 2)
    rounded_button(wd, [nx, ny, nx + nw, ny + nh], pal["default_btn"], pal["default_btn"], int(6 * scale))
    ntw, nth = measure(wd, next_label, button_f)
    wd.text((nx + (nw - ntw) / 2, ny + (nh - nth) / 2 - 0.5 * scale), next_label, font=button_f, fill=pal["default_text"])

    # Dots
    diameter = int(7 * scale)
    spacing = int(10 * scale)
    count = 6
    total = count * diameter + (count - 1) * spacing
    dx = (w - total) // 2
    dy = fy0 - dots_gap - dots_h + (dots_h - diameter) // 2
    for i in range(count):
        x = dx + i * (diameter + spacing)
        color = pal["fill"] if i == index else pal["dot"]
        wd.ellipse([x, dy, x + diameter, y := dy + diameter], fill=color)

    def measure_block(text, fnt, width, leading):
        lines = wrap(wd, text, fnt, width)
        _, th = measure(wd, "Ag", fnt)
        return len(lines) * th * leading

    # Pages
    if index == 0:
        sides = 28 * scale
        inner_w = w - 2 * sides
        content_h_used = 80 * scale + 16 * scale + measure_block(WELCOME_TITLE, heading, inner_w, 1.18) + 12 * scale + measure_block(WELCOME_BODY, body_f, inner_w, 1.32)
        y = page_top + max(18 * scale, ((page_bottom - page_top) - content_h_used) / 2)
        ember = rp.draw_ember(int(80 * scale))
        ex = (w - ember.width) // 2
        win.paste(ember, (ex, int(y)), ember)
        y += 80 * scale + 16 * scale
        h1 = text_block(sides, y, WELCOME_TITLE, heading, pal["text"], inner_w, align="center", leading=1.18)
        y += h1 + 12 * scale
        text_block(sides, y, WELCOME_BODY, body_f, pal["text"], inner_w, align="center", leading=1.32)

    elif index == 1:
        sides = 28 * scale
        inner_w = w - 2 * sides
        content_h_used = 112 * scale + 16 * scale + measure_block("How it works", heading, inner_w, 1.18) + 12 * scale + measure_block(HOW_BODY, body_f, inner_w, 1.32)
        y = page_top + max(18 * scale, ((page_bottom - page_top) - content_h_used) / 2)
        demo = draw_glow_demo((int(220 * scale), int(112 * scale)), scale)
        win.paste(demo, ((w - demo.width) // 2, int(y)), demo)
        y += 112 * scale + 16 * scale
        h1 = text_block(sides, y, "How it works", heading, pal["text"], inner_w, align="center", leading=1.18)
        y += h1 + 12 * scale
        text_block(sides, y, HOW_BODY, body_f, pal["text"], inner_w, align="center", leading=1.32)

    elif index == 2:
        sides = 24 * scale
        y = page_top + 20 * scale
        h1 = text_block(sides, y, "Tell your bot", heading, pal["text"], w - 2 * sides, align="left", leading=1.18)
        y += h1 + 10 * scale
        h2 = text_block(sides, y, TELL_INTRO, body_f, pal["text"], w - 2 * sides, align="left", leading=1.32)
        y += h2 + 10 * scale
        # instruction box
        box_x0 = sides
        box_x1 = w - sides
        inner = 12 * scale
        # measure instruction
        lines = wrap(wd, INSTRUCTION, small_f, box_x1 - box_x0 - 2 * inner)
        _, th = measure(wd, "Ag", small_f)
        line_h = th * 1.32
        inst_h = len(lines) * line_h
        btn_h = int(measure(wd, "Ag", button_f)[1] + 8 * scale)
        box_y0 = y
        box_y1 = y + 10 * scale + inst_h + 8 * scale + btn_h + 10 * scale
        wd.rounded_rectangle(
            [box_x0, box_y0, box_x1, box_y1],
            radius=int(8 * scale),
            fill=pal["box"],
            outline=pal["box_stroke"],
            width=max(1, scale // 2 + 1),
        )
        iy = box_y0 + 10 * scale
        for i, line in enumerate(lines):
            wd.text((box_x0 + inner, iy + i * line_h), line, font=small_f, fill=pal["text"])
        text_button(
            wd,
            box_x0 + inner,
            box_y1 - 10 * scale - btn_h / 2,
            "Copy",
            button_f,
            pal["button_bg"],
            pal["button_text"],
            pal["button_stroke"],
            scale,
            min_w=64,
        )

    elif index == 3:
        sides = 24 * scale
        y = page_top + 18 * scale
        h1 = text_block(sides, y, "Try it", heading, pal["text"], w - 2 * sides, align="left", leading=1.18)
        y += h1 + 12 * scale
        # Show Test Border button
        tw, th = measure(wd, "Show Test Border", button_f)
        bw = int(tw + 24 * scale)
        bh = int(th + 8 * scale)
        rounded_button(
            wd,
            [sides, y, sides + bw, y + bh],
            pal["button_bg"],
            pal["button_stroke"],
            int(6 * scale),
        )
        wd.text((sides + (bw - tw) / 2, y + (bh - th) / 2 - 0.5 * scale), "Show Test Border", font=button_f, fill=pal["button_text"])
        y += bh + 10 * scale
        h2 = text_block(sides, y, TRY_HINT, hint_f, pal["text"], w - 2 * sides, align="left", leading=1.32)
        y += h2 + 10 * scale
        inner = 12 * scale
        line_h = measure(wd, "Ag", mono_f)[1] * 1.45
        box_h = 10 * scale + len(COMMANDS) * line_h + 10 * scale
        wd.rounded_rectangle(
            [sides, y, w - sides, y + box_h],
            radius=int(8 * scale),
            fill=pal["box"],
            outline=pal["box_stroke"],
            width=max(1, scale // 2 + 1),
        )
        for i, line in enumerate(COMMANDS):
            wd.text((sides + inner, y + 10 * scale + i * line_h), line, font=mono_f, fill=pal["text"])

    elif index == 4:
        sides = 24 * scale
        y = page_top + 22 * scale
        h1 = text_block(sides, y, "Make it yours", heading, pal["text"], w - 2 * sides, align="left", leading=1.18)
        y += h1 + 12 * scale
        h2 = text_block(sides, y, YOURS_BODY, body_f, pal["text"], w - 2 * sides, align="left", leading=1.32)
        y += h2 + 12 * scale
        # swatches, packed from the left like the window
        diameter = int(18 * scale)
        gap = 10 * scale
        x = sides + 3 * scale
        cy = y + diameter / 2 + 3 * scale
        for i, (_name, color) in enumerate(PRESETS):
            if i == 0:
                ring_r = diameter / 2 + 3 * scale
                wd.ellipse(
                    [x + diameter / 2 - ring_r, cy - ring_r, x + diameter / 2 + ring_r, cy + ring_r],
                    outline=pal["ring"],
                    width=max(1, int(1.5 * scale)),
                )
            wd.ellipse([x, cy - diameter / 2, x + diameter, cy + diameter / 2], fill=color)
            if i == len(PRESETS) - 1:
                wd.ellipse(
                    [x + 1, cy - diameter / 2 + 1, x + diameter - 1, cy + diameter / 2 - 1],
                    outline=pal["white_edge"],
                    width=max(1, scale // 2 + 1),
                )
            x += diameter + gap
        y += diameter + 6 * scale + 16 * scale
        tw, th = measure(wd, "Open Settings", button_f)
        bw = int(tw + 24 * scale)
        bh = int(th + 8 * scale)
        rounded_button(
            wd,
            [sides, y, sides + bw, y + bh],
            pal["button_bg"],
            pal["button_stroke"],
            int(6 * scale),
        )
        wd.text((sides + (bw - tw) / 2, y + (bh - th) / 2 - 0.5 * scale), "Open Settings", font=button_f, fill=pal["button_text"])

    elif index == 5:
        sides = 28 * scale
        inner_w = w - 2 * sides
        ember_sz = int(112 * scale)
        ember = draw_happy_ember(ember_sz, 0.3)
        content_h_used = (
            ember_sz
            + 16 * scale
            + measure_block(THANKS_TITLE, heading, inner_w, 1.18)
            + 12 * scale
            + measure_block(THANKS_BODY, body_f, inner_w, 1.32)
            + 16 * scale
            + int(measure(wd, "Ag", button_f)[1] + 8 * scale)
        )
        y = page_top + max(16 * scale, ((page_bottom - page_top) - content_h_used) / 2)
        win.paste(ember, ((w - ember.width) // 2, int(y)), ember)
        y += ember_sz + 16 * scale
        h1 = text_block(sides, y, THANKS_TITLE, heading, pal["text"], inner_w, align="center", leading=1.18)
        y += h1 + 12 * scale
        h2 = text_block(sides, y, THANKS_BODY, body_f, pal["text"], inner_w, align="center", leading=1.32)
        y += h2 + 16 * scale
        tw, th = measure(wd, "Tip Jar", button_f)
        bw = int(tw + 28 * scale)
        bh = int(th + 8 * scale)
        bx = (w - bw) // 2
        rounded_button(
            wd,
            [bx, y, bx + bw, y + bh],
            pal["button_bg"],
            pal["button_stroke"],
            int(6 * scale),
        )
        wd.text((bx + (bw - tw) / 2, y + (bh - th) / 2 - 0.5 * scale), "Tip Jar", font=button_f, fill=pal["button_text"])

    rgba.paste(win, (pad, pad), win)
    return rgba.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [
        ("quickstart-p1.png", 0, False),
        ("quickstart-p2.png", 1, False),
        ("quickstart-p3.png", 2, False),
        ("quickstart-p4.png", 3, False),
        ("quickstart-p5.png", 4, False),
        ("quickstart-p6-light.png", 5, False),
        ("quickstart-p6-v2.png", 5, False),
        ("quickstart-p1-dark.png", 0, True),
        ("quickstart-p3-dark.png", 2, True),
        ("quickstart-p6-dark.png", 5, True),
    ]
    for name, index, dark in jobs:
        img = render_page(index, dark)
        path = OUT / name
        img.save(path, "PNG")
        print(f"wrote {path} {img.size[0]}x{img.size[1]}")

    # Happy-hop frame strip
    times = [0.0, 0.15, 0.30, 0.58, 0.90, 1.50]
    labels = ["rest", "up", "hop", "blink", "settle", "hop"]
    s = 3
    size = 128 * s
    gap = 16 * s
    label_h = 22 * s
    spad = 20 * s
    n = len(times)
    sw = spad * 2 + n * size + (n - 1) * gap
    sh = spad * 2 + size + label_h
    strip = Image.new("RGB", (sw, sh), (245, 245, 247))
    sd = ImageDraw.Draw(strip)
    sfont = load("regular", 12 * s)
    for i, (tm, label) in enumerate(zip(times, labels)):
        ember = draw_happy_ember(size, tm)
        x = spad + i * (size + gap)
        strip.paste(ember, (x, spad), ember)
        tw, th = measure(sd, label, sfont)
        sd.text((x + (size - tw) / 2, spad + size + 4 * s), label, font=sfont, fill=(29, 29, 31))
    strip_path = OUT / "quickstart-p6-strip.png"
    strip.save(strip_path, "PNG")
    print(f"wrote {strip_path} {strip.size[0]}x{strip.size[1]}")


if __name__ == "__main__":
    main()
