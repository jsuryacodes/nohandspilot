// Renders Pilot.app's icons from public/favicon.svg, so the Mac app and the site share one mark: npm run app-icon
// Writes app/Resources/AppIcon.icns (Apple's grid: 824 body in a 1024 canvas, soft shadow) and the menu-bar
// template MenuIcon.png / MenuIcon@2x.png (hand and wave only, black on clear; macOS tints it).
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from '@playwright/test';

const web = fileURLToPath(new URL('..', import.meta.url));
const out = join(web, '../app/Resources');
const svg = readFileSync(join(web, 'public/favicon.svg'), 'utf8');
// At 16 and 32 px the thin seven-bump wave turns to mush: fewer, bigger bumps and a thicker stroke.
const small = svg
  .replace(/ d="M5 42\.5[^"]*"/, ' d="M4 42.5C9 42.5 11 37 17.5 37C24 37 26 48 32 48C38 48 40 37 46.5 37C53 37 55 42.5 60 42.5"')
  .replace('stroke-width="7.8"', 'stroke-width="11"')
  .replace('stroke-width="3.4"', 'stroke-width="5.4"');
// Menu bar: drop the tile and the outline, paint everything black, crop to the mark.
const template = (s) =>
  s
    .replace(/<rect width="64" height="64" fill="url\(#bg\)"\/>/, '')
    .replace(/<rect x="\.5"[^>]*\/>/, '')
    .replace(/clip-path="url\(#tile\)"/, '')
    .replaceAll('#F2EDE4', '#000')
    .replace('#FFB02E', '#000')
    .replace('viewBox="0 0 64 64"', 'viewBox="3 7 58 58"');

const browser = await chromium.launch();
const page = await browser.newPage();
async function png(markup, px, file, { grid = true } = {}) {
  await page.setViewportSize({ width: px, height: px });
  // Apple grid: the body is 824/1024 of the canvas, centred, with a soft drop shadow underneath.
  const inner = grid ? (px * 824) / 1024 : px;
  const shadow = grid ? `filter: drop-shadow(0 ${px * 0.012}px ${px * 0.02}px rgb(0 0 0 / .32))` : '';
  await page.setContent(`<!doctype html><style>*{margin:0}body{width:${px}px;height:${px}px;display:grid;place-items:center;background:transparent}
    svg{width:${inner}px;height:${inner}px;${shadow}}</style>${markup}`);
  await page.screenshot({ path: file, omitBackground: true });
}

const tmp = mkdtempSync(join(tmpdir(), 'pilot-icon-'));
const set = join(tmp, 'AppIcon.iconset');
mkdirSync(set);
mkdirSync(out, { recursive: true });
for (const pt of [16, 32, 128, 256, 512])
  for (const scale of [1, 2]) {
    const px = pt * scale;
    await png(px <= 32 ? small : svg, px, join(set, `icon_${pt}x${pt}${scale === 2 ? '@2x' : ''}.png`));
  }
execFileSync('iconutil', ['-c', 'icns', set, '-o', join(out, 'AppIcon.icns')]);
// 18 pt menu-bar template; the small variant keeps the wave legible at 18 px.
await png(template(small), 18, join(out, 'MenuIcon.png'), { grid: false });
await png(template(svg), 36, join(out, 'MenuIcon@2x.png'), { grid: false });
// Previews for checking by eye (not shipped).
for (const px of [16, 32, 64, 1024]) await png(px <= 32 ? small : svg, px, join(tmp, `preview-${px}.png`));
console.log(`Wrote ${out}/AppIcon.icns, MenuIcon.png, MenuIcon@2x.png. Previews: ${tmp}`);
await browser.close();
