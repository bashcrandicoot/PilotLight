#!/usr/bin/env bash
# Install PilotLight.app, the CLI, a legacy grok-border alias, and the LaunchAgent.
# Never uses sudo. Does not take over the screen: the app is started with
# launchctl or `open -g -j`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="${1:-$ROOT/build/PilotLight.app}"
DEST_APP="$HOME/Applications/PilotLight.app"
BIN_DIR="$HOME/bin"
CLI_DEST="$BIN_DIR/pilotlight"
ALIAS_DEST="$BIN_DIR/grok-border"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS/com.bashframes.pilotlight.plist"
LABEL="com.bashframes.pilotlight"
UID_NUM="$(id -u)"

if [[ ! -d "$APP_SRC" ]]; then
  echo "No app at $APP_SRC — run ./Scripts/build.sh first." >&2
  exit 1
fi

# Remove a leftover "Grok Border" install from earlier naming, if present.
legacy_app="$HOME/Applications/Grok Border.app"
legacy_plist="$LAUNCH_AGENTS/com.bashframes.grokborder.plist"
if launchctl print "gui/${UID_NUM}/com.bashframes.grokborder" >/dev/null 2>&1; then
  launchctl bootout "gui/${UID_NUM}/com.bashframes.grokborder" >/dev/null 2>&1 || true
fi
if [[ -d "$legacy_app" ]]; then
  rm -rf "$legacy_app"
  echo "Removed leftover $legacy_app"
fi
if [[ -f "$legacy_plist" ]]; then
  rm -f "$legacy_plist"
  echo "Removed leftover $legacy_plist"
fi
mkdir -p "$HOME/Applications"
# Replace only our app bundle at the destination path.
if [[ -d "$DEST_APP" ]]; then
  rm -rf "$DEST_APP"
fi
cp -R "$APP_SRC" "$DEST_APP"
# Drop any quarantine that a copy might have picked up.
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true

mkdir -p "$BIN_DIR"
cp "$ROOT/Tools/pilotlight" "$CLI_DEST"
chmod 755 "$CLI_DEST"
# Recreate the alias so it always points at the current CLI.
ln -sfn "$CLI_DEST" "$ALIAS_DEST"

# /usr/local/bin only if writable without sudo.
if [[ -d /usr/local/bin && -w /usr/local/bin ]]; then
  ln -sfn "$CLI_DEST" /usr/local/bin/pilotlight
  ln -sfn "$CLI_DEST" /usr/local/bin/grok-border
  echo "Also linked CLI into /usr/local/bin"
fi

mkdir -p "$LAUNCH_AGENTS"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${DEST_APP}/Contents/MacOS/PilotLight</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
</dict>
</plist>
PLIST

# Reload our agent only. KeepAlive is false, so this starts it now via RunAtLoad
# equivalent after bootstrap.
if launchctl print "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1; then
  launchctl bootout "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1 || true
  # Give launchd a moment to drop the old job before bootstrap.
  sleep 0.3
fi
launchctl bootstrap "gui/${UID_NUM}" "$PLIST"
launchctl enable "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1 || true

# If bootstrap didn't start it (already running from a previous copy, or a
# race), make sure one instance is up without activating it.
if ! pgrep -x PilotLight >/dev/null 2>&1; then
  open -g -j -a "$DEST_APP"
fi

echo "Installed:"
echo "  $DEST_APP"
echo "  $CLI_DEST"
echo "  $ALIAS_DEST  (alias)"
echo "  $PLIST"
echo "PilotLight is running in the menu bar. The border stays off until you run: $CLI_DEST on"
