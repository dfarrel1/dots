#!/usr/bin/env bash
# Stop hook (opt-in by marker) — handoff nudge with a throttle. Stop fires after
# every response; this emits only when all three hold:
#   1. the branch is track/<name>
#   2. the tree carries uncommitted work
#   3. the last handoff for the track (.claude/handoff/<track>.last) is older than
#      HANDOFF_STOP_THROTTLE_MIN minutes (default 30), or there was none

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

aw_has_marker || exit 0
aw_repo_registers stop-handoff-throttle.sh && exit 0

THROTTLE_MIN="${HANDOFF_STOP_THROTTLE_MIN:-30}"

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
[[ "$BRANCH" == track/* ]] || exit 0
TRACK="${BRANCH#track/}"

if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
  exit 0
fi

MARKER=".claude/handoff/${TRACK}.last"
if [ -f "$MARKER" ]; then
  LAST_TS="$(head -1 "$MARKER")"
  LAST_EPOCH="$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_TS" +%s 2>/dev/null || \
                date -u -d "$LAST_TS" +%s 2>/dev/null || echo "0")"
  NOW_EPOCH="$(date -u +%s)"
  AGE_MIN=$(( (NOW_EPOCH - LAST_EPOCH) / 60 ))
  [ "$AGE_MIN" -lt "$THROTTLE_MIN" ] && exit 0
fi

cat <<JSON
{"systemMessage":"Track '$TRACK' has uncommitted work and the last /handoff was more than $THROTTLE_MIN min ago (or never). Consider /handoff before the next pause. If the work is about to land as a real commit with a good message body, skip it. Throttle window: $THROTTLE_MIN min."}
JSON
