#!/usr/bin/env bash
# PreToolUse hook (opt-in by marker) — refuse Edit/Write/MultiEdit/NotebookEdit on
# paths inside the master (main) worktree.
#
# Active only when the repo carries .claude/agent-workflow.yaml and its
# `master_readonly` is not `false`. Edits belong in a per-session worktree under
# the marker's `worktrees_dir` (default .claude/worktrees/<name>/), so concurrent
# sessions cannot collide and the master tree stays a clean fast-forward target.
#
# Allows: the same tools on paths inside a per-session worktree, paths outside the
# repo (/tmp, ~/.claude, ...), and every other tool.
#
# Operator override, session-wide (Edit/Write calls carry no command string):
#   AGENT_ALLOW_MASTER_WRITE=1 claude          (alias GOAT_ALLOW_MASTER_WRITE=1)
#
# Input: JSON on stdin (Claude Code PreToolUse schema).
# Output: JSON on stdout. Exit 0 always; permissionDecision controls allow/deny.

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

aw_has_marker || exit 0
[ "$(aw_get master_readonly true)" = "false" ] && exit 0
aw_repo_registers pretooluse-master-worktree-write-guard.sh && exit 0

INPUT="$(cat)"

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
case "$TOOL_NAME" in
  Edit|Write|MultiEdit|NotebookEdit) ;;
  *) exit 0 ;;
esac

[ "$(aw_env AGENT_ALLOW_MASTER_WRITE GOAT_ALLOW_MASTER_WRITE 0)" = "1" ] && exit 0

# Write/Edit/MultiEdit name the field file_path; NotebookEdit names it notebook_path.
TARGET="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
[ -n "$TARGET" ] || exit 0

case "$TARGET" in
  /*) ABS="$TARGET" ;;
  *)  ABS="${PWD}/${TARGET}" ;;
esac

MASTER_ROOT="$(aw_master_root)"
[ -n "$MASTER_ROOT" ] || exit 0

case "$ABS" in
  "$MASTER_ROOT"/*|"$MASTER_ROOT") ;;
  *) exit 0 ;;  # outside the repo
esac

WT_DIR="$(aw_get worktrees_dir .claude/worktrees)"
WT_DIR="${WT_DIR%/}"
case "$ABS" in
  "$MASTER_ROOT/$WT_DIR"/*) exit 0 ;;  # inside a per-session worktree
esac

REASON="Refused: $TOOL_NAME against a path inside the master worktree.

Target:        $ABS
Master root:   $MASTER_ROOT

This repo keeps its master worktree read-only (.claude/agent-workflow.yaml).
Edits belong in a per-session worktree under $WT_DIR/<name>/, so concurrent
sessions cannot collide and master stays a clean fast-forward target.

Provision one before editing:

  /iso enter <track-name>

That creates $WT_DIR/<name>/ on branch track/<name> from the trunk and moves
the session's operating directory there.

If this edit is truly meant for master (rare: cleaning up after another
session), the operator sets the override before starting Claude Code:

  AGENT_ALLOW_MASTER_WRITE=1 claude"

aw_deny "$REASON"
exit 0
