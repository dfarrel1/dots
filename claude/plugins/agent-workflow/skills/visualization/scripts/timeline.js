/* timeline.js: a small engine for animated and interactive explainers (references/animation.md).
 *
 * Two modes, one file, no dependencies:
 *   Viz.timeline({...})  a scrubbable timeline of eased tweens over a STATE object; a render(state) function
 *                        draws the SVG from the state every frame. Chapters carry captions; Play, Back, Next,
 *                        a scrubber, step dots and keys drive it. Seeking is stateless (any time t can be drawn
 *                        directly), which is what makes scrubbing, printing and frame-sampled lint possible.
 *   Viz.explorer({...})  direct manipulation: sliders and draggable handles set parameters, render(params)
 *                        recomputes the drawing live (the Red Blob Games pattern).
 *
 * Built on the record's step player (stepper.js: reader-started, no loops, aria-live caption, reduced motion,
 * print = final frame + numbered captions) and extended with what a 3Blue1Brown-standard explainer needs
 * (record section 6.2): continuity of objects (positions, sizes, colours and numbers interpolate), draw-on,
 * emphasis that moves with the story, and a scrubbable timeline.
 *
 * Lint hook: window.VIZ = { duration, chapters, seek(t), samples(dt) } (timeline) or
 *            window.VIZ = { sweep, apply(p) } (explorer). figlint.mjs samples rest frames AND transitions.
 * URL: ?t=12.5 opens at that time (used by render_png.mjs and PDF builds); ?print shows the print frame.
 */
