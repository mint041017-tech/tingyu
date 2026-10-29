import { chromium } from 'playwright-core';
const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
const context = await browser.newContext({ viewport: { width: 393, height: 852 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, locale: 'zh-CN' });
const page = await context.newPage();
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push(String(e)));
await page.addInitScript(() => {
  localStorage.setItem('tingyu.pomodoro', JSON.stringify({ settings: { playWithFocus: false }, phase: 'focus', remaining: 1500, running: false, completed: false, focusInCycle: 0, sessions: [] }));
});
await page.goto('http://127.0.0.1:8140/', { waitUntil: 'networkidle' });
await page.waitForTimeout(4000);
console.log('semantics nodes', await page.locator('flt-semantics').count());
console.log('buttons', await page.locator('flt-semantics [role="button"]').evaluateAll(els => els.slice(0, 20).map(e => ({label: e.getAttribute('aria-label'), text: e.textContent.slice(0, 30), rect: e.getBoundingClientRect().toJSON()}))));
await page.screenshot({ path: 'build/ui/probe-mobile.png' });
console.log('errors', errors.slice(0, 10));
await browser.close();
