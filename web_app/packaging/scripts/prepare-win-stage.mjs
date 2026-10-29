import { cp, mkdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const stage = path.join(root, 'dist', 'win-stage');

await rm(stage, { recursive: true, force: true });
await mkdir(stage, { recursive: true });
await writeFile(
  path.join(stage, 'package.json'),
  JSON.stringify(
    {
      name: 'tingyu',
      productName: '听隅',
      version: '1.1.0',
      description: '听隅 · 给自己，留一小片安静。',
      author: 'Citro',
      license: 'UNLICENSED',
      main: 'electron/main.cjs',
    },
    null,
    2,
  ),
  'utf8',
);
await cp(path.join(root, 'electron'), path.join(stage, 'electron'), { recursive: true });
await cp(path.join(root, 'www'), path.join(stage, 'www'), { recursive: true });
await cp(path.join(root, 'resources'), path.join(stage, 'resources'), { recursive: true });
console.log(`Windows staging ready: ${stage}`);
