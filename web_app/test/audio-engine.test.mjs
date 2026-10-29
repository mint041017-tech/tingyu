import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const code = await readFile(new URL('../web/audio-engine.js', import.meta.url), 'utf8');
const flush = async () => { for (let i = 0; i < 80; i++) await Promise.resolve(); };
const bytes = object => new TextEncoder().encode(JSON.stringify(object)).buffer;
const sounds = ['rain', 'forest', 'stream', 'ocean', 'wind', 'chimes', 'cafe', 'fire']
  .map(id => ({ id, name: id, file: `assets/audio/${id}.wav`, kind: 'recording' }));

class Events {
  listeners = new Map();
  addEventListener(name, callback) {
    if (!this.listeners.has(name)) this.listeners.set(name, new Set());
    this.listeners.get(name).add(callback);
  }
  removeEventListener(name, callback) { this.listeners.get(name)?.delete(callback); }
  emit(name) { for (const fn of [...(this.listeners.get(name) || [])]) fn({ type: name }); }
}
function harness(options = {}) {
  let now = 0, nextTimer = 1, uuid = 0;
  const timers = new Map(), contexts = [], trace = [], fetches = [];
  const records = options.records || new Map();
  const storage = options.storage || new Map();
  const deferred = new Map();
  const input = new Events();
  Object.assign(input, { type: 'file', value: '', files: [], disabled: false, clicks: 0,
    click() { this.clicks++; trace.push('picker'); } });
  const document = new Events();
  document.baseURI = 'https://tingyu.test/test/';
  document.getElementById = id => id === 'local-audio-file' ? input : null;
  function setTimer(fn, delay, interval = false) {
    const id = nextTimer++; timers.set(id, { fn, due: now + delay, delay, interval }); return id;
  }
  class Param {
    value = 1;
    events = [];
    setValueAtTime(value, time) { this.value = value; this.events.push({ type: 'set', value, time }); }
    linearRampToValueAtTime(value, time) { this.value = value; this.events.push({ type: 'ramp', value, time }); }
    cancelScheduledValues(time) { this.events.push({ type: 'cancel', time }); }
    cancelAndHoldAtTime(time) { this.events.push({ type: 'hold', time }); }
    setValueCurveAtTime(curve, time, duration) {
      this.events.push({ type: 'curve', curve: [...curve], time, duration });
    }
  }
  class Node {
    connections = [];
    connect(node) { this.connections.push(node); return node; }
    disconnect() { this.connections = []; this.disconnected = true; }
  }
  class Buffer {
    constructor(channels, length, sampleRate) {
      this.numberOfChannels = channels; this.length = length; this.sampleRate = sampleRate;
      this.duration = length / sampleRate;
      this.channels = Array.from({ length: channels }, () => new Float32Array(length));
    }
    getChannelData(channel) { return this.channels[channel]; }
  }
  class AudioContext extends Events {
    constructor() {
      super();
      if (options.contextFails) throw new Error('device');
      this.state = 'suspended'; this.sampleRate = options.sampleRate || 2000;
      this.destination = new Node(); this.gains = []; this.sources = []; this.timeOffset = 0;
      contexts.push(this); trace.push('create');
    }
    get currentTime() { return now / 1000 - this.timeOffset; }
    resume() {
      trace.push('resume');
      if (options.resumeFails) return Promise.reject(new Error('NotAllowedError'));
      this.state = 'running'; this.emit('statechange'); return Promise.resolve();
    }
    createGain() { const node = new Node(); node.gain = new Param(); this.gains.push(node); return node; }
    createDynamicsCompressor() {
      const node = new Node();
      for (const name of ['threshold', 'knee', 'ratio', 'attack', 'release']) node[name] = new Param();
      this.compressor = node; return node;
    }
    createAnalyser() {
      const node = new Node(); node.getFloatTimeDomainData = data => data.fill(options.level || 0);
      this.analyser = node; return node;
    }
    createBuffer(channels, length, sampleRate) { return new Buffer(channels, length, sampleRate); }
    createBufferSource() {
      const node = new Node();
      node.start = () => { node.started = true; trace.push('source'); };
      node.stop = time => { node.stopAt = time ?? this.currentTime; };
      this.sources.push(node); return node;
    }
    async decodeAudioData(array) {
      const data = JSON.parse(new TextDecoder().decode(array));
      if (data.bad) throw new Error('EncodingError');
      const buffer = this.createBuffer(data.channels || 1, Math.ceil(this.sampleRate * (data.duration || 6)), this.sampleRate);
      for (const channel of buffer.channels) {
        for (let i = 0; i < channel.length; i++) channel[i] = 0.2 * Math.sin(i * 0.13) + 0.05 * Math.cos(i * 0.17);
      }
      return buffer;
    }
  }
  const database = {
    objectStoreNames: { contains: () => true },
    close() {},
    transaction(_name, mode) {
      const tx = {};
      tx.objectStore = () => {
        const request = action => {
          const req = {};
          queueMicrotask(() => {
            if (options.dbWriteFails && mode === 'readwrite') { tx.onabort?.(); return; }
            req.result = action(); req.onsuccess?.(); tx.oncomplete?.();
          });
          return req;
        };
        return {
          getAll: () => request(() => [...records.values()]),
          get: id => request(() => records.get(id)),
          put: record => request(() => { records.set(record.id, record); return record.id; }),
          delete: id => request(() => records.delete(id)),
        };
      };
      return tx;
    },
  };
  const indexedDB = { open() {
    const request = {};
    queueMicrotask(() => {
      if (options.dbOpenFails) request.onerror?.();
      else { request.result = database; request.onsuccess?.(); }
    });
    return request;
  } };
  const window = new Events();
  window.AudioContext = AudioContext;
  window.indexedDB = indexedDB;
  window.localStorage = {
    getItem(key) { if (options.storageFails) throw new Error('SecurityError'); return storage.get(key) ?? null; },
    setItem(key, value) { if (options.storageFails) throw new Error('QuotaExceededError'); storage.set(key, value); },
  };
  window.crypto = { randomUUID: () => `test-${++uuid}` };
  const mediaHandlers = new Map();
  const navigator = { mediaSession: { setActionHandler: (name, fn) => mediaHandlers.set(name, fn) } };
  async function fetch(url, config) {
    fetches.push({ url, config }); trace.push('fetch');
    if (url.endsWith('manifest.json')) {
      if (options.manifestFails) throw new Error('network');
      return { ok: true, json: async () => ({ sounds: options.sounds || sounds }) };
    }
    const id = url.split('/').pop().split('.')[0];
    if (deferred.has(id)) await deferred.get(id).promise;
    if (options.missing === id) return { ok: false, status: 404 };
    return { ok: true, arrayBuffer: async () => bytes({ duration: options.duration || 6,
      channels: options.channels || 1, bad: options.badAudio === id }) };
  }
  const sandbox = vm.createContext({ window, document, navigator, URL, console,
    Float32Array, JSON, Math, Error, SyntaxError, Promise, Set, Map, Object, Array,
    Number, String, Date, fetch, performance: { now: () => now },
    setTimeout: (fn, delay) => setTimer(fn, delay), clearTimeout: id => timers.delete(id),
    setInterval: (fn, delay) => setTimer(fn, delay, true), clearInterval: id => timers.delete(id) });
  vm.runInContext(code, sandbox, { filename: 'audio-engine.js' });
  return {
    window, input, contexts, records, storage, trace, fetches, mediaHandlers, document,
    command: async (action, payload = {}) => JSON.parse(await window.tingyuCommand(action, JSON.stringify(payload))),
    snapshot: () => JSON.parse(window.tingyuSnapshot()),
    diagnostic: () => window.tingyuDiagnostics(),
    defer(id) {
      let resolve;
      const promise = new Promise(r => { resolve = r; });
      deferred.set(id, { promise }); return () => { deferred.delete(id); resolve(); };
    },
    async advance(milliseconds, runTimers = true) {
      now += milliseconds;
      if (runTimers) {
        for (const [id, timer] of [...timers]) {
          if (timer.due <= now) {
            if (timer.interval) timer.due = now + timer.delay; else timers.delete(id);
            timer.fn();
          }
        }
      }
      await flush();
    },
    file({ name = '夜雨.wav', duration = 6, size = 4096, bad = false } = {}) {
      return { name, size, type: 'audio/wav', arrayBuffer: async () => bytes({ duration, bad }) };
    },
  };
}
const one = [{ id: 'brown', volume: 60 }];
const active = h => Array.from(h.diagnostic().sources).filter(source => !source.retiring);

