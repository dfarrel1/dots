---
name: design-work
description: "Use AUTOMATICALLY, without being asked, whenever any of these are true: writing or revising a design doc, architecture doc, spec, ADR, plan, proposal, runbook, compliance or RMF write-up; publishing an HTML artifact or report; a design or planning conversation that has run more than two turns; producing anything a person outside this session will read (a partner, an assessor, a G6, a reviewer, a handover); the operator gives feedback that a document reads badly, is confusing, is too long, reads like a transcript, or is missing detail; or revising any document for a second time. Also use when deciding HOW to structure design output, not only when writing prose. Covers: establishing intent before producing, checking output against intent, and the writing rules that keep it cold-readable and technically specific."
---

# Design work

**This skill is self-triggering.** Load it without being asked whenever the description
matches. Do not wait for the operator to name it — the failures below are ones the operator
should never have to catch.


Two failures dominate this work. The first is producing something other than what was asked
for. The second is writing that performs care and cleverness instead of communicating. Rules
1 and 2 address those. The rest are the specific forms they take.

---

## 1. Establish intent before producing, and check against it while producing

**At the start.** State in one or two plain sentences what the operator wants and who will
read it. If the task will take more than one edit, say that back before building anything.
Getting this wrong costs the whole turn.

Three things to pin down, and only ask when the answer would change the work:

- **What is it for** — a decision, a build, a handover, a review by someone who was not here.
- **Who reads it** — that decides vocabulary, length and how much context to carry.
- **What "done" looks like** — the operator's test, not yours.

**While working.** Check the output against the stated intent at each stage, not at the end.
When work starts growing past what was asked, stop and say so rather than continuing. Scope
that expands quietly is scope the operator did not choose.

**At delivery.** Say how the output meets the intent and where it does not. Name what was left
out and why. Never let "here it is" stand in for "here is how this answers what you asked."

**When feedback arrives**, first classify it, because the three kinds need opposite responses:

| Feedback is about | Response |
|---|---|
| **Intent** — this is not what I wanted | Stop. Re-establish intent. Do not patch. |
| **Framing** — the content is right, it reads wrong | Change how it reads. **Keep every section.** |
| **Content** — this claim is wrong | Fix the claim, check for the same error elsewhere. |

Treating framing feedback as content feedback deletes work the operator wanted. Treating
intent feedback as framing feedback produces a well-written wrong answer.

---

## 2. Do not perform cleverness or care

This is the root cause of most of what follows. Operator, verbatim: *"you spin out and get
lost in your own tendency to try to sound clever and careful."*

**Performing care** is announcing rigor instead of exercising it:

- "Worth being precise about", "to be clear", "honestly", "stated rather than asserted",
  "let me be careful here" — delete all of these and state the thing.
- Hedges that carry no information. If a claim is uncertain, say what would settle it.
- Flagging your own diligence. The work shows it or it does not.

**Performing candour** is trust-seeking by disclosure: caveats, "balance", past incidents, failure rates,
"not measured in the sources" hedges, handling warnings. Assume the reader is unmoved by any of it; only
germane, true material counts. Describe the current state with status words; unbuilt things are "designed, not built"; a date appears only when the operator set it.
A past event appears only when the reader asks about it. Never encode "state every incident or limitation"
into a spec or writer brief.

**Performing cleverness** is writing for effect:

- Aphorisms and closing zingers: "running out of memory with extra steps", "a defect in the
  name, not the operator".
- Elegant inversions and parallel constructions that restate a point already made.
- Making the same point twice because the second phrasing is prettier. Cut the second.

Test each sentence: **does it add information, or does it add tone?** Cut the tone.

---

## 3. Cold-readable first, then the hard detail

A design output has two readers: someone who was not in the session and needs to follow it,
and someone who has to act on it and needs the specifics. **Serve both in that order.**

**The shape, per section:** open with one or two sentences a cold reader understands with no
prior context. Then give the supporting detail immediately underneath — same section, not an
appendix, not a footnote.

> **Plain:** The access rules match the certificate name and cannot see which authority issued
> it, so the name has to carry the issuer itself.
>
> **Detail:** The link layer parses the peer certificate and keeps a single string. A rule
> granting `fed.xaa.*` can therefore only be satisfied by a certificate whose name begins
> `fed.xaa.`, so nothing our own authority minted can satisfy it.

