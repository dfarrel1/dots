#!/usr/bin/env bash
# Regression fixture for pretooluse-master-worktree-write-guard.sh.
# Exits non-zero on first failed expectation.

set -euo pipefail

. "$(dirname "$0")/fixture.sh"
HOOK="$HOOKS/pretooluse-master-worktree-write-guard.sh"

if [ ! -x "$HOOK" ]; then
  echo "ERROR: hook not executable at $HOOK" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
COMMON_DIR="$(git rev-parse --git-common-dir)"
MASTER_ROOT="$(cd "$(dirname "$COMMON_DIR")" && pwd)"

FAILS=0
PASSES=0

test_tool() {
  local label="$1" expected="$2" tool="$3" path="$4"
  local payload
  payload=$(jq -n --arg tool "$tool" --arg path "$path" \
    '{tool_name:$tool, tool_input:{file_path:$path}}')
  local result
  # Hermetic: the hook honors the override from the session
  # env first, so a suite run from an override shell (the documented
  # repair procedure) would turn every deny case into a false failure.
  # Clear it here; the one override case passes it back explicitly.
  result=$(printf '%s' "$payload" | env -u GOAT_ALLOW_MASTER_WRITE -u AGENT_ALLOW_MASTER_WRITE "$HOOK" 2>&1)
  local decision="allow"
  if [ -n "$result" ]; then
    decision=$(printf '%s' "$result" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null)
  fi
  if [ "$decision" = "$expected" ]; then
    echo "PASS  [$expected]  $label"
    PASSES=$((PASSES + 1))
  else
    echo "FAIL  expected=$expected got=$decision  $label  | path=$path"
    FAILS=$((FAILS + 1))
  fi
}

test_tool_env() {
  local label="$1" expected="$2" tool="$3" path="$4" env_kv="$5"
  local payload
  payload=$(jq -n --arg tool "$tool" --arg path "$path" \
    '{tool_name:$tool, tool_input:{file_path:$path}}')
  local result
  result=$(printf '%s' "$payload" | env -u GOAT_ALLOW_MASTER_WRITE -u AGENT_ALLOW_MASTER_WRITE "$env_kv" "$HOOK" 2>&1)
  local decision="allow"
  if [ -n "$result" ]; then
    decision=$(printf '%s' "$result" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null)
  fi
  if [ "$decision" = "$expected" ]; then
    echo "PASS  [$expected]  $label"
    PASSES=$((PASSES + 1))
  else
    echo "FAIL  expected=$expected got=$decision  $label  | env=$env_kv path=$path"
    FAILS=$((FAILS + 1))
  fi
}

echo "== DENIED (master worktree paths) =="
test_tool "Edit a master file"           deny  Edit       "$MASTER_ROOT/CLAUDE.md"
test_tool "Write a master file"          deny  Write      "$MASTER_ROOT/docs/design/foo.md"
test_tool "MultiEdit a master file"      deny  MultiEdit  "$MASTER_ROOT/ops/work/main.go"
test_tool "Edit a master root file"      deny  Edit       "$MASTER_ROOT/README.md"
test_tool "Edit a nested master file"    deny  Edit       "$MASTER_ROOT/docs/project/active-work/tracks/foo.yaml"

echo "== ALLOWED (per-session worktree paths) =="
test_tool "Edit inside a worktree"       allow Edit       "$MASTER_ROOT/.claude/worktrees/foo/CLAUDE.md"
test_tool "Write inside a worktree"      allow Write      "$MASTER_ROOT/.claude/worktrees/bar/baz.txt"
test_tool "MultiEdit inside a worktree"  allow MultiEdit  "$MASTER_ROOT/.claude/worktrees/x/y.go"

echo "== ALLOWED (paths outside the repo) =="
test_tool "Edit a /tmp file"             allow Edit       "/tmp/scratch.txt"
test_tool "Write to user home"           allow Write      "$HOME/.claude/projects/foo/memory/bar.md"

echo "== ALLOWED (non-Edit/Write tools) =="
test_tool "Bash tool (handled by sibling guard)" allow Bash "$MASTER_ROOT/CLAUDE.md"
test_tool "Read tool (read-only)"                allow Read "$MASTER_ROOT/CLAUDE.md"

echo "== OVERRIDE =="
test_tool_env "override env var allows master write" allow Edit \
  "$MASTER_ROOT/CLAUDE.md" AGENT_ALLOW_MASTER_WRITE=1
test_tool_env "GOAT_ alias allows master write" allow Edit \
  "$MASTER_ROOT/CLAUDE.md" GOAT_ALLOW_MASTER_WRITE=1

echo "== MARKER GATING =="
PLAIN_RESULT=$(cd "$FIX_PLAIN" && jq -n --arg p "$FIX_PLAIN/README.md" '{tool_name:"Edit",tool_input:{file_path:$p}}' | "$HOOK")
if [ -z "$PLAIN_RESULT" ]; then echo "PASS  [allow]  repo without the marker: guard off"; PASSES=$((PASSES + 1))
else echo "FAIL  guard fired in a repo without the marker"; FAILS=$((FAILS + 1)); fi

echo "----"
echo "passes=$PASSES fails=$FAILS"
if [ "$FAILS" -gt 0 ]; then
  exit 1
fi