test('API defaults, namespaced storage, defensive JSON, and no automatic playback', async () => {
  const h = harness();
  const before = h.snapshot();
  assert.deepEqual(before.tracks, [{ id: 'rain', volume: 65 }, { id: 'forest', volume: 25 }, { id: 'brown', volume: 20 }]);
  assert.equal(before.master, 70); assert.equal(before.title, '窗边一页');
  assert.equal(before.playing, false); assert.equal(before.timer.status, 'off');
  assert.equal(h.contexts.length, 0);
  assert.equal(h.window.tingyuRead('absent'), '');
  assert.equal(h.window.tingyuWrite('favorites', '[1]'), true);
  assert.equal(h.storage.get('tingyu.favorites'), '[1]');
  assert.equal(JSON.parse(await h.window.tingyuCommand('load', '{')).ok, false);
  assert.equal((await h.command('bogus')).ok, false);
  assert.equal((await h.command('init')).ok, true);
  assert.equal(h.snapshot().busy, false); assert.equal(h.contexts.length, 0);
  assert.deepEqual([...h.mediaHandlers.keys()], ['play', 'pause', 'stop']);
});

test('resume happens synchronously before fetching; graph, looping, ratio normalization and smoothing', async () => {
  const h = harness({ level: 0.1 });
  const pending = h.command('play');
  assert.deepEqual(h.trace, ['create', 'resume']);
  assert.equal(h.snapshot().busy, true);
  assert.equal((await pending).ok, true);
  assert.equal(h.snapshot().playing, true); assert.equal(active(h).length, 3);
  const ctx = h.contexts[0], [bus, timer] = ctx.gains;
  assert.equal(bus.connections[0], ctx.compressor);
  assert.equal(ctx.compressor.connections[0], timer);
  assert.equal(timer.connections[0], ctx.analyser);
  assert.equal(ctx.analyser.connections[0], ctx.destination);
  for (const source of ctx.sources) { assert.equal(source.loop, true); assert.equal(source.loopEnd, source.buffer.duration); }
  assert.ok(Math.abs(h.diagnostic().normalization - 0.85 / 1.1) < 1e-12);
  assert.ok(Math.abs(h.snapshot().level - 0.1) < 1e-6);
  await h.command('volume', { id: 'rain', value: 80 });
  assert.equal(active(h).find(v => v.id === 'rain').volume, 0.8);
  assert.ok(ctx.gains[2].gain.events.some(event => event.type === 'ramp' && event.value === 0.8));
  await h.command('master', { value: 200 }); assert.equal(h.snapshot().master, 100);
  await h.command('pause'); await h.advance(110);
  assert.equal(active(h).length, 0); assert.equal(h.diagnostic().sources.length, 0);
});

