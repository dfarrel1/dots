#!/usr/bin/env python3
"""patterns: parameterised, measured figure layouts for the shapes that recur. START HERE for any new figure.

Every new figure that did not follow an existing set struggled for its first rounds because it started from a
blank canvas (record: critique logs, rounds 1-3). A pattern carries the layout decisions those rounds paid for:
pitch, gaps, label placement, wrap rules, height budget, and what to do when the data grows. Pick the nearest
pattern, change the labels and data, then extend it. Each function returns a figkit Figure (call .save()).

Every pattern adapts to its data (it switches layout or variant when items grow) and REFUSES, with the pattern
to use instead, when the data cannot make a legible figure. A refusal is the system working (record W2).

    import sys; sys.path[:0] = ["<skill>/scripts", "<skill>/patterns"]
    from patterns import process_line
    process_line("Nothing is issued until two people approve", alt="...", steps=[("Sponsor invites", "single-use link"), ...]).save("out/x.svg")

Catalogue, with use-when / avoid-when and rendered examples: patterns/README.md. Worst-case tests (long labels,
2 and 9 items): patterns/test_patterns.py.
"""
import math, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts"))
from figkit import Figure, FigureError, Rect, ring, text_width, balanced_wrap, ASC, TONE, FILL, fmt
from chartkit import Chart, Scale, num


class Refused(ValueError):
    """The data cannot make a legible figure in this pattern. The message names what to do instead."""


def fits(build, variants=("standard", "tall")):
    """Build with the first variant whose height limit the figure fits. Returns the Figure (checked)."""
    last = None
    for v in variants:
        f = build(v)
        try: f.svg(); return f
        except FigureError as e:
            last = e
            if "units tall" not in str(e): raise
    raise last


def _tone(spec, default="plain"):
    return spec[2] if len(spec) > 2 and spec[2] else default


