# The critique loop

Most defects in the record's logs were found by looking, not by a checker: orphans, empty bands, ambiguous
labels, crowded titles, a fake screen. So looking is part of the build, in rounds, logged.

## Each round

1. Build from source (never hand-edit an output).
2. Gates: the build itself (figkit refuses), `figlint`, `tokens.py check`, `pdfgate` when there is a PDF.
3. Render: `node scripts/render_png.mjs --print --sheet <files>` (light and dark, 900 and 680 px, the print
   layout, every explainer rest frame; add `--frames all` for transitions).
4. Read every PNG with the Read tool, at full size. Then go through the checklist below, one class at a time.
5. Log the round (template below). Fix every defect at its cause: the layout, the copy, or the pattern.
   If the fix belongs in a pattern or in figkit, fix it there so the next figure does not repeat it.
6. Repeat until a round finds nothing. The final round is a confirmation round and is logged too.

## Checklist: defect classes no checker catches (or catches only partly)

| Class | Look for | Usual fix |
|---|---|---|
| Empty space | a region with nothing in it, a box much larger than its text, a band of white between title and content | tighten the layout, move the note up, use the slim variant, or reserve the space on purpose (say so) |
| Prose in the drawing | a label longer than about five words, a sentence inside a box, an edge label with a clause | move detail to the caption or the dated note |
| Ambiguous labels | a number with no unit, two rings labelled without saying which is which, "it" or "this" | say what it is: "inner: TLS", "4 on day 5" |
| Orphans and unbalanced wraps | one word alone on a line; a heading that wraps while its siblings do not; a name broken at a hyphen | shorten, balance, or use a no-wrap span for names |
| Crowded or detached labels | a bracket label touching the title; a label nearer the wrong object | add room in the pattern, not by nudging |
| Fake screens | a mock window, a drawn UI, a screenshot of a test account, a half-cut control | a diagram of real interface labels, or a clean crop of the real control |
| Colour meaning drift | red for something that is not a hazard; two accents; status shown only by colour | one accent; status as a word; red only for hazard |
| Density | many small repeated items; decorative icons | fewer things, larger, with a label saying what they stand for |
| Motion | a jump (layout shift) between steps; an element vanishing and leaving a hole; two things changing at once; a caption that does not match its frame | reserve space; replace in place; one change per step; check rest frames against captions |
| Print-only | an instruction that makes no sense on paper; a formula broken across lines; a figure split across pages | hide screen-only text; non-breaking spaces in formulas; break-inside: avoid |

## Log template (`critique-log.md` beside the work)

```markdown
# Critique log: <work>

## Round N: <what was rendered> (<themes>, <widths>, print?, frames?)
| Item | Defect (class) | Fix |
|---|---|---|
| figure-name | "Credentials issued" wraps while siblings do not (unbalanced wrap) | label shortened |

Gates: figkit ok; figlint <files>: E errors, W warnings; tokens: P pairs, F failing; pdfgate: <result>.
Accepted (with reason): <warning> - <why it is correct as drawn>.
```

A warning is accepted only with a reason a reader can check ("the empty block at step 1 is the ring's
reserved space; filling it would make later steps jump"). "Looks fine" is not a reason.
