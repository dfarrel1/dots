#!/usr/bin/env bash
# PreToolUse hook (always on) — refuse destructive git/rm patterns on the Bash tool.
#
# Refuses commands that can destroy uncommitted work without warning: reset --hard,
# push --force (not --force-with-lease), branch -D, checkout ., restore ., clean -f,
# rm -rf .git, worktree remove --force, and every mutating git stash subcommand
# (refs/stash is one ref shared by every worktree and every concurrent session).
#
# Operator override, single-shot, in the command string itself:
#   AGENT_ALLOW_DESTRUCTIVE_GIT=1 git reset --hard origin/main
# GOAT_ALLOW_DESTRUCTIVE_GIT=1 is accepted as an alias.
#
# Input: JSON on stdin (Claude Code PreToolUse schema).
# Output: JSON on stdout. Exit 0 always; permissionDecision controls allow/deny.

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# The repo still wires its own copy of this guard: let that one decide.
aw_repo_registers pretooluse-destructive-git-guard.sh && exit 0

INPUT="$(cat)"

# Only inspect Bash tool calls; everything else passes through unchanged.
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
if [ -z "$CMD" ]; then
  exit 0
fi

# Operator override: must appear as an assignment in the command itself.
if aw_cmd_has_override AGENT_ALLOW_DESTRUCTIVE_GIT GOAT_ALLOW_DESTRUCTIVE_GIT "$CMD"; then
  exit 0
fi

# Match the destructive patterns. Each pattern is anchored to the start of a
# subshell or chained command so substrings inside comments / strings don't
# spuriously match. We deliberately accept some false-positive risk in favor
# of refusal-by-default.
MATCH=""

# git reset --hard (anywhere)
if printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?reset[[:space:]]+(.+[[:space:]])?--hard'; then
  MATCH="git reset --hard"
fi

# git push --force / -f, NOT --force-with-lease
if [ -z "$MATCH" ] && printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push[[:space:]]+'; then
  if printf '%s' "$CMD" | grep -qE 'push[[:space:]]+([^&|;]*[[:space:]])?(--force([[:space:]]|$)|-f([[:space:]]|$))'; then
    # Allow --force-with-lease (safer; refuses stale-base overwrite).
    if ! printf '%s' "$CMD" | grep -qE 'push[[:space:]]+([^&|;]*[[:space:]])?--force-with-lease'; then
      MATCH="git push --force (without --force-with-lease)"
    fi
  fi
fi

# git branch -D / --delete --force
if [ -z "$MATCH" ] && printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?branch[[:space:]]+([^&|;]*[[:space:]])?(-D([[:space:]]|$)|--delete[[:space:]]+--force([[:space:]]|$)|-d[[:space:]]+--force([[:space:]]|$))'; then
  MATCH="git branch -D (force-delete branch)"
fi

# git checkout -- . / git checkout .  (discards all unstaged in CWD)
if [ -z "$MATCH" ] && printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?checkout[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)'; then
  MATCH="git checkout . (discards all unstaged)"
fi

# git restore .  WITHOUT --staged  (discards unstaged worktree changes)
if [ -z "$MATCH" ] && printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?restore[[:space:]]+'; then
  # Allow --staged (only unstages, doesn't touch worktree).
  if ! printf '%s' "$CMD" | grep -qE 'restore[[:space:]]+([^&|;]*[[:space:]])?--staged'; then
    if printf '%s' "$CMD" | grep -qE 'restore[[:space:]]+([^&|;]*[[:space:]])?\.([[:space:]]|$)'; then
      MATCH="git restore . (discards unstaged worktree changes)"
    fi
  fi
fi

# git clean -f / -fd / -fdx / -ff
if [ -z "$MATCH" ] && printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?clean[[:space:]]+([^&|;]*[[:space:]])?-[a-z]*f'; then
  MATCH="git clean -f (deletes untracked files)"
fi

# rm -rf .git  (total repo destruction)
if [ -z "$MATCH" ] && printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;])rm[[:space:]]+([^&|;]*[[:space:]])?-[a-z]*[rR]f?[a-z]*[[:space:]]+([^&|;]*[[:space:]])?\.git([[:space:]]|/|$)'; then
  MATCH="rm -rf .git (destroys repository)"
fi

# git worktree remove --force (drops uncommitted work in a sibling worktree)
if [ -z "$MATCH" ] && printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?worktree[[:space:]]+remove[[:space:]]+([^&|;]*[[:space:]])?(--force|-f)([[:space:]]|$)'; then
  MATCH="git worktree remove --force (drops uncommitted work in sibling worktree)"
fi

# git stash mutations — refs/stash is repo-global, shared by every worktree and
# every concurrent session, so a pop in one session can take another's work.
# Read-only `list` and `show` stay allowed.
if [ -z "$MATCH" ] && printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?stash([[:space:]]|$)'; then
  # Allow read-only subcommands.
  if ! printf '%s' "$CMD" | grep -qE 'stash[[:space:]]+(list|show)([[:space:]]|$)'; then
    MATCH="git stash (mutating subcommand — stash list is repo-global, shared across sessions)"
  fi
fi

if [ -n "$MATCH" ]; then
  REASON="Destructive operation refused: ${MATCH}.

This command can overwrite or delete uncommitted work without warning, and
refs/stash is shared by every worktree and every concurrent session.

Use the coordination primitives instead:

  - Your per-session worktree is the isolation. Keep work-in-progress
    uncommitted there; no other session can see or pop it.
  - To carry state across a session boundary, use /handoff: it writes a
    'wip(<track>): handoff baton' commit on your track branch.
  - To keep state across an operation that rewrites your branch: note the SHA,
    tag it ('git tag wip/before-<x> HEAD'), or commit 'wip(<track>): ...'.
    The reflog also keeps it for 90 days.
  - Inspect first with 'git status' / 'git diff'; use
    'git push --force-with-lease' instead of --force; 'git restore --staged
    <path>' to unstage only.

If the destructive action is truly intended, prefix the command with:
  AGENT_ALLOW_DESTRUCTIVE_GIT=1 <your command>

Confirm with the operator before using the override on a tree carrying
uncommitted work."

  aw_deny "$REASON"
  exit 0
fi

exit 0
