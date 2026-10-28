#!/usr/bin/env node
// Original Kumbia Kombat compositions. No samples, source songs, or dependencies.
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const PPQ = 480;
const pieces = [
  { id:'garden_mojo', title:'Lanterns in the Garden', stat:'Mojo', bars:32, bpm:92, root:57, mode:'minor', progression:[0,0,5,5,3,3,7,7],
    motif:[[0,0,.5],[.75,3,.25],[1.5,7,.5],[2.5,10,.5],[3.25,7,.5],[4,5,.75],[5,3,.5],[6,2,.5],[7,0,.75]],
    answer:[[0,7,.5],[1,10,.5],[1.75,12,.25],[2.5,10,.5],[3.5,7,.25],[4.5,5,.5],[5.5,3,.5],[6.5,2,.25],[7,0,.5]], program:21, color:'warm reed, muted guitar, dry guiro' },
  { id:'bar_swag', title:'Copper Counter Shuffle', stat:'Swag', bars:32, bpm:100, root:60, mode:'minor', progression:[0,0,8,8,5,5,7,7],
    motif:[[.5,0,.25],[1,7,.5],[2.25,10,.25],[3,7,.5],[4.5,3,.5],[5.25,5,.25],[6,7,.25],[6.75,3,.25],[7.5,0,.25]],
    answer:[[0,12,.5],[.75,10,.25],[1.5,7,.25],[2.25,3,.5],[3.25,5,.25],[4.5,7,.5],[5.5,10,.25],[6.25,7,.5],[7.5,0,.25]], program:5, color:'bright electric keys, rounded bass, tight congas' },
  { id:'crowd_duende', title:'Velvet Current', stat:'Flow', bars:32, bpm:108, root:62, mode:'dorian', progression:[0,0,5,5,0,0,7,7],
    motif:[[0,0,.75],[1.25,2,.25],[2,5,.5],[2.75,9,.5],[3.5,7,.25],[4.25,5,.75],[5.5,3,.5],[6.5,2,.5],[7.25,0,.5]],
    answer:[[.25,7,.75],[1.5,9,.5],[2.5,12,.5],[3.5,9,.25],[4,7,.75],[5.25,5,.5],[6.25,3,.5],[7.25,2,.5]], program:11, color:'marimba call, sine flute answer, airy clave' },
  { id:'restroom_nerve', title:'The Last Cubicle Sprint', stat:'Nerve', bars:16, bpm:132, root:64, mode:'minor', progression:[0,7,0,7,5,7,0,7],
    motif:[[0,0,.25],[.5,0,.25],[1.25,3,.25],[2,7,.25],[2.75,3,.25],[3.5,2,.25],[4,0,.25],[4.75,7,.25],[5.5,10,.25],[6.25,7,.25],[7,2,.5]],
    answer:[[0,12,.25],[.75,7,.25],[1.5,10,.25],[2.25,7,.25],[3,3,.25],[3.5,2,.25],[4.25,0,.25],[5,3,.25],[5.75,7,.25],[6.5,2,.25],[7.25,0,.5]], program:80, color:'short square pluck, clipped timbales, nervous octave bass' },
  { id:'vip_presence', title:'Gold at the Door', stat:'Presence', bars:32, bpm:112, root:65, mode:'major', progression:[0,0,5,5,9,9,7,7],
    motif:[[0,0,.75],[1.5,4,.5],[2.5,7,.75],[3.5,9,.25],[4.5,12,.75],[5.5,9,.5],[6.5,7,.5],[7.25,4,.5]],
    answer:[[.5,7,.5],[1.5,9,.5],[2.5,12,.75],[3.5,14,.25],[4,12,.75],[5.25,9,.5],[6.25,7,.5],[7.25,0,.5]], program:61, color:'restrained brass, glassy keys, broad bass and final ensemble' },
];
const tracks = [
  {id:'pulse',channel:9,program:0,voice:'drums'},
  {id:'bass',channel:0,program:33,voice:'roundBass'},
  {id:'guitar',channel:1,program:24,voice:'mutedPluck'},
  {id:'lead',channel:2,program:21,voice:'reed'},
  {id:'answer',channel:3,program:73,voice:'sineFlute'},
  {id:'brass',channel:4,program:61,voice:'softBrass'},
];
function compose(p) {
  const events=[];
  const note=(track,beat,pitch,duration,velocity,minTier=0,maxTier=4)=>events.push({track,beat,pitch,duration,velocity,minTier,maxTier});
  const third=p.mode==='major'?4:3;
  for(let bar=0;bar<p.bars;bar++) {
    const b=bar*4, chord=p.root+p.progression[bar%8];
    // Unswung cumbia pulse stays audible even when the arrangement loses layers.
    for(const x of [0,2]) note('pulse',b+x,36,.16,86);
    for(const x of [1,3]) note('pulse',b+x,38,.12,54);
    for(let x=0;x<4;x+=.5) note('pulse',b+x,73,.16,x%1===0?42:31);
    for(const x of [1.5,2.75,3.5]) note('pulse',b+x,x===2.75?64:63,.16,58,1);
    for(const x of bar%2===0?[0,1.5,3]:[1,2]) note('pulse',b+x,75,.09,45,2);
    note('bass',b,chord-24,.8,87);
    note('bass',b+2,chord-17,.7,78);
    note('bass',b+1.5,chord-12,.3,68,1);
    note('bass',b+3.5,chord-24,.3,74,1);
    // The party already has harmony when the player arrives. Sparse dyads give
    // way to the denser four-offbeat triads at tier 2, without doubling voices.
    for(const x of [.5,2.5]) for(const interval of [third,7])
      note('guitar',b+x,chord+interval,.24,39,0,1);
    for(const x of [.5,1.5,2.5,3.5]) for(const interval of [0,third,7])
      note('guitar',b+x,chord+interval,.22,48+(x===2.5?8:0),2);
    if(bar%4===3) for(const [j,pitch] of [65,64,60,65].entries()) note('pulse',b+3+j*.25,pitch,.1,55+j*6,4);
    if(bar%2===1) for(const interval of [0,third,7]) note('brass',b+2.5,chord+12+interval,.45,47,4);
  }
  // Four written sections use two authored motifs with octave/rhythm orchestration.
  for(let phrase=0;phrase<p.bars/2;phrase++) {
    const section=Math.floor(phrase/4), motif=section%2===0?p.motif:p.answer;
    const base=phrase*8;
    for(const [offset,interval,duration] of motif) {
      const cadence=phrase%4===3 && offset>=7;
      const pitch=p.root+(cadence?0:interval)+(section===2?12:0);
      note('lead',base+offset,pitch,Math.min(duration,p.bars*4-base-offset),76,3);
      if(phrase%2===1 && offset<4) note('answer',base+offset+4,p.root+interval+12,duration*.7,48,4);
    }
    // A restrained version of this room's real hook is present from tier 0.
    // Tier 3 replaces it with the complete phrase, rather than merely getting louder.
    for(const [i,[offset,interval,duration]] of motif.entries()) {
      if(i%2!==0 && i!==motif.length-1) continue;
      const cadence=phrase%4===3 && offset>=7;
      note('lead',base+offset,p.root+(cadence?0:interval),duration*.85,58,0,2);
    }
    // A separate answer joins on alternate phrases at tier 2; the intervening
    // phrases remain open until the full-ensemble response arrives at tier 4.
    if(phrase%2===0) for(const [offset,interval,duration] of p.answer) {
      if(offset>=3.5) continue;
      note('answer',base+4+offset,p.root+interval+12,duration*.6,42,2);
    }
  }
  events.sort((a,b)=>a.beat-b.beat||a.track.localeCompare(b.track)||a.pitch-b.pitch);
  const adornments=[
    {id:'spark',gesture:'up',quantizeBeats:.25,events:[[0,12,.12],[.25,16,.12],[.5,19,.25]]},
    {id:'dip',gesture:'down',quantizeBeats:.25,events:[[0,12,.16],[.25,7,.16],[.5,0,.3]]},
    {id:'slide',gesture:'left',quantizeBeats:.25,events:[[0,7,.2],[.25,5,.2],[.5,3,.2],[.75,0,.2]]},
    {id:'shine',gesture:'right',quantizeBeats:.25,events:[[0,0,.2],[.25,7,.2],[.5,12,.4]]},
  ].map(a=>({...a,events:a.events.map(([beat,pitch,duration])=>({track:'answer',beat,pitch:p.root+pitch,duration,velocity:65,minTier:0}))}));
  return {schemaVersion:1,id:p.id,title:p.title,stat:p.stat,composer:'Kumbia Kombat original project score',
    license:'See assets/music/LICENSE.md',ppq:PPQ,beatsPerBar:4,bars:p.bars,phraseBars:2,
    key:{midiTonic:p.root,mode:p.mode},style:'Original synth cumbia / Latin instrumental',color:p.color,
    tiers:[0,3,6,9,12].map((delta,tier)=>({tier,bpm:p.bpm+delta,name:['Party groove','Percussion lift','Countermelody','Full melody','Full ensemble'][tier]})),
    sections:Array.from({length:p.bars/8},(_,i)=>({bar:i*8,bars:8,name:['Invitation','Answer','Lift','Approval'][i]})),
    tracks:tracks.map(t=>({...t,program:t.id==='lead'?p.program:t.program})),events,adornments,
    gameplayReference:{authority:'lib/game campaign configuration; score EOF does not approve an opponent',
      phrasePassesPerTier:[1,2,2,1,3][pieces.indexOf(p)],fullTierChallengePasses:[2,2,3,3,4][pieces.indexOf(p)],
      cleanTargetSeconds:[60,80,95,45,110][pieces.indexOf(p)]},
    transition:{cadenceBars:2,nextLevelCountInBars:1}};
}

