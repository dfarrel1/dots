# Charts

Palette choice, mark specs and interaction rules for charts are the `dataviz` skill's: read it before the
first line of chart code. This file lists only what this skill adds and enforces, in `scripts/chartkit.py`
and the `annotated_chart` and `small_multiples` patterns.

## Enforced

| Rule | How |
|---|---|
| Numbers come from data | Values and tick labels are computed from the data passed in; never typed into a label |
| Bars start at zero | `Chart(kind="bar")` with a domain above 0 raises |
| A line axis above zero says why | `zero_reason="..."` is required, and drawn on the chart |
| Source and date on every chart | `Chart.finish()` raises without `source=` and `asof=`; drawn as the dated note |
| Direct labels, no legend | Series labelled at their ends; labels dodged so they never overlap |
| One emphasis | Up to 3 series get distinct roles; beyond that the first is the accent and the rest are neutral grey. Crit (red) is never a series colour: it means hazard |
| Small multiples share one scale | One `Scale` object for every panel; the note says so |
| The finding is on the chart | `annotate(x, y, text)`: a dot on the point that matters and a short haloed label |

## Practice

- The title states what the data shows ("Pair-by-pair links outgrow the systems after five"), not the axes.
- Label units once, on the axis title or in the label ("190 links"), not on every tick.
- A bare number beside a name is ambiguous: say what it is ("4 on day 5").
- Prefer small multiples to a chart with more than about five lines.
- A comparison of options on several attributes is a table, not a chart.
- Illustrative numbers are labelled "illustrative" in the source line.
- Animated charts: interpolate between data states with object constancy (each mark keeps its identity
  between states, keyed by its category), so the reader can follow a value as it changes.
