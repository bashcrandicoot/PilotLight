#!/usr/bin/env python3
"""Rebuild docs/images/ember.gif from the official 2.4 s Ember loop.

Brandy's ember-preview.gif is a wide pill shot with a glow background and
older copy, so this exports the character itself: 256×256 (2× for a 128 px
README display), transparent background, 60 frames, 2.4 s, under 300 KB.
Timing and transforms match EmberBot in PillBotView.swift. Needs cairosvg
and ffmpeg.
"""

from __future__ import annotations

import math
import re
import subprocess
from pathlib import Path

import cairosvg

ROOT = Path(__file__).resolve().parents[1]
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from ember_geometry import (
    LOBES,
    SQUASH_ANCHOR,
    body_markup,
    eye_centers,
    eye_markup,
)
OUT = ROOT / "docs/images/ember.gif"
FRAME_DIR = Path("/tmp/ember-gif-frames")

SIZE = 256
PAD = 8
LOOP = 2.4
N_FRAMES = 60
CLOSED = 0.12
ANCHOR = SQUASH_ANCHOR


def lerp_ease(from_v: float, to_v: float, start: float, end: float, t: float) -> float:
    if t <= start:
        return from_v
    if t >= end:
        return to_v
    u = (t - start) / (end - start)
    eased = 0.5 - 0.5 * math.cos(math.pi * u)
    return from_v + (to_v - from_v) * eased


def blink(t: float) -> float:
    if t < 0.86:
        return 1.0
    if t < 0.92:
        return lerp_ease(1.0, CLOSED, 0.86, 0.92, t)
    if t < 0.96:
        return CLOSED
    if t < 1.02:
        return lerp_ease(CLOSED, 1.0, 0.96, 1.02, t)
    return 1.0


def look(t: float) -> float:
    if t < 1.28:
        return 0.0
    if t < 1.48:
        return lerp_ease(0.0, -8.0, 1.28, 1.48, t)
    if t < 1.66:
        return -8.0
    if t < 1.90:
        return lerp_ease(-8.0, 8.0, 1.66, 1.90, t)
    if t < 2.10:
        return 8.0
    if t < 2.34:
        return lerp_ease(8.0, 0.0, 2.10, 2.34, t)
    return 0.0


def pose(t: float) -> dict[str, float]:
    tau = t % LOOP
    if tau < 0:
        tau += LOOP
    phase = math.sin(2 * math.pi * tau / 1.2)
    return {
        "bobY": -5.0 * phase,
        "scaleX": 1 - 0.035 * phase,
        "scaleY": 1 + 0.05 * phase,
        "blinkY": blink(tau),
        "lookX": look(tau),
    }


def frame_svg(body: str, left: str, right: str, t: float) -> bytes:
    p = pose(t)
    ax, ay = ANCHOR
    vb = f"{-PAD} {-PAD} {64 + PAD * 2} {64 + PAD * 2}"
    bot = (
        f'translate(0 {p["bobY"]:.5f}) '
        f"translate({ax} {ay}) scale({p['scaleX']:.6f} {p['scaleY']:.6f}) "
        f"translate({-ax} {-ay})"
    )
    eyes = f'translate({p["lookX"]:.5f} 0)'
    b = p["blinkY"]
    (lx, ly), (rx, ry) = eye_centers()
    left_t = f"translate({lx} {ly}) scale(1 {b:.5f}) rotate(10) translate({-lx} {-ly})"
    right_t = f"translate({rx} {ry}) scale(1 {b:.5f}) rotate(10) translate({-rx} {-ry})"
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" width="{SIZE}" height="{SIZE}" fill="none">
  <g id="bot" transform="{bot}">
    <g id="body">{body}</g>
    <g id="eyes" transform="{eyes}">
      <g id="eye-left" transform="{left_t}">{left}</g>
      <g id="eye-right" transform="{right_t}">{right}</g>
    </g>
  </g>
</svg>
'''.encode("utf-8")


def main() -> None:
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    for old in FRAME_DIR.glob("*.png"):
        old.unlink()
    (lcx, lcy), (rcx, rcy) = eye_centers()
    body, left, right = body_markup(), eye_markup(lcx, lcy), eye_markup(rcx, rcy)
    for i in range(N_FRAMES):
        t = i * LOOP / N_FRAMES
        png = cairosvg.svg2png(
            bytestring=frame_svg(body, left, right, t),
            output_width=SIZE,
            output_height=SIZE,
            background_color="rgba(0,0,0,0)",
        )
        (FRAME_DIR / f"frame-{i:03d}.png").write_bytes(png)

    pal = Path("/tmp/ember-palette.png")
    fps = str(N_FRAMES / LOOP)
    subprocess.check_call(
        [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-framerate", fps, "-i", str(FRAME_DIR / "frame-%03d.png"),
            "-vf", "palettegen=reserve_transparent=1:stats_mode=full",
            str(pal),
        ]
    )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.check_call(
        [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-framerate", fps, "-i", str(FRAME_DIR / "frame-%03d.png"),
            "-i", str(pal),
            "-lavfi", "paletteuse=dither=none",
            "-gifflags", "-offsetting",
            str(OUT),
        ]
    )
    print(f"wrote {OUT} {OUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
