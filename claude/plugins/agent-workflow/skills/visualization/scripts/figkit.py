#!/usr/bin/env python3
"""figkit: SVG figures that are correct by construction. Stdlib only.

Generalised from a figure kit that shipped a checked family of figures (record W1-W3, W8): every label is
measured before it is placed (font-metrics.json: the widest advance of each character across every font in
the stack, plus 6 % headroom), wrapped inside its box, and boxes take the height their text needs. On save,
figkit checks the geometry and REFUSES to write a figure in which text overlaps text, sits closer than the
clearance to a box edge or a line, leaves the viewBox, straddles a box edge, an arrow misses its target edge,
text is under the minimum size, or the figure is taller than its variant allows. Fix the layout; never
silence the check.

Colour comes only from CSS classes (t, tq, bx, bxa, lna, ...) that the stylesheet maps to role tokens
(templates/viz.css, or a provided design system adapted with tokens.py). No literal colours, so one
stylesheet switches every figure between light, dark and print.

Units: SVG user units. The canonical width is 760; Figure(width=W) scales every size, gap and limit by
W/760, so a 1200-wide slide figure keeps the same proportions and minimum printed size.

    import sys; sys.path.insert(0, "<skill>/scripts")
    from figkit import Figure
    f = Figure("A restart always gets a new key", alt="One-sentence message ...")
    a, b = f.row(f.top, [dict(head="Handshake", sub="new key A"), dict(head="Restart", sub="key erased")], gap=32)
    f.connect(a, b)
    f.note("As of 26 October 2026: ...")
    f.save("out/key.svg")
"""
import json, math, os
from contextlib import contextmanager
from html import escape

HERE = os.path.dirname(os.path.abspath(__file__))
SAFETY = 1.06
_METRICS = {}


def use_metrics(path=None):
    """Load a metrics table (default: font-metrics.json beside this file, or $VIZ_FONT_METRICS).
    Re-measure with measure_fonts.mjs whenever the font stack changes."""
    path = path or os.environ.get("VIZ_FONT_METRICS") or os.path.join(HERE, "font-metrics.json")
    _METRICS.clear(); _METRICS.update(json.load(open(path)))
    return _METRICS


use_metrics()

# ---- the grammar at the canonical 760 width (references/figure-grammar.md) --------------------------------
W = 760
MARGIN, GUTTER = 20, 24
PAD_X, PAD_Y = 16, 14
CLEAR = 8
RADIUS = {"service": 8, "person": 20, "band": 8, "chip": 6, "zone": 12}
TYPE = {   # style: (size, weight, leading, class)
    "title": (18, 700, 24, "t"), "slimtitle": (16, 700, 22, "t"), "head": (15, 700, 20, "t"),
    "body": (14, 400, 20, "t"), "sub": (13, 400, 18, "tq"), "label": (13, 700, 18, "tq"),
    "note": (13, 400, 18, "tq"), "big": (28, 700, 32, "t"), "num": (22, 700, 26, "t"),
}
MIN_SIZE = 13
MAX_H = {"slim": 240, "standard": 300, "tall": 380, "stage": 460}
TONE = {
    "plain": ("bx", "t"), "panel": ("bxp", "t"), "accent": ("bxa", "t"), "good": ("bxg", "tg"),
    "warn": ("bxw", "tw"), "info": ("bxi", "ti"), "crit": ("bxc", "tc"), "mute": ("bxm", "tm"),
    "planned": ("bxd", "tq"),
}
LINE = {
    "flow": ("lna", "fa", 2), "neutral": ("ln", "fl", 1.25), "good": ("lng", "fg", 2),
    "warn": ("lnw", "fw", 2), "control": ("lnd", "fl", 1.25), "optional": ("lno", "fg", 2),
    "rule": ("lnr", "fl", 1), "crit": ("lnx", "fc", 2),
}
FILL = {"accent": "fa", "good": "fg", "warn": "fw", "mute": "fm", "info": "fi", "crit": "fc", "line": "fl", "panel": "fp"}
ASC, DESC = 0.80, 0.24     # ink extents of a line relative to its baseline


def text_width(s, size, weight=400):
    table = _METRICS["bold" if weight >= 600 else "regular"]
    fallback = table.get("M", 900)
    return sum(table.get(ch, fallback) for ch in s) / 1000 * size * SAFETY


def wrap(s, width, size, weight=400):
    """Greedy wrap. A single word wider than the width raises: shorten the label or widen the box."""
    words, lines, cur = s.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if text_width(trial, size, weight) <= width:
            cur = trial
        else:
            if not cur:
                raise ValueError(f"word {w!r} is wider than {width:.0f} units at size {size}: widen the box or shorten it")
            lines.append(cur); cur = w
    if cur: lines.append(cur)
    return lines


