import { chromium } from 'playwright-core';
import { mkdir, writeFile } from 'node:fs/promises';

const browser = await chromium.launch({
  executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  headless: true,
  args: ['--autoplay-policy=no-user-gesture-required'],
});
const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, locale: 'zh-CN' });
const page = await context.newPage();
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push(String(e)));
await page.goto('http://127.0.0.1:8140/', { waitUntil: 'networkidle' });
await page.waitForTimeout(3200);
const play = page.locator('flt-semantics [role="button"]').filter({ hasText: '播放声音' }).first();
await play.click({ force: true });
let state = null;
for (let i = 0; i < 20; i++) {
  await page.waitForTimeout(750);
  state = await page.evaluate(() => {
    try {
      const snap = JSON.parse(window.tingyuSnapshot());
      const diag = window.tingyuDiagnostics();
      return { playing: snap.playing, tracks: snap.tracks.length, context: diag.context.state, sources: diag.sources.length, rms: diag.rms, error: snap.error };
    } catch (e) { return { error: String(e) }; }
  });
  if (state.playing && state.sources >= 1 && state.rms > 0) break;
}
await page.screenshot({ path: 'build/ui/audio-playing.png' });
const chime = await page.evaluate(() => { try { return window.tingyuChime('bell', 0.5); } catch (e) { return String(e); } });
await writeFile('build/ui/audio-check.json', JSON.stringify({ at: new Date().toISOString(), errors, state, chime }, null, 2), 'utf8');
console.log(JSON.stringify({ errors, state, chime }, null, 2));
await browser.close();
