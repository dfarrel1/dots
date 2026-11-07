#!/usr/bin/env bash
# PreCompact hook (opt-in by marker) — nudge for a handoff baton before context
# compaction summarizes in-head state away. It does not run /handoff itself; it
# emits additionalContext and the session decides. Silent unless the branch is
# track/* or the tree carries uncommitted work.

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

aw_has_marker || exit 0
aw_repo_registers precompact-handoff.sh && exit 0

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
HAS_TRACK=0; [[ "$BRANCH" == track/* ]] && HAS_TRACK=1
HAS_WIP=0
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then HAS_WIP=1; fi
[ "$HAS_TRACK" = "0" ] && [ "$HAS_WIP" = "0" ] && exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"Context compaction is about to run. If you have an active track and/or uncommitted work, run /handoff now, before compaction summarizes away your in-head state. /handoff detects the track and captures the todo list, active hypothesis, ruled-out paths, next step and WIP files into a wip(<track>): handoff baton commit. On a clean tree whose last commit already says what is next, it is a fast no-op."}}
JSON
