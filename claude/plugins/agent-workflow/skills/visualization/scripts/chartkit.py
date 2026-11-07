#!/usr/bin/env python3
"""chartkit: honest charts on top of figkit (same measured text, same refusal to write a broken figure).

Rules it enforces (references/charts.md; palette and mark detail defer to the `dataviz` skill):
  - numbers come from data passed in, never typed into labels by hand; tick labels are computed.
  - bars start at zero. A bar chart whose domain excludes 0 raises.
  - a line chart may start above zero only with zero_reason="..." (the reason is drawn as a quiet axis note).
  - every chart carries a source and a date: Chart(..., source="...", asof="...") or save() raises.
  - series are labelled directly at their ends (no legend); labels are dodged so they never overlap.
  - small multiples share one scale (Scale objects are passed, not rebuilt per panel).

    from figkit import Figure; from chartkit import Chart, Scale
    f = Figure("Links grow with the square of the systems", alt="...")
    c = Chart(f, Rect(70, f.top, 560, 180), x=Scale(2, 30), y=Scale(0, 435), source="Computed: n(n-1)/2", asof="26 October 2026")
    c.axes(xlabel="Systems", ylabel="Links"); c.line([(n, n*(n-1)/2) for n in range(2, 31)], "Pair by pair", kind="warn")
    c.annotate(20, 190, "20 systems: 190 links"); c.finish()
"""
import math
from figkit import Rect, text_width, fmt, ASC, LINE, FILL


def nice_step(span, target=5):
    raw = span / max(1, target); mag = 10 ** math.floor(math.log10(raw)) if raw > 0 else 1
    for m in (1, 2, 2.5, 5, 10):
        if raw <= m * mag: return m * mag
    return 10 * mag


class Scale:
    """Linear scale. nice=True widens the domain to whole ticks."""
    def __init__(self, lo, hi, nice=True, ticks=5):
        if hi <= lo: raise ValueError("scale domain is empty")
        self.step = nice_step(hi - lo, ticks)
        self.lo = math.floor(lo / self.step) * self.step if nice else lo
        self.hi = math.ceil(hi / self.step) * self.step if nice else hi
    def ticks(self):
        out, v = [], self.lo
        while v <= self.hi + 1e-9: out.append(round(v, 10)); v += self.step
        return out
    def __call__(self, v, a, b): return a + (v - self.lo) / (self.hi - self.lo) * (b - a)


def num(v):
    if abs(v - round(v)) < 1e-9: return f"{int(round(v)):,}"
    return f"{v:,.1f}"


