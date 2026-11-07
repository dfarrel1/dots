#!/usr/bin/env bash
# SessionEnd hook (opt-in by marker) — last-chance handoff nudge. Catches abrupt
# ends (quota, crash, /quit) that the PreCompact and Stop nudges never see.
# Silent unless the branch is track/* or the tree carries uncommitted work.

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

aw_has_marker || exit 0
aw_repo_registers session-end-handoff.sh && exit 0

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
HAS_TRACK=0; [[ "$BRANCH" == track/* ]] && HAS_TRACK=1
HAS_WIP=0
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then HAS_WIP=1; fi
[ "$HAS_TRACK" = "0" ] && [ "$HAS_WIP" = "0" ] && exit 0

cat <<'JSON'
{"systemMessage":"Session is ending. If you have an active track and/or uncommitted work, run /handoff now to capture in-flight state into a wip(<track>): handoff baton commit, so the next session resumes without reconstructing it."}
JSON
