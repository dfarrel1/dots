// figlint: render figures and explainers in real Chrome and fail on what a reader would see.
// usage: node figlint.mjs [options] <file.html|file.svg|dir> ...
//   --css <file>        stylesheet for bare .svg files (default ../templates/viz.css)
//   --widths 900,680    viewport widths (default 900,680)    --themes light,dark (default both)
//   --sample 0.1        seconds between transition samples for timeline explainers (default 0.1)
//   --no-print          skip the print pass                  --allow-remote  downgrade remote requests to warnings
//   --json <out.json>   write the findings
// Exit 1 on any error. Zero errors is the bar; every warning is fixed or justified in the critique log.
//
// Generalised from a checker that took a figure family from 11 errors / 77 warnings to 0 / 0 (record W4),
// with the gaps the record lists (section 4) closed: SVG text-on-shape contrast, printed size, whitespace,
// words per label, orphans, arrows with no head, remote fonts, undefined CSS variables, and every
// transition frame of a timeline explainer, not only its rest frames (section 6.2 item 6).
//
// ERRORS  text-overlap  text-clipped  text-crosses-box  line-through-text  html-overflow  low-contrast
//         svg-low-contrast  figure-no-alt  remote-resource  undefined-var  print-small-text  print-too-wide
// WARNINGS text-tight  text-clearance  small-text  small-authored  arrow-short  arrow-no-head  label-words
//         prose-in-box  empty-space  orphan  explainer-controls  var-fallback
// Exemptions are explicit attributes, never thresholds: data-lint="strike" (a deliberate strike-through line),
// data-lint="halo" (a haloed label a line may pass behind), data-lint="nohead" (a connector meant to have no
// arrowhead), data-role="note"|"title" (allowed longer text), data-lint="space" (a deliberately empty region).
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { launch, closeFast } from './pw.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const opts = { css: path.join(HERE, '../templates/viz.css'), widths: [900, 680], themes: ['light', 'dark'], sample: 0.1, print: true, allowRemote: false, json: null };
const inputs = [];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--css') opts.css = argv[++i];
  else if (a === '--widths') opts.widths = argv[++i].split(',').map(Number);
  else if (a === '--themes') opts.themes = argv[++i].split(',');
  else if (a === '--sample') opts.sample = parseFloat(argv[++i]);
  else if (a === '--no-print') opts.print = false;
  else if (a === '--allow-remote') opts.allowRemote = true;
  else if (a === '--json') opts.json = argv[++i];
  else inputs.push(a);
}
function collect(p) {
  const st = fs.statSync(p);
  if (st.isDirectory()) return fs.readdirSync(p).flatMap(f => collect(path.join(p, f)));
  return /\.(html|svg)$/.test(p) && !path.basename(p).startsWith('_') ? [path.resolve(p)] : [];
}
const files = inputs.flatMap(collect);
if (!files.length) { console.error('figlint: no .html or .svg files given'); process.exit(2); }

