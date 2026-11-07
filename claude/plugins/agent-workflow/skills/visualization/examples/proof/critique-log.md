# Critique log: proof set

Every item was built only with the skill (patterns, figkit, chartkit, tokens, timeline engine), rendered to
PNG at device scale 1.5 (light and dark, 900 and 680 px, print), and read with the Read tool. Dates:
26-27 October 2026.

## Pattern library (patterns/, 12 patterns, 48 cases)

### Round 1: all cases built; 22 of the 45 PNGs read (every example, every 9-item case, the long cases of process, layers, enclosure, timeline, stack)
| Item | Defect (class) | Fix |
|---|---|---|
| hub_vs_mesh example | 323 units, over the standard budget (height) | rings shrink 64 -> 56 -> 50 before falling back to tall |
| layers (all) | level labels 7 units from the inner level's edge (clearance; figkit refused) | 34-unit label band |
| enclosure long | "Partner-operated" wider than a third-width box (figkit refused) | falls back to fewer, wider columns |
| two_state 9 | change label wider than the gap (refused) | the gap widens to fit a short label |
| matrix 9 | 490 units, over even the tall budget | > 7 rows refuses: an HTML table |
| small_multiples 9 | 468 units | 7-9 panels in rows of 5 |
| process_line 9 | sparse two-column layout, 40 % one empty block (empty space; figlint agreed) | 7-10 steps in two horizontal rows |
| two_state | change label under the arrow (grammar: above) | label above |
| matrix | cells top-aligned beside bold row heads | cells centred vertically |
| small_multiples | bare "4" beside a panel name (ambiguous label) | value label only with a stated unit (`last_label="{} on day 5"`) |
| annotated_chart | annotation in the title row; 9-series palette used the hazard red | annotation beside its point; > 3 series: one accent, the rest grey; red never a series colour |
| figlint | `empty-space` counted the space beside the title | title and note rows count as occupied |

Gates: figlint on 12 pattern pages: 0 errors, 12 warnings (all `empty-space`, on 2-item and 9-item cases).

### Round 2: the six changed cases re-rendered and read
No defects. Accepted: matrix row heads (15) and cells (13) differ by 2 units in centring; the 2-item cases are sparse by nature.

## Rebuilt figure 1: onboard-process.svg (a shipped process figure, from `process_line`)
| Round | Defect (class) | Fix |
|---|---|---|
| 1 | closing band balanced into two half-width lines, right half of the band empty (empty space) | copy shortened to one line ("...each with its own certificate and access.") |
| 1 | "Credentials issued" wraps while "Sponsor vouches" does not (unbalanced wrap) | accepted: it is the label's real width; balanced wrap keeps the two lines even |
| 2 | none (light/dark, 900/680, print) | |

## Rebuilt figure 2: growth-comparison.svg (a shipped comparison figure, from `hub_vs_mesh`)
| Round | Defect | Fix |
|---|---|---|
| 1 | none (light/dark, 900/680, print) | |

## Design-system decision demo: ds-default.html against ds-provided.html
| Step | Result |
|---|---|
| detect | `tokens.py detect provided/` found `style.css` (78 custom properties); role map 1:1 (`provided/map.json`) |
| contrast, default | 31 pairs, light/dark/print, 0 failing |
| contrast, provided | 1 failing: `line` on `panel` 2.83:1 (bar 3:1) in light. Neither proof figure outlines a shape on a panel, so it is waived for this deliverable (`--waive line/panel`) as a declared deviation. The provided system's own checker never measured that pair. |
| fonts | provided stack (Inter, -apple-system, Helvetica Neue, Segoe UI, Arial) re-measured with the system face: `provided/font-metrics.json`; the figure was laid out with those metrics |
| render, round 1 | both systems clean in light and dark; the difference is the accent hue and the font stack, as intended |
| PDF | ds-provided.pdf: 1 page, 0 Type 3 (the provided stack does not lead with system-ui) |

