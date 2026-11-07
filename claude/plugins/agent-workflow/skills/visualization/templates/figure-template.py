#!/usr/bin/env python3
"""Figure template. Copy beside the work, then: pick a pattern, change labels and data, extend with figkit.
usage: python3 figure-template.py   ->  out/<name>.svg and out/<name>.html (lint and look at both)

  node <skill>/scripts/figlint.mjs out/
  node <skill>/scripts/render_png.mjs --print out/<name>.html   (then read every PNG)
"""
import os, sys
SKILL = os.path.expanduser("~/.claude/skills/visualization")
sys.path[:0] = [os.path.join(SKILL, "scripts"), os.path.join(SKILL, "patterns")]
import figkit
from figkit import page, Rect
from patterns import process_line          # the nearest pattern (see patterns/README.md)

OUT = os.path.join(os.getcwd(), "out")
# figkit.use_metrics("<provided>/font-metrics.json")   # only when a provided system has its own font stack

# 1. The finding (title) and the whole message (alt), written before anything is drawn.
TITLE = "Nothing is issued until two people approve"
ALT = "A request moves through four steps; the second and third are approvals by two different people, and only then is anything issued"

# 2. The pattern, with this figure's labels and data.
f = process_line(TITLE, ALT,
                 steps=[("Request", "by the owner"), ("Review", "first approver"), ("Approve", "second approver"), ("Issue", "automatic")],
                 bracket=(1, 2, "two people"))

# 3. Extend only if needed, with figkit primitives on the same Figure (they are measured and checked too):
# f.note("As of <date>: ...")

svg = f.save(os.path.join(OUT, "figure.svg"))                       # raises if the geometry check fails
page([svg], TITLE, out=os.path.join(OUT, "figure.html"),
     captions=["The caption adds the 'so what' for this reader; it does not repeat the title."])
print("wrote out/figure.svg and out/figure.html")
