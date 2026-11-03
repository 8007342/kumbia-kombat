#!/usr/bin/env node
import assert from 'node:assert/strict';
import {readFileSync, readdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
// --root <dir> validates a candidate pack under <dir>/assets/music by the same rules.
const rootArg=process.argv.indexOf('--root');
const root=rootArg>=0?resolve(process.argv[rootArg+1]):resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const manifest=JSON.parse(readFileSync(resolve(root,'assets/music/manifest.json')));
assert.equal(manifest.scores.length,5);
assert.equal(manifest.transitions.successes.length,5);
assert.equal(manifest.transitions.bridges.length,4);
const signatures=new Set(), transitionSignatures=new Set();let notes=0, midiCount=0;
function validateMidi(path,score,tier){
 const events=score.events.filter(n=>n.minTier<=tier&&n.maxTier>=tier);
 const midi=readFileSync(resolve(root,path));
 assert.equal(midi.toString('ascii',0,4),'MThd');assert.equal(midi.readUInt16BE(8),1);
 const trackCount=score.tracks.length+1;assert.equal(midi.readUInt16BE(10),trackCount);assert.equal(midi.readUInt16BE(12),480);
 let offset=14,totalOns=0,totalOffs=0;
 for(let track=0;track<trackCount;track++){
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
 assert.equal(totalOns,events.length);assert.equal(totalOffs,totalOns);assert.equal(offset,midi.length);midiCount++;
}
const all=[...manifest.scores,...manifest.transitions.successes,...manifest.transitions.bridges];
for(const entry of all){
 const score=JSON.parse(readFileSync(resolve(root,entry.path)));
 assert.equal(score.schemaVersion,1);assert.equal(score.tiers.length,5);
 assert.equal(score.bars%score.phraseBars,0);
 let previous=-1;
 for(const event of score.events){
  assert.ok(event.beat>=previous);previous=event.beat;
  assert.ok(event.duration>0&&event.beat+event.duration<=score.bars*4);
  assert.ok(event.pitch>=0&&event.pitch<=127&&event.velocity>0&&event.velocity<=127);
  assert.ok(event.minTier>=0&&event.minTier<=event.maxTier&&event.maxTier<=4);
  assert.ok(score.tracks.some(t=>t.id===event.track));notes++;
 }
 assert.ok(score.events.some(e=>e.beat===0),'Every segment has an authored downbeat');
 if(!score.kind){
  assert.equal(score.adornments.length,4);
  const baseline=score.events.filter(n=>n.minTier===0);
  for(let phrase=0;phrase<score.bars*4;phrase+=8){
   const heard=baseline.filter(n=>n.beat>=phrase&&n.beat<phrase+8);
   assert.ok(heard.filter(n=>n.track==='lead').length>=4,'Every opening-tier phrase carries its room hook');
   assert.ok(heard.some(n=>n.track==='guitar'),'Opening tier has harmonic accompaniment');
   assert.ok(heard.some(n=>n.track==='bass')&&heard.some(n=>n.track==='pulse'),'Opening tier keeps bass and percussion');
  }
  for(let tier=1;tier<5;tier++)assert.equal(score.tiers[tier].bpm-score.tiers[tier-1].bpm,3,'Orchestration revision preserves authored tempo steps');
  signatures.add(JSON.stringify(score.events.filter(n=>n.track==='lead'&&n.minTier===3).slice(0,9)));
  let previousCount=0;
  for(let tier=0;tier<5;tier++){
   const events=score.events.filter(n=>n.minTier<=tier&&n.maxTier>=tier);
   assert.ok(events.length>previousCount,'Every room tier adds composed content');previousCount=events.length;
   validateMidi(`assets/music/midi/${score.id}_tier${tier}.mid`,score,tier);
  }
 } else {
  assert.equal(score.bars,2);assert.equal(score.adornments.length,0);
  transitionSignatures.add(JSON.stringify(score.events));
  assert.ok(score.events.every(e=>e.minTier===0&&e.maxTier===4),'Successes and bridges are complete authored phrases');
  if(score.kind==='bridge'){
   assert.ok(score.events.filter(e=>e.beat<4).every(e=>e.track==='pulse'),'Bridge starts with a genuine percussion pivot');
   assert.ok(score.events.some(e=>e.beat>=4&&e.track==='answer'),'Bridge introduces destination motif');
  } else {
   const opening=score.events.filter(e=>e.beat<4), settling=score.events.filter(e=>e.beat>=4);
   assert.ok(settling.length<opening.length,'Success second bar thins the ensemble');
   assert.ok(settling.reduce((sum,e)=>sum+e.velocity,0)<opening.reduce((sum,e)=>sum+e.velocity,0),'Success second bar has gentler authored attacks (not a loudness measurement)');
   assert.ok(settling.some(e=>e.track==='lead'),'Warm-down retains the tonic answer');
   assert.ok([4,6].every(beat=>settling.some(e=>e.track==='pulse'&&e.pitch===36&&e.beat===beat)),'Warm-down retains the beat');
  }
  validateMidi(entry.midiPath,score,score.kind==='success'?4:0);
 }
}
assert.equal(signatures.size,5,'All room lead compositions differ');
assert.equal(transitionSignatures.size,9,'Every success and bridge has distinct composed content');
assert.equal(readdirSync(resolve(root,'assets/music/midi')).filter(f=>f.endsWith('.mid')).length,34);
assert.equal(readdirSync(resolve(root,'assets/music/scores')).filter(f=>f.endsWith('.json')).length,14);
console.log(`PASS: 5 room scores + 5 successes + 4 bridges, ${notes} valid notes; ${midiCount} MIDI files parsed with balanced attacks/releases; distinct transition phrases and pitched destination pickups`);
