import assert from 'node:assert/strict';

const origin = process.env.TINGYU_ORIGIN || 'http://127.0.0.1:8137/';
const debugPort = process.env.TINGYU_DEBUG_PORT || '9245';
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
async function measure(reload) {
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  await send('Network.setCacheDisabled', { cacheDisabled: !reload });
  await send('Page.addScriptToEvaluateOnNewDocument', { source: `
    window.__startup = { start: performance.now(), firstFrame: null };
    document.addEventListener('DOMContentLoaded', () => {
      const check = setInterval(() => {
        if (!document.getElementById('loading') && !window.__startup.firstFrame) {
          window.__startup.firstFrame = performance.now();
          clearInterval(check);
        }
      }, 20);
      setTimeout(() => clearInterval(check), 30000);
    });
  ` });
  if (reload) await send('Page.reload', { ignoreCache: false });
  else await send('Page.navigate', { url: origin });
  await new Promise(resolve => {
    const started = Date.now();
    const timer = setInterval(async () => {
      try {
        if (await evaluate(() => Boolean(window.__startup && window.__startup.firstFrame))) {
          clearInterval(timer); resolve();
        } else if (Date.now() - started > 30000) { clearInterval(timer); resolve(); }
      } catch (_) { /* Navigation context is being replaced. */ }
    }, 100);
  });
  return await evaluate(() => {
    const resources = performance.getEntriesByType('resource')
      .map(item => ({ name: item.name, bytes: item.transferSize || item.encodedBodySize || 0,
        end: Math.round(item.responseEnd), duration: Math.round(item.duration) }))
      .sort((a, b) => b.bytes - a.bytes);
    const nav = performance.getEntriesByType('navigation')[0];
    return {
      firstFrameMs: window.__startup?.firstFrame ? Math.round(window.__startup.firstFrame) : null,
      domInteractiveMs: nav ? Math.round(nav.domInteractive) : null,
      totalTransferBytes: resources.reduce((sum, item) => sum + item.bytes, 0),
      resources,
    };
  });
}
try {
  const cold = await measure(false);
  const warm = await measure(true);
  console.log(JSON.stringify({ origin, cold, warm }, null, 2));
  assert.ok(cold.firstFrameMs && cold.firstFrameMs < 30000);
  assert.ok(!cold.resources.some(item => item.name.endsWith('.wav')), 'Audio must stay lazy on the home screen');
} finally {
  socket.close();
}
