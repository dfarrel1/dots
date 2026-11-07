#!/usr/bin/env python3
"""tokens.py: create, adapt and validate design-system tokens for figures. Stdlib only.

Every figure colour is one of a fixed set of ROLES (below). A design system is usable for figures when each
role maps to one of its tokens and every role pair a figure uses passes contrast in light, dark and print.

  python3 tokens.py check  <file.css> [--map map.json] [--waive fg/bg ...]
                                                                  contrast of every role pair, light/dark/print; exit 1 on a failure.
                                                                  --waive only for a pair the deliverable never draws, with the reason recorded
                                                                  --complete derives roles the system lacks (as adapt does)
  python3 tokens.py generate <spec.json> [-o tokens.css] [--fix]  write a role token file; --fix nudges failing colours until they pass
  python3 tokens.py detect <path>                                 find a provided system and propose a role map (review it by hand)
  python3 tokens.py adapt <their.css> --map map.json [-o roles.css] write role tokens as var() references to their tokens

Why measured, not chosen by eye: record F4 (three light status colours at 4.20-4.54:1, a literal #fff at
2.12:1 in dark, links at 1.6:1, tokens referenced but defined nowhere). Print is checked separately because a
print block that overrides selectors instead of tokens printed a name near-white on white.
"""
import json, math, os, re, sys

ROLES = ["ink", "quiet", "rule", "line", "paper", "panel", "accent", "accent-soft", "on-accent",
         "good", "good-bg", "warn", "warn-bg", "info", "info-bg", "crit", "crit-bg", "mute", "mute-bg"]
# (foreground, background, used for, bar): text 4.5:1; graphics (outlines, arrows) 3:1 (WCAG 1.4.11)
PAIRS = [
    ("ink", "paper", "body text, figure labels", 4.5), ("quiet", "paper", "captions, notes, sub-labels", 4.5),
    ("ink", "panel", "text on panels", 4.5), ("quiet", "panel", "quiet text on panels", 4.5),
    ("accent", "paper", "accent text, links", 4.5), ("accent", "accent-soft", "accent text in accent boxes", 4.5),
    ("ink", "accent-soft", "text in accent boxes", 4.5), ("quiet", "accent-soft", "quiet text in accent boxes", 4.5),
    ("on-accent", "accent", "numerals on accent discs, Play button", 4.5),
    ("good", "good-bg", "good box heading", 4.5), ("warn", "warn-bg", "warn box heading", 4.5),
    ("info", "info-bg", "info box heading", 4.5), ("crit", "crit-bg", "hazard box heading", 4.5),
    ("mute", "mute-bg", "mute box heading", 4.5),
    ("ink", "good-bg", "text in good boxes", 4.5), ("ink", "warn-bg", "text in warn boxes", 4.5),
    ("ink", "info-bg", "text in info boxes", 4.5), ("ink", "crit-bg", "text in hazard boxes", 4.5),
    ("ink", "mute-bg", "text in mute boxes", 4.5), ("quiet", "good-bg", "quiet text in good boxes", 4.5),
    ("quiet", "warn-bg", "quiet text in warn boxes", 4.5), ("quiet", "mute-bg", "quiet text in mute boxes", 4.5),
    ("good", "paper", "good text on paper", 4.5), ("warn", "paper", "warn text on paper", 4.5),
    ("info", "paper", "info text on paper", 4.5), ("crit", "paper", "crit text on paper", 4.5),
    ("mute", "paper", "mute text on paper", 4.5), ("on-accent", "good", "numerals on good discs", 4.5),
    ("line", "paper", "box outlines, neutral connectors (graphic)", 3.0), ("line", "panel", "outlines on panels (graphic)", 3.0),
    ("accent", "panel", "flow arrows on panels (graphic)", 3.0),
]

# ---- colour ------------------------------------------------------------------------------------------------
NAMED = {"white": "#ffffff", "black": "#000000", "transparent": None}


