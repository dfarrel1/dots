#!/usr/bin/env bash
# check-claude-md-size.sh — CI template: keep CLAUDE.md an index, not a manual.
#
# CLAUDE.md is loaded into every agent session as standing context, and it
# regrows one "just one paragraph" at a time. The cap is mechanical.
#
# Hysteresis, not a single line: the file may drift up to TRIP_BYTES; crossing
# it calls for ONE curation pass down to TARGET_BYTES (move narrative to its
# owning doc, leave a one-line pointer), instead of byte-shaving in every PR.
#
#   check-claude-md-size.sh [file]       default CLAUDE.md
#   CLAUDE_MD_TRIP_BYTES / CLAUDE_MD_TARGET_BYTES override 35000 / 25000
set -euo pipefail

FILE="${1:-CLAUDE.md}"
TRIP_BYTES="${CLAUDE_MD_TRIP_BYTES:-35000}"
TARGET_BYTES="${CLAUDE_MD_TARGET_BYTES:-25000}"

[ -f "$FILE" ] || { echo "check-claude-md-size: $FILE not found" >&2; exit 2; }
size=$(wc -c < "$FILE" | tr -d ' ')

if [ "$size" -gt "$TRIP_BYTES" ]; then
  echo "FAIL: $FILE is ${size} bytes, over the ${TRIP_BYTES} trip line." >&2
  echo "Curate it to ${TARGET_BYTES} or below by MOVING narrative to its owning doc and" >&2
  echo "leaving a one-line pointer. Rewording to save a few bytes brings you back here." >&2
  echo "Largest lines:" >&2
  awk '{ printf "%7d  L%-4d  %s\n", length($0), NR, substr($0, 1, 80) }' "$FILE" | sort -rn | head -5 >&2
  exit 1
fi
echo "OK: $FILE is ${size} bytes (trip ${TRIP_BYTES}; curation target ${TARGET_BYTES})."
