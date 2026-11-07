#!/usr/bin/env bash
# run.sh — hermetic tests for agent-tools: aw-config, next-id, worktree-reap,
# closeout-check, aw-seed-memories, the git-hooks dispatcher and claude-adopt.
# Every repo, remote and HOME is a temp directory; nothing global is touched.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DOTS="$(cd "$HERE/.." && pwd)"
export PATH="$HERE/bin:$PATH"
unset CLAUDE_PROJECT_DIR GH_REPO
T="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL="$T/gitconfig"; : > "$GIT_CONFIG_GLOBAL"
git config --global user.email t@t.test; git config --global user.name t
git config --global init.defaultBranch main

PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); echo "ok    $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL  $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /' | head -15; }
check() { local label="$1"; shift; if "$@"; then ok "$label"; else bad "$label"; fi; }

newrepo() { # newrepo <dir> : repo with one commit and a bare origin
  git init -q "$1"; git -C "$1" commit -q --allow-empty -m init
  git init -q --bare "$1.origin.git"; git -C "$1" remote add origin "$1.origin.git"
  git -C "$1" push -q origin main; git -C "$1" fetch -q origin
}

# --- aw-config -------------------------------------------------------------
R="$T/cfg"; newrepo "$R"
check "aw-config: default without marker"   test "$(cd "$R" && aw-config trunk main)" = main
check "aw-config: --marker fails without one" bash -c "cd '$R' && ! aw-config --marker >/dev/null"
mkdir -p "$R/.claude"; printf 'trunk: develop  # comment\nbus: "team"\n' > "$R/.claude/agent-workflow.yaml"
check "aw-config: value, comment stripped"  test "$(cd "$R" && aw-config trunk main)" = develop
check "aw-config: quotes stripped"          test "$(cd "$R" && aw-config bus "")" = team
check "aw-config: --slug from origin"       test -n "$(cd "$R" && aw-config --slug)"
git -C "$R" remote add up git@example.invalid:some-org/some-repo.git
check "aw-config: --slug scp form"          test "$(cd "$R" && aw-config --slug up)" = some-org/some-repo

# --- next-id ---------------------------------------------------------------
R="$T/ids"; newrepo "$R"
mkdir -p "$R/docs/adr" "$R/docs/findings"; touch "$R/docs/adr/0007-a.md" "$R/docs/findings/F-012-x.md"
git -C "$R" add -A; git -C "$R" commit -q -m ids; git -C "$R" push -q origin main; git -C "$R" fetch -q origin
git -C "$R" checkout -q -b side; touch "$R/docs/adr/0009-b.md"; git -C "$R" add -A; git -C "$R" commit -q -m b
git -C "$R" push -q origin side; git -C "$R" fetch -q origin; git -C "$R" checkout -q main
out="$(cd "$R" && next-id 2>&1)"
check "next-id: sees the unmerged branch's ADR" grep -q 'ADR      0*10$\|ADR      10$' <<< "$out"
check "next-id: next finding"                    grep -q 'finding  F-013' <<< "$out"
mkdir -p "$R/.claude" "$R/records/decisions"; printf 'adr_dir: records/decisions\n' > "$R/.claude/agent-workflow.yaml"
touch "$R/records/decisions/0040-c.md"; git -C "$R" add -A; git -C "$R" commit -q -m c; git -C "$R" push -q origin main; git -C "$R" fetch -q origin
out="$(cd "$R" && next-id 2>&1)"
check "next-id: adr_dir from the marker"         grep -q 'ADR      41' <<< "$out"

# --- worktree-reap ---------------------------------------------------------
R="$T/reap"; newrepo "$R"
git -C "$R" worktree add -q "$R/.claude/worktrees/done" -b track/done origin/main 2>/dev/null
git -C "$R" worktree add -q "$R/.claude/worktrees/wip" -b track/wip origin/main 2>/dev/null
echo x > "$R/.claude/worktrees/wip/f"
out="$(cd "$R" && worktree-reap 2>&1)"
check "worktree-reap: merged worktree planned REAP" grep -qE '^REAP +track/done' <<< "$out"
check "worktree-reap: dirty worktree held"          grep -qE '^HOLD +track/wip' <<< "$out"
check "worktree-reap: dry run removes nothing"      test -d "$R/.claude/worktrees/done"
out="$(cd "$R" && worktree-reap --apply --yes 2>&1)"
check "worktree-reap: --apply reaps merged"         test ! -d "$R/.claude/worktrees/done"
check "worktree-reap: --apply keeps the dirty one"  test -f "$R/.claude/worktrees/wip/f"

# --- closeout-check --------------------------------------------------------
R="$T/close"; newrepo "$R"
out="$(cd "$R" && PATH="$HERE/bin:/usr/bin:/bin" closeout-check 2>&1)"; rc=$?
check "closeout-check: no gh is NOT a pass"         test "$rc" = 1
check "closeout-check: repo from origin"            grep -q "on .*close.origin" <<< "$out"
echo dirt > "$R/dirt"
out="$(cd "$R" && PATH="$HERE/bin:/usr/bin:/bin" closeout-check 2>&1)"
check "closeout-check: dirt is OUTSTANDING"         grep -q 'OUTSTANDING: 1 uncommitted' <<< "$out"

