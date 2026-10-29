import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const root = new URL('../web/', import.meta.url);
const manifest = JSON.parse(await readFile(new URL('assets/audio/manifest.json', root), 'utf8'));
const models = await readFile(new URL('../lib/models.dart', import.meta.url), 'utf8');
const engine = await readFile(new URL('audio-engine.js', root), 'utf8');
const modelIds = [...models.matchAll(/SoundSpec\(\s*'([^']+)'/g)].map(match => match[1]);
const builtinList = engine.match(/const BUILTINS = new Set\(\[([\s\S]*?)\]\)/)[1];
const builtinIds = [...builtinList.matchAll(/'([^']+)'/g)].map(match => match[1]);
const recordings = manifest.sounds.filter(sound => sound.kind === 'recording');

test('the 28-sound catalog matches the manifest and engine without renamed duplicates', () => {
  const ids = [...manifest.sounds.map(sound => sound.id), 'white', 'pink', 'brown'];
  assert.equal(ids.length, 28);
  assert.equal(new Set(ids).size, 28);
  assert.deepEqual(modelIds.toSorted(), ids.toSorted());
  assert.deepEqual(builtinIds.toSorted(), ids.toSorted());
  assert.equal(recordings.length, 24);
  assert.equal(new Set(recordings.map(sound => sound.sourceUrl)).size, 24);
  assert.equal(new Set(recordings.map(sound => sound.sha256)).size, 24);
});

for (const sound of recordings) {
  test(`${sound.id}: complete, audible, unclipped PCM with a checked loop boundary`, async () => {
    assert.match(sound.file, /^assets\/audio\/[a-z_]+\.wav$/);
    const bytes = await readFile(new URL(sound.file, root));
    assert.equal(bytes.length, sound.bytes);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), sound.sha256);
    assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
    assert.equal(bytes.toString('ascii', 8, 12), 'WAVE');
    let format, data;
    for (let offset = 12; offset + 8 <= bytes.length;) {
      const type = bytes.toString('ascii', offset, offset + 4);
      const size = bytes.readUInt32LE(offset + 4);
      assert.ok(offset + 8 + size <= bytes.length, 'PCM chunk is not truncated');
      if (type === 'fmt ') format = bytes.subarray(offset + 8, offset + 8 + size);
      if (type === 'data') data = bytes.subarray(offset + 8, offset + 8 + size);
      offset += 8 + size + (size % 2);
    }
    assert.ok(format && data);
    assert.equal(format.readUInt16LE(0), 1);
    const channels = format.readUInt16LE(2);
    const rate = format.readUInt32LE(4);
    assert.ok(channels >= 1 && channels <= 2);
    assert.equal(format.readUInt16LE(14), 16);
    const duration = data.length / 2 / channels / rate;
    assert.ok(duration >= 5 && duration <= 120);
    assert.ok(Math.abs(duration - sound.duration) < 1 / rate);
    let energy = 0, peak = 0, clips = 0;
    for (let index = 0; index < data.length; index += 2) {
      const sample = data.readInt16LE(index) / 32768;
      energy += sample * sample;
      peak = Math.max(peak, Math.abs(sample));
      if (Math.abs(sample) >= 32767 / 32768) clips++;
    }
    const rms = Math.sqrt(energy / (data.length / 2));
    assert.ok(rms > 0.002, `RMS ${rms} is too quiet`);
    assert.ok(peak <= 0.9, `Peak ${peak} leaves insufficient mix headroom`);
    assert.equal(clips, 0);
    for (let channel = 0; channel < channels; channel++) {
      const first = data.readInt16LE(channel * 2);
      const last = data.readInt16LE(data.length - channels * 2 + channel * 2);
      assert.ok(Math.abs(first - last) / 32768 < 0.04, 'Large discontinuity at loop seam');
    }
  });
}