test('distinct generated spectra, 20+ second buffers and a bounded read-only diagnostic', async () => {
  const h = harness();
  await h.command('load', { tracks: ['white', 'pink', 'brown'].map(id => ({ id, volume: 30 })) });
  const ratios = h.contexts[0].sources.map(source => {
    const data = source.buffer.getChannelData(0);
    let energy = 0, difference = 0;
    for (let i = 1; i < data.length; i++) { energy += data[i] ** 2; difference += (data[i] - data[i - 1]) ** 2; }
    assert.ok(source.buffer.duration >= 20);
    assert.ok(Math.max(...data.subarray(0, 10000)) < 1);
    return difference / energy;
  });
  assert.ok(ratios[0] > ratios[1] * 2, ratios.toString());
  assert.ok(ratios[1] > ratios[2] * 2, ratios.toString());
  const diagnostic = h.diagnostic();
  assert.ok(Object.isFrozen(diagnostic)); assert.ok(Object.isFrozen(diagnostic.sources));
  assert.ok(diagnostic.cache.bytes <= diagnostic.cache.limitBytes);
});

test('draft restoration, local references checked after IndexedDB, and paused add stays paused', async () => {
  const storage = new Map([['tingyu.draft', JSON.stringify({ master: 42, title: '草稿',
    tracks: [{ id: 'local:missing', volume: 80 }, { id: 'pink', volume: 30 }] })]]);
  const h = harness({ storage });
  await h.command('init');
  assert.deepEqual(h.snapshot().tracks, [{ id: 'pink', volume: 30 }]);
  assert.equal(h.snapshot().master, 42); assert.equal(h.snapshot().title, '草稿');
  await h.command('add', { id: 'rain' });
  assert.equal(h.snapshot().tracks[1].volume, 45);
  assert.equal(h.contexts.length, 0); assert.equal(h.snapshot().playing, false);
  await h.command('add', { id: 'rain' }); assert.equal(h.snapshot().tracks.length, 2);
  for (const id of ['forest', 'stream', 'ocean', 'brown']) await h.command('add', { id });
  assert.equal((await h.command('add', { id: 'white' })).ok, false);
  const fresh = harness({ storage });
  await fresh.command('init');
  assert.equal(fresh.snapshot().tracks.length, 6); assert.equal(fresh.snapshot().playing, false);
});

