---
name: claude-md-frugality
description: Decide whether something belongs in CLAUDE.md at all, and in what form. Fires before adding or expanding any CLAUDE.md line, and during a curation pass when the file crosses its trip line.
---

# Being frugal with CLAUDE.md

CLAUDE.md is loaded into every session in this repo. A line there is not free:
it is paid for on every task by every agent, forever, whether or not that task
touches the subject. A design doc is paid for only when someone reads it.

That asymmetry is the whole rule. **CLAUDE.md is an index: it tells a reader
where the truth lives, it is not where the truth lives.**

## The test, before you add anything

Ask, in order:

1. **Would an agent who never opens the linked doc still act correctly?** If
   yes, the line is doing its job as a pointer. If the line has to *explain* to
   be useful, it belongs in the doc, and the pointer belongs here.
2. **Does this change what someone DOES, or only what they know?** Only the
   first earns index space. Background belongs in the design doc.
3. **Is it discoverable from something already listed?** If an existing pointer
   leads there in one hop, add nothing.
4. **Will it be stale in a month?** Live state — counts, statuses, "currently
   N nodes", in-flight work — goes in the repo's status docs, never here. A stale
   line in the index misleads every session until someone notices.

If it survives all four, write the shortest pointer that names the thing and
its canonical home.

## What earns a line

- A **path or command** an agent must know exists to avoid doing it wrong.
- An **invariant** that is expensive to rediscover and cheap to state:
  fail-closed guards, "generated — never hand-edit", one-way doors.
- A **name→home mapping**: this subsystem's truth is in that doc.

## What does not

- Narrative, rationale, history — that is the design doc's job.
- Tables that grow a row per environment, service, or host. Those belong in
  their canonical doc with one pointer here. They are the single most common
  way this file bloats, because each row looks small.
- Restating something a linked doc already says.
- Anything you are adding "so it is not forgotten". That is what the design
  doc, a finding, or a status doc is for.

## The trip line

A size gate such as `agent-tools/ci/check-claude-md-size.sh` (dots) allows drift to 35 000 bytes, then demands a
curation pass down to 25 000. The hysteresis is deliberate: a single hard cap
made every unrelated PR pay a few minutes of byte-shaving — rewording cells and
shortening dashes to buy 40 bytes — which is waste and fixes nothing.

**When the trip fires, curate; do not squeeze.** Find content with a canonical
home elsewhere and move it. If you are reformatting rather than relocating, you
are doing the wrong thing: the file will be back over the line shortly, and the
next agent pays again.

Good curation moves: lift a multi-row table into its design doc; collapse three
lines about one subsystem into one pointer; delete a line whose linked doc
already says it better; move live state to a status doc.
