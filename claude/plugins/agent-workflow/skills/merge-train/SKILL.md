---
name: merge-train
description: Keep many agents' pull requests to one repository from conflicting with each other. Use whenever more than two sessions or subagents are opening PRs to the same repo at once, whenever a lead plans a fan-out that will produce several PRs, whenever PRs start reporting CONFLICTING or DIRTY after a merge, and before pushing a branch that changes a file other open PRs also change. Covers the four causes of serial conflicts, the merge slot for shared-core changes, generated counts, stacks, and the overlap check (bin/pr-overlap) that finds a conflict before it lands.
allowed-tools: Bash
---

# /merge-train — parallel PRs without a conflict pile-up

When several agents push to one repository, the usual failure is not a bad
change. One merge moves a shared line, and every other open PR then conflicts
with main and waits for a rebase. The rebases queue behind the slowest agent,
and work that was finished stops moving.

## The four causes

| Cause | What it looks like | Rule |
|---|---|---|
| Shared derived text: counts, tables of totals, a "last updated" line, a generated index | Every PR edits the same README or roadmap line | **Feature PRs never edit derived text.** One owner regenerates it in its own PR after each merge wave, or CI generates it |
| Two changes to the shared core at once: a spec, a schema, a parser used by every component | Many files in many directories conflict together | **One merge slot for the core.** One PR holds it from ready to merged; the next one rebases onto main as soon as the previous one merges, and only then fans out |
| A stack left on a squashed base | Every PR in a chain conflicts after the first one merges | **Rebase the next PR the moment its base merges**, and say so on the bus |
| Additive work that touches the core it doesn't need | A data-only PR conflicts because it also touched engine or library code | **Keep additive PRs additive**: data, docs, tests in their own directory. If they need a core change, they wait for the slot PR that brings it |

## The merge slot

1. A PR that changes the shared core claims the slot on the bus before it is
   ready to merge: `work bus warn "MERGE SLOT: <repo>#<n> <what>"`.
2. While it holds the slot, other core changes keep building on a branch cut
   from the slot holder's branch, never from a stale main.
3. When it merges, its owner posts `SLOT FREE: <repo>#<n>`. The next claimant
   rebases at once, runs its tests, then claims the slot.
4. The order is the order of claims. Where versions are numbered, claim the
   number and the slot together, so number order equals merge order.

## The overlap check

Run before every push and in any sweep that merges PRs:

```bash
pr-overlap <repo dir> [branch]     # bin/pr-overlap in this plugin
```

It prints `CONFLICTS-WITH-MAIN #n` for each open PR that no longer merges,
`OVERLAP #n <file>` for each open PR that changes a file your branch also
changes, and with no branch argument `SHARED <file>: #a #b ...` for files
several open PRs change. It ignores files listed in `PR_OVERLAP_IGNORE`
(default: `README.md`, for the derived-text owner to regenerate).

An overlap is not a stop. It tells you which other session to talk to before
both of you merge, or that your branch should wait for, or build on, the other.

## For a lead that merges others' PRs

- Merge core-slot PRs first, then stacks in order, then additive PRs.
- After each merge, run the overlap check and tell each owner whose PR now
  conflicts, by name and PR number, in the same sweep.
- When conflicts recur on one file, that file is a shared hot spot: move it
  under one of the four rules above instead of rebasing again.
