# Lessons from the record

The skill is built on an evidence record of six months of figures, explainers and printed documents
(compiled 26 October 2026, kept privately). Codes below (W1, F8, class 3) are that record's own. This file keeps what changes
behaviour; read the record for the evidence trail.

## The five lessons

1. **Measure before placing; refuse to write what does not fit.** Text measured with metrics that cover
   every font a reader may have (max across the stack, +6 %), and a generator that raises on a broken figure,
   removed the largest defect classes at authoring time (W1, W2). In the skill: `figkit`, `font-metrics.json`.
2. **Lint the render in every path the reader uses.** Light, dark, narrow, print, PDF fonts and every
   animation step each produced defects the others missed; source greps and single-width checks were
   unreliable (F5, F15, F16, F17). In the skill: `figlint` (themes x widths x print x frames), `pdfgate`.
3. **Budget figures from the print cap backwards.** Height limits per variant (slim 240, standard 300 at 760
   wide) fixed small printed type; enlarging the cap only moved the problem into page counts (W8, F2).
4. **One design system per family, mapped onto fixed roles and measured.** Twelve systems with conflicting
   meanings for amber, red, green and dashes exist across the sources; partial adoption reads as broken (F20).
   In the skill: 19 roles, `tokens.py`, adopt for the whole family or not at all.
5. **Looking is part of the build, and so is ownership.** Critique rounds found what lints cannot (empty
   space, ambiguous labels, orphans, fake screens); figure warnings with no owner stayed unfixed across 99
   documents (F21). In the skill: render, read, log; every warning fixed or justified in writing.

## What worked (keep doing)

| Code | Method | Where it lives now |
|---|---|---|
| W1-W3 | Measure text; refuse to write; compute geometry in code, never hand-type text coordinates | `figkit.py`, `patterns/` |
| W4 | Lint in a real browser: both themes, two widths, every step | `figlint.mjs` (plus print and transition frames) |
| W5 | Render, then read the PNGs, in logged rounds | `render_png.mjs`, `references/critique-loop.md` |
| W6, W7 | Inline SVG themed by classes and tokens; label halos (`paint-order: stroke`) | `viz-base.css` (`.halo`), `text(..., halo=True)` |
| W8 | Height caps per variant, from the print cap | `figkit.MAX_H` |
| W9, W10 | Chrome print plus machine checks of the PDF; a font stack that embeds cleanly | `pdfgate.py`; default stack Helvetica Neue / Helvetica / Arial |
| W11 | Semantic, honest colour and line styles; planned things dashed; status as a word | `references/figure-grammar.md` |
| W12 | Titles state the finding; alt text states the whole message | `Figure(title, alt)` refuses a short alt; figlint `figure-no-alt` |
| W13 | Detailed figure plus a simplified companion | slim variant; `references/figure-grammar.md` |
| W14, W16 | One source, several outputs, outputs never edited | build scripts; `explainer.page`, `figkit.page` |
| W17 | Reserved space: nothing jumps when later steps arrive | timeline formula rows; `references/animation.md` |
| W18 | Diagrams from real interface labels, never fake screens | `references/critique-loop.md` checklist |
| W19 | Thresholds calibrated on measured populations | `pdfgate` gap 0.40; figlint empty-space 0.16 (calibrated below) |
| W20 | Fewer things, larger | `references/figure-grammar.md` |

## What failed (do not repeat)

