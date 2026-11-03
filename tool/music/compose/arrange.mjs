// The deterministic arranger: a validated brief plus its motifs becomes score JSON in the
// format the game already plays. No model and no wall clock: same inputs, same bytes.
import {MODES,makeRng,pick,buildTimeline,bassRootFifth,bassWalking,bassTumbao,bassPedal,comp,pad,voiceLead,parseChord} from './harmony.mjs';
import {applyOp,fitToHarmony,counterLine,fills} from './motif.mjs';

const round=n=>Math.round(n*10000)/10000;
const DEFAULT_PLAN=['statement','sequence','answer','cadence'];

function percussion(part,brief,timeline,rng){
 const out=[],layers=brief.groove.layers??[],pattern=brief.groove.pattern;
 const add=(beat,pitch,duration,velocity)=>out.push({beat,pitch,duration,velocity});
 if(part.kit==='fills'){
  for(const n of fills(timeline,rng))add(n.beat,n.pitch,n.duration,55+Math.floor(rng()*14));
  return out;
 }
 for(const entry of timeline){
  const b=entry.bar*4,odd=entry.bar%2===1;
  if(part.kit==='clave'){
   // Son clave 3-2 (en.wikipedia.org/wiki/Salsa_(musical_structure)), alone on its pitch.
   for(const x of odd?[1,2]:[0,1.5,3])add(b+x,75,.09,56);
  }else if(part.kit==='anchor'){
   // Project judgement: a soft pulse so players can still find the beat over an anticipated bass.
   for(const x of [0,2])add(b+x,36,.14,58);
   for(const x of [1,3])add(b+x,73,.1,30);
  }else if(part.kit==='conga'){
   // Sources say the conga pattern stresses beat 4 (en.wikipedia.org/wiki/Tumbao); the hits around it are project judgement.
   for(const x of pick(rng,[[1,3,3.5],[1,2.5,3,3.5],[.5,1,3,3.5],[1,1.75,3,3.5]]))add(b+x,x>=3?64:63,.14,x>=3?62:46);
  }else if(part.kit==='cascara'){
   // Project judgement: a shell-like syncopated eighth line, not a transcribed pattern.
   for(const x of odd?[0,1,1.5,2.5,3.5]:[0,.5,1.5,2,3])add(b+x,73,.12,x%1===0?44:34);
  }else if(part.kit==='campana'){
   for(const x of [0,1,2,3])add(b+x,65,.12,x===0?60:46);
   add(b+1.5,60,.1,38);
  }else if(part.kit==='shaker'){
   // Project judgement: the shaker motif sits between the scraper's eighths.
   for(const x of odd?[.25,.75,1.25,2.25,2.75,3.25,3.75]:[.25,.75,1.75,2.25,2.75,3.75])add(b+x,73,.07,26);
  }else if(part.kit==='core'){
   const kicks=pattern==='half-time'?[0]:[0,2];
   for(const x of kicks)add(b+x,36,.16,86);
   if(layers.includes('double-time-kick'))for(const x of [1,3])add(b+x,36,.12,64);
   for(const x of pattern==='half-time'?[2]:[1,3])add(b+x,38,.12,54);
   for(let x=0;x<4;x+=.5)add(b+x,73,.16,x%1===0?42:31);
  }else if(part.kit==='lift'){
   for(const x of pick(rng,[[1.5,2.75,3.5],[1.5,3,3.5],[.75,1.5,2.75,3.5],[1.5,2.5,2.75]]))add(b+x,x%1===.75?64:63,.16,58);
  }else if(part.kit==='bright'){
   const clave=layers.includes('clave')?(odd?[1,2]:[0,1.5,3]):[.5,2.5];
   for(const x of clave)add(b+x,75,.09,45);
  }
 }
 return out;
}

