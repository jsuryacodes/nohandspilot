// Renders public/og.png (1200×630, the link preview) from the site's own fonts, colours and icon: npm run og
import { readFileSync } from 'node:fs';
import { chromium } from '@playwright/test';

const root = new URL('..', import.meta.url);
const font = (pkg, file) =>
  `data:font/woff2;base64,${readFileSync(new URL(`node_modules/@fontsource-variable/${pkg}/files/${file}`, root)).toString('base64')}`;
const icon = readFileSync(new URL('public/favicon.svg', root), 'utf8');

const html = `<!doctype html><meta charset="utf-8"><style>
@font-face { font-family: Fraunces; src: url(${font('fraunces', 'fraunces-latin-opsz-normal.woff2')}); font-weight: 100 900; }
@font-face { font-family: Instrument; src: url(${font('instrument-sans', 'instrument-sans-latin-wght-normal.woff2')}); font-weight: 400 700; }
@font-face { font-family: JetBrains; src: url(${font('jetbrains-mono', 'jetbrains-mono-latin-wght-normal.woff2')}); font-weight: 100 800; }
* { margin: 0; box-sizing: border-box; }
body { width: 1200px; height: 630px; padding: 64px 72px; background: #08090b radial-gradient(70% 70% at 30% 0%, rgb(242 237 228 / .08), transparent);
  color: #f2ede4; font-family: Instrument; display: flex; flex-direction: column; -webkit-font-smoothing: antialiased; }
.brand { display: flex; align-items: center; gap: 16px; font: 400 30px Fraunces; letter-spacing: -.01em; }
.brand svg { width: 56px; height: 56px; }
h1 { margin-top: 44px; font: 380 84px/0.98 Fraunces; letter-spacing: -.022em; max-width: 900px; }
p { margin-top: 24px; font-size: 28px; color: rgb(242 237 228 / .68); }
.said { margin-top: auto; font: 400 22px JetBrains; color: rgb(242 237 228 / .68); }
.hud { margin-top: 16px; display: inline-flex; align-self: flex-start; gap: 12px; padding: 14px 20px; border-radius: 12px;
  background: #1e2227; box-shadow: 0 0 0 1px rgb(242 237 228 / .09); font-size: 24px; }
.hud b { color: #ffb02e; font-weight: 400; }
</style>
<div class="brand">${icon}No Hands Pilot</div>
<h1>Use your Mac without touching it.</h1>
<p>Wispr Flow is the ears. Pilot is the hands.</p>
<div class="said">"Pilot, open Chrome, new tab, search for Docker networking"</div>
<div class="hud"><b>✓</b>Opened Google Chrome → New tab → Searching Docker networking</div>`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
await page.setContent(html);
await page.evaluate(() => document.fonts.ready);
await page.screenshot({ path: new URL('public/og.png', root).pathname });
await browser.close();
console.log('public/og.png');
