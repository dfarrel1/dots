#!/usr/bin/env python3
"""explainer.py: wrap a stage SVG and its timeline script into ONE self-contained explainer page.

    from explainer import page
    page(out="out/x.html", title="Pairs grow faster", h1="Pair-by-pair links grow much faster than the systems",
         dek="Press Play, step with Next, or drag the timeline.", stage=svg_string, script=js_string,
         shows="What this shows ...", leaves="What this leaves out ...")

The page inlines viz.css (or css=[...] for a provided design system), explainer.css and timeline.js, so it
opens offline with no external request (figlint fails remote requests). The stage SVG must carry role="img"
and an aria-label stating the whole message; `script` calls Viz.timeline({...}) or Viz.explorer({...}).
Page shape (from the explainer standard the record's stepper met): kicker, a finding as h1, dek, stage,
player, "What this shows" callout, "What this leaves out" line, a dated foot."""
import os
from html import escape

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)


def page(out, title, h1, stage, script, dek="", kicker="Explainer", shows=None, leaves=None, foot=None, css=None, extra_html="",
         howto="Press Play, step with Next, or drag the timeline.", player=True):
    """player=False for an explorer (its own controls go in extra_html, directly under the stage)."""
    css = css or [os.path.join(SKILL, "templates", "viz.css")]
    style = "\n".join(open(p).read() for p in css) + "\n" + open(os.path.join(SKILL, "templates", "explainer.css")).read()
    engine = open(os.path.join(HERE, "timeline.js")).read()
    parts = [f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
             f"<title>{escape(title)}</title><style>{style}</style></head><body><main>",
             f'<div class="kicker">{escape(kicker)}</div><h1>{escape(h1)}</h1>' + (f'<p class="dek">{escape(dek)}</p>' if dek else ""),
             # screen-only: "Press Play" means nothing on paper (found on the first printed explainer)
             f'<p class="howto no-print">{escape(howto)}</p>' if howto else "",
             (f'<div class="stage">{stage}</div><div class="player"></div>' if player else f'<div class="stage solo">{stage}</div>'), extra_html]
    if shows: parts.append(f'<div class="callout"><p><b>What this shows.</b> {escape(shows)}</p></div>')
    if leaves: parts.append(f'<p class="leaves"><b>What this leaves out:</b> {escape(leaves)}</p>')
    if foot: parts.append(f'<p class="source">{escape(foot)}</p>')
    parts.append(f"</main><script>{engine}</script><script>{script}</script></body></html>\n")
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    open(out, "w").write("".join(parts))
    return out
