#!/usr/bin/env bash
# session-bus-tail.sh (opt-in by marker) — DELIVERY hook for `work bus`.
#
# Posting to the bus is not delivery; this hook is. Wired for BOTH:
#   - UserPromptSubmit — incremental: inject events newer than this session's
#     cursor, advance the cursor.
#   - SessionStart    — catch-up: no cursor yet, so inject recent events (last
#     AGENT_BUS_CATCHUP_HOURS, default 24) that arrived while this session did
#     not exist, then set the cursor to end-of-file.
#
# Injection policy:
#   - urgent + warn: always injected.
#   - info: capped to the AGENT_BUS_INFO_CAP (default 5) most recent; a count of
#     omitted events is shown instead.
#   - catch-up only (SessionStart): warn is capped to AGENT_BUS_WARN_CAP
#     (default 8) and bodies are cut to AGENT_BUS_CATCHUP_TRUNC chars (default
#     300). Incremental delivery into a live session is never cut or capped.
#   - directed messages ("TO session <my-id>" / "TO track <my-track>") are always
#     injected, never capped, never cut.
#   - own events (emitted by this session) are never injected.
#   - empty result = no stdout = zero token cost.
# Each AGENT_BUS_* knob also accepts its older GOAT_BUS_* name.
#
# Which bus: by default one per clone, keyed on a SHA-256 of the master worktree
# path, so every worktree of a clone shares it. A marker line `bus: <name>` puts
# the repo on the named bus ~/.claude/state/session-bus-<name>.jsonl instead, so
# sibling repos can share one. `work bus` computes the same path.
#
# Subagents inherit nothing from this hook: hook context lands in the parent
# session only. Hand a subagent the relevant excerpt in its spawn prompt.
#
# Per-session cursor: ~/.claude/state/session-bus-cursor-<session-id>, a byte
# offset into the bus file. session-id comes from the hook's stdin JSON, falling
# back to $CLAUDE_SESSION_ID, $CLAUDE_CODE_SESSION_ID, then p$PPID.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

REPO_ROOT="$(aw_toplevel)"
[ -n "$REPO_ROOT" ] || exit 0          # not in a repo
aw_has_marker || exit 0                # repo has not adopted the workflow
aw_repo_registers session-bus-tail.sh && exit 0
command -v jq >/dev/null 2>&1 || exit 0

HOOK_INPUT="$(cat 2>/dev/null || true)"
STDIN_SESSION_ID="$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
HOOK_EVENT="$(printf '%s' "$HOOK_INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"

MASTER_ROOT="$(aw_master_root)"
[ -n "$MASTER_ROOT" ] || MASTER_ROOT="$REPO_ROOT"

BUS_NAME="$(aw_get bus "")"
if [ -n "$BUS_NAME" ]; then
  case "$BUS_NAME" in (*[!A-Za-z0-9._-]*) exit 0 ;; esac   # same rule as `work bus`
  BUS_FILE="$HOME/.claude/state/session-bus-${BUS_NAME}.jsonl"
else
  REPO_FP="$(printf '%s' "$MASTER_ROOT" | shasum -a 256 | cut -c1-12)"
  BUS_FILE="$HOME/.claude/state/session-bus-${REPO_FP}.jsonl"
fi

if [ ! -f "$BUS_FILE" ]; then
  exit 0  # no bus yet
fi

# Identity set for "me": stdin session_id (authoritative, stable per
# session) + the PPID-derived id the emit side falls back to.
PPID_ID="p$PPID"
SESSION_ID="${STDIN_SESSION_ID:-${CLAUDE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-$PPID_ID}}}"

# Current track (for "TO track <name>" directed messages)
BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
TRACK="${BRANCH#track/}"
[ "$TRACK" = "$BRANCH" ] && TRACK=""

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"
CURSOR_FILE="$STATE_DIR/session-bus-cursor-${SESSION_ID}"

INFO_CAP="$(aw_env AGENT_BUS_INFO_CAP GOAT_BUS_INFO_CAP 5)"
CATCHUP_HOURS="$(aw_env AGENT_BUS_CATCHUP_HOURS GOAT_BUS_CATCHUP_HOURS 24)"
# Catch-up-only limits; 0 = unlimited. Set below once catch-up mode is known.
WARN_CAP=0
TRUNC=0

FILE_SIZE="$(stat -f%z "$BUS_FILE" 2>/dev/null || stat -c%s "$BUS_FILE" 2>/dev/null || echo 0)"

