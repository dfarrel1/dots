#!/usr/bin/env bash
# check-no-agent-references.sh — CI template: refuse agent-tooling references
# (claude.ai URLs, Claude-Session: trailers, anthropic.com URLs, markdown links
# into a local agent-memory directory) in committed files outside the paths that
# exist for the tooling, and in commit messages of a range.
#
#   check-no-agent-references.sh                  scan the tracked tree
#   check-no-agent-references.sh --staged         scan staged files
#   check-no-agent-references.sh --commits A..B   scan commit messages in a range
#   check-no-agent-references.sh --census         report every hit, never fail
#
# Allowed paths: CLAUDE.md anywhere, .claude/, this script, and one glob per
# line in .agent-references-allow at the repo root.
set -uo pipefail

PATTERN='claude\.ai|Claude-Session:|anthropic\.com|\]\([^)]*\.claude/projects'
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
SELF="$(git ls-files --full-name -- "$0" 2>/dev/null || true)"

allowed() {
  case "$1" in
    CLAUDE.md|*/CLAUDE.md|.claude/*|*/.claude/*) return 0 ;;
  esac
  [ -n "$SELF" ] && [ "$1" = "$SELF" ] && return 0
  if [ -f .agent-references-allow ]; then
    local g
    while IFS= read -r g; do
      case "$g" in ''|'#'*) continue ;; esac
      # shellcheck disable=SC2254
      case "$1" in $g) return 0 ;; esac
    done < .agent-references-allow
  fi
  return 1
}

MODE=tree; CENSUS=0; RANGE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --staged) MODE=staged ;;
    --census) CENSUS=1 ;;
    --commits) MODE=commits; RANGE="${2:?--commits needs a range}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ "$MODE" = commits ]; then
  bad="$(git log --format='%H %B' "$RANGE" | grep -nE "$PATTERN" || true)"
  if [ -n "$bad" ]; then
    echo "refused: agent-tooling references in commit messages of $RANGE:"; printf '%s\n' "$bad" | head -10
    [ "$CENSUS" = 1 ] && exit 0; exit 1
  fi
  echo "ok: no agent-tooling references in commit messages of $RANGE"; exit 0
fi

if [ "$MODE" = staged ]; then
  FILES="$(git diff --cached --name-only --diff-filter=ACM | while IFS= read -r f; do
    [ -f "$f" ] && grep -lIEq "$PATTERN" "$f" 2>/dev/null && printf '%s\n' "$f"; done)"
else
  FILES="$(git grep -lIE "$PATTERN" -- . 2>/dev/null || true)"
fi

hits=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if allowed "$f"; then [ "$CENSUS" = 1 ] && printf '  allowed  %s\n' "$f"; continue; fi
  hits=$((hits + 1)); printf '  REFUSED  %s\n' "$f"
  grep -nE "$PATTERN" "$f" | head -3 | sed 's/^/             /'
done <<< "$FILES"

[ "$CENSUS" = 1 ] && { echo "census: $hits file(s) outside the allowlist"; exit 0; }
if [ "$hits" -gt 0 ]; then
  echo; echo "refused: remove the reference, or add the path to .agent-references-allow if the file exists for the tooling."
  exit 1
fi
echo "ok: no agent-tooling references outside the allowlist"