test('armed timer starts on successful playback, remains absolute through pause, expires via snapshot alone', async () => {
  const h = harness();
  await h.command('load', { tracks: one, autoplay: false });
  await h.command('timer', { seconds: 10, fadeSeconds: 4 });
  await h.advance(5000, false);
  assert.equal(h.snapshot().timer.status, 'armed'); assert.equal(h.snapshot().timer.remaining, 10);
  await h.command('play');
  const param = h.contexts[0].gains[1].gain;
  const curve = param.events.findLast(event => event.type === 'curve');
  assert.equal(curve.time, 11); assert.equal(curve.duration, 4);
  assert.equal(curve.curve[0], 1); assert.equal(curve.curve.at(-1), 0);
  await h.advance(3000, false); await h.command('pause');
  await h.advance(4000, false);
  assert.equal(h.snapshot().timer.status, 'fading'); assert.equal(h.snapshot().timer.remaining, 3);
  await h.command('play');
  const resumed = param.events.findLast(event => event.type === 'curve');
  assert.equal(resumed.duration, 3); assert.ok(resumed.curve[0] < 1);
  await h.advance(3100, false);
  assert.equal(h.snapshot().timer.status, 'expired'); assert.equal(h.snapshot().playing, false);
  assert.equal(h.diagnostic().sources.length, 0);
  await h.command('play'); assert.equal(h.snapshot().playing, true); assert.equal(h.snapshot().timer.status, 'off');
});

test('timer validation, cancellation restores smoothly, replacement fade is prescheduled', async () => {
  const h = harness();
  for (const payload of [{ seconds: 0 }, { seconds: 43201 }, { seconds: 1.2 }, { seconds: 10, fadeSeconds: 6 },
    { seconds: 600, fadeSeconds: 121 }, { seconds: 10, fadeSeconds: -1 }]) {
    assert.equal((await h.command('timer', payload)).ok, false);
  }
  await h.command('load', { tracks: one });
  await h.command('timer', { seconds: 2, fadeSeconds: 1 });
  await h.advance(1500, false);
  assert.ok(Math.abs(h.diagnostic().timerGain - 0.5) < 1e-6);
  await h.command('cancelTimer');
  const param = h.contexts[0].gains[1].gain;
  const end = param.events.slice(-3);
  assert.equal(end[0].type, 'hold'); assert.ok(Math.abs(end[1].value - 0.5) < 1e-6);
  assert.equal(end[2].type, 'ramp'); assert.equal(end[2].value, 1);
  assert.equal(h.snapshot().timer.status, 'off');
  await h.advance(100); await h.command('timer', { seconds: 1, fadeSeconds: 0 });
  assert.ok(param.events.some(event => event.type === 'set' && event.value === 0 && event.time === 2.6));
  await h.command('stop'); assert.equal(h.snapshot().timer.status, 'off'); assert.equal(h.snapshot().playing, false);
});

