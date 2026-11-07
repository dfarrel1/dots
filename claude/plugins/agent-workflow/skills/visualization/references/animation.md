# Animated and interactive explainers

An explainer teaches one idea about change: growth, a path, a cut and a recovery, a key's life. The bar is
the 3Blue1Brown standard: the same objects persist and transform, the formula and the drawing move together,
and the reader always knows what to look at. Working example: `examples/proof/build_pairs_explainer.py`.
Public techniques worth taking: `references/exemplars-public.md`.

## When to animate

Animate only when the idea IS a change. If one frame says it, make a static figure. If the reader needs to
try values, make an explorer (sliders, drag), not a movie.

## The engine: `scripts/timeline.js`

State-driven and stateless to seek: you tween numbers, colours and strings in a STATE object; a `render(s, t, H)`
function draws the SVG from the state. Any time t can be drawn directly, which is what makes scrubbing,
printing the key frame and frame-sampled linting possible.

```js
const tl = Viz.timeline({ svg: "#stage", state: { x: 0, n: 0, hl: 0 }, render, hold: 1400 });
tl.chapter(0, "Caption for step 1.");               // captions belong to chapters; rest frame = where its motion settles
tl.tween(0.2, 0.8, { x: 120 }, "smooth");           // eased: linear in out inOut smooth there backOut
tl.tween(1.0, 0.6, { n: [0, 15] }, "linear");       // explicit [from, to]
tl.tween(1.0, 0.6, { col: "--accent" });            // colours: role tokens or hex, mixed in OKLab
tl.pulse(2.0, 1.2, "hl");                           // emphasis: 0 -> 1 -> 0
tl.set(3.0, { label: "after" });                    // instant
function render(s, t, H) {
  H.attrs(el, { cx: s.x });  H.count(numEl, s.n);   // integer counter with grouping
  H.drawOn(lineEl, s.d);                            // stroke draw-on: 0 hidden, 1 drawn (follows the path direction)
  el.style.fill = H.mix("--quiet", "--accent", s.hl);  // highlight by mixing role colours
  H.fade(el, s.o);                                  // opacity with a true hidden state (not linted when gone)
}
```

The page: `scripts/explainer.py page(out, title, h1, stage, script, dek, shows, leaves, foot)` inlines the
stylesheet, `explainer.css` and the engine into one offline file and builds the player (Back, Play/Pause,
Next, a labelled scrubber, step dots, "Step n of N", an `aria-live` caption).

Interactive: `Viz.explorer({ svg, params, sliders: {n: "#n"}, handles: [["#node", (x, y, p) => ...]], render, sweep })`.
Sliders and draggable handles (pointer and arrow keys) set parameters; `render(p, H)` recomputes live; `sweep`
lists the parameter values figlint checks. Template: `templates/explorer-template.py`.

## Motion rules

1. **Continuity of objects.** Things that persist move, morph and recolour; they do not fade out and back
   in. When a ring gains a node, the existing nodes slide along the arc to their new places, then the new
   one grows in.
2. **One change at a time, eased.** 0.4-1 s per motion; smootherstep (`smooth`) or `inOut` for moves,
   `backOut` for things arriving, `there` for emphasis. Nothing animates on first paint.
3. **The formula moves with the drawing.** Each term appears as the thing it counts appears, lit in the
   accent while it is the subject, with an underline that follows it; the matching objects light up at the
   same moment (the factor `n` with the systems, `(n - 1)` with one system's links).
4. **Highlight the current element, then let it settle.** New links draw in the accent and fade to neutral
   when their step ends; the newest term stays lit until the next one arrives.
5. **Reserve space.** Everything that will appear has its place from the start: rows of terms are
   left-aligned to the final line's width, counters right-align the numeral and left-align the word. Nothing
   shifts when later items arrive (record W17). A reserved area may look empty in step 1: justify the
   `empty-space` warning in the log.
6. **Reader-started, no loops.** Play holds on each rest frame for reading time (`hold`, default 1.5 s), stops
   at the end. Next plays the next step's motion and stops at its rest frame; Back jumps.
7. **Reduced motion.** Under `prefers-reduced-motion: reduce`, Play jumps rest frame to rest frame with a 6 s
   dwell and no tweens; scrubbing still works.
8. **Print.** The key frame (`printTime`, default the end) and every caption as a numbered list; controls and
   the "Press Play" line are hidden. A printed explainer must stand alone.
9. **Captions carry the numbers**, one or two sentences per step, stating the finding of that step.

## Checking motion

figlint samples every rest frame AND every 0.1 s while anything moves (`window.VIZ.samples`), in light and
dark at two widths, plus the print frame. The proof explainer: 989 frames, 0 errors. A deliberately bad
test (a label sliding through another, clear at both rests) is caught at the moving frame only
(`examples/proof/negative/transition-collision.html`). For fast motion, sample finer: the interval should be
shorter than the time a moving label takes to cross its own width (`--sample 0.05`).

Contrast, orphans, prose and empty space are checked at rest frames only (a fade is transient by design);
overlap, clipping, crossing, lines through text and text size are checked in every frame.

## Look at motion

`node scripts/render_png.mjs --frames all --sample 0.25 --sheet out/x.html` writes every transition frame and
one contact sheet per theme and width; read the sheet first, then any frame that looks wrong.

## Export

The page is the deliverable. For a deck, use the print key frame as a static figure, or render the rest
frames to PNG at device scale 2 (one per slide). Never paste a screenshot of a figure into a deck at a size
where its labels fall below 10 px (record F13).
