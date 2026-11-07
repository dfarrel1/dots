---
name: loose-end
description: File the thing you noticed but are not going to fix. Use whenever work surfaces a real problem that is OUTSIDE the session's task and does NOT block it — a defect in a neighbouring surface, a gap you had to route around, a check you started and could not finish, a config that is wrong but not wrong enough to stop for. Also use at close-out, before writing the open-items list, so every item on it has a tracked home. NOT for the task you are actually doing, and NOT for anything blocking — fix that.
allowed-tools: Bash, Read, Write, Edit
---

# /loose-end — the thing you noticed is not filed until it is filed

A loose end that lives only in a session transcript is lost: the tab closes and
the next person rediscovers it, usually by being bitten by it.

**The bar: could someone who was not in this session find it, understand it,
and act on it, without asking you?** If not, it is not filed.

## 1. Is it a loose end?

| The thing is | Do this |
|---|---|
| **Blocking your task** | Fix it. It is your task now. |
| **Trivial and in a file you are already touching** | Fix it. Filing costs more than fixing. |
| **Real, outside your task, and nobody is tracking it** | **File it.** That is this skill. |
| **Already tracked, or speculative** | Drop it. Say so once in your summary. |

Not loose ends:

- **Work you are mid-way through.** That belongs in your track record or your
  PR; a second record goes stale.
- **A hunch.** "This looks slow" with no measurement is not actionable: measure
  it, or say in your summary that you did not.

## 2. Where it goes

The issue tracker is the marker's `issues_repo` (`aw-config issues_repo`), else
the repo the `origin` remote points at:

```bash
REPO="$(aw-config issues_repo "" 2>/dev/null)"
[ -n "$REPO" ] || REPO="$(git remote get-url origin | sed -E 's|\.git$||; s|^.*[:/]([^/]+/[^/]+)$|\1|')"
```

A repo may keep other registers (findings, a backlog, track records); its own
CLAUDE.md or docs name them. Use a measured-defect register only when you have
a measurement someone would otherwise have to take again.

## 3. Check it is not already filed

Always, before writing anything. Duplicates split the discussion and each one
looks unowned.

```bash
gh issue list --repo "$REPO" --state all --search "<distinctive words>" --limit 10
```

Search the distinctive noun — the host, the flag, the file, the error string —
not your phrasing of the problem.

## 4. Write it so a cold reader can act

**The title is the claim, not the topic.** A reader scanning a hundred open
issues tells what is wrong from the title alone.

| Bad title | Good title |
|---|---|
| Operator keys | Revoking a key in the console does nothing while the deploy env pins it |
| Catalog page is slow | Catalog page fires 629 requests per load |
| Check the other environment | The other environment was never checked for the key shadowing found here |

Body, in this order, short:

```markdown
## What happened
What you observed, with real names: host, file:line, command, exact error text.
If you measured, give the number, its units and how you got it. If not, say so.

## The gap
Why it matters, in one or two sentences.

## Where it came from
One line: found while doing <other thing>, not investigated further.
```

Label it (`bug`, `enhancement` or `chore`; `urgent` only if something is
broken for someone now; `needs-triage` so it gets routed).

```bash
gh issue create --repo "$REPO" --title "<the claim>" --body-file <unique-file>.md \
  --label bug --label needs-triage
```

## 5. Confirm before you file, once

Filing reaches the team's tracker and notifies watchers. **Collect loose ends
as you go; before filing, show the operator the one-line titles and ask once.**
File the approved ones in one pass and give back the issue numbers. Unanswered
means not filed, and your summary says so in those words.

## 6. Say where it went

Name every filed item, with its number, in the session summary and in the
close-out open-items table. Filing is what turns an **OPEN** item into an
**ASSIGNED** one.

## Refuses

- Filing a duplicate. Search first, every time.
- Filing a hunch. Measure it or say it is unmeasured.
- Filing to avoid small work that is in front of you.
- Filing silently.