test('removing the last track cancels armed and running timers while paused or playing', async () => {
  for (const mode of ['armed', 'playing', 'paused']) {
    const h = harness();
    await h.command('load', { tracks: one, autoplay: false });
    await h.command('timer', { seconds: 10, fadeSeconds: 4 });
    if (mode !== 'armed') await h.command('play');
    if (mode === 'paused') await h.command('pause');
    assert.equal(h.snapshot().playing, mode === 'playing');
    assert.equal(h.snapshot().timer.status, mode === 'armed' ? 'armed' : 'running');
    assert.equal((await h.command('remove', { id: 'brown' })).ok, true);
    assert.deepEqual(h.snapshot().tracks, []);
    assert.equal(h.snapshot().playing, false); assert.equal(h.diagnostic().desiredPlaying, false);
    assert.deepEqual(h.snapshot().timer, { status: 'off', remaining: 0, duration: 0, fade: 0 });
    assert.equal(h.diagnostic().deadline, null); assert.equal(active(h).length, 0);
    await h.advance(11000);
    assert.equal(h.snapshot().timer.status, 'off'); assert.equal(h.diagnostic().sources.length, 0);
  }
});

test('removing a non-last track retains armed and running timers while paused or playing', async () => {
  for (const mode of ['armed', 'playing', 'paused']) {
    const h = harness();
    await h.command('load', { tracks: [...one, { id: 'pink', volume: 30 }], autoplay: false });
    await h.command('timer', { seconds: 10, fadeSeconds: 4 });
    if (mode !== 'armed') await h.command('play');
    if (mode === 'paused') await h.command('pause');
    await h.advance(1000);
    const timer = h.snapshot().timer, deadline = h.diagnostic().deadline;
    assert.equal((await h.command('remove', { id: 'pink' })).ok, true);
    assert.deepEqual(h.snapshot().tracks, one); assert.equal(h.snapshot().playing, mode === 'playing');
    assert.deepEqual(h.snapshot().timer, timer); assert.equal(h.diagnostic().deadline, deadline);
    assert.deepEqual(active(h).map(v => v.id), mode === 'playing' ? ['brown'] : []);
  }
});

test('resume rebases timer automation to performance deadline after context suspension', async () => {
  const h = harness();
  await h.command('load', { tracks: one }); await h.command('timer', { seconds: 10, fadeSeconds: 4 });
  const ctx = h.contexts[0]; ctx.state = 'suspended';
  await h.advance(8000, false); ctx.timeOffset = 7;
  ctx.state = 'running'; ctx.emit('statechange');
  const curve = ctx.gains[1].gain.events.findLast(event => event.type === 'curve');
  assert.equal(curve.time, 1); assert.equal(curve.duration, 2);
  assert.ok(Math.abs(curve.curve[0] - 0.5) < 1e-6);
  ctx.state = 'suspended'; await h.advance(3000, false);
  ctx.state = 'running'; ctx.emit('statechange');
  assert.equal(h.snapshot().timer.status, 'expired'); assert.equal(active(h).length, 0);
});

test('late load cannot restart after pause or override newer load', async () => {
  const h = harness();
  await h.command('init'); const release = h.defer('rain');
  const pending = h.command('load', { tracks: [{ id: 'rain' }] }); await flush();
  await h.command('pause'); release();
  assert.equal((await pending).cancelled, true); assert.equal(active(h).length, 0);
  const h2 = harness(); await h2.command('init'); const release2 = h2.defer('forest');
  const old = h2.command('load', { tracks: [{ id: 'forest' }] }); await flush();
  await h2.command('load', { tracks: [{ id: 'white' }], title: '新混音' }); release2(); await old;
  assert.deepEqual(active(h2).map(v => v.id), ['white']); assert.equal(h2.snapshot().title, '新混音');
});