function melodyPart(part,brief,timeline,motif){
 const beats=motif.beats,out=[];
 const chordAt=beat=>timeline[Math.floor(beat/4)];
 let previous=null,start=0;
 for(const form of brief.form){
  const key=timeline[start/4],plan=part.plan?.[form.section]??DEFAULT_PLAN,scale=MODES[key.mode];
  const context={scale,beats};
  const phrases=Math.floor(form.bars*4/beats);
  for(let i=0;i<phrases;i++){
   const base=start+i*beats;
   const shaped=applyOp(plan[i%plan.length],motif.notes,context);
   const fitted=fitToHarmony(shaped,{tonic:key.tonic,mode:key.mode,start:base,chordAt,register:part.register??[60,88],previous});
   if(fitted.length)previous=fitted.at(-1).pitch;
   for(const n of fitted)out.push({...n,duration:Math.min(n.duration,base+beats-n.beat)});
  }
  start+=form.bars*4;
 }
 return out;
}
/** A restrained form of a melody: enough notes to carry the hook, softer and shorter. */
function thinHook(notes,phraseBeats){
 const out=[];
 const byPhrase=new Map();
 for(const n of notes){const k=Math.floor(n.beat/phraseBeats);if(!byPhrase.has(k))byPhrase.set(k,[]);byPhrase.get(k).push(n)}
 for(const phrase of byPhrase.values()){
  let kept=phrase.filter((_,i)=>i%2===0||i===phrase.length-1);
  if(kept.length<4)kept=phrase;
  for(const n of kept)out.push({...n,duration:n.duration*.85});
 }
 return out;
}
function stabs(timeline,register,rng){
 const out=[];let previous=null;
 for(const entry of timeline){
  const voiced=voiceLead(previous,entry.pcs,3,register);previous=voiced;
  if(entry.bar%2===0)continue;
  const at=pick(rng,[[2.5],[2.5,3.25],[1.5,3.5],[3,3.5]]);
  for(const x of at)for(const pitch of voiced)out.push({beat:entry.bar*4+x,pitch,duration:.45});
 }
 return out;
}

/** Brass riffs on a two-bar cycle, for mambo sections. Project judgement, not a transcription. */
const MAMBO=[[0,.75,1.5,2.5,3.25],[.5,1.25,2,3,3.5],[.5,1.5,2.25,3.5],[0,1,1.5,2.75,3.5]];
function mambo(timeline,register,rng){
 const out=[];let previous=null,riff=pick(rng,MAMBO);
 for(const entry of timeline){
  const voiced=voiceLead(previous,entry.pcs,3,register);previous=voiced;
  if(entry.bar%2===0)riff=pick(rng,MAMBO);
  const shape=entry.bar%2===0?riff:pick(rng,MAMBO);
  for(const x of shape)for(const pitch of voiced)out.push({beat:entry.bar*4+x,pitch,duration:.35});
 }
 return out;
}

function tierRanges(brief){
 const ranges=new Map();
 brief.tiers.forEach((tier,index)=>{
  for(const id of tier.adds)ranges.set(id,{minTier:index,maxTier:4});
  for(const id of tier.removes??[])ranges.get(id).maxTier=index-1;
 });
 return ranges;
}

