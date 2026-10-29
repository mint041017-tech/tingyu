import { chromium } from 'playwright-core';
import { mkdir, writeFile } from 'node:fs/promises';

const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
const context = await browser.newContext({ viewport: { width: 393, height: 852 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, locale: 'zh-CN' });
const page = await context.newPage();
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push(String(e)));
await page.route('**/flutter_bootstrap.js', async route => {
  await new Promise(resolve => setTimeout(resolve, 4200));
  await route.continue();
});
await page.goto('http://127.0.0.1:8140/', { waitUntil: 'domcontentloaded' });
await page.waitForTimeout(850);
await mkdir('build/ui', { recursive: true });
await page.screenshot({ path: 'build/ui/boot-animation.png' });
const state = await page.evaluate(() => {
  const brand = document.querySelector('.brand');
  const leaf = document.querySelector('.brand-mark .leaf');
  const vein = document.querySelector('.brand-mark .vein');
  const mark = document.querySelector('.brand-mark svg');
  return {
    title: document.title,
    hasBrand: !!brand,
    hasSvgMark: !!mark,
    manifest: document.querySelector('link[rel="manifest"]')?.getAttribute('href') || null,
    brandAnimation: brand ? getComputedStyle(brand).animationName : null,
    leafAnimation: leaf ? getComputedStyle(leaf).animationName : null,
    veinAnimation: vein ? getComputedStyle(vein).animationName : null,
    loadingVisible: !!document.getElementById('loading'),
  };
});
await writeFile('build/ui/boot-check.json', JSON.stringify({ at: new Date().toISOString(), errors, state }, null, 2), 'utf8');
console.log(JSON.stringify({ errors, state }, null, 2));
await browser.close();
