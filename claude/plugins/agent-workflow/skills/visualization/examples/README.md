# Examples

| Path | What it proves |
|---|---|
| `proof/build_proof.py` | Two shipped figures rebuilt only with the skill: a process (`out/onboard-process.svg`, from `process_line`) and a comparison (`out/growth-comparison.svg`, from `hub_vs_mesh`); the design-system decision demo (`out/ds-default.html` against `out/ds-provided.html`, the same figure under the bundled default and under a provided system, re-measured for its fonts) |
| `proof/build_pairs_explainer.py` | A 3Blue1Brown-style explainer on the timeline engine: n(n-1)/2 links against n connections, nodes growing in while the ring re-spaces, links drawing on one by one, counters interpolating, the sum writing itself term by term and turning into n(n-1)/2 with each factor lit with what it counts. Linted at 989 frames (rest and moving) |
| `proof/build_key_flow.py` | A new topic, started from the nearest pattern: rounds counted against the record |
| `proof/negative/` | Deliberate defects the gates must catch (a mid-transition collision, invisible SVG text, a remote font, an undefined variable, Type 3 fonts) |
| `proof/critique-log.md` | Every round: what was rendered, every defect found, its fix, gate results, accepted warnings with reasons |
| `explorer-demo.html` | `templates/explorer-template.py` built: a slider and a draggable point drive a drawing, a live formula and a linked chart |
| `explainer-template-demo.html` | `templates/explainer-template.py` built: the smallest complete timeline explainer |

Rebuild everything:

```bash
cd ~/.claude/skills/visualization
python3 patterns/test_patterns.py
python3 examples/proof/build_proof.py && python3 examples/proof/build_pairs_explainer.py && python3 examples/proof/build_key_flow.py
node scripts/figlint.mjs examples/proof/out/*.svg examples/proof/out/ds-default.html examples/proof/out/proof-doc.html examples/proof/out/key-flow.html
node scripts/figlint.mjs --css examples/proof/provided/style.css examples/proof/out/ds-provided.html
node scripts/figlint.mjs examples/proof/out/pairs-explainer.html          # every rest and transition frame
python3 scripts/pdfgate.py build examples/proof/out/pairs-explainer.html -o examples/proof/out/pairs-explainer.pdf --pages 1 --size letter
```
