# Public exemplars: techniques to take

What this file is for: lift the techniques that make the best public figures and explainers work, and build them into this skill's timeline engine, patterns, chart rules and critique checklist. Take ideas, not assets. Every figure here is drawn fresh as hand-laid SVG with our own tokens. Code is copied only where the licence allows it (manim MIT, D3 ISC), with attribution, and even then describing the idea is usually better than copying it.

Every link below was fetched or came back in a search during research on 2026-10-26. Where a page failed or did not cover a point, the entry says so.

Skill targets used in the "maps into" lines:
- **engine**: the JS timeline engine (tweens, easing, scrubbable timeline, formula-sync)
- **pattern**: a reusable figure or explainer pattern
- **chart rule**: a rule for static charts
- **checklist**: an item in the critique checklist or a browser lint gate

---

## 1. 3Blue1Brown / manim

Links (fetched):
- Community edition repo, MIT, dual copyright 3Blue1Brown LLC and Manim Community Developers: https://github.com/ManimCommunity/manim
- 3b1b original (`manimgl`), MIT: https://github.com/3b1b/manim
- TransformMatchingTex: https://docs.manim.community/en/stable/reference/manim.animation.transform_matching_parts.TransformMatchingTex.html
- ReplacementTransform: https://docs.manim.community/en/stable/reference/manim.animation.transform.ReplacementTransform.html
- Indication animations: https://docs.manim.community/en/stable/reference/manim.animation.indication.html
- Rate functions: https://docs.manim.community/en/stable/reference/manim.utils.rate_functions.html
- ValueTracker: https://docs.manim.community/en/stable/reference/manim.mobject.value_tracker.ValueTracker.html
- MathTex (colouring formula parts): https://docs.manim.community/en/stable/reference/manim.mobject.text.tex_mobject.MathTex.html
- Example gallery: https://docs.manim.community/en/stable/examples.html

Techniques to take:
- **One scalar drives the scene.** A `ValueTracker` is an invisible number. Visible objects carry updaters that re-read it every frame. Animate the number, and everything that depends on it follows. Examples: `MovingAngle` (angle, its label and the line all follow `theta_tracker`) and `PolygonOnAxes` (`always_redraw` rebuilds a rectangle from the tracked value).
- **Transform vs ReplacementTransform.** `Transform` morphs A's shape into B's but the scene keeps A. `ReplacementTransform` swaps A out for B. In our engine, decide which element id survives a morph so later steps target the right node.
- **Match formula parts by content.** `TransformMatchingTex` pairs sub-expressions whose TeX strings are equal. Matched parts move to their new place, unmatched parts fade or morph (`transform_mismatches`, `fade_transform_mismatches`, `key_map` for manual pairings). Rearranging an equation becomes visible motion instead of a cut.
- **Colour-code terms with the objects they describe.** `MathTex` splits a formula with `{{ ... }}` groups, `substrings_to_isolate`, and `tex_to_color_map` or `set_color_by_tex`. The term `a^2` gets the same colour as the square drawn on side a. `set_opacity_by_tex` dims the terms not in play.
- **Highlight verbs as a small vocabulary.** `Indicate` (brief resize and recolour), `Circumscribe` (temporary outline), `Flash`, `FocusOn` (spotlight closes in), `ShowPassingFlash` (a sliver travels along a path), `Wiggle`. Each one is short-lived and returns the object to its resting state.
- **Rate functions are named and swappable.** `smooth`, `linear`, `there_and_back`, `rush_into`/`rush_from`, and the `ease_in_*`/`ease_out_*` families. `there_and_back` suits highlights that should return to rest. The rate-functions page lists `smooth` but does not say it is the `Animation` default, so that point is unconfirmed here.
- **Traced paths.** `PointWithTrace` grows a path behind a moving dot with an updater. The trail records history so the viewer sees where the point has been.

