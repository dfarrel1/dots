#!/usr/bin/env python3
"""Proof: a 3Blue1Brown-style explainer built on the timeline engine.
Finding: linking n systems pair by pair needs n(n-1)/2 links; through one hub it needs n.
Nodes morph in (grow, and the ring re-spaces by sliding along its arc), links draw on one by one, the counters
interpolate, and the sum under each counter writes itself term by term, highlighted in step with the drawing.
The last step turns the sum into n(n-1)/2, highlighting each factor together with what it counts.
usage: python3 build_pairs_explainer.py   ->  out/pairs-explainer.html"""
import json, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(SKILL, "scripts"))
from figkit import text_width
from explainer import page

N = 6
W, H = 760, 404
LX, RX, CY, R, NR, HR = 200, 560, 158, 92, 15, 30
FS = 18                                   # formula size (units): 18 at 760 wide prints at about 16 px


def tspans(pieces, x, y, anchor_w, tid, cls="tq"):
    """One <text> of tspans, left-aligned so the FINAL line is centred on anchor_w: terms appear in place and
    nothing shifts as later terms arrive (reserved space, record W17)."""
    total = sum(text_width(p, FS) for p in pieces) / 1.06
    x0 = anchor_w - total / 2
    sp = "".join(f'<tspan id="{tid}{i}">{p.replace(" ", "&#160;")}</tspan>' for i, p in enumerate(pieces))
    return f'<text id="{tid}" x="{x0:.1f}" y="{y}" class="{cls}" font-size="{FS}">{sp}</text>'


left1 = ["= 1"] + [f" + {k}" for k in range(2, N)]                    # links added by node k: k-1
right1 = ["= 1"] + [" + 1"] * (N - 1)
left2 = ["= ", "n", "(n − 1)", " ÷ 2", f" = {N} × {N - 1} ÷ 2"]
right2 = ["= ", "n", f" = {N}"]

svg = [f'<svg id="stage" class="viz" viewBox="0 0 {W} {H}" role="img" aria-label="Six systems added one at a time: pair by pair each new system needs a link to every system already there, so the links add up to 1 + 2 + 3 + 4 + 5 = 15 = n(n-1)/2; through one hub each new system adds one connection, six in all">']
svg.append(f'<text x="{LX}" y="30" text-anchor="middle" class="t" font-size="15" font-weight="700">Pair by pair</text>')
svg.append(f'<text x="{RX}" y="30" text-anchor="middle" class="t" font-size="15" font-weight="700">Through one hub</text>')
svg.append(f'<path d="M380 14V{H - 14}" class="lnr"/>')
# links and spokes first (drawn under the nodes)
for i in range(N):
    for j in range(i + 1, N):
        svg.append(f'<line id="L{i}_{j}" class="ln" x1="0" y1="0" x2="0" y2="0" style="visibility:hidden"/>')
for i in range(N):
    svg.append(f'<line id="S{i}" class="lna" x1="0" y1="0" x2="0" y2="0" style="visibility:hidden"/>')
svg.append(f'<circle id="hub" cx="{RX}" cy="{CY}" r="{HR}" class="bxa"/><text id="hubT" x="{RX}" y="{CY + 4.6}" text-anchor="middle" class="t" font-size="13" font-weight="700">Hub</text>')
for side in "PQ":
    for i in range(N):
        svg.append(f'<g id="{side}{i}" style="visibility:hidden"><circle class="bx" r="{NR}"/><text class="t" text-anchor="middle" font-size="13" y="4.6">{i + 1}</text></g>')