# ---- 1. process line ----------------------------------------------------------------------------------------
def process_line(title, alt, steps, bracket=None, closing=None, closing_lead=None, last_tone="good", variant=None, numbers=None):
    """Numbered steps in reading order. steps: [(head, sub)]. bracket: (i, j, label) over steps i..j (0-based),
    e.g. the two approvals. closing: a statement band under the line (closing_lead: its bold lead word).
    numbers: the disc labels when the steps carry numbers of their own (a driver's phase ranges, "1–2"),
    so a figure never shows a second numbering beside the one the reader resumes from; default 1..n.
    Horizontal for up to 6 steps whose words fit; otherwise numbered rows in one or two columns."""
    n = len(steps)
    if numbers is not None and len(numbers) != n: raise Refused("numbers= needs one label per step")
    labels = [str(x) for x in numbers] if numbers is not None else [str(i + 1) for i in range(n)]
    def disc_r(f, base):
        return max(base, max(text_width(l, f.T["sub"][0], 700) for l in labels) / 2 + 6 * f.k)
    if n < 2: raise Refused("a process needs at least two steps")
    if n > 10: raise Refused("more than 10 steps: split the process into phases, one figure each")
    def horizontal(v, per_row=None):
        f = Figure(title, alt, variant=v)
        per = per_row or n
        pitch = (f.w - 2 * f.MARGIN) / per
        r = disc_r(f, 15 * f.k)
        cy0 = f.top + (46 if bracket else 20) * f.k
        if per < n:              # two rows: the second starts under the first, numbering carries the order
            return _two_rows(f, steps, per, pitch, r, cy0, last_tone, closing, closing_lead, labels)
        cx = [f.MARGIN + pitch * (i + 0.5) for i in range(n)]
        cy = cy0
        if bracket:
            i, j, lab = bracket
            by = cy - r - 12 * f.k
            f.line([(cx[i], cy - r - 4 * f.k), (cx[i], by), (cx[j], by), (cx[j], cy - r - 4 * f.k)], "neutral", nohead_ok=True)
            f.text((cx[i] + cx[j]) / 2, by - 12 * f.k, lab, "label", "middle", cls="ta")
        for i in range(n - 1):
            f.line([(cx[i] + r + 6 * f.k, cy), (cx[i + 1] - r - 1.5 * f.k, cy)], "neutral", arrow=True)
        for i, (h, sub) in enumerate(steps):
            last = i == n - 1 and last_tone
            f.disc(cx[i], cy, labels[i], tone=last_tone if last else "accent", r=r)
            y = f.text_block(cx[i], cy + r + 26 * f.k, h, "head", pitch - 8 * f.k, anchor="middle", balanced=True, cls="tg" if last == "good" else "t")
            if sub: f.text_block(cx[i], y + 22 * f.k, sub, "sub", pitch - 8 * f.k, anchor="middle", balanced=True)
        if closing: f.band(f.content_bottom() + 24 * f.k, closing, tone="panel", style="body", lead_in=closing_lead, align="left")
        return f
    def rows(v):
        f = Figure(title, alt, variant=v)
        cols = 1 if n <= 5 else 2
        per = math.ceil(n / cols)
        colw = (f.w - 2 * f.MARGIN - 40 * f.k * (cols - 1)) / cols
        r, pitch = disc_r(f, 12 * f.k), 46 * f.k
        y0 = f.top + r + 2 * f.k
        pos = []
        for i, (h, sub) in enumerate(steps):
            c, k = divmod(i, per)
            x = f.MARGIN + c * (colw + 40 * f.k); y = y0 + k * pitch
            pos.append((x + r, y))
            last = i == n - 1 and last_tone
            f.disc(x + r, y, labels[i], tone=last_tone if last else "accent", r=r)
            hw = text_width(h, f.T["head"][0], 700)
            tx = x + 2 * r + 12 * f.k
            if tx + hw > x + colw: raise Refused(f"step {h!r} is too long for a column: shorten it to a few words")
            f.text(tx, y + 5 * f.k, h, "head", cls="tg" if last == "good" else "t")
            if sub:
                sx = tx + hw + 10 * f.k
                if sx + text_width(sub, f.T["sub"][0]) <= x + colw: f.text(sx, y + 5 * f.k, sub, "sub")
                else: raise Refused(f"the detail {sub!r} does not fit beside {h!r}: shorten it, or move it to the caption")
        for i in range(n - 1):
            (x1, y1), (x2, y2) = pos[i], pos[i + 1]
            if x1 == x2: f.line([(x1, y1 + r + 4 * f.k), (x2, y2 - r - 1.5 * f.k)], "neutral", arrow=True)
            else:       # continue into the next column: below the last row, up the gutter, into the first disc
                yb = y1 + r + 12 * f.k; gx = x2 - r - 20 * f.k
                f.line([(x1, y1 + r + 4 * f.k), (x1, yb), (gx, yb), (gx, y2), (x2 - r - 1.5 * f.k, y2)], "neutral", arrow=True)
        if closing: f.band(f.content_bottom() + 24 * f.k, closing, tone="panel", style="body", lead_in=closing_lead, align="left")
        return f
    if variant: return (horizontal if n <= 6 else rows)(variant)
    tries = [lambda v: horizontal(v)] if n <= 6 else [lambda v: horizontal(v, math.ceil(n / 2))]
    for t in tries:
        try: return fits(t)
        except (ValueError, FigureError) as e:
            if isinstance(e, Refused): raise
    return fits(rows)


def _two_rows(f, steps, per, pitch, r, cy, last_tone, closing, closing_lead, labels=None):
    n = len(steps)
    bottom = cy
    for row in range(2):
        idx = list(range(row * per, min(n, (row + 1) * per)))
        cx = [f.MARGIN + pitch * (k + 0.5) for k in range(len(idx))]
        for a in range(len(idx) - 1):
            f.line([(cx[a] + r + 6 * f.k, cy), (cx[a + 1] - r - 1.5 * f.k, cy)], "neutral", arrow=True)
        for k, i in enumerate(idx):
            h, sub = steps[i]
            last = i == n - 1 and last_tone
            f.disc(cx[k], cy, labels[i] if labels else i + 1, tone=last_tone if last else "accent", r=r)
            y = f.text_block(cx[k], cy + r + 26 * f.k, h, "head", pitch - 8 * f.k, anchor="middle", balanced=True, cls="tg" if last == "good" else "t")
            if sub: y = f.text_block(cx[k], y + 22 * f.k, sub, "sub", pitch - 8 * f.k, anchor="middle", balanced=True)
            bottom = max(bottom, y)
        cy = bottom + 30 * f.k + r
    if closing: f.band(f.content_bottom() + 24 * f.k, closing, tone="panel", style="body", lead_in=closing_lead, align="left")
    return f


