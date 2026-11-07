#!/usr/bin/env bash
# Regression fixture for pretooluse-docker-desktop-guard.sh.
# Exits non-zero on first failed expectation.

set -euo pipefail

. "$(dirname "$0")/fixture.sh"
HOOK="$HOOKS/pretooluse-docker-desktop-guard.sh"

if [ ! -x "$HOOK" ]; then
  echo "ERROR: hook not executable at $HOOK" >&2
  exit 2
fi

FAILS=0
PASSES=0

# Hermetic homes: CLEAN_HOME has no opt-out marker (guard armed regardless of
# this machine's real config); OPTOUT_HOME carries the marker file.
CLEAN_HOME="$(mktemp -d)"
OPTOUT_HOME="$(mktemp -d)"
mkdir -p "$OPTOUT_HOME/.config/agent-workflow"
touch "$OPTOUT_HOME/.config/agent-workflow/docker-desktop-allowed"
LEGACY_HOME="$(mktemp -d)"
mkdir -p "$LEGACY_HOME/.legacy/state"
touch "$LEGACY_HOME/.legacy/state/docker-desktop-allowed"
trap 'rm -rf "$CLEAN_HOME" "$OPTOUT_HOME" "$LEGACY_HOME" "$FIX_ROOT"' EXIT
TEST_SENTINELS=""

TEST_HOME="$CLEAN_HOME"
TEST_ENV_OK=""

test_cmd() {
  local label="$1" expected="$2" cmd="$3"
  local result
  result=$(printf '%s' "$(jq -n --arg cmd "$cmd" '{tool_name:"Bash",tool_input:{command:$cmd}}')" \
    | env -u GOAT_DOCKER_DESKTOP_OK -u AGENT_DOCKER_DESKTOP_OK -u XDG_CONFIG_HOME ${TEST_ENV_OK:+$TEST_ENV_OK=1} ${TEST_SENTINELS:+AGENT_DOCKER_DESKTOP_SENTINELS=$TEST_SENTINELS} HOME="$TEST_HOME" "$HOOK" 2>&1)
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
test_cmd "plain docker cli"                     allow "docker ps"
test_cmd "docker compose config"                allow "docker compose -f x.yml config"
test_cmd "docker build (daemon-down no-op)"     allow "docker build -t foo ."
test_cmd "open unrelated app"                   allow "open -a Safari https://example.com"
test_cmd "open a file"                          allow "open /tmp/report.html"
test_cmd "mention in string (grep)"             allow "grep -r 'docker daemon' docs/"
test_cmd "docker desktop status (not start)"    allow "docker desktop status"
test_cmd "colima status"                        allow "colima status"
test_cmd "operator override"                    allow "AGENT_ALLOW_DOCKER_DESKTOP=1 open -a Docker"
test_cmd "operator override (GOAT_ alias)"      allow "GOAT_ALLOW_DOCKER_DESKTOP=1 open -a Docker"

echo
echo "== REFUSED =="
test_cmd "open -a Docker"                       deny  "open -a Docker"
test_cmd "open -a Docker chained"               deny  "open -a Docker 2>/dev/null && echo up"
test_cmd "open -a 'Docker Desktop' quoted"      deny  "open -a \"Docker Desktop\""
test_cmd "open Docker.app path"                 deny  "open /Applications/Docker.app"
test_cmd "open -g -a Docker.app"                deny  "open -g -a /Applications/Docker.app"
test_cmd "docker desktop start"                 deny  "docker desktop start"
test_cmd "colima start"                         deny  "colima start --cpu 4"
test_cmd "limactl start"                        deny  "limactl start default"
test_cmd "orb start"                            deny  "orb start"
test_cmd "mid-chain launch"                     deny  "echo hi; open -a Docker; echo bye"
test_cmd "subshell-paren launch" deny "ls -d /Applications/Docker.app 2>/dev/null && (open -a Docker 2>&1 && echo \"start requested\") || echo \"no Docker.app\""
test_cmd "backtick launch"                      deny  "echo \`open -a Docker\`"
test_cmd "subshell colima"                      deny  "(colima start)"

echo
echo "== MACHINE OPT-OUT =="
TEST_ENV_OK=AGENT_DOCKER_DESKTOP_OK
test_cmd "env opt-out allows launch"           allow "open -a Docker"
TEST_ENV_OK=GOAT_DOCKER_DESKTOP_OK
test_cmd "env opt-out (GOAT_ alias)"           allow "open -a Docker"
TEST_ENV_OK=""
TEST_HOME="$OPTOUT_HOME"
test_cmd "marker-file opt-out allows launch"   allow "open -a Docker"
TEST_HOME="$LEGACY_HOME"
test_cmd "legacy sentinel not honoured unless listed" deny "open -a Docker"
TEST_SENTINELS="~/.legacy/state/docker-desktop-allowed"
test_cmd "legacy sentinel listed in AGENT_DOCKER_DESKTOP_SENTINELS" allow "open -a Docker"
TEST_SENTINELS=""
TEST_HOME="$CLEAN_HOME"
test_cmd "re-armed after opt-out removed"      deny  "open -a Docker"

echo
echo "== SUMMARY =="
echo "PASS: $PASSES"
echo "FAIL: $FAILS"
if [ "$FAILS" -gt 0 ]; then exit 1; fi
exit 0
