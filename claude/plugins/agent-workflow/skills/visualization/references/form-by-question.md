# Choosing the form

Decide the form from the reader's question before any drawing. State the finding as a title and the whole
message as one sentence of alt text first; if you cannot, you do not yet know what the figure is for.

| The reader asks | Form | Pattern / tool | Avoid |
|---|---|---|---|
| In what order? | process line (numbered steps, arrows, an optional bracket over a span) | `process_line` | a flowchart with branches for a linear process |
| What decides, between which options? | fan-out from one owner | `fan_out` | a decision tree deeper than two levels in one figure |
| What wraps what? | nested layers, outermost first | `layers` (<= 6), else `stack` | concentric circles with labels on arcs |
| What is inside the boundary, and what happens when it is cut? | enclosure + link, with a cut mark | `enclosure` | dashed short links (they print as fragments) |
| What changed? | before / after, two panels and the change between | `two_state` | two separate figures the reader must compare across pages |
| When? | timeline, labels alternating above and below | `timeline` | a Gantt chart unless durations matter |
| Which option, on what? | matrix up to 7 rows; a real HTML table beyond | `matrix`, `<table>` | a chart for categorical comparisons |
| What sits on what? | stacked tiers with parts as chips | `stack` | a 3-D stack unless the illustration style is isometric |
| Where? | schematic area with numbered markers and callouts beside it | `map_callouts` | labels over a raster basemap |
| How does it scale? | two structures side by side with computed counts, then a chart | `hub_vs_mesh`, `annotated_chart` | numbers typed into labels |
| How much / what trend? | annotated line or bar chart | `annotated_chart`, `chartkit` | legends, dual axes, truncated bars |
| How do several compare over time? | small multiples on one scale | `small_multiples` | one chart with nine lines |
| How does it change, step by step? | animated explainer | `timeline.js` + `explainer.py` | a GIF or video (not checkable, not accessible) |
| What if I change this? | explorer with sliders or drag | `Viz.explorer`, `templates/explorer-template.py` | a movie of every value |
| What does it look like? | illustration: isometric module or a hand-laid symbol scene | `references/figure-grammar.md` | clip-art, photos with labels pasted on |
| How do I do it in a product? | a diagram of the real interface labels, or a clean real crop | figkit boxes with UI words | mock screens (record F7) |

## Size and variant

- A one-pager or a figure beside text: slim (<= 240 units).
- A three- or ten-page document: standard (<= 300).
- A reference sheet that will not be printed in a compact layout: tall (<= 380).
- An explainer stage: <= 460, screen-first, with a printed key frame.
- A slide: `Figure(width=1200)` keeps the same proportions; nothing smaller than 13 units at 760-equivalent.

## Two audiences

If a figure must serve experts and lay readers, make a detailed figure and a simplified companion (record
W13) rather than one figure that serves neither. The simplified one is usually a slim variant of the same
pattern with fewer items.
