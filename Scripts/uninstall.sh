#!/usr/bin/env bash
# Remove only PilotLight's install artifacts. Does not touch other apps or
# files, and never uses sudo.
set -euo pipefail

UID_NUM="$(id -u)"
LABEL="com.bashframes.pilotlight"
DEST_APP="$HOME/Applications/PilotLight.app"
CLI_DEST="$HOME/bin/pilotlight"
ALIAS_DEST="$HOME/bin/grok-border"
PLIST="$HOME/Library/LaunchAgents/com.bashframes.pilotlight.plist"
FLAG="$HOME/.grok-working"

if launchctl print "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1; then
  launchctl bootout "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1 || true
fi

# Quit our process only.
if pgrep -x PilotLight >/dev/null 2>&1; then
  pkill -x PilotLight >/dev/null 2>&1 || true
fi

if [[ -d "$DEST_APP" ]]; then
  rm -rf "$DEST_APP"
fi
if [[ -f "$PLIST" ]]; then
  rm -f "$PLIST"
fi
if [[ -f "$CLI_DEST" || -L "$CLI_DEST" ]]; then
  rm -f "$CLI_DEST"
fi
# Only remove the grok-border name if it is a symlink to our CLI (or is already
# broken after we removed the CLI).
if [[ -L "$ALIAS_DEST" ]]; then
  target="$(readlink "$ALIAS_DEST" || true)"
  if [[ "$target" == "$CLI_DEST" || "$target" == "pilotlight" || ! -e "$ALIAS_DEST" ]]; then
    rm -f "$ALIAS_DEST"
  fi
fi
if [[ -L /usr/local/bin/pilotlight ]]; then
  target="$(readlink /usr/local/bin/pilotlight || true)"
  if [[ "$target" == "$CLI_DEST" ]]; then
    rm -f /usr/local/bin/pilotlight
  fi
fi
if [[ -L /usr/local/bin/grok-border ]]; then
  target="$(readlink /usr/local/bin/grok-border || true)"
  if [[ "$target" == "$CLI_DEST" || "$target" == /usr/local/bin/pilotlight ]]; then
    rm -f /usr/local/bin/grok-border
  fi
fi
rm -f "$FLAG"

echo "PilotLight has been uninstalled."