# ---- 2. hub and spoke against pair by pair -------------------------------------------------------------------
def hub_vs_mesh(title, alt, n, left="Pair by pair", right="Through one hub", hub="Hub", unit=("system", "systems"),
                link=("link", "links"), conn=("connection", "connections"), note=None):
    """Two networks side by side: n nodes joined pair by pair (n(n-1)/2 links) against n nodes on one hub
    (n connections). Counts are computed, never typed. 2 <= n <= 12."""
    if not 2 <= n <= 12: raise Refused("use 2 to 12 nodes; for larger n show the numbers in a chart (annotated_chart)")
    for R0 in (64, 56, 50):                 # shrink the rings before giving up the standard height
        try: return fits(lambda v: _hub(title, alt, n, left, right, hub, unit, link, conn, note, v, R0), ("standard",))
        except FigureError as e:
            if "units tall" not in str(e): raise
    return fits(lambda v: _hub(title, alt, n, left, right, hub, unit, link, conn, note, v, 50), ("tall",))


def _hub(title, alt, n, left, right, hub, unit, link, conn, note, variant, R0):
    f = Figure(title, alt, variant=variant)
    R = R0 * f.k; nr = (12 if n <= 6 else 9 if n <= 9 else 7) * f.k; hr = 26 * f.k
    cy = f.top + 6 * f.k + R + nr
    lx, rx = f.MARGIN + (f.w - 2 * f.MARGIN) * 0.25, f.MARGIN + (f.w - 2 * f.MARGIN) * 0.75
    P = ring(n, lx, cy, R)
    for i in range(n):
        for j in range(i + 1, n):
            (x1, y1), (x2, y2) = P[i], P[j]; d = math.hypot(x2 - x1, y2 - y1); ux, uy = (x2 - x1) / d, (y2 - y1) / d
            f.line([(x1 + ux * nr, y1 + uy * nr), (x2 - ux * nr, y2 - uy * nr)], "neutral", nohead_ok=True)
    for x, y in P: f.node(x, y, nr)
    Q = ring(n, rx, cy, R)
    for x, y in Q:
        d = math.hypot(x - rx, y - cy); ux, uy = (x - rx) / d, (y - cy) / d
        f.line([(rx + ux * hr, cy + uy * hr), (x - ux * nr, y - uy * nr)], "flow", nohead_ok=True)
    f.node(rx, cy, hr, tone="accent")
    for x, y in Q: f.node(x, y, nr)
    if text_width(hub, f.T["sub"][0], 700) <= 1.6 * hr - 4: f.text(rx, cy + 4.5 * f.k, hub, "label", "middle", cls="t")
    L = n * (n - 1) // 2
    yl = cy + R + nr + 26 * f.k
    colw = (f.w - 2 * f.MARGIN) / 2 - 24 * f.k
    a = f.text_block(lx, yl, left, "head", colw, anchor="middle", balanced=True)
    f.text_block(lx, a + 22 * f.k, f"{n} {unit[n != 1]}, {L:,} {link[L != 1]}", "body", colw, anchor="middle", balanced=True, cls="tw")
    b = f.text_block(rx, yl, right, "head", colw, anchor="middle", balanced=True)
    f.text_block(rx, b + 22 * f.k, f"{n} {unit[n != 1]}, {n} {conn[n != 1]}", "body", colw, anchor="middle", balanced=True, cls="tg")
    f.line([(f.w / 2, f.top + 4 * f.k), (f.w / 2, f.content_bottom())], "rule", nohead_ok=True)
    if note: f.note(note, gap=16)
    return f


# ---- 3. layers / nesting ---------------------------------------------------------------------------------------
def layers(title, alt, levels, core, note=None):
    """Nested envelopes, outermost first. levels: [(label, sub, tone)], core: (head, sub). Up to 6 levels;
    each level's label sits top-left inside it. Deeper nesting: use stack() (an ordered list of tiers)."""
    if len(levels) > 6: raise Refused("more than 6 nesting levels cannot be read as rings: use stack() with the order stated")
    def build(v):
        f = Figure(title, alt, variant=v)
        dx, top, bot = 26 * f.k, 34 * f.k, 12 * f.k
        n = len(levels)
        ch = f.measure_box(f.w - 2 * f.MARGIN - 2 * n * dx, head=core[0], sub=core[1], align="center")
        y = f.top
        total = n * (top + bot) + ch
        for i, lv in enumerate(levels):
            x = f.MARGIN + i * dx; w = f.w - 2 * x; h = total - i * (top + bot)
            f.rect(Rect(x, y + i * top, w, h), TONE[_tone(lv, "panel" if i % 2 == 0 else "plain")][0], 12, kind="zone")
            f.text(x + f.PAD_X, y + i * top + 21 * f.k, lv[0], "label", cls=TONE[_tone(lv, "panel")][1] if _tone(lv, "panel") not in ("panel", "plain") else "tq")
            if lv[1]:
                lw = text_width(lv[0], f.T["label"][0], 700)
                f.text(x + f.PAD_X + lw + 10 * f.k, y + i * top + 21 * f.k, lv[1], "sub")
        cx = f.MARGIN + n * dx
        f.box(cx, y + n * top, f.w - 2 * cx, ch, head=core[0], sub=core[1], tone="accent", align="center")
        if note: f.note(note, gap=16)
        return f
    return fits(build)


