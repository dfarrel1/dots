---
name: coldstart
description: Resume a session automatically after a break, in any repo. At close-out, when work is unfinished or a service was stopped, leave a cold-start marker (`coldstart leave`); at the next session start a hook flushes it, starts its start-up commands and hands its instructions to the new session. The operator never has to remember restart steps. On by default; opt out with AGENT_COLDSTART=off.
allowed-tools: Bash
---

# /coldstart — leave a marker so the next session starts itself

## Opt out

```bash
[ "${AGENT_COLDSTART:-${GOAT_COLDSTART:-on}}" = "off" ] && echo "coldstart: OFF — skipping"
```

If that prints, stop and say so.

## Why

The operator will not remember restart steps after a break, and should not have
to. The `/handoff` baton carries a session's state across a break in a commit,
but something still has to start the services again and tell the new session to
read the baton. That is the marker.

## The three parts

| Part | Where | What it does |
|---|---|---|
| Module | `coldstart` (agent-tools/bin; the plugin's `bin/coldstart`) | where the marker lives, its sections, `check` and `leave` |
| Check and run | the plugin's SessionStart hook | no marker: exits in milliseconds; a marker: moves it to `.claude/coldstart.consumed/` first (it fires once), starts its `## Run` lines in the background, hands `## Then` to the session |
| Leave behind | `coldstart leave [<repo>] < marker` | written by `/closeout` when work is unfinished, and by a session whose cold start could not finish |

A repo that wires its own `session-start-coldstart.sh` keeps it; the plugin
hook then stays silent.

## Writing a marker

```markdown
# <one line: what is being resumed>

## Run
<start-up commands safe to run unattended: local services only>

## Then
1. Read the latest handoff baton: `git log -1 --grep 'handoff baton' track/<name>`.
2. <what the session does first, in order, as instructions to itself>
```

- `## Run` holds only what is safe unattended: starting local services. Never a
  send, a merge, a deploy, a delete, or anything that acts on people, devices or
  shared infrastructure; those go in `## Then`, where the session does them with
  its own checks.
- `## Then` is for the session, not the operator: the operator does nothing.
- State belongs in the baton commit, not the marker; the marker points at it.
- The marker is `<repo>/.claude/coldstart.md`; keep `.claude/coldstart.md` and
  `.claude/coldstart.consumed/` gitignored (`claude-adopt` adds the lines).

## At the start of a session

When the context says COLD START, do the `## Then` steps before the operator's
request and say in one line that it was done; read the run log it names. If a
step cannot finish, re-arm with `coldstart leave`.

## Compose with

- `/handoff`: the baton holds the state; the marker starts the next session on it.
- `/closeout`: a Not-clean verdict, or anything stopped for the break, leaves a marker.
