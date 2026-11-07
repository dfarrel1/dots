#!/usr/bin/env bash
# SessionStart hook (always on) — cold start: resume a session automatically when
# the last one left a marker at <repo>/.claude/coldstart.md. With no marker it
# exits in milliseconds and prints nothing. Never blocks the session: any failure
# is swallowed. The module is bin/coldstart beside this directory.

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0

aw_repo_registers session-start-coldstart.sh && exit 0

"$(dirname "$0")/../bin/coldstart" check 2>/dev/null || true
