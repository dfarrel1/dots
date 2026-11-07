#!/usr/bin/env bash
# SessionStart hook (always on) — the session-title rule: the front ~25 characters
# of a session's title carry its meaning, because that is what a tab strip shows.

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
aw_repo_registers "Session tab title naming" context-tab-title.sh && exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Session tab title naming: when generating this session's title / summary that shows on the IDE tab strip, make the front ~25 characters self-sufficient (roughly all that is visible before truncation). Lead with the most specific noun or short phrase; cut filler like 'Working on', 'Help with', 'Implementing'. Prefer concrete subjects over verbs. For feature work use '<short-tag>: <thing>' so the tag survives truncation (e.g. 'work CLI: close-out docs'). For debugging, lead with the symptom. For exploratory sessions, lead with the topic, not the action."}}
JSON
