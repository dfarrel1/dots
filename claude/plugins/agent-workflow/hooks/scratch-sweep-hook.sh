#!/usr/bin/env bash
# scratch-sweep-hook.sh <start|prompt|end> — keeps Claude Code's per-session temp
# space (<tmp>/claude-<uid>/<project>/<session>/, the scratchpad and task output)
# from filling the disk. Always on; opt out with AGENT_SCRATCH_SWEEP=off.
#   start   remove the temp dirs of sessions idle for AGENT_SCRATCH_STALE_HOURS (12)
#   prompt  warn this session when free disk is low or its own temp dir is large
#           (AGENT_SCRATCH_DISK_MIN_GB 5, AGENT_SCRATCH_SELF_MAX_GB 2, once per 15 min)
#   end     remove this session's own temp dir
# Reads the hook JSON (session_id, transcript_path) on standard input.
set -uo pipefail
[ "${AGENT_SCRATCH_SWEEP:-on}" = "off" ] && exit 0
TOOL="$(cd "$(dirname "$0")/../bin" && pwd)/scratch-sweep"
IN="$(cat 2>/dev/null || true)"
field() { printf '%s' "$IN" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('$1',''))
except Exception: print('')" 2>/dev/null; }
SID="$(field session_id)"; TP="$(field transcript_path)"
PDIR="${TP%/*}"; PROJ="${PDIR##*/}"; [ -n "$TP" ] || PROJ=""
case "${1:-}" in
  start)
    out="$("$TOOL" stale --hours "${AGENT_SCRATCH_STALE_HOURS:-12}" --except="$SID" --apply 2>/dev/null | tail -1)"
    case "$out" in *"removed 0 "*|"") ;; *) printf '{"systemMessage":%s}\n' "$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" ;; esac ;;
  prompt)
    [ -n "$SID" ] && [ -n "$PROJ" ] || exit 0
    "$TOOL" watch --session="$SID" --project="$PROJ" \
      --disk-min-gb "${AGENT_SCRATCH_DISK_MIN_GB:-5}" --self-max-gb "${AGENT_SCRATCH_SELF_MAX_GB:-2}" 2>/dev/null ;;
  end)
    [ -n "$SID" ] || exit 0
    ( "$TOOL" session "$SID" ${PROJ:+--project="$PROJ"} --apply >/dev/null 2>&1 & ) ;;
esac
exit 0
