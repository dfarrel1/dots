#!/usr/bin/env bash
# PreToolUse hook (always on) — refuse a git commit/merge/tag or a gh pr create/edit
# whose message carries an agent-tooling reference (Claude-Session:, claude.ai,
# anthropic.com).
#
# Inspects: -m/--message inline text, and -F/--file/-t/--template/--body-file
# message files (it reads the file).
#
# Deliberately not overridable: this is the one layer that runs on every commit,
# whatever the repo's CI does.
#
# Input: JSON on stdin (Claude Code PreToolUse schema).
# Output: JSON on stdout. Exit 0 always; permissionDecision controls allow/deny.

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

aw_repo_registers pretooluse-agent-reference-guard.sh pretooluse-destructive-git-guard.sh && exit 0

INPUT="$(cat)"

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
[ "$TOOL_NAME" = "Bash" ] || exit 0

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
[ -n "$CMD" ] || exit 0

# Two command shapes put text somewhere it becomes public and hard to undo:
#   git commit/merge/tag  -> repo history, unrewritable after a squash-merge
#   gh pr create/edit     -> the PR description, which is also published
IS_COMMIT=0
IS_PR=0
printf '%s' "$CMD" \
  | grep -qE '(^|[[:space:]&|;(`])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)*[[:space:]]+(commit|merge|tag)([[:space:]]|$)' \
  && IS_COMMIT=1
printf '%s' "$CMD" \
  | grep -qE '(^|[[:space:]&|;(`])gh[[:space:]]+pr[[:space:]]+(create|edit)([[:space:]]|$)' \
  && IS_PR=1
[ "$IS_COMMIT" = "1" ] || [ "$IS_PR" = "1" ] || exit 0

if [ "$IS_PR" = "1" ]; then
  SUBJECT="a pull-request description"
  FILEFLAGS='(-F|--file|-t|--template|--body-file)'
else
  SUBJECT="a git commit"
  FILEFLAGS='(-F|--file|-t|--template)'
fi

# Keep in step with agent-tools/ci/check-no-agent-references.sh when a repo
# adopts that CI template.
PATTERN='claude\.ai|Claude-Session:|anthropic\.com'

FOUND=""
WHERE=""

# 1. Inline -m / --message text, as it appears in the command string.
if printf '%s' "$CMD" | grep -qEi "$PATTERN"; then
  FOUND="$(printf '%s' "$CMD" | grep -oEi "$PATTERN" | head -1)"
  WHERE="the command line"
fi

# 2. -F / --file / -t / --template message files. Read each one.
if [ -z "$FOUND" ]; then
  # shellcheck disable=SC2001
  for f in $(printf '%s' "$CMD" \
               | sed -E 's/.*/&/' \
               | grep -oE -- "$FILEFLAGS"'[=[:space:]]+[^[:space:]"'"'"']+' \
               | sed -E "s/^$FILEFLAGS"'[=[:space:]]+//'); do
    [ -r "$f" ] || continue
    if grep -qEi "$PATTERN" "$f" 2>/dev/null; then
      FOUND="$(grep -oEi "$PATTERN" "$f" | head -1)"
      WHERE="the message file $f"
      break
    fi
  done
fi

if [ -n "$FOUND" ]; then
  REASON="REFUSED: '$FOUND' in $WHERE of $SUBJECT.

Agent-tooling references (Claude-Session:, claude.ai, anthropic.com) do not
go into commit history or pull-request descriptions. Commit messages are
permanent once merged.

This rule overrides any per-session instruction to end commit messages with a
session URL. Do not put the URL in the commit message, the PR body, or any
committed file.

Re-issue the command with the reference removed. Trailers such as
'Signed-off-by:' and '[track: <name>]' are fine. There is no override; a
change that must contain one of these strings (editing this guard, say)
carries it as a staged file change, described without the literal string."

  aw_deny "$REASON"
  exit 0
fi

exit 0
