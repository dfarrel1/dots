// render_png: render figures and explainers to PNG so you can LOOK at them (the critique loop, references/critique-loop.md).
// usage: node render_png.mjs [options] <file.html|file.svg|dir> ...
//   --out <dir>          output directory (default ./png)
//   --themes light,dark  --widths 900,680   --scale 2 (device scale; never under 1.5: record F24)
//   --print              also render the print layout (light, 691 px column)
//   --frames all|rest|<t1,t2,...>   timeline explainers: every rest frame (default 'rest'), every transition sample
//                        ('all', at --sample seconds), or given times. Explorers render every sweep value.
//   --sheet              also write one contact sheet per file per theme (all frames as thumbnails), for scanning motion
//   --css <file>         stylesheet for bare .svg files (default ../templates/viz.css)
// Output names: <name>-<theme>-<width>[-t<time>|-p<n>].png; the figure is clipped to its <figure>/.stage when present.
import fs from 'fs'; import path from 'path'; import { fileURLToPath } from 'url';
import { launch, closeFast } from './pw.mjs';
const HERE = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const o = { out: 'png', themes: ['light', 'dark'], widths: [900, 680], scale: 2, print: false, frames: 'rest', sample: 0.25, sheet: false, css: path.join(HERE, '../templates/viz.css') };
const inputs = [];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--out') o.out = argv[++i]; else if (a === '--themes') o.themes = argv[++i].split(',');
  else if (a === '--widths') o.widths = argv[++i].split(',').map(Number); else if (a === '--scale') o.scale = +argv[++i];
  else if (a === '--print') o.print = true; else if (a === '--frames') o.frames = argv[++i];
  else if (a === '--sample') o.sample = +argv[++i]; else if (a === '--sheet') o.sheet = true; else if (a === '--css') o.css = argv[++i];
  else inputs.push(a);
}
if (o.scale < 1.5) { console.error('render_png: --scale under 1.5 makes a 10 px label and a clipped one look alike; refusing'); process.exit(2); }
const collect = p => fs.statSync(p).isDirectory() ? fs.readdirSync(p).flatMap(f => collect(path.join(p, f))) : (/\.(html|svg)$/.test(p) && !path.basename(p).startsWith('_') ? [path.resolve(p)] : []);
const files = inputs.flatMap(collect);
fs.mkdirSync(o.out, { recursive: true });
const b = await launch();
const written = [];
async function shot(page, name) {
  const el = await page.$('.stage') || await page.$('figure') || await page.$('main') || await page.$('body');
  const target = path.join(o.out, name + '.png');
  // .stage + .player together when present: the caption is part of what the reader sees
  const box = await page.evaluate(() => {
    const s = document.querySelector('.stage'); if (!s) return null; const p = document.querySelector('.player');
    const a = s.getBoundingClientRect(), c = p ? p.getBoundingClientRect() : a;
    return { x: Math.max(0, a.left - 4), y: Math.max(0, a.top - 4 + scrollY), width: a.width + 8, height: c.bottom - a.top + 8 };
  });
  if (box) await page.screenshot({ path: target, clip: box, fullPage: true }); else await el.screenshot({ path: target });
  written.push(target); return target;
}
for (const f of files) {
  const base = path.basename(f).replace(/\.(html|svg)$/, '');
  const runs = o.themes.flatMap(t => o.widths.map(w => [t, w, null]));
  if (o.print) runs.push(['light', 691, 'print']);
  for (const [scheme, width, media] of runs) {
    const page = await b.newPage({ viewport: { width, height: 1000 }, deviceScaleFactor: o.scale, colorScheme: scheme });
    if (media) await page.emulateMedia({ media });
    if (f.endsWith('.svg')) await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><style>${fs.readFileSync(o.css, 'utf8')}</style></head><body><main><figure><div class="fig">${fs.readFileSync(f, 'utf8')}</div></figure></main></body></html>`);
    else await page.goto('file://' + f);
    await page.waitForTimeout(250);
    const tag = `${base}-${media ? 'print' : scheme}-${width}`;
    const kind = await page.evaluate(() => (window.VIZ && window.VIZ.kind) || 'static');
    const shots = [];
    if (media) {
      await page.evaluate(() => { if (window.VIZ && window.VIZ.kind === 'timeline') window.VIZ.seek(window.VIZ.printTime); });
      const t = path.join(o.out, tag + '.png'); await page.screenshot({ path: t, fullPage: true }); written.push(t);
    } else if (kind === 'timeline') {
      let times;
      if (o.frames === 'rest') times = (await page.evaluate(() => window.VIZ.chapters.map(c => c.rest)));
      else if (o.frames === 'all') times = (await page.evaluate(dt => window.VIZ.samples(dt).map(s => s.t), o.sample));
      else times = o.frames.split(',').map(Number);
      for (const t of times) { await page.evaluate(t => window.VIZ.seek(t), t); shots.push(await shot(page, `${tag}-t${t.toFixed(2)}`)); }
    } else if (kind === 'explorer') {
      const sweep = await page.evaluate(() => window.VIZ.sweep);
      for (let i = 0; i < sweep.length; i++) { await page.evaluate(v => window.VIZ.apply(v), sweep[i]); shots.push(await shot(page, `${tag}-p${i + 1}`)); }
    } else shots.push(await shot(page, tag));
    await page.close();
    if (o.sheet && shots.length > 1) {
      // frames are embedded as data URIs so the sheet never screenshots before its images load
      const imgs = shots.map(s => `<figure><img src="data:image/png;base64,${fs.readFileSync(s).toString('base64')}"><figcaption>${path.basename(s, '.png').split('-').pop()}</figcaption></figure>`).join('');
      const sheetHtml = path.resolve(o.out, `_${tag}-sheet.html`);
      fs.writeFileSync(sheetHtml, `<!doctype html><style>body{margin:8px;font:12px Helvetica,Arial,sans-serif;display:grid;grid-template-columns:repeat(4,1fr);gap:6px}figure{margin:0}img{width:100%;border:1px solid #999}</style>${imgs}`);
      const sp = await b.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 1 });
      await sp.goto('file://' + sheetHtml);
      await sp.waitForTimeout(300);
      const t = path.join(o.out, `${tag}-sheet.png`); await sp.screenshot({ path: t, fullPage: true }); written.push(t); await sp.close(); fs.rmSync(sheetHtml);
    }
  }
}
await closeFast(b);
console.log(written.join('\n'));
console.log(`render_png: ${written.length} images in ${o.out}. Now read each one with the Read tool and log what you see.`);
process.exit(0);
