# lib.sh — shared helpers for the agent-workflow plugin hooks. Sourced, never run.
#
# Two rules every hook follows:
#   1. A repo-shaped hook (worktree guards, bus, handoff nudges, tracker context)
#      does nothing unless the repo carries the marker .claude/agent-workflow.yaml.
#      In an ordinary clone every file sits in the "master worktree", so those
#      hooks would refuse every edit.
#   2. A hook does nothing when the repo's own .claude/settings.json already
#      registers the same hook. During a migration the repo copy and the plugin
#      copy would otherwise both run: guards fire twice and the bus hook delivers
#      every message twice.
#
# Knob names: AGENT_* is the name; the older GOAT_* name is accepted as an alias.

# aw_toplevel — the current worktree's top level, empty outside git.
aw_toplevel() { git rev-parse --show-toplevel 2>/dev/null || true; }

# aw_master_root — the main worktree of the current repository (the parent of the
# common git dir), the same from the main worktree and from every linked one.
aw_master_root() {
  local common
  common="$(git rev-parse --git-common-dir 2>/dev/null || true)"
  [ -n "$common" ] || { aw_toplevel; return; }
  common="$(cd "$common" 2>/dev/null && pwd)" || { aw_toplevel; return; }
  case "$common" in
    */.git) printf '%s\n' "${common%/.git}" ;;
    *) aw_toplevel ;;
  esac
}

# aw_project_root — where Claude Code was started: CLAUDE_PROJECT_DIR, else the top level.
aw_project_root() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then printf '%s\n' "$CLAUDE_PROJECT_DIR"; else aw_toplevel; fi
}

# aw_marker — path of the repo's marker file, empty when there is none.
aw_marker() {
  local d
  for d in "$(aw_toplevel)" "$(aw_master_root)" "${CLAUDE_PROJECT_DIR:-}"; do
    [ -n "$d" ] && [ -f "$d/.claude/agent-workflow.yaml" ] && { printf '%s\n' "$d/.claude/agent-workflow.yaml"; return 0; }
  done
  return 1
}

aw_has_marker() { aw_marker >/dev/null 2>&1; }

# aw_get <key> <default> — a top-level scalar from the marker. The marker is a flat
# "key: value" file; quotes and trailing comments are stripped.
aw_get() {
  local key="$1" def="${2:-}" m v
  m="$(aw_marker 2>/dev/null || true)"
  if [ -n "$m" ]; then
    v="$(sed -n -E "s/^${key}:[[:space:]]*//p" "$m" | head -1 | sed -E 's/[[:space:]]+#.*$//; s/^["'\'']//; s/["'\'']$//; s/[[:space:]]+$//')"
  fi
  printf '%s\n' "${v:-$def}"
}

# aw_repo_registers <needle>... — true when the repo's own Claude settings already
# wire a hook carrying any needle (a script basename, or a distinctive phrase of an
# inline context hook).
aw_repo_registers() {
  local d f n
  for d in "$(aw_project_root)" "$(aw_toplevel)" "$(aw_master_root)"; do
    [ -n "$d" ] || continue
    for f in "$d/.claude/settings.json" "$d/.claude/settings.local.json"; do
      [ -f "$f" ] || continue
      for n in "$@"; do
        grep -qF -- "$n" "$f" 2>/dev/null && return 0
      done
    done
  done
  return 1
}

# aw_env <NEW> <OLD> <default> — the value of $NEW, else $OLD, else default.
aw_env() {
  local new="$1" old="$2" def="${3:-}"
  local nv="${!new:-}" ov="${!old:-}"
  printf '%s\n' "${nv:-${ov:-$def}}"
}

# aw_cmd_has_override <NEW> <OLD> <command> — true when the command string itself
# carries NEW=1 or OLD=1 as an assignment (a deliberate, per-invocation override).
aw_cmd_has_override() {
  printf '%s' "$3" | grep -qE "(^|[[:space:]])($1|$2)=1([[:space:]]|\$)"
}

# aw_deny <reason> — print a PreToolUse deny decision.
aw_deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
}