# ---- 4. enclosure: a boundary, what is inside, the link to the outside (optionally cut) ------------------------
def enclosure(title, alt, zone_label, inside, outside=None, cut=False, cut_label="cut", link_label=None, note=None, zone_tone="accent"):
    """A site or boundary drawn around its contents, an outside party on the left, and the link between them,
    broken by an amber cross when cut=True. inside: [(head, sub, tone)], 1..9 items in up to 3 columns."""
    if not 1 <= len(inside) <= 9: raise Refused("1 to 9 items inside the boundary; more belongs in a table")
    def build(v, cols=None):
        f = Figure(title, alt, variant=v)
        ow = 150 * f.k if outside else 0; link = 64 * f.k if outside else 0
        zx = f.MARGIN + ow + link
        n = len(inside); cols = cols or (min(3, n) if n != 4 else 2)
        rows_ = [inside[i:i + cols] for i in range(0, n, cols)]
        y = f.top + 40 * f.k
        boxes = []
        for row in rows_:
            specs = [dict(head=h, sub=s, tone=_tone((h, s) + tuple(rest), "plain"), pad=10 * f.k) for h, s, *rest in row]
            while len(specs) < cols: specs.append(None)
            real = [s for s in specs if s]
            span = (f.right - 16 * f.k) - (zx + 16 * f.k)
            w1 = (span - 16 * f.k * (cols - 1)) / cols
            bx = f.row(y, real, x0=zx + 16 * f.k, x1=zx + 16 * f.k + w1 * len(real) + 16 * f.k * (len(real) - 1), gap=16 * f.k)
            boxes += bx; y = bx[0].b + 12 * f.k
        site = f.zone(Rect(zx, f.top, f.right - zx, y - 12 * f.k + 14 * f.k - f.top), tone=zone_tone, back=True)
        f.text(zx + 16 * f.k, f.top + 14 * f.k + f.T["head"][0] * ASC, zone_label, "head")
        if outside:
            h = f.measure_box(ow, head=outside[0], sub=outside[1], align="center")
            ob = f.box(f.MARGIN, site.cy - h / 2, ow, h, head=outside[0], sub=outside[1], tone="panel", align="center")
            x1, x2, yy = ob.r, site.x, site.cy
            if cut:
                mid = (x1 + x2) / 2
                f.line([(x1, yy), (mid - 12 * f.k, yy)], "neutral", nohead_ok=True)
                f.line([(mid + 12 * f.k, yy), (x2, yy)], "neutral", nohead_ok=True)
                f.cut(mid, yy, cut_label)
            else:
                f.line([(x1, yy), (x2 - 0.75 * f.k, yy)], "flow", arrow=True, target=site)
                if link_label: f.text((x1 + x2) / 2, yy - 13 * f.k, link_label, "label", "middle")
        if note: f.note(note, gap=16)
        return f
    start = min(3, len(inside)) if len(inside) != 4 else 2
    for cols in range(start, 0, -1):          # long words: fall back to fewer, wider columns
        try: return fits(lambda v: build(v, cols))
        except ValueError as e:
            if isinstance(e, Refused) or cols == 1: raise


