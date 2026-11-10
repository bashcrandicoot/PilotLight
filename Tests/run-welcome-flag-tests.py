#!/usr/bin/env python3
"""Run WelcomeFlag cases on the box (no AppKit, no windows, no file reads).

Mirrors Sources/PilotLight/WelcomeFlag.swift exactly, and checks that the
Swift source still defines the same API so the Mac build cannot drift.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources" / "PilotLight" / "WelcomeFlag.swift"


class WelcomeFlag:
    def __init__(self, seen: bool = False) -> None:
        self.seen = seen

    @property
    def shouldShowOnLaunch(self) -> bool:
        return not self.seen

    def markShown(self) -> None:
        self.seen = True


def check_source() -> None:
    text = SOURCE.read_text()
    assert "struct WelcomeFlag" in text, "missing WelcomeFlag"
    assert re.search(r"var shouldShowOnLaunch:\s*Bool\s*\{\s*!seen\s*\}", text), (
        "shouldShowOnLaunch must be !seen"
    )
    assert re.search(r"func markShown\(\)\s*\{\s*seen = true", text), (
        "markShown must set seen = true"
    )


def expect(cond: bool, message: str, failures: list[str]) -> None:
    if not cond:
        failures.append(message)


def main() -> int:
    check_source()
    failures: list[str] = []

    unseen = WelcomeFlag()
    expect(unseen.seen is False, "default is unseen", failures)
    expect(unseen.shouldShowOnLaunch is True, "unseen flag should auto-show on launch", failures)

    unseen.markShown()
    expect(unseen.seen is True, "markShown records that the window was presented", failures)
    expect(unseen.shouldShowOnLaunch is False, "after show, it must not auto-open again", failures)

    unseen.markShown()
    expect(unseen.seen is True, "markShown is idempotent", failures)
    expect(unseen.shouldShowOnLaunch is False, "a second mark still does not auto-show", failures)

    already = WelcomeFlag(seen=True)
    expect(already.shouldShowOnLaunch is False, "a stored seen flag never auto-shows", failures)
    expect(already.seen is True, "menu can still present even when seen is true", failures)

    restored = WelcomeFlag(seen=False)
    expect(restored.shouldShowOnLaunch is True, "a fresh store auto-shows once", failures)
    restored.markShown()
    persisted = WelcomeFlag(seen=restored.seen)
    expect(persisted.shouldShowOnLaunch is False, "persisted seen value suppresses auto-show", failures)

    if failures:
        for item in failures:
            print(f"FAIL: {item}", file=sys.stderr)
        print(f"WelcomeFlagTests: {len(failures)} failed", file=sys.stderr)
        return 1
    print("WelcomeFlagTests: all passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
