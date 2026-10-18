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
    // A recognizable two-note invitation survives below the complete melody tier.
    note('lead',base,p.root,.5,58,1,2);
    note('lead',base+6,p.root+7,.5,54,1,2);
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
    tiers:[0,3,6,9,12].map((delta,tier)=>({tier,bpm:p.bpm+delta,name:['Pulse','Groove','Harmony','Melody','Full ensemble'][tier]})),
    sections:Array.from({length:p.bars/8},(_,i)=>({bar:i*8,bars:8,name:['Invitation','Answer','Lift','Approval'][i]})),
    tracks:tracks.map(t=>({...t,program:t.id==='lead'?p.program:t.program})),events,adornments,
    gameplayReference:{authority:'lib/game campaign configuration; score EOF does not approve an opponent',
      phrasePassesPerTier:[1,2,2,1,3][pieces.indexOf(p)],fullTierChallengePasses:[2,2,3,3,4][pieces.indexOf(p)],
      cleanTargetSeconds:[60,80,95,45,110][pieces.indexOf(p)]},
    transition:{cadenceBars:2,nextLevelCountInBars:1}};
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
const manifest={schemaVersion:1,scores:[]};
for(const piece of pieces){
  const score=compose(piece);
  writeFileSync(resolve(root,`assets/music/scores/${piece.id}.json`),JSON.stringify(score)+'\n');
  for(let tier=0;tier<5;tier++)writeFileSync(resolve(root,`assets/music/midi/${piece.id}_tier${tier}.mid`),midi(score,tier));
  manifest.scores.push({id:score.id,title:score.title,path:`assets/music/scores/${score.id}.json`,bars:score.bars,baseBpm:score.tiers[0].bpm,fullBpm:score.tiers[4].bpm});
  console.log(`${score.id}: ${score.events.length} notes, ${score.bars} bars, five MIDI arrangements`);
}
writeFileSync(resolve(root,'assets/music/manifest.json'),JSON.stringify(manifest,null,2)+'\n');
