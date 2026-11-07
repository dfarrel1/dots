---
name: visualization
description: Make illustrations, diagrams, figures, charts, and 3Blue1Brown-style animated or interactive explainers to a high, checked standard, in a provided design system or a measured one. Use this skill whenever the user asks for a diagram, illustration, figure, chart, graph, visual, infographic, architecture or process picture, timeline, comparison graphic, explainer, animation, interactive or explorable demo. Also use it when they ask to illustrate, visualize or "add a picture to" a document, brief, report, deck or page, or when a figure in an existing document looks wrong (overlaps, clipped text, tiny labels, bad dark mode, a PDF that prints badly). Use it before writing the first line of SVG, figure code or animation code, even for a quick one-off.
---

# Visualization

Figures that are measured before they are drawn, linted in a real browser in every way a reader sees them,
and looked at before delivery. Built from a record of what worked and failed across six months of this
user's figures (`references/lessons-from-record.md`). Read it once; it explains every rule below.

## 0. Decide the form, and state the finding

Before drawing anything, write two sentences:
1. **The finding**, as the title: "A restart always gets a new key", never "Key lifecycle". If it needs "and",
   it is two figures.
2. **The alt text**: the whole message in one sentence, with its key facts.

Then pick the form from the question the reader is asking:

| The reader asks | Form | Start from |
|---|---|---|
| In what order? Who does what next? | Process line | `patterns.process_line` |
| What is inside what? Which layer wraps which? | Layers | `patterns.layers` |
| What is in the boundary; what happens if it is cut? | Enclosure | `patterns.enclosure` |
| Who decides, and between which options? | Fan-out | `patterns.fan_out` |
| What changed? | Before / after | `patterns.two_state` |
| When? | Timeline | `patterns.timeline` |
| Which option is better, on what? (up to 7 rows) | Matrix; more rows is an HTML `<table>` | `patterns.matrix` |
| What sits on what? | Stack of tiers | `patterns.stack` |
| Where? | Schematic map with numbered markers | `patterns.map_callouts` |
| How does it scale / one structure against another? | Hub against mesh, or a chart | `patterns.hub_vs_mesh`, `annotated_chart` |
| How much, how fast, what trend? | Annotated chart | `patterns.annotated_chart` |
| How do several things compare over time? | Small multiples, one shared scale | `patterns.small_multiples` |
| How does it change, step by step? | Animated explainer (timeline engine) | `examples/proof/build_pairs_explainer.py` |
| What happens if I change this? | Interactive explorer (sliders, drag) | `templates/explorer-template.py` |
| What does it look like, physically? | Illustration (isometric style module, or a hand-laid scene) | `references/figure-grammar.md` |

More detail and edge cases: `references/form-by-question.md`.

## 1. Start from the nearest pattern, never a blank canvas

Every figure the record shows starting from scratch took 3-7 critique rounds to get right; the patterns
carry those rounds' decisions (pitch, gaps, wrap rules, height budget, what to do at 9 items).

1. Open `patterns/README.md` and pick the nearest pattern (rendered examples, use-when / avoid-when).
2. Copy its call, change the labels and data. Run it. A pattern either builds a checked figure or refuses
   with what to do instead (split, shorten, use a table). A refusal is information, not an error to route around.
3. Only then extend: add a primitive from `scripts/figkit.py` (box, row, column, connect, fan, band, zone,
   node, curve, cut, grid, note) on top of the pattern's figure. Extend a pattern in `patterns/patterns.py`
   when the same shape will recur, and add its worst-case cases to `patterns/test_patterns.py`.

For animated and interactive work, `references/exemplars-public.md` lists the public techniques worth taking.

## 2. Design system: detect, adopt, or create

- **Provided** (the user names one, or the repo has a design-system doc or a CSS file with custom properties):
  run `python3 scripts/tokens.py detect <path>`, read the system's own docs as canon, confirm the proposed
  role map by hand, then `tokens.py check <css> --map map.json`. Re-measure fonts for its stack
  (`node scripts/measure_fonts.mjs --fonts '<its stack>' --out <dir>/font-metrics.json`, then
  `figkit.use_metrics(path)`). Adopt it for the whole family of outputs, or not at all.
- **None provided, one-off figure**: use the bundled default (`templates/viz.css`). It is measured; do not edit colours by eye.
- **None provided, a document family or more than three figures**: create a minimal measured system from
  `templates/design-system-starter.md` and `tokens.py generate spec.json --fix`, and write it down once.