CUTOFF=""  # empty = no ts filter (incremental mode)
if [ -f "$CURSOR_FILE" ]; then
  SINCE="$(cat "$CURSOR_FILE")"
  case "$SINCE" in (''|*[!0-9]*) SINCE=0 ;; esac
  # Cursor past EOF = bus file was rotated; start over from 0.
  [ "$SINCE" -gt "$FILE_SIZE" ] && SINCE=0
else
  if [ "$HOOK_EVENT" = "SessionStart" ]; then
    # Catch-up: scan the whole file but only surface recent events.
    SINCE=0
    CUTOFF="$(date -u -v-"${CATCHUP_HOURS}"H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
      || date -u -d "${CATCHUP_HOURS} hours ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
    WARN_CAP="$(aw_env AGENT_BUS_WARN_CAP GOAT_BUS_WARN_CAP 8)"
    TRUNC="$(aw_env AGENT_BUS_CATCHUP_TRUNC GOAT_BUS_CATCHUP_TRUNC 300)"
    # Cursor-file hygiene: drop cursors from long-dead sessions.
    find "$STATE_DIR" -name 'session-bus-cursor-*' -mtime +14 -delete 2>/dev/null || true
  else
    # First fire without SessionStart having run (hook newly installed
    # mid-session): initialize the cursor, don't dump history.
    echo "$FILE_SIZE" > "$CURSOR_FILE"
    exit 0
  fi
fi

# Advance the cursor first (to the size captured above, so events landing
# mid-script are picked up next fire, not lost).
echo "$FILE_SIZE" > "$CURSOR_FILE"

if [ "$SINCE" -ge "$FILE_SIZE" ]; then
  exit 0  # nothing new
fi

# One jq pass over the new slice: drop own + malformed events, apply the
# ts cutoff (catch-up mode), classify directed / always / capped-info,
# render compact lines. Emits nothing when nothing survives.
OUT="$(tail -c +$((SINCE + 1)) "$BUS_FILE" | jq -nrR \
  --arg sid "$SESSION_ID" --arg pid "$PPID_ID" --arg track "$TRACK" \
  --arg cwd "$(pwd)" --arg cutoff "$CUTOFF" --argjson cap "$INFO_CAP" \
  --argjson warncap "$WARN_CAP" --argjson trunc "$TRUNC" '
  def mine: (.session_id // "") as $es
    | ($es == $sid or $es == $pid
       or ($es == "" and (.cwd // "") == $cwd));          # legacy events: cwd match
  def directed: (.msg // "") as $m
    | (($m | contains("TO session \($sid)")) or ($m | contains("TO session \($pid)"))
       or ($track != "" and ($m | contains("TO track \($track)"))));
  def body: (.msg // "") as $m
    | if (.level == "urgent") or directed then $m
      elif $trunc > 0 and ($m | length) > $trunc
      then ($m[:$trunc] | sub("\\s+$"; "")) + " … [truncated — full text: work bus tail]"
      else $m end;
  def render: "[\(.level)] \(.ts) \(.owner)\(if (.track // "") != "" then " track=\(.track)" else "" end) session=\(.session_id // "?")\(if directed then " (ADDRESSED TO THIS SESSION)" else "" end):\n  \(body)";
  [inputs | fromjson? | select(type == "object")
   | select(mine | not)
   | select($cutoff == "" or ((.ts // "") >= $cutoff))] as $evs
  | ($evs | map(select(directed or (.level != "info" and .level != "warn")))) as $always
  | ($evs | map(select(.level == "warn" and (directed | not)))) as $warn
  | ($evs | map(select(.level == "info" and (directed | not)))) as $info
  | (if $warncap <= 0 or ($warn | length) <= $warncap then $warn else $warn[-$warncap:] end) as $wkept
  | (if $cap <= 0 then [] elif ($info | length) > $cap then $info[-$cap:] else $info end) as $kept
  | ((($info | length) - ($kept | length))
     + (($warn | length) - ($wkept | length))) as $omitted
  | (($always + $wkept + $kept) | sort_by(.ts)) as $show
  | if ($show | length) == 0 and $omitted == 0 then empty
    else
      ($show | map(render) | join("\n")) +
      (if $omitted > 0 then "\n(\($omitted) older event(s) omitted — read with: work bus tail)" else "" end)
    end
' 2>/dev/null || true)"

if [ -z "$OUT" ]; then
  exit 0
fi

cat <<EOF
<session-bus-events>
Messages from other concurrent sessions on the multi-agent bus (delivered
by hook; NOT inherited by subagents — pass excerpts in spawn prompts).
Check for scope overlap with your current work; reply/acknowledge with
work bus ack <ts> or work bus info/warn --to session:<id>.

$OUT
</session-bus-events>
EOF
