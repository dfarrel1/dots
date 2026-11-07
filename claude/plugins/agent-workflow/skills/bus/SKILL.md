---
name: bus
description: Talk to the other Claude Code sessions working this repo right now — post a claim, a warning, a correction or a finding to the session bus, read what other sessions have posted, reply to a specific session or track, and acknowledge a message so its sender knows it landed. Use before touching shared substrate (a live host, main, a shared deploy, a record number), when you learn something another session would act on wrongly without it, when you are asked what other sessions are doing, and when a delivered bus message is addressed to you. Needs the repo to carry .claude/agent-workflow.yaml and `work` on PATH.
allowed-tools: Bash
---

# /bus — the channel between concurrent sessions

Tool: `work bus` (agent-tools/work in dots). Delivery: the plugin's
`session-bus-tail.sh` hook. Both are active only in a repo that carries
`.claude/agent-workflow.yaml`.

## Post

```bash
work bus info   "<msg>"                      # something others may want
work bus warn   "<msg>"                      # something others must not step on
work bus urgent "<msg>"                      # operator should look now
work bus warn   "<msg>" --to track:<name>    # aimed at one track
work bus ack <ts> [--note "<text>"]          # tell a sender it landed
```

The event carries your session id, host, cwd, branch and track automatically.

## Read

```bash
work bus tail | jq -r '"[\(.level)] \(.ts) \(.session_id) \(.track // "-")\n  \(.msg)"'
work bus tail --track <name>          # one track's thread
work bus tail | tail -20              # raw JSONL, newest last
```

You normally do not need to read: the delivery hook injects new events into
your context on every prompt. Read for the full text of something the hook cut,
or for history from before your session existed.

## Posting is not delivery — the hook is

An event is a durable record the moment it is written. It reaches another
session only when that session's hook fires: at its `SessionStart` (catch-up
over the last 24 h) and on each of its prompts. A session that is mid-turn, or
stopped, receives nothing until its next prompt. There is no push, no
interrupt, no polling.

So: **post, then continue.** Do not wait for a reply and do not treat silence
as agreement. Confirmation that a reader acted is an `ack` from their side.

| Level | Reaches a live session | Reaches a session at start-up |
|---|---|---|
| `urgent` | always, in full | always, in full |
| `warn` | always, in full | last 8, bodies cut to 300 chars |
| `info` | last 5 only | last 5 only, bodies cut to 300 chars |
| anything `--to` you | always, in full, flagged | always, in full, flagged |

Omitted events are counted, not hidden: the reader sees `(N older event(s)
omitted)`. Nothing is delivered twice: each session keeps a byte cursor.

**Choose the level by what a reader must do.** `info` is capped at 5; a claim
you need respected is `warn`.

## Addressing

`--to track:<name>` is the reliable aim: the reader's track comes from its
branch (`track/<name>`), so it lands whatever the level.

`--to session:<id>` takes the id from a delivered event's `session=` field or
from `bus tail`.

A directed message is flagged `(ADDRESSED TO THIS SESSION)` and its sender is
waiting on one of:

```bash
work bus ack <ts> --note "picked it up; not touching X"
work bus warn "<correction or answer>" --to session:<their id>
```

`ack` writes an event aimed back at the sender's session, so it is delivery,
not just a log line.

## What to post

| Post | Don't post |
|---|---|
| "I am about to deploy X to host Y" | per-command status |
| "I claimed record number N" | file edits, build steps |
| "PR #N is merged; the fix is in main" | search results, debug output |
| "I was wrong at 15:20Z — here is the measurement" | "starting work on X" with no shared surface |
| "This id / branch / host is contested" | anything you would not read yourself |

- **Correct yourself on the bus.** A claim you then measured differently gets a
  correction at the same or higher level; others have already acted on it.
- **Claim before you write.** Numbered records race across branches: run
  `next-id --fetch`, post the claim, then write the file.

## Limits

| Limit | Behaviour |
|---|---|
| 2 KB per message | emit is refused; split into numbered posts ("1 of 2") |
| identical message within 60 s | refused as rate-limited; `--force` overrides |
| subagents | inherit nothing: paste the excerpt into the spawn prompt |
| a subagent's own posts | attributed to your session id |
| `bus ack <ts>` | finds events in the live file only, not rotated archives |
| monthly rotation | the file rolls over on the first post of a new month |

## Which bus you are on

By default the bus is keyed on the master worktree path: every worktree of a
clone shares it, and two clones are two separate buses. A marker line
`bus: <name>` puts the repo on a named bus that sibling repos can share:

```bash
ls -la ~/.claude/state/session-bus-*.jsonl     # one file per bus
work bus tail | wc -l                          # how busy is the one I'm on?
```

## Compose with

- `work pickup|release` — slowly changing state: who holds what track. The bus
  is events: what is happening now. A pickup is worth one `info`; the post is
  not a substitute for the pickup.
- `/handoff` — continuity across a session boundary, in a commit.
- `/iso` — sets the branch the bus derives your track from. Post from inside
  your worktree so `track=` is populated.

## If the bus looks dead

Events still land in the JSONL even when nothing is delivered.

```bash
ls -l ~/.claude/state/session-bus-*.jsonl                       # anything being written?
command -v jq                                                   # no jq: hook exits silently
ls "$(git rev-parse --show-toplevel)/.claude/agent-workflow.yaml"   # marker present?
rm ~/.claude/state/session-bus-cursor-"$CLAUDE_CODE_SESSION_ID" # cursor stuck past EOF
```
