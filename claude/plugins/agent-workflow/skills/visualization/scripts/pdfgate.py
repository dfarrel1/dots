#!/usr/bin/env python3
"""pdfgate: build a PDF with headless Chrome (optional) and check it the way a reader sees it. Stdlib + poppler.

  python3 pdfgate.py check doc.pdf [--pages N] [--max-gap 0.40] [--size letter|a4] [--body-pt H] [--allow-gap P ...]
  python3 pdfgate.py build page.html -o doc.pdf [--pages N] ...     (build with Chrome, then check)

Checks (each from a recorded failure; references/print-and-pdf.md):
  type3       ANY Type 3 font, counted from pdffonts' type column, never matched by font name. Text set in one
              copies out as unreadable codepoints (record F15: 304 and 270 Type 3 fonts in two circulated PDFs).
  pages       page count equals --pages when given (record: a one-pager that printed on two pages).
  geometry    every page the same size, and the size --size names. Chrome's silent shrink-to-fit (record F5)
              scales the WHOLE document, so pages agree with each other: pin --body-pt from a known-good
              build (the gate prints the measured value), and run figlint on the HTML, whose print-too-wide
              check catches the cause before printing. (A per-page comparison was tried and dropped: a page
              of figure labels reads as "smaller text" and fired falsely on the first explainer PDF.)
  blank       a non-final page with under 1 % ink.
  gap         a non-final page whose bottom 40 % or more is empty (a break-inside:avoid block moved whole).
              0.40 was calibrated on 141 pages: worst legitimate 38 %, defects 58-81 % (record W19).
              Raise it only for a figure-plate document, by name, against a fresh measurement.
  punct       a line that starts with punctuation (an orphaned full stop or comma).
Exit 1 on any failure. Missing tools make it exit 2 and say so: a missing tool must never read as a pass.
"""
import os, re, shutil, signal, subprocess, sys, tempfile, time, statistics, collections

SIZES = {"letter": (612, 792), "a4": (595.3, 841.9)}


def need(*tools):
    miss = [t for t in tools if not shutil.which(t)]
    if miss:
        print(f"pdfgate: {', '.join(miss)} not installed (poppler: brew install poppler / apt install poppler-utils). NOT CHECKED.", file=sys.stderr)
        sys.exit(2)


def find_chrome():
    for p in [os.environ.get("CHROME"), "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
              "/Applications/Chromium.app/Contents/MacOS/Chromium", shutil.which("google-chrome"),
              shutil.which("chromium"), shutil.which("chromium-browser"), shutil.which("chrome")]:
        if p and os.path.exists(p): return p
    print("pdfgate: Chrome not found; set CHROME=/path/to/chrome", file=sys.stderr); sys.exit(2)


def build(html, pdf, timeout=120):
    """Chrome --print-to-pdf with a fresh profile, a hard timeout, and a freshness check: Chrome can write the
    PDF and then hang on exit, or hang before writing and leave a stale PDF that looks current (record F19)."""
    chrome = find_chrome()
    start = time.time()
    prof = tempfile.mkdtemp(prefix="pdfgate-profile-")
    args = [chrome, "--headless=new", "--disable-gpu", "--no-first-run", "--no-pdf-header-footer",
            "--run-all-compositor-stages-before-draw", "--virtual-time-budget=4000",
            f"--user-data-dir={prof}", f"--print-to-pdf={pdf}", "file://" + os.path.abspath(html)]
    p = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    t0 = time.time()
    while p.poll() is None and time.time() - t0 < timeout:
        if os.path.exists(pdf) and os.path.getmtime(pdf) >= start and os.path.getsize(pdf) > 0:
            time.sleep(1.5)          # let it finish writing, then stop waiting for a clean exit
            if p.poll() is None:
                try: os.killpg(p.pid, signal.SIGTERM)
                except ProcessLookupError: pass
            break
        time.sleep(0.25)
    if p.poll() is None:
        try: os.killpg(p.pid, signal.SIGKILL)
        except ProcessLookupError: pass
    shutil.rmtree(prof, ignore_errors=True)
    if not os.path.exists(pdf) or os.path.getmtime(pdf) < start:
        print(f"pdfgate: Chrome did not write a fresh {pdf} within {timeout}s", file=sys.stderr); sys.exit(1)
    print(f"built {pdf} ({os.path.getsize(pdf) // 1024} KB) in {time.time() - start:.1f}s")


def read_pgm(path):
    with open(path, "rb") as f: data = f.read()
    parts, i = [], 0
    while len(parts) < 4:       # P5 header: magic, width, height, maxval (with optional comments)
        while data[i:i + 1].isspace(): i += 1
        if data[i:i + 1] == b"#":
            while data[i:i + 1] not in (b"\n", b""): i += 1
            continue
        j = i
        while not data[j:j + 1].isspace(): j += 1
        parts.append(data[i:j]); i = j
    i += 1
    w, h = int(parts[1]), int(parts[2])
    return w, h, data[i:i + w * h]