# ---- 5. fan-out: one owner to several choices ---------------------------------------------------------------
def fan_out(title, alt, owner, choices, note=None, kind="neutral"):
    """One owner (a band or box at the top) to its choices (a row beneath, through one spine).
    owner: (head, sub). choices: [(head, sub, tone)], 2..10, in rows of up to 5 fed by a trunk on the left."""
    if not 2 <= len(choices) <= 10: raise Refused("2 to 10 choices; more belongs in a table")
    def build(v):
        f = Figure(title, alt, variant=v)
        ow = min(f.w - 2 * f.MARGIN, max(260 * f.k, text_width(owner[0], f.T["head"][0], 700) + 2 * f.PAD_X + 20 * f.k))
        oh = f.measure_box(ow, head=owner[0], sub=owner[1], align="center")
        ob = f.box((f.w - ow) / 2, f.top, ow, oh, head=owner[0], sub=owner[1], tone="accent", shape="person", align="center")
        per = 5 if len(choices) > 5 else len(choices)
        rows_ = [choices[i:i + per] for i in range(0, len(choices), per)]
        multi = len(rows_) > 1
        x0 = f.MARGIN + (22 * f.k if multi else 0)
        y = ob.b + 40 * f.k
        trunk_x = f.MARGIN + 6 * f.k
        prev_bus = None
        for k, row in enumerate(rows_):
            specs = [dict(head=h, sub=s, tone=_tone((h, s) + tuple(rest), "plain"), pad=10 * f.k) for h, s, *rest in row]
            n = len(specs); full = (f.right - x0 - 16 * f.k * (per - 1)) / per
            x1 = x0 + full * n + 16 * f.k * (n - 1)
            bx = f.row(y, specs, x0=x0, x1=x1, gap=16 * f.k)
            bus = y - 20 * f.k
            if k == 0:
                f.line([(ob.cx, ob.b), (ob.cx, bus)], kind, nohead_ok=True)
                lo = min([b.cx for b in bx] + [ob.cx] + ([trunk_x] if multi else [])); hi = max([b.cx for b in bx] + [ob.cx])
            else:
                lo, hi = trunk_x, max(b.cx for b in bx)
                f.line([(trunk_x, prev_bus), (trunk_x, bus)], kind, nohead_ok=True)
            f.line([(lo, bus), (hi, bus)], kind, nohead_ok=True)
            for b in bx: f.line([(b.cx, bus), (b.cx, b.y - 0.75 * f.k)], kind, arrow=True, target=b)
            prev_bus = bus
            y = bx[0].b + 40 * f.k
        if note: f.note(note, gap=16)
        return f
    return fits(build)


# ---- 6. before / after (two states) ---------------------------------------------------------------------------
def two_state(title, alt, before, after, change=None, note=None):
    """Two states side by side and the change between them. before/after: (head, [items], tone).
    Items are short phrases (1..9 each); 6 or more are set compact, as quiet lines."""
    for side in (before, after):
        if not 1 <= len(side[1]) <= 9: raise Refused("1 to 9 items per state; more belongs in a table (matrix())")
    def build(v):
        f = Figure(title, alt, variant=v)
        gap = max(64 * f.k, (text_width(change, f.T["label"][0], 700) + 28 * f.k) if change else 0)
        if gap > 200 * f.k: raise Refused(f"the change label {change!r} is too long: one or two words, the rest in the caption")
        w = (f.w - 2 * f.MARGIN - gap) / 2
        def spec(s):
            many = len(s[1]) > 5
            return dict(head=s[0], tone=s[2] if len(s) > 2 else "plain", **({"sub": list(s[1])} if many else {"lines": list(s[1])}))
        a, b = spec(before), spec(after)
        H = max(f.measure_box(w, **{k: v for k, v in a.items() if k != "tone"}), f.measure_box(w, **{k: v for k, v in b.items() if k != "tone"}))
        A = f.box(f.MARGIN, f.top, w, H, **a); B = f.box(f.MARGIN + w + gap, f.top, w, H, **b)
        f.connect(A, B, kind="flow", at=A.y + 44 * f.k)
        if change:
            cw = gap - 8 * f.k
            if text_width(change, f.T["label"][0], 700) > cw: raise Refused(f"the change label {change!r} is wider than the gap: use one or two short words, or put it in the caption")
            f.text(A.r + gap / 2, A.y + 44 * f.k - f.CLEAR - 5 * f.k, change, "label", "middle", cls="ta")
        if note: f.note(note, gap=16)
        return f
    return fits(build)


