#!/usr/bin/env bash
# Regression fixture for session-bus-tail.sh (bus delivery hook).
# Exits non-zero on first failed expectation summary.
#
# Hermetic: overrides HOME to a temp dir and runs the hook from a temp git
# repo, so the machine's real bus + cursors are never touched.

set -euo pipefail

. "$(dirname "$0")/fixture.sh"
HOOK="$HOOKS/session-bus-tail.sh"

if [ ! -x "$HOOK" ]; then
  echo "ERROR: hook not executable at $HOOK" >&2
  exit 2
fi

FAILS=0
PASSES=0

TEST_HOME="$(mktemp -d)"
REPO_DIR="$(mktemp -d)/repo"
mkdir -p "$REPO_DIR"
trap 'rm -rf "$TEST_HOME" "$(dirname "$REPO_DIR")" "$FIX_ROOT"' EXIT

git init --quiet "$REPO_DIR"
git -C "$REPO_DIR" -c user.name=test -c user.email=test@example.com \
  commit --allow-empty -m init --quiet
mkdir -p "$REPO_DIR/.claude"; printf 'version: 1\n' > "$REPO_DIR/.claude/agent-workflow.yaml"

# Bus file path must match the hook's fingerprint of the repo root.
REPO_ROOT_ABS="$(cd "$REPO_DIR" && pwd)"
REPO_FP="$(printf '%s' "$REPO_ROOT_ABS" | shasum -a 256 | cut -c1-12)"
STATE_DIR="$TEST_HOME/.claude/state"
mkdir -p "$STATE_DIR"
BUS_FILE="$STATE_DIR/session-bus-${REPO_FP}.jsonl"

NOW_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

emit() { # emit <level> <session_id> <msg> [ts]
  local level="$1" sid="$2" msg="$3" ts="${4:-$NOW_TS}"
  jq -cn --arg ts "$ts" --arg level "$level" --arg sid "$sid" --arg msg "$msg" \
    '{ts:$ts, level:$level, msg:$msg, owner:"tester@example.com", session_id:$sid}' >> "$BUS_FILE"
}

run_hook() { # run_hook <event> <session_id> -> stdout
  local event="$1" sid="$2"
  jq -n --arg e "$event" --arg s "$sid" '{hook_event_name:$e, session_id:$s, cwd:"'"$REPO_ROOT_ABS"'"}' \
    | (cd "$REPO_DIR" && HOME="$TEST_HOME" "$HOOK" 2>/dev/null)
}

check() { # check <label> <expect: contains|not-contains|empty> <needle> <output>
  local label="$1" mode="$2" needle="$3" out="$4"
  local ok=0
  case "$mode" in
    contains)     [[ "$out" == *"$needle"* ]] && ok=1 ;;
    not-contains) [[ "$out" != *"$needle"* ]] && ok=1 ;;
    empty)        [ -z "$out" ] && ok=1 ;;
  esac
  if [ "$ok" = 1 ]; then
    echo "PASS  $label"; PASSES=$((PASSES + 1))
  else
    echo "FAIL  $label  (mode=$mode needle=$needle)"; echo "----- output -----"; echo "$out"; echo "------------------"
    FAILS=$((FAILS + 1))
  fi
}

SID="test-session-me"

echo "== SessionStart catch-up =="
emit info  sender-A "old news"           "2020-01-01T00:00:00Z"
emit urgent sender-A "old fire"          "2020-01-01T00:00:01Z"
emit urgent sender-B "recent fire"
emit info  sender-B "recent chatter"
OUT="$(run_hook SessionStart "$SID")"
check "recent urgent injected at SessionStart"      contains     "recent fire"    "$OUT"
check "recent info injected at SessionStart"        contains     "recent chatter" "$OUT"
check "events older than catch-up window excluded"  not-contains "old fire"       "$OUT"
check "cursor written at SessionStart" contains "$(stat -f%z "$BUS_FILE" 2>/dev/null || stat -c%s "$BUS_FILE")" "$(cat "$STATE_DIR/session-bus-cursor-$SID")"

