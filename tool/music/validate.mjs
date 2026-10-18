#!/usr/bin/env node
import assert from 'node:assert/strict';
import {readFileSync, readdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const manifest=JSON.parse(readFileSync(resolve(root,'assets/music/manifest.json')));
assert.equal(manifest.scores.length,5);
const signatures=new Set();let notes=0;
for(const entry of manifest.scores){
 const score=JSON.parse(readFileSync(resolve(root,entry.path)));
 assert.equal(score.schemaVersion,1);assert.equal(score.tiers.length,5);
 assert.equal(score.adornments.length,4);assert.equal(score.bars%score.phraseBars,0);
 signatures.add(JSON.stringify(score.events.filter(n=>n.track==='lead'&&n.minTier===3).slice(0,9)));
 let previous=-1;
 for(const event of score.events){
  assert.ok(event.beat>=previous);previous=event.beat;
  assert.ok(event.duration>0&&event.beat+event.duration<=score.bars*4);
  assert.ok(event.pitch>=0&&event.pitch<=127&&event.velocity>0&&event.velocity<=127);
  assert.ok(event.minTier>=0&&event.minTier<=event.maxTier&&event.maxTier<=4);
  assert.ok(score.tracks.some(t=>t.id===event.track));notes++;
 }
 let previousCount=0;
 for(let tier=0;tier<5;tier++){
  const events=score.events.filter(n=>n.minTier<=tier&&n.maxTier>=tier);
  assert.ok(events.length>previousCount,'Every arrangement tier adds composed content');previousCount=events.length;
  const midi=readFileSync(resolve(root,`assets/music/midi/${score.id}_tier${tier}.mid`));
  assert.equal(midi.toString('ascii',0,4),'MThd');assert.equal(midi.readUInt16BE(8),1);
  assert.equal(midi.readUInt16BE(10),7);assert.equal(midi.readUInt16BE(12),480);
  let offset=14,totalOns=0,totalOffs=0;
  for(let track=0;track<7;track++){
   assert.equal(midi.toString('ascii',offset,offset+4),'MTrk');
   const end=offset+8+midi.readUInt32BE(offset+4);offset+=8;let tick=0;const active=new Map();
   const vlq=()=>{let value=0,byte;do{byte=midi[offset++];value=value*128+(byte&127)}while(byte&128);return value};
   while(offset<end){tick+=vlq();const status=midi[offset++];if(status===255){const type=midi[offset++],length=vlq();offset+=length;if(type===47)assert.equal(offset,end);}
    else if((status&240)===192)offset++;
    else{const pitch=midi[offset++],velocity=midi[offset++],key=`${status&15}:${pitch}`;
     if((status&240)===144&&velocity>0){totalOns++;active.set(key,(active.get(key)||0)+1);}
     else{totalOffs++;assert.ok(active.get(key)>0,'MIDI note-off must match note-on');active.set(key,active.get(key)-1);}}
   }
   assert.ok([...active.values()].every(n=>n===0),'No stuck MIDI notes');
   if(track>0)assert.equal(tick,score.bars*4*480,'MIDI track ends at score boundary');
   assert.equal(offset,end);
  }
  assert.equal(totalOns,events.length);assert.equal(totalOffs,totalOns);assert.equal(offset,midi.length);
 }
}
assert.equal(signatures.size,5,'All five lead compositions must differ');
assert.equal(readdirSync(resolve(root,'assets/music/midi')).filter(f=>f.endsWith('.mid')).length,25);
console.log(`PASS: five unique scores, ${notes} valid notes, all 25 MIDI files parsed with balanced attacks/releases, five increasing tiers and four adornments per score`);
