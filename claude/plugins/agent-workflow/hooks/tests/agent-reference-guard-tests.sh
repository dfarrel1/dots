#!/usr/bin/env bash
# Tests for pretooluse-agent-reference-guard.sh.
#
# These cases pin both directions: what must be refused, and what must keep
# working, because a guard that refuses ordinary greps and history reads would be
# turned off within a day.
set -uo pipefail
. "$(dirname "$0")/fixture.sh"
G="$HOOKS/pretooluse-agent-reference-guard.sh"
fail=0

decide() {
  local out
  out=$(jq -Rn --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | "$G")
  if [ -z "$out" ]; then echo allow
  else printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision'; fi
}

expect() { # expect <want> <label> <cmd>
  local got; got=$(decide "$3")
  if [ "$got" = "$1" ]; then
    printf 'ok    %-46s %s\n' "$2" "$got"
  else
    printf 'FAIL  %-46s want=%s got=%s\n' "$2" "$1" "$got"; fail=1
  fi
}

BAD_FILE=$(mktemp); printf 'fix: y\n\n[track: t]\n\nClaude-Session: https://claude.ai/code/session_01\n' > "$BAD_FILE"
GOOD_FILE=$(mktemp); printf 'fix: y\n\n[track: t]\n\nSigned-off-by: a <a@b>\n' > "$GOOD_FILE"

# --- must refuse -----------------------------------------------------------
expect deny  "commit -m with the session trailer" \
  'git -C /w commit -s -m "fix: x

Claude-Session: https://claude.ai/code/session_01"'
expect deny  "commit -m with a bare claude.ai link"   'git commit -m "see https://claude.ai/code/x"'
expect deny  "commit -m with anthropic.com"           'git -C /w commit -m "ref anthropic.com/x"'
expect deny  "commit -F pointing at a dirty file"     "git -C /w commit -s -F $BAD_FILE"
expect deny  "gh pr create --body with the URL"       'gh pr create --body "https://claude.ai/code/x"'
expect deny  "gh pr edit --body-file (dirty)"         "gh pr edit 1 --body-file $BAD_FILE"
expect deny  "git tag -m"                             'git tag -a v1 -m "claude.ai"'

# --- must allow ------------------------------------------------------------
expect allow "clean commit -F"                        "git -C /w commit -s -F $GOOD_FILE"
expect allow "clean inline commit"                    'git -C /w commit -s -m "fix: z [track: t]"'
expect allow "reading history for the pattern"        'git log -1 --format=%B | grep claude.ai'
expect allow "grepping docs for the pattern"          'grep -rn "claude.ai" docs/'
expect allow "clean gh pr create"                     'gh pr create --title x --body "does a thing"'
expect allow "unrelated command"                      'ls -la'
expect allow "git status"                             'git -C /w status --short'

rm -f "$BAD_FILE" "$GOOD_FILE"
[ "$fail" = "0" ] && echo "PASS" || { echo "FAILURES"; exit 1; }