def balanced_wrap(s, width, size, weight=400):
    """Fewest lines, then even lengths (no one-word orphan lines). Use for labels and headings."""
    lines = wrap(s, width, size, weight)
    n = len(lines)
    if n < 2: return lines
    lo, hi, best = 0.0, width, lines
    for _ in range(18):
        mid = (lo + hi) / 2
        try: t = wrap(s, mid, size, weight)
        except ValueError: lo = mid; continue
        if len(t) <= n: best, hi = t, mid
        else: lo = mid
    return best


def auto_wrap(s, width, size, weight=400):
    """Paragraphs: fill lines, but balance when the last line would be under 45 % of the measure."""
    lines = wrap(s, width, size, weight)
    if len(lines) > 1 and text_width(lines[-1], size, weight) < 0.45 * width:
        return balanced_wrap(s, width, size, weight)
    return lines


class Rect:
    def __init__(self, x, y, w, h): self.x, self.y, self.w, self.h = x, y, w, h
    r = property(lambda s: s.x + s.w); b = property(lambda s: s.y + s.h)
    cx = property(lambda s: s.x + s.w / 2); cy = property(lambda s: s.y + s.h / 2)
    def __repr__(self): return f"Rect({self.x:.0f},{self.y:.0f},{self.w:.0f},{self.h:.0f})"


def fmt(v): return ("%.2f" % v).rstrip("0").rstrip(".")
def overlap(a, b, m=0): return a.x < b.r + m and b.x < a.r + m and a.y < b.b + m and b.y < a.b + m


def seg_rect_dist(x1, y1, x2, y2, r):
    n = max(2, int(math.hypot(x2 - x1, y2 - y1) / 2)); best = 1e9
    for k in range(n + 1):
        t = k / n; x, y = x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
        best = min(best, math.hypot(max(r.x - x, 0, x - r.r), max(r.y - y, 0, y - r.b)))
    return best


class FigureError(SystemExit):
    pass


