#!/usr/bin/env bash
# Install (or refresh) the io.dlf-dds.warnmem LaunchAgent: a background macOS
# memory-pressure notifier (companion to the `warnmem` shell function).
#
# Idempotent + path-agnostic: resolves this repo's location at runtime, renders
# the plist template into ~/Library/LaunchAgents with absolute paths, and
# (re)loads it via launchd. Safe to re-run after a fresh clone or a path change.
#
# Usage: ./xtra/launchagents/install.sh   [uninstall]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../xtra/launchagents
DOTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"                  # repo root
WATCHER="$DOTS_DIR/profile/warnmem-watch.sh"
LABEL="io.dlf-dds.warnmem"
DST="$HOME/Library/LaunchAgents/$LABEL.plist"

uninstall() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$DST"
  echo "Removed $LABEL"
}

if [ "${1:-}" = "uninstall" ]; then uninstall; exit 0; fi

[ -f "$WATCHER" ] || { echo "missing watcher: $WATCHER" >&2; exit 1; }
chmod +x "$WATCHER"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

sed -e "s#__WATCHER_PATH__#$WATCHER#g" -e "s#__HOME__#$HOME#g" \
  "$SCRIPT_DIR/$LABEL.plist" > "$DST"
plutil -lint "$DST" >/dev/null

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DST"
echo "Loaded $LABEL  (watcher: $WATCHER, interval 30s, warn <12% free)"