def check(pdf, pages=None, max_gap=0.40, size=None, allow_gap=(), body_pt=None):
    need("pdffonts", "pdfinfo", "pdftoppm", "pdftotext")
    fail, warn = [], []
    # fonts
    out = subprocess.run(["pdffonts", pdf], capture_output=True, text=True).stdout.splitlines()
    t3 = [l for l in out[2:] if re.search(r"\bType 3\b", l)]
    nfonts = len(out[2:])
    if t3: fail.append(f"type3: {len(t3)} Type 3 font(s) of {nfonts}; text in them copies out as garbage. Replace the glyph (arrows, ticks, circled numerals fall back to system faces) or the font.")
    # pages and geometry
    info = subprocess.run(["pdfinfo", "-l", "9999", pdf], capture_output=True, text=True).stdout
    n = int(re.search(r"Pages:\s+(\d+)", info).group(1))
    if pages and n != pages: fail.append(f"pages: {n} pages, expected {pages}")
    psizes = [(float(a), float(b)) for a, b in re.findall(r"Page\s+\d+ size:\s+([\d.]+) x ([\d.]+)", info)] or \
             [tuple(map(float, re.search(r"Page size:\s+([\d.]+) x ([\d.]+)", info).groups()))]
    if len(set((round(a), round(b)) for a, b in psizes)) > 1: fail.append(f"geometry: mixed page sizes {sorted(set(psizes))}")
    if size and any(abs(a - SIZES[size][0]) > 2 or abs(b - SIZES[size][1]) > 2 for a, b in psizes):
        fail.append(f"geometry: page size {psizes[0]} is not {size} {SIZES[size]}")
    # body text size per page (word box heights): a page set noticeably smaller than the rest was shrunk
    bb = subprocess.run(["pdftotext", "-bbox", pdf, "-"], capture_output=True, text=True).stdout
    modes = []
    for pg in bb.split("<page ")[1:]:
        hs = [round(float(b) - float(a), 1) for a, b in re.findall(r'yMin="([\d.]+)" xMax="[\d.]+" yMax="([\d.]+)"', pg)]
        modes.append(collections.Counter(hs).most_common(1)[0][0] if hs else None)
    known = [m for m in modes if m]
    if len(known) >= 2:
        doc = statistics.median(known)
        # Chrome shrinks the WHOLE document when one element is too wide, so pages agree with each other and
        # only an absolute reference catches it: pin --body-pt to the value printed on a known-good build.
        if body_pt and abs(doc - body_pt) / body_pt > 0.05:
            fail.append(f"geometry: body text is {doc:.1f}pt high, expected {body_pt:.1f}pt: the whole document was scaled (shrink-to-fit)")
        print(f"  body text box height {doc:.1f}pt (pin it with --body-pt {doc:.1f})")
    # ink: blank pages and bottom gaps
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["pdftoppm", "-r", "36", "-gray", pdf, f"{tmp}/p"], check=True)
        files = sorted(f for f in os.listdir(tmp) if f.endswith(".pgm"))
        for i, fn in enumerate(files, 1):
            w, h, px = read_pgm(os.path.join(tmp, fn))
            dark = sum(1 for k in range(0, len(px), 2) if px[k] < 200)
            ink = dark / (len(px) / 2)
            last = 0
            for y in range(h - 1, -1, -1):
                row = px[y * w:(y + 1) * w]
                if any(v < 200 for v in row[::2]): last = y; break
            gap = (h - last) / h
            if i == len(files): continue
            if ink < 0.01: fail.append(f"blank: page {i} has {ink * 100:.1f}% ink")
            elif gap > max_gap and i not in allow_gap: fail.append(f"gap: page {i} is {gap * 100:.0f}% empty at the bottom (limit {max_gap * 100:.0f}%); a block that would not fit moved whole")
    # punctuation starting a line
    txt = subprocess.run(["pdftotext", "-layout", pdf, "-"], capture_output=True, text=True).stdout
    for ln in txt.splitlines():
        s = ln.strip()
        if s and re.match(r"^[.,;:!?)\]’”]", s) and not re.match(r"^\.\.\.|^\.\w", s):
            warn.append(f"punct: a line starts with punctuation: {s[:60]!r}")
    print(f"pdfgate {pdf}: {n} pages, {nfonts} fonts, {len(t3)} Type 3")
    for f in fail: print("  FAIL", f)
    for w_ in warn: print("  WARN", w_)
    print(f"pdfgate: {len(fail)} failures, {len(warn)} warnings")
    return 1 if fail else 0


def main(a):
    if len(a) < 2: print(__doc__); return 2
    opt = lambda k, d=None: a[a.index(k) + 1] if k in a else d
    kw = dict(pages=int(opt("--pages")) if opt("--pages") else None, max_gap=float(opt("--max-gap", 0.40)),
              size=opt("--size"), body_pt=float(opt("--body-pt")) if opt("--body-pt") else None, allow_gap=[int(a[i + 1]) for i, x in enumerate(a) if x == "--allow-gap"])
    if a[0] == "build":
        pdf = opt("-o") or os.path.splitext(a[1])[0] + ".pdf"
        build(a[1], pdf); return check(pdf, **kw)
    if a[0] == "check": return check(a[1], **kw)
    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
