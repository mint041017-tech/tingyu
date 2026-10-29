import { chromium } from 'playwright-core';
import { writeFile } from 'node:fs/promises';

const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
const context = await browser.newContext({ viewport: { width: 393, height: 852 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, locale: 'zh-CN' });
const page = await context.newPage();
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push(String(e)));
await page.addInitScript(() => {
  if (sessionStorage.getItem('tingyu.e2e.seeded')) return;
  sessionStorage.setItem('tingyu.e2e.seeded', '1');
  localStorage.setItem('tingyu.theme', 'light');
  localStorage.setItem('tingyu.pomodoro', JSON.stringify({
    settings: { focus: 1, short: 1, long: 1, longEvery: 2, chimeVolume: 40, chimeKind: 'bell', autoStart: false, playWithFocus: false, pauseOnBreak: true, chime: true, notify: false },
    phase: 'focus', remaining: 60, running: false, completed: false, focusInCycle: 0, sessions: [],
  }));
});
const nav = () => page.locator('flt-semantics [role="button"]').filter({ hasText: /^专注/ }).first();
await page.goto('http://127.0.0.1:8140/', { waitUntil: 'networkidle' });
await page.waitForTimeout(3000);
await nav().click({ force: true });
await page.waitForTimeout(500);
await page.evaluate(() => { window.__chimeCalls = 0; const original = window.tingyuChime; window.tingyuChime = (...args) => { window.__chimeCalls += 1; return original(...args); }; });
await page.locator('flt-semantics [role="button"]').filter({ hasText: /开始专注/ }).first().click({ force: true });
await page.waitForTimeout(2500);
const running = await page.evaluate(() => JSON.parse(localStorage.getItem('tingyu.pomodoro')));
await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(3200);
const afterReload = await page.evaluate(() => JSON.parse(localStorage.getItem('tingyu.pomodoro')));
await nav().click({ force: true });
await page.waitForTimeout(500);
await page.evaluate(() => { window.__chimeCalls = 0; const original = window.tingyuChime; window.tingyuChime = (...args) => { window.__chimeCalls += 1; return original(...args); }; });
const resumedLabel = await page.evaluate(() => [...document.querySelectorAll('flt-semantics [role="button"]')].map(e => e.textContent.trim()).find(t => /^专注 \d\d:\d\d/.test(t)) || null);
await page.waitForFunction(() => {
  const el = document.querySelector('flt-semantics');
  return el && el.textContent.includes('开始休息');
}, null, { timeout: 90000 }).catch(() => null);
await page.waitForTimeout(1200);
const finalState = await page.evaluate(() => {
  const raw = JSON.parse(localStorage.getItem('tingyu.pomodoro'));
  return { phase: raw.phase, running: raw.running, sessions: raw.sessions, focusInCycle: raw.focusInCycle, chimeCalls: window.__chimeCalls, text: document.querySelector('flt-semantics')?.textContent?.slice(0, 900) };
});
await page.screenshot({ path: 'build/ui/pomodoro-complete.png' });
await page.locator('flt-semantics [role="button"]').filter({ hasText: '切换明暗主题' }).first().click({ force: true });
await page.waitForTimeout(600);
const theme = await page.evaluate(() => localStorage.getItem('tingyu.theme'));
await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(2800);
const persistedTheme = await page.evaluate(() => localStorage.getItem('tingyu.theme'));
await writeFile('build/ui/pomodoro-e2e.json', JSON.stringify({ at: new Date().toISOString(), errors, running: { running: running.running, endAt: running.endAt }, afterReload: { running: afterReload.running, remaining: afterReload.remaining, endAt: afterReload.endAt }, resumedLabel, finalState, theme, persistedTheme }, null, 2), 'utf8');
console.log(JSON.stringify({ errors, running: { running: running.running, endAt: running.endAt }, afterReload: { running: afterReload.running, remaining: afterReload.remaining }, resumedLabel, finalState: { phase: finalState.phase, running: finalState.running, sessions: finalState.sessions, chimeCalls: finalState.chimeCalls, text: finalState.text?.slice(0, 260) }, theme, persistedTheme }, null, 2));
await browser.close();