echo
echo "== Incremental delivery + cursor =="
OUT="$(run_hook UserPromptSubmit "$SID")"
check "no new events → zero output (zero token cost)" empty "" "$OUT"
emit warn sender-B "heads up: rebasing main"
OUT="$(run_hook UserPromptSubmit "$SID")"
check "new cross-session warn injected on next prompt" contains "heads up: rebasing main" "$OUT"
OUT="$(run_hook UserPromptSubmit "$SID")"
check "cursor prevents re-injection" empty "" "$OUT"

echo
echo "== Own-event + level filtering =="
emit info "$SID" "my own note"
emit info sender-B "someone else's note"
OUT="$(run_hook UserPromptSubmit "$SID")"
check "own event filtered out"        not-contains "my own note"         "$OUT"
check "other session's info arrives"  contains     "someone else's note" "$OUT"

for i in 1 2 3 4 5 6 7; do emit info sender-C "filler info $i"; done
emit urgent sender-C "urgent rides above the cap"
emit info sender-C "TO session $SID: directed rides above the cap"
OUT="$(run_hook UserPromptSubmit "$SID")"
check "info capped: oldest dropped"          not-contains "filler info 1" "$OUT"
check "info capped: newest kept"             contains     "filler info 7" "$OUT"
check "omitted count surfaced"               contains     "omitted"       "$OUT"
check "urgent exempt from cap"               contains     "urgent rides above the cap" "$OUT"
check "directed-to-me info exempt from cap"  contains     "directed rides above the cap" "$OUT"
check "directed message flagged"             contains     "ADDRESSED TO THIS SESSION" "$OUT"

echo
echo "== Directed to track =="
git -C "$REPO_DIR" checkout --quiet -b track/my-track
emit info sender-D "TO track my-track: track-directed message"
OUT="$(run_hook UserPromptSubmit "$SID")"
check "TO track <current track> flagged as addressed" contains "ADDRESSED TO THIS SESSION" "$OUT"
git -C "$REPO_DIR" checkout --quiet -

echo
echo "== First UserPromptSubmit with no cursor (hook installed mid-session) =="
SID2="test-session-late"
OUT="$(run_hook UserPromptSubmit "$SID2")"
check "first prompt-fire initializes cursor silently" empty "" "$OUT"
emit warn sender-E "after cursor init"
OUT="$(run_hook UserPromptSubmit "$SID2")"
check "delivery works after silent init" contains "after cursor init" "$OUT"

echo
echo "== Rotation safety (cursor past EOF) =="
echo "999999999" > "$STATE_DIR/session-bus-cursor-$SID"
OUT="$(run_hook UserPromptSubmit "$SID")"
check "cursor past EOF resets without crash" contains "session-bus-events" "$OUT"

echo
echo "== Named bus (marker bus: <name>) =="
printf 'version: 1\nbus: shared-test\n' > "$REPO_DIR/.claude/agent-workflow.yaml"
NAMED="$STATE_DIR/session-bus-shared-test.jsonl"
jq -cn --arg ts "$NOW_TS" '{ts:$ts, level:"warn", msg:"on the named bus", owner:"t", session_id:"sender-N"}' >> "$NAMED"
OUT="$(run_hook SessionStart test-session-named)"
check "named bus delivered" contains "on the named bus" "$OUT"
check "per-clone bus not read when named" not-contains "after cursor init" "$OUT"

echo
echo "== No marker: silent =="
rm "$REPO_DIR/.claude/agent-workflow.yaml"
OUT="$(run_hook SessionStart test-session-nomarker)"
check "no marker -> no delivery" empty "" "$OUT"

echo
echo "$PASSES passed, $FAILS failed"
[ "$FAILS" -eq 0 ]