def parse_color(v):
    v = v.strip().lower()
    if v in NAMED: return None if NAMED[v] is None else parse_color(NAMED[v])
    m = re.fullmatch(r"#([0-9a-f]{3,8})", v)
    if m:
        h = m.group(1)
        if len(h) in (3, 4): h = "".join(c * 2 for c in h[:3])
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    m = re.fullmatch(r"rgba?\(([^)]+)\)", v)
    if m:
        p = re.split(r"[,\s/]+", m.group(1).strip())
        return tuple(round(float(x[:-1]) * 2.55) if x.endswith("%") else round(float(x)) for x in p[:3])
    m = re.fullmatch(r"hsla?\(([^)]+)\)", v)
    if m:
        p = re.split(r"[,\s/]+", m.group(1).strip())
        h, s, l = float(p[0].rstrip("deg")), float(p[1].rstrip("%")) / 100, float(p[2].rstrip("%")) / 100
        return tuple(round(255 * c) for c in _hsl_rgb(h / 360, s, l))
    return None


def _hsl_rgb(h, s, l):
    def f(p, q, t):
        t %= 1
        return p + (q - p) * 6 * t if t < 1 / 6 else q if t < 1 / 2 else p + (q - p) * (2 / 3 - t) * 6 if t < 2 / 3 else p
    if s == 0: return (l, l, l)
    q = l * (1 + s) if l < .5 else l + s - l * s; p = 2 * l - q
    return (f(p, q, h + 1 / 3), f(p, q, h), f(p, q, h - 1 / 3))


def hexc(rgb): return "#%02x%02x%02x" % tuple(max(0, min(255, round(c))) for c in rgb)


def lum(rgb):
    c = [x / 255 for x in rgb]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def ratio(a, b):
    A, B = lum(a), lum(b); return (max(A, B) + 0.05) / (min(A, B) + 0.05)

# ---- CSS parsing -------------------------------------------------------------------------------------------