Maps into this skill:
- **engine**: a tracker primitive (named scalar, tweenable, with subscribers); `morph` with `keep` / `replace` semantics; a highlight verb set (`indicate`, `circumscribe`, `flash`, `focus`, `pulse-along-path`) that each end at rest; named easing functions including `thereAndBack`.
- **engine + pattern**: formula-sync. Formula terms carry `data-term="a2"`. The drawing carries the same key. One token sets the colour of both. Steps that highlight a term highlight its object too, and the reverse.
- **pattern**: equation rearrangement by matched keys, so terms slide to their new positions and the rest fades.

---

## 2. Bartosz Ciechanowski (ciechanow.ski)

Links (fetched): https://ciechanow.ski/gears/ , https://ciechanow.ski/bicycle/

Techniques to take:
- **Figure placed right after the sentence that says what to watch** ("watch the trace paths"), then a prompt to move a control and see the result.
- **Sliders are the main control.** They set one physical quantity (speed, force angle, radius ratio, pressure angle) or scrub a time axis. Several sliders in one figure are named in the prose by their order.
- **Drag where it is natural.** Drag rotates the 3D camera, or grabs a marked point on the object to set a direction (bicycle).
- **One new idea per figure.** Gears goes from one disc, to two friction discs, to meshing gears, to tooth profiles, to gear trains. Bicycle compares two otherwise-identical setups that differ in one variable.
- **Colour encodes role and keeps it all article long.** Driver yellow, driven green. Contact point and tangential force red, applied force grey.
- **Few formal captions.** Labels in the figure and the surrounding prose carry the explanation.
- **Play/pause on every animated figure**, plus a global pause. Inline links jump a figure to a preset state.

Maps into this skill:
- **pattern**: the "progressive build" explainer, a sequence of figures each adding exactly one element, sharing tokens and layout.
- **engine**: a time slider bound to the timeline playhead; per-figure play/pause; preset-state links (`data-preset`) that tween to a stored state.
- **checklist**: does each figure introduce exactly one new thing? Is every colour role fixed across the whole piece?

---

## 3. Distill.pub

Links (fetched):
- Research Debt (Olah and Carter, 2017): https://distill.pub/2017/research-debt/
- Author guide: https://distill.pub/guide/
- Communicating with Interactive Articles (Hohman et al., 2020): https://distill.pub/2020/communicating-with-interactive-articles/

Techniques to take:
- **Interpretive labour.** The explainer pays once, every reader pays the cost of understanding. Spend effort on the figure so the reader spends less. Good explanation often restructures the idea and its notation, not just its prose.
- **Static base, animate the parts.** For a complex diagram where only some parts move, draw it statically, tag elements with classes or ids, and drive only those (author guide). This matches hand-laid SVG plus an engine.
- **Layout widths as a vocabulary.** Body, middle, page, screen, gutter, and floated side variants. A figure picks its width on purpose; marginalia go in the gutter.
- **Link equations to text.** Hover a term to highlight its plain-language meaning (Hohman et al.).
- **Predict before reveal.** "You Draw It" asks the reader to sketch the trend first, then shows the data.
- **Multiple representations side by side** (algebraic and geometric). **Details on demand** via hover and tap. **Segmented content** with play, pause and scrub.
- **Cautions.** Not everything needs to be interactive. Interactive pieces cost far more to make. They need accessible alternatives. Evidence on scrollytelling versus steppers is mixed, and one study found better comprehension with slideshows.
- The author guide gives no specific caption or accessibility guidance (checked, not present).

Maps into this skill:
- **engine**: hover-link between a formula term, its prose gloss and its drawn object (same `data-term` key as section 1).
- **pattern**: predict-then-reveal; side-by-side representations sharing one model.
- **checklist**: "does this need to be interactive at all?"; every interactive figure has a static fallback frame and a text description.

---

## 4. Red Blob Games (Amit Patel)

Links (fetched):
- Making of: line drawing: https://www.redblobgames.com/making-of/line-drawing/
- Little things: https://www.redblobgames.com/making-of/little-things/
- Draggable objects: https://www.redblobgames.com/making-of/draggable/
- Curved paths, making of: https://www.redblobgames.com/articles/curved-paths/making-of.html