test('failed mixed load stops previous sound and reports the specific failed decode', async () => {
  const h = harness({ badAudio: 'rain' });
  await h.command('load', { tracks: one });
  const result = await h.command('load', { tracks: [{ id: 'rain' }, { id: 'forest' }] });
  assert.equal(result.ok, false); assert.match(result.error, /rain.*解码|解码.*rain/);
  await h.advance(110);
  assert.equal(h.snapshot().playing, false); assert.equal(h.diagnostic().sources.length, 0);
  assert.equal(h.snapshot().busy, false);
});

test('missing natural sounds never become white noise; manifest URLs cannot redirect off OBS', async () => {
  const h = harness({ sounds: [] });
  const result = await h.command('preview', { id: 'forest' });
  assert.equal(result.ok, false); assert.match(result.error, /不可用/); assert.equal(active(h).length, 0);
  assert.equal(h.snapshot().previewId, null);
  const external = harness({ sounds: [{ id: 'rain', name: '雨', file: 'https://evil.test/rain.wav' }] });
  assert.equal((await external.command('load', { tracks: [{ id: 'rain' }] })).ok, true);
  const audioRequests = external.fetches.filter(item => item.url.endsWith('.wav'));
  assert.deepEqual(audioRequests.map(item => item.url), ['https://obs.chimu-claw.xyz/ambient%20noise/rain.wav']);
  assert.equal(audioRequests[0].config.mode, 'cors');
  assert.equal(audioRequests[0].config.credentials, 'omit');
  assert.ok(!external.fetches.some(item => item.url.includes('evil.test')));
  const synthetic = harness({ sounds: [{ id: 'underwater', kind: 'synth' }] });
  assert.equal((await synthetic.command('preview', { id: 'underwater' })).ok, true);
  assert.equal(active(synthetic)[0].id, 'underwater'); assert.ok(active(synthetic)[0].duration >= 20);
});

test('exclusive preview ends after 8s and restores previous mix; pause and stop veto restoration', async () => {
  const h = harness(); await h.command('load', { tracks: one });
  await h.command('preview', { id: 'white' }); await h.advance(110);
  assert.equal(h.snapshot().playing, false); assert.equal(h.snapshot().previewId, 'white');
  assert.deepEqual(active(h).map(v => v.id), ['white']);
  await h.advance(8000);
  assert.equal(h.snapshot().previewId, null); assert.equal(h.snapshot().playing, true);
  assert.deepEqual(active(h).map(v => v.id), ['brown']);
  for (const action of ['pause', 'stop']) {
    await h.command('preview', { id: 'pink' }); await h.command(action); await h.advance(9000);
    assert.equal(h.snapshot().playing, false); assert.equal(h.snapshot().previewId, null); assert.equal(active(h).length, 0);
    await h.command('play');
  }
});

test('timer expiry during preview or async preview load prevents any restoration', async () => {
  const h = harness(); await h.command('load', { tracks: one });
  await h.command('timer', { seconds: 2, fadeSeconds: 1 });
  await h.command('preview', { id: 'pink' }); await h.advance(2100, false);
  assert.equal(h.snapshot().timer.status, 'expired'); assert.equal(h.snapshot().previewId, null);
  assert.equal(h.diagnostic().sources.length, 0); await h.advance(9000);
  assert.equal(h.snapshot().playing, false);
  await h.command('play'); const release = h.defer('rain');
  const pending = h.command('preview', { id: 'rain' }); await flush();
  await h.command('pause'); release();
  assert.equal((await pending).cancelled, true); await h.advance(9000);
  assert.equal(h.snapshot().playing, false); assert.equal(active(h).length, 0);
});

test('stopPreview restores safely; switching previews preserves original resume intent', async () => {
  const h = harness(); await h.command('load', { tracks: one });
  const release = h.defer('rain'); const stale = h.command('preview', { id: 'rain' }); await flush();
  await h.command('preview', { id: 'white' }); release(); assert.equal((await stale).cancelled, true);
  assert.equal(h.snapshot().previewId, 'white');
  await h.command('stopPreview'); assert.equal(h.snapshot().playing, true);
  assert.deepEqual(active(h).map(v => v.id), ['brown']);
});

