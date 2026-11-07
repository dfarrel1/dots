---
name: closeout
description: Close out a track or session — run the cleanliness checks and report a verified verdict, emit a prompt/response table of the whole session, and publish a cold-read HTML report. Triggered when the operator asks to clean up / close out / wrap up, or when a track's work looks complete. Opt out with AGENT_CLOSEOUT_PROTOCOL=off.
allowed-tools: Bash
---

# /closeout — verified close-out, session record, cold-read report

Three deliverables, always all three.

## Opt out

```bash
[ "${AGENT_CLOSEOUT_PROTOCOL:-${GOAT_CLOSEOUT_PROTOCOL:-on}}" = "off" ] && echo "closeout protocol: OFF — skipping"
```

If that prints, stop and say so. It is on by default because the failure it
guards against is a session *believing* it finished.

## 1. Cleanliness checks — run them, do not assume

```bash
closeout-check                  # whole-repo verdict (agent-tools/bin)
closeout-check --track <name>   # also judges that track's PR, branch and record
```

Exit 0 prints **REPO CLEAN**; exit 1 prints every outstanding item, each
labelled `OUTSTANDING`, and every one of those appears in the summary. It checks
worktrees, uncommitted work, your open PRs, remote `track/*` branches, the named
track's PR and record, and private-key material in the scratch directory.

On branches it compares **content**, not reachability: squash-merge makes the
merged commit a new object, so `--is-ancestor` fails by construction on
branches that ARE merged. By hand:

```bash
R="$(git rev-parse --show-toplevel)"
git -C "$R" worktree list                                   # worktrees still on disk?
git -C "$R" status --short                                  # uncommitted files?
gh pr list --state open --limit 40 --json number,title -q '.[] | "#\(.number) \(.title)"'
git -C "$R" ls-remote origin 'refs/heads/track/*'           # branches left after merge?
git -C "$R" log origin/main --oneline -10                   # is the work in main?
```

The verdict is exactly one of:

- **Clean** — worktrees reaped, nothing uncommitted, every PR merged, work in
  main, and no open item classed URGENT or OPEN.
- **Not clean** — name what is outstanding and why.

Common leftovers:

| Leftover | Handling |
|---|---|
| Worktrees under the worktrees dir | Remove; `--force` only after confirming the branch content is in main. |
| One-off scripts written as workarounds | Delete if the blocker they existed for is fixed. |
| Tracker yaml moved aside to allow a fast-forward | Confirm the repo copy exists before dropping the backup. |
| Private keys, cert bundles, tarballs in the scratch directory | Remove. |
| Commits on `track/*` missing `[track: <name>]` | Amend; push with `--force-with-lease`. |

## 2. Prompt/response table

Every operator turn, in order. Paraphrase prompts over 20 words. A five-word
paraphrase of what the turn produced. Include the turns where the operator
pushed back or corrected course: this is a record, not a highlight reel.

| # | Operator asked | I did (5 words) |
|---|---|---|

## 3. HTML report, cold-read accessible

Start from `closeout-report-template.html` beside this file: copy it to the
scratch directory, fill it, publish it. Do not hand-write a new page.

Reading order (never rearrange):

1. **Verdict banner** — Clean / Not clean pill, two sentences, 3-4 facts with numbers.
2. **Open items** — "This session" then "Outside this session". One row per item:
   class pill · item (one sentence, real names) · owner and how it resolves. URGENT
   first. A Clean verdict cannot sit above an OPEN or URGENT row.
3. **What changed** — at most ~8 rows: area · change (PR, host, file) · how verified.
4. **Corrected during the session** — what was wrong and what it really was. Omit if none.
5. **Session record** — the prompt/response table, collapsed.
6. One muted line listing the checks that were run.

Content rules:

- **Anchor on real names** — hosts, files, PR numbers, record IDs, commands. A
  reader can look those up; they cannot look up invented shorthand.
- **Do not coin vocabulary**, and do not over-abstract: "the storage card" with
  no model, host or path is as useless as jargon.
- Tables and rows over prose. No process narration, no self-characterisation.
- Where a record ID appears, add a clause saying what it is.

### Open items — classify every one

Every open item carries one **scope**, one **class**, an owner, and how it resolves.

| Scope | Meaning |
|---|---|
| **THIS SESSION** | Created, touched or owed by this session's work |
| **OUTSIDE THIS SESSION** | Pre-existing or someone else's; seen during the checks |

| Class | Meaning | Effect on the verdict |
|---|---|---|
| **URGENT** | Needs a human action now, or something breaks or stays broken | Listed first. **Not clean** |
| **OPEN** | Unresolved work this session owns and nothing else tracks | **Not clean** |
| **ASSIGNED** | Open, with a named owner and a tracked home (PR, issue, track record) | Compatible with **Clean** |
| **BY DESIGN** | Open because the designed progression leaves it open at this stage (a soak, a phase gate). Say what resolves it | Compatible with **Clean** |

Rules:

- A **Clean** verdict and an OPEN or URGENT item never appear in the same close-out.
- "Resolves by" is a mechanism a reader can look up (a PR number, an issue, a
  track name, a command), never "later".
- Before settling for OPEN, run `/loose-end`: filing gives the item a number and
  an owner, which makes it ASSIGNED.
- Items that are not this session's are OUTSIDE THIS SESSION and ASSIGNED to
  their owner. OPEN and URGENT are only ever THIS SESSION; a truly urgent outside
  item is escalated to its owner and recorded as ASSIGNED with that escalation.
- Two groups, **This session** first, each a table with Class · Item · Owner ·
  Resolves by. An empty group is one line ("Outside this session: none").
- An item that cannot be classified is OPEN.

## 4. Leave a cold start when anything is unfinished

If the verdict is **Not clean**, or a service was stopped for the break, leave a
cold-start marker before ending: `coldstart leave < marker` with a `## Run`
section (start-up commands safe unattended) and a `## Then` section (what the
next session does first, pointing at the latest `/handoff` baton). Never hand
the operator restart steps. See `/coldstart`.

## Compose with

- `/iso` — the worktree this checks for is usually the one `/iso enter` made.
- `work release <track>` — records the track's outcome; this skill checks the
  repo. Do both.