function renderParts(brief,timeline,motifs){
 const ranges=tierRanges(brief),events=[];
 const melodies={};
 const rngFor=id=>makeRng(brief.seed,id);
 // A hook thins its motif's full melody, so both have to share one line.
 const fullFirst=brief.parts.filter(p=>p.role==='melody').sort((a,b)=>(a.style==='hook')-(b.style==='hook'));
 for(const part of fullFirst)melodies[part.motif]??=melodyPart(part,brief,timeline,motifs[part.motif]);
 const primary=melodies[brief.parts.find(p=>p.role==='melody').motif];
 for(const part of brief.parts){
  const rng=rngFor(part.id),range=ranges.get(part.id),velocity=part.velocity??70;
  let notes;
  if(part.role==='percussion')notes=percussion(part,brief,timeline,rng);
  else if(part.role==='bass'){
   notes=[];
   timeline.forEach((entry,i)=>notes.push(...(part.style==='tumbao'?bassTumbao(entry,timeline[(i+1)%timeline.length],rng):part.style==='walking'?bassWalking(entry,timeline[(i+1)%timeline.length],rng):part.style==='pedal'?bassPedal(entry):bassRootFifth(entry,rng))));
  }
  else if(part.role==='comp')notes=comp(timeline,part.style,part.register??[55,79],rng);
  else if(part.role==='pad')notes=pad(timeline,part.register??[48,72]);
  else if(part.role==='stabs')notes=(part.style==='mambo'?mambo:stabs)(timeline,part.register??[58,82],rng);
  else if(part.role==='counter')notes=counterLine(primary,timeline,part.register??[67,91],rng);
  else if(part.role==='melody'){
   notes=part.style==='hook'?thinHook(melodies[part.motif],motifs[part.motif].beats):melodyPart(part,brief,timeline,motifs[part.motif]);
  }
  if(part.sections){
   const allowed=new Set(timeline.filter(e=>part.sections.includes(e.section)).map(e=>e.bar));
   notes=notes.filter(n=>allowed.has(Math.floor(n.beat/4)));
  }
  for(const n of notes)events.push({track:part.track,beat:n.beat,pitch:n.pitch,duration:n.duration,velocity:n.velocity??velocity,...range});
 }
 return events;
}

/** Same track, beat and pitch in overlapping tiers would sound twice. Keep one. */
function dedupe(events){
 const kept=new Map();
 for(const e of events){
  const key=`${e.track}|${e.beat}|${e.pitch}`;
  const list=kept.get(key)??[];
  const clash=list.find(o=>o.minTier<=e.maxTier&&e.minTier<=o.maxTier);
  if(clash){clash.minTier=Math.min(clash.minTier,e.minTier);clash.maxTier=Math.max(clash.maxTier,e.maxTier);clash.velocity=Math.max(clash.velocity,e.velocity)}
  else{list.push({...e});kept.set(key,list)}
 }
 return [...kept.values()].flat();
}
function finish(events,totalBeats,swing=0){
 const out=[];
 for(const e of dedupe(events)){
  const beat=e.beat%1===.5&&e.track!=='pulse'?e.beat+swing*.5:e.beat;
  // Nothing rings past the form: this is what keeps loop seams clean.
  const duration=Math.min(e.duration,totalBeats-beat);
  if(duration<=0)continue;
  out.push({...e,beat:round(beat),duration:round(duration)});
 }
 return out.sort((a,b)=>a.beat-b.beat||a.track.localeCompare(b.track)||a.pitch-b.pitch||a.minTier-b.minTier);
}

export function tracksOf(brief){
 const seen=new Map();let channel=0;
 for(const part of brief.parts){
  if(seen.has(part.track))continue;
  const id=part.track,assigned=id==='pulse'?9:channel++;
  if(channel===9)channel++;
  seen.set(id,{id,channel:assigned,program:part.program??0,voice:part.voice});
 }
 return [...seen.values()];
}

function adornments(brief,timeline){
 const entry=timeline[0],tonic=entry.tonic,scale=MODES[entry.mode];
 const chord=parseChord(brief.harmony[entry.section][0],entry.mode);
 const third=chord.root+chord.intervals[1],fifth=chord.root+chord.intervals[2];
 const shapes=[
  ['spark','up',[[0,12+chord.root,.12],[.25,12+third,.12],[.5,12+fifth,.25]]],
  ['dip','down',[[0,12+chord.root,.16],[.25,fifth,.16],[.5,chord.root,.3]]],
  ['slide','left',[[0,fifth,.2],[.25,scale[3],.2],[.5,scale[2],.2],[.75,0,.2]]],
  ['shine','right',[[0,0,.2],[.25,fifth,.2],[.5,12,.4]]],
 ];
 return shapes.map(([id,gesture,events])=>({id,gesture,quantizeBeats:.25,
  events:events.map(([beat,pitch,duration])=>({track:'answer',beat,pitch:tonic+pitch,duration,velocity:65,minTier:0}))}));
}

