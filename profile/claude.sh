#!/usr/bin/env bash

# Claude Code agent workflow: puts dots' agent-tools on PATH and adds
# `claude-adopt`, which switches a repo onto the workflow. The plugin itself
# (claude/plugins/agent-workflow) is enabled once, at user scope; see
# claude/README.md.

_dots_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
export DOTS_AGENT_TOOLS="$_dots_root/agent-tools"
case ":$PATH:" in
  *":$DOTS_AGENT_TOOLS/bin:"*) ;;
  *) export PATH="$PATH:$DOTS_AGENT_TOOLS/bin" ;;
esac
unset _dots_root

# Runtime state the workflow writes inside a repo; never committed.
_claude_adopt_ignores=(
  ".claude/worktrees/"
  ".claude/handoff/"
  ".claude/coldstart.md"
  ".claude/coldstart.consumed/"
  ".iso-mode.env"
)

# @desc Switch the current repo onto the agent workflow (marker, ignores, optional CI gates and memory seeds)
# @usage claude-adopt [--local] [--bus <name>] [--no-master-guards] [--ci] [--seed-memories] [--dry-run]
claude-adopt() {
  local local_only=0 bus="" guards=true ci=0 seed=0 dry=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --local) local_only=1 ;;
      --bus) bus="$2"; shift ;;
      --no-master-guards) guards=false ;;
      --ci) ci=1 ;;
      --seed-memories) seed=1 ;;
      --dry-run) dry=1 ;;
      -h|--help)
        cat <<'EOF'
claude-adopt [--local] [--bus <name>] [--no-master-guards] [--ci] [--seed-memories] [--dry-run]

  (default)           write .claude/agent-workflow.yaml and the runtime-state .gitignore lines
                      (both to be committed): the plugin's worktree guards, session bus, handoff
                      nudges and tracker context switch on for this repo
  --local             only add the runtime-state lines to .git/info/exclude (nothing to commit,
                      nothing switched on); what `clone` runs after every clone
  --bus <name>        put the repo on a named bus shared with sibling repos
  --no-master-guards  marker with master_readonly: false (bus and tracker on, worktree guards off)
  --ci                copy the CI gate templates to .github/agent-workflow/ and add a workflow
  --seed-memories     seed the workflow's feedback memories into this project's memory directory
  --dry-run           print what would change
EOF
        return 0 ;;
      *) echo "claude-adopt: unknown argument $1" >&2; return 2 ;;
    esac
    shift
  done

  local common root
  common="$(git rev-parse --git-common-dir 2>/dev/null)" || { echo "claude-adopt: not in a git repo" >&2; return 1; }
  common="$(cd "$common" && pwd)"
  root="$(git rev-parse --show-toplevel)"

  _ca_do() { if [ "$dry" = 1 ]; then echo "would: $*"; else "$@"; fi; }
  _ca_add_lines() { # file line...
    local f="$1" l; shift
    for l in "$@"; do
      grep -qxF "$l" "$f" 2>/dev/null && continue
      if [ "$dry" = 1 ]; then echo "would add to ${f#"$root"/}: $l"; else printf '%s\n' "$l" >> "$f"; echo "added to ${f#"$root"/}: $l"; fi
    done
  }

  if [ "$local_only" = 1 ]; then
    [ "$dry" = 1 ] || mkdir -p "$common/info"
    _ca_add_lines "$common/info/exclude" "${_claude_adopt_ignores[@]}"
    return 0
  fi

  local marker="$root/.claude/agent-workflow.yaml"
  if [ -f "$marker" ]; then
    echo "marker present: .claude/agent-workflow.yaml (left as is)"
  elif [ "$dry" = 1 ]; then
    echo "would write .claude/agent-workflow.yaml (master_readonly: $guards${bus:+, bus: $bus})"
  else
    mkdir -p "$root/.claude"
    {
      echo "# agent-workflow: this repo uses per-session worktrees, the session bus and the work tracker."
      echo "# Every key is optional; these are the defaults. See dots agent-tools/work/README.md."
      echo "version: 1"
      echo "master_readonly: $guards"
      echo "worktrees_dir: .claude/worktrees"
      echo "tracker_dir: docs/project/active-work"
      echo "roles_dir: ops/work/roles"
      local trunk; trunk="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
      echo "trunk: ${trunk#origin/}" | sed 's/^trunk: $/trunk: main/'
      [ -n "$bus" ] && echo "bus: $bus"
    } > "$marker"
    echo "wrote .claude/agent-workflow.yaml"
  fi
  _ca_add_lines "$root/.gitignore" "${_claude_adopt_ignores[@]}"

  if [ "$ci" = 1 ]; then
    _ca_do mkdir -p "$root/.github/agent-workflow" "$root/.github/workflows"
    _ca_do cp "$DOTS_AGENT_TOOLS"/ci/check-*.sh "$root/.github/agent-workflow/"
    if [ -f "$root/.github/workflows/agent-workflow.yml" ]; then
      echo "workflow present: .github/workflows/agent-workflow.yml (left as is)"
    else
      _ca_do cp "$DOTS_AGENT_TOOLS/ci/agent-workflow.yml" "$root/.github/workflows/agent-workflow.yml"
    fi
  fi
  if [ "$seed" = 1 ]; then
    if [ "$dry" = 1 ]; then aw-seed-memories --dry-run "${common%/.git}"; else aw-seed-memories "${common%/.git}"; fi
  fi
  [ "$dry" = 1 ] || echo "review and commit: git -C \"$root\" status --short"
}