test('import immediately opens HTML picker, cancellation resolves without an error or disabled input', async () => {
  const h = harness(); const pending = h.command('import');
  assert.equal(h.input.clicks, 1); assert.equal(h.snapshot().busy, true);
  assert.match(h.input.accept, /audio/); assert.equal(h.fetches.length, 0);
  h.input.emit('cancel'); assert.deepEqual(await pending, { ok: true, cancelled: true });
  assert.equal(h.snapshot().busy, false); assert.equal(h.snapshot().error, null); assert.equal(h.input.disabled, false);
  const fallback = h.command('import'); h.window.emit('focus'); await h.advance(501);
  assert.equal((await fallback).cancelled, true);
});

test('valid local import persists original file, restores after refresh, and deletion removes only that track', async () => {
  const h = harness(); const file = h.file();
  const pending = h.command('import'); h.input.files = [file]; h.input.emit('change');
  const result = await pending; assert.equal(result.ok, true); assert.match(result.id, /^local:/);
  assert.equal(h.records.get(result.id).blob, file); assert.equal(h.snapshot().locals[0].duration, 6);
  assert.equal(h.snapshot().playing, false); assert.equal(h.snapshot().busy, false);
  await h.command('load', { tracks: [{ id: result.id, volume: 50 }, { id: 'pink', volume: 20 }], autoplay: false });
  const fresh = harness({ records: h.records, storage: h.storage });
  await fresh.command('init'); assert.equal(fresh.snapshot().locals.length, 1);
  assert.equal(fresh.snapshot().playing, false);
  await fresh.command('play'); assert.equal(active(fresh).length, 2);
  await fresh.command('deleteLocal', { id: result.id });
  assert.equal(fresh.records.size, 0); assert.equal(fresh.snapshot().locals.length, 0);
  assert.deepEqual(fresh.snapshot().tracks, [{ id: 'pink', volume: 20 }]);
  assert.deepEqual(active(fresh).map(v => v.id), ['pink']); assert.equal(fresh.snapshot().playing, true);
  assert.equal((await fresh.command('deleteLocal', { id: 'pink' })).ok, false);
});

test('invalid, oversized and unpersistable imports never register a local sound', async () => {
  for (const fixture of [{ size: 51 * 1024 * 1024 }, { duration: 4.99 }, { duration: 600.1 }, { bad: true }]) {
    const h = harness(); const pending = h.command('import'); h.input.files = [h.file(fixture)]; h.input.emit('change');
    const result = await pending;
    assert.equal(result.ok, false); assert.match(result.error, /[\u3400-\u9fff]/);
    assert.equal(h.records.size, 0); assert.equal(h.snapshot().locals.length, 0); assert.equal(h.input.disabled, false);
  }
  for (const option of ['dbWriteFails', 'dbOpenFails']) {
    const h = harness({ [option]: true }); const pending = h.command('import');
    h.input.files = [h.file()]; h.input.emit('change'); assert.equal((await pending).ok, false);
    assert.equal(h.snapshot().locals.length, 0); assert.equal(h.snapshot().busy, false);
  }
});

test('audio device and storage failure paths return Chinese errors without leaked playback intent', async () => {
  for (const option of ['contextFails', 'resumeFails']) {
    for (const action of ['play', 'load', 'preview']) {
      const h = harness({ [option]: true });
      const result = await h.command(action, { id: 'pink', tracks: one });
      assert.equal(result.ok, false); assert.match(result.error, /[\u3400-\u9fff]/);
      assert.equal(h.snapshot().previewId, null); assert.equal(h.snapshot().playing, false);
      assert.equal(h.diagnostic().desiredPlaying, false); assert.equal(h.snapshot().busy, false);
    }
  }
  const h = harness({ storageFails: true });
  assert.equal(h.window.tingyuWrite('x', 'y'), false); assert.equal(h.window.tingyuRead('x'), '');
});

test('LRU decoded buffer cache is bounded, including oversized uncacheable recordings', async () => {
  const h = harness({ duration: 600, channels: 2, sampleRate: 16000 });
  for (const id of ['rain', 'forest', 'stream']) {
    await h.command('load', { tracks: [{ id }] }); await h.advance(110);
    const cache = h.diagnostic().cache;
    assert.ok(cache.bytes <= cache.limitBytes); assert.equal(cache.entries, 0);
    assert.equal(active(h).length, 1);
  }
});