Techniques to take:
- **Inputs are draggable, outputs are recomputed.** Put handles on the algorithm's inputs (line endpoints). On drag, update the input, then call `update()`, which recomputes outputs and redraws.
- **Keep the algorithm separate from drawing.** A pure function (`pointsOnLine`) computes outputs from inputs. Layers only render.
- **Diagram object with layers.** One object holds the inputs and the SVG root. Each visual layer is a `<g>` with its own update function registered via `onUpdate()`. `update()` runs them all. Build diagrams by chaining `addGrid()`, `addTrack()`, `addHandles()`.
- **Scrubbable numbers drive the same loop.** An inline number in the prose writes a diagram field and calls `update()`.
- **Two-way handle mapping.** Getter maps model value to pixel position; setter maps pointer position back to the value. Chainable modifiers: `clamped`, `rounded`, `add`, `multiply`, `cartesian`.
- **Build order.** Split the algorithm into steps, one diagram per step, polish last. Polish = bounds, larger invisible hit areas, cursor feedback.
- **Pointer details.** Pointer events for mouse and touch; pointer capture so drag continues outside the element; primary button only; store the grab offset so the object does not jump; `preventDefault()` on `touchstart` of the handle only, rather than `touch-action: none` on the whole diagram, so the page still scrolls.
- **Little things.** Invisible hit area under small handles; grab cursor; hover and drag feedback; controls below the figure so fingers do not hide it; saturated colour only on small important marks; the same colours in diagram, prose and controls; draw legend swatches inline in the text; native controls first for accessibility.

Maps into this skill:
- **engine**: a reactive model (`state` object, `set(key, v)` triggers `update()`), a layer registry, a drag helper (pointer capture, offset, clamp, round, invisible hit area), and scrubbable inline numbers bound to the same state.
- **pattern**: "one model, several linked views". Every view is a pure render of shared state.
- **checklist**: hit area at least about 44px; drag works with touch without trapping page scroll; handles have a cursor and hover state; keyboard alternative (native range input) exists.

---

## 5. Nicky Case (ncase.me, explorables)

Links:
- Essay on explorable explanation practice (fetched): https://blog.ncase.me/explorable-explanations/
- https://ncase.me/explorable-explanations/ returned 404.
- Search only: Data Stories episode 103 with Case, https://datastori.es/103-explorable-explanations-with-nicky-case/ ; archive https://www.ncase.me/archive

Techniques to take:
- **Use the right medium.** Interactivity for processes, systems and models. Text for abstractions, graphs for broad relationships, animation for change over time.
- **Hook, build, conclude.** Open with something that needs no prior knowledge; build from basics; end on something that only makes sense after the earlier parts.
- **Start small, build big.** Teach each mechanic in isolation before combining.
- **Let the reader discover.** Let them generate data and form their own model, then give an embedded task ("make the gears jam", "find the angle that maximises range").
- **Gate content** until prerequisites are met. Guide without restricting: author-guided, player-driven.
- **Playtest.** Watch real people use it. The essay cites a piece that added gating after testers skimmed and got lost.
- Play-first framing: the search result attributes to Case the view that play conveys ideas deeper and faster than words and pictures. No single canonical "play first" essay was found.

Maps into this skill:
- **pattern**: explainer skeleton = hook, isolated mechanics, combined system, embedded task, payoff.
- **checklist**: does the opening work with no prior knowledge? Is there at least one task for the reader? Was it tried on a person who did not build it?

---

## 6. Bret Victor, "Explorable Explanations" (2011)

Link (fetched): https://worrydream.com/ExplorableExplanations/

