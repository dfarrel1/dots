#!/usr/bin/env bash
# Regression fixture for bin/scratch-sweep and hooks/scratch-sweep-hook.sh.
# Hermetic: a temp root and a temp transcripts dir, never the real ones.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
TOOL="$PLUGIN_ROOT/bin/scratch-sweep"; HOOK="$PLUGIN_ROOT/hooks/scratch-sweep-hook.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
export CLAUDE_CODE_TMPDIR="$W/tmp" CLAUDE_CONFIG_DIR="$W/cfg"
ROOT="$W/tmp/claude-$(id -u)"; PROJ="-proj"
OLD=11111111-1111-1111-1111-111111111111; NEW=22222222-2222-2222-2222-222222222222; ME=33333333-3333-3333-3333-333333333333
for s in $OLD $NEW $ME; do mkdir -p "$ROOT/$PROJ/$s/scratchpad"; head -c 2048 /dev/zero > "$ROOT/$PROJ/$s/scratchpad/f"; done
mkdir -p "$W/cfg/projects/$PROJ"
for s in $OLD $NEW $ME; do touch "$W/cfg/projects/$PROJ/$s.jsonl"; done
touch -t 202001010000 "$W/cfg/projects/$PROJ/$OLD.jsonl" "$W/cfg/projects/$PROJ/$ME.jsonl"
FAILS=0; PASSES=0
expect() { local what="$1"; shift; if "$@"; then PASSES=$((PASSES+1)); else FAILS=$((FAILS+1)); echo "FAIL: $what" >&2; fi; }
J() { printf '{"session_id":"%s","transcript_path":"%s/cfg/projects/%s/%s.jsonl"}' "$1" "$W" "$PROJ" "$1"; }

# 1. dry run removes nothing
"$TOOL" stale --hours 12 >/dev/null; expect "dry run keeps the idle session" [ -d "$ROOT/$PROJ/$OLD" ]
# 2. start hook removes the idle session, keeps the active one and the current one even when idle
J $ME | "$HOOK" start >/dev/null
expect "idle session removed" [ ! -d "$ROOT/$PROJ/$OLD" ]
expect "active session kept" [ -d "$ROOT/$PROJ/$NEW" ]
expect "current session kept though idle" [ -d "$ROOT/$PROJ/$ME" ]
# 3. prompt hook is silent when disk is fine and the dir is small
out="$(J $ME | AGENT_SCRATCH_DISK_MIN_GB=0 "$HOOK" prompt)"; expect "prompt silent under thresholds" [ -z "$out" ]
# 4. prompt hook warns over the self limit, with valid hook JSON, then throttles
out="$(J $ME | AGENT_SCRATCH_DISK_MIN_GB=0 AGENT_SCRATCH_SELF_MAX_GB=0 "$HOOK" prompt)"
ok_json() { printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "Scratch space" in d["hookSpecificOutput"]["additionalContext"]'; }
expect "prompt warns over the self limit" ok_json
out="$(J $ME | AGENT_SCRATCH_DISK_MIN_GB=0 AGENT_SCRATCH_SELF_MAX_GB=0 "$HOOK" prompt)"
expect "second warning throttled" [ -z "$out" ]
# 5. end hook removes the session's own dir and nothing else
J $ME | "$HOOK" end; for _ in 1 2 3 4 5 6 7 8 9 10; do [ -d "$ROOT/$PROJ/$ME" ] || break; sleep 0.2; done
expect "own dir removed at end" [ ! -d "$ROOT/$PROJ/$ME" ]
expect "other session untouched at end" [ -d "$ROOT/$PROJ/$NEW" ]
# 6. opt-out
J $NEW | AGENT_SCRATCH_SWEEP=off "$HOOK" end; sleep 0.5
expect "AGENT_SCRATCH_SWEEP=off does nothing" [ -d "$ROOT/$PROJ/$NEW" ]
# 7. a non-session directory under the project is never touched
mkdir -p "$ROOT/$PROJ/not-a-session"; touch -t 202001010000 "$ROOT/$PROJ/not-a-session"
"$TOOL" stale --hours 0 --apply >/dev/null; expect "non-session dir untouched" [ -d "$ROOT/$PROJ/not-a-session" ]

echo "$PASSES passed, $FAILS failed"; [ "$FAILS" = 0 ]