// Success tags quote the room's opening call, then answer with a new tonic coda.
const codas = [
 [[4,7,.5],[4.75,10,.25],[5.5,12,.5],[6.5,7,.5],[7,0,.75]],
 [[4.25,10,.25],[4.75,7,.25],[5.5,3,.5],[6.25,2,.25],[7,0,.75]],
 [[4,9,.75],[5,7,.5],[5.75,5,.5],[6.5,2,.25],[7,0,.75]],
 [[4,12,.25],[4.5,10,.25],[5,7,.25],[5.5,3,.25],[6,2,.25],[6.5,0,1.25]],
 [[4,12,.75],[5,9,.5],[5.75,7,.5],[6.5,4,.25],[7,0,.875]],
];
const bridgeNames=['garden_to_bar','bar_to_crowd','crowd_to_restroom','restroom_to_vip'];
const bridgeTitles=['Through the Copper Door','Into the Velvet Current','Quick Step Down the Hall','Breathe, Then Enter Gold'];
function transitionBase(id,title,p,bpm,events,kind) {
 return {schemaVersion:1,id,title,stat:p.stat,kind,composer:'Kumbia Kombat original project score',
  license:'See assets/music/LICENSE.md',ppq:PPQ,beatsPerBar:4,bars:2,phraseBars:2,
  key:{midiTonic:p.root,mode:p.mode},style:'Original synth cumbia / Latin instrumental',
  tiers:Array.from({length:5},(_,tier)=>({tier,bpm:typeof bpm==='number'?bpm:bpm[tier],name:'Authored transition'})),
  tracks:tracks.map(t=>({...t,program:t.id==='lead'?p.program:t.program})),
  sections:[{bar:0,bars:2,name:kind==='success'?'Recognition and tonic answer':'Percussion pivot and tonal pickup'}],
  events:events.sort((a,b)=>a.beat-b.beat||a.track.localeCompare(b.track)||a.pitch-b.pitch),adornments:[]};
}
function composeSuccess(p,index){
 const events=[], note=(track,beat,pitch,duration,velocity)=>events.push({track,beat,pitch,duration,velocity,minTier:0,maxTier:4});
 // Recognition first; the second bar lets the room settle while the tonic
 // answer remains audible. Keep the beat, not a master-volume fade or ritard.
 for(let beat=0;beat<8;beat+=.5) {
  if(beat>=4 && beat%1!==0)continue;
  note('pulse',beat,73,.14,beat>=4?28:beat%1===0?44:34);
 }
 for(const beat of [0,2,4,6])note('pulse',beat,36,.18,beat>=4?62:82);
 for(const beat of [1,3,5,7])note('pulse',beat,38,.12,beat>=4?34:48);
 for(const beat of [1.5,3.5])note('pulse',beat,63,.12,64);
 for(const beat of [0,4]){
  note('bass',beat,p.root-24,1.4,beat===0?82:66);note('bass',beat+2,p.root-17,.7,beat===0?74:58);
  const offbeats=beat===0?[.5,1.5,2.5,3.5]:[.5,2.5];
  const voicing=beat===0?[0,p.mode==='major'?4:3,7]:[p.mode==='major'?4:3,7];
  for(const x of offbeats)for(const interval of voicing)note('guitar',beat+x,p.root+interval,.22,beat===0?52:38);
 }
 for(const [beat,pitch,duration] of [...p.motif.filter(n=>n[0]<4),...codas[index]])note('lead',beat,p.root+pitch+12,duration,beat>=4?68:84);
 for(const interval of [0,p.mode==='major'?4:3,7])note('brass',7,p.root+interval,.875,index===4?54:40);
 const result=transitionBase(p.id+'_success',p.title+' — Room Approval',p,[0,3,6,9,12].map(d=>p.bpm+d),events,'success');
 result.parentScore=p.id;result.musicalIntent=index===4?'Final VIP tonic tag: the whole night resolves with a quieter second-bar answer.':'Quote the room call, then thin percussion and harmony as the tonic answer settles the room.';
 return result;
}
function composeBridge(from,to,index){
 const events=[], note=(track,beat,pitch,duration,velocity)=>events.push({track,beat,pitch,duration,velocity,minTier:0,maxTier:4});
 // First bar intentionally has no bass/chords: a written percussion pivot lets
 // the prior key resolve before the new harmony arrives, without bending audio.
 const clavePatterns=[[0,1.5,3,4.5,6],[0,.75,2.5,4,5.5,7],[0,.5,1.25,2,2.75,3.5,4.5,6],[0,2,3.5,4,5.5,7]];
 for(const beat of clavePatterns[index])note('pulse',beat,75,.1,62);
 for(let beat=0;beat<8;beat+=.5)note('pulse',beat,73,.13,beat%1===0?40:28);
 for(const beat of [0,2,4,6])note('pulse',beat,36,.16,index===3?62:78);
 for(const [j,pitch] of [64,63,65,60].entries())note('pulse',2.5+j*.375,pitch,.14,52+j*6);
 const pickup=to.motif.filter(n=>n[0]<3.5);
 for(const [beat,pitch,duration] of pickup)note('answer',4+beat,to.root+pitch,Math.min(duration,7.75-(4+beat)),72);
 note('bass',4,to.root-24,.9,78);note('bass',6,to.root-17,.65,72);
 const third=to.mode==='major'?4:3;
 for(const beat of [4.5,5.5,6.5])for(const interval of [0,third,7])note('guitar',beat,to.root+interval,.24,48);
 // Dominant pickup is a short written cadence; destination tonic answers it.
 note('bass',7,to.root-17,.7,74);
 note('answer',7.5,to.root+7,.25,68);
 note('pulse',7.75,65,.12,72);
 const result=transitionBase(bridgeNames[index],bridgeTitles[index],to,to.bpm,events,'bridge');
 result.fromScore=from.id;result.toScore=to.id;
 result.musicalIntent=['A minor settles; a dry guiro/clave pivot opens C minor.',
  'C minor releases into a lighter clave pattern; D Dorian answers.',
  'D Dorian opens into a tightening timbale pickup toward urgent E minor.',
  'E minor releases into a spacious percussion bar; F major opens the VIP door.'][index];
 result.tempoIntent='Written percussion pivot takes the destination base tempo at its downbeat; the second bar introduces the destination motif. No pitch/time crossfade.';
 return result;
}
function variable(n){const a=[n&127];while(n>>=7)a.unshift((n&127)|128);return Buffer.from(a)}
const u16=n=>{const b=Buffer.alloc(2);b.writeUInt16BE(n);return b};
const u32=n=>{const b=Buffer.alloc(4);b.writeUInt32BE(n);return b};
const chunk=(id,b)=>Buffer.concat([Buffer.from(id),u32(b.length),b]);
function midi(score,tier=4) {
  const tempo=Math.round(60000000/score.tiers[tier].bpm);
  const meta=Buffer.from([0,0xff,0x51,3,(tempo>>16)&255,(tempo>>8)&255,tempo&255,0,0xff,0x58,4,4,2,24,8,0,0xff,0x2f,0]);
  const chunks=[chunk('MTrk',meta)];
  for(const t of score.tracks) {
    const ev=[{tick:0,priority:0,data:Buffer.from([0xc0|t.channel,t.program])}];
    for(const e of score.events.filter(e=>e.track===t.id&&e.minTier<=tier&&e.maxTier>=tier)) {
      ev.push({tick:Math.round(e.beat*PPQ),priority:2,data:Buffer.from([0x90|t.channel,e.pitch,e.velocity])});
      ev.push({tick:Math.round((e.beat+e.duration)*PPQ),priority:1,data:Buffer.from([0x80|t.channel,e.pitch,0])});
    }
    ev.sort((a,b)=>a.tick-b.tick||a.priority-b.priority);
    let last=0;const parts=[];
    for(const e of ev){parts.push(variable(e.tick-last),e.data);last=e.tick;}
    parts.push(variable(score.bars*4*PPQ-last),Buffer.from([0xff,0x2f,0]));
    chunks.push(chunk('MTrk',Buffer.concat(parts)));
  }
  return Buffer.concat([chunk('MThd',Buffer.concat([u16(1),u16(chunks.length),u16(PPQ)])),...chunks]);
}
mkdirSync(resolve(root,'assets/music/scores'),{recursive:true});
mkdirSync(resolve(root,'assets/music/midi'),{recursive:true});
const manifest={schemaVersion:1,scores:[],transitions:{successes:[],bridges:[]}};
for(const piece of pieces){
  const score=compose(piece);
  writeFileSync(resolve(root,`assets/music/scores/${piece.id}.json`),JSON.stringify(score)+'\n');
  for(let tier=0;tier<5;tier++)writeFileSync(resolve(root,`assets/music/midi/${piece.id}_tier${tier}.mid`),midi(score,tier));
  manifest.scores.push({id:score.id,title:score.title,path:`assets/music/scores/${score.id}.json`,bars:score.bars,baseBpm:score.tiers[0].bpm,fullBpm:score.tiers[4].bpm});
  console.log(`${score.id}: ${score.events.length} notes, ${score.bars} bars, five MIDI arrangements`);
}

