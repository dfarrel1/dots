#!/usr/bin/env bash
# Regression fixture for pretooluse-destructive-git-guard.sh.
# Exits non-zero on first failed expectation.

set -euo pipefail

. "$(dirname "$0")/fixture.sh"
HOOK="$HOOKS/pretooluse-destructive-git-guard.sh"

if [ ! -x "$HOOK" ]; then
  echo "ERROR: hook not executable at $HOOK" >&2
  exit 2
fi

FAILS=0
PASSES=0

test_cmd() {
  local label="$1" expected="$2" cmd="$3"
  local result
  # Hermetic: the hook reads the override from the command
  # text, never the env, but clear it anyway so the suite cannot inherit
  # an operator override from the calling shell if that ever changes.
  result=$(printf '%s' "$(jq -n --arg cmd "$cmd" '{tool_name:"Bash",tool_input:{command:$cmd}}')" | env -u GOAT_ALLOW_DESTRUCTIVE_GIT -u AGENT_ALLOW_DESTRUCTIVE_GIT "$HOOK" 2>&1)
  local decision="allow"
  if [ -n "$result" ]; then
    decision=$(printf '%s' "$result" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null)
  fi
  if [ "$decision" = "$expected" ]; then
    echo "PASS  [$expected]  $label"
    PASSES=$((PASSES + 1))
  else
    echo "FAIL  expected=$expected got=$decision  $label  | cmd=$cmd"
    FAILS=$((FAILS + 1))
  fi
}

echo "== ALLOWED =="
test_cmd "git push --force-with-lease"                   allow "git push --force-with-lease origin track/foo"
test_cmd "git reset (soft, default)"                     allow "git reset HEAD~1"
test_cmd "git reset --soft"                              allow "git reset --soft HEAD~1"
test_cmd "git reset --mixed"                             allow "git reset --mixed"
test_cmd "git status"                                    allow "git status"
test_cmd "git stash list (read-only)"                    allow "git stash list"
test_cmd "git stash show (read-only)"                    allow "git stash show stash@{0}"
test_cmd "git restore --staged"                          allow "git restore --staged file.txt"
test_cmd "git clean -n (dry-run)"                        allow "git clean -n"
test_cmd "rm -rf /tmp/foo (not .git)"                    allow "rm -rf /tmp/foo"
test_cmd "git worktree remove (no force)"                allow "git worktree remove .claude/worktrees/foo"
test_cmd "git rebase --abort (recovery)"                 allow "git rebase --abort"
test_cmd "git rebase --continue"                         allow "git rebase --continue"
test_cmd "git branch -d (lowercase delete)"              allow "git branch -d feature/merged"
test_cmd "override on push -f"                           allow "GOAT_ALLOW_DESTRUCTIVE_GIT=1 git push -f origin x"
test_cmd "override on reset --hard"                      allow "GOAT_ALLOW_DESTRUCTIVE_GIT=1 git reset --hard"
test_cmd "AGENT_ override on reset --hard"                allow "AGENT_ALLOW_DESTRUCTIVE_GIT=1 git reset --hard"
test_cmd "non-Bash tool passthrough"                     allow ""   # special-cased below

# Non-Bash tool: hook must produce no output (empty = allow).
NONBASH_RESULT=$(printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"/x"}}' | "$HOOK")
if [ -z "$NONBASH_RESULT" ]; then
  echo "PASS  [allow]  Non-Bash tool produces no output (the last 'allow' above is duplicate-safe)"
  PASSES=$((PASSES + 1))
else
  echo "FAIL  Non-Bash tool produced output: $NONBASH_RESULT"
  FAILS=$((FAILS + 1))
fi

echo "== DENIED =="
test_cmd "git reset --hard"                              deny  "git reset --hard origin/main"
test_cmd "git reset --hard via cd-chain"                 deny  "cd /tmp && git reset --hard HEAD"
test_cmd "git -C reset --hard"                           deny  "git -C /repo reset --hard"
test_cmd "git push --force"                              deny  "git push --force origin main"
test_cmd "git push -f"                                   deny  "git push -f origin main"
test_cmd "git branch -D"                                 deny  "git branch -D feature/abandoned"
test_cmd "git checkout ."                                deny  "git checkout ."
test_cmd "git checkout -- ."                             deny  "git checkout -- ."
test_cmd "git restore ."                                 deny  "git restore ."
test_cmd "git clean -fd"                                 deny  "git clean -fd"
test_cmd "rm -rf .git"                                   deny  "rm -rf .git"
test_cmd "git worktree remove --force"                   deny  "git worktree remove --force .claude/worktrees/foo"
test_cmd "git stash (bare, defaults to push)"            deny  "git stash"
test_cmd "git stash push"                                deny  "git stash push -m wip"
test_cmd "git stash save"                                deny  "git stash save 'context'"
test_cmd "git stash pop"                                 deny  "git stash pop"
test_cmd "git stash apply"                               deny  "git stash apply stash@{0}"
test_cmd "git stash drop"                                deny  "git stash drop stash@{1}"
test_cmd "git stash clear"                               deny  "git stash clear"
test_cmd "git stash branch"                              deny  "git stash branch recovery"
test_cmd "git stash create"                              deny  "git stash create"
test_cmd "git stash store"                               deny  "git stash store -m wip deadbeef"
test_cmd "git -C ... stash push"                         deny  "git -C /repo stash push -m wip"

echo "== REPO-WIRED COPY WINS (no double delivery) =="
mkdir -p "$FIX_PLAIN/.claude"
printf '{"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"x/pretooluse-destructive-git-guard.sh"}]}]}}' > "$FIX_PLAIN/.claude/settings.json"
DUP=$(cd "$FIX_PLAIN" && printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git reset --hard"}}' | "$HOOK")
if [ -z "$DUP" ]; then echo "PASS  [allow]  repo wires its own copy -> plugin copy silent"; PASSES=$((PASSES + 1))
else echo "FAIL  plugin copy answered although the repo wires its own"; FAILS=$((FAILS + 1)); fi

echo
echo "== SUMMARY =="
echo "PASS: $PASSES"
echo "FAIL: $FAILS"
if [ "$FAILS" -gt 0 ]; then exit 1; fi
exit 0
