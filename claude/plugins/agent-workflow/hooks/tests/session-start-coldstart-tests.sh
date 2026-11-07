#!/usr/bin/env bash
# Regression fixture for session-start-coldstart.sh.
# Hermetic: runs against a temp repo, never the real one. Exits non-zero on the first failed expectation summary.

set -euo pipefail

. "$(dirname "$0")/fixture.sh"
HOOK="$HOOKS/session-start-coldstart.sh"
TOOL="$PLUGIN_ROOT/bin/coldstart"
[ -x "$HOOK" ] && [ -x "$TOOL" ] || { echo "ERROR: hook or tool not executable" >&2; exit 2; }

FAILS=0; PASSES=0
expect() { # expect "<description>" <command...>
  local what="$1"; shift
  if "$@"; then PASSES=$((PASSES + 1)); else FAILS=$((FAILS + 1)); echo "FAIL: $what" >&2; fi
}

REPO="$FIX_PLAIN"; mkdir -p "$REPO/.claude"

# 1. no marker: no output, exit 0
out="$(CLAUDE_PROJECT_DIR="$REPO" "$HOOK")"; expect "no output with no marker" [ -z "$out" ]

# 2. a marker without '## Then' is refused
refuses() { ! printf '## Run\ntrue\n' | "$TOOL" leave "$REPO" 2>/dev/null; }
expect "a marker without ## Then is refused" refuses

# 3. a marker fires: context carries the Then text, the Run line runs, the marker is flushed
printf '# t\n\n## Run\necho ran > "%s/ran"\n\n## Then\n1. resume the queue\n' "$REPO" | "$TOOL" leave "$REPO" >/dev/null
out="$(CLAUDE_PROJECT_DIR="$REPO" "$HOOK")"
has_then() { echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "resume the queue" in d["hookSpecificOutput"]["additionalContext"]'; }
expect "context carries the Then text" has_then
expect "marker flushed" [ ! -f "$REPO/.claude/coldstart.md" ]
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$REPO/ran" ] && break; sleep 0.2; done
expect "Run line ran" [ -f "$REPO/ran" ]

# 4. fires once: a second start prints nothing
out="$(CLAUDE_PROJECT_DIR="$REPO" "$HOOK")"; expect "fires once" [ -z "$out" ]

# 5. opt-out
printf '## Then\n1. x\n' | "$TOOL" leave "$REPO" >/dev/null
out="$(AGENT_COLDSTART=off CLAUDE_PROJECT_DIR="$REPO" "$HOOK")"
expect "AGENT_COLDSTART=off prints nothing" [ -z "$out" ]
expect "AGENT_COLDSTART=off leaves the marker" [ -f "$REPO/.claude/coldstart.md" ]
out="$(GOAT_COLDSTART=off CLAUDE_PROJECT_DIR="$REPO" "$HOOK")"
expect "GOAT_COLDSTART=off (alias) prints nothing" [ -z "$out" ]

# 6. a repo that wires its own coldstart hook: the plugin copy stays silent
printf '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"x/session-start-coldstart.sh"}]}]}}' > "$REPO/.claude/settings.json"
out="$(CLAUDE_PROJECT_DIR="$REPO" "$HOOK")"
expect "repo-wired copy wins" [ -z "$out" ]
expect "repo-wired copy wins: marker untouched" [ -f "$REPO/.claude/coldstart.md" ]

echo "session-start-coldstart: $PASSES passed, $FAILS failed"
[ "$FAILS" = 0 ]
