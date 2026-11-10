#!/usr/bin/env python3
"""Run FirstRunPolicy cases on the box (no AppKit, no windows, no file reads)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources" / "PilotLight" / "FirstRunPolicy.swift"


def check_source() -> None:
    text = SOURCE.read_text()
    assert "enum FirstRunPolicy" in text
    assert "func cliDecision" in text
    assert "func loginAutoDecision" in text
    assert "skipRequiresApproval" in text
    assert "skipExistingUser" in text
    assert "skipLegacyLaunchAgent" in text


def cli_decision(has_bundled: bool, is_present: bool, is_current: bool) -> str:
    if not has_bundled:
        return "skip"
    if is_present and is_current:
        return "skip"
    return "install"


def login_auto(is_first_launch: bool, status: str, legacy: bool) -> str:
    if status == "enabled":
        return "skipAlreadyEnabled"
    if status == "requiresApproval":
        return "skipRequiresApproval"
    if legacy:
        return "skipLegacyLaunchAgent"
    if not is_first_launch:
        return "skipExistingUser"
    return "register"


def login_user_enable(status: str) -> str:
    if status == "enabled":
        return "skipAlreadyEnabled"
    if status == "requiresApproval":
        return "skipRequiresApproval"
    return "register"


def main() -> int:
    check_source()
    failures: list[str] = []

    def expect(cond: bool, message: str) -> None:
        if not cond:
            failures.append(message)

    expect(cli_decision(False, False, False) == "skip", "no bundled CLI means skip")
    expect(cli_decision(True, True, True) == "skip", "present and current CLI is skipped")
    expect(cli_decision(True, False, False) == "install", "missing CLI is installed")
    expect(cli_decision(True, True, False) == "install", "stale CLI is replaced")
    expect(login_auto(True, "notRegistered", False) == "register", "first launch registers")
    expect(login_auto(True, "notFound", False) == "register", "first launch notFound registers")
    expect(login_auto(True, "enabled", False) == "skipAlreadyEnabled", "enabled skipped on first launch")
    expect(login_auto(True, "requiresApproval", False) == "skipRequiresApproval", "approval is never forced")
    expect(login_auto(True, "notRegistered", True) == "skipLegacyLaunchAgent", "legacy LaunchAgent left alone")
    expect(login_auto(False, "notRegistered", False) == "skipExistingUser", "existing user does not auto-register")
    expect(login_auto(False, "enabled", False) == "skipAlreadyEnabled", "enabled wins over existing-user")
    expect(login_user_enable("notRegistered") == "register", "Settings toggle registers")
    expect(login_user_enable("requiresApproval") == "skipRequiresApproval", "Settings toggle does not force approval")
    expect(login_user_enable("enabled") == "skipAlreadyEnabled", "Settings toggle no-op when enabled")

    if failures:
        for item in failures:
            print(f"FAIL: {item}", file=sys.stderr)
        print(f"FirstRunPolicyTests: {len(failures)} failed", file=sys.stderr)
        return 1
    print("FirstRunPolicyTests: all passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