for(const [index,piece] of pieces.entries()){
 const success=composeSuccess(piece,index);
 writeFileSync(resolve(root,'assets/music/scores/'+success.id+'.json'),JSON.stringify(success)+'\n');
 writeFileSync(resolve(root,'assets/music/midi/'+success.id+'.mid'),midi(success,4));
 manifest.transitions.successes.push({id:success.id,title:success.title,bars:2,baseBpm:success.tiers[0].bpm,fullBpm:success.tiers[4].bpm,parentScore:piece.id,path:'assets/music/scores/'+success.id+'.json',midiPath:'assets/music/midi/'+success.id+'.mid'});
 console.log(success.id+': original two-bar success phrase');
 if(index===pieces.length-1)continue;
 const bridge=composeBridge(piece,pieces[index+1],index);
 writeFileSync(resolve(root,'assets/music/scores/'+bridge.id+'.json'),JSON.stringify(bridge)+'\n');
 writeFileSync(resolve(root,'assets/music/midi/'+bridge.id+'.mid'),midi(bridge,0));
 manifest.transitions.bridges.push({id:bridge.id,title:bridge.title,bars:2,baseBpm:bridge.tiers[0].bpm,fullBpm:bridge.tiers[4].bpm,fromScore:piece.id,toScore:pieces[index+1].id,path:'assets/music/scores/'+bridge.id+'.json',midiPath:'assets/music/midi/'+bridge.id+'.mid'});
 console.log(bridge.id+': original two-bar percussion pivot and pickup');
}
writeFileSync(resolve(root,'assets/music/manifest.json'),JSON.stringify(manifest,null,2)+'\n');