class Chart:
    def __init__(self, fig, rect, x, y, source=None, asof=None, zero_reason=None, kind="line"):
        self.f, self.r, self.x, self.y = fig, rect, x, y
        self.source, self.asof, self.zero_reason = source, asof, zero_reason
        self.labels = []          # end labels to dodge: (y, text, cls, x)
        if kind == "bar" and y.lo > 0: raise ValueError("a bar chart must start at zero (bars encode length)")
        if kind == "line" and y.lo > 0 and not zero_reason:
            raise ValueError("this axis does not start at zero: pass zero_reason='why the baseline is not zero' (it is drawn on the chart)")

    def px(self, v): return self.x(v, self.r.x, self.r.r)
    def py(self, v): return self.y(v, self.r.b, self.r.y)

    def axes(self, xlabel=None, ylabel=None, xfmt=num, yfmt=num, grid=True, xticks=None):
        f, r = self.f, self.r
        for v in self.y.ticks():
            yy = self.py(v)
            if grid: f.line([(r.x, yy), (r.r, yy)], "rule", nohead_ok=True)
            f.text(r.x - 8 * f.k, yy + 4.5 * f.k, yfmt(v), "sub", "end")
        for v in (xticks or self.x.ticks()):
            xx = self.px(v)
            f.text(xx, r.b + 8 * f.k + f.T["sub"][0] * ASC, xfmt(v), "sub", "middle")
        f.line([(r.x, r.b), (r.r, r.b)], "neutral", nohead_ok=True)
        if xlabel: f.text(r.r, r.b + 30 * f.k + f.T["sub"][0] * ASC, xlabel, "label", "end")
        if ylabel: f.text(r.x - 8 * f.k, r.y - 14 * f.k, ylabel, "label", "end" if text_width(ylabel, f.T["label"][0], 700) < r.x - 2 * f.MARGIN else "start")
        if self.zero_reason and self.y.lo > 0:
            f.text(r.x, r.b - 6 * f.k, f"axis starts at {num(self.y.lo)}: {self.zero_reason}", "sub", cls="tq")

    def line(self, pts, label=None, kind="flow", dots=False):
        f = self.f
        P = [(self.px(a), self.py(b)) for a, b in pts]
        f.line(P, kind, nohead_ok=True)
        if dots:
            for x, y in P: f.raw(f'<circle cx="{fmt(x)}" cy="{fmt(y)}" r="{fmt(3 * f.k)}" class="{LINE[kind][1]}"/>')
        if label: self.labels.append([P[-1][1], label, {"flow": "ta", "warn": "tw", "good": "tg", "neutral": "tq", "crit": "tc"}.get(kind, "t"), P[-1][0]])
        return P

    def bars(self, data, kind="accent", label_values=True, band=0.62):
        """data: [(category, value)]. Categories evenly spaced across the x range; values labelled on the bar."""
        f, r = self.f, self.r
        n = len(data); slot = r.w / n; bw = slot * band
        for i, (cat, v) in enumerate(data):
            x = r.x + slot * i + (slot - bw) / 2; y0, y1 = self.py(0), self.py(v)
            f.raw(f'<rect x="{fmt(x)}" y="{fmt(min(y0, y1))}" width="{fmt(bw)}" height="{fmt(abs(y0 - y1))}" class="{FILL[kind]}"/>')
            f.shapes.append((Rect(x, min(y0, y1), bw, abs(y0 - y1)), "art", f.group))
            f.text(x + bw / 2, r.b + 8 * f.k + f.T["sub"][0] * ASC, cat, "sub", "middle")
            if label_values: f.text(x + bw / 2, min(y0, y1) - 6 * f.k, num(v), "label", "middle", cls="t")

    def annotate(self, xv, yv, text, dx=-14, dy=-6, anchor="end"):
        """Annotate the finding on the chart itself: a dot on the point and a short label with a leader."""
        f = self.f
        x, y = self.px(xv), self.py(yv)
        f.raw(f'<circle cx="{fmt(x)}" cy="{fmt(y)}" r="{fmt(4.5 * f.k)}" class="fa"/>', Rect(x - 4.5 * f.k, y - 4.5 * f.k, 9 * f.k, 9 * f.k), kind="disc")
        tx, ty = x + dx * f.k, y + dy * f.k
        if abs(dy) > 16:         # a leader only when the label is placed away from its point
            f.line([(x, y - 6 * f.k), (tx + (4 if anchor == "end" else -4) * f.k, ty + 6 * f.k)], "neutral", nohead_ok=True)
        f.text(tx, ty, text, "label", anchor, cls="t", halo=True)

    def finish(self, gap=16):
        """Place the dodged end labels and the source line. Raises if source or date is missing."""
        f = self.f
        if not self.source or not self.asof: raise ValueError("a chart needs source= and asof= (record W11: honest and dated)")
        size, lead = f.T["label"][0], f.T["label"][2]
        L = sorted(self.labels, key=lambda a: a[0])
        for i in range(1, len(L)):                    # dodge: push labels apart to one line's leading
            if L[i][0] - L[i - 1][0] < lead: L[i][0] = L[i - 1][0] + lead
        over = (L[-1][0] - self.r.b) if L else 0
        if over > 0:
            for a in L: a[0] -= over
        for y, t, cls, x in L:
            f.text(self.r.r + 10 * f.k, y + size * 0.33, t, "label", cls=cls)
        f.note(f"Source: {self.source}. As of {self.asof}.", gap=gap)
