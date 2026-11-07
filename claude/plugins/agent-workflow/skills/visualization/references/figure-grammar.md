# Figure grammar

The same kind of thing is always drawn the same way. These rules are what figkit, the patterns and figlint
enforce; when a provided design system has its own rule for something, its rule wins and the difference is
written down as a declared deviation.

## Principles

1. **The title states the finding.** One idea per figure; if the title needs "and", make two.
2. **Meaning before ornament.** Colour, shape, line style and weight each mean one thing. No shadows,
   gradients, clip-art, 3-D (except a deliberate isometric illustration style), or decoration.
3. **Words on the thing.** Labels sit on or beside what they name; no legends where a direct label fits.
   Labels are five words or fewer; detail goes in a quiet sub-line, the caption, or the dated note.
4. **Correct by construction.** Layout is computed; text is measured before it is placed; boxes take the
   height their text needs. A figure that fails its check is not written.
5. **Honest and dated.** Anything that shows status carries its date; planned things are drawn as planned
   (dashed); illustrative numbers say so.
6. **Fewer things, larger.** Show a small representative number and let a label say what they stand for.

## Canvas and type (units at a 760-wide viewBox; `Figure(width=W)` scales everything by W/760)

| Item | Value |
|---|---|
| Width / margin / gutter | 760 / 20 / 24 (rows with arrows: 28-32 gap so shafts are at least 18 long) |
| Box padding | 16 horizontal, 14 vertical (10 in a compact stack; never less) |
| Clearance | 8 between text ink and any box edge or line |
| Height budget | slim <= 240, standard <= 300, tall <= 380 (reference sheets only), stage <= 460 (explainers) |
| Type | title 18/700, slim title 16, box head 15/700, body 14, sub and labels 13, numeral 28 |
| Minimum | 13 units. At the 680 px check a 13-unit label renders at about 10.6 px; figkit refuses smaller |

A figure in a page column scales with the column. On phones, either use a slim variant or wrap the figure
in `.fig.scroll` (it keeps its size and scrolls sideways) rather than let 13-unit text fall below 10 px.

## Shapes

| Thing | Drawn as | figkit |
|---|---|---|
| System, service, device, step | rectangle, radius 8 | `box(shape="service")` |
| Person, unit, organisation, owner | rectangle, radius 20 | `box(shape="person")` |
| The shared thing everything sits on, or a closing statement | full-width band | `band()` |
| Site, host, boundary | rectangle, radius 12, behind its contents, label top-left | `zone()` |
| Designed or not built | dashed outline | `box(tone="planned")` |
| Step in a sequence | numbered disc | `disc()`, `box(badge=n)` |
| A system in a network drawing | outlined circle | `node()` |
| Data store, key, person, device, service | plain 24-unit icons | `draw_icon()` |

## Lines

| Meaning | Style | Class | `kind` |
|---|---|---|---|
| Data flow, the main path | solid accent, 2 | `lna` | `flow` |
| Relation, sequence, neutral connector | solid line colour, 1.25 | `ln` | `neutral` |
| Control or management traffic | dashed 6/5, 1.25 | `lnd` | `control` |
| A link that is down | its own line, broken by an amber cross, labelled | as the link + `cut()` | |
| Optional path | dotted 2/5, green | `lno` | `optional` |
| Good outcome / attention path | solid green / solid amber, 2 | `lng` / `lnw` | `good` / `warn` |
| Hairline, divider | rule colour, 1 | `lnr` | `rule` |
| Hazard (general only) | dotted red, 2 | `lnx` | `crit` |

Arrowheads are filled triangles drawn as paths (never markers), tip exactly on the target edge (0.75
outside it). A connector that deliberately has no head carries `data-lint="nohead"` (figkit sets it for
fan spines and chart lines).

## Colour semantics

| Fill / outline | Means |
|---|---|
| paper fill, line outline (`bx`) | an ordinary system or step |
| accent-soft, accent outline (`bxa`) | the thing the figure is about (one per figure where possible) |
| good (`bxg`) | live, keeps working, the end state reached |
| warn (`bxw`) | attention, waits, planned |
| mute (`bxm`) | erased, inert, not built |
| panel (`bxp`) | context: the cloud, a background statement |
| crit (`bxc`) | a general hazard, its applicability written beside it |

Never more than two tones besides plain. Colour is never the only signal: status is written as its word,
and a line's meaning is also in its style and label. Red never means "cut" or a series colour.

## Labels

- Inside a box: heading first, then body or sub. Left-aligned in rows of peers; centred only in a single box
  or a column of equal boxes. Balanced wrap; never break inside a name.
- On a connector: above a horizontal arrow, its ink at least 8 above the line; right of a vertical one.
- Over lines or a busy background: a halo (`text(..., halo=True)`, class `halo`), never a moved line.
- The dated note: under everything, quiet 13, "As of <date>:" when it states a status.

## Why no Mermaid, Graphviz or draw.io for shared figures (record F8, F9, F23)

- Mermaid shipped an error box as a figure in one of 184 blocks, unnoticed until a gate was added; its
  styling sits outside the design system (literal hex in `classDef`), so it cannot follow tokens or dark
  mode; its layout cannot be held to a print budget.
- Graphviz output wider than about 1250 px scaled labels below legibility; `rank=same` silently ejected nodes
  from clusters; it was embedded as PNG, so not themeable or editable.
- draw.io was configured twice and never used: a GUI file format does not fit an agent that writes and checks code.
Mermaid remains acceptable for a private sketch in a design doc, never for anything circulated.

## SVG over canvas

Prefer SVG for every figure and explainer: SVG text is real text that figlint can measure, contrast-check
and collision-check, that screen readers read and PDFs keep as text. Canvas text is pixels: no checker in
the record could see it (record 6.1: the canvas animation's labels were never linted). Use canvas only for
thousands of moving marks; then draw labels as an SVG or HTML overlay above the canvas, so they stay checkable.

## Illustration styles

- **Isometric**: true 30 degree projection `X = (x - y) cos30, Y = (x + y) sin30 - z`,
  three-tone faces (top light, left mid, right dark), a 0.9 outline, plain volumes with at most one
  identifying detail, numbered markers keyed to callouts, planned things as pale dashed "ghost" boxes, at most
  four status tags.
- **Scene with symbols**: a `<symbol>` sprite in `currentColor`, used via `<use>`, so icons follow the token
  colour of their context; labels with halos over the scene.