// ---------------------------------------------------------------------------------------------------------
// The in-page checker. o = { rest: bool, print: bool }. Returns [{code, sev, msg}].
function inPage(o) {
  const out = [];
  const push = (code, sev, msg) => out.push({ code, sev, msg });
  const effOpacity = el => { let a = 1; for (let e = el; e && e.nodeType === 1; e = e.parentElement) a *= parseFloat(getComputedStyle(e).opacity); return a; };
  const visible = el => {
    for (let e = el; e && e.nodeType === 1; e = e.parentElement) {
      const cs = getComputedStyle(e);
      if (cs.display === 'none' || cs.visibility === 'hidden') return false;
    }
    if (effOpacity(el) < 0.05) return false;
    const r = el.getBoundingClientRect(); return r.width > 0 || r.height > 0;
  };
  const words = s => (s || '').trim().split(/\s+/).filter(w => /[\p{L}\p{N}]/u.test(w));
  const label = el => {
    const t = (el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 48);
    const svg = el.closest('svg'); const fig = svg ? (svg.getAttribute('aria-label') || '').slice(0, 36) : '';
    return `"${t}"${fig ? ' in [' + fig + ']' : ''}`;
  };
  const inter = (a, b) => Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left)) * Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
  const toScreen = (m, x, y) => [m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f];
  const inkRect = t => {   // glyph ink box: getBBox through the screen CTM, internal leading trimmed (~11 % each side)
    try {
      const bb = t.getBBox(), m = t.getScreenCTM();
      const pts = [[bb.x, bb.y], [bb.x + bb.width, bb.y], [bb.x, bb.y + bb.height], [bb.x + bb.width, bb.y + bb.height]].map(([x, y]) => toScreen(m, x, y));
      const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
      const h = Math.max(...ys) - Math.min(...ys), pad = h * 0.11;
      return { left: Math.min(...xs), right: Math.max(...xs), top: Math.min(...ys) + pad, bottom: Math.max(...ys) - pad };
    } catch { return t.getBoundingClientRect(); }
  };
  const parseRGB = s => { const m = (s || '').match(/rgba?\(([^)]+)\)/); if (!m) return null; const v = m[1].split(/[ ,/]+/).filter(Boolean).map(parseFloat); return { r: v[0], g: v[1], b: v[2], a: v.length > 3 ? v[3] : 1 }; };
  const lum = c => { const f = x => { x /= 255; return x <= 0.04045 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); }; return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); };
  const ratio = (a, b) => { const L1 = lum(a), L2 = lum(b); return (Math.max(L1, L2) + 0.05) / (Math.min(L1, L2) + 0.05); };
  const bgOf = el => { for (let e = el; e; e = e.parentElement) { const c = parseRGB(getComputedStyle(e).backgroundColor); if (c && c.a > 0.5) return c; } return parseRGB(getComputedStyle(document.body).backgroundColor) || { r: 255, g: 255, b: 255 }; };

  const svgs = [...document.querySelectorAll('svg')].filter(s => visible(s) && !s.closest('defs,marker,symbol') && !s.parentElement.closest('svg'));
  for (const svg of svgs) {
    const vr = svg.getBoundingClientRect();
    const vb = svg.viewBox && svg.viewBox.baseVal && svg.viewBox.baseVal.width ? svg.viewBox.baseVal : null;
    const unit = vb ? vr.width / vb.width : 1, norm = vb ? 760 / vb.width : 1;
    const decorative = svg.getAttribute('aria-hidden') === 'true';
    if (!decorative && vr.width > 120 && !svg.getAttribute('aria-label') && !svg.getAttribute('aria-labelledby') && !svg.querySelector(':scope > title'))
      push('figure-no-alt', 'E', `an SVG figure has no aria-label or <title> (${Math.round(vr.width)} px wide)`);
    if (decorative || vr.width < 120) continue;
    const texts = [...svg.querySelectorAll('text')].filter(t => visible(t) && t.textContent.trim() && !t.closest('defs,marker,symbol'));
    const rects = texts.map(inkRect);
    const shapes = [...svg.querySelectorAll('rect,circle,ellipse')].filter(s => visible(s) && !s.closest('marker,defs,symbol'))
      .map(s => ({ s, r: s.getBoundingClientRect() })).filter(x => x.r.width > 6 && x.r.height > 6);
    const lines = [...svg.querySelectorAll('path,line,polyline')].filter(p => visible(p) && !p.closest('marker,defs,symbol') && !p.closest('[data-lint~=strike]'))
      .filter(p => { const cs = getComputedStyle(p); return cs.stroke !== 'none' && parseFloat(cs.strokeWidth) > 0; });
    const halo = t => t.closest('[data-lint~=halo]') || /\bhalo\b/.test(t.getAttribute('class') || '');
    texts.forEach((t, i) => {
      const r = rects[i];
      if (r.left < vr.left - 0.5 || r.right > vr.right + 0.5 || r.top < vr.top - 0.5 || r.bottom > vr.bottom + 0.5)
        push('text-clipped', 'E', `text outside the figure's bounds ${label(t)}`);
      const fsz = parseFloat(getComputedStyle(t).fontSize) * (t.getScreenCTM()?.a || 1);
      if (o.print) { if (fsz < 10.5) push('print-small-text', 'E', `${fsz.toFixed(1)} px in print ${label(t)}`); }
      else if (fsz < 10.5) push('small-text', 'W', `${fsz.toFixed(1)} px ${label(t)}`);
      const authored = parseFloat(getComputedStyle(t).fontSize) * norm;
      if (vb && authored < 12.95 && !o.print) push('small-authored', 'W', `${authored.toFixed(1)} units at 760 wide (minimum 13) ${label(t)}`);
      for (let j = i + 1; j < texts.length; j++) {
        if (texts[j].contains(t) || t.contains(texts[j])) continue;
        if (inter(r, rects[j]) > 4) push('text-overlap', 'E', `${label(t)} overlaps ${label(texts[j])}`);
      }
      for (const { s, r: b } of shapes) {
        const ov = inter(r, b), area = (r.right - r.left) * (r.bottom - r.top);
        if (s.tagName !== 'rect' && ov > 2) {
          // circles and ellipses: test the ink corners against the real outline, not the bounding box
          const m = s.getScreenCTM().inverse(); const pts = [[r.left, r.top], [r.right, r.top], [r.left, r.bottom], [r.right, r.bottom]];
          const ins = pts.map(([x, y]) => { const p = new DOMPoint(x, y).matrixTransform(m); return s.isPointInFill(p); });
          if (ins.some(Boolean) && !ins.every(Boolean)) push('text-crosses-box', 'E', `${label(t)} straddles the edge of a <${s.tagName}>`);
          continue;
        }
        if (ov > 2 && ov < area * 0.97) push('text-crosses-box', 'E', `${label(t)} straddles the edge of a <${s.tagName}>`);
        else if (ov >= area * 0.97 && s.tagName === 'rect' && b.width < vr.width * 0.95) {
          const gap = Math.min(r.left - b.left, b.right - r.right, r.top - b.top, b.bottom - r.bottom);
          if (gap < 4) push('text-tight', 'W', `${gap.toFixed(1)} px clearance ${label(t)}`);
          else if (vb && gap / unit < 7.5) push('text-clearance', 'W', `${(gap / unit).toFixed(1)} units to a box edge (minimum 8) ${label(t)}`);
        }
      }
      if (halo(t)) return;
      for (const p of lines) {
        let len = 0; try { len = p.getTotalLength(); } catch { continue; }
        if (!len) continue;
        // a partly drawn line (stroke-dasharray draw-on) is only checked over its drawn part
        const cs = getComputedStyle(p); let drawn = len;
        if (cs.strokeDasharray && cs.strokeDasharray !== 'none') { const off = parseFloat(cs.strokeDashoffset) || 0; const da = cs.strokeDasharray.split(/[ ,]+/).map(parseFloat); if (da.length === 2 && Math.abs(da[0] - len) < 1) drawn = Math.max(0, len - off); }
        const m = p.getScreenCTM(); const n = Math.min(400, Math.max(8, Math.ceil(drawn / 3)));
        let hits = 0;
        for (let k = 0; k <= n; k++) {
          const q = p.getPointAtLength(drawn * k / n); const [x, y] = toScreen(m, q.x, q.y);
          if (x > r.left + 1 && x < r.right - 1 && y > r.top + 1 && y < r.bottom - 1) hits++;
        }
        if (hits >= 2) { push('line-through-text', 'E', `a line passes through ${label(t)}`); break; }
      }
    });
    if (!vb) continue;
    // ---- arrows: tips that stop short, and connectors that end on a box with no head ----
    const boxes = shapes.filter(x => x.s.tagName === 'rect' && x.r.width > 12 && x.r.height > 12).map(x => x.r);
    const heads = [];
    for (const p of svg.querySelectorAll('path')) {
      const m = (p.getAttribute('d') || '').match(/^M([\d.-]+) ([\d.-]+)L[\d.-]+ [\d.-]+L[\d.-]+ [\d.-]+z$/);
      if (m && visible(p)) { const [x, y] = toScreen(p.getScreenCTM(), +m[1], +m[2]); heads.push([x, y]); }
    }
    for (const p of svg.querySelectorAll('path[marker-end],line[marker-end]')) if (visible(p)) { try { const L = p.getTotalLength(), q = p.getPointAtLength(L); heads.push(toScreen(p.getScreenCTM(), q.x, q.y)); } catch {} }
    const edgeDist = (x, y) => {
      let best = Infinity;
      for (const b of boxes) {
        const inY = y >= b.top - 1 && y <= b.bottom + 1, inX = x >= b.left - 1 && x <= b.right + 1;
        if (inY) best = Math.min(best, Math.abs(x - b.left), Math.abs(x - b.right));
        if (inX) best = Math.min(best, Math.abs(y - b.top), Math.abs(y - b.bottom));
      }
      return best / unit;
    };
    for (const [x, y] of heads) { const d = edgeDist(x, y); if (d > 2 && d < 16) push('arrow-short', 'W', `an arrowhead stops ${d.toFixed(1)} units from a box edge in [${(svg.getAttribute('aria-label') || '').slice(0, 36)}]`); }
    if (o.rest) for (const p of lines) {
      if (p.closest('[data-lint~=nohead]') || /\blnr\b/.test(p.getAttribute('class') || '')) continue;
      const d = p.getAttribute('d') || ''; if (/z\s*$/i.test(d)) continue;
      let L; try { L = p.getTotalLength(); } catch { continue; } if (L < 10) continue;
      const q = p.getPointAtLength(L), [x, y] = toScreen(p.getScreenCTM(), q.x, q.y);
      if (edgeDist(x, y) > 1.6) continue;
      if (!heads.some(([hx, hy]) => Math.hypot(hx - x, hy - y) / unit < 14)) push('arrow-no-head', 'W', `a connector ends on a box edge with no arrowhead (mark data-lint="nohead" if meant) in [${(svg.getAttribute('aria-label') || '').slice(0, 36)}]`);
    }
    if (!o.rest) continue;
    // ---- SVG text contrast against the shape actually under it ----
    texts.forEach((t, i) => {
      if (effOpacity(t) < 0.95) return;
      const r = rects[i], cx = (r.left + r.right) / 2, cy = (r.top + r.bottom) / 2;
      const fg = parseRGB(getComputedStyle(t).fill); if (!fg) return;
      let bg = null;
      const under = [...svg.querySelectorAll('rect,circle,ellipse,path,polygon')].filter(s => (s.compareDocumentPosition(t) & Node.DOCUMENT_POSITION_FOLLOWING) && visible(s));
      for (let k = under.length - 1; k >= 0; k--) {
        const s = under[k], cs = getComputedStyle(s); const c = parseRGB(cs.fill);
        if (!c || cs.fill === 'none' || c.a * parseFloat(cs.fillOpacity) * effOpacity(s) < 0.6) continue;
        try { const p = new DOMPoint(cx, cy).matrixTransform(s.getScreenCTM().inverse()); if (s.isPointInFill(p)) { bg = c; break; } } catch {}
      }
      bg = bg || bgOf(svg);
      const px = parseFloat(getComputedStyle(t).fontSize) * (t.getScreenCTM()?.a || 1), bold = parseInt(getComputedStyle(t).fontWeight) >= 700;
      const need = px >= 24 || (bold && px >= 18.66) ? 3 : 4.5, cr = ratio(fg, bg);
      if (cr < need) push('svg-low-contrast', 'E', `${cr.toFixed(2)}:1 (needs ${need}) ${label(t)}`);
    });
    // ---- words: prose belongs in the caption, not the drawing (record F10) ----
    const prose = t => t.closest('[data-role=note],[data-role=title],[data-role=statement],[data-lint~=prose]');
    texts.forEach(t => { const n = words(t.textContent).length; if (n > 12 && !prose(t)) push('label-words', 'W', `${n} words in one label ${label(t)}`); });
    for (const { s, r: b } of shapes) {
      if (s.tagName !== 'rect' || b.width > vr.width * 0.95) continue;
      const inside = texts.filter((t, i) => { const r = rects[i]; return r.left >= b.left && r.right <= b.right && r.top >= b.top && r.bottom <= b.bottom && !prose(t); });
      const n = inside.reduce((a, t) => a + words(t.textContent).length, 0);
      const smaller = shapes.some(x => x.s !== s && x.r.left >= b.left && x.r.right <= b.right && x.r.top >= b.top && x.r.bottom <= b.bottom);
      if (n > 30 && !smaller) push('prose-in-box', 'W', `${n} words inside one box: move detail to the caption ("${(inside[0]?.textContent || '').slice(0, 30)}...")`);
    }
    // ---- orphans in wrapped SVG labels: a one-word last line under a line of 3+ words ----
    const lineGroups = new Map();
    texts.forEach((t, i) => { const k = `${t.getAttribute('x')}|${t.getAttribute('text-anchor') || 's'}|${t.getAttribute('font-size')}|${t.getAttribute('class')}`; (lineGroups.get(k) || lineGroups.set(k, []).get(k)).push([rects[i], t]); });
    for (const g of lineGroups.values()) {
      g.sort((a, b) => a[0].top - b[0].top);
      for (let k = 1; k < g.length; k++) {
        const [ra, ta] = g[k - 1], [rb, tb] = g[k], h = ra.bottom - ra.top;
        const consecutive = rb.top - ra.top > 0 && rb.top - ra.top < h * 1.9;
        const endsBlock = !(g[k + 1] && g[k + 1][0].top - rb.top < h * 1.9);
        if (consecutive && endsBlock && words(tb.textContent).length === 1 && words(ta.textContent).length >= 3)
          push('orphan', 'W', `one word alone on the last line ${label(tb)}`);
      }
    }
    // ---- empty space: the largest empty rectangle inside the drawing's content area (record defect class 7) ----
    if (!svg.closest('[data-lint~=space]')) {
      const N = 48, cw = vr.width / N, rows = Math.max(4, Math.round(vr.height / cw));
      const grid = Array.from({ length: rows }, () => new Uint8Array(N));
      const mark = (l, t_, r_, b_) => { for (let y = Math.max(0, Math.floor((t_ - vr.top) / cw)); y <= Math.min(rows - 1, Math.floor((b_ - vr.top) / cw)); y++) for (let x = Math.max(0, Math.floor((l - vr.left) / cw)); x <= Math.min(N - 1, Math.floor((r_ - vr.left) / cw)); x++) grid[y][x] = 1; };
      // the title row and the dated note span the drawing: the space beside them is not a hole in the figure
      rects.forEach((r, i) => texts[i].closest('[data-role=title],[data-role=note]') ? mark(vr.left, r.top, vr.right, r.bottom) : mark(r.left, r.top, r.right, r.bottom));
      const big = vr.width * vr.height * 0.12;
      for (const { s, r } of shapes) {
        if ((r.right - r.left) * (r.bottom - r.top) < big) mark(r.left, r.top, r.right, r.bottom);
        else { const e = cw * 0.6; mark(r.left, r.top, r.right, r.top + e); mark(r.left, r.bottom - e, r.right, r.bottom); mark(r.left, r.top, r.left + e, r.bottom); mark(r.right - e, r.top, r.right, r.bottom); }
      }
      for (const p of lines) { let L; try { L = p.getTotalLength(); } catch { continue; } const m = p.getScreenCTM(); for (let k = 0; k <= Math.ceil(L / 4); k++) { const q = p.getPointAtLength(Math.min(L, k * 4)); const [x, y] = toScreen(m, q.x, q.y); mark(x - 1, y - 1, x + 1, y + 1); } }
      let x0 = N, x1 = -1, y0 = rows, y1 = -1;
      grid.forEach((row, y) => row.forEach((v, x) => { if (v) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); } }));
      if (x1 > x0 && y1 > y0) {
        const hgt = new Array(N).fill(0); let best = 0, bestR = null;
        for (let y = y0; y <= y1; y++) {
          for (let x = x0; x <= x1; x++) hgt[x] = grid[y][x] ? 0 : hgt[x] + 1;
          for (let x = x0; x <= x1; x++) { let h = Infinity; for (let x2 = x; x2 <= x1 && hgt[x2]; x2++) { h = Math.min(h, hgt[x2]); const a = h * (x2 - x + 1); if (a > best) { best = a; bestR = [x, y - h + 1, x2, y]; } } }
        }
        const area = (x1 - x0 + 1) * (y1 - y0 + 1), share = best / area;
        if (share > 0.16 && bestR) push('empty-space', 'W', `${Math.round(share * 100)}% of the drawing is one empty block (about ${Math.round((bestR[2] - bestR[0] + 1) * cw / unit)} x ${Math.round((bestR[3] - bestR[1] + 1) * cw / unit)} units, from ${Math.round(bestR[0] * cw / unit)},${Math.round(bestR[1] * cw / unit)}) in [${(svg.getAttribute('aria-label') || '').slice(0, 36)}]`);
      }
    }
  }
  // ---- explainer semantics ----
  if (o.rest && window.VIZ && window.VIZ.kind === 'timeline') {
    const play = document.querySelector('#play'), cap = document.querySelector('#caption'), scrub = document.querySelector('#scrub');
    if (!play || !play.hasAttribute('aria-pressed') || !cap || cap.getAttribute('aria-live') !== 'polite' || !scrub || !scrub.getAttribute('aria-label') || !document.querySelector('#prev') || !document.querySelector('#next'))
      push('explainer-controls', 'W', 'timeline needs #prev, #play (aria-pressed), #next, a labelled #scrub and an aria-live="polite" #caption');
  }
  if (o.rest && window.VIZ && window.VIZ.kind === 'explorer') {
    for (const i of document.querySelectorAll('input')) if (!i.getAttribute('aria-label') && !i.closest('label') && !(i.id && document.querySelector(`label[for="${i.id}"]`))) push('explainer-controls', 'W', `an explorer input has no label (#${i.id || '?'})`);
  }
  // ---- HTML: overflow, contrast, orphans ----
  for (const el of document.querySelectorAll('body *')) {
    if (el.closest('svg') || !visible(el) || /^(SCRIPT|STYLE)$/.test(el.tagName)) continue;
    const cs = getComputedStyle(el);
    if (el.clientWidth > 0 && el.scrollWidth > el.clientWidth + 2 && !/inline/.test(cs.display) && !['auto', 'scroll'].includes(cs.overflowX) && el.tagName !== 'INPUT')
      push('html-overflow', 'E', `<${el.tagName.toLowerCase()} class="${el.className}"> content ${el.scrollWidth}px in ${el.clientWidth}px`);
    const own = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
    if (!own) continue;
    if (o.rest) {
      const fg = parseRGB(cs.color), bg = bgOf(el);
      if (fg && bg) {
        const size = parseFloat(cs.fontSize), bold = parseInt(cs.fontWeight) >= 700, need = (size >= 24 || (bold && size >= 18.66)) ? 3 : 4.5;
        const op = effOpacity(el), cr = ratio(fg, bg);
        if (op > 0.95 && cr < need && !(el.disabled)) push('low-contrast', 'E', `${cr.toFixed(2)}:1 (needs ${need}) "${el.textContent.trim().slice(0, 40)}"`);
      }
    }
    if (o.rest && (/^(P|LI|FIGCAPTION|H1|H2|H3|TD|TH|DD)$/.test(el.tagName) || el.classList.contains('caption') || el.classList.contains('dek'))) {
      const tn = [...el.childNodes].filter(n => n.nodeType === 3 && n.textContent.trim()).pop();
      if (!tn) continue;
      const txt = tn.textContent, m = txt.match(/(\S+)\s+(\S+)\s*$/); if (!m) continue;
      const i2 = txt.lastIndexOf(m[2]), i1 = txt.lastIndexOf(m[1], i2 - 1);
      const rg = document.createRange(); rg.setStart(tn, i2); rg.setEnd(tn, i2 + m[2].length); const r2 = rg.getBoundingClientRect();
      rg.setStart(tn, i1); rg.setEnd(tn, i1 + m[1].length); const r1 = rg.getBoundingClientRect();
      if (r2.top > r1.top + 2) {
        const lineWords = (() => { let n = 0; const ws = txt.trim().split(/\s+/); let pos = 0; for (const w of ws) { const at = txt.indexOf(w, pos); pos = at + w.length; rg.setStart(tn, at); rg.setEnd(tn, pos); if (Math.abs(rg.getBoundingClientRect().top - r1.top) < 2) n++; } return n; })();
        if (lineWords >= 3) push('orphan', 'W', `one word alone on the last line: "${txt.trim().slice(-40)}"`);
      }
    }
  }
  // ---- CSS variables used but never defined ----
  if (o.rest) {
    let cssText = '';
    for (const sh of document.styleSheets) { try { for (const r of sh.cssRules) cssText += r.cssText + '\n'; } catch {} }
    document.querySelectorAll('[style]').forEach(e => cssText += e.getAttribute('style') + ';');
    const defined = new Set([...cssText.matchAll(/(--[\w-]+)\s*:/g)].map(m => m[1]));
    const seen = new Set();
    for (const m of cssText.matchAll(/var\(\s*(--[\w-]+)\s*(,)?/g)) {
      if (defined.has(m[1]) || seen.has(m[1])) continue; seen.add(m[1]);
      if (getComputedStyle(document.documentElement).getPropertyValue(m[1]).trim()) continue;
      push(m[2] ? 'var-fallback' : 'undefined-var', m[2] ? 'W' : 'E', `${m[1]} is used but never defined${m[2] ? ' (a fallback hides it)' : ''}`);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------------
const browser = await launch();
const report = [];
const frames = {};
const add = (f, scheme, width, step, list) => { for (const d of list) report.push({ file: f, scheme, width, step, ...d }); };
async function open(f, scheme, width, media) {
  const page = await browser.newPage({ viewport: { width, height: 1100 }, colorScheme: scheme, reducedMotion: 'no-preference' });
  const remote = [];
  page.on('request', r => { const u = r.url(); if (/^https?:/.test(u)) remote.push(u); });
  if (media) await page.emulateMedia({ media });
  if (f.endsWith('.svg')) {
    const svg = fs.readFileSync(f, 'utf8');
    await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><style>${fs.readFileSync(opts.css, 'utf8')}</style></head><body><main><figure><div class="fig">${svg}</div></figure></main></body></html>`);
  } else await page.goto('file://' + f);
  await page.waitForTimeout(250);
  return { page, remote };
}
for (const f of files) {
  frames[f] = 0;
  for (const scheme of opts.themes) for (const width of opts.widths) {
    const { page, remote } = await open(f, scheme, width);
    const kind = await page.evaluate(() => (window.VIZ && window.VIZ.kind) || (window.STEPS ? 'steps' : 'static'));
    if (kind === 'timeline') {
      const samples = await page.evaluate(dt => window.VIZ.samples(dt), opts.sample);
      for (const s of samples) {
        await page.evaluate(t => window.VIZ.seek(t), s.t);
        add(f, scheme, width, `t=${s.t.toFixed(2)} ${s.rest ? 'rest' : 'moving'} (step ${s.chapter})`, await page.evaluate(inPage, { rest: s.rest }));
        frames[f]++;
      }
    } else if (kind === 'explorer') {
      const sweep = await page.evaluate(() => window.VIZ.sweep);
      for (const p of sweep) {
        await page.evaluate(v => window.VIZ.apply(v), p);
        add(f, scheme, width, JSON.stringify(p), await page.evaluate(inPage, { rest: true })); frames[f]++;
      }
    } else if (kind === 'steps') {
      const n = await page.evaluate(() => window.STEPS.length);
      for (let s = 0; s < n; s++) {
        if (s) { await page.click('#next'); await page.waitForTimeout(1100); }
        add(f, scheme, width, `step ${s + 1}`, await page.evaluate(inPage, { rest: true })); frames[f]++;
      }
    } else { add(f, scheme, width, '-', await page.evaluate(inPage, { rest: true })); frames[f]++; }
    for (const u of new Set(remote)) report.push({ file: f, scheme, width, step: '-', code: 'remote-resource', sev: opts.allowRemote ? 'W' : 'E', msg: `requests ${u.slice(0, 90)} (offline and mesh-only readers never get it)` });
    await page.close();
  }
  if (opts.print) {
    const { page } = await open(f, 'light', 691, 'print');   // Letter, 0.65 in side margins: a 7.2 in (691 px) column
    await page.evaluate(() => { if (window.VIZ && window.VIZ.kind === 'timeline') window.VIZ.seek(window.VIZ.printTime); });
    await page.waitForTimeout(100);
    add(f, 'print', 691, 'print', (await page.evaluate(inPage, { rest: true, print: true })).filter(d => !['small-authored', 'orphan', 'explainer-controls'].includes(d.code)));
    const w = await page.evaluate(() => document.documentElement.scrollWidth);
    if (w > 692) report.push({ file: f, scheme: 'print', width: 691, step: 'print', code: 'print-too-wide', sev: 'E', msg: `the page is ${w}px wide in print; Chrome will silently shrink every page to fit (record F5)` });
    frames[f]++;
    await page.close();
  }
}
await closeFast(browser);

const key = d => `${d.file}|${d.code}|${d.msg}`;
const seen = new Map();
for (const d of report) {
  const k = key(d);
  if (!seen.has(k)) seen.set(k, { ...d, where: new Set(), steps: new Set() });
  seen.get(k).where.add(`${d.scheme}/${d.width}`); seen.get(k).steps.add(d.step);
}
const uniq = [...seen.values()].map(d => ({ ...d, where: [...d.where], steps: [...d.steps] }));
const errs = uniq.filter(d => d.sev === 'E'), warns = uniq.filter(d => d.sev === 'W');
for (const d of uniq.sort((a, b) => a.file.localeCompare(b.file) || a.sev.localeCompare(b.sev) || a.code.localeCompare(b.code))) {
  const st = d.steps.filter(s => s !== '-'); const sts = st.length ? ` at ${st.slice(0, 3).join('; ')}${st.length > 3 ? ` (+${st.length - 3} more frames)` : ''}` : '';
  console.log(`${d.sev} ${path.basename(d.file)}  ${d.code}  ${d.msg}${sts}  [${d.where.join(' ')}]`);
}
for (const f of files) console.log(`  ${path.basename(f)}: ${frames[f]} frames checked`);
console.log(`\nfiglint: ${files.length} files, ${errs.length} errors, ${warns.length} warnings`);
if (opts.json) fs.writeFileSync(opts.json, JSON.stringify(uniq, null, 1));
process.exit(errs.length ? 1 : 0);