Every figure colour is one of 19 roles (ink, quiet, rule, line, paper, panel, accent, accent-soft, on-accent,
good, warn, info, crit, mute, each status with a -bg). Figures use classes only, never literal colours, so
light, dark and print all follow from the tokens. Full procedure: `references/design-systems.md`.

## 3. Build

- **Static figures**: figkit (patterns are figkit). Hand-laid SVG, measured text, CSS-variable tokens. No
  Mermaid, Graphviz or draw.io for anything shared: they fail silently, cannot follow tokens or dark mode,
  and ignore the page (record F8, F9, F23). Grammar: `references/figure-grammar.md`.
- **Charts**: `scripts/chartkit.py` (honest scale, numbers from data, source and date required). Read the
  `dataviz` skill for palette and mark choice; `references/charts.md` lists what is enforced here.
- **Animated explainers**: `scripts/timeline.js` (eased tweens of position, size, colour and number, draw-on,
  formula highlighting, a scrubbable timeline, keys, reduced motion, a print key frame) and
  `scripts/explainer.py` to wrap it into one self-contained page. Prefer SVG over canvas so text stays
  checkable. Rules and API: `references/animation.md`.
- **Page or document**: `figkit.page()` for figure pages; deliver one self-contained HTML (CSS and JS
  inline, no remote fonts or CDNs unless the user allows them). PDF with `scripts/pdfgate.py build`.

## 4. Gates: zero errors before delivery

Run all that apply. Zero errors is the bar. Every warning is either fixed or justified in writing in the
critique log, with its reason. Never weaken a check or a threshold to pass; fix the figure.

| Gate | Command | Catches |
|---|---|---|
| Construction | the figkit / pattern build itself | overlaps, clearance < 8, text off-canvas, arrows off their target, text < 13 units, height over budget |
| Browser lint | `node scripts/figlint.mjs <files>` | the same in real Chrome, light + dark, 900 + 680 px, print; every explainer rest frame AND transition frame (sampled every 0.1 s); contrast incl. SVG text on its shape; small text; overflow; alt text; orphans; prose in boxes; empty space; remote requests; undefined CSS variables |
| Tokens | `python3 scripts/tokens.py check <css> [--map]` | every role pair in light, dark and print |
| PDF | `python3 scripts/pdfgate.py build page.html -o x.pdf --pages N --size letter` | Type 3 fonts (counted, not matched by name), page count, page size, blank pages, bottom gaps, punctuation starting a line |
| Patterns | `python3 patterns/test_patterns.py` | after any change to figkit or a pattern |

Chrome needs the sandbox disabled. Playwright is found automatically (npx cache, global, local); if missing,
the scripts say how to install it.

## 5. Look, in rounds, and log it

Gates do not catch everything: most defects in the record were found by looking. After the gates pass:

1. `node scripts/render_png.mjs --print --sheet <files>` (light and dark, 900 and 680 px, every explainer
   rest frame; `--frames all` for transitions). Device scale is at least 1.5.
2. Read every PNG with the Read tool. List defects by class: empty space, prose in the drawing, ambiguous
   labels, orphan words, unbalanced sibling wraps, a crowded title, a fake screen, colour meaning drift,
   a print-only problem. The checklist is `references/critique-loop.md`.
3. Fix, rebuild, re-gate, re-render. Repeat until a round finds nothing.
4. Keep `critique-log.md` beside the work: one table per round (item, defect, fix), the gate results, and
   every accepted warning with its reason.

## 6. Deliver

- One self-contained HTML (and a PDF when asked), built from source; never hand-edit an output.
- Report: the gate results, the number of critique rounds, and anything accepted with its reason.
- If the work will be published as an artifact, the page contract of the `artifact-design` skill applies too.

## Files

```
scripts/   figkit.py chartkit.py tokens.py figlint.mjs render_png.mjs pdfgate.py timeline.js explainer.py
           measure_fonts.mjs pw.mjs font-metrics.json
patterns/  patterns.py (12 patterns)  test_patterns.py  README.md  png/
templates/ viz.css (= tokens-default.css + viz-base.css)  tokens-default.json  explainer.css
           figure-template.py  explainer-template.py  explorer-template.py  design-system-starter.md
references/ form-by-question.md figure-grammar.md design-systems.md charts.md animation.md print-and-pdf.md
           critique-loop.md lessons-from-record.md exemplars-public.md
examples/  proof/ (rebuilt figures, the explainer, the design-system demo, critique log)
```