# counters: numeral right-anchored, word left-anchored, so the pair never jitters as digits change
CYC = CY + R + NR + 46
svg.append(f'<text id="cL" x="{LX + 2}" y="{CYC}" text-anchor="end" class="tw" font-size="28" font-weight="700">0</text>')
svg.append(f'<text id="cLw" x="{LX + 10}" y="{CYC}" class="tw" font-size="15" font-weight="700">links</text>')
svg.append(f'<text id="cR" x="{RX - 38}" y="{CYC}" text-anchor="end" class="tg" font-size="28" font-weight="700">0</text>')
svg.append(f'<text id="cRw" x="{RX - 30}" y="{CYC}" class="tg" font-size="15" font-weight="700">connections</text>')
svg.append(tspans(left1, 0, CYC + 34, LX, "fL"))
svg.append(tspans(right1, 0, CYC + 34, RX, "fR"))
svg.append(tspans(left2, 0, CYC + 64, LX, "gL"))
svg.append(tspans(right2, 0, CYC + 64, RX, "gR"))
svg.append('<line id="ul" class="lna" x1="0" y1="0" x2="0" y2="0" style="visibility:hidden"/>')
svg.append('<line id="ur" class="lna" x1="0" y1="0" x2="0" y2="0" style="visibility:hidden"/>')
svg.append("</svg>")

CAPTIONS = [
    "One system on its own needs no links. Through a hub, it needs one connection.",
    "A second system: pair by pair it needs one link, to the first. Through the hub it adds one connection.",
    "A third system must link to both systems already there: 2 new links, 3 in all. The hub still adds 1.",
    "A fourth system adds 3 links, one to each existing system: 6 in all. The hub adds 1: 4 in all.",
    "A fifth system adds 4 links: 10 in all, against 5 connections.",
    "A sixth adds 5 links: 1 + 2 + 3 + 4 + 5 = 15, against 6 connections.",
    "The sum is n(n − 1) ÷ 2: each of the n systems links to the n − 1 others, and every link is counted from both ends, so halve it. Through the hub it is just n.",
]

script = r"""
const N = %(N)d, LX = %(LX)d, RX = %(RX)d, CY = %(CY)d, R = %(R)d, NR = %(NR)d, HR = %(HR)d;
const $ = id => document.getElementById(id);
const ang = (i, n) => -Math.PI / 2 + 2 * Math.PI * i / n;
const state = { cL: 0, cR: 0, hub: 1 };
for (let i = 0; i < N; i++) {
  state[`a${i}`] = ang(i, i + 1); state[`s${i}`] = 0; state[`h${i}`] = 0; state[`sd${i}`] = 0; state[`sh${i}`] = 0;
  for (let j = i + 1; j < N; j++) { state[`d${i}_${j}`] = 0; state[`lh${i}_${j}`] = 0; }
}
%(TERMS)s
const tl = Viz.timeline({ svg: "#stage", state, hold: 1400, render });
// chapter 1: the first system
tl.chapter(0, %(C0)s);
tl.tween(0.2, 0.8, { s0: 1 }, "backOut").tween(0.2, 0.6, { h0: 1 });
tl.tween(1.0, 0.6, { sd0: 1 }, "inOut").tween(1.0, 0.6, { cR: 1, fR0o: 1, fR0h: 1 });
tl.tween(1.9, 0.5, { h0: 0, fR0h: 0 });
let t = 2.6;
for (let k = 1; k < N; k++) {          // system k+1 arrives
  tl.chapter(t, CAP[k]);
  for (let i = 0; i < k; i++) tl.tween(t, 0.9, { [`a${i}`]: ang(i, k + 1) }, "smooth");   // the ring re-spaces along its arc
  tl.set(t, { [`a${k}`]: ang(k, k + 1) });
  tl.tween(t + 0.8, 0.7, { [`s${k}`]: 1 }, "backOut").tween(t + 0.8, 0.5, { [`h${k}`]: 1 });
  const t1 = t + 1.5;
  tl.tween(t1, 0.4, { [`fL${k - 1}o`]: 1, [`fL${k - 1}h`]: 1 });                         // the new term appears, lit
  tl.tween(t1, 0.6, { [`sd${k}`]: 1, cR: k + 1, [`fR${k}o`]: 1, [`fR${k}h`]: 1 });
  const per = Math.max(0.32, 1.6 / k);
  for (let i = 0; i < k; i++) {                                                              // k links draw, one by one
    const s = t1 + 0.2 + i * per;
    tl.tween(s, per * 0.95, { [`d${i}_${k}`]: 1, [`lh${i}_${k}`]: 1 }, "out");
  }
  const tc = t1 + 0.2 + k * per;
  tl.tween(t1 + 0.2, tc - t1 - 0.2, { cL: k * (k + 1) / 2 }, "linear");                      // the counter counts the links as they draw
  // settle: the new links fade to neutral, the term stays lit until the next system arrives
  for (let i = 0; i < k; i++) tl.tween(tc + 0.3, 0.6, { [`lh${i}_${k}`]: 0 });
  tl.tween(tc + 0.3, 0.6, { [`h${k}`]: 0, [`fR${k}h`]: 0 });
  if (k > 1) tl.tween(t1, 0.4, { [`fL${k - 2}h`]: 0 });
  t = tc + 1.2;
}
// final chapter: the sum becomes n(n-1)/2, each factor lit with what it counts
tl.chapter(t, CAP[N]);
tl.tween(t, 0.5, { [`fL${N - 2}h`]: 0, gL0o: 1, gL1o: 1, gR0o: 1, gR1o: 1 });
let u = t + 0.7;
tl.tween(u, 0.4, { gL1h: 1, gR1h: 1 }); for (let i = 0; i < N; i++) tl.tween(u, 0.4, { [`h${i}`]: 1 });              // n: the systems
tl.tween(u + 1.6, 0.4, { gL1h: 0, gR1h: 0 }); for (let i = 1; i < N; i++) tl.tween(u + 1.6, 0.4, { [`h${i}`]: 0 });
u += 2.1;
tl.tween(u, 0.4, { gL2o: 1, gL2h: 1 }); for (let j = 1; j < N; j++) tl.tween(u, 0.4, { [`lh0_${j}`]: 1 });         // (n-1): one system's links
tl.tween(u + 1.8, 0.4, { gL2h: 0, h0: 0 }); for (let j = 1; j < N; j++) tl.tween(u + 1.8, 0.4, { [`lh0_${j}`]: 0 });
u += 2.3;
tl.tween(u, 0.4, { gL3o: 1, gL3h: 1 });                                                                           // / 2: each link counted twice
for (let i = 0; i < N; i++) for (let j = i + 1; j < N; j++) tl.pulse(u + 0.1, 1.4, `lh${i}_${j}`);
tl.tween(u + 1.7, 0.4, { gL3h: 0 });
u += 2.2;
tl.tween(u, 0.5, { gL4o: 1, gL4h: 1, gR2o: 1, gR2h: 1 });
for (let i = 0; i < N; i++) tl.pulse(u, 1.2, `sh${i}`);
tl.chapter(u + 2.4, null);  // marks the end of motion (removed below)
"""