| Code | Failure | Rule |
|---|---|---|
| F1 | Box sizes typed by hand, text sized afterwards; a regex font-size bump moved the defect | Let figkit size boxes; never bump sizes without re-layout |
| F2 | Figures too tall for the print cap | Respect variant height limits; split or make an explainer |
| F3, F18 | Font-stack change reflowed every page; webfonts that could never load | The stack is layout. Re-measure when it changes; no remote fonts offline |
| F4 | Contrast failures: colours by eye, literals outside tokens, print overrides on selectors | `tokens.py check` in light, dark and print; classes only |
| F5, F16 | Chrome silently shrank over-wide pages; print rules dead through specificity | figlint `print-too-wide`; `pdfgate --body-pt`; print on tokens |
| F6 | Labels overflowing at narrow widths | figlint at 680 px; `.fig.scroll` for figures that must keep size |
| F7 | Fake or staged screenshots | Real crops from a clean session, cropped to the control, or a diagram of real labels |
| F8 | Mermaid failing silently (an error box shipped), unthemeable | No Mermaid for shared figures |
| F9 | Graphviz layout ignoring the page; warnings not failures | No auto-layout for shared figures |
| F10, F11, F12 | Prose in diagrams; dense many-item illustrations; over-detailed icons | <= 5 words per label; detail to the caption; plain icons; figlint `label-words`, `prose-in-box` |
| F13, F14 | Raster figures pasted into decks; labels over a raster basemap | SVG only; numbered markers with callouts beside the map (`map_callouts`) |
| F15 | Type 3 fonts in PDFs | pdfgate counts Type 3 from `pdffonts`; re-measured 27 Oct 2026: a `system-ui` page embeds 7 of 7 fonts as Type 3 (`examples/proof/negative/type3.html`) |
| F19 | Chrome headless hangs, leaving a stale PDF | `pdfgate build`: fresh profile, hard timeout, freshness check |
| F21 | Warnings orphaned between roles | Whoever builds the figure owns its warnings |
| F22 | Hard-coded tool paths; stale previews | `pw.mjs` resolves Playwright; builds write outputs from source every time |
| F24 | 72 dpi proof renders | `render_png` refuses device scale under 1.5 |

## Defect classes, ranked, and what catches each now

| Rank | Class | Caught by |
|---|---|---|
| 1 | Text too small, on page or in print | figkit `MIN_SIZE`; figlint `small-text`, `small-authored`, `print-small-text` (E) |
| 2 | Text crossing a box edge or not fitting | figkit clearance; figlint `text-crosses-box` (now true circle outlines), `text-clearance`, `text-tight` |
| 3 | Arrow wrong: through text, short, no head | figkit `connect`; figlint `line-through-text`, `arrow-short`, `arrow-no-head` (new) |
| 4 | Page layout: overflow, shrink, breaks, page count | figlint `html-overflow`, `print-too-wide`; pdfgate pages, gap, blank, size, `--body-pt` |
| 5 | Wrapping: orphans, broken names, unbalanced siblings | figkit balanced wrap; figlint `orphan` (HTML and SVG, new); `text-wrap: pretty`; looking |
| 6 | Contrast and dark mode | `tokens.py` (light, dark, print); figlint `low-contrast`, `svg-low-contrast` (new: text on the shape under it) |
| 7 | Empty or unbalanced space | figlint `empty-space` (new: largest empty rectangle) + looking |
| 8 | Prose or too many items in the drawing | figlint `label-words`, `prose-in-box` (new); pattern item limits |
| 9 | Fonts: Type 3, unloadable webfonts, reflow | pdfgate `type3`; figlint `remote-resource` (new); measure_fonts per stack |
| 10 | Screenshot hygiene and fake screens | looking (critique checklist) |
| 11 | Renderer failing silently | no Mermaid/Graphviz; pdfgate freshness check |
| 12 | Stale or wrong copy delivered | build from source; deliver the file the build just wrote |
| 13 | Labels over raster or canvas | SVG text only; canvas needs a DOM label overlay (`references/animation.md`) |

## Calibration of the new figlint checks (W19)

Run on the persona-library family on 26 October 2026, which the older figlint passed at 0 errors and 0
warnings (17 files, 85 renders): the new checks raised **0 errors** (no false-positive contrast, arrow or
overflow errors) and 22 warnings, all explained: long titles and notes before `data-role` marked them (now
exempt), two cut-link relation lines with no head (now `nohead`), one real orphan the original log accepted.
`empty-space` at a 16 % threshold raised nothing on that family and fires on the patterns' sparse worst
cases (2-item, 9-item) and on a deliberately empty test figure. Raise a threshold only against a fresh measurement.
