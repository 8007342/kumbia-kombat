import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');
const table=JSON.parse(readFileSync(resolve(root,'tool/music/voices.json')));
const dart=readFileSync(resolve(root,'lib/music/voice_recipes.dart'),'utf8');

test('voices.json and the Dart recipes list the same voices',()=>{
 const inDart=[...dart.matchAll(/^  '(\w+)': VoiceRecipe\(/gm)].map(m=>m[1]).sort();
 assert.deepEqual(inDart,[...table.recipes].sort());
});
test('no recipe shadows a shipped voice, so shipped scores keep their sound',()=>{
 for(const voice of table.existing)assert.ok(!table.recipes.includes(voice),voice);
 const shipped=JSON.parse(readFileSync(resolve(root,'assets/music/scores/bar_swag.json')));
 for(const t of shipped.tracks)assert.ok(table.existing.includes(t.voice),t.voice);
});
