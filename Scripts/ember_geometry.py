"""Brandy's refined Ember construction, 64×64 viewBox.

Tighter, more balanced three-lobe bun: side lobes sit closer, the top lobe
is fuller, and the base is rounder and less of a wide cushion. Fill stays
#E25C3A. Eyes are slightly chunkier so they hold at small sizes.

Source of truth: icon/ember-character-refined-600.png and the ELLIPSES
block in the brand colourway renderer.
"""

from __future__ import annotations

EMBER_HEX = "#E25C3A"
EMBER_RGBA = (0xE2, 0x5C, 0x3A, 255)
VIEWBOX = 64.0

LOBES = [
    (21.4, 33.4, 14.6, 15.2),  # left
    (42.6, 33.4, 14.6, 15.2),  # right
    (32.0, 18.8, 16.4, 16.0),  # top
    (32.0, 36.8, 18.0, 16.6),  # base
]
SQUASH_ANCHOR = (32.0, 53.4)

EYE_CX, EYE_CY = 32.0, 32.4
EYE_W, EYE_H = 8.4, 16.2
EYE_GAP = 6.2
EYE_TILT = 10.0

# Original wider bun, kept so review sheets can compare.
LEGACY_LOBES = [
    (20.0, 34.5, 16.2, 16.2),
    (44.0, 34.5, 16.2, 16.2),
    (32.0, 21.0, 15.2, 15.2),
    (32.0, 38.5, 21.5, 15.5),
]
LEGACY_SQUASH_ANCHOR = (32.0, 54.0)
LEGACY_EYE_CENTERS = ((25.0, 33.0), (39.0, 33.0))
LEGACY_EYE_W, LEGACY_EYE_H = 7.4, 15.8


def eye_centers() -> tuple[tuple[float, float], tuple[float, float]]:
    half = EYE_W / 2
    inset = EYE_GAP / 2 + half
    return ((EYE_CX - inset, EYE_CY), (EYE_CX + inset, EYE_CY))


def body_markup(lobes=None, fill: str = EMBER_HEX) -> str:
    parts = []
    for cx, cy, rx, ry in (lobes if lobes is not None else LOBES):
        parts.append(
            f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}"/>'
        )
    return "\n".join(parts)


def eye_markup(cx: float, cy: float, width: float = EYE_W, height: float = EYE_H) -> str:
    hw, hh = width / 2, height / 2
    return (
        f'<rect x="{cx - hw:.3f}" y="{cy - hh:.3f}" width="{width}" height="{height}" '
        f'rx="{hw}" ry="{hw}" fill="#FFFFFF"/>'
    )