Techniques to take:
- **Reactive documents.** Underlined numbers in the prose are model inputs; dragging one recomputes the conclusions in the sentence.
- **Explorable examples.** Instead of two static examples, let the reader run any parameter combination and find things the author did not mention (instability at low Q in the filter example).
- **Many representations change together.** The filter is shown six ways at once.
- **State where the model stops being right.** The filter formula is flagged as approximate outside a stated range.
- **Expose the model** so readers can check the reasoning. The 2024 postscript says the term originally meant an argument resting on visible, editable models, not any article with interactive graphics.

Maps into this skill:
- **engine**: scrubbable inline numbers (shared with section 4).
- **chart rule**: show the valid range of any model curve; shade or label where it is approximate.
- **checklist**: can the reader see and change the assumptions behind the conclusion?

---

## 7. Mike Bostock / D3 / Observable

Links (fetched):
- Object constancy: https://bost.ocks.org/mike/constancy/
- Thinking with joins: https://bost.ocks.org/mike/join/
- Towards Reusable Charts: https://bost.ocks.org/mike/chart/
- d3-interpolate (ISC licence in footer): https://d3js.org/d3-interpolate
- d3-transition overview: https://d3js.org/d3-transition (the overview page did not cover chaining, delay or `end()` in detail; those points come from the API as known, verify on the Control flow and Timing subpages)

Related research (search results, PDF not read): Heer and Robertson, "Animated Transitions in Statistical Data Graphics", InfoVis 2007, https://idl.uw.edu/papers/animated-transitions . The project page shows a staged scatter-to-bar transition: move points to x first and update the axis, then morph points into bars.

Techniques to take:
- **Object constancy.** A mark that stands for one datum stays that mark through a transition, so the eye tracks motion instead of rereading labels. Key every mark by a stable id, never by index; index joins make misleading motion.
- **Animate only meaningful change.** Filter, sort, change dimension: animate. Switch to unrelated data: cross-fade or cut.
- **Enter / update / exit.** Declare which marks correspond to which data. New data enters (grow in), persisting data updates (move), removed data exits (shrink out). Empty sets are no-ops, so no special cases.
- **Set constants on enter, varying attributes on update.** Fewer DOM writes.
- **Reusable chart = closure plus getter-setters.** `chart.width(640).height(400)`; call with no argument to read. Defaults are private and overridable. Apply to a selection so one chart renders many panels.
- **Interpolate colour in a perceptual space.** `interpolateLab`, `interpolateHcl` (shortest or long hue path), `interpolateCubehelix` (monotonic lightness), `interpolateRgb.gamma(2.2)`. RGB midpoints go muddy. `quantize(interp, n)` turns a continuous ramp into n discrete swatches.
- **Interpolate structure.** `interpolateString` tweens the numbers inside a string (an SVG path `d`, a transform); `interpolateObject` tweens shared keys.
- **Staged transitions.** Chain `transition().transition()` so stage two starts when stage one ends; stagger with a per-element `delay((d, i) => i * k)`; `end()` returns a promise; a new transition with the same name interrupts the old one.

Maps into this skill:
- **engine**: keyed marks (`data-key`) and an enter/update/exit diff for SVG groups; tween colour in OKLab/Lab or HCL, never raw RGB; string/path tweening; stage chaining with per-element stagger; interrupt-on-retarget so scrubbing never stacks tweens.
- **pattern**: staged transitions between chart forms (axis first, then marks).
- **chart rule**: sequential ramps are built by interpolating in a perceptual space and quantising to n steps.
- **checklist**: lint that every animated mark has a stable key; that no transition animates between unrelated datasets.

---

## 8. NYT and Reuters graphics desks

Links:
- Amanda Cox interview, Simply Statistics, 2012 (fetched): https://simplystatistics.org/posts/2012-06-01-interview-with-amanda-cox-graphics-editor-at-the-new/
- 2015 talk recap listing "Annotation Layer" as a topic (search result, secondhand): https://www.ambriente.com/blog/?p=889
- Annotation guidance (search result): https://data.europa.eu/apps/data-visualisation-guide/visual-annotations-introduction
- Kosara, "The Scrollytelling Scourge", 2016 (fetched): https://eagereyes.org/blog/2016/the-scrollytelling-scourge
- Small multiples practice (search results): Pew, https://www.pewresearch.org/decoded/2018/12/20/how-pew-research-center-uses-small-multiple-charts/ ; ONS service manual, https://service-manual.ons.gov.uk/data-visualisation/chart-types/small-multiple-charts ; Datawrapper, https://www.datawrapper.de/blog/small-multiple-line-charts
- Reuters: searches found no Reuters Graphics write-up on annotation, small multiples or scrollytelling. Nothing here is attributed to Reuters.

