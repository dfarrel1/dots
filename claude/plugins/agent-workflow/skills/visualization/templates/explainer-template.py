#!/usr/bin/env python3
"""Explainer template: the smallest complete timeline explainer. Copy it, then grow it.
The full worked example (morphing nodes, draw-on links, counters, a formula lit in step with the drawing) is
examples/proof/build_pairs_explainer.py; rules in references/animation.md.
usage: python3 explainer-template.py [out.html]   then lint (every rest AND transition frame) and render:
  node <skill>/scripts/figlint.mjs out.html
  node <skill>/scripts/render_png.mjs --frames all --sheet out.html"""
import os, sys
SKILL = os.path.expanduser("~/.claude/skills/visualization")
sys.path.insert(0, os.path.join(SKILL, "scripts"))
from explainer import page

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.getcwd(), "explainer.html")

# The stage: every element that moves exists from the start (reserved space; nothing jumps).
stage = """<svg id="stage" class="viz" viewBox="0 0 760 240" role="img" aria-label="A message moves from the sender to the receiver through a relay, and the count of hops goes from 0 to 2">
<rect x="20" y="80" width="150" height="64" rx="8" class="bx"/><text x="95" y="118" text-anchor="middle" class="t" font-size="15" font-weight="700">Sender</text>
<rect x="305" y="80" width="150" height="64" rx="8" class="bxa"/><text x="380" y="118" text-anchor="middle" class="t" font-size="15" font-weight="700">Relay</text>
<rect x="590" y="80" width="150" height="64" rx="8" class="bx"/><text x="665" y="118" text-anchor="middle" class="t" font-size="15" font-weight="700">Receiver</text>
<line id="hop1" x1="170" y1="112" x2="305" y2="112" class="lna" data-lint="nohead"/><line id="hop2" x1="455" y1="112" x2="590" y2="112" class="lna" data-lint="nohead"/>
<circle id="msg" cx="95" cy="176" r="9" class="fa"/>
<text id="count" x="380" y="214" text-anchor="end" class="t" font-size="22" font-weight="700">0</text>
<text x="388" y="214" class="tq" font-size="15">hops</text>
</svg>"""

script = """
const $ = id => document.getElementById(id);
function render(s, t, H) {
  H.drawOn($("hop1"), s.d1); H.drawOn($("hop2"), s.d2);
  H.attrs($("msg"), { cx: s.x });
  H.count($("count"), s.hops);
  $("count").style.fill = H.mix("--ink", "--accent", s.hl);
}
const tl = Viz.timeline({ svg: "#stage", state: { d1: 0, d2: 0, x: 95, hops: 0, hl: 0 }, render });
tl.chapter(0, "The sender has a message for the receiver.");
tl.chapter(0.6, "First hop: the message reaches the relay.");
tl.tween(0.8, 0.7, { d1: 1 }, "out").tween(1.4, 0.9, { x: 380, hops: 1 }, "smooth").pulse(1.4, 1.0, "hl");
tl.chapter(3.0, "Second hop: the relay forwards it to the receiver. Two hops in all.");
tl.tween(3.2, 0.7, { d2: 1 }, "out").tween(3.8, 0.9, { x: 665, hops: 2 }, "smooth").pulse(3.8, 1.0, "hl");
"""

page(out, "Two hops", "A relayed message takes two hops", stage, script,
     dek="The relay sits between sender and receiver.",
     shows="A relayed message crosses two links instead of one.",
     leaves="what the relay can see of the message.", foot="Illustrative.")
print(out)
