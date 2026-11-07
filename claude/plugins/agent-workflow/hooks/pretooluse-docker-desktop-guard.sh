#!/usr/bin/env bash
# PreToolUse hook (always on) — refuse Bash commands that launch Docker Desktop
# or a peer container VM (colima, lima, orbstack) on this machine.
#
# Refuses (Bash tool only):
#   open -a Docker / open -a "Docker Desktop" / open ... Docker.app
#   docker desktop start
#   colima start / limactl start / orb start / orbctl start
# Allows plain `docker ...` CLI calls (they fail harmlessly when no daemon runs).
#
# Operator override, single-shot, in the command string:
#   AGENT_ALLOW_DOCKER_DESKTOP=1 <command>     (alias GOAT_ALLOW_DOCKER_DESKTOP=1)
#
# Input: JSON on stdin (Claude Code PreToolUse schema).
# Output: JSON on stdout. Exit 0 always; permissionDecision controls allow/deny.

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

aw_repo_registers pretooluse-docker-desktop-guard.sh pretooluse-destructive-git-guard.sh && exit 0

INPUT="$(cat)"

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
if [ -z "$CMD" ]; then
  exit 0
fi

# Machine-wide opt-out (operator-set only; agents must not create it):
#   touch "${XDG_CONFIG_HOME:-$HOME/.config}/agent-workflow/docker-desktop-allowed"
# or AGENT_DOCKER_DESKTOP_OK=1 (alias GOAT_DOCKER_DESKTOP_OK=1) in the session
# environment. AGENT_DOCKER_DESKTOP_SENTINELS adds more sentinel files
# (colon-separated, a leading ~ is expanded), for a machine that already has one
# under another name.
if [ "$(aw_env AGENT_DOCKER_DESKTOP_OK GOAT_DOCKER_DESKTOP_OK 0)" = "1" ]; then
  exit 0
fi
SENTINELS="${XDG_CONFIG_HOME:-$HOME/.config}/agent-workflow/docker-desktop-allowed:${AGENT_DOCKER_DESKTOP_SENTINELS:-}"
IFS=: read -r -a _sentinels <<< "$SENTINELS"
for _s in "${_sentinels[@]}"; do
  [ -n "$_s" ] || continue
  case "$_s" in "~/"*) _s="$HOME/${_s#"~/"}" ;; esac
  [ -f "$_s" ] && exit 0
done

# Single-shot operator override in the command string itself.
if aw_cmd_has_override AGENT_ALLOW_DOCKER_DESKTOP GOAT_ALLOW_DOCKER_DESKTOP "$CMD"; then
  exit 0
fi

MATCH=""

# open -a Docker / "Docker Desktop" / any path ending in Docker.app
if printf '%s' "$CMD" | grep -qiE '(^|[[:space:]&|;(`])open[[:space:]]+[^&|;]*(-a[[:space:]]+["'"'"']?Docker(\.app|[[:space:]]?Desktop)?["'"'"']?([[:space:];&|)`]|$|["'"'"'])|Docker\.app)'; then
  MATCH="open Docker Desktop"
fi

# docker desktop start
if [ -z "$MATCH" ] && printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;(`])docker[[:space:]]+desktop[[:space:]]+start'; then
  MATCH="docker desktop start"
fi

# colima / limactl / orbstack VM start
if [ -z "$MATCH" ] && printf '%s' "$CMD" | grep -qE '(^|[[:space:]&|;(`])(colima|limactl|orb|orbctl)[[:space:]]+start'; then
  MATCH="container VM start (colima/lima/orbstack)"
fi

if [ -n "$MATCH" ]; then
  REASON="REFUSED: '$MATCH' — launching Docker Desktop or a container VM is blocked for agent sessions.

A container VM takes a large share of the machine's memory and CPU for as long
as it runs, and every other session on the machine pays for it. Starting one
is a machine-wide decision for the operator, not a side effect of one task.

Do not retry with the override on your own. Instead:

  - Tell the operator you need it and what for (image build, compose stack),
    and let them decide and start it.
  - Prefer building on a remote host or in CI.
  - If the operator approves, they start it themselves or tell you to prefix
    the command with: AGENT_ALLOW_DOCKER_DESKTOP=1 <command>"

  aw_deny "$REASON"
  exit 0
fi

exit 0