Techniques to take:
- **Annotate the finding.** Words point at the pattern or the expert reading, not "here is some data". Cox: "The annotation layer is critical, even in a newspaper", and "If you annotate three points in a scatterplot, I'm probably good."
- **Keep annotation light.** Pointers, outlines, short notes over the graphic (talk recap, secondhand).
- **A graphic should read without the article** and must not feel like homework. Typography is hierarchy, not decoration.
- **Sliders imply a story** with a beginning, middle and end, even when the variable is not time. Movement must mean something.
- **Small multiples share one template and one scale**; only the data changes between panels. Title states the finding (Pew). Label reference lines or bands once, on the first panel (ONS). A highlight can repeat across all panels (Datawrapper).
- **Scrollytelling cautions (Kosara).** Scroll is continuous but stories have discrete steps; length is hidden; no direct access to a step; scroll-jacking; text scrolls past the graphic. Prefer a stepper with numbered steps and next/previous; animate between steps.

Maps into this skill:
- **chart rule**: a title that states the finding; direct labels at line ends; at most a few annotations, each pointing at a specific mark; small multiples use one shared scale and one template, reference lines labelled once.
- **engine**: stepper navigation (numbered steps, prev/next, keyboard) as the default sequencing control; scroll-trigger only as an opt-in.
- **checklist**: does the figure state its finding on the figure? Does it read without the surrounding text?

---

## 9. Edward Tufte

Links:
- Sparkline theory and practice (fetched): https://www.edwardtufte.com/notebook/sparkline-theory-and-practice-edward-tufte/
- Lecture notes summarising data-ink, chartjunk, lie factor (search results, not fetched): https://faculty.cc.gatech.edu/~stasko/7450/15/Notes/tufte.pdf ; IEEE Spectrum "Tufteisms", https://spectrum.ieee.org/tufteisms
- The books themselves were not fetched.

Techniques to take:
- **Show the data** above all else.
- **Data-ink ratio.** Maximise the share of ink that encodes non-redundant data. Gridlines, frames, legends and decoration are non-data ink; thin or remove them.
- **Chartjunk.** 3D effects, decorative gradients and ornament that carry no data and can hinder reading.
- **Lie factor** = size of effect shown / size of effect in the data. Aim for 1.0. Area or 3D encodings of a 1D quantity inflate it.
- **Small multiples.** Same design repeated across panels so the eye compares the data, not the design.
- **Sparklines.** Word-sized, typographic resolution, placed wherever a word or number goes. Aspect ratio chosen so the line looks lumpy, not spiky or flat. Mark the last value and tie it to its printed number by colour; mark min and max; show the normal range as a light grey band. No frames, tints or bars.

Maps into this skill:
- **chart rule**: default to no frame, light or no gridlines, direct labels instead of legends; bars start at zero; areas scale with value, not radius.
- **pattern**: inline sparkline with end-value dot, min/max marks and normal band.
- **checklist**: compute lie factor for any area or length encoding; flag 3D, gradients and decorative fills; flag a legend where direct labels would fit.

---

## Strongest techniques to build into the skill

Ranked by how much each improves a figure or explainer for the effort to build it. Items 1 to 6 are the six requested flags.