export function arrange(brief,motifs){
 const timeline=buildTimeline(brief),totalBars=timeline.length,totalBeats=totalBars*4;
 const events=finish(renderParts(brief,timeline,motifs),totalBeats,brief.groove.swing??0);
 const first=timeline[0];
 let bar=0;
 const sections=brief.form.map(f=>{const s={bar,bars:f.bars,name:f.name};bar+=f.bars;return s});
 return {schemaVersion:1,id:brief.id,title:brief.title,stat:brief.stat,composer:'Kumbia Kombat original project score',
  license:'See assets/music/LICENSE.md',ppq:480,beatsPerBar:4,bars:totalBars,phraseBars:2,
  key:{midiTonic:first.tonic,mode:first.mode},style:brief.style??'Original synth instrumental',color:brief.color??brief.prompt,
  tiers:brief.tiers.map((t,tier)=>({tier,bpm:brief.bpm+3*tier,name:t.name})),
  sections,tracks:tracksOf(brief),events,adornments:adornments(brief,timeline),
  gameplayReference:brief.gameplayReference??{authority:'lib/game campaign configuration; score EOF does not approve an opponent'},
  transition:{cadenceBars:2,nextLevelCountInBars:1},
  provenance:{brief:brief.id,prompt:brief.prompt,seed:brief.seed,arranger:'tool/music/compose/arrange.mjs',status:'candidate',
   motifs:Object.fromEntries(Object.entries(motifs).map(([k,m])=>[k,{id:m.id,...m.provenance}]))}};
}

function transitionBase(id,title,meta,tiers,tracks,events,kind,sectionName){
 return {schemaVersion:1,id,title,stat:meta.stat,kind,composer:'Kumbia Kombat original project score',
  license:'See assets/music/LICENSE.md',ppq:480,beatsPerBar:4,bars:2,phraseBars:2,
  key:{midiTonic:meta.tonic,mode:meta.mode},style:meta.style,tiers,tracks,
  sections:[{bar:0,bars:2,name:sectionName}],
  events:events.sort((a,b)=>a.beat-b.beat||a.track.localeCompare(b.track)||a.pitch-b.pitch),adornments:[]};
}
const transitionNote=(track,beat,pitch,duration,velocity)=>({track,beat:round(beat),pitch,duration:round(duration),velocity,minTier:0,maxTier:4});

/** Two bars: recognition, then a thinner warm-down that keeps the beat and the tonic answer. */
export function composeSuccess(brief,motifs){
 const timeline=buildTimeline(brief),first=timeline[0],tonic=first.tonic,mode=first.mode,scale=MODES[mode];
 const rng=makeRng(brief.seed,'success'),third=mode==='major'||mode==='mixolydian'?4:3;
 const motif=motifs[brief.parts.find(p=>p.role==='melody').motif];
 const events=[],note=(...a)=>events.push(transitionNote(...a));
 for(let beat=0;beat<8;beat+=.5){
  if(beat>=4&&beat%1!==0)continue;
  note('pulse',beat,73,.14,beat>=4?28:beat%1===0?44:34);
 }
 for(const beat of [0,2,4,6])note('pulse',beat,36,.18,beat>=4?62:82);
 for(const beat of [1,3,5,7])note('pulse',beat,38,.12,beat>=4?34:48);
 for(const beat of pick(rng,[[1.5,3.5],[1.5,2.75],[1.5,3,3.5]]))note('pulse',beat,63,.12,64);
 for(const beat of [0,4]){
  note('bass',beat,tonic-24,1.4,beat===0?82:66);note('bass',beat+2,tonic-17,.7,beat===0?74:58);
  const offbeats=beat===0?[.5,1.5,2.5,3.5]:[.5,2.5],voicing=beat===0?[0,third,7]:[third,7];
  for(const x of offbeats)for(const interval of voicing)note('guitar',beat+x,tonic+interval,.22,beat===0?52:38);
 }
 for(const [beat,semi,duration] of motif.notes.filter(n=>n[0]<4))note('lead',beat,tonic+semi+12,duration,84);
 const fall=[[4,scale[4]],[4.75,scale[3]],[5.5,scale[2]],[6.5,scale[1]]];
 for(const [beat,semi] of fall)note('lead',beat,tonic+semi+12,.5,68);
 note('lead',7,tonic+12,.75,68);
 for(const interval of [0,third,7])note('brass',7,tonic+interval,.875,40);
 const result=transitionBase(`${brief.id}_success`,`${brief.title} — Room Approval`,{stat:brief.stat,tonic,mode,style:brief.style??'Original synth instrumental'},
  brief.tiers.map((t,tier)=>({tier,bpm:brief.bpm+3*tier,name:'Authored transition'})),tracksOf(brief),events,'success','Recognition and tonic answer');
 result.parentScore=brief.id;
 result.musicalIntent=brief.transitions?.successIntent??'Quote the room call, then thin to a warm tonic answer.';
 return result;
}

