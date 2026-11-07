# Print and PDF

## Build

`python3 scripts/pdfgate.py build page.html -o page.pdf --pages N --size letter` runs headless Chrome with
`--print-to-pdf`, a fresh profile, `--no-pdf-header-footer`, a hard timeout and a freshness check, then runs
every check below. Chrome is the renderer because it matches the HTML exactly (record W9); its failures are
silent, so the checks are not optional.

Chrome can write the PDF and then hang on exit, or hang before writing and leave yesterday's PDF looking
current (record F19). The build kills the process group once a fresh file exists and fails if the file is
older than the build.

## Checks (`pdfgate.py check`)

| Check | Rule | Evidence |
|---|---|---|
| Type 3 fonts | Zero. Counted from `pdffonts`' type column, never matched by font name | 304 and 270 Type 3 fonts in two circulated PDFs (F15); a `system-ui` page measured 7 of 7 on 27 Oct 2026 |
| Pages | Exactly `--pages` | a one-pager printing on two; a ten-pager at 13 |
| Page size | One size, the one `--size` names | |
| Shrink | Body text box height equals `--body-pt` (pin it from a known-good build; the gate prints it) | Chrome scales the whole document when one element is too wide (F5) |
| Blank page | Under 1 % ink on a non-final page | |
| Bottom gap | Under 40 % of a non-final page empty at the bottom; `--allow-gap N` for a page that is a deliberate break | calibrated on 141 pages: legitimate max 38 %, defects 58-81 % (W19) |
| Punctuation | A line starting with `. , ; :` is a warning | orphaned full stops after UI keys (guides round 5) |

## Rules that keep PDFs clean

- **Fonts**: an offline stack of faces that embed as TrueType: Helvetica Neue / Helvetica / Arial for text,
  Menlo / Consolas / Courier New for code, Georgia for serif. Never lead with `system-ui`, `-apple-system`
  or `ui-serif`/`ui-monospace` in anything that will be printed. Glyphs the body font lacks (arrows, ticks,
  circled numerals, box drawing) fall back to a system face and embed as Type 3: replace the glyph with SVG
  or a word.
- **Print styling on tokens**: `@media print { :root { --ink: ...; } }`, never selector overrides; a print
  rule with lower specificity than the base rule is silently dead (F16).
- **Width**: nothing wider than the printed column (691 px for Letter with 0.65 in side margins). figlint's
  print pass reports `print-too-wide` before you print. No `nowrap` on long table cells.
- **Breaks**: `break-inside: avoid` on figures, callouts and table rows; `break-after: avoid` on headings.
- **Figures in print**: figlint's print pass checks printed text size (10.5 px minimum, an error). A standard
  figure (<= 300 units tall) at full column width prints 13-unit text at about 11.8 px. If the page caps
  figure height, shrink the figure's budget, not the cap (F2).
- **Explainers in print**: the key frame plus every caption as a numbered list; hide controls and any
  "press Play" instruction.
- **Look at the PDF**: `pdftoppm -png -r 110 x.pdf png/x` and read the pages. 72 dpi hides the difference
  between a 10 px label and a clipped one (F24).
