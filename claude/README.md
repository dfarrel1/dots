# Claude Code agent workflow

Working machinery for running several Claude Code sessions on one machine and
one repo without collisions, shared by every repo instead of copied into each.

| Part | Where | Installed as |
|---|---|---|
| Plugin `agent-workflow`: hooks, skills, memory seeds | `claude/plugins/agent-workflow/` | Claude Code plugin from this repo's marketplace (`.claude-plugin/marketplace.json`), enabled at user scope |
| `work` CLI: tracks, session bus, clusters | `agent-tools/work/` | `go install ./agent-tools/work` |
| Session tools: `claude-session`, `worktree-reap`, `closeout-check`, `coldstart`, `next-id`, `aw-config`, `aw-seed-memories` | `agent-tools/bin/` | on PATH via `profile/claude.sh` |
| Git hooks dispatcher | `agent-tools/git-hooks/` | global `core.hooksPath` (`install-global --apply`) |
| CI gate templates | `agent-tools/ci/` | copied per repo by `claude-adopt --ci` |
| `claude-adopt` | `profile/claude.sh` | shell function |

## What runs where

The plugin fires in every session in every repo. Its parts split in two:

| Always on (every repo) | Only in repos carrying `.claude/agent-workflow.yaml` |
|---|---|
| destructive-git guard (refuses) | master-worktree write guard (refuses) |
| container-VM launch guard (refuses) | master-worktree git guard (refuses) |
| agent-reference guard on commits and PR bodies (refuses) | session-bus delivery |
| cold start (`.claude/coldstart.md`) | handoff nudges (PreCompact, Stop, SessionEnd) |
| session-title rule | tracker context and release reminder |

Every hook does nothing when the repo's own `.claude/settings.json` still wires
a hook of the same name, so a repo that carries its own copies is not served
twice while it migrates. Every hook other than the three refusing guards fails
open.

Knobs are `AGENT_*`; the older `GOAT_*` names are accepted as aliases.

| Knob | Effect |
|---|---|
| `AGENT_ALLOW_DESTRUCTIVE_GIT=1 <cmd>` | one-shot override of the destructive-git guard (in the command) |
| `AGENT_ALLOW_MASTER_GIT_MUTATE=1 <cmd>` | one-shot override of the master-worktree git guard (in the command) |
| `AGENT_ALLOW_DOCKER_DESKTOP=1 <cmd>` | one-shot override of the container-VM guard (in the command) |
| `AGENT_ALLOW_MASTER_WRITE=1` | session-wide override of the master-worktree write guard (set before `claude`) |
| `AGENT_DOCKER_DESKTOP_OK=1`, or the file `~/.config/agent-workflow/docker-desktop-allowed` | machine-wide container-VM opt-out; `AGENT_DOCKER_DESKTOP_SENTINELS` lists more sentinel files |
| `AGENT_COLDSTART=off` | no cold start |
| `AGENT_CLOSEOUT_PROTOCOL=off` | `/closeout` skips itself |
| `AGENT_BUS_INFO_CAP`, `AGENT_BUS_WARN_CAP`, `AGENT_BUS_CATCHUP_HOURS`, `AGENT_BUS_CATCHUP_TRUNC` | bus delivery limits (5, 8, 24, 300) |
| `AGENT_GIT_HOOKS=off <git cmd>` | skip the dispatcher's own checks for one command |

## Switching it on

```bash
claude plugin marketplace add <path to this dots checkout>
claude plugin install agent-workflow@dots
go install ./agent-tools/work
agent-tools/git-hooks/install-global --apply
```

Then, per repo that should use worktrees, the bus and the tracker:

```bash
claude-adopt            # writes .claude/agent-workflow.yaml and .gitignore lines; commit them
```

`clone` (profile/git.sh) runs `claude-adopt --local` after every clone, which
only keeps the workflow's runtime files out of `git status` through
`.git/info/exclude`.

## Tests

```bash
claude/plugins/agent-workflow/hooks/tests/run-all.sh
agent-tools/tests/run.sh
(cd agent-tools/work && go test ./...)
claude plugin validate claude/plugins/agent-workflow && claude plugin validate .
```
