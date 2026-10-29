import { cp, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const packaging = path.resolve(here, '..');
const source = path.resolve(packaging, '..', 'build', 'web');
const dest = path.join(packaging, 'www');

await rm(dest, { recursive: true, force: true });
await cp(source, dest, { recursive: true });

async function prune(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      await prune(full);
    } else if (entry.name.endsWith('.gz') || entry.name.endsWith('.symbols')) {
      await rm(full, { force: true });
    }
  }
}
await prune(dest);

const bootstrap = path.join(dest, 'flutter_bootstrap.js');
const code = await readFile(bootstrap, 'utf8');
const patched = code.replace(/serviceWorkerSettings:\s*\{[^}]*\}/, 'serviceWorkerSettings: null');
if (patched === code) throw new Error('未找到 serviceWorkerSettings，无法为原生壳关闭 Service Worker');
await writeFile(bootstrap, patched, 'utf8');
await rm(path.join(dest, 'flutter_service_worker.js'), { force: true });

// 内置录音从公共 OBS 按需加载；安装包不重复携带 74 MB WAV，只保留清单。
for (const entry of await readdir(path.join(dest, 'assets', 'audio'), { withFileTypes: true })) {
  if (entry.isFile() && entry.name !== 'manifest.json') {
    await rm(path.join(dest, 'assets', 'audio', entry.name), { force: true });
  }
}
// 只保留 dart2js + CanvasKit 需要的渲染资源。
for (const name of ['skwasm.wasm', 'skwasm_heavy.wasm', 'wimp.wasm', 'skwasm.js', 'skwasm_heavy.js', 'wimp.js']) {
  await rm(path.join(dest, 'canvaskit', name), { force: true });
}
await rm(path.join(dest, 'canvaskit', 'webparagraph'), { recursive: true, force: true });


async function sizeOf(dir) {
  let total = 0;
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) total += await sizeOf(full);
    else total += (await stat(full)).size;
  }
  return total;
}

console.log(`synced ${source} -> ${dest}`);
console.log(`size ${(await sizeOf(dest) / 1048576).toFixed(1)} MB；已关闭 Service Worker，移除 gzip 旁文件`);
