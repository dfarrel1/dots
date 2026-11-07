---
name: handoff
description: Capture in-flight session state (todo list, active hypothesis, ruled-out paths, next step, WIP files) into a `wip(<track>): handoff baton` commit so a different Claude Code session — different account, after a quota stop, a crash or `/clear` — can resume the track without re-deriving context. Composes with `/iso` and per-session worktrees.
allowed-tools: Bash
---

# /handoff — capture in-flight state into a `wip(<track>):` commit

The explicit pause-point baton. Run it when about to lose state for any reason:
a quota stop, a halt at a permission boundary, a planned `/clear`, or a nudge
from the PreCompact / SessionEnd / Stop hooks.

**Cost model:** one extra commit per natural pause point, not per tool call.

## When to invoke

- A PreCompact / SessionEnd / Stop hook nudge says so.
- You are about to start a background task that may outlast the session.
- You are about to `/clear` or `/iso exit` with WIP in the tree.
- You are leaving plan mode with ruled-out hypotheses worth recording.
- You hit a permission boundary and are about to halt.
- The operator is pausing you and you carry non-trivial in-head state.

## When not to

- The tree is clean and the last commit's body already says what is next.
- You are not on a tracked branch (no `track/<name>`).
- Pure read-only inspection, or a one-line fix you are committing now.

When in doubt, invoke: the no-op path is fast.

## Recipe

```bash
WT="$(git rev-parse --show-toplevel)"
BRANCH="$(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
TRACK=""
[[ "$BRANCH" == track/* ]] && TRACK="${BRANCH#track/}"
if [ -z "$TRACK" ]; then
  echo "/handoff: no track/<name> branch checked out; pass --track <name> if the work has one."
  exit 0
fi

if git -C "$WT" diff --quiet && git -C "$WT" diff --cached --quiet; then
  if git -C "$WT" log -1 --format=%B | grep -qiE "next:|next step:|to do:|todo:"; then
    echo "/handoff: clean tree; last commit already carries a forward pointer. No-op."
  else
    echo "/handoff: clean tree but the last commit has no 'Next:' line; consider amending it."
  fi
  exit 0
fi
echo "/handoff: WIP detected; compose the baton commit."
```

The baton commit body:

````markdown
wip(<track>): handoff baton — <one-line summary of where you are>

[track: <track>]

## Todo snapshot
- [x] <completed>
- [ ] <pending>

## Active hypothesis
Working on: <what you are attacking now>
Reason: <why you think this is the cause or the right approach>

## Ruled out
- Tried X — failed because Y. (<sha or "uncommitted">)

## Next concrete step
<one sentence: what the next session does FIRST>

## WIP files
- <path>: <what is mid-edit>

## How to resume
```
/iso resume <track>
git log --grep="handoff baton" -1 --format=full
git diff HEAD
```
````

Then:

```bash
git -C "$WT" add -A
git -C "$WT" commit -s -F <msgfile>
git -C "$WT" push -u origin "$BRANCH"          # if the branch has a remote

SHA="$(git -C "$WT" rev-parse --short HEAD)"; TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
work update "$TRACK" --note "handoff at $SHA @ $TS — see git log --grep='handoff baton' -1"   # if the track is registered
mkdir -p "$WT/.claude/handoff" && echo "$TS" > "$WT/.claude/handoff/$TRACK.last"           # read by the Stop hook's throttle
echo "HANDOFF_COMPLETE=$SHA TRACK=$TRACK TIMESTAMP=$TS"
```

## What the next session does

```bash
/iso resume <track>                              # re-enter the worktree
git log --grep="handoff baton" -1 --format=full  # read the baton
git diff HEAD                                    # any uncommitted state
work list --owner "$(work whoami)"               # confirm scope
```

Target: re-onboarded in under two minutes.

## Throttle file

`.claude/handoff/<track>.last` holds the time of the last handoff. The Stop
hook skips its nudge while the marker is younger than its window (default
30 min, `HANDOFF_STOP_THROTTLE_MIN`). The recipe writes it.

## Master mode

On master (no worktree), `wip(<track>):` commits land on main and stay in
history. Keep master-mode work small.

## Compose with

- `/iso resume <name>` — the re-entry path.
- `work update <track> --note` — carries the latest baton sha and time.
- `/coldstart` — the baton holds the state; the cold-start marker starts the
  next session on it.