# ---- 7. timeline -------------------------------------------------------------------------------------------------
def timeline(title, alt, events, note=None, today=None):
    """Dated events on one axis, labels alternating above and below so neighbours never collide.
    events: [(date, label)] in order, 2..9. today: index of the event to mark as the present (accent)."""
    n = len(events)
    if not 2 <= n <= 9: raise Refused("2 to 9 events; more is a table, or a timeline per period")
    def build(v):
        f = Figure(title, alt, variant=v)
        span = f.w - 2 * f.MARGIN
        pitch = span / n
        bw = min(2 * pitch - 20 * f.k, 230 * f.k) if n > 2 else min(pitch * 1.6, 300 * f.k)
        def block_h(lbl):
            return len(balanced_wrap(lbl, bw, f.T["body"][0])) * f.T["body"][2]
        up = max(block_h(lbl) for i, (_, lbl) in enumerate(events) if i % 2 == 0)
        ay = f.top + 24 * f.k + up + 22 * f.k
        f.line([(f.MARGIN, ay), (f.right, ay)], "neutral", nohead_ok=True)
        for i, (date, lbl) in enumerate(events):
            x = f.MARGIN + pitch * (i + 0.5)
            tone = "accent" if today == i else "line"
            f.raw(f'<circle cx="{fmt(x)}" cy="{fmt(ay)}" r="{fmt(6 * f.k)}" class="{FILL[tone]}"/>', Rect(x - 6 * f.k, ay - 6 * f.k, 12 * f.k, 12 * f.k), kind="disc")
            lines = balanced_wrap(lbl, bw, f.T["body"][0])
            if i % 2 == 0:
                top = ay - 22 * f.k - len(lines) * f.T["body"][2]
                f.text(x, top - 4 * f.k, date, "label", "middle", cls="ta" if today == i else "tq")
                for k, ln in enumerate(lines): f.text(x, top + f.T["body"][0] * ASC + 6 * f.k + k * f.T["body"][2], ln, "body", "middle")
            else:
                yy = ay + 22 * f.k + f.T["label"][0] * ASC
                f.text(x, yy, date, "label", "middle", cls="ta" if today == i else "tq")
                for k, ln in enumerate(lines): f.text(x, yy + 20 * f.k + k * f.T["body"][2], ln, "body", "middle")
        if note: f.note(note, gap=18)
        return f
    return fits(build)


# ---- 8. comparison matrix --------------------------------------------------------------------------------------
def matrix(title, alt, cols, rows, col_widths=None, note=None):
    """Options compared on attributes: a header row and one row per option. rows: [[row head, cell, ...]]; a cell
    is a string or dict(sub=..., tone=...). Status cells carry their word, never colour alone.
    Up to 7 rows (6-7 may need the tall variant); more, or long prose cells, belong in an HTML table."""
    if len(rows) > 7: raise Refused("more than 7 rows: use an HTML <table> (it reflows, stays searchable, and has no height budget)")
    def build(v):
        f = Figure(title, alt, variant=v)
        f.grid(f.top, cols, rows, col_widths=col_widths)
        if note: f.note(note, gap=16)
        return f
    return fits(build)


# ---- 9. stack / architecture tiers --------------------------------------------------------------------------------
def stack(title, alt, tiers, label_w=150, note=None):
    """Tiers top to bottom, each a band with its name at the left and its parts as chips that flow and wrap.
    tiers: [(name, [parts], tone)], 2..7 tiers, any number of parts per tier (chips wrap to new rows)."""
    if not 2 <= len(tiers) <= 7: raise Refused("2 to 7 tiers; split a deeper stack into two figures")
    def build(v):
        f = Figure(title, alt, variant=v)
        lw = label_w * f.k; y = f.top
        chip_h = round(10 * f.k * 2 + f.T["sub"][0] * 1.04)
        for name, parts, *rest in tiers:
            tone = rest[0] if rest else "panel"
            x0 = f.MARGIN + lw; xmax = f.right - 12 * f.k
            pos, x, row = [], x0, 0
            for p in parts:
                cw = text_width(p, f.T["sub"][0]) + 2 * f.PAD_X
                if cw > xmax - x0: raise Refused(f"part {p!r} is wider than its tier: shorten it")
                if x + cw > xmax: row += 1; x = x0
                pos.append((x, row, cw, p)); x += cw + 8 * f.k
            rows_ = row + 1
            nh = max(f.measure_box(lw - 12 * f.k, head=name), 0)
            h = max(rows_ * chip_h + (rows_ - 1) * 8 * f.k + 24 * f.k, nh)
            band = f.rect(Rect(f.MARGIN, y, f.w - 2 * f.MARGIN, h), TONE[tone][0], 8, kind="zone")
            f.text_block(f.MARGIN + f.PAD_X, y + 12 * f.k + f.T["head"][0] * ASC, name, "head", lw - f.PAD_X - 12 * f.k, balanced=True)
            for x, r_, cw, p in pos:
                cy = y + 12 * f.k + r_ * (chip_h + 8 * f.k)
                f.rect(Rect(x, cy, cw, chip_h), "bx", 6)
                f.text(x + f.PAD_X, cy + 10 * f.k + f.T["sub"][0] * ASC, p, "sub", cls="t")
            y = band.b + 8 * f.k
        if note: f.note(note, gap=16)
        return f
    return fits(build)


