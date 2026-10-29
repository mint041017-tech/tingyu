import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

const origin = process.env.TINGYU_ORIGIN || 'http://127.0.0.1:8137/';
const debugPort = process.env.TINGYU_DEBUG_PORT || '9247';
const targets = await (await fetch(`http://127.0.0.1:${debugPort}/json`)).json();
const target = targets.find(item => item.type === 'page');
assert.ok(target, 'Open a clean Chrome test page first');
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise(resolve => socket.addEventListener('open', resolve, { once: true }));
let sequence = 0;
const pending = new Map();
socket.addEventListener('message', event => {
  const message = JSON.parse(event.data);
  const job = pending.get(message.id);
  if (!job) return;
  pending.delete(message.id);
  clearTimeout(job.timeout);
  if (message.error) job.reject(new Error(JSON.stringify(message.error)));
  else job.resolve(message.result);
});
function send(method, params = {}) {
  const id = ++sequence;
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => { pending.delete(id); reject(new Error(`Timed out: ${method}`)); }, 120000);
    pending.set(id, { resolve, reject, timeout });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(fn) {
  const result = await send('Runtime.evaluate', { expression: `(${fn.toString()})()`, returnByValue: true, awaitPromise: true });
  if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
async function shot(name) {
  await evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const { data } = await send('Page.captureScreenshot', { format: 'png' });
  await writeFile(new URL(`../build/${name}.png`, import.meta.url), Buffer.from(data, 'base64'));
}
try {
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  await send('Network.setCacheDisabled', { cacheDisabled: true });
  await send('Network.setBlockedURLs', { urls: ['*flutter_bootstrap.js*'] });
  await send('Page.navigate', { url: origin });
  await evaluate(() => new Promise((resolve, reject) => {
    const started = performance.now();
    const timer = setInterval(() => {
      if (document.querySelector('.boot-wait') && document.querySelector('#loading img')?.complete) {
        clearInterval(timer); resolve();
      } else if (performance.now() - started > 10000) { clearInterval(timer); reject(new Error('Boot shell did not render')); }
    }, 50);
  }));
  const shell = await evaluate(() => ({
    buttons: document.querySelectorAll('#loading button').length,
    banner: document.querySelector('.boot-banner strong')?.textContent || '',
    status: document.getElementById('boot-status').textContent,
    audioPlaying: JSON.parse(tingyuSnapshot()).playing,
  }));
  assert.equal(shell.buttons, 0, 'Loading page must not expose playback controls');
  assert.match(shell.banner, /正在准备声音空间/);
  assert.match(shell.status, /正在载入/);
  assert.equal(shell.audioPlaying, false, 'Loading page must not start audio');
  await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await shot('boot-mobile');
  await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 960, deviceScaleFactor: 1, mobile: false });
  await shot('boot-desktop');
  console.log(JSON.stringify({
    shellRender: 'passed', relativeBase: await evaluate(() => document.baseURI),
    loadingControls: shell.buttons, audioPlaying: shell.audioPlaying,
    theme: await evaluate(() => document.documentElement.dataset.theme || null),
  }));
} finally {
  socket.close();
}
