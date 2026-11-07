---
name: iso
description: Toggle a Claude Code session between worktree-mode (isolated per-session worktree) and master-mode (operating on master HEAD). Subcommands enter, exit, status, resume. For repos that carry .claude/agent-workflow.yaml.
allowed-tools: Bash
---

# /iso — session isolation mode

Controls the per-session worktree for the current session. Composes with the
master-worktree guards (active in repos with `.claude/agent-workflow.yaml`),
which refuse edits and mutating git in the master worktree, and with the
`claude-session` launcher.

Claude Code starts in the master worktree. `/iso enter` is the entry point:
invoke it first in any session that may write or commit.

Paths come from the marker, read with `aw-config` (agent-tools/bin):
`worktrees_dir` (default `.claude/worktrees`), `tracker_dir` (default
`docs/project/active-work`), `trunk` (default `main`), `autonomous_allowlist`
(default `ops/scripts/permissions/overnight-allowlist.json`).

## Subcommands

- **`/iso enter <name>`** — provision `<worktrees_dir>/<name>` on branch
  `track/<name>` from `origin/<trunk>`, register the track, and operate there.
- **`/iso enter --autonomous <name>`** — the same, plus copies the repo's
  autonomous allowlist into the worktree's `.claude/settings.local.json` so the
  session runs without permission prompts. The hard deny list still applies. A
  permission denial is a structural halt.
- **`/iso exit`** — return to the master worktree; the track is paused, not
  released.
- **`/iso resume <name>`** — re-enter an existing worktree.
- **`/iso status`** — operating directory, branch, dirty flag, autonomous flag.

## Dirty handling

- **enter** refuses when the master worktree carries uncommitted changes, except
  under `tracker_dir` (the `work` CLI writes its yaml in the master worktree).
  Commit on a track branch (or a `wip(<track>):` baton via `/handoff`) or
  discard first. Stash is not an option: the destructive-git guard refuses
  stash mutations (refs/stash is repo-global).
- **exit** refuses when the worktree carries uncommitted changes: commit or
  `/handoff` first.

## Committing from a track worktree

On `track/<name>`, every commit carries the `[track: <name>]` trailer:

```bash
work commit <name> -m "fix(scope): subject"          # appends the trailer
git -C <worktree> commit -s -F <msgfile>             # msgfile ends: [track: <name>]
```

## Operating-directory directive

Every successful subcommand prints:

```
OPERATING_DIRECTORY=<absolute path>
MODE=<worktree|master>
TRACK=<name|none>
BRANCH=<branch>
```

Use it for every later file operation: Read / Write / Edit take absolute paths
under `OPERATING_DIRECTORY`, and git takes `git -C <OPERATING_DIRECTORY>`. The
Bash tool's cwd does not persist between calls.

## Subcommand reference

### `enter [--autonomous] <name>`

```bash
AUTONOMOUS=0; NAME=""
for arg in "$@"; do
  case "$arg" in
    --autonomous) AUTONOMOUS=1 ;;
    *) [ -z "$NAME" ] && NAME="$arg" ;;
  esac
done
[ -n "$NAME" ] || { echo "usage: /iso enter [--autonomous] <name>"; exit 1; }

cfg() { aw-config "$1" "$2" 2>/dev/null || echo "$2"; }
abs_git=$(cd "$(git rev-parse --git-dir)" && pwd)
abs_common=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$abs_git" = "$abs_common" ] || { echo "/iso enter must run from the master worktree (now in: $(pwd))"; exit 1; }
REPO_ROOT="${abs_common%/.git}"
WT_DIR="$(cfg worktrees_dir .claude/worktrees)"; TRACKER="$(cfg tracker_dir docs/project/active-work)"; TRUNK="$(cfg trunk main)"

# The positive "." pathspec is required: a lone :(exclude) matches nothing.
if ! git -C "$REPO_ROOT" diff --quiet -- . ":(exclude)$TRACKER" \
   || ! git -C "$REPO_ROOT" diff --cached --quiet -- . ":(exclude)$TRACKER"; then
  echo "/iso enter refuses: the master worktree has uncommitted changes outside $TRACKER."
  echo "  commit them on a track branch (or /handoff) or discard them first. Stash is refused."
  exit 1
fi

WORKTREE_ABS="${REPO_ROOT}/${WT_DIR}/${NAME}"; BRANCH="track/${NAME}"
if [ ! -d "$WORKTREE_ABS" ]; then
  git -C "$REPO_ROOT" fetch origin "$TRUNK" --quiet
  git -C "$REPO_ROOT" worktree add "$WORKTREE_ABS" -b "$BRANCH" "origin/$TRUNK"
fi
( cd "$REPO_ROOT" && work pickup "$NAME" --note "/iso enter; worktree at ${WT_DIR}/${NAME}" ) 2>/dev/null || true

cat > "${WORKTREE_ABS}/.iso-mode.env" <<ENVEOF
# /iso enter anchor — every Bash call in this worktree starts with: cd "\$WORKTREE_ROOT" && ...
WORKTREE_ROOT=${WORKTREE_ABS}
TRACK=${NAME}
BRANCH=${BRANCH}
MODE=worktree
AUTONOMOUS=${AUTONOMOUS}
ENVEOF

if [ "$AUTONOMOUS" = "1" ]; then
  ALLOWLIST="${REPO_ROOT}/$(cfg autonomous_allowlist ops/scripts/permissions/overnight-allowlist.json)"
  if [ -f "$ALLOWLIST" ]; then
    mkdir -p "${WORKTREE_ABS}/.claude" && cp "$ALLOWLIST" "${WORKTREE_ABS}/.claude/settings.local.json"
    echo "/iso enter --autonomous: allowlist installed at .claude/settings.local.json (rollback: rm it)"
  else
    echo "warning: --autonomous requested but no allowlist at ${ALLOWLIST}; permission prompts stay on"
  fi
fi

cat <<EOF
OPERATING_DIRECTORY=${WORKTREE_ABS}
MODE=worktree
TRACK=${NAME}
BRANCH=${BRANCH}
AUTONOMOUS=${AUTONOMOUS}
EOF
```

