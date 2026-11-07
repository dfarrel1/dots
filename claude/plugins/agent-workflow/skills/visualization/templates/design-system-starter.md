# <Name>: figure design system

One page, written once, reused for every figure and page in the family. Generated tokens live in
`tokens.css` (from `spec.json` via `tokens.py generate spec.json --fix`); this page records the decisions.

## Roles and tokens

| Role | Light | Dark | Means |
|---|---|---|---|
| ink / quiet | | | text / secondary text |
| rule / line | | | hairlines / outlines and neutral connectors |
| paper / panel | | | page / context panels |
| accent / accent-soft / on-accent | | | the thing the figure is about; one per figure |
| good (+bg) | | | live, keeps working, end state reached |
| warn (+bg) | | | attention, waits, planned |
| info (+bg) | | | context, built not deployed |
| crit (+bg) | | | a general hazard only |
| mute (+bg) | | | inert, erased, not built |

Contrast: paste the table from `tokens.py check tokens.css` here (light, dark, print). Any waived pair: say
which, and why it is never drawn.

## Type

Stack: `<font stack>` (offline; no system-ui first; re-run `measure_fonts.mjs` if it changes).
Figure sizes at a 760-wide viewBox: title 18, heading 15, body 14, labels 13 (minimum 13).

## Grid and variants

760 wide, 20 margin, 24 gutter, 8 clearance. Slim <= 240, standard <= 300, explainer stage <= 460.

## Semantic legend (one meaning each)

| Mark | Means |
|---|---|
| solid accent line | the main data path |
| dashed line | control or management traffic |
| dashed outline | designed, not built |
| amber cross on a line | a link that is down |

## Declared deviations from the skill's grammar

- <none, or each one with its reason>
