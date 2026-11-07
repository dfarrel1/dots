# fixture.sh — sourced by every hook test. Builds a hermetic temp repo that has
# adopted the workflow (it carries .claude/agent-workflow.yaml), cds into it, and
# clears anything from the calling session that would change a hook's answer.
#
# Exports: HOOKS (the hooks directory), PLUGIN_ROOT, FIX_ROOT (temp dir, removed
# on exit), FIX_REPO (the adopted repo, the cwd), FIX_PLAIN (a repo without the
# marker).

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="$(cd "$HOOKS/.." && pwd)"
unset CLAUDE_PROJECT_DIR AGENT_ALLOW_DESTRUCTIVE_GIT GOAT_ALLOW_DESTRUCTIVE_GIT \
      AGENT_ALLOW_MASTER_WRITE GOAT_ALLOW_MASTER_WRITE AGENT_ALLOW_MASTER_GIT_MUTATE \
      GOAT_ALLOW_MASTER_GIT_MUTATE AGENT_DOCKER_DESKTOP_OK GOAT_DOCKER_DESKTOP_OK \
      AGENT_DOCKER_DESKTOP_SENTINELS AGENT_COLDSTART GOAT_COLDSTART
FIX_ROOT="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$FIX_ROOT"' EXIT
FIX_REPO="$FIX_ROOT/repo"
FIX_PLAIN="$FIX_ROOT/plain"
for _r in "$FIX_REPO" "$FIX_PLAIN"; do
  git init -q -b main "$_r"
  git -C "$_r" -c user.email=t@t.test -c user.name=t commit -q --allow-empty -m init
done
mkdir -p "$FIX_REPO/.claude"
printf 'version: 1\nworktrees_dir: .claude/worktrees\n' > "$FIX_REPO/.claude/agent-workflow.yaml"
cd "$FIX_REPO"
