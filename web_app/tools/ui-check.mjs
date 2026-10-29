import { chromium } from 'playwright-core';
import { mkdir, writeFile } from 'node:fs/promises';

const origin = process.env.TINGYU_ORIGIN || 'http://127.0.0.1:8140/';
const browser = await chromium.launch({
  executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  headless: true,
  args: ['--autoplay-policy=no-user-gesture-required'],
});
await mkdir('build/ui', { recursive: true });
const errors = [];
const logs = [];

async function open(viewport, mobile = false) {
  const context = await browser.newContext({
    viewport, deviceScaleFactor: 1, isMobile: mobile, hasTouch: mobile, locale: 'zh-CN',
  });
  const page = await context.newPage();
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push(String(e)));
  await page.addInitScript(() => {
    localStorage.setItem('tingyu.pomodoro', JSON.stringify({
      settings: { focus: 25, short: 5, long: 15, longEvery: 4, playWithFocus: false, autoStart: false, chime: true, notify: false },
      phase: 'focus', remaining: 1500, running: false, completed: false, focusInCycle: 0, sessions: [],
    }));
    localStorage.setItem('tingyu.theme', 'light');
  });
  await page.goto(origin, { waitUntil: 'networkidle' });
  await page.waitForTimeout(3200);
  return { context, page };
}

async function button(page, pattern) {
  return page.locator('flt-semantics [role="button"]').filter({ hasText: pattern }).first();
}

async function clickText(page, pattern) {
  const b = await button(page, pattern);
  if (!(await b.count())) throw new Error(`button not found: ${pattern}`);
  await b.click({ force: true });
}

async function shot(page, name) {
  await page.screenshot({ path: `build/ui/${name}.png` });
}

const mobile = await open({ width: 393, height: 852 }, true);
await shot(mobile.page, 'm-home');
await clickText(mobile.page, /^专注$/);
await mobile.page.waitForTimeout(800);
await shot(mobile.page, 'm-pomodoro');
logs.push({ step: 'pomodoro labels', buttons: await mobile.page.locator('flt-semantics [role="button"]').evaluateAll(els => els.map(e => e.textContent.trim()).filter(Boolean).slice(0, 30)) });
const clockBefore = await mobile.page.evaluate(() => document.querySelector('flt-semantics')?.textContent ?? '');
await clickText(mobile.page, /开始专注/);
await mobile.page.waitForTimeout(2600);
await shot(mobile.page, 'm-pomodoro-running');
logs.push({ step: 'running labels', buttons: await mobile.page.locator('flt-semantics [role="button"]').evaluateAll(els => els.map(e => e.textContent.trim()).filter(Boolean).slice(0, 30)) });
await clickText(mobile.page, /暂停/);
await mobile.page.waitForTimeout(500);
await shot(mobile.page, 'm-pomodoro-paused');
await clickText(mobile.page, /切换明暗主题/);
await mobile.page.waitForTimeout(500);
await shot(mobile.page, 'm-pomodoro-dark');
await clickText(mobile.page, /^设置/);
await mobile.page.waitForTimeout(700);
await shot(mobile.page, 'm-settings');
await clickText(mobile.page, /^声音/);
await mobile.page.waitForTimeout(700);
await shot(mobile.page, 'm-library');
logs.push({ step: 'chime', value: await mobile.page.evaluate(() => { try { return window.tingyuChime('bell', 0.5); } catch (e) { return String(e); } }) });
logs.push({ step: 'diagnostics', value: await mobile.page.evaluate(() => { try { return window.tingyuDiagnostics().context; } catch (e) { return String(e); } }) });
await mobile.context.close();

const desktop = await open({ width: 1440, height: 1000 });
await shot(desktop.page, 'd-home');
await clickText(desktop.page, /^专注$/);
await desktop.page.waitForTimeout(800);
await shot(desktop.page, 'd-pomodoro');
await clickText(desktop.page, /^设置/);
await desktop.page.waitForTimeout(700);
await shot(desktop.page, 'd-settings');
await desktop.context.close();

await writeFile('build/ui/ui-check.json', JSON.stringify({ at: new Date().toISOString(), errors, logs }, null, 2), 'utf8');
console.log(JSON.stringify({ errors, logs }, null, 2));
await browser.close();