# --- aw-seed-memories ------------------------------------------------------
R="$T/seed"; newrepo "$R"
MEM="$HOME/.claude/projects/$(printf '%s' "$R" | sed 's|[/.]|-|g')/memory"
out="$(cd "$R" && aw-seed-memories 2>&1)"
check "aw-seed-memories: files seeded"              test -f "$MEM/feedback_master_worktree_readonly.md"
check "aw-seed-memories: index lines added"         test "$(grep -c '^- \[' "$MEM/MEMORY.md")" = 8
echo "mine" > "$MEM/feedback_bus_emit_at_release.md"
(cd "$R" && aw-seed-memories >/dev/null 2>&1)
check "aw-seed-memories: never overwrites"          test "$(cat "$MEM/feedback_bus_emit_at_release.md")" = mine
check "aw-seed-memories: no duplicate index lines"  test "$(grep -c '^- \[' "$MEM/MEMORY.md")" = 8

# --- git-hooks dispatcher --------------------------------------------------
git config --global core.hooksPath "$HERE/git-hooks/hooks"
R="$T/hooks"; newrepo "$R"
printf '#!/bin/sh\necho repo-pre-commit-ran >> "%s/ran"\n' "$T" > "$R/.git/hooks/pre-commit"; chmod +x "$R/.git/hooks/pre-commit"
git -C "$R" commit -q --allow-empty -m chained
check "dispatch: chains to the repo's own hook"     grep -q repo-pre-commit-ran "$T/ran"
printf '#!/bin/sh\nexit 1\n' > "$R/.git/hooks/pre-commit"
check "dispatch: repo hook's refusal stands"        bash -c "! git -C '$R' commit -q --allow-empty -m refused 2>/dev/null"
rm "$R/.git/hooks/pre-commit"
git -C "$R" checkout -q -b feature 2>/dev/null
check "dispatch: no marker, branch switch allowed"  test "$(git -C "$R" branch --show-current)" = feature
git -C "$R" checkout -q main
mkdir -p "$R/.claude"; printf 'version: 1\n' > "$R/.claude/agent-workflow.yaml"
git -C "$R" checkout -q -b feature2 2>/dev/null
check "dispatch: marker, master HEAD reverted"      test "$(git -C "$R" branch --show-current)" = main
git -C "$R" worktree add -q "$R/.claude/worktrees/t1" -b track/t1 2>/dev/null
check "dispatch: linked worktree unaffected"        test "$(git -C "$R/.claude/worktrees/t1" branch --show-current)" = track/t1
out="$(git -C "$R/.claude/worktrees/t1" commit --allow-empty -m 'no trailer' 2>&1)"
check "dispatch: missing trailer warns"             grep -q 'lacks \[track: t1\]' <<< "$out"
out="$(git -C "$R/.claude/worktrees/t1" commit --allow-empty -m "$(printf 'ok\n\n[track: t1]')" 2>&1)"
check "dispatch: trailer present, no warning"       bash -c "! grep -q lacks <<< '$out'"
printf 'master_readonly: false\n' > "$R/.claude/agent-workflow.yaml"
git -C "$R" checkout -q -b feature3 2>/dev/null
check "dispatch: master_readonly false, allowed"    test "$(git -C "$R" branch --show-current)" = feature3
git config --global --unset core.hooksPath

# --- claude-adopt ----------------------------------------------------------
# shellcheck source=../../profile/claude.sh
. "$DOTS/profile/claude.sh"
R="$T/adopt"; newrepo "$R"
(cd "$R" && claude-adopt --local >/dev/null)
check "claude-adopt --local: info/exclude lines"    grep -qxF '.claude/worktrees/' "$R/.git/info/exclude"
check "claude-adopt --local: tree stays clean"      test -z "$(git -C "$R" status --porcelain)"
out="$(cd "$R" && claude-adopt --dry-run 2>&1)"
check "claude-adopt --dry-run: writes nothing"      test ! -e "$R/.claude/agent-workflow.yaml"
(cd "$R" && claude-adopt --bus shared --ci >/dev/null)
check "claude-adopt: marker written"                grep -qx 'bus: shared' "$R/.claude/agent-workflow.yaml"
check "claude-adopt: trunk recorded"                grep -qE '^trunk: [a-z]+' "$R/.claude/agent-workflow.yaml"
check "claude-adopt: .gitignore lines"              grep -qxF '.claude/coldstart.md' "$R/.gitignore"
check "claude-adopt --ci: workflow copied"          test -f "$R/.github/workflows/agent-workflow.yml"
(cd "$R" && claude-adopt >/dev/null)
check "claude-adopt: idempotent ignores"            test "$(grep -cxF '.claude/worktrees/' "$R/.gitignore")" = 1

echo
echo "agent-tools: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