/**
 * Two bars: a percussion pivot in the first, the destination's call in the second.
 * `to` is {id, stat, tonic, mode, bpm, style, tracks, pickup: [[beat, semis, duration]]}.
 */
export function composeBridge(id,title,fromId,to,seed,intent){
 const rng=makeRng(seed,id),events=[],note=(...a)=>events.push(transitionNote(...a));
 const clave=pick(rng,[[0,1.5,3,4.5,6],[0,.75,2.5,4,5.5,7],[0,.5,1.25,2,2.75,3.5,4.5,6],[0,2,3.5,4,5.5,7]]);
 for(const beat of clave)note('pulse',beat,75,.1,62);
 for(let beat=0;beat<8;beat+=.5)note('pulse',beat,73,.13,beat%1===0?40:28);
 for(const beat of [0,2,4,6])note('pulse',beat,36,.16,78);
 pick(rng,[[64,63,65,60],[60,64,63,65],[65,63,64,60]]).forEach((pitch,j)=>note('pulse',2.5+j*.375,pitch,.14,52+j*6));
 for(const [beat,semi,duration] of to.pickup)note('answer',4+beat,to.tonic+semi,Math.min(duration,7.75-(4+beat)),72);
 note('bass',4,to.tonic-24,.9,78);note('bass',6,to.tonic-17,.65,72);
 const third=to.mode==='major'||to.mode==='mixolydian'?4:3;
 for(const beat of [4.5,5.5,6.5])for(const interval of [0,third,7])note('guitar',beat,to.tonic+interval,.24,48);
 note('bass',7,to.tonic-17,.7,74);
 note('answer',7.5,to.tonic+7,.25,68);
 note('pulse',7.75,65,.12,72);
 const result=transitionBase(id,title,{stat:to.stat,tonic:to.tonic,mode:to.mode,style:to.style},
  Array.from({length:5},(_,tier)=>({tier,bpm:to.bpm,name:'Authored transition'})),to.tracks,events,'bridge','Percussion pivot and tonal pickup');
 result.fromScore=fromId;result.toScore=to.id;result.musicalIntent=intent;
 result.tempoIntent='Written percussion pivot takes the destination base tempo at its downbeat; the second bar introduces the destination motif. No pitch/time crossfade.';
 return result;
}

/** What a bridge needs to know about a room built from a brief. */
export function bridgeTargetFromBrief(brief,motifs){
 const first=buildTimeline(brief)[0];
 const motif=motifs[brief.parts.find(p=>p.role==='melody').motif];
 return {id:brief.id,stat:brief.stat,tonic:first.tonic,mode:first.mode,bpm:brief.bpm,style:brief.style??'Original synth instrumental',
  tracks:tracksOf(brief),pickup:motif.notes.filter(n=>n[0]<3.5)};
}
/** The same, read back from a shipped score: its call is the tier-3 lead's first bar. */
export function bridgeTargetFromScore(score){
 const tonic=score.key.midiTonic;
 const lead=score.events.filter(e=>e.track==='lead'&&e.minTier===3&&e.beat<3.5).map(e=>[e.beat,e.pitch-tonic,e.duration]);
 return {id:score.id,stat:score.stat,tonic,mode:score.key.mode,bpm:score.tiers[0].bpm,style:score.style,tracks:score.tracks,pickup:lead};
}
