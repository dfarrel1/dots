# work — concurrency-governance CLI

A small Go CLI that lets several Claude Code sessions (and people) work one
repository at once without stepping on each other:

- **Tracks** — `pickup` / `update` / `release` record who holds which piece of
  work, as one yaml file per track, committed in the repo.
- **Session bus** — `work bus` posts and reads events between live sessions on
  one machine; the agent-workflow plugin's `session-bus-tail.sh` hook delivers
  them into each session's context.
- **Clusters, roles, file claims, decisions** — multi-track captaincy on top of
  tracks.

## Install

```bash
go install ./agent-tools/work          # from the dots checkout; lands in $GOBIN or $GOPATH/bin
work --help
```

`./work` beside the source is a wrapper that rebuilds from the current source
on every call, for running it without installing.

## Configuration: `.claude/agent-workflow.yaml`

The repo-root marker switches a repo onto the workflow. Every key is optional;
the defaults are shown.

```yaml
version: 1
tracker_dir: docs/project/active-work   # per-track yaml records
roles_dir: ops/work/roles               # role prompts for `work role`
worktrees_dir: .claude/worktrees        # per-session worktrees (/iso, claude-session)
trunk: main                             # the branch work merges into
bus: ""                                 # named bus shared with sibling repos; empty = one bus per clone
master_readonly: true                   # read by the plugin's master-worktree guards
```

A marker that does not parse, a path that leaves the repo, or a bus name with
characters other than letters, digits, `.`, `_` and `-` is refused rather than
replaced by defaults. `claude-adopt` (dots `profile/claude.sh`) writes the marker.

## Storage layout

```
<tracker_dir>/
├── tracks/<name>.yaml              (one per active track)
├── recently_completed/<name>.yaml  (one per closed track)
├── queued/<name>.yaml
├── clusters/<name>.yaml
├── file_claims/<sha8>__<base>.yaml
├── pending_decisions/<id>.yaml
└── _schema_version
```

Two PRs touching different tracks write different files, so they never
conflict. `work migrate` splits a legacy monolithic `<tracker_dir>.yaml` into
this layout; `load` refuses to run while the legacy file exists.

## Tracks

```bash
work whoami                                   # WORK_OWNER, CLAUDE_SESSION_ID, git user.email, hostname
work pickup <track> --scope <paths> --eta <when> --note "<what>"
work update <track> --status <s> --note "<progress>"
work commit <track> -m "<msg>" --paths a,b    # appends [track: <track>]; commits only the named paths
work release <track>                          # moves the record to recently_completed/; fill its summary:
work list [--owner <o>] [--status <s>]
work check-stale [--threshold 24h]
```

`pickup` records whether the work happens in the master worktree or a
per-session worktree (detected from git, or inferred from
`<worktrees_dir>/<track>` on `track/<track>`). `release` removes that worktree
when its work is merged.

### The release merge check

`release` refuses to mark a track done while its branch has commits that are on
no remote's trunk. It checks every remote `git remote` lists (no remote name is
assumed), using `git cherry` (patch-id, so rebases pass) and, for squash-merges,
a merged PR for the branch on any remote's GitHub repo (`gh pr list --repo
<owner/repo>`). `--allow-unmerged "<reason>"` records an intentional abandon.

The `summary:` on the released record is read cold by people scanning the
directory: plain-English goal, work and result, one paragraph, no internal IDs
as load-bearing nouns.

## Session bus

```bash
work bus info|warn|urgent "<msg>" [--to track:<name>|session:<id>] [--force]
work bus ack <ts> [--note "<text>"]
work bus tail [--track <name>] [--since <byte-offset>]
work bus cursor
```

Append-only JSONL at `~/.claude/state/session-bus-<fingerprint>.jsonl`, where
the fingerprint is the first 12 hex characters of SHA-256 of the master
worktree path, so every worktree of a clone shares one bus. With `bus: <name>`
in the marker the file is `session-bus-<name>.jsonl`, shared by every repo that
names it. Messages are capped at 2 KB; identical messages within 60 s are
refused; the file rotates monthly. Posting is not delivery: the plugin hook
delivers at `SessionStart` and on each prompt.

## Clusters, roles, file claims, decisions

```bash
work cluster register <name> --captain <agent_id> --scope <s> [--kickoff-memo <path>]
work cluster status|list|update|release ...
work role list | work role load <role>        # prompts at <roles_dir>/<role>.md
work file claim <path> --until <when> [--note ...] | file release <path> | file list
work decisions pending | raise --summary <s> [--options "a,b"] | resolve <id> --resolution <s>
```

## Tests

```bash
cd agent-tools/work && go test ./...
```

`multi_session_bus_test.go` builds the binary and drives the real plugin hook
end to end in a sandboxed `$HOME`.