Both failure directions are real, and the second is the one to watch:

| Failure | Looks like | Fix |
|---|---|---|
| **Too thin** | "The storage card", "the config file", "it was slow" — no model, host, path or number. A reader cannot look any of it up or act on it | Name the specific thing |
| **Too dense** | Opening a section with the mechanism, so a reader who does not already know the subsystem cannot get in | Lead with the plain claim, then the mechanism |

**What counts as salient detail:** real names a reader can look up — hosts, file paths with
line numbers, identifiers, commands, versions — and numbers with their units and how they were
obtained. **What does not:** invented shorthand, session-local abbreviations, or restating the
plain sentence in more words.

The test: **a reader who stops after the first two sentences of a section should have learned
something true and usable.** A reader who continues should get enough to act without asking a
follow-up question.

---

## 4. State the design, not the derivation

A reader must not be able to reconstruct the order things were discovered in. Banned shapes:

- "The weakness is X. **The fix:** Y." Describe Y as part of the design.
- "None of this is a new idea", "it turns out", "we found that".
- A **question-and-answer table mirroring the conversation.** Decisions go in a register as
  declarative statements plus rationale: *"Peering uses a third dedicated tunnel, not a join
  to either party's network — because a join hands over control of reachability."* Never
  *"Question: should we join their network? Answer: no."*
- "Read the section above again and notice what is missing."

---

## 5. Every sentence completes its claim

The specific failure: a clause that sets up a consequence and stops.

> "The rules match this name and cannot see the issuer. **So the name has to say.**"

Say what. "The name must therefore carry the issuer itself." Never write "the reverse holds"
— write the reverse. Never leave a pronoun whose referent changed mid-sentence.

---

## 6. Read the rendered prose before publishing

Not the diff.

```bash
sed -n '/<h2>First real section/,$p' doc.html | sed 's/<[^>]*>/ /g' | tr -s ' ' | fold -s -w 160
```

Fragments, half-thoughts and stale identifiers are invisible in a diff and obvious in stripped
text. The operator should not be the one who finds them.

---

## 7. Never reference an artifact the reader has not seen

"The decisions table is the problem", said before publishing the table, names something that
exists only in your working state. Unpublished sections, in-flight edits and internal
filenames are not shared context. Publish first, or describe the thing instead of pointing
at it.

---

## 8. Status words are distinct and never blurred

| Word | Means |
|---|---|
| **Measured** | A command ran and produced this result |
| **Built** | The code exists and is deployed |
| **Written** | The document or specification exists |
| **Designed** | Decided, not implemented |
| **Not built** | Nothing exists |
| **Unmeasured** | Exists but was never exercised |

Never write "smoke tested" unless a command did it. For a two-direction claim, say which
direction was proven and which was not.

---

## 9. Rewrite in place; do not accrete

After several rounds of feedback, rewrite the affected section rather than appending a
correction. Accretion produces the derivation-shaped document in rule 4: each round adds a
"but actually" beat until the whole thing reads as a transcript.

---

## 10. No excuse framed as a diagnosis

Do not explain a quality failure by chain length, context usage, or task complexity. It is
unfalsifiable and almost never the cause. Fix the work, say what was wrong in one sentence,
continue.

---

## Checklist

**Before starting:** intent stated in plain words; reader named; "done" defined.

**Before publishing:**

1. Output checked against the operator's **quoted** instruction (not my paraphrase of it); delegated output read
   by me against that quote, not only gated for form.
2. Rendered prose read cold, start to finish.
3. No performed care, cleverness or candour: no caveat, history or hedge that is not germane to the reader.
4. **Every section opens plain and then goes deep** — a cold reader gets in, an acting reader gets specifics.
5. Real names throughout: hosts, paths with line numbers, identifiers, commands, numbers with units.
6. No derivation beats, no conversation-shaped tables.
7. Status words from rule 8 used precisely.
8. No stale identifiers — grep for names replaced earlier in the session.
9. Examples cannot be misread as syntax (a party named `any` yields the rule `fed.any.*`).
10. Nothing referenced that the reader has not been shown.
