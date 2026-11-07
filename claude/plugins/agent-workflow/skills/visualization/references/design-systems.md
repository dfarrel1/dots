# Design systems: detect, adopt, or create

Every figure colour is a ROLE, and the stylesheet maps roles to tokens. That one indirection is what lets a
figure follow a provided system, flip to dark mode, and print correctly without being redrawn.

## The roles

`ink` `quiet` `rule` `line` `paper` `panel` `accent` `accent-soft` `on-accent` `good` `good-bg` `warn`
`warn-bg` `info` `info-bg` `crit` `crit-bg` `mute` `mute-bg`. Plus `--font` and `--mono` (the stack is
layout: re-measure when it changes). Figure classes (`t`, `tq`, `bx`, `bxa`, `lna`, `fa`, ... in
`templates/viz-base.css`) reference roles only.

## Decision

| Situation | Do |
|---|---|
| The user names a system, or the repo has one (design-system doc, tokens file, CSS with many custom properties) | **Adopt it** (below). Do not import a second token set. |
| No system; one or two one-off figures | **Bundled default**: `templates/viz.css`. Measured; do not edit by eye. |
| No system; a document family, a deck, or more than three figures | **Create a minimal one** (below) and reuse it for every artifact in the delivery. |

Apply a system to the whole family of outputs at once, or not at all: a system on 1 of 9 surfaces "does not
look 11 percent better; it looks broken" (record F20).

## Adopt a provided system

1. Find it: `python3 scripts/tokens.py detect <repo or folder>`. Read its own docs (README, design-system.md,
   SKILL.md) as canon: figure style rules (for example "thin strokes, no fills, captions in mono") and voice rules.
2. Map roles to its tokens. `detect` proposes a map by name; check every line by hand and save `map.json`
   (`{"ink": "--color-text", "accent": "--brand", ...}`; a literal colour is allowed for a role it lacks).
3. If its token names differ from the roles, generate the adapter: `tokens.py adapt their.css --map map.json -o roles.css`
   and load `roles.css` after their stylesheet. Same names (as in `examples/proof/provided/`): nothing to adapt.
   Roles the system lacks (often line, the soft and -bg tints, on-accent, info, mute) are DERIVED from the
   roles it has with CSS `color-mix(in oklab, ...)`, so they follow its light and dark values; `adapt` writes
   them with a comment naming them as declared deviations. Check with `tokens.py check their.css --map map.json --complete`,
   which evaluates the same expressions. Tested on a GitHub-style token set (`evals/chart-in-provided-design-system`):
   9 roles mapped, 10 derived, 30 of 31 pairs pass; the one failure is the system's own warning colour at
   4.45:1 on its tint, so in that system a warn box gets an ink heading (or the pair is waived if never drawn).
4. Measure contrast in every output path: `tokens.py check their.css --map map.json`. Light, dark and print.
   - A dark-only system (no light theme) needs a print remap ON TOKENS: add an `@media print { :root { ... } }`
     block. Never override selectors for print (record F4, F16).
   - A failing pair the deliverable never draws can be waived, as a declared deviation with its reason:
     `--waive line/panel`. Example: the provided system in `examples/proof/provided/` measures `line` on
     `panel` at 2.83:1 (under 3:1); the proof figures never outline a shape on a panel, so it is waived there
     and recorded in the critique log. A pair that is drawn is fixed, not waived.
5. Re-measure fonts for its stack: `node scripts/measure_fonts.mjs --fonts '<its --font stack>' --out <dir>/font-metrics.json`,
   then `figkit.use_metrics('<dir>/font-metrics.json')` before building. A stack with `system-ui` or
   `-apple-system` first is measured with the system face (it is wider) and is a Type 3 risk in PDF: run pdfgate.
6. Where it has no rule for a figure need (status, planned, cut), use this skill's grammar and record the
   addition as a declared deviation in the deliverable's source.

## Create a minimal system

1. Copy `templates/tokens-default.json` and `templates/design-system-starter.md` next to the work.
2. Choose the accent and status hues; keep backgrounds light and low-chroma in light, deep and low-chroma
   in dark ("lifted, not inverted").
3. `python3 scripts/tokens.py generate spec.json --fix -o tokens.css`. `--fix` moves only foreground
   lightness (hue and saturation kept, backgrounds never moved) until every pair passes; it prints each change.
4. `cat tokens.css templates/viz-base.css > system.css`; build with `css=[system.css]`.
5. Fill in the starter: the semantic legend (one accent; colour plus line style per meaning; status as a
   word), the type scale, the spacing grid and the figure variants. One page, written once, reused.

## The bundled default

`templates/tokens-default.json` -> `tokens-default.css` (generated) + `viz-base.css` = `viz.css`.
Every role pair passes in light, dark and print (31 pairs; `tokens.py check templates/viz.css`). The font
stack is `"Helvetica Neue", Helvetica, Arial, "Liberation Sans", sans-serif`: offline, no system-ui (Type 3
in PDF, measured 27 October 2026: 7 of 7 fonts on a system-ui page). Metrics: `scripts/font-metrics.json`.

The default deliberately does not reuse any one document family's accent: its structure and method come
from the persona library's measured system (record 5.3), its hue is its own, so a default figure never
passes as part of a family it does not belong to.
