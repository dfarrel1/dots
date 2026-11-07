#!/usr/bin/env python3
"""Explorer template (direct manipulation, the Red Blob Games pattern): one parameter, three linked views.
A slider AND a draggable point on a chart both set n; the network drawing, the live formula and the chart dot
all recompute from n. Copy this file, change the model in `render`, keep the structure.
usage: python3 explorer-template.py [out.html]   then: node <skill>/scripts/figlint.mjs out.html"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "scripts"))
from explainer import page

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.getcwd(), "explorer.html")
NMAX = 12
# Chart geometry (viewBox units): x maps n = 2..NMAX across 450..720 (clear of the axis), y maps links 0..66 up from 300 to 120
stage = f'''<svg id="ex" class="viz" viewBox="0 0 760 360" role="img" aria-label="Choose a number of systems: the network on the left redraws with every pair linked, the formula gives the number of links, and the chart on the right shows where that number sits on the curve">
<g id="net"></g>
<text id="formula" x="200" y="330" text-anchor="middle" class="t" font-size="18">n(n − 1) ÷ 2 = 15</text>
<path d="M420 300H720" class="ln"/><path d="M420 300V112" class="ln"/>
<text x="720" y="322" text-anchor="middle" class="tq" font-size="13">{NMAX}</text>
<text x="570" y="322" text-anchor="middle" class="tq" font-size="13" font-weight="700">systems</text>
<text x="450" y="322" text-anchor="middle" class="tq" font-size="13">2</text>
<text x="412" y="124" text-anchor="end" class="tq" font-size="13">66</text>
<text x="412" y="304" text-anchor="end" class="tq" font-size="13">0</text>
<text x="430" y="100" class="tq" font-size="13" font-weight="700">links</text>
<path id="curve" class="lnw" data-lint="nohead"/>
<circle id="dot" r="9" class="fa"/>
<text id="dotlabel" class="t halo" font-size="13" font-weight="700" data-lint="halo">15</text>
</svg>'''
controls = '<div class="params no-print"><label>Systems <input id="n" type="range" min="2" max="12" value="6" aria-label="Number of systems"> <output id="nout">6</output></label><span class="tq">or drag the dot along the curve</span></div>'
script = f'''
const NMAX = {NMAX}, X = n => 450 + (n - 2) / (NMAX - 2) * 270, Y = v => 300 - v / 66 * 188;
const ns = "http://www.w3.org/2000/svg", $ = id => document.getElementById(id);
const mk = (tag, a) => {{ const e = document.createElementNS(ns, tag); for (const k in a) e.setAttribute(k, a[k]); return e; }};
let d = ""; for (let n = 2; n <= NMAX; n++) d += (n === 2 ? "M" : "L") + X(n).toFixed(1) + " " + Y(n * (n - 1) / 2).toFixed(1);
$("curve").setAttribute("d", d);
function render(p, H) {{
  const n = Math.round(p.n), L = n * (n - 1) / 2, net = $("net"); net.replaceChildren();
  const R = 105, r = n > 9 ? 8 : 11, P = Array.from({{ length: n }}, (_, i) => [200 + R * Math.cos(-Math.PI / 2 + 2 * Math.PI * i / n), 175 + R * Math.sin(-Math.PI / 2 + 2 * Math.PI * i / n)]);
  for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) net.append(mk("line", {{ x1: P[i][0], y1: P[i][1], x2: P[j][0], y2: P[j][1], class: "ln" }}));
  P.forEach(([x, y]) => net.append(mk("circle", {{ cx: x, cy: y, r, class: "bx" }})));
  $("formula").textContent = `n(n − 1) ÷ 2 = ${{n}} × ${{n - 1}} ÷ 2 = ${{L}}`;
  H.attrs($("dot"), {{ cx: X(n), cy: Y(L) }});
  const left = n > 6;      // label on the side away from the axis and the curve's steep end
  H.attrs($("dotlabel"), {{ x: X(n) + (left ? -14 : 10), y: Y(L) - (left ? 12 : 24), "text-anchor": left ? "end" : "start" }});
  $("dotlabel").textContent = `${{L}} ${{L === 1 ? "link" : "links"}}`;
  $("nout").textContent = n;
}}
Viz.explorer({{ svg: "#ex", params: {{ n: 6 }}, sliders: {{ n: "#n" }}, render, printParams: {{ n: 8 }},
  handles: [["#dot", (x, y, p) => {{ p.n = Math.max(2, Math.min(NMAX, Math.round(2 + (x - 450) / 270 * (NMAX - 2)))); }}]],
  sweep: [{{ n: 2 }}, {{ n: 6 }}, {{ n: 9 }}, {{ n: 12 }}] }});
'''
page(out, "Links explorer", "Every system you add costs one link per system already there",
     stage, script, dek="Choose a number of systems and watch the links, the formula and the curve move together.",
     howto="Move the slider, or drag the dot along the curve.", extra_html=controls,
     player=False, shows="The number of links grows with the square of the systems: n(n − 1) ÷ 2.",
     foot="Numbers computed from n(n − 1) ÷ 2.")
print(out)