TERMS_JS = []
for name, n in (("fL", len(left1)), ("fR", len(right1)), ("gL", len(left2)), ("gR", len(right2))):
    for k in range(n): TERMS_JS.append(f"state.{name}{k}o = 0; state.{name}{k}h = 0;")
render = r"""
function render(s, t, H) {
  const line = getComputedStyle(document.documentElement);
  const pos = (cx, i) => [cx + R * Math.cos(s[`a${i}`]), CY + R * Math.sin(s[`a${i}`])];
  for (const [side, cx] of [["P", LX], ["Q", RX]]) for (let i = 0; i < N; i++) {
    const g = $(side + i), sc = s[`s${i}`], [x, y] = pos(cx, i);
    g.style.visibility = sc > 0.01 ? "" : "hidden";
    g.setAttribute("transform", `translate(${x.toFixed(2)} ${y.toFixed(2)})`);
    const c = g.firstChild; c.setAttribute("r", (NR * Math.max(0.01, sc)).toFixed(2));
    c.style.fill = H.mix("--paper", "--accent-soft", s[`h${i}`]); c.style.stroke = H.mix("--line", "--accent", s[`h${i}`]);
    c.style.strokeWidth = 1.25 + s[`h${i}`];
    H.fade(g.lastChild, H.clamp((sc - 0.75) / 0.25));
  }
  for (let i = 0; i < N; i++) for (let j = i + 1; j < N; j++) {
    const el = $(`L${i}_${j}`), [x1, y1] = pos(LX, i), [x2, y2] = pos(LX, j);
    const dx = x2 - x1, dy = y2 - y1, d = Math.hypot(dx, dy) || 1, ux = dx / d, uy = dy / d;
    const ri = NR * s[`s${i}`], rj = NR * s[`s${j}`];
    // drawn from the NEW system (j) towards the existing one (i)
    H.attrs(el, { x1: x2 - ux * rj, y1: y2 - uy * rj, x2: x1 + ux * ri, y2: y1 + uy * ri });
    const h = s[`lh${i}_${j}`];
    el.style.stroke = H.mix("--line", "--accent", h); el.style.strokeWidth = 1.25 + 1.25 * h;
    H.drawOn(el, s[`d${i}_${j}`]);
  }
  for (let i = 0; i < N; i++) {
    const el = $(`S${i}`), [x, y] = pos(RX, i), dx = x - RX, dy = y - CY, d = Math.hypot(dx, dy) || 1;
    H.attrs(el, { x1: RX + dx / d * HR, y1: CY + dy / d * HR, x2: x - dx / d * NR * s[`s${i}`], y2: y - dy / d * NR * s[`s${i}`] });
    el.style.strokeWidth = 2 + 1.5 * s[`sh${i}`];
    H.drawOn(el, s[`sd${i}`]);
  }
  H.count($("cL"), s.cL); H.count($("cR"), s.cR);
  $("cLw").textContent = Math.round(s.cL) === 1 ? "link" : "links";
  $("cRw").textContent = Math.round(s.cR) === 1 ? "connection" : "connections";
  // formula terms: fade in, lit in the accent while they are the subject; the underline follows the lit term
  const ul = { fL: $("ul"), gL: $("ul"), fR: $("ur"), gR: $("ur") }; let lit = { ul: null, ur: null };
  for (const [name, n] of TERMN) for (let k = 0; k < n; k++) {
    const sp = $(name + k), o = s[`${name}${k}o`], h = s[`${name}${k}h`];
    sp.style.fillOpacity = o; sp.style.fill = H.mix("--quiet", "--accent", h);
    const u = ul[name].id; if (h > 0.02 && o > 0.5 && (!lit[u] || h > lit[u][1])) lit[u] = [sp, h];
  }
  for (const u of ["ul", "ur"]) {
    const el = $(u);
    if (!lit[u]) { el.style.visibility = "hidden"; continue; }
    const b = lit[u][0].getBBox(); el.style.visibility = ""; el.style.opacity = lit[u][1];
    H.attrs(el, { x1: b.x + 2, x2: b.x + b.width - 2, y1: b.y + b.height + 3, y2: b.y + b.height + 3 });
  }
}
"""
TERMN = json.dumps([["fL", len(left1)], ["fR", len(right1)], ["gL", len(left2)], ["gR", len(right2)]])
js = (f"const CAP = {json.dumps(CAPTIONS, ensure_ascii=False)};\nconst TERMN = {TERMN};\n" + render +
      (script % dict(N=N, LX=LX, RX=RX, CY=CY, R=R, NR=NR, HR=HR, TERMS="\n".join(TERMS_JS), C0=json.dumps(CAPTIONS[0], ensure_ascii=False)))
      .replace('tl.chapter(u + 2.4, null);  // marks the end of motion (removed below)\n', ''))
# the engine reads chapters and tweens when Viz.timeline is created; the render function closes over them
out = page(os.path.join(HERE, "out", "pairs-explainer.html"), title="Pairs against a hub",
           h1="Pair-by-pair links grow much faster than the systems",
           dek="Each new system needs a link to every system already there; through a hub it needs one.",
           stage="".join(svg), script=js,
           shows="With n systems, linking every pair needs 1 + 2 + ... + (n − 1) = n(n − 1) ÷ 2 links, each one built, tested and kept working. Through one hub each system connects once, so n connections. At 20 systems that is 190 against 20.",
           leaves="each connection still needs an owner's decision about what it may carry; the arithmetic counts integration work, not approvals.",
           foot="Numbers computed from n(n − 1) ÷ 2 and n.")
print(out)