### `exit`

```bash
WT="$(git rev-parse --show-toplevel)"
if ! git -C "$WT" diff --quiet || ! git -C "$WT" diff --cached --quiet; then
  echo "/iso exit refuses: the worktree has uncommitted changes. Commit or /handoff first."
  exit 1
fi
abs_git=$(cd "$(git rev-parse --git-dir)" && pwd)
abs_common=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$abs_git" = "$abs_common" ] && { echo "/iso exit: already in the master worktree"; exit 0; }
COMMON_REPO="${abs_common%/.git}"
( cd "$COMMON_REPO" && work update "$(basename "$WT")" --status "paused:iso-exit" ) 2>/dev/null || true

WT_COUNT=$(git -C "$COMMON_REPO" worktree list | grep -c . || echo 0)
if [ "$WT_COUNT" -gt 10 ]; then
  echo "note: ${WT_COUNT} worktrees on disk. Review with: worktree-reap (dry run), worktree-reap --apply"
fi

cat <<EOF
OPERATING_DIRECTORY=${COMMON_REPO}
MODE=master
TRACK=none
BRANCH=$(git -C "$COMMON_REPO" branch --show-current)
EOF
```

### `status`

```bash
WT="$(git rev-parse --show-toplevel)"
abs_git=$(cd "$(git rev-parse --git-dir)" && pwd)
abs_common=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$abs_git" = "$abs_common" ] && echo "MODE=master" || echo "MODE=worktree"
echo "OPERATING_DIRECTORY=${WT}"
echo "BRANCH=$(git -C "$WT" branch --show-current)"
echo "DIRTY=$(git -C "$WT" diff --quiet && git -C "$WT" diff --cached --quiet && echo no || echo yes)"
echo "AUTONOMOUS=$([ -f "${WT}/.claude/settings.local.json" ] && echo yes || echo no)"
```

### `resume <name>`

```bash
NAME="$1"
abs_common=$(cd "$(git rev-parse --git-common-dir)" && pwd)
COMMON_REPO="${abs_common%/.git}"
WT_DIR="$(aw-config worktrees_dir .claude/worktrees 2>/dev/null || echo .claude/worktrees)"
WORKTREE_ABS="${COMMON_REPO}/${WT_DIR}/${NAME}"
[ -d "$WORKTREE_ABS" ] || { echo "/iso resume: ${WORKTREE_ABS} does not exist; use /iso enter"; exit 1; }
( cd "$COMMON_REPO" && work update "${NAME}" --status active ) 2>/dev/null || true

cat <<EOF
OPERATING_DIRECTORY=${WORKTREE_ABS}
MODE=worktree
TRACK=${NAME}
BRANCH=track/${NAME}
EOF
```

## Compose with

- `claude-session <name>`: sets the entry mode at launch; `/iso` toggles
  mid-session.
- The git-hooks dispatcher (agent-tools/git-hooks): keeps master HEAD on the
  trunk in adopted repos.
- `/handoff`, `/bus`, `work release`.
