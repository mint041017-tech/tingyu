import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

const origin = process.env.TINGYU_ORIGIN || 'http://127.0.0.1:8137/';
const debugPort = process.env.TINGYU_DEBUG_PORT || '9237';
const targets = await (await fetch(`http://127.0.0.1:${debugPort}/json`)).json();
const target = targets.find(item => item.type === 'page' && item.url.startsWith(origin));
assert.ok(target, 'Open the preview in the dedicated Chrome test window first');
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise(resolve => socket.addEventListener('open', resolve, { once: true }));
let sequence = 0;
const pending = new Map();
const exceptions = [];
socket.addEventListener('message', event => {
  const message = JSON.parse(event.data);
  if (message.method === 'Runtime.exceptionThrown') exceptions.push(message.params.exceptionDetails);
  if (message.method === 'Runtime.consoleAPICalled' && message.params.type === 'error') exceptions.push(message.params.args);
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
    const timeout = setTimeout(() => { pending.delete(id); reject(new Error(`Timed out: ${method}`)); }, 600000);
    pending.set(id, { resolve, reject, timeout });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(fn, ...args) {
  const result = await send('Runtime.evaluate', {
    expression: `(${fn.toString()})(...${JSON.stringify(args)})`,
    returnByValue: true, awaitPromise: true, userGesture: true,
  });
  if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
async function frames() {
  await evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}
async function click(label) {
  const point = await evaluate(name => {
    const element = [...document.querySelectorAll('[role="button"]')].find(item =>
      item.getAttribute('aria-label') === name || item.textContent.trim() === name);
    if (!element) throw new Error(`Missing button: ${name}`);
    const rect = element.getBoundingClientRect();
    return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
  }, label);
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', button: 'left', clickCount: 1, ...point });
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', button: 'left', clickCount: 1, ...point });
  await frames();
}
async function screenshot(name) {
  await evaluate(() => new Promise(resolve => {
    const start = performance.now();
    function settled() {
      if (performance.now() - start >= 800) resolve();
      else requestAnimationFrame(settled);
    }
    requestAnimationFrame(settled);
  }));
  const { data } = await send('Page.captureScreenshot', { format: 'png' });
  await writeFile(new URL(`../build/${name}.png`, import.meta.url), Buffer.from(data, 'base64'));
}
const report = {};
try {
  await send('Runtime.enable');
  await send('Page.enable');
  await send('Network.enable');
  await send('Page.bringToFront');
  await evaluate(() => navigator.serviceWorker
    ? navigator.serviceWorker.getRegistrations().then(items => Promise.all(items.map(item => item.unregister())))
    : []);
  await send('Network.setCacheDisabled', { cacheDisabled: true });
  await send('Page.reload', { ignoreCache: true });
  await evaluate(() => new Promise((resolve, reject) => {
    const started = performance.now();
    const timer = setInterval(() => {
      if (document.querySelector('flt-semantics [role="button"]') && typeof tingyuSnapshot === 'function') {
        clearInterval(timer); resolve(true);
      } else if (performance.now() - started > 20000) { clearInterval(timer); reject(new Error('Flutter did not render')); }
    }, 100);
  }));
  await click('此刻');
  await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 960, deviceScaleFactor: 1, mobile: false });
  await screenshot('desktop-preview');
  await click('声音');
  await screenshot('desktop-library');
  report.library = await evaluate(() => [...document.querySelectorAll('[role="group"][aria-label]')]
    .map(element => element.getAttribute('aria-label')).filter(label => /环境录音|合成音色/.test(label)));
  await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await screenshot('mobile-library');
  await click('此刻');
  await screenshot('mobile-preview');
  await click('切换明暗主题');
  await screenshot('mobile-theme');
  await click('切换明暗主题');
  await send('Emulation.setDeviceMetricsOverride', { width: 320, height: 740, deviceScaleFactor: 1, mobile: true });
  await screenshot('small-phone-preview');
  report.audio = await evaluate(async () => {
    const command = async (action, payload = {}) => {
      const result = JSON.parse(await tingyuCommand(action, JSON.stringify(payload)));
      if (!result.ok) throw new Error(`${action}: ${result.error}`);
      return result;
    };
    const original = JSON.parse(tingyuSnapshot());
    const manifest = await (await fetch('assets/audio/manifest.json')).json();
    const ids = [...new Set([...manifest.sounds.map(sound => sound.id), 'white', 'pink', 'brown'])];
    const measurements = [];
    await command('stop');
    await command('master', { value: 75 });
    for (const id of ids) {
      await command('load', { tracks: [{ id, volume: 80 }], title: id, autoplay: true });
      const measurement = await new Promise(resolve => {
        const samples = [];
        const timer = setInterval(() => {
          const value = tingyuDiagnostics();
          samples.push({ rms: value.rms, peak: value.peak });
          if (samples.length === 8) {
            clearInterval(timer);
            resolve({ id, rms: samples.reduce((sum, sample) => sum + sample.rms, 0) / samples.length,
              peak: Math.max(...samples.map(sample => sample.peak)), sources: value.sources,
              cacheBytes: value.cache.bytes, cacheLimit: value.cache.limitBytes });
          }
        }, 100);
      });
      measurements.push(measurement);
    }
    await command('load', { tracks: ids.slice(0, 6).map(id => ({ id, volume: 45 })), title: 'six-track-check' });
    const six = tingyuDiagnostics();
    const seventh = JSON.parse(await tingyuCommand('add', JSON.stringify({ id: ids[6] })));
    await command('volume', { id: ids[0], value: 25 });
    await command('timer', { seconds: 5, fadeSeconds: 2 });
    const fade = await new Promise(resolve => {
      const samples = [];
      const timer = setInterval(() => {
        const state = JSON.parse(tingyuSnapshot()), diagnostic = tingyuDiagnostics();
        samples.push({ status: state.timer.status, gain: diagnostic.timerGain, rms: diagnostic.rms });
        if (state.timer.status === 'expired' || samples.length > 40) {
          clearInterval(timer); resolve({ samples, final: state, sources: diagnostic.sources });
        }
      }, 200);
    });
    await command('stop');
    await command('load', { tracks: original.tracks, title: original.title, autoplay: false });
    await command('master', { value: original.master });
    return { measurements, six, seventh, fade };
  });
  for (const sound of report.audio.measurements) {
    assert.ok(sound.rms > 0.0001, `${sound.id} has no usable output`);
    assert.ok(sound.peak < 1, `${sound.id} clips`);
    assert.equal(sound.sources.filter(source => !source.retiring).length, 1);
    assert.ok(sound.sources.every(source => source.loop));
    assert.ok(sound.cacheBytes <= sound.cacheLimit);
  }
  assert.equal(report.audio.six.sources.filter(source => !source.retiring).length, 6);
  assert.equal(report.audio.seventh.ok, false);
  assert.equal(report.audio.fade.final.timer.status, 'expired');
  assert.equal(report.audio.fade.final.playing, false);
  assert.equal(report.audio.fade.sources.length, 0);
  assert.ok(report.audio.fade.samples.some(sample => sample.gain > 0 && sample.gain < 1));
  assert.equal(exceptions.length, 0, JSON.stringify(exceptions));
  await send('Emulation.clearDeviceMetricsOverride');
  await click('此刻');
  await writeFile(new URL('../build/browser-smoke.json', import.meta.url), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ soundsPassed: report.audio.measurements.length,
    minimumRms: Math.min(...report.audio.measurements.map(sound => sound.rms)),
    sixTrackLimit: 'passed', scheduledFade: 'passed', exceptions: exceptions.length,
    viewports: ['1440x960', '390x844', '320x740'] }, null, 2));
} finally {
  await send('Emulation.clearDeviceMetricsOverride').catch(() => {});
  socket.close();
}
