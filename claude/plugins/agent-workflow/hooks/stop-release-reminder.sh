#!/usr/bin/env bash
# Stop hook (opt-in by marker) — remind a session that picked up tracks to release
# or update them before it ends.

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
aw_has_marker || exit 0
aw_repo_registers "Concurrency governance" stop-release-reminder.sh && exit 0

cat <<'JSON'
{"systemMessage":"Concurrency governance: if (and only if) you picked up tracks this session, release or update them before ending. Check with `work list --owner \"$(work whoami)\"`. On release, fill `summary:` on the new recently_completed row: plain-English goal, work and result, one paragraph. Purely ad-hoc work with no pickup needs nothing here."}
JSON
