import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {validateBrief,validateMotif} from './brief.mjs';

const briefs=resolve(dirname(fileURLToPath(import.meta.url)),'../briefs');
const fresh=()=>JSON.parse(readFileSync(resolve(briefs,'bar_swag.json')));
const loadMotif=p=>JSON.parse(readFileSync(resolve(briefs,p)));

test('the bar brief is valid, including its motif files',()=>{
 assert.deepEqual(validateBrief(fresh(),{loadMotif}),[]);
});

test('an unknown voice is refused by name',()=>{
 const brief=fresh();
 brief.voices.push('kazooOfDoom');
 assert.ok(validateBrief(brief).some(p=>p.includes('$.voices[6]')&&p.includes('"kazooOfDoom"')));
 const other=fresh();
 other.parts[0].voice='kazooOfDoom';
 assert.ok(validateBrief(other).some(p=>p.includes('$.parts[0].voice')&&p.includes('"kazooOfDoom"')));
});

test('an unknown section is refused by name',()=>{
 const brief=fresh();
 brief.harmony.Z=['i'];
 assert.ok(validateBrief(brief).some(p=>p.includes('$.harmony.Z')&&p.includes('"Z"')));
 const key=fresh();
 key.keys[0].section='Q';
 assert.ok(validateBrief(key).some(p=>p.includes('$.keys[0].section')&&p.includes('"Q"')));
 const plan=fresh();
 plan.parts.find(p=>p.id==='lead').plan.Z=['statement'];
 assert.ok(validateBrief(plan).some(p=>p.includes('.plan.Z')&&p.includes('"Z"')));
});

test('a form that misses a phrase boundary is refused',()=>{
 const brief=fresh();
 brief.form[0].bars=7;
 assert.ok(validateBrief(brief).some(p=>p.includes('$.form[0].bars')));
});

test('unknown fields and parts are refused by name',()=>{
 const field=fresh();
 field.tempoo=1;
 assert.ok(validateBrief(field).some(p=>p.includes('$.tempoo')));
 const part=fresh();
 part.tiers[1].adds.push('ghost');
 assert.ok(validateBrief(part).some(p=>p.includes('$.tiers[1].adds')&&p.includes('"ghost"')));
});

test('a part that never plays is refused',()=>{
 const brief=fresh();
 brief.tiers[4].adds=brief.tiers[4].adds.filter(id=>id!=='stabs');
 assert.ok(validateBrief(brief).some(p=>p.includes('"stabs"')));
});

test('motif schema names problems, and unaccepted candidates are refused',()=>{
 const motif=loadMotif('motifs/bar_swag.lead.json');
 assert.deepEqual(validateMotif(motif),[]);
 assert.ok(validateMotif({...motif,notes:[[9,0,1]]}).some(p=>p.includes('$.notes[0]')));
 assert.ok(validateMotif({...motif,provenance:{source:'mystery',licence:'x',accepted:true}}).some(p=>p.includes('$.provenance.source')));
 const brief=fresh();
 const candidate=p=>({...loadMotif(p),provenance:{source:'amt',licence:'Apache-2.0',accepted:false}});
 assert.ok(validateBrief(brief,{loadMotif:candidate}).some(p=>p.includes('unaccepted candidate')));
});
