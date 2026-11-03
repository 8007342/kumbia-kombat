#!/usr/bin/env node
// Complexity gates over score JSON (openspec change score-composition-pipeline, design D3).
// They catch bad patterns; they are not evidence that music sounds good.
//   node tool/music/compose/gates.mjs [--root <dir>] [--report] [id ...]
// Exits 1 when any named or manifest room score fails, unless --report is given.
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

// Starting values, to be tuned by listening. They are not measurements of quality.
export const THRESHOLDS={
 maxBarRepeat:0.60,        // share of pitched bars that copy, or transpose, an earlier bar
 maxMelodyBarRepeat:0.40,  // the same for melody tracks only
 minPhraseVariety:0.40,    // distinct 2-bar phrases / phrases, melody tracks
 minChordRoots:4,          // distinct bass roots across the score
 minSectionHarmonies:2,    // distinct section-level bass progressions
 minIndependence:0.55,     // 1 - mean onset overlap between pitched track pairs
 minPitchEntropy:0.45,     // pitch-class entropy per melody track, 0..1
 minRhythmPatterns:4,      // distinct bar rhythms per melody track
 minDensityStep:1.05,      // notes in tier n / notes in tier n-1
 maxVelocityShare:0.5,     // velocity-only changes / all changes between adjacent tiers
};
const MELODY=new Set(['lead','answer']);
const r3=n=>Math.round(n*1000)/1000;
export const notesAt=(score,tier)=>score.events.filter(e=>e.minTier<=tier&&e.maxTier>=tier);
const pitchedTracks=score=>score.tracks.map(t=>t.id).filter(id=>id!=='pulse');

function bars(notes,beatsPerBar,span){
 const out=new Map();
 for(const n of notes){
  const i=Math.floor(n.beat/(beatsPerBar*span)+1e-9);
  if(!out.has(i))out.set(i,[]);
  out.get(i).push(n);
 }
 return out;
}
// Transposition-invariant: positions, intervals from the bar's first note, and durations.
function signature(notes,start){
 const sorted=[...notes].sort((a,b)=>a.beat-b.beat||a.pitch-b.pitch);
 return sorted.map(n=>`${r3(n.beat-start)}:${n.pitch-sorted[0].pitch}:${r3(n.duration)}`).join(' ');
}
const rhythmOf=(notes,start)=>[...new Set(notes.map(n=>r3(n.beat-start)))].sort((a,b)=>a-b).join(' ');

function repetition(score,track,span=1){
 const size=score.beatsPerBar*span,seen=new Map();
 let total=0,repeated=0;
 for(const [i,notes] of bars(notesAt(score,4).filter(n=>n.track===track),score.beatsPerBar,span)){
  const sig=signature(notes,i*size);total++;
  if(seen.has(sig))repeated++;else seen.set(sig,[]);
  seen.get(sig).push(i);
 }
 const worst=[...seen.entries()].sort((a,b)=>b[1].length-a[1].length)[0];
 return {total,repeated,distinct:seen.size,worstBars:worst?.[1]??[]};
}
function harmony(score){
 const bass=notesAt(score,4).filter(n=>n.track==='bass');
 const roots=[];
 for(let bar=0;bar<score.bars;bar++){
  const inBar=bass.filter(n=>n.beat>=bar*score.beatsPerBar&&n.beat<(bar+1)*score.beatsPerBar);
  const first=inBar.sort((a,b)=>a.beat-b.beat||a.pitch-b.pitch)[0];
  roots.push(first?((first.pitch%12)+12)%12:null);
 }
 let changes=0;for(let i=1;i<roots.length;i++)if(roots[i]!==roots[i-1])changes++;
 const sections=(score.sections??[]).map(s=>roots.slice(s.bar,s.bar+s.bars).join(','));
 return {chordRoots:new Set(roots.filter(r=>r!==null)).size,changesPer8Bars:r3(changes/score.bars*8),sectionHarmonies:new Set(sections).size};
}
function independence(score){
 const tracks=pitchedTracks(score).map(id=>({id,on:new Set(notesAt(score,4).filter(n=>n.track===id).map(n=>r3(n.beat)))})).filter(t=>t.on.size);
 const pairs=[];
 for(let a=0;a<tracks.length;a++)for(let b=a+1;b<tracks.length;b++){
  const both=[...tracks[a].on].filter(x=>tracks[b].on.has(x)).length;
  pairs.push({pair:`${tracks[a].id}/${tracks[b].id}`,overlap:both/(tracks[a].on.size+tracks[b].on.size-both)});
 }
 if(!pairs.length)return {value:0,mostParallel:null};
 const top=[...pairs].sort((x,y)=>y.overlap-x.overlap)[0];
 return {value:r3(1-pairs.reduce((s,p)=>s+p.overlap,0)/pairs.length),mostParallel:`${top.pair} ${r3(top.overlap)}`};
}
function entropy(score,track){
 const counts=new Array(12).fill(0);let total=0;
 for(const n of notesAt(score,4))if(n.track===track){counts[n.pitch%12]++;total++;}
 if(!total)return 0;
 return r3(-counts.filter(Boolean).reduce((s,c)=>s+(c/total)*Math.log2(c/total),0)/Math.log2(12));
}
function rhythms(score,track){
 const size=score.beatsPerBar,set=new Set();
 for(const [i,notes] of bars(notesAt(score,4).filter(n=>n.track===track),size,1))set.add(rhythmOf(notes,i*size));
 return set.size;
}
function build(score){
 const key=n=>`${n.track}|${r3(n.beat)}|${n.pitch}`;
 const steps=[];
 for(let tier=1;tier<5;tier++){
  const low=new Map(notesAt(score,tier-1).map(n=>[key(n),n])),high=new Map(notesAt(score,tier).map(n=>[key(n),n]));
  let added=0,removed=0,velocity=0;
  for(const [k,n] of high){if(!low.has(k))added++;else if(low.get(k).velocity!==n.velocity)velocity++;}
  for(const k of low.keys())if(!high.has(k))removed++;
  const voices=t=>new Set(notesAt(score,t).map(n=>n.track)).size;
  steps.push({tier,notes:high.size,density:r3(high.size/Math.max(1,low.size)),voices:voices(tier),velocityShare:r3(velocity/Math.max(1,added+removed+velocity))});
 }
 return steps;
}

