// pw.mjs: find an installed Playwright and launch Chrome, without hard-coding any cache path.
// Search order: $PLAYWRIGHT_MODULE (path to a playwright package dir or its index.mjs), a normal
// resolution from the current directory and from this script, the global npm root, then every
// npx cache under ~/.npm/_npx (newest first). Browser: installed Google Chrome (channel "chrome"),
// falling back to Playwright's bundled Chromium.
import fs from 'fs';
import path from 'path';
import os from 'os';
import { createRequire } from 'module';
import { execSync } from 'child_process';
import { pathToFileURL, fileURLToPath } from 'url';

const HERE = path.dirname(fileURLToPath(import.meta.url));

function candidates() {
  const out = [];
  const env = process.env.PLAYWRIGHT_MODULE;
  if (env) out.push(env.endsWith('.mjs') || env.endsWith('.js') ? env : path.join(env, 'index.mjs'));
  for (const base of [process.cwd(), HERE]) {
    try { out.push(createRequire(path.join(base, 'noop.js')).resolve('playwright').replace(/index\.js$/, 'index.mjs')); } catch {}
  }
  try {
    const g = execSync('npm root -g', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    if (g) out.push(path.join(g, 'playwright', 'index.mjs'));
  } catch {}
  const npx = path.join(os.homedir(), '.npm', '_npx');
  try {
    const dirs = fs.readdirSync(npx).map(d => path.join(npx, d, 'node_modules', 'playwright', 'index.mjs'))
      .filter(p => fs.existsSync(p))
      .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
    out.push(...dirs);
  } catch {}
  return [...new Set(out)].filter(p => fs.existsSync(p));
}

export async function loadPlaywright() {
  const tried = candidates();
  for (const p of tried) {
    try { const m = await import(pathToFileURL(p).href); if (m.chromium) return m; } catch {}
  }
  console.error(`Playwright not found. Searched: $PLAYWRIGHT_MODULE, node resolution from ${process.cwd()} and ${HERE},
the global npm root, and ~/.npm/_npx/*. Install it once with either:
  npx -y playwright@1 --version          (puts a copy in the npx cache, which this script finds)
  npm i -g playwright                     (global install)
or point PLAYWRIGHT_MODULE at a playwright package directory.`);
  process.exit(3);
}

export async function launch(opts = {}) {
  const { chromium } = await loadPlaywright();
  try { return await chromium.launch({ channel: 'chrome', headless: true, ...opts }); }
  catch (e1) {
    try { return await chromium.launch({ headless: true, ...opts }); }
    catch (e2) {
      console.error(`Could not launch Chrome or Playwright's Chromium.\n  chrome: ${e1.message.split('\n')[0]}\n  bundled: ${e2.message.split('\n')[0]}
Install Google Chrome, or run: npx playwright install chromium
If you are inside a sandbox, run the command with the sandbox disabled (Chrome needs it).`);
      process.exit(3);
    }
  }
}

// Real Chrome can take ~20 s to exit after a headless session (measured 26 October 2026). Do not wait for it:
// give close() a moment, then let the caller exit (Playwright kills the child process on exit).
export async function closeFast(browser, ms = 1500) {
  await Promise.race([browser.close().catch(() => {}), new Promise(r => setTimeout(r, ms))]);
}
