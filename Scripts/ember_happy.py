#!/usr/bin/env python3
"""Happy hop for Ember. Brand had no separate waving or happy pose."""

from __future__ import annotations

import math
import re
from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from asset_paths import ember_svg

EMBER_SVG = ember_svg()
HAPPY_LOOP = 2.4
HAPPY_CLOSED = 0.12


def _happy_blink(t: float) -> float:
    def window(start: float) -> float | None:
        close_end, hold_end, open_end = start + 0.06, start + 0.10, start + 0.16
        if t < start or t >= open_end:
            return None
        if t < close_end:
            u = (t - start) / (close_end - start)
            eased = 0.5 - 0.5 * math.cos(math.pi * u)
            return 1 + (HAPPY_CLOSED - 1) * eased
        if t < hold_end:
            return HAPPY_CLOSED
        u = (t - hold_end) / (open_end - hold_end)
        eased = 0.5 - 0.5 * math.cos(math.pi * u)
        return HAPPY_CLOSED + (1 - HAPPY_CLOSED) * eased

    return window(0.50) or window(1.70) or 1.0


def happy_pose(t: float) -> dict:
    tau = t % HAPPY_LOOP
    if tau < 0:
        tau += HAPPY_LOOP
    hop = max(0.0, math.sin(2 * math.pi * tau / 1.2))
    return {
        "bobY": -8.0 * hop,
        "scaleX": 1 - 0.05 * hop,
        "scaleY": 1 + 0.08 * hop,
        "blinkY": _happy_blink(tau),
        "lookY": -2.0,
        "tilt": 6.0 * math.sin(2 * math.pi * tau / HAPPY_LOOP),
    }


def draw_happy_ember(pixel_size: int, t: float) -> Image.Image:
    svg_text = EMBER_SVG.read_text()
    body = re.search(r'<g id="body">\s*(.*?)\s*</g>', svg_text, re.S).group(1).strip()
    left = re.search(r'<g id="eye-left"[^>]*>\s*(.*?)\s*</g>', svg_text, re.S).group(1).strip()
    right = re.search(r'<g id="eye-right"[^>]*>\s*(.*?)\s*</g>', svg_text, re.S).group(1).strip()
    p = happy_pose(t)
    pad = 10
    vb = f"{-pad} {-pad} {64 + pad * 2} {64 + pad * 2}"
    bot = (
        f'translate(0 {p["bobY"]:.5f}) translate(32 54) rotate({p["tilt"]:.4f}) '
        f'scale({p["scaleX"]:.6f} {p["scaleY"]:.6f}) translate(-32 -54)'
    )
    eyes = f'translate(0 {p["lookY"]:.5f})'
    b = p["blinkY"]
    left_t = f"translate(25 33) scale(1 {b:.5f}) rotate(10) translate(-25 -33)"
    right_t = f"translate(39 33) scale(1 {b:.5f}) rotate(10) translate(-39 -33)"
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" '
        f'width="{pixel_size}" height="{pixel_size}" fill="none">'
        f'<g id="bot" transform="{bot}">'
        f'<g id="body">{body}</g>'
        f'<g id="eyes" transform="{eyes}">'
        f'<g id="eye-left" transform="{left_t}">{left}</g>'
        f'<g id="eye-right" transform="{right_t}">{right}</g>'
        "</g></g></svg>"
    )
    png = cairosvg.svg2png(
        bytestring=xml.encode("utf-8"),
        output_width=pixel_size,
        output_height=pixel_size,
        background_color="rgba(0,0,0,0)",
    )
    return Image.open(BytesIO(png)).convert("RGBA")
