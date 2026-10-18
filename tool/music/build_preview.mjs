#!/usr/bin/env node
import { mkdirSync, cpSync, copyFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const output=resolve(root,'build/music-preview');
mkdirSync(output,{recursive:true});
writeFileSync(resolve(output,'packages.json'),JSON.stringify({configVersion:2,packages:[]}));
execFileSync('dart',['compile','js','--packages='+resolve(output,'packages.json'),resolve(root,'tool/music/preview.dart'),'-o',resolve(output,'main.js')],{stdio:'inherit'});
copyFileSync(resolve(root,'tool/music/preview.html'),resolve(output,'index.html'));
cpSync(resolve(root,'assets/music'),resolve(output,'assets/music'),{recursive:true});
console.log('Music preview built at build/music-preview/index.html. Serve this directory over HTTP.');