## Explainer: pairs-explainer.html (timeline engine)
| Round | Defect (class) | Fix |
|---|---|---|
| 0 | page script failed: engine variable `init` declared twice | renamed |
| 1 | each step's rest frame was the NEXT step's start, so the caption ran one step ahead of the drawing (motion) | engine: a chapter's rest frame = where its own tweens end |
| 2 | contact sheet blank (Chrome will not load file:// images into about:blank) | render_png writes the sheet page beside the images |
| 2 | figlint: orphans in the h1 and two captions at one width (orphan) | `text-wrap: pretty` in the base CSS |
| 3 | PDF gate: 2 pages, expected 1 (pages) | compact print rules for explainers |
| 3 | print showed "Press Play, step with Next..." (meaningless on paper) | instruction moved to a screen-only line |
| 3 | "n(n - 1) / ÷ 2" broken across lines in the callout (print-only, wrap) | non-breaking spaces inside formulas |
| 3 | PDF gate false positive: per-page "shrink" fired on the figure page (gate defect) | per-page comparison removed; whole-document `--body-pt` pin instead |
| 4 | none | |

Accepted: figlint `empty-space` at step 1 (the ring area is empty because it is reserved for later steps;
filling it would make the layout jump).

## New topic: key-flow.svg ("only the named reader can ever open the key")
Started from the nearest pattern (`process_line`), no blank canvas.
| Round | Defect (class) | Fix |
|---|---|---|
| 1 | geometry passed on the first build; by looking: two-line heads beside one-line siblings, three-line subs (unbalanced wrap, prose) | verb heads (Grant, Wrap, Store, Fetch, Unwrap, Open), short subs |
| 2 | one sub still wrapped ("owner names / reader") | "names the reader" |
| 3 | none; figlint 0 errors 0 warnings; PDF 1 page, 0 Type 3 | |

**Rounds to pass, against the record:** this new figure took **3 rounds** (2 with defects, 1 confirming),
with no geometry refusal and no lint error at any round; every defect was a wording/wrap issue found by
looking. The record's comparable logs: the persona-library figure family took **7 rounds** (rounds 1-7 of
`persona-library/design/critique-log.md`, with refusals, print-height redraws and explainer holes), and the
guide set took **6** (rounds 0-5 of `guides/critique-log.md`). Caveats, stated plainly: this is one figure; its
shape is a close fit to an existing pattern; and the same author built the pattern, so it is not a blind test.
A figure whose shape matches no pattern would start nearer the old cost.

## Explorer template demo: examples/explorer-demo.html
| Round | Defect (class) | Fix |
|---|---|---|
| 1 | an empty player strip under the stage; axis end labelled "systems: 12" (ambiguous label) | explorers get no player; axis title and end tick separated |
| 2 | figlint E at n=2: the dot covers the "0" tick label (text-crosses-box); "1 links" (plural) | curve moved clear of the axis; singular |
| 3 | "1 link" sits on the curve | label raised above the curve at small n |
| 4 | none; figlint 0 errors, 1 warning (empty space at n=2: two nodes) | accepted |

## Negative tests (examples/proof/negative/): the gates catch what they claim
| Test | Expected | Result |
|---|---|---|
| transition-collision.html: a label slides through another, clear at both rest frames | error only at a moving frame | `text-overlap` at t=2.00 moving; none at rest |
| static-defects.html: SVG text in the box's own fill colour, connector without a head, a remote font, an undefined variable, 9-unit text | E svg-low-contrast, E remote-resource, E undefined-var, W arrow-no-head, W small-text | all raised |
| type3.html: a page in system-ui with check marks and circled numerals | pdfgate type3 failure | 7 of 7 fonts Type 3, FAIL |

## Final confirmation run (27 October 2026, everything rebuilt from source)
| Gate | Result |
|---|---|
| `patterns/test_patterns.py` | 48 cases, 0 failing (3 expected refusals) |
| tokens: default / provided / provided with the declared waiver | 0 / 1 (`line` on `panel`) / 0 failing |
| figlint: static proof (6 files), provided demo (1), explainer (989 frames), demos (2), pattern pages (12) | 0 errors everywhere |
| pdfgate: proof-doc, ds-provided, pairs-explainer, key-flow | each 1 page, 0 Type 3, 0 failures |

Warnings remaining, all `empty-space`, each accepted with its reason:
- explainer step 1: the ring area is reserved for later steps (filling it would make the layout jump);
- pattern pages: the 2-item worst cases (hub_vs_mesh, timeline, map) are sparse by construction; `two_state` with 9 compact items leaves the right half of each box empty; the `map_callouts` examples leave space under a short callout list. The map one is a known limit of that pattern (the list does not yet centre against the map);
- explorer demo at n=2 (two nodes) and the explainer template's dot row: sparse by content.