test('failed additions roll back without losing the existing mix', async () => {
  const h = harness({ badAudio: 'rain' });
  await h.command('load', { tracks: one });
  for (const id of ['rain', 'unknown']) {
    const result = await h.command('add', { id });
    assert.equal(result.ok, false);
    assert.deepEqual(h.snapshot().tracks, one);
    assert.deepEqual(active(h).map(v => v.id), ['brown']);
    assert.equal(h.snapshot().playing, true);
  }
  await h.command('pause');
  assert.equal((await h.command('add', { id: 'unknown' })).ok, false);
  assert.deepEqual(h.snapshot().tracks, one); assert.equal(h.snapshot().playing, false);
});

test('removing a mix track leaves an unrelated preview uninterrupted', async () => {
  const h = harness();
  await h.command('load', { tracks: [{ id: 'pink' }, { id: 'brown' }] });
  await h.command('timer', { seconds: 30, fadeSeconds: 5 });
  await h.command('preview', { id: 'white' });
  await h.advance(1000);
  const timer = h.snapshot().timer, deadline = h.diagnostic().deadline;
  await h.command('remove', { id: 'pink' });
  assert.equal(h.snapshot().previewId, 'white'); assert.equal(h.snapshot().playing, false);
  assert.deepEqual(active(h).map(v => v.id), ['white']);
  assert.deepEqual(h.snapshot().timer, timer); assert.equal(h.diagnostic().deadline, deadline);
  await h.advance(8100);
  assert.equal(h.snapshot().playing, true); assert.deepEqual(active(h).map(v => v.id), ['brown']);
  assert.equal(h.snapshot().timer.status, 'running'); assert.equal(h.diagnostic().deadline, deadline);
});

test('removing the last mix track cancels the timer but preserves an unrelated preview without resuming', async () => {
  for (const autoplay of [false, true]) {
    const h = harness();
    await h.command('load', { tracks: one, autoplay });
    await h.command('timer', { seconds: 2, fadeSeconds: 1 });
    await h.command('preview', { id: 'white' });
    await h.advance(1500);
    assert.equal(h.snapshot().timer.status, 'fading');
    const generation = h.diagnostic().generation;
    assert.equal((await h.command('remove', { id: 'brown' })).ok, true);
    assert.deepEqual(h.snapshot().tracks, []); assert.equal(h.snapshot().playing, false);
    assert.deepEqual(h.snapshot().timer, { status: 'off', remaining: 0, duration: 0, fade: 0 });
    assert.equal(h.diagnostic().deadline, null); assert.equal(h.diagnostic().generation, generation);
    assert.equal(h.snapshot().previewId, 'white'); assert.deepEqual(active(h).map(v => v.id), ['white']);
    await h.advance(1000);
    assert.equal(h.snapshot().previewId, 'white'); assert.deepEqual(active(h).map(v => v.id), ['white']);
    assert.equal(h.diagnostic().timerGain, 1);
    await h.advance(5500);
    assert.equal(h.snapshot().previewId, null); assert.equal(h.snapshot().playing, false);
    assert.equal(h.diagnostic().desiredPlaying, false); assert.equal(active(h).length, 0);
    assert.equal(h.snapshot().error, null); assert.equal(h.snapshot().timer.status, 'off');
  }
});

test('failed playback leaves armed timer unstarted, and timer expiration invalidates pending load', async () => {
  const h = harness({ missing: 'rain' });
  await h.command('timer', { seconds: 10, fadeSeconds: 5 });
  assert.equal((await h.command('load', { tracks: [{ id: 'rain' }] })).ok, false);
  await h.advance(12000, false);
  assert.equal(h.snapshot().timer.status, 'armed'); assert.equal(h.snapshot().timer.remaining, 10);
  await h.command('load', { tracks: one });
  const release = h.defer('forest'); const pending = h.command('load', { tracks: [{ id: 'forest' }] });
  await flush(); await h.advance(11000, false);
  assert.equal(h.snapshot().timer.status, 'expired');
  release(); assert.equal((await pending).cancelled, true); assert.equal(active(h).length, 0);
});
