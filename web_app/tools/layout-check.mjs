import { chromium } from 'playwright-core';
import { mkdir } from 'node:fs/promises';

const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
const errors = [];
async function shot(viewport, name, mobile = false, clickPomodoro = false) {
  const context = await browser.newContext({ viewport, deviceScaleFactor: 1, isMobile: mobile, hasTouch: mobile, locale: 'zh-CN' });
  const page = await context.newPage();
  page.on('console', m => { if (m.type() === 'error') errors.push(name + ': ' + m.text()); });
  page.on('pageerror', e => errors.push(name + ': ' + String(e)));
  await page.addInitScript(() => localStorage.setItem('tingyu.theme', 'light'));
  await page.goto('http://127.0.0.1:8140/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `build/ui/${name}-home.png` });
  if (clickPomodoro) {
    const nav = page.locator('flt-semantics [role="button"]').filter({ hasText: /^专注$/ }).first();
    await nav.click({ force: true });
    await page.waitForTimeout(700);
    await page.screenshot({ path: `build/ui/${name}-pomodoro.png` });
    const metrics = await page.evaluate(() => ({
      title: document.title,
      bodyWidth: document.body.scrollWidth,
      viewportWidth: innerWidth,
      overflowX: document.body.scrollWidth > innerWidth + 1,
    }));
    console.log(name, JSON.stringify(metrics));
  }
  await context.close();
}
await mkdir('build/ui', { recursive: true });
await shot({ width: 1024, height: 768 }, 'ipad-landscape', false, true);
await shot({ width: 768, height: 1024 }, 'ipad-portrait', true, true);
await shot({ width: 320, height: 568 }, 'phone-small', true, true);
await shot({ width: 820, height: 620 }, 'win-min', false, true);
await shot({ width: 1366, height: 1024 }, 'ipad-pro', false, true);
console.log('errors', JSON.stringify(errors));
await browser.close();
