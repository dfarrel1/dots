# Pattern library

Start every new figure here. Pick the nearest pattern, change its labels and data, then extend. Each pattern
is a function in `patterns.py` that returns a checked figkit `Figure`. It adapts to its data (it switches
layout or height variant as items grow) and refuses, naming the alternative, when the data cannot make a
legible figure. `test_patterns.py` builds every pattern with a realistic example, long labels, 2 items and
9 items: 48 cases, all passing (3 of them are expected refusals).

```python
import sys; sys.path[:0] = ["~/.claude/skills/visualization/scripts", "~/.claude/skills/visualization/patterns"]  # expanded
from patterns import process_line, Refused
f = process_line("Nothing is issued until two people approve", "A request moves through ... (the whole message)",
                 steps=[("Request", "by the owner"), ("Review", "first approver"), ("Approve", "second approver"), ("Issue", "automatic")],
                 bracket=(1, 2, "two people"))
f.save("out/approvals.svg")
```

Rendered examples are in `png/` (`<pattern>-<case>-light-900.png`); regenerate with
`python3 patterns/test_patterns.py && node scripts/render_png.mjs --out patterns/png --themes light --widths 900 patterns/out/*.svg`.

| Pattern | Example | Use when | Avoid when | Adapts / refuses |
|---|---|---|---|---|
| `process_line(title, alt, steps, bracket, closing, closing_lead)` | [png](png/process_line-example-light-900.png), [9 steps](png/process_line-9-light-900.png) | an ordered sequence; who does what next; a span to bracket (the approvals) | branches or loops (draw two figures, or an enclosure) | <= 6 steps in one line; 7-10 in two rows; long words fall back to numbered rows; > 10 refuses |
| `hub_vs_mesh(title, alt, n, left, right, hub, note)` | [png](png/hub_vs_mesh-example-light-900.png), [9](png/hub_vs_mesh-9-light-900.png) | one structure against another; how links scale; counts computed, never typed | more than 12 nodes (use `annotated_chart`) | ring radius shrinks to keep the standard height |
| `layers(title, alt, levels, core, note)` | [png](png/layers-example-light-900.png), [long](png/layers-long-light-900.png) | what wraps what: envelopes, encryption layers, nested boundaries | more than 6 levels (refuses: use `stack`) | label and detail on one line inside each level |
| `enclosure(title, alt, zone_label, inside, outside, cut, link_label, note)` | [png](png/enclosure-example-light-900.png), [9](png/enclosure-9-light-900.png) | a site or boundary, what is inside, the link out, a cut-off | more than 9 inside items (a table) | 1-3 columns; falls back to fewer, wider columns for long words |
| `fan_out(title, alt, owner, choices, note)` | [png](png/fan_out-example-light-900.png), [9](png/fan_out-9-light-900.png) | one owner deciding between options; one-to-many delivery | a decision tree deeper than one level | rows of up to 5, fed by a left trunk |
| `two_state(title, alt, before, after, change, note)` | [png](png/two_state-example-light-900.png), [9](png/two_state-9-light-900.png) | before / after; today / target; manual / automated | more than 9 items a side (a matrix or table) | bullets up to 5, compact lines beyond; the gap widens to fit the change label |
| `timeline(title, alt, events, today, note)` | [png](png/timeline-example-light-900.png), [9](png/timeline-9-light-900.png) | dated milestones in order | durations that matter (a Gantt), more than 9 events | labels alternate above and below; wrap under the date |
| `matrix(title, alt, cols, rows, col_widths, note)` | [png](png/matrix-example-light-900.png) | options compared on a few attributes, with status cells as words | more than 7 rows (refuses: an HTML table), prose cells | standard, then tall |
| `stack(title, alt, tiers, label_w, note)` | [png](png/stack-example-light-900.png), [long](png/stack-long-light-900.png) | tiers: what sits on what, with parts as chips | more than 7 tiers | chips flow and wrap to new rows |
| `map_callouts(title, alt, points, region_path, note)` | [png](png/map_callouts-example-light-900.png), [9](png/map_callouts-9-light-900.png) | where: numbered markers on a schematic area, callouts beside it | labels over a raster basemap (record F14) | markers numbered top to bottom; colliding markers refuse |
| `small_multiples(title, alt, panels, source, asof, kind, last_label)` | [png](png/small_multiples-example-light-900.png), [9](png/small_multiples-9-light-900.png) | several series compared on one shared scale | one panel (use a chart) | 1 row up to 3 panels, 3 per row to 6, 5 per row to 9 |
| `annotated_chart(title, alt, series, source, asof, annotate, xlabel, ylabel, zero_reason)` | [png](png/annotated_chart-example-light-900.png), [9](png/annotated_chart-9-light-900.png) | a trend or growth with its finding marked on it | categorical comparison (a matrix or bars) | end labels dodged; more than 3 series: one accent, the rest grey; long series names refuse |

## Worst-case results (`python3 patterns/test_patterns.py`)

All 48 cases pass, including three expected refusals: `layers` at 9 levels, `matrix` at 9 rows and
`annotated_chart` with very long series names. Sparse cases (2 items) raise figlint `empty-space` warnings
by design; the realistic examples raise none that are not listed in `out/figlint.txt`.

## Adding a pattern

1. Write the function in `patterns.py`: title and alt first, measured layout through figkit, `fits()` for the
   height variant, `Refused` with the alternative when the data cannot fit.
2. Add four cases to `test_patterns.py` (example, long labels, 2 items, 9 items, or an expected refusal).
3. Run the tests, figlint on `out/pages`, render, look, and fix the pattern until a round finds nothing.
4. Add a row to the table above.
