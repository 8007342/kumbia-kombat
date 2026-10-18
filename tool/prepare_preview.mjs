#!/usr/bin/env node
// Run after `npm run build`; preserve the score room alongside the game.
import { execFileSync } from 'node:child_process';
import { cpSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
if (!existsSync(resolve(root, 'build/web/index.html'))) {
  throw new Error('Build Flutter first with npm run build.');
}
execFileSync('node', [resolve(root, 'tool/music/build_preview.mjs')], {stdio: 'inherit'});
cpSync(resolve(root, 'build/music-preview'), resolve(root, 'build/web/music'), {recursive: true});
console.log('Game: build/web/ ; music playground: build/web/music/');