# ---- 10. map with callouts ---------------------------------------------------------------------------------------
def _blob(cx, cy, rx, ry, seed=3, k=24):
    pts = []
    for i in range(k):
        a = 2 * math.pi * i / k
        w = 1 + 0.10 * math.sin(3 * a + seed) + 0.06 * math.sin(5 * a + 2 * seed)
        pts.append((cx + rx * w * math.cos(a), cy + ry * w * math.sin(a)))
    d = f"M{fmt(pts[0][0])} {fmt(pts[0][1])}"
    for i in range(k):            # smooth closed curve through the points (Catmull-Rom as cubic Beziers)
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % k], pts[(i + 2) % k]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6); c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{fmt(c1[0])} {fmt(c1[1])} {fmt(c2[0])} {fmt(c2[1])} {fmt(p2[0])} {fmt(p2[1])}"
    return d + "z"


def map_callouts(title, alt, points, region_path=None, note=None):
    """A schematic area with numbered markers and the callouts as a numbered list beside it (the numbered-marker
    practice; never labels over a raster basemap, which collided with its printed names: record F14).
    points: [(x, y, label)] with x, y in 0..1 of the map area, 1..9 points. region_path: SVG path data in the
    map's own 0..1 box scaled to the area, or None for a neutral schematic outline."""
    if not 1 <= len(points) <= 9: raise Refused("1 to 9 markers; more needs a table keyed to the map")
    def build(v):
        f = Figure(title, alt, variant=v)
        mw, mh = 400 * f.k, 220 * f.k
        m = Rect(f.MARGIN, f.top, mw, mh)
        d = region_path or _blob(m.cx, m.cy, mw * 0.43, mh * 0.40)
        f.items.append(("svg", f'<path d="{d}" class="bxp" data-lint="nohead"/>', f.group))
        order = sorted(range(len(points)), key=lambda i: (points[i][1], points[i][0]))
        r = 12 * f.k
        P = [(m.x + points[i][0] * mw, m.y + points[i][1] * mh) for i in order]
        for a in range(len(P)):
            for b in range(a + 1, len(P)):
                if math.hypot(P[a][0] - P[b][0], P[a][1] - P[b][1]) < 2 * r + 6 * f.k:
                    raise Refused(f"markers {a + 1} and {b + 1} collide: merge them, or add an inset for that area")
        for k, (x, y) in enumerate(P): f.disc(x, y, k + 1, r=r)
        lx = m.r + 30 * f.k; lw = f.right - lx - 2 * r - 10 * f.k
        y = f.top + r
        for k, i in enumerate(order):
            f.disc(lx + r, y, k + 1, r=r)
            last = f.text_block(lx + 2 * r + 10 * f.k, y + 5 * f.k, points[i][2], "body", lw, balanced=True)
            y = max(y + 2 * r + 6 * f.k, last + f.T["body"][2] * 0.5 + r)
        f.bottom = max(f.bottom, m.b)
        if note: f.note(note, gap=16)
        return f
    return fits(build)