| # | Technique | Source | Where it goes in the skill | Licence note |
|---|---|---|---|---|
| 1 | Draggable parameters with live recompute: handles on inputs, pure compute function, layered `update()`, scrubbable numbers on the same state | Red Blob Games; Bret Victor | engine (reactive state, drag helper, scrubbable number) + pattern (one model, linked views) + checklist (hit area, touch, keyboard) | Idea only; write our own code |
| 2 | Synced formula-term colour highlighting: one `data-term` key colours the term, its object and its prose gloss; highlight one, highlight all; matched-key equation rearrangement | 3b1b manim (`MathTex` colour maps, `TransformMatchingTex`); Distill (link equations to text) | engine (formula-sync) + pattern (rearrangement) | manim MIT, attribute if any code is adapted; prefer reimplementing the idea |
| 3 | Object constancy: every animated mark keyed by a stable id; enter/update/exit; animate only meaningful change, cut between unrelated data | D3 / Bostock | engine (keyed diff) + checklist (lint for missing keys) | D3 ISC; idea only needed |
| 4 | Interpolate colour in a perceptual space (Lab/OKLab/HCL/cubehelix), quantise ramps to n steps | d3-interpolate | engine (colour tween) + chart rule (ramp construction) | D3 ISC; small interpolator code may be adapted with notice |
| 5 | Annotate the finding on the chart: finding-stating title, direct labels, a few pointers on specific marks | NYT (Cox); Tufte | chart rule + checklist | Idea only |
| 6 | Small multiples with shared scales: one template, one scale, reference lines labelled once, repeated highlight | Tufte; Pew; ONS; Datawrapper | chart rule + pattern | Idea only |
| 7 | One tracker drives the scene: tweenable named scalar with subscribers | manim `ValueTracker` | engine | manim MIT; idea only |
| 8 | Highlight verbs that return to rest (indicate, circumscribe, flash, focus) with `thereAndBack` easing | manim | engine | manim MIT; idea only |
| 9 | Progressive build: one new element per figure, fixed colour roles across the piece | Ciechanowski; Nicky Case | pattern + checklist | Idea only; his articles are not openly licensed, copy nothing |
| 10 | Stepper over scrollytelling: numbered steps, prev/next, animate between steps | Kosara; Distill (mixed evidence) | engine (default sequencing) | Idea only |
| 11 | Staged transitions: axis first, then marks; per-element stagger; interrupt on retarget | Heer and Robertson; d3-transition | engine | Idea only |
| 12 | Predict before reveal | Distill (You Draw It) | pattern | Idea only |
| 13 | Data-ink and lie factor checks; sparklines with end, min/max and normal band | Tufte | chart rule + checklist + pattern | Idea only |

## What this skill already implements from the list (27 October 2026)

| # | Technique | Where |
|---|---|---|
| 1 | Draggable parameters with live recompute, keyboard parity for handles, linked views | `Viz.explorer` (`sliders`, `handles`, `render(p)`); `templates/explorer-template.py` (slider + draggable point on a chart drive the drawing and a live formula) |
| 2 | Formula terms lit in step with the objects they count | `examples/proof/build_pairs_explainer.py`: tspans per term, `H.mix("--quiet", "--accent", h)` plus a following underline; the matching nodes and links light at the same moment. Not yet: a `data-term` key that also lights the caption's prose |
| 3 | Object constancy | state keyed by stable ids (`a3`, `d1_4`), objects persist and move rather than re-enter |
| 4 | Colour interpolation in a perceptual space | OKLab mixing of resolved role tokens in `timeline.js` (`mix`) and `tokens.py` (`color-mix(in oklab)` derivations) |
| 5 | Annotate the finding on the chart | `chartkit.Chart.annotate`, finding titles, direct end labels |
| 6 | Small multiples with one shared scale | `patterns.small_multiples` (one `Scale` for every panel; the note says so) |
| 7, 8 | One tracker drives the scene; emphasis that returns to rest | tweened state + `render(s)`; `tl.pulse()` with the `there` easing |
| 10 | Stepper first | chapters with Next/Back as the default; Play holds on each rest frame |
| 11 | Staged transitions | by authoring (ring re-spaces, then the node grows, then links draw); no automatic stagger helper yet |