def _blocks(css):
    """Yield (context, selector, body) for every rule, with context = enclosing @media prelude or ''."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    i, n, stack = 0, len(css), []
    sel_start = 0
    while i < n:
        ch = css[i]
        if ch == "{":
            prelude = css[sel_start:i].strip()
            if prelude.startswith("@"):
                stack.append(prelude); sel_start = i + 1
            else:
                j = css.index("}", i)
                yield (" ".join(stack), prelude, css[i + 1:j])
                i = j; sel_start = j + 1
        elif ch == "}":
            if stack: stack.pop()
            sel_start = i + 1
        elif ch == ";" and not stack:
            sel_start = i + 1
        i += 1


def themes_from_css(css):
    """Return {'light': {...}, 'dark': {...}, 'print': {...}} of custom properties (raw values)."""
    light, dark, prt = {}, {}, {}
    for ctx, sel, body in _blocks(css):
        props = dict((k.strip(), v.strip()) for k, v in re.findall(r"(--[\w-]+)\s*:\s*([^;]+)", body))
        if not props: continue
        s = sel.replace(" ", "")
        is_dark = "dark" in ctx or re.search(r"data-theme=\"?dark|\.dark\b|\.theme-dark", s)
        is_light_forced = re.search(r"data-theme=\"?light|\.light\b", s)
        if "print" in ctx: prt.update(props)
        elif is_dark: dark.update(props)
        elif is_light_forced: light.update({k: v for k, v in props.items() if k not in light})
        elif ctx == "" or "screen" in ctx: light.update(props)
    return {"light": light, "dark": {**light, **dark}, "print": {**light, **prt}}


def _oklab(rgb):
    lin = [(c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4 for c in rgb]
    r, g, b = lin
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s_ = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s_, 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s_, 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s_)


def _from_oklab(L, a, b):
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3; m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3; s_ = (L - 0.0894841775 * a - 1.291485548 * b) ** 3
    lin = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s_, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s_, -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s_)
    return tuple(max(0, min(255, 255 * (12.92 * c if c <= 0.0031308 else 1.055 * max(c, 0) ** (1 / 2.4) - 0.055))) for c in lin)


def mix_oklab(a, b, p):
    """p = share of a (0..1), as CSS color-mix(in oklab, a p%, b)."""
    A, B = _oklab(a), _oklab(b)
    return _from_oklab(*[x * p + y * (1 - p) for x, y in zip(A, B)])


def resolve(props, name, depth=0):
    if depth > 12 or name not in props: return None
    v = props[name]
    mm = re.fullmatch(r"color-mix\(\s*in oklab\s*,\s*(.+?)\s+([\d.]+)%\s*,\s*(.+?)\s*\)", v.strip())
    if mm:
        def one(x):
            x = x.strip(); vm = re.fullmatch(r"var\(\s*(--[\w-]+)\s*\)", x)
            return resolve(props, vm.group(1), depth + 1) if vm else parse_color(x)
        a, b = one(mm.group(1)), one(mm.group(3))
        return tuple(round(c) for c in mix_oklab(a, b, float(mm.group(2)) / 100)) if a and b else None
    m = re.fullmatch(r"var\(\s*(--[\w-]+)\s*(?:,\s*(.+))?\)", v.strip())
    if m:
        r = resolve(props, m.group(1), depth + 1)
        return r if r is not None else (parse_color(m.group(2)) if m.group(2) else None)
    return parse_color(v)


def role_colors(css, mapping=None):
    th = themes_from_css(css)
    out, missing = {}, set()
    for t, props in th.items():
        out[t] = {}
        for role in ROLES:
            src = (mapping or {}).get(role, "--" + role)
            if src.startswith(("color-mix", "var(")):
                c = resolve({**props, "--__tmp": src}, "--__tmp")
            else:
                c = parse_color(src) if not src.startswith("--") else resolve(props, src)
            if c is None: missing.add(f"{role} ({src})")
            out[t][role] = c
    return out, sorted(missing)


def check(css, mapping=None, md=False, quiet=False, waive=()):
    """waive: 'fg/bg' pairs the deliverable never uses, as a declared deviation (write the reason down)."""
    cols, missing = role_colors(css, mapping)
    bad, rows = 0, []
    for fg, bg, use, bar in PAIRS:
        vals = []
        for t in ("light", "dark", "print"):
            a, b = cols[t].get(fg), cols[t].get(bg)
            vals.append(ratio(a, b) if a and b else None)
        present = [v for v in vals if v is not None]
        if not present: continue
        fail = min(present) < bar
        if fail and f"{fg}/{bg}" in waive: fail = "waived"
        bad += fail is True
        rows.append((fg, bg, use, vals, bar, fail))
    if not quiet:
        print("| Foreground on background | Used for | Light | Dark | Print | Bar |\n|---|---|---|---|---|---|")
        for fg, bg, use, vals, bar, fail in rows:
            v = " | ".join("n/a" if x is None else f"{x:.2f}" for x in vals)
            print(f"| `{fg}` on `{bg}` | {use} | {v} | {bar:g}:1{' **FAIL**' if fail is True else (' WAIVED (declared deviation: this pair is not used)' if fail else '')} |")
        if missing: print(f"\nRoles with no resolvable colour: {', '.join(missing)}. Map them (--map) or the figure classes that use them fall back to nothing.")
        print(f"\ntokens: {len(rows)} pairs checked in light, dark and print, {bad} failing")
    return bad, missing

# ---- generate ----------------------------------------------------------------------------------------------


def _nudge(rgb, toward_dark, step=0.03):
    # move lightness in HSL, keeping hue and saturation, so the colour keeps its meaning
    r, g, b = [x / 255 for x in rgb]
    mx, mn = max(r, g, b), min(r, g, b); l = (mx + mn) / 2
    d = mx - mn
    s = 0 if d == 0 else d / (1 - abs(2 * l - 1))
    if d == 0: h = 0
    elif mx == r: h = ((g - b) / d) % 6
    elif mx == g: h = (b - r) / d + 2
    else: h = (r - g) / d + 4
    h /= 6
    l = max(0, min(1, l - step if toward_dark else l + step))
    return tuple(255 * c for c in _hsl_rgb(h, s, l))


def fix_theme(theme, dark):
    """Nudge every failing FOREGROUND until all its pairs pass. Backgrounds are never moved."""
    changes = []
    for _ in range(60):
        moved = False
        for fg, bg, use, bar in PAIRS:
            a, b = theme.get(fg), theme.get(bg)
            if not a or not b or ratio(parse_color(a), parse_color(b)) >= bar: continue
            new = hexc(_nudge(parse_color(a), toward_dark=not dark))
            if fg in ("on-accent",): new = hexc(_nudge(parse_color(a), toward_dark=dark))
            changes.append((fg, a, new)); theme[fg] = new; moved = True
        if not moved: break
    return changes


def css_block(sel, vals, extra=""):
    body = " ".join(f"--{k}:{v};" for k, v in vals.items())
    return f"{sel} {{ {body}{extra} }}\n"


def generate(spec, fix=False):
    light, dark = dict(spec["light"]), dict(spec["dark"])
    if fix:
        for name, th, dk in (("light", light, False), ("dark", dark, True)):
            for fg, a, b in fix_theme(th, dk): print(f"  fixed {name} --{fg}: {a} -> {b}", file=sys.stderr)
    font = spec.get("font", '"Helvetica Neue", Helvetica, Arial, "Liberation Sans", sans-serif')
    mono = spec.get("mono", 'Menlo, Consolas, "Courier New", monospace')
    fonts = {"font": font, "mono": mono}
    out = [f"/* {spec.get('name', 'tokens')}: role tokens for figures and pages. Generated by tokens.py; edit the spec, not this block. */\n",
           css_block(":root", {**light, **fonts}, " color-scheme: light;"),
           "@media (prefers-color-scheme: dark) {\n  " + css_block(':root:not([data-theme="light"])', dark, " color-scheme: dark;") + "}\n",
           css_block('[data-theme="light"]', light, " color-scheme: light;"),
           css_block(':root[data-theme="dark"], [data-theme="dark"]', dark, " color-scheme: dark;"),
           "/* Print is always the light theme, set on tokens (never by overriding selectors: record F4, F16). */\n",
           "@media print {\n  " + css_block(":root, :root:not([data-theme]), [data-theme]", light, " color-scheme: light;") + "}\n"]
    return "".join(out)

# ---- detect and adapt ---------------------------------------------------------------------------------------
HINTS = {
    "ink": ["ink", "text", "fg", "foreground", "body-color", "color-text", "text-primary", "on-surface", "on-background"],
    "quiet": ["quiet", "muted", "text-secondary", "secondary-text", "subtle", "fg-muted", "text-muted", "ink2", "ink-2"],
    "rule": ["rule", "border", "divider", "hairline", "outline-variant"],
    "line": ["line", "stroke", "border-strong", "outline"],
    "paper": ["paper", "bg", "background", "surface", "canvas", "page"],
    "panel": ["panel", "surface-2", "bg-subtle", "card", "surface-variant", "bg-alt", "surface"],
    "accent": ["accent", "primary", "brand", "link"],
    "accent-soft": ["accent-soft", "primary-soft", "accent-bg", "primary-container", "brand-soft"],
    "on-accent": ["on-accent", "on-primary", "accent-contrast", "primary-contrast"],
    "good": ["good", "success", "ok", "positive", "green"], "warn": ["warn", "warning", "caution", "amber"],
    "info": ["info", "notice", "blue"], "crit": ["crit", "danger", "error", "critical", "negative", "red"],
    "mute": ["mute", "disabled", "inactive", "neutral"],
}


def propose(css):
    names = list(themes_from_css(css)["light"].keys())
    out = {}
    for role in ROLES:
        base = role.replace("-bg", "")
        for h in HINTS.get(role, []) + (([f"{b}-bg" for b in HINTS.get(base, [])] + [f"{b}-soft" for b in HINTS.get(base, [])]) if role.endswith("-bg") else []):
            hit = [n for n in names if n.lstrip("-") == h] or [n for n in names if n.lstrip("-").endswith("-" + h) or n.lstrip("-").startswith(h + "-")]
            if role.endswith("-bg"):
                hit = [n for n in names if n.lstrip("-") in (f"{h}",)] or hit
            hit = [x for x in hit if x not in out.values()]      # one token, one role
            if hit: out[role] = hit[0]; break
    return out


def detect(path):
    cands = []
    for root, dirs, files in os.walk(path) if os.path.isdir(path) else [(os.path.dirname(path), [], [os.path.basename(path)])]:
        dirs[:] = [d for d in dirs if d not in ("node_modules", ".git", "dist", "out")]
        for f in files:
            p = os.path.join(root, f)
            if f.endswith(".css"):
                try: n = len(re.findall(r"--[\w-]+\s*:", open(p, errors="ignore").read()))
                except OSError: continue
                if n >= 6: cands.append((n, p))
            elif re.search(r"(design[-_ ]?system|tokens|brand|style[-_]?guide)", f, re.I) and f.endswith((".md", ".json")):
                cands.append((0, p))
    cands.sort(reverse=True)
    if not cands: print("no design system found under", path); return 1
    print("Candidate design-system files (most custom properties first):")
    for n, p in cands[:12]: print(f"  {p}" + (f"  ({n} custom properties)" if n else "  (document: read it as canon)"))
    css_files = [p for n, p in cands if n]
    if css_files:
        css = open(css_files[0]).read()
        print(f"\nProposed role map for {css_files[0]} (check every line by hand; save as map.json):")
        print(json.dumps(propose(css), indent=1))
    return 0


# Roles a provided system often lacks, derived from the roles it has (CSS color-mix in OKLab, so the derived
# colour follows the provided system's own light and dark values). (role, expression over other roles)
DERIVE = {
    "line": "color-mix(in oklab, var(ink) 52%, var(paper))", "panel": "color-mix(in oklab, var(ink) 4%, var(paper))",
    "rule": "color-mix(in oklab, var(ink) 14%, var(paper))", "quiet": "color-mix(in oklab, var(ink) 70%, var(paper))",
    "accent-soft": "color-mix(in oklab, var(accent) 7%, var(paper))", "on-accent": "var(paper)",
    "info": "var(accent)", "mute": "var(quiet)",
    "good-bg": "color-mix(in oklab, var(good) 7%, var(paper))", "warn-bg": "color-mix(in oklab, var(warn) 7%, var(paper))",
    "info-bg": "color-mix(in oklab, var(info) 7%, var(paper))", "crit-bg": "color-mix(in oklab, var(crit) 7%, var(paper))",
    "mute-bg": "color-mix(in oklab, var(mute) 10%, var(paper))",
    "good": "var(ink)", "warn": "var(ink)", "crit": "var(ink)",
}


def complete(mapping):
    """Fill roles the provided system lacks with derived expressions over the roles it has. Returns
    (full mapping, list of derived roles). Derived roles are declared deviations: say so in the deliverable."""
    full, derived = dict(mapping), []
    for _ in range(4):
        for role in ROLES:
            if role in full or role not in DERIVE: continue
            expr = DERIVE[role]
            deps = re.findall(r"var\(([\w-]+)\)", expr)
            if all(d in full for d in deps):
                for d in deps:
                    src = full[d]
                    expr = expr.replace(f"var({d})", f"var({src})" if src.startswith("--") else src)
                full[role] = expr; derived.append(role)
    return full, derived


def adapt(css, mapping):
    mapping, derived = complete(mapping)
    lines = [f"  --{role}: var({src});" if src.startswith("--") else f"  --{role}: {src};"
             for role, src in mapping.items() if src != "--" + role]   # same name: their token already is the role
    if derived: lines.append(f"  /* derived (declared deviation, not in the provided system): {', '.join(derived)} */")
    body = "\n".join(lines)
    return ("/* Role tokens adapted from a provided design system (tokens.py adapt). Defined on the figure itself so\n"
            "   they follow whichever theme the provided system applies to the element. */\n"
            f":root, svg.viz, .viz-root {{\n{body}\n}}\n")


def main(argv):
    if len(argv) < 2: print(__doc__); return 2
    cmd, arg = argv[0], argv[1]
    opt = lambda k: argv[argv.index(k) + 1] if k in argv else None
    mapping = json.load(open(opt("--map"))) if opt("--map") else None
    if cmd == "check":
        waive = [argv[i + 1] for i, a in enumerate(argv) if a == "--waive"]
        if mapping and "--complete" in argv:
            mapping, derived = complete(mapping)
            if derived: print(f"derived roles (declared deviations): {', '.join(derived)}")
        bad, missing = check(open(arg).read(), mapping, waive=waive)
        return 1 if bad else 0
    if cmd == "generate":
        css = generate(json.load(open(arg)), fix="--fix" in argv)
        if opt("-o"): open(opt("-o"), "w").write(css); print("wrote", opt("-o"), file=sys.stderr)
        else: print(css)
        bad, _ = check(css, quiet=True)
        if bad: print(f"{bad} pairs still fail; run with --fix or change the spec", file=sys.stderr); return 1
        return 0
    if cmd == "detect": return detect(arg)
    if cmd == "adapt":
        if not mapping: print("adapt needs --map map.json"); return 2
        out = adapt(open(arg).read(), mapping)
        if opt("-o"): open(opt("-o"), "w").write(out)
        else: print(out)
        return 0
    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