# ---- 11. small multiples -------------------------------------------------------------------------------------
def small_multiples(title, alt, panels, source, asof, kind="bar", y_max=None, cols=None, xlabels=None, note=None, last_label=None):
    """One small chart per category on ONE shared scale, so the panels compare at a glance (Tufte).
    panels: {name: [values]}; kind 'bar' or 'line'. 2..9 panels: one row up to 3, then 3 per row, then 5 per row."""
    n = len(panels)
    if not 2 <= n <= 9: raise Refused("2 to 9 panels; more needs a heatmap or a table")
    allv = [v for vs in panels.values() for v in vs]
    ys = Scale(0, y_max or max(allv), ticks=2)            # one scale for every panel: comparisons stay honest
    def build(v):
        f = Figure(title, alt, variant=v)
        c = cols or (n if n <= 3 else 3 if n <= 6 else 5); rws = math.ceil(n / c)
        gx = 28 * f.k; pw = (f.w - 2 * f.MARGIN - 34 * f.k - gx * (c - 1)) / c; ph = (92 if rws == 1 else 76) * f.k
        for name, vals in panels.items():
            if text_width(name, f.T["head"][0], 700) + (text_width(last_label.format(num(vals[-1])), f.T["label"][0], 700) + 12 * f.k if last_label else 0) > pw:
                raise Refused(f"panel name {name!r} does not fit its panel: shorten it")
        y = f.top
        for k, (name, vals) in enumerate(panels.items()):
            r_, c_ = divmod(k, c)
            x = f.MARGIN + 34 * f.k + c_ * (pw + gx); yy = f.top + r_ * (ph + 58 * f.k)
            f.text(x, yy + f.T["head"][0] * ASC, name, "head")
            area = Rect(x, yy + 26 * f.k, pw, ph)
            ch = Chart(f, area, x=Scale(0, max(1, len(vals) - 1), nice=False), y=ys, kind=kind, source=source, asof=asof)
            if c_ == 0:
                for t in (ys.lo, ys.hi): f.text(x - 8 * f.k, ch.py(t) + 4.5 * f.k, num(t), "sub", "end")
            f.line([(x, ch.py(ys.hi)), (x + pw, ch.py(ys.hi))], "rule", nohead_ok=True)
            f.line([(x, area.b), (x + pw, area.b)], "neutral", nohead_ok=True)
            if kind == "bar":
                m = len(vals); slot = pw / m; bw = slot * 0.62
                for i, val in enumerate(vals):
                    bx = x + slot * i + (slot - bw) / 2; y0, y1 = ch.py(0), ch.py(val)
                    f.raw(f'<rect x="{fmt(bx)}" y="{fmt(y1)}" width="{fmt(bw)}" height="{fmt(y0 - y1)}" class="fa"/>')
            else:
                pts = [(x + pw * i / max(1, len(vals) - 1), ch.py(val)) for i, val in enumerate(vals)]
                f.line(pts, "flow", nohead_ok=True)
            if last_label:      # e.g. last_label="{} today": a bare number beside a name is ambiguous
                f.text(x + pw, yy + f.T["head"][0] * ASC, last_label.format(num(vals[-1])), "label", "end", cls="ta")
            if xlabels and r_ == rws - 1:
                f.text(x, area.b + 8 * f.k + f.T["sub"][0] * ASC, xlabels[0], "sub")
                f.text(x + pw, area.b + 8 * f.k + f.T["sub"][0] * ASC, xlabels[-1], "sub", "end")
        f.note((note + " " if note else "") + f"Source: {source}. As of {asof}. All panels share one scale.", gap=18)
        return f
    return fits(build)


# ---- 12. annotated chart -----------------------------------------------------------------------------------------
def annotated_chart(title, alt, series, source, asof, annotate=None, xlabel=None, ylabel=None, zero_reason=None, kinds=None, label_w=150):
    """A line chart whose finding is written on it: series labelled at their ends (dodged, no legend) and one
    annotation on the point that matters. series: {label: [(x, y)]}, 1..9 series."""
    if not 1 <= len(series) <= 9: raise Refused("1 to 9 series; more needs small_multiples()")
    xs = [x for p in series.values() for x, _ in p]; ys_ = [y for p in series.values() for _, y in p]
    def build(v):
        f = Figure(title, alt, variant=v)
        lw = max(text_width(k, f.T["label"][0], 700) for k in series) + 14 * f.k
        if lw > label_w * f.k * 1.6: raise Refused("series labels are too long to sit at the line ends: shorten them")
        r = Rect(f.MARGIN + 52 * f.k, f.top + 18 * f.k, f.w - 2 * f.MARGIN - 52 * f.k - lw, 140 * f.k)
        ys = Scale(0 if zero_reason is None else min(ys_), max(ys_))
        c = Chart(f, r, x=Scale(min(xs), max(xs), nice=False), y=ys, source=source, asof=asof, zero_reason=zero_reason)
        c.axes(xlabel=xlabel, ylabel=ylabel, xticks=sorted(set([min(xs), max(xs)] + [t for t in Scale(min(xs), max(xs)).ticks() if min(xs) <= t <= max(xs)])))
        kinds_ = kinds or {}
        # up to 3 series get distinct roles; beyond that, highlight the first and grey the rest (dataviz: one
        # emphasis, not a rainbow). Crit is never a series colour: it means hazard.
        palette = ["flow", "warn", "good"] if len(series) <= 3 else ["flow"] + ["neutral"] * 8
        for i, (k, pts) in enumerate(series.items()): c.line(pts, k, kind=kinds_.get(k, palette[i]))
        if annotate: c.annotate(*annotate)
        c.finish()
        return f
    return fits(build)
