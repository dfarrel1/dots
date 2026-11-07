#!/usr/bin/env bash
# SessionStart hook (opt-in by marker) — when to pick up a track with `work`, and
# what a release record must say. The tracker directory comes from the marker.

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
aw_has_marker || exit 0
aw_repo_registers "Concurrency governance" context-concurrency.sh && exit 0
command -v jq >/dev/null 2>&1 || exit 0

TRACKER="$(aw_get tracker_dir docs/project/active-work)"
CTX="Concurrency governance: opt-in coordination, not a tax on every keystroke. Default to ad-hoc (no pickup) for read-only exploration, single-commit edits, fresh-corner new files and work under 15 minutes. Pick up a track ONLY when the work is multi-commit or multi-hour, overlaps shared docs or indexes, involves long-running jobs or shared infrastructure, or spans sessions. If you pick up: \`work pickup <name> --scope ... --eta ... --note ...\`, then a \`[track: <name>]\` trailer on every commit (or \`work commit <name> -m \"...\"\`), then \`work release <name>\` when done. Promote mid-flight if ad-hoc work grows track-shaped. Run \`work list\` only if you suspect overlap with another session. On release, fill the \`summary:\` field of the new row in ${TRACKER}/recently_completed/: plain-English goal, work and result, readable cold, one paragraph."
jq -cn --arg c "$CTX" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