export function evaluate(score,thresholds=THRESHOLDS){
 const T=thresholds,failures=[],fail=(gate,message)=>failures.push({gate,message});
 const pitched=pitchedTracks(score).filter(id=>notesAt(score,4).some(n=>n.track===id));
 const perTrack=Object.fromEntries(pitched.map(id=>[id,repetition(score,id)]));
 const sum=f=>pitched.reduce((s,id)=>s+f(perTrack[id]),0);
 const barRepeat=r3(sum(r=>r.repeated)/Math.max(1,sum(r=>r.total)));
 const melody=pitched.filter(id=>MELODY.has(id));
 const melodyRepeat=r3(melody.reduce((s,id)=>s+perTrack[id].repeated,0)/Math.max(1,melody.reduce((s,id)=>s+perTrack[id].total,0)));
 const phrase=Object.fromEntries(melody.map(id=>{const r=repetition(score,id,score.phraseBars);return [id,r3(r.distinct/Math.max(1,r.total))]}));
 const h=harmony(score),ind=independence(score),steps=build(score);
 const melodyDetail=Object.fromEntries(melody.map(id=>[id,{pitchEntropy:entropy(score,id),rhythmPatterns:rhythms(score,id)}]));
 const metrics={barRepeat,melodyBarRepeat:melodyRepeat,repeatByTrack:Object.fromEntries(pitched.map(id=>[id,r3(perTrack[id].repeated/Math.max(1,perTrack[id].total))])),
  phraseVariety:phrase,...h,independence:ind.value,mostParallel:ind.mostParallel,melody:melodyDetail,tiers:steps};
 const worstNamed=(ids=pitched)=>{const id=[...ids].sort((a,b)=>perTrack[b].repeated-perTrack[a].repeated)[0];const bars=perTrack[id].worstBars;
  return `${id}: one pattern (or its transposition) fills ${bars.length} bars, first at bars ${bars.slice(0,4).join(', ')}`};
 if(barRepeat>T.maxBarRepeat)fail('repetition',`${barRepeat} of pitched bars copy or transpose an earlier bar (limit ${T.maxBarRepeat}); ${worstNamed()}`);
 if(melody.length&&melodyRepeat>T.maxMelodyBarRepeat)fail('melody-repetition',`${melodyRepeat} of melody bars copy or transpose an earlier bar (limit ${T.maxMelodyBarRepeat}); ${worstNamed(melody)}`);
 for(const [id,v] of Object.entries(phrase))if(v<T.minPhraseVariety)fail('phrase-variety',`${id}: only ${v} of its phrases are distinct (minimum ${T.minPhraseVariety})`);
 if(h.chordRoots<T.minChordRoots)fail('harmony',`${h.chordRoots} distinct chord roots (minimum ${T.minChordRoots})`);
 if(score.sections?.length>1&&h.sectionHarmonies<T.minSectionHarmonies)fail('harmony',`${h.sectionHarmonies} distinct section progressions (minimum ${T.minSectionHarmonies})`);
 if(ind.value<T.minIndependence)fail('independence',`voice independence ${ind.value} (minimum ${T.minIndependence}); most parallel ${ind.mostParallel}`);
 for(const [id,m] of Object.entries(melodyDetail)){
  if(m.pitchEntropy<T.minPitchEntropy)fail('pitch-variety',`${id}: pitch entropy ${m.pitchEntropy} (minimum ${T.minPitchEntropy})`);
  if(m.rhythmPatterns<T.minRhythmPatterns)fail('rhythm-variety',`${id}: ${m.rhythmPatterns} bar rhythms (minimum ${T.minRhythmPatterns})`);
 }
 for(const s of steps){
  if(s.density<T.minDensityStep)fail('build',`tier ${s.tier} has ${s.density}x the notes of tier ${s.tier-1} (minimum ${T.minDensityStep})`);
  if(s.velocityShare>T.maxVelocityShare)fail('louder-not-richer',`tier ${s.tier} differs from tier ${s.tier-1} mostly by velocity (${s.velocityShare} of changes)`);
 }
 if(steps[3].voices<=new Set(notesAt(score,0).map(n=>n.track)).size)fail('build','tier 4 uses no more voices than tier 0');
 return {id:score.id,passed:failures.length===0,metrics,failures};
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);let base=resolve(dirname(fileURLToPath(import.meta.url)),'../../..'),report=false;const ids=[];
 for(let i=0;i<args.length;i++){if(args[i]==='--root')base=resolve(args[++i]);else if(args[i]==='--report')report=true;else ids.push(args[i]);}
 const manifest=JSON.parse(readFileSync(resolve(base,'assets/music/manifest.json')));
 let failed=0;
 for(const entry of manifest.scores.filter(s=>!ids.length||ids.includes(s.id))){
  const result=evaluate(JSON.parse(readFileSync(resolve(base,entry.path))));
  if(!result.passed)failed++;
  console.log(JSON.stringify(result));
 }
 console.log(`${failed} failing score(s)`);
 if(failed&&!report)process.exit(1);
}