class Figure:
    def __init__(self, title, alt, width=W, variant="standard", title_style=None, id=None):
        """title: the FINDING ("A restart always gets a new key"), never a topic ("Key lifecycle").
        alt: the whole message in one sentence; becomes aria-label. variant: slim (<=240), standard (<=300),
        tall (<=380, reference sheets only), stage (<=460, explainer stages); limits scale with width/760."""
        if not alt or len(alt.split()) < 5: raise ValueError("alt must state the figure's message in one sentence")
        self.w, self.alt, self.variant, self.id = width, alt, variant, id
        k = self.k = width / W
        self.T = {s: (round(a * k, 2), b, round(c * k, 2), d) for s, (a, b, c, d) in TYPE.items()}
        self.MARGIN, self.GUTTER, self.PAD_X, self.PAD_Y, self.CLEAR = (v * k for v in (MARGIN, GUTTER, PAD_X, PAD_Y, CLEAR))
        self.MIN = MIN_SIZE * k
        self.items, self.texts, self.shapes, self.segments, self.ends = [], [], [], [], []
        self.group, self.parent, self.bottom = None, {}, 0
        if title:
            st = title_style or ("slimtitle" if variant == "slim" else "title")
            size = self.T[st][0]
            y = self.MARGIN + round(size * ASC) + 2
            ys = self.text_block(self.MARGIN, y, title, st, width - 2 * self.MARGIN, role="title")
            self.top = ys + (18 if variant == "slim" else 20) * k
        else:
            self.top = self.MARGIN
    # convenience
    @property
    def right(self): return self.w - self.MARGIN

    # ---- low level ---------------------------------------------------------------------------------------
    @contextmanager
    def g(self, gid, cls=None):
        """Group elements under <g id=gid> so an explainer can show, hide, move or tween them."""
        prev, self.group = self.group, gid
        self.parent[gid] = prev
        self.items.append(("open", (gid, cls), gid))
        try: yield
        finally:
            self.items.append(("close", gid, gid)); self.group = prev

    def raw(self, svg, bbox=None, kind="art"):
        """Hand-drawn SVG (an icon). Give its bbox so the check keeps text and lines clear of it."""
        self.items.append(("svg", svg, self.group))
        if bbox: self.shapes.append((bbox, kind, self.group)); self.bottom = max(self.bottom, bbox.b)

    def text(self, x, y, s, style="body", anchor="start", cls=None, check=True, id=None, halo=False, role=None):
        size, weight, _, c = self.T[style]
        if size < self.MIN - 0.01: raise ValueError(f"figure text below {MIN_SIZE} units (at 760 wide)")
        cls = (cls or c) + (" halo" if halo else "")
        w = text_width(s, size, weight)
        x0 = x if anchor == "start" else x - w / 2 if anchor == "middle" else x - w
        a = "" if anchor == "start" else f' text-anchor="{anchor}"'
        fw = ' font-weight="700"' if weight >= 600 else ""
        extra = (f' id="{id}"' if id else "") + (' data-lint="halo"' if halo else "") + (f' data-role="{role}"' if role else "")
        self.items.append(("svg", f'<text x="{fmt(x)}" y="{fmt(y)}"{a} class="{cls}" font-size="{fmt(size)}"{fw}{extra}>{escape(s)}</text>', self.group))
        ink = Rect(x0, y - size * ASC, w, size * (ASC + DESC))
        if check: self.texts.append((ink, s, self.group, halo))
        self.bottom = max(self.bottom, ink.b)
        return ink

    def text_block(self, x, y, s, style, width, anchor="start", cls=None, balanced=None, role=None):
        """Wrapped text, first baseline at y. Returns the last baseline."""
        size, weight, lead, _ = self.T[style]
        lines = (balanced_wrap if balanced else auto_wrap)(s, width, size, weight)
        for i, ln in enumerate(lines):
            self.text(x, y + i * lead, ln, style, anchor, cls, role=role)
        return y + (len(lines) - 1) * lead

    def _head(self, pts, sw, hc, target):
        (x1, y1), (x2, y2) = pts[-2], pts[-1]
        L = math.hypot(x2 - x1, y2 - y1); ux, uy = (x2 - x1) / L, (y2 - y1) / L
        hl, hw = ((10, 5) if sw >= 2 else (9, 4.5)); hl *= self.k; hw *= self.k
        bx, by = x2 - ux * hl, y2 - uy * hl
        p1 = (bx - uy * hw, by + ux * hw); p2 = (bx + uy * hw, by - ux * hw)
        if target is not None: self.ends.append((x2, y2, target))
        return (bx + ux, by + uy), f'<path d="M{fmt(x2)} {fmt(y2)}L{fmt(p1[0])} {fmt(p1[1])}L{fmt(p2[0])} {fmt(p2[1])}z" class="{hc}"/>'

    def line(self, pts, kind="neutral", arrow=False, strike=False, target=None, cls=None, id=None, nohead_ok=False):
        """Polyline through pts. arrow=True ends in a filled head whose tip is the last point.
        strike=True marks a deliberate strike-through (exempt from line-through-text)."""
        lc, hc, sw = LINE[kind]; lc = cls or lc
        pts = [tuple(map(float, p)) for p in pts]
        draw, head = list(pts), ""
        if arrow: draw[-1], head = self._head(pts, sw, hc, target)
        d = "M" + "L".join(f"{fmt(x)} {fmt(y)}" for x, y in draw)
        lint = ' data-lint="strike"' if strike else (' data-lint="nohead"' if nohead_ok else "")
        idt = f' id="{id}"' if id else ""
        self.items.append(("svg", f'<path d="{d}" class="{lc}"{lint}{idt}/>' + head, self.group))
        if not strike:
            for a, b in zip(pts, pts[1:]): self.segments.append(((a[0], a[1], b[0], b[1]), self.group))
        for x, y in pts: self.bottom = max(self.bottom, y)
        return pts

    def curve(self, p0, c, p1, kind="neutral", arrow=False, target=None, label=None, label_side=1):
        """Quadratic curve p0 -> p1 bending through control point c (for links that must clear something).
        The check samples it as 24 segments. label: placed at the curve's midpoint, offset outward."""
        lc, hc, sw = LINE[kind]
        q = lambda t: ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1])
        pts = [q(i / 24) for i in range(25)]
        head = ""
        if arrow:
            end, head = self._head(pts, sw, hc, target)
            p1d = end
        else:
            p1d = p1
        d = f"M{fmt(p0[0])} {fmt(p0[1])}Q{fmt(c[0])} {fmt(c[1])} {fmt(p1d[0])} {fmt(p1d[1])}"
        self.items.append(("svg", f'<path d="{d}" class="{lc}"/>' + head, self.group))
        for a, b in zip(pts, pts[1:]): self.segments.append(((a[0], a[1], b[0], b[1]), self.group))
        for x, y in pts: self.bottom = max(self.bottom, y)
        if label:
            mx, my = q(0.5); size = self.T["label"][0]
            self.text(mx, my - label_side * (self.CLEAR + 6 * self.k) + (size * ASC if label_side < 0 else 0), label, "label", "middle")
        return pts

    def rect(self, r, cls, rx=8, kind="box", dash=None, id=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        idt = f' id="{id}"' if id else ""
        self.items.append(("svg", f'<rect x="{fmt(r.x)}" y="{fmt(r.y)}" width="{fmt(r.w)}" height="{fmt(r.h)}" rx="{fmt(rx * self.k)}" class="{cls}"{d}{idt}/>', self.group))
        self.shapes.append((r, kind, self.group)); self.bottom = max(self.bottom, r.b)
        return r

    def disc(self, cx, cy, label=None, tone="accent", r=13, id=None):
        """A filled numbered disc (a step marker)."""
        idt = f' id="{id}"' if id else ""
        self.items.append(("svg", f'<circle cx="{fmt(cx)}" cy="{fmt(cy)}" r="{fmt(r)}" class="{FILL[tone]}"{idt}/>', self.group))
        if label is not None:
            self.text(cx, cy + 4.6 * self.k, str(label), "sub", "middle", cls="ton", check=False)
        self.shapes.append((Rect(cx - r, cy - r, 2 * r, 2 * r), "disc", self.group))
        return Rect(cx - r, cy - r, 2 * r, 2 * r)

    def node(self, cx, cy, r, tone="plain", label=None, id=None):
        """An outlined circle (a system in a network drawing). label sits inside if it fits, else raises."""
        idt = f' id="{id}"' if id else ""
        self.items.append(("svg", f'<circle cx="{fmt(cx)}" cy="{fmt(cy)}" r="{fmt(r)}" class="{TONE[tone][0]}"{idt}/>', self.group))
        rr = Rect(cx - r, cy - r, 2 * r, 2 * r)
        if label:
            size = self.T["head"][0] if r >= 30 * self.k else self.T["sub"][0]
            if text_width(label, size, 700) > 1.6 * r - 4: raise ValueError(f"label {label!r} does not fit a node of radius {r}")
            self.text(cx, cy + size * 0.33, label, "head" if r >= 30 * self.k else "label", "middle", cls=TONE[tone][1], check=False)
        self.shapes.append((rr, "disc", self.group))
        return rr

    # ---- layout primitives -------------------------------------------------------------------------------
    def measure_box(self, w, head=None, body=None, sub=None, lines=None, icon=None, badge=None, align="left", pad=None):
        return self._layout_box(Rect(0, 0, w, 0), head, body, sub, lines, icon, badge, align, dry=True, pad=pad)

    def box(self, x, y, w, h=None, head=None, body=None, sub=None, lines=None, tone="plain", shape="service",
            icon=None, badge=None, align="left", valign="top", dash=None, pad=None, id=None):
        """A box sized to its content. head: bold heading (<= 5 words); body: ink paragraph; sub: quiet detail;
        lines: bullets. shape: 'service' (8 radius: systems, steps) or 'person' (20 radius: people, owners)."""
        pad = self.PAD_Y if pad is None else pad
        if pad < self.CLEAR + 2 * self.k: raise ValueError("box padding would put text within the clearance of its edge")
        need = self.measure_box(w, head, body, sub, lines, icon, badge, align, pad)
        h = max(h or 0, need)
        r = self.rect(Rect(x, y, w, h), TONE[tone][0], RADIUS[shape], dash=dash, id=id)
        off = (h - need) / 2 if valign == "middle" else 0
        self._layout_box(Rect(x, y + off, w, h), head, body, sub, lines, icon, badge, align, tone=tone, pad=pad)
        return r

    def _layout_box(self, r, head, body, sub, lines, icon, badge, align, dry=False, tone="plain", pad=None):
        k = self.k; pad = self.PAD_Y if pad is None else pad
        x0, inner = r.x + self.PAD_X, r.w - 2 * self.PAD_X
        anchor, tx = ("middle", r.cx) if align == "center" else ("start", x0)
        y, first = r.y + pad, [True]
        def gap(n):
            nonlocal y
            if not first[0]: y += n * k
            first[0] = False
        if badge is not None:
            gap(0)
            if not dry: self.disc((r.cx if align == "center" else x0 + 13 * k), y + 13 * k, str(badge), tone={"good": "good", "warn": "warn", "mute": "mute"}.get(tone, "accent"), r=13 * k)
            y += 26 * k
        if head:
            gap(10)
            size, weight, lead, _ = self.T["head"]
            hx, hw = tx, inner
            if icon:
                hx, hw = x0 + 34 * k, inner - 34 * k
                if not dry: draw_icon(self, icon, x0, y - 2 * k)
            hl = balanced_wrap(head, hw, size, weight)
            base = y + size * ASC
            if not dry:
                hcls = TONE[tone][1] if tone in ("good", "warn", "info", "crit", "mute") else "t"
                for i, ln in enumerate(hl): self.text(hx, base + i * lead, ln, "head", anchor if not icon else "start", cls=hcls)
            y = base + (len(hl) - 1) * lead + size * DESC
            if icon: y = max(y, r.y + pad + 26 * k)
        for style, txt in (("body", body), ("sub", sub)):
            if not txt: continue
            gap(8)
            size, weight, lead, _ = self.T[style]
            for para in (txt if isinstance(txt, list) else [txt]):
                ls = balanced_wrap(para, inner, size, weight)
                base = y + size * ASC
                if not dry:
                    for i, ln in enumerate(ls): self.text(tx, base + i * lead, ln, style, anchor)
                y = base + (len(ls) - 1) * lead + size * DESC + 6 * k
            y -= 6 * k
        if lines:
            gap(10)
            size, weight, lead, _ = self.T["body"]
            ind = 14 * k
            for j, item in enumerate(lines):
                if j: y += 8 * k
                ls = balanced_wrap(item, inner - ind, size, weight)
                base = y + size * ASC
                if not dry:
                    fill = {"good": "fg", "warn": "fw", "accent": "fa", "info": "fi"}.get(tone, "fl")
                    self.items.append(("svg", f'<circle cx="{fmt(x0 + 3 * k)}" cy="{fmt(base - size * 0.32)}" r="{fmt(2.6 * k)}" class="{fill}"/>', self.group))
                    for i, ln in enumerate(ls): self.text(x0 + ind, base + i * lead, ln, "body")
                y = base + (len(ls) - 1) * lead + size * DESC
        return math.ceil(y + pad - r.y)

    def row(self, y, specs, x0=None, x1=None, gap=None, widths=None, equal=True, **common):
        """Boxes side by side across x0..x1, equal heights unless equal=False. widths: relative weights."""
        x0 = self.MARGIN if x0 is None else x0; x1 = self.right if x1 is None else x1
        gap = self.GUTTER if gap is None else gap
        n = len(specs); widths = widths or [1] * n
        avail = x1 - x0 - gap * (n - 1)
        ws = [avail * q / sum(widths) for q in widths]
        merged = [dict(common, **s) for s in specs]
        H = max(self.measure_box(ws[i], **_pick(merged[i])) for i in range(n))
        out, x = [], x0
        for i, s in enumerate(merged):
            out.append(self.box(x, y, ws[i], H if equal else None, **s)); x += ws[i] + gap
        return out

    def column(self, x, y, w, specs, gap=12, equal=False, **common):
        merged = [dict(common, **s) for s in specs]
        H = max(self.measure_box(w, **_pick(s)) for s in merged) if equal else None
        out = []
        for s in merged:
            b = self.box(x, y, w, H, **s); out.append(b); y = b.b + gap * self.k
        return out

    def grid(self, y, cols, rows, col_widths=None, head_tone="panel", cell_tone="plain", gap=6, x0=None, x1=None, row_heads=True):
        """A comparison matrix: rows of equal-height cells. rows: list of lists of cell specs or strings.
        cols: header strings (None for no header row). Returns the list of row rectangles per row."""
        x0 = self.MARGIN if x0 is None else x0; x1 = self.right if x1 is None else x1
        g = gap * self.k
        out = []
        if cols:
            out.append(self.row(y, [dict(head=c, tone=head_tone, pad=10 * self.k) for c in cols], x0=x0, x1=x1, gap=g, widths=col_widths))
            y = out[-1][0].b + g
        for r_ in rows:
            specs = []
            for j, c in enumerate(r_):
                c = dict(sub=c) if isinstance(c, str) else dict(c)
                if j == 0 and row_heads and "head" not in c and "sub" in c: c = dict(head=c.pop("sub"), **c)
                c.setdefault("tone", cell_tone); c.setdefault("pad", 10 * self.k); c.setdefault("valign", "middle")
                specs.append(c)
            out.append(self.row(y, specs, x0=x0, x1=x1, gap=g, widths=col_widths))
            y = out[-1][0].b + g
        return out

    def connect(self, a, b, kind="neutral", label=None, side=None, route=None, label_pos=0.5, at=None):
        """Arrow from box a to box b, edge to edge; side 'h' or 'v' is inferred. route='elbow' for a dogleg.
        Labels go above a horizontal arrow and right of a vertical one, clear of the line."""
        if side is None: side = "h" if (b.x >= a.r or a.x >= b.r) else "v"
        e = 0.75 * self.k
        if side == "h":
            fwd = b.x >= a.r
            sx, ex = (a.r, b.x - e) if fwd else (a.x, b.r + e)
            if at is None:
                lo, hi = max(a.y, b.y), min(a.b, b.b); at = (lo + hi) / 2 if lo < hi else None
            pts = [(sx, at), (ex, at)] if at is not None and route != "elbow" else \
                [(sx, a.cy), ((sx + ex) / 2, a.cy), ((sx + ex) / 2, b.cy), (ex, b.cy)]
        else:
            fwd = b.y >= a.b
            sy, ey = (a.b, b.y - e) if fwd else (a.y, b.b + e)
            if at is None:
                lo, hi = max(a.x, b.x), min(a.r, b.r); at = (lo + hi) / 2 if lo < hi else None
            pts = [(at, sy), (at, ey)] if at is not None and route != "elbow" else \
                [(a.cx, sy), (a.cx, (sy + ey) / 2), (b.cx, (sy + ey) / 2), (b.cx, ey)]
        self.line(pts, kind, arrow=True, target=b)
        if label:
            (x1, y1), (x2, y2) = pts[0], pts[-1]
            if side == "h": self.text(x1 + (x2 - x1) * label_pos, pts[0][1] - self.CLEAR - 5 * self.k, label, "label", "middle")
            else: self.text(pts[0][0] + self.CLEAR + 2 * self.k, y1 + (y2 - y1) * label_pos + 4.5 * self.k, label, "label")
        return pts

    def fan(self, a, targets, kind="neutral", spine_gap=None, direction="right"):
        """One box to several: a stub, one spine, an arrow to each target. direction 'right' or 'down'."""
        if direction == "right":
            xs = a.r + (spine_gap if spine_gap is not None else (min(t.x for t in targets) - a.r) / 2)
            cys = [t.cy for t in targets]
            self.line([(a.r, a.cy), (xs, a.cy)], kind, nohead_ok=True)
            self.line([(xs, min(cys + [a.cy])), (xs, max(cys + [a.cy]))], kind, nohead_ok=True)
            for t in targets: self.line([(xs, t.cy), (t.x - 0.75 * self.k, t.cy)], kind, arrow=True, target=t)
        else:
            ys = a.b + (spine_gap if spine_gap is not None else (min(t.y for t in targets) - a.b) / 2)
            cxs = [t.cx for t in targets]
            self.line([(a.cx, a.b), (a.cx, ys)], kind, nohead_ok=True)
            self.line([(min(cxs + [a.cx]), ys), (max(cxs + [a.cx]), ys)], kind, nohead_ok=True)
            for t in targets: self.line([(t.cx, ys), (t.cx, t.y - 0.75 * self.k)], kind, arrow=True, target=t)

    def band(self, y, text, tone="accent", x0=None, x1=None, style="head", align="center", h=None, lead_in=None):
        """A full-width band: the shared thing everything sits on, or a closing statement.
        lead_in: one bold word or two in their own column at the left."""
        x0 = self.MARGIN if x0 is None else x0; x1 = self.right if x1 is None else x1
        size, weight, lead, _ = self.T[style]
        lw = text_width(lead_in, self.T["head"][0], 700) + 20 * self.k if lead_in else 0
        inner = x1 - x0 - 2 * self.PAD_X - lw
        if align == "center" and not lead_in: ls = balanced_wrap(text, inner, size, weight)
        else:   # a wide band: fill lines; balance only to rescue a one-word or very short last line
            ls = wrap(text, inner, size, weight)
            if len(ls) > 1 and (len(ls[-1].split()) == 1 or text_width(ls[-1], size, weight) < 0.3 * inner):
                ls = balanced_wrap(text, inner, size, weight)
        block = size * (ASC + DESC) + (len(ls) - 1) * lead
        h = max(h or 0, math.ceil(2 * self.PAD_Y - 2 * self.k + block))
        r = self.rect(Rect(x0, y, x1 - x0, h), TONE[tone][0], RADIUS["band"], kind="band")
        base = y + (h - block) / 2 + size * ASC
        if lead_in:
            self.text(x0 + self.PAD_X, base, lead_in, "head")
            for i, ln in enumerate(ls): self.text(x0 + self.PAD_X + lw, base + i * lead, ln, style, role="statement")
        else:
            tx, anchor = ((x0 + x1) / 2, "middle") if align == "center" else (x0 + self.PAD_X, "start")
            for i, ln in enumerate(ls): self.text(tx, base + i * lead, ln, style, anchor, role="statement")
        return r

    def zone(self, r, label=None, tone="panel", back=False, dash=None):
        """An enclosure (a site, a boundary) drawn behind its contents, label top-left.
        back=True moves it behind everything already drawn, so it can be sized after its contents."""
        self.rect(r, TONE[tone][0], RADIUS["zone"], kind="zone", dash=dash)
        if back: self.items.insert(0, self.items.pop())
        if label:
            self.text(r.x + self.PAD_X, r.y + self.PAD_Y + self.T["label"][0] * ASC, label, "label",
                      cls=TONE[tone][1] if tone not in ("panel", "plain") else "tq")
        return r

    def cut(self, x, y, label="cut", above=True):
        """The mark for a link that is down: an amber cross on the line, labelled. Draw the line in two parts
        either side of x first (a gap of 12 units each way)."""
        k = self.k; s = 8 * k
        self.raw(f'<path d="M{fmt(x-s)} {fmt(y-s)}l{fmt(2*s)} {fmt(2*s)}M{fmt(x+s)} {fmt(y-s)}l{fmt(-2*s)} {fmt(2*s)}" class="lnw" data-lint="strike"/>',
                 Rect(x - s, y - s, 2 * s, 2 * s), kind="art")
        ty = y - 22 * k if above else y + 22 * k + self.T["label"][0] * ASC
        self.text(x, ty, label, "label", "middle", cls="tw")

    def note(self, text, y=None, gap=20):
        """The dated note under everything (quiet 13). Starts 'As of <date>:' when it states a status."""
        size = self.T["note"][0]
        y = y if y is not None else self.content_bottom() + gap * self.k + size * ASC
        return self.text_block(self.MARGIN, y, text, "note", self.w - 2 * self.MARGIN, role="note")

    def content_bottom(self):
        return max([self.bottom] + [r.b for r, *_ in self.shapes])

    # ---- check and output ---------------------------------------------------------------------------------
    def check(self):
        """Geometry check of the whole figure. Returns a list of problems (empty is clean)."""
        T = [(r, s, halo) for r, s, g, halo in self.texts]
        S = [(r, k) for r, k, g in self.shapes]
        L = [seg for seg, g in self.segments]
        H, C, probs = self.height, self.CLEAR, []
        for r, s, _ in T:
            if r.x < 2 or r.r > self.w - 2 or r.y < 2 or r.b > H - 2: probs.append(f"text leaves the viewBox: {s!r} {r}")
        for i, (a, sa, _) in enumerate(T):
            for b, sb, _ in T[i + 1:]:
                if overlap(a, b, -2 * self.k): probs.append(f"text overlaps text: {sa!r} / {sb!r}")
        for r, s, halo in T:
            for b, kind in S:
                if kind == "art":
                    if overlap(r, b, C - 4 * self.k): probs.append(f"text within {C - 4:.0f} of a glyph: {s!r}")
                    continue
                inside = r.x >= b.x and r.r <= b.r and r.y >= b.y and r.b <= b.b
                if inside:
                    if kind == "disc": continue
                    gap = min(r.x - b.x, b.r - r.r, r.y - b.y, b.b - r.b)
                    if gap < C - 0.01: probs.append(f"text {gap:.1f} from a box edge (needs {C:.0f}): {s!r}")
                elif overlap(r, b, 0): probs.append(f"text straddles a box edge: {s!r} {r} / {b}")
                elif overlap(r, b, C - 0.01) and kind != "disc": probs.append(f"text closer than {C:.0f} to a box outside it: {s!r}")
            if halo: continue
            for (x1, y1, x2, y2) in L:
                if seg_rect_dist(x1, y1, x2, y2, r) < C - 0.01: probs.append(f"a line passes within {C:.0f} of text: {s!r}"); break
        for x, y, t in self.ends:
            on = ((abs(x - t.x) < 1.6 or abs(x - t.r) < 1.6) and t.y - 0.5 <= y <= t.b + 0.5) or \
                 ((abs(y - t.y) < 1.6 or abs(y - t.b) < 1.6) and t.x - 0.5 <= x <= t.r + 0.5)
            if not on: probs.append(f"arrow tip ({x:.1f},{y:.1f}) is not on the edge of {t}")
        return probs

    @property
    def height(self):
        return getattr(self, "_h", None) or math.ceil(self.content_bottom() + self.MARGIN)

    def svg(self, height=None, check=True):
        if height: self._h = height
        H = self.height
        if check:
            limit = MAX_H[self.variant] * self.k
            if H > limit + 0.5:
                raise FigureError(f"figkit: figure is {H} units tall; the {self.variant} limit at this width is {limit:.0f}. "
                                  "Split it, lay it out horizontally, tighten the stack (pad=10), or make it an explainer.")
            probs = self.check()
            if probs: raise FigureError("figkit check failed:\n  " + "\n  ".join(dict.fromkeys(probs)))
        body = []
        for kind, data, _ in self.items:
            if kind == "open":
                gid, cls = data; body.append(f'<g id="{gid}"' + (f' class="{cls}"' if cls else "") + ">")
            elif kind == "close": body.append("</g>")
            else: body.append(data)
        idt = f' id="{self.id}"' if self.id else ""
        return (f'<svg{idt} class="viz" viewBox="0 0 {fmt(self.w)} {H}" role="img" aria-label="{escape(self.alt)}">\n'
                + "\n".join(body) + "\n</svg>\n")

    def save(self, path, **kw):
        s = self.svg(**kw)
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        open(path, "w").write(s)
        return s


def _pick(d): return {k: v for k, v in d.items() if k in ("head", "body", "sub", "lines", "icon", "badge", "align", "pad")}


def ring(n, cx, cy, r, start=-math.pi / 2):
    """n points evenly round a circle, the first at the top."""
    return [(cx + r * math.cos(start + 2 * math.pi * i / n), cy + r * math.sin(start + 2 * math.pi * i / n)) for i in range(n)]


def draw_icon(f, name, x, y, cls="fa"):
    """24-unit glyphs in the accent fill: person, device, service, store, key. Keep icons plain (record F12)."""
    k = f.k; P = lambda v: fmt(v)
    s = lambda v: v * k
    p = {
        "person": f'<circle cx="{P(x+s(12))}" cy="{P(y+s(7))}" r="{P(s(6))}" class="{cls}"/><path d="M{P(x+s(1))} {P(y+s(24))}q{P(s(11))} {P(-s(16))} {P(s(22))} 0z" class="{cls}"/>',
        "device": f'<rect x="{P(x+s(4))}" y="{P(y+s(5))}" width="{P(s(16))}" height="{P(s(19))}" rx="{P(s(3))}" class="{cls}"/>',
        "service": f'<path d="M{P(x+s(12))} {P(y)}l{P(s(11))} {P(s(6.3))}v{P(s(12.7))}l{P(-s(11))} {P(s(6.3))}l{P(-s(11))} {P(-s(6.3))}v{P(-s(12.7))}z" class="{cls}"/>',
        "store": f'<path d="M{P(x+s(2))} {P(y+s(5))}v{P(s(14))}c0 {P(s(3))} {P(s(20))} {P(s(3))} {P(s(20))} 0v{P(-s(14))}" class="{cls}"/><ellipse cx="{P(x+s(12))}" cy="{P(y+s(5))}" rx="{P(s(10))}" ry="{P(s(3.5))}" class="{cls}"/>',
        "key": f'<circle cx="{P(x+s(7))}" cy="{P(y+s(12))}" r="{P(s(6))}" class="{cls}"/><path d="M{P(x+s(12))} {P(y+s(10.5))}h{P(s(11))}v{P(s(3))}h{P(-s(3))}v{P(s(4))}h{P(-s(3))}v{P(-s(4))}h{P(-s(5))}z" class="{cls}"/>',
    }[name]
    f.raw(p, Rect(x, y - k, 24 * k, 26 * k))


# ---- page wrapper: one self-contained HTML page holding figures, for lint, PNG and delivery --------------
def page(figures, title, css=None, out=None, captions=None, lang="en", extra_head=""):
    """Wrap SVG strings in a self-contained page (CSS inlined; no external requests).
    css: path(s) to stylesheets; default templates/viz.css. captions: one per figure (the 'so what')."""
    css = css or [os.path.join(os.path.dirname(HERE), "templates", "viz.css")]
    css = [css] if isinstance(css, str) else css
    style = "\n".join(open(p).read() for p in css)
    captions = captions or [None] * len(figures)
    figs = "\n".join(f'<figure><div class="fig">{s}</div>' + (f"<figcaption>{escape(c)}</figcaption>" if c else "") + "</figure>"
                     for s, c in zip(figures, captions))
    html = (f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width, initial-scale=1"><title>{escape(title)}</title>'
            f'<style>{style}</style>{extra_head}</head><body><main>{figs}</main></body></html>\n')
    if out:
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        open(out, "w").write(html)
    return html