(function (global) {
  "use strict";
  // ---- easing (all map 0..1 to 0..1) -------------------------------------------------------------------
  const E = {
    linear: t => t,
    in: t => t * t * t,
    out: t => 1 - Math.pow(1 - t, 3),
    inOut: t => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
    smooth: t => t * t * t * (t * (6 * t - 15) + 10),           // smootherstep; close to manim's default "smooth"
    there: t => Math.sin(Math.PI * t),                           // there and back: 0 -> 1 -> 0 (emphasis pulses)
    backOut: t => { const c = 1.4; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); },
  };
  const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));

  // ---- colour: tokens resolved from CSS, mixed in OKLab (perceptually even; no muddy midpoints) ----------
  const cache = new Map();
  function parseRGB(s) {
    s = (s || "").trim();
    let m = s.match(/^#([0-9a-f]{3,8})$/i);
    if (m) { let h = m[1]; if (h.length < 6) h = h.slice(0, 3).split("").map(c => c + c).join(""); return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16)); }
    m = s.match(/rgba?\(([^)]+)\)/);
    if (m) return m[1].split(/[ ,/]+/).filter(Boolean).slice(0, 3).map(parseFloat);
    return null;
  }
  function resolveColor(c, scope) {
    if (Array.isArray(c)) return c;
    const key = c;
    if (cache.has(key)) return cache.get(key);
    let v = c;
    const m = /^(?:var\()?\s*(--[\w-]+)\s*\)?$/.exec(c);
    if (m) v = getComputedStyle(scope || document.documentElement).getPropertyValue(m[1]);
    let rgb = parseRGB(v);
    if (!rgb) { const p = document.createElement("span"); p.style.color = v; document.body.append(p); rgb = parseRGB(getComputedStyle(p).color); p.remove(); }
    rgb = rgb || [0, 0, 0];
    cache.set(key, rgb); return rgb;
  }
  const lin = c => { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
  const gam = c => 255 * (c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055);
  function toOklab([r, g, b]) {
    r = lin(r); g = lin(g); b = lin(b);
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s];
  }
  function fromOklab([L, a, b]) {
    const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3), m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3), s = Math.pow(L - 0.0894841775 * a - 1.291485548 * b, 3);
    return [gam(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s), gam(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s), gam(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s)];
  }
  function mix(a, b, f, scope) {
    const A = toOklab(resolveColor(a, scope)), B = toOklab(resolveColor(b, scope));
    const c = fromOklab(A.map((v, i) => v + (B[i] - v) * clamp(f)));
    return `rgb(${c.map(x => Math.round(clamp(x, 0, 255))).join(",")})`;
  }
  const isColor = v => typeof v === "string" && /^(#|rgb|var\(|--)/.test(v.trim());
  function interp(a, b, p, scope) {
    if (typeof a === "number" && typeof b === "number") return a + (b - a) * p;
    if (isColor(a) && isColor(b)) return p <= 0 ? a : p >= 1 ? b : mix(a, b, p, scope);
    return p < 1 ? a : b;                                         // strings and booleans switch at the end
  }
  // Clear cached colours when the theme or the print state changes.
  const clearColors = () => cache.clear();
  if (global.matchMedia) {
    ["(prefers-color-scheme: dark)", "print"].forEach(q => { const mq = matchMedia(q); (mq.addEventListener ? mq.addEventListener("change", clearColors) : mq.addListener(clearColors)); });
  }

  // ---- helpers for render functions -----------------------------------------------------------------------
  const H = {
    mix, ease: E, clamp,
    /** Draw a line or path on: d = 0 hidden, 1 fully drawn. Direction = the element's own direction. */
    drawOn(el, d) {
      if (d <= 0.001) { el.style.visibility = "hidden"; return; }
      el.style.visibility = "";
      const len = el.getTotalLength ? el.getTotalLength() : 0;
      if (d >= 0.999 || !len) { el.style.strokeDasharray = ""; el.style.strokeDashoffset = ""; return; }
      el.style.strokeDasharray = `${len} ${len}`; el.style.strokeDashoffset = `${len * (1 - d)}`;
    },
    /** Opacity with a true hidden state, so a fully faded element is not hit-tested or linted. */
    fade(el, o) { el.style.opacity = o; el.style.visibility = o <= 0.001 ? "hidden" : ""; },
    attrs(el, a) { for (const k in a) el.setAttribute(k, typeof a[k] === "number" ? +a[k].toFixed(2) : a[k]); },
    /** Integer counter text. fmt(n) returns the string; default groups thousands. */
    count(el, v, fmt) { const n = Math.round(v); el.textContent = fmt ? fmt(n) : n.toLocaleString("en-GB"); },
  };

  // ---- the timeline -----------------------------------------------------------------------------------------
  function timeline(o) {
    const svg = typeof o.svg === "string" ? document.querySelector(o.svg) : o.svg;
    const reduce = matchMedia("(prefers-reduced-motion: reduce)");
    const init0 = Object.assign({}, o.state);
    const tracks = {};                 // key -> [{t0, t1, from, to, ease}]
    const chapters = [];
    let duration = 0, finalised = false;

    const api = {
      /** Animate state keys from t0 for dur seconds. changes: {key: to} or {key: [from, to]}. */
      tween(t0, dur, changes, ease = "inOut") {
        for (const k in changes) {
          const v = changes[k], [from, to] = Array.isArray(v) && v.length === 2 && !isColor(v) ? v : [undefined, v];
          (tracks[k] = tracks[k] || []).push({ t0, t1: t0 + dur, from, to, ease: typeof ease === "function" ? ease : E[ease] });
          duration = Math.max(duration, t0 + dur);
        }
        return api;
      },
      /** Set keys instantly at t. */
      set(t, changes) { return api.tween(t, 0, changes, "linear"); },
      /** An emphasis pulse: key goes 0 -> 1 -> 0 over dur (pair it with a mix() in render). */
      pulse(t0, dur, key) { return api.tween(t0, dur, { [key]: [0, 1] }, "there").set(t0 + dur, { [key]: 0 }); },
      /** A chapter: caption from time t; rest = the time its motion has settled (its key frame). */
      chapter(t, caption, rest) { chapters.push({ t, caption, rest }); duration = Math.max(duration, t); return api; },
      seek, play, stop, get t() { return now; }, get duration() { return duration; },
    };

    function bake() {
      if (finalised) return; finalised = true;
      for (const k in tracks) {
        tracks[k].sort((a, b) => a.t0 - b.t0);
        let prev = init0[k];
        for (const tr of tracks[k]) { if (tr.from === undefined) tr.from = prev; prev = tr.to; }
        if (!(k in init0)) init0[k] = tracks[k][0].from;
      }
      chapters.sort((a, b) => a.t - b.t);
      // A chapter's rest frame (its key frame) is where its own motion settles: the last tween that starts inside
      // the chapter ends there. Never the next chapter's start, which would show the next caption.
      chapters.forEach((c, i) => {
        const next = i + 1 < chapters.length ? chapters[i + 1].t : duration + 1e-3;
        let end = c.t;
        for (const k in tracks) for (const tr of tracks[k]) if (tr.t0 >= c.t - 1e-9 && tr.t0 < next - 1e-9) end = Math.max(end, tr.t1);
        if (c.rest == null) c.rest = Math.min(end, next - 0.01);
        c.next = next;
      });
    }
    function valueAt(k, t) {
      const ts = tracks[k]; if (!ts) return init0[k];
      let v = init0[k];
      for (const tr of ts) {
        if (tr.t0 > t) break;
        if (t >= tr.t1) { v = tr.to; continue; }
        v = interp(tr.from, tr.to, tr.ease(clamp((t - tr.t0) / (tr.t1 - tr.t0 || 1))), svg); break;
      }
      return v;
    }
    function stateAt(t) { const s = {}; for (const k in init0) s[k] = valueAt(k, t); for (const k in tracks) if (!(k in s)) s[k] = valueAt(k, t); return s; }
    function chapterAt(t) { let c = 0; chapters.forEach((ch, i) => { if (t >= ch.t - 1e-6) c = i; }); return c; }

    // ---- player UI ----
    const stage = svg.closest(".stage") || svg.parentElement;
    let player = o.player ? document.querySelector(o.player) : stage.nextElementSibling;
    if (!player || !player.classList.contains("player")) { player = document.createElement("div"); player.className = "player"; stage.after(player); }
    player.innerHTML = `<p class="caption" id="caption" aria-live="polite"></p>
      <div class="controls">
        <button type="button" id="prev">Back</button><button type="button" id="play" aria-pressed="false">Play</button><button type="button" id="next">Next</button>
        <input id="scrub" type="range" min="0" step="10" aria-label="Position in the animation">
        <span class="lbl" id="count"></span>
      </div>
      <div class="dots" id="dots" role="group" aria-label="Steps"></div>
      <p class="keys">Keys: Left and Right step, Space or K plays and pauses, comma and full stop nudge the time, Home and End jump.</p>`;
    const $ = id => player.querySelector("#" + id);
    const cap = $("caption"), playB = $("play"), scrub = $("scrub"), count = $("count"), dots = $("dots");
    let now = 0, raf = 0, target = null, holdUntil = 0, curChap = -1, last = 0;

    function seek(t, announce = true) {
      bake();
      now = clamp(t, 0, duration);
      o.render(stateAt(now), now, H);
      const c = chapterAt(now);
      if (c !== curChap && announce) { curChap = c; cap.textContent = chapters[c] ? chapters[c].caption : ""; }
      scrub.value = Math.round(now * 1000);
      count.textContent = `Step ${c + 1} of ${chapters.length}`;
      [...dots.children].forEach((d, k) => d.setAttribute("aria-current", k === c ? "step" : "false"));
      $("prev").disabled = now <= (chapters[0] ? chapters[0].rest : 0) + 1e-3;
      $("next").disabled = now >= duration - 1e-3;
    }
    function stop() { cancelAnimationFrame(raf); raf = 0; target = null; playB.textContent = "Play"; playB.setAttribute("aria-pressed", "false"); clearTimeout(api._rm); }
    function frame(ts) {
      const dt = Math.min(0.05, (ts - last) / 1000); last = ts;
      if (ts < holdUntil) { raf = requestAnimationFrame(frame); return; }
      const end = target != null ? target : duration;
      let t = now + dt * (o.speed || 1);
      // pause on each chapter's rest frame for reading time when playing straight through
      const c = chapters[chapterAt(now)];
      if (target == null && c && now < c.rest && t >= c.rest && c.rest < duration) { t = c.rest; holdUntil = ts + (o.hold != null ? o.hold : 1500); }
      if (t >= end) { seek(end); stop(); return; }
      seek(t); raf = requestAnimationFrame(frame);
    }
    function play(to = null) {
      bake(); stop();
      if (reduce.matches) {                       // reduced motion: no tweens; key frames with a long dwell
        const go = () => { const c = chapterAt(now); const nx = chapters[c + 1]; if (!nx || (to != null && now >= to)) return stop(); seek(nx.rest); api._rm = setTimeout(go, 6000); };
        playB.textContent = "Pause"; playB.setAttribute("aria-pressed", "true");
        if (to != null) { const c = chapters[chapterAt(now) + 1]; if (c) seek(c.rest); return stop(); }
        api._rm = setTimeout(go, 600); return;
      }
      if (to == null && now >= duration - 1e-3) seek(0);
      target = to; playB.textContent = "Pause"; playB.setAttribute("aria-pressed", "true");
      last = performance.now(); holdUntil = 0; raf = requestAnimationFrame(frame);
    }
    function nextStep() {                         // Next plays the next chapter's motion, then stops at its rest frame
      const c = chapterAt(now), ch = chapters[c];
      if (ch && now < ch.rest - 1e-3) { stop(); return play(ch.rest); }
      const nx = chapters[c + 1]; if (!nx) return;
      stop(); seek(nx.t); play(nx.rest);
    }
    function prevStep() {                         // Back jumps (no motion) to the previous chapter's rest frame
      stop(); const c = chapterAt(now), ch = chapters[c];
      if (ch && now > ch.rest + 1e-3) return seek(ch.rest);
      seek(chapters[Math.max(0, c - 1)].rest);
    }
    playB.onclick = () => (raf || api._rm ? stop() : play());
    $("next").onclick = nextStep; $("prev").onclick = prevStep;
    scrub.oninput = () => { stop(); seek(scrub.value / 1000); };
    document.addEventListener("keydown", e => {
      if (e.altKey || e.ctrlKey || e.metaKey || /input|textarea|select/i.test(e.target.tagName) && e.target !== scrub) return;
      const k = e.key;
      if (k === "ArrowRight" && e.target !== scrub) { e.preventDefault(); nextStep(); }
      else if (k === "ArrowLeft" && e.target !== scrub) { e.preventDefault(); prevStep(); }
      else if (k === "Home") { e.preventDefault(); stop(); seek(0); }
      else if (k === "End") { e.preventDefault(); stop(); seek(duration); }
      else if (k === ",") { stop(); seek(now - 0.1); } else if (k === ".") { stop(); seek(now + 0.1); }
      else if ((k === " " && e.target.tagName !== "BUTTON") || k === "k" || k === "K") { e.preventDefault(); playB.click(); }
    });

    function init() {
      bake();
      scrub.max = Math.round(duration * 1000);
      chapters.forEach((c, k) => {
        const b = document.createElement("button"); b.type = "button"; b.setAttribute("aria-label", `Step ${k + 1}`);
        b.onclick = () => { stop(); seek(c.rest); }; dots.append(b);
      });
      // Print: the key frame (o.printTime, default the end) and every caption as a numbered list.
      const list = document.createElement("ol"); list.className = "print-steps";
      chapters.forEach(c => { const li = document.createElement("li"); li.textContent = c.caption; list.append(li); });
      player.after(list);
      const printT = o.printTime != null ? o.printTime : duration;
      let before = null;
      const toPrint = () => { if (before == null) before = now; stop(); cache.clear(); seek(printT); };
      const fromPrint = () => { cache.clear(); if (before != null) seek(before); before = null; };
      addEventListener("beforeprint", toPrint); addEventListener("afterprint", fromPrint);
      const mqp = matchMedia("print"); (mqp.addEventListener ? mqp.addEventListener("change", e => (e.matches ? toPrint() : fromPrint())) : 0);
      const q = new URLSearchParams(location.search);
      const startT = q.has("print") ? printT : q.has("t") ? parseFloat(q.get("t")) : (o.start != null ? o.start : chapters[0] ? chapters[0].rest : 0);
      seek(startT);
      requestAnimationFrame(() => stage.classList.add("ready"));

      // Lint hook: rest frames (chapter key frames) and transition samples every dt seconds while anything moves.
      global.VIZ = {
        kind: "timeline", get duration() { return duration; }, chapters: chapters.map(c => ({ t: c.t, rest: c.rest, caption: c.caption })),
        seek: t => seek(t), printTime: printT,
        samples(dt = 0.1) {
          const iv = []; for (const k in tracks) for (const tr of tracks[k]) if (tr.t1 > tr.t0) iv.push([tr.t0, tr.t1]);
          const out = chapters.map((c, i) => ({ t: c.rest, rest: true, chapter: i + 1 }));
          for (let t = 0; t <= duration + 1e-9; t += dt) {
            if (iv.some(([a, b]) => t > a + 1e-6 && t < b - 1e-6)) out.push({ t: +t.toFixed(3), rest: false, chapter: chapterAt(t) + 1 });
          }
          return out.sort((a, b) => a.t - b.t);
        },
      };
    }
    // Tweens and chapters are added after Viz.timeline() returns (or inside o.build); initialise once they exist.
    if (o.build) { o.build(api); init(); } else queueMicrotask(init);
    return api;
  }

  // ---- the explorer (direct manipulation) -------------------------------------------------------------------
  function explorer(o) {
    const svg = typeof o.svg === "string" ? document.querySelector(o.svg) : o.svg;
    const p = Object.assign({}, o.params);
    const inputs = {};
    for (const name in (o.sliders || {})) {
      const el = document.querySelector(o.sliders[name]); inputs[name] = el;
      el.value = p[name]; el.addEventListener("input", () => { p[name] = +el.value; draw(); });
    }
    function draw() { o.render(p, H); for (const n in inputs) if (+inputs[n].value !== p[n]) inputs[n].value = p[n]; }
    /** Make an SVG element draggable; onDrag(x, y, params) receives viewBox coordinates and updates params. */
    function drag(el, onDrag) {
      el.style.cursor = "grab"; el.setAttribute("tabindex", "0");
      const pt = svg.createSVGPoint();
      const at = e => { pt.x = e.clientX; pt.y = e.clientY; return pt.matrixTransform(svg.getScreenCTM().inverse()); };
      el.addEventListener("pointerdown", e => {
        el.setPointerCapture(e.pointerId); el.style.cursor = "grabbing";
        const mv = ev => { const q = at(ev); onDrag(q.x, q.y, p); draw(); };
        const up = () => { el.style.cursor = "grab"; el.removeEventListener("pointermove", mv); el.removeEventListener("pointerup", up); };
        el.addEventListener("pointermove", mv); el.addEventListener("pointerup", up);
      });
      el.addEventListener("keydown", e => {         // keyboard parity: arrows move the handle by 4 units
        const d = { ArrowLeft: [-4, 0], ArrowRight: [4, 0], ArrowUp: [0, -4], ArrowDown: [0, 4] }[e.key]; if (!d) return;
        e.preventDefault(); const b = el.getBBox(); onDrag(b.x + b.width / 2 + d[0], b.y + b.height / 2 + d[1], p); draw();
      });
    }
    (o.handles || []).forEach(([sel, fn]) => drag(svg.querySelector(sel), fn));
    const q = new URLSearchParams(location.search);
    for (const n in p) if (q.has(n)) p[n] = parseFloat(q.get(n));
    const pr = o.printParams; if (pr) { addEventListener("beforeprint", () => { Object.assign(p, pr); draw(); }); if (q.has("print")) Object.assign(p, pr); }
    draw();
    global.VIZ = { kind: "explorer", sweep: o.sweep || [p], apply(v) { Object.assign(p, v); draw(); } };
    return { params: p, draw, drag };
  }

  global.Viz = { timeline, explorer, ease: E, mix, helpers: H };
})(window);
