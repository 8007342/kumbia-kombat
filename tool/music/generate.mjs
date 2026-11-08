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
  if(p.swing)events.splice(0,events.length,...swingEvents(events,p.swing,[0,3,6,9,12].map(d=>p.bpm+d)));
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
// Swing feel, set per score with `swing:{ratioAt100,ratioAt300}`. Scores are
// written on a straight grid; this moves each offbeat later within its beat.
// The ratio (long eighth : short eighth) falls in a straight line with tempo, as
// in plan/research/swing-duet-research-2026-11-05.md section 2. A score holds one
// position per note but plays at five tempos, so a note whose swung position
// differs between tiers is written once per tier, gated by minTier and maxTier.
function swingFraction(bpm,swing){
 const ratio=Math.max(1,swing.ratioAt100+(swing.ratioAt300-swing.ratioAt100)*(bpm-100)/200);
 return ratio/(1+ratio);
}
const toTick=beat=>Math.round(beat*PPQ)/PPQ;
function swungBeat(beat,fraction){
 const whole=Math.floor(beat), within=beat-whole;
 return whole+(within<=.5?within*2*fraction:fraction+(within-.5)*2*(1-fraction));
}
function swingNote(e,fraction){
 const beat=toTick(swungBeat(e.beat,fraction));
 // Drum lengths set the sound of the hit, so only pitched notes stretch.
 const duration=e.track==='pulse'?e.duration:Math.max(1/PPQ,toTick(swungBeat(e.beat+e.duration,fraction))-beat);
 return {...e,beat,duration};
}
function swingEvents(events,swing,bpms){
 const out=[];
 for(const e of events){
  let run=null;
  for(let tier=e.minTier;tier<=e.maxTier;tier++){
   const moved=swingNote(e,swingFraction(bpms[tier],swing));
   if(run&&run.beat===moved.beat&&run.duration===moved.duration)run.maxTier=tier;
   else out.push(run={...moved,minTier:tier,maxTier:tier});
  }
 }
 return out;
}

// The pool lawn: an original 32-bar AABA in E-flat. The runtime has no real
// cymbal, so the ride is the synth's narrow noise voice (73) and the hi-hat its
// wider one (75); GM's own ride and hat numbers would give it a negative pitch.
const SWING={ratioAt100:3.5,ratioAt300:1};
const chordKinds={'6':[0,4,7,9],'7':[0,4,7,10],'m7':[0,3,7,10],'m6':[0,3,7,9]};
const chordNames={Eb6:[0,'6'],C7:[9,'7'],Fm7:[2,'m7'],Bb7:[7,'7'],Ab7:[5,'7'],Ab6:[5,'6'],Abm6:[5,'m6'],Gm7:[4,'m7']};
const sectionA=[['Eb6'],['C7'],['Fm7'],['Bb7'],['Eb6'],['Ab7'],['Fm7','Bb7'],['Eb6','Bb7']];
const sectionB=[['Gm7'],['C7'],['Fm7'],['Bb7'],['Ab6'],['Abm6'],['Gm7','C7'],['Fm7','Bb7']];
const poolForm=[...sectionA,...sectionA.slice(0,7),['Eb6'],...sectionB,...sectionA];
// [beat, semitones above the tonic, length], on a straight grid. Most phrases
// share the chart's rhythm, so the tune teaches what the taps will ask for.
const phraseA1=[[0,4,.9],[1,7,.45],[1.5,9,1.2],[3,7,.8],[4,13,.9],[5,9,.45],[5.5,7,.9],[6.5,4,1.2]];
const phraseA2=[[0,5,.9],[1,9,.45],[1.5,12,1.2],[3,9,.8],[4,14,.9],[5,11,.45],[5.5,7,.9],[6.5,5,1.2]];
const phraseA3=[[0,4,.9],[1,7,.45],[1.5,9,1.2],[3,12,.8],[4,15,.9],[5,12,.45],[5.5,9,.9],[6.5,5,1.2]];
const phraseA4=[[0,9,.8],[1,5,.4],[1.5,2,.9],[3,7,.9],[4,4,.9],[5,7,.4],[5.5,4,.9],[6.5,5,1.2]];
const phraseHome=[[0,9,.8],[1,5,.4],[1.5,2,.9],[3,7,.9],[4,4,.9],[5,7,.4],[5.5,4,.9],[6.5,0,1.3]];
const phraseB1=[[0,11,1.8],[2,14,1.4],[3.5,11,.4],[4,13,1.8],[6,16,.9],[7,14,.7]];
const phraseB2=[[0,9,1.8],[2,12,1.4],[3.5,9,.4],[4,11,1.8],[6,14,.9],[7,12,.7]];
const phraseB3=[[0,12,1.8],[2,9,1.4],[3.5,5,.4],[4,8,1.8],[6,5,.9],[7,4,.7]];
const phraseB4=[[0,7,.9],[1,4,.45],[2,13,.9],[3,7,.9],[4,12,.9],[5,9,.45],[6,14,.9],[7,11,.7]];
const poolPhrases=[phraseA1,phraseA2,phraseA3,phraseA4,phraseA1,phraseA2,phraseA3,phraseHome,
 phraseB1,phraseB2,phraseB3,phraseB4,phraseA1,phraseA2,phraseA3,phraseA4];
const swingPieces=[{id:'pool_swing',title:'Long Way Across the Lawn',stat:'Grace',bars:32,bpms:[128,136,144,152,160],root:63,mode:'major',
 swing:SWING,motif:phraseA1,program:71,color:'square-wave reed lead, sawtooth brass section, noise ride, walking triangle bass'}];
const chordIn=(bar,beat)=>{const chords=poolForm[bar%poolForm.length];return chordNames[chords[chords.length>1&&beat>=2?1:0]]};
const tonePitch=(root,[semis,kind],index,low)=>{
 const pc=(root+semis+chordKinds[kind][index])%12;
 return low+((pc-low)%12+12)%12;
};
function walkingBass(p,bar,note){
 const b=bar*4, chords=poolForm[bar].map(name=>chordNames[name]);
 const nextChord=chordIn((bar+1)%p.bars,0);
 const shapes=[[0,1,2],[0,2,3],[0,3,2]];
 const velocity=[84,70,78,70];
 const parts=chords.length>1?[[0,2],[2,2]]:[[0,4]];
 for(const [i,[start,length]] of parts.entries()){
  const chord=chords[i], target=i+1<chords.length?chords[i+1]:nextChord;
  const home=tonePitch(p.root,chord,0,39), landing=tonePitch(p.root,target,0,39);
  const line=length===4?shapes[bar%3].map(index=>tonePitch(p.root,chord,index,home)):[home];
  const last=line[line.length-1];
  // Walk up or down a semitone into the next root, whichever is nearer.
  const approach=[landing-1,landing+1,landing+11,landing+13].sort((x,y)=>Math.abs(x-last)-Math.abs(y-last)||x-y)[0];
  for(const [j,pitch] of [...line,approach].entries())note('bass',b+start+j,pitch,.85,velocity[start+j]);
  if(bar%4===3&&i===parts.length-1)note('bass',b+3.5,approach,.3,56,2);
 }
}
function composeSwing(p){
 const events=[], note=(track,beat,pitch,duration,velocity,minTier=0,maxTier=4)=>events.push({track,beat,pitch,duration,velocity,minTier,maxTier});
 for(let bar=0;bar<p.bars;bar++){
  const b=bar*4, even=bar%2===0, section=Math.floor(bar/8);
  // Ride "ding, ding-a, ding, ding-a", hi-hat on 2 and 4, feathered kick.
  for(const x of [0,1,1.5,2,3,3.5])note('pulse',b+x,73,.12,x%1?36:x%2?56:48);
  for(const x of [1,3])note('pulse',b+x,75,.05,46);
  for(const x of [0,1,2,3])note('pulse',b+x,36,.1,x===0?52:34);
  walkingBass(p,bar,note);
  // Comping follows the chart's one-bar cell, so taps land with the band. It
  // is the rhythm of beats 0, 1, the swung 1.5, then 3, or 2.5 on even bars.
  const last=even?2.5:3;
  for(const x of [0,1.5,last]){
   const chord=chordIn(bar,x);
   for(const index of [1,3])note('guitar',b+x,tonePitch(p.root,chord,index,55),.28,44,0,1);
   for(const index of [1,3])note('guitar',b+x,tonePitch(p.root,chord,index,55),.28,x===0?46:42,2);
   note('guitar',b+x,tonePitch(p.root,chord,2,55),.28,38,2,3);
  }
  for(const index of [1,3])note('guitar',b+1,tonePitch(p.root,chordIn(bar,1),index,55),.2,36,2);
  // Tier 1: snare chatter joins. Tier 3: a backbeat. Tier 4: a tom fill.
  if(!even)for(const x of [1.5,3.5])note('pulse',b+x,38,.06,30,1);
  if(even&&bar%4===2)note('pulse',b+2.5,36,.1,58,2);
  for(const x of [1,3])note('pulse',b+x,38,.06,42,3);
  if(bar%4===3)for(const [x,pitch,velocity] of [[2.5,65,56],[3,64,62],[3.5,63,68],[3.75,60,74]])note('pulse',b+x,pitch,.1,velocity,4);
  // One brass riff, thicker by a voice at each tier after it enters. Voices are
  // the seventh or sixth, third, fifth, then root, in close position.
  const riff=(x,duration,velocity,enter)=>{
   for(const [voice,index] of [3,1,2,0].entries()){
    if(enter+voice>4)break;
    note('brass',b+x,tonePitch(p.root,chordIn(bar,x),index,67),duration,velocity,enter+voice);
   }
  };
  if(even)for(const [x,length] of [[2.5,.35],[3.5,.25]])riff(x,length,36,1);
  else for(const [x,length] of [[1.5,.35],[2,.45]])riff(x,length,34,2);
  if(section===2)for(const x of [.5,1.5,2.5,3.5])if(!(even&&x>=2.5)&&!(!even&&x===1.5))riff(x,.25,30,3);
  if(section===3)for(const [x,length] of [[0,.3],[3,.4]])for(const index of [3,1,2])note('brass',b+x,tonePitch(p.root,chordIn(bar,x),index,67),length,36,4);
  // A quiet high answer: tier 2 on the third bar of each four, tier 4 on the first too.
  if(bar%2===0){
   const enter=bar%4===2?2:4;
   for(const [x,index] of [[.5,2],[1.5,1],[2.5,0]])note('answer',b+x,tonePitch(p.root,chordIn(bar,x),index,75),.4,44,enter);
  }
 }
 for(const [phrase,line] of poolPhrases.entries()){
  const base=phrase*8;
  for(const [i,[offset,interval,duration]] of line.entries()){
   // Tier 3 replaces the restrained hook with the complete phrase.
   note('lead',base+offset,p.root+interval,duration,58,3);
   if(i%2===0||i===line.length-1)note('lead',base+offset,p.root+interval,duration*.85,46,0,2);
  }
 }
 const heard=swingEvents(events,p.swing,p.bpms);
 heard.sort((a,c)=>a.beat-c.beat||a.track.localeCompare(c.track)||a.pitch-c.pitch);
 const adornments=[
  {id:'spark',gesture:'up',quantizeBeats:.25,events:[[0,12,.12],[.25,16,.12],[.5,19,.25]]},
  {id:'dip',gesture:'down',quantizeBeats:.25,events:[[0,12,.16],[.25,7,.16],[.5,0,.3]]},
  {id:'slide',gesture:'left',quantizeBeats:.25,events:[[0,7,.2],[.25,5,.2],[.5,4,.2],[.75,0,.2]]},
  {id:'shine',gesture:'right',quantizeBeats:.25,events:[[0,0,.2],[.25,7,.2],[.5,12,.4]]},
 ].map(a=>({...a,events:a.events.map(([beat,pitch,duration])=>({track:'answer',beat,pitch:p.root+pitch,duration,velocity:65,minTier:0}))}));
 return {schemaVersion:1,id:p.id,title:p.title,stat:p.stat,composer:'Kumbia Kombat original project score',
  license:'See assets/music/LICENSE.md',ppq:PPQ,beatsPerBar:4,bars:p.bars,phraseBars:2,
  key:{midiTonic:p.root,mode:p.mode},style:'Original synth swing instrumental',color:p.color,swing:p.swing,
  tiers:p.bpms.map((bpm,tier)=>({tier,bpm,name:['Ride and walk','Section enters','Riffs answer','Full melody','Shout chorus'][tier]})),
  sections:Array.from({length:p.bars/8},(_,i)=>({bar:i*8,bars:8,name:['Invitation','Answer','Lift','Approval'][i]})),
  tracks:tracks.map(t=>({...t,program:t.id==='lead'?p.program:t.program})),events:heard,adornments,
  gameplayReference:{authority:'levels/pool-garden.json; score EOF does not approve an opponent',
   phrasePassesPerTier:2,fullTierChallengePasses:2,cleanTargetSeconds:70},
  transition:{cadenceBars:2,nextLevelCountInBars:1}};
}
function composeSwingSuccess(p){
 const events=[], note=(track,beat,pitch,duration,velocity)=>events.push({track,beat,pitch,duration,velocity,minTier:0,maxTier:4});
 // Same shape as the other rooms: recognition, then the room settles on the
 // tonic while the beat carries on. A room clears at its top tier, so this
 // swings for that tempo.
 for(const x of [0,1,1.5,2,3,3.5])note('pulse',x,73,.12,x%1?36:x%2?56:48);
 for(const x of [4,5,6,7])note('pulse',x,73,.12,x%2?34:28);
 for(const x of [1,3])note('pulse',x,75,.05,46);
 for(const x of [0,2,4,6])note('pulse',x,36,.14,x>=4?44:62);
 for(const [x,pitch,velocity] of [[0,39,82],[1,43,70],[2,46,76],[3,50,68],[4,51,64],[6,46,58]])note('bass',x,pitch,x>=4?1.4:.85,velocity);
 for(const x of [0,1.5,2.5])for(const index of [1,3,2])note('guitar',x,tonePitch(p.root,chordNames.Eb6,index,55),.28,50);
 for(const x of [4,5.5])for(const index of [1,3])note('guitar',x,tonePitch(p.root,chordNames.Eb6,index,55),.28,36);
 for(const [x,interval,duration] of [...p.motif.filter(n=>n[0]<4),[4,7,.75],[5,9,.4],[5.5,7,.9],[6.5,4,.4],[7,0,.9]])
  note('lead',x,p.root+interval+12,duration,x>=4?50:60);
 for(const interval of [0,4,7])note('brass',7,p.root+interval,.875,40);
 const fraction=swingFraction(p.bpms[4],p.swing);
 const result=transitionBase(p.id+'_success',p.title+' — Room Approval',p,p.bpms,events.map(e=>swingNote(e,fraction)),'success');
 result.style='Original synth swing instrumental';result.parentScore=p.id;result.swing=p.swing;
 result.musicalIntent='Quote the lawn call an octave up, then thin the band as the tonic answer settles.';
 return result;
}
function composeIntoSwing(to,{id,title,fromScore,clave,intent}){
 const events=[], note=(track,beat,pitch,duration,velocity)=>events.push({track,beat,pitch,duration,velocity,minTier:0,maxTier:4});
 // Bar one is percussion on a straight grid, the last of the bar's feel. Bar two
 // swings: the bass starts on the bar's C and walks the circle of fifths to the
 // lawn's E-flat. C minor and E-flat major share every note, so nothing jars.
 for(const beat of clave)note('pulse',beat,75,.1,62);
 for(let beat=0;beat<3.5;beat+=.5)note('pulse',beat,73,.13,beat%1===0?40:28);
 for(const beat of [0,2])note('pulse',beat,36,.16,78);
 for(const [beat,pitch,velocity] of [[2.5,60,56],[3,63,62],[3.5,65,68]])note('pulse',beat,pitch,.14,velocity);
 note('pulse',3.75,38,.1,72);
 for(const x of [4,5,5.5,6,7,7.5])note('pulse',x,73,.12,x%1?36:x%2?56:48);
 for(const x of [5,7])note('pulse',x,75,.05,46);
 for(const x of [4,6])note('pulse',x,36,.14,70);
 for(const [x,pitch] of [[4,48],[5,51],[6,53],[7,46]])note('bass',x,pitch,.85,x===4?82:74);
 const shells=[[4,'m7',0],[5.5,'m7',0],[6,'7',5],[7.5,'7',10]];
 for(const [x,kind,semis] of shells)for(const index of [1,3])note('guitar',x,tonePitch(60,[semis,kind],index,55),.26,48);
 for(const [offset,interval,duration] of to.motif.filter(n=>n[0]<3.5))note('answer',4+offset,to.root+interval,Math.min(duration,3.4-offset),72);
 for(const index of [1,3,2])note('brass',7.5,tonePitch(60,[10,'7'],index,67),.4,52);
 note('pulse',7.75,65,.12,72);
 const fraction=swingFraction(to.bpms[0],to.swing);
 const result=transitionBase(id,title,to,to.bpms[0],events.map(e=>e.beat<4?e:swingNote(e,fraction)),'bridge');
 result.style='Original synth swing instrumental';result.fromScore=fromScore;result.toScore=to.id;result.swing=to.swing;
 result.musicalIntent=intent;
 result.tempoIntent='Takes the lawn\'s base tempo at its downbeat, as every bridge does, so the count-in already has the new pulse. No pitch or time crossfade.';
 return result;
}
function composePoolToBar(from,to){
 const events=[], note=(track,beat,pitch,duration,velocity)=>events.push({track,beat,pitch,duration,velocity,minTier:0,maxTier:4});
 // The mirror of the way in. Bar one still swings, on drums alone; bar two is
 // straight, and the bass steps from the lawn's E-flat down to the bar's C minor.
 for(const beat of [0,1,2.5,3])note('pulse',beat,75,.1,62);
 for(let beat=0;beat<3.5;beat+=.5)note('pulse',beat,73,.13,beat%1===0?40:28);
 for(const beat of [0,2])note('pulse',beat,36,.16,78);
 for(const [beat,pitch,velocity] of [[2.5,67,56],[3,65,62],[3.5,63,68]])note('pulse',beat,pitch,.14,velocity);
 for(const x of [4,5,6,6.5,7])note('pulse',x,73,.12,x%1?36:48);
 for(const x of [4,6])note('pulse',x,36,.14,70);
 for(const [x,pitch] of [[4,51],[5,56],[6,55],[7,43]])note('bass',x,pitch-12,.85,x===4?82:74);
 for(const [x,kind,semis] of [[4,'6',3],[5.5,'6',8],[6,'7',7],[7.5,'7',7]])for(const index of [1,3])note('guitar',x,tonePitch(60,[semis,kind],index,55),.26,48);
 for(const [offset,interval,duration] of to.motif.filter(n=>n[0]<3.5))note('answer',4+offset,to.root+interval,Math.min(duration,3.4-offset),72);
 note('pulse',7.75,65,.12,72);
 const fraction=swingFraction(to.bpm,from.swing);
 const result=transitionBase('pool_to_bar','In from the Lawn',to,to.bpm,events.map(e=>e.beat<4?swingNote(e,fraction):e),'bridge');
 result.fromScore=from.id;result.toScore=to.id;
 result.musicalIntent='The lawn\'s swing thins to a drum break; the band comes in straight, and the bass steps E-flat, A-flat, G into the bar\'s C minor.';
 result.tempoIntent='Takes the bar\'s base tempo at its downbeat, as every bridge does. The drop from the lawn\'s top tempo is intended: the bar is slower and more complex. No pitch or time crossfade.';
 return result;
}
// The bar closes the campaign for now, and its oil gulp lands on beat 8, past a
// two-bar tag. When the indoor party ships, point bar.json back at bar_swag_success
// and let bar_to_crowd carry the gulp.
function composeBarFinale(success,to){
 const events=success.events.map(e=>({...e})), note=(track,beat,pitch,duration,velocity)=>events.push({track,beat,pitch,duration,velocity,minTier:0,maxTier:4});
 for(const beat of [8,9.5,11])note('pulse',beat,75,.1,62);
 for(let beat=8;beat<12;beat+=.5)note('pulse',beat,73,.13,beat%1===0?40:28);
 for(const beat of [8,10])note('pulse',beat,36,.16,78);
 for(const [x,pitch] of [[12,48],[13,55],[14,43]])note('bass',x,pitch-12,.9,78);
 for(const x of [12,13.5])for(const interval of [0,3,7])note('guitar',x,to.root+interval,.26,48);
 note('bass',15,36,.95,84);
 for(const interval of [0,3,7,12])note('guitar',15,to.root+interval,.95,52);
 const result={...success,id:'bar_swag_finale',title:success.title+', with the Last Drop',bars:4,phraseBars:4,
  sections:[{bar:0,bars:2,name:'Recognition and tonic answer'},{bar:2,bars:2,name:'Drum break under the gulp, then the last cadence'}],
  events:events.sort((a,b)=>a.beat-b.beat||a.track.localeCompare(b.track)||a.pitch-b.pitch)};
 return result;
}
// The salon: "Terciopelo", an original 32-bar bolero-cha in D minor. A cha-cha-chá
// groove (güiro long-long-long-short-short, congas on the "cha-cha" of beat 4,
// a tumbao-like bass with the 4-and pickup) under a sung bolero line for violin,
// answered by flute. The B section turns to F major, the relative major, which
// the success tag resolves to. Its five tiers run 108 to 124 BPM in 4 BPM steps,
// so tiers 0, 2 and 4 are the rendered low, mid and high tempos.
const boleroKinds={m:[0,3,7],M:[0,4,7],'7':[0,4,7,10],m7b5:[0,3,6,10]};
const boleroChords={Dm:[0,'m'],Gm:[5,'m'],A7:[7,'7'],Bb:[8,'M'],Em7b5:[2,'m7b5'],F:[3,'M'],C7:[10,'7']};
const boleroForm=[
 ['Dm'],['Dm'],['Gm'],['Gm'],['A7'],['A7'],['Dm'],['Dm','A7'],
 ['Dm'],['Dm'],['Gm'],['Gm'],['Bb'],['Em7b5','A7'],['Dm'],['Dm'],
 ['F'],['F'],['C7'],['C7'],['Gm'],['Gm'],['A7'],['A7'],
 ['Dm'],['Gm'],['Bb'],['A7'],['Dm'],['Gm'],['A7'],['Dm'],
];
// [beat, semitones above D4, length]. Long notes and sighs: a bolero is sung.
const bP1=[[0,7,1.5],[1.5,8,.5],[2,7,1],[3,5,1],[4,3,1.5],[5.5,2,.5],[6,3,1.5]];
const bP2=[[0,10,1.5],[1.5,12,.5],[2,10,1],[3,8,.5],[3.5,7,.5],[4,5,2],[6,3,1],[7,2,1]];
const bP3=[[0,7,1],[1,11,1],[2,14,1.5],[3.5,17,.5],[4,15,1],[5,14,1],[6,11,1.5],[7.5,7,.5]];
const bP4=[[0,12,1.5],[1.5,10,.5],[2,8,1],[3,7,1],[4,3,1],[5,2,1],[6,0,2]];
const bP7=[[0,8,1.5],[1.5,10,.5],[2,12,1],[3,8,1],[4,5,1],[5,8,.5],[5.5,7,.5],[6,11,1],[7,7,1]];
const bP9=[[0,15,1.5],[1.5,14,.5],[2,12,1],[3,10,1],[4,7,2],[6,10,1],[7,12,1]];
const bP10=[[0,14,1.5],[1.5,15,.5],[2,17,1],[3,14,1],[4,10,1.5],[5.5,8,.5],[6,10,2]];
const bP11=[[0,17,1.5],[1.5,15,.5],[2,14,1],[3,12,1],[4,10,2],[6,8,1],[7,7,1]];
const bP12=[[0,7,.5],[.5,11,.5],[1,14,.5],[1.5,17,1.5],[3,14,1],[4,11,2],[6,7,2]];
const bP13=[[0,7,1.5],[1.5,8,.5],[2,7,1],[3,3,1],[4,5,1.5],[5.5,7,.5],[6,10,2]];
const bP14=[[0,8,1.5],[1.5,10,.5],[2,8,1],[3,5,1],[4,7,1],[5,11,1],[6,14,2]];
const bP15=[[0,15,1.5],[1.5,14,.5],[2,12,1],[3,10,1],[4,10,1],[5,8,1],[6,7,2]];
const bP16=[[0,14,1],[1,11,1],[2,7,1],[3,11,1],[4,12,3.5]];
const boleroPhrases=[bP1,bP2,bP3,bP4,bP1,bP2,bP7,bP4,bP9,bP10,bP11,bP12,bP13,bP14,bP15,bP16];
const boleroPieces=[{id:'salon_bolero',title:'Terciopelo',stat:'Charm',bars:32,bpms:[108,112,116,120,124],root:62,mode:'minor',
 motif:bP1,program:40,color:'singing violin lead, flute answers, montuno keys, soft round bass, güiro and congas on the cha-cha-chá, string swells at the top'}];
const boleroChordAt=(bar,beat)=>{const c=boleroForm[bar%boleroForm.length];return boleroChords[c[c.length>1&&beat>=2?1:0]]};
const boleroTone=(root,[semis,kind],index,low)=>{
 const tones=boleroKinds[kind];const pc=(root+semis+tones[index%tones.length])%12;
 return low+((pc-low)%12+12)%12;
};
// One bar of the cha-cha-chá groove, shared by the score, the tag and the bridge.
function chachaPercussion(note,b,tier){
 // Güiro: three long strokes, then the short-short "cha-cha" on 4 and 4-and.
 for(const [x,d,v] of [[0,.4,44],[1,.4,38],[2,.4,40],[3,.18,46],[3.5,.18,50]])note('pulse',b+x,73,d,v,tier);
 for(const x of [0,2])note('pulse',b+x,36,.14,x===0?70:58,tier);
}
function composeBolero(p){
 const events=[], note=(track,beat,pitch,duration,velocity,minTier=0,maxTier=4)=>events.push({track,beat,pitch,duration,velocity,minTier,maxTier});
 for(let bar=0;bar<p.bars;bar++){
  const b=bar*4, chord=boleroChordAt(bar,0), late=boleroChordAt(bar,2);
  chachaPercussion(note,b,0);
  // Tier 1: congas, a slap on 2 and open tones on the cha-cha of 4.
  note('pulse',b+1,63,.12,52,1);
  for(const x of [3,3.5])note('pulse',b+x,64,.14,58,1);
  // Tier 3: a soft cha-cha bell on each beat.
  for(const x of [0,1,2,3])note('pulse',b+x,75,.08,x===0?40:32,3);
  // Tier 4: a short timbale run into each four-bar phrase.
  if(bar%4===3)for(const [x,pitch,v] of [[2.5,65,50],[2.75,64,54],[3,60,58],[3.25,60,62]])note('pulse',b+x,pitch,.1,v,4);
  // Bass: root and fifth, then the 4-and pickup from tier 1.
  note('bass',b,boleroTone(p.root,chord,0,38),1.4,84);
  note('bass',b+2,boleroTone(p.root,late,2,38),.9,74);
  note('bass',b+3,boleroTone(p.root,late,0,38),.4,64,1);
  note('bass',b+3.5,boleroTone(p.root,late,0,38),.4,70,1);
  // Montuno: sparse off-beat dyads, then the full syncopated figure at tier 2.
  for(const x of [1.5,3])for(const i of [1,2])note('guitar',b+x,boleroTone(p.root,boleroChordAt(bar,x),i,57),.3,40,0,1);
  for(const [x,i] of [[.5,0],[1,1],[1.5,2],[2.5,0],[3,1],[3.5,2]]){
   const c=boleroChordAt(bar,x);
   note('guitar',b+x,boleroTone(p.root,c,i,57),.24,x%1?46:40,2);
   note('guitar',b+x,boleroTone(p.root,c,i+1,57),.24,x%1?40:34,2);
  }
  // Tier 4: strings swell under each bar, louder into the phrase's second bar.
  for(const i of [0,1,2])note('brass',b,boleroTone(p.root,chord,i,62),late===chord?3.8:1.9,bar%2?44:34,4);
  if(late!==chord)for(const i of [0,1,2])note('brass',b+2,boleroTone(p.root,late,i,62),1.8,bar%2?46:36,4);
 }
 for(const [phrase,line] of boleroPhrases.entries()){
  const base=phrase*8;
  for(const [i,[offset,interval,duration]] of line.entries()){
   note('lead',base+offset,p.root+interval,Math.min(duration,p.bars*4-base-offset),74,3);
   if(i%2===0||i===1||i===line.length-1)note('lead',base+offset,p.root+interval,Math.min(duration*.85,p.bars*4-base-offset),56,0,2);
   if(offset<6)note('answer',base+offset,p.root+interval+12,Math.min(duration*.8,p.bars*4-base-offset),34,4);
  }
  // Flute answers in the lead's long last note, from tier 2.
  const last=line[line.length-1];
  if(last[0]<=6.5&&base+7.5<=p.bars*4)for(const [j,step] of [7,5,3].entries())note('answer',base+6.5+j*.5,p.root+12+step,.4,44,2);
 }
 events.sort((a,c)=>a.beat-c.beat||a.track.localeCompare(c.track)||a.pitch-c.pitch);
 const adornments=[
  {id:'spark',gesture:'up',quantizeBeats:.25,events:[[0,12,.12],[.25,15,.12],[.5,19,.25]]},
  {id:'dip',gesture:'down',quantizeBeats:.25,events:[[0,12,.16],[.25,7,.16],[.5,0,.3]]},
  {id:'slide',gesture:'left',quantizeBeats:.25,events:[[0,8,.2],[.25,7,.2],[.5,5,.2],[.75,3,.2]]},
  {id:'shine',gesture:'right',quantizeBeats:.25,events:[[0,0,.2],[.25,7,.2],[.5,15,.4]]},
 ].map(a=>({...a,events:a.events.map(([beat,pitch,duration])=>({track:'answer',beat,pitch:p.root+pitch,duration,velocity:62,minTier:0}))}));
 return {schemaVersion:1,id:p.id,title:p.title,stat:p.stat,composer:'Kumbia Kombat original project score',
  license:'See assets/music/LICENSE.md',ppq:PPQ,beatsPerBar:4,bars:p.bars,phraseBars:2,
  key:{midiTonic:p.root,mode:p.mode},style:'Original synth bolero-cha instrumental',color:p.color,tierBpms:p.bpms,
  tiers:p.bpms.map((bpm,tier)=>({tier,bpm,name:['Güiro and bass','Congas join','Montuno and flute','Violin sings','Strings swell'][tier]})),
  sections:Array.from({length:p.bars/8},(_,i)=>({bar:i*8,bars:8,name:['Invitation','Answer','Lift','Approval'][i]})),
  tracks:tracks.map(t=>({...t,program:t.id==='lead'?p.program:t.id==='brass'?48:t.program})),events,adornments,
  gameplayReference:{authority:'levels/salon.json; score EOF does not approve an opponent',
   phrasePassesPerTier:2,fullTierChallengePasses:2,cleanTargetSeconds:110},
  transition:{cadenceBars:2,nextLevelCountInBars:1}};
}
function composeBoleroSuccess(p){
 const events=[], note=(track,beat,pitch,duration,velocity)=>events.push({track,beat,pitch,duration,velocity,minTier:0,maxTier:4});
 // Four bars, the salon ends the night: the opening call over D minor, then
 // B-flat, C7 and home to F major, the relative major. Bars three and four thin out.
 const plan=[['Dm',0],['Bb',4],['C7',8],['F',12]];
 for(const [name,b] of plan){
  const chord=boleroChords[name], settle=b>=8;
  for(const [x,d,v] of [[0,.4,44],[1,.4,38],[2,.4,40],[3,.18,46],[3.5,.18,50]])if(!settle||x<3||b===8)note('pulse',b+x,73,d,settle?v-12:v);
  for(const x of [0,2])note('pulse',b+x,36,.14,settle?52:70);
  if(!settle)for(const x of [3,3.5])note('pulse',b+x,64,.14,58);
  note('bass',b,boleroTone(p.root,chord,0,38),b===12?3.8:1.4,settle?70:84);
  if(b<12)note('bass',b+2,boleroTone(p.root,chord,2,38),.9,settle?60:74);
  const comp=settle?[[1.5,1]]:[[.5,0],[1,1],[1.5,2],[2.5,0],[3,1],[3.5,2]];
  if(b<12)for(const [x,i] of comp)note('guitar',b+x,boleroTone(p.root,chord,i,57),.24,settle?36:44);
 }
 for(const [x,interval,duration] of [[0,7,1.5],[1.5,8,.5],[2,7,1],[3,5,1],[4,8,1.5],[5.5,10,.5],[6,12,1],[7,10,1],[8,14,1.5],[9.5,12,.5],[10,10,1],[11,8,1],[12,7,3.75]])
  note('lead',x,p.root+interval,duration,x>=8?58:72);
 for(const [x,interval,duration] of [[6.5,22,.4],[7,19,.4],[7.5,17,.4],[12,15,3.75]])note('answer',x,p.root+interval,duration,x>=8?44:50);
 // The last chord: F major, held by the strings and the montuno.
 for(const interval of [3,7,10,15])note('brass',12,p.root+interval,3.75,40);
 for(const interval of [3,7,10])note('guitar',12,p.root-12+interval+12,1.8,40);
 note('pulse',12,36,.14,48);
 const result=transitionBase(p.id+'_success',p.title+' — Room Approval',p,p.bpms,events,'success');
 result.bars=4;result.phraseBars=4;result.style='Original synth bolero-cha instrumental';result.parentScore=p.id;result.tierBpms=p.bpms;
 result.sections=[{bar:0,bars:2,name:'Recognition'},{bar:2,bars:2,name:'Resolution to the relative major'}];
 result.tracks=result.tracks.map(t=>t.id==='brass'?{...t,program:48}:t);
 result.resolvesTo={midiTonic:p.root+3,mode:'major'};
 result.musicalIntent='Quote the salon\'s call over D minor, then B-flat and C7 carry it home to F major, the relative major, and the band thins as it lands.';
 return result;
}
// Mansion, act two: three original room scores, their tags and the bridges that
// join the campaign billiards, comedor, salon, galeria, terraza. Each is a written
// 32-bar form with five tiers whose 0, 2 and 4 are the rendered low, mid and high
// tempos. A chord is [semitones above the key's tonic, kind]; a phrase line is
// [beat, semitones above the lead's tonic, length] over two bars.
const roomKinds={M:[0,4,7],m:[0,3,7],'7':[0,4,7,10]};
const roomTone=(root,[semis,kind],index,low)=>{
 const tones=roomKinds[kind];const pc=(root+semis+tones[index%tones.length])%12;
 return low+((pc-low)%12+12)%12;
};
const roomChordAt=(p,bar,beat)=>{const c=p.form[bar%p.form.length];return p.chords[c[c.length>1&&beat>=2?1:0]]};
// The nearest chord tone at least a minor third under a pitch: a written harmony line.
function harmonyBelow(p,bar,beat,pitch){
 const chord=roomChordAt(p,bar,beat);
 for(let d=3;d<10;d++){const pc=((pitch-d)%12+12)%12;if(roomKinds[chord[1]].some(t=>(p.key+chord[0]+t)%12===pc))return pitch-d;}
 return pitch-12;
}
// Polka: tololoche on every beat (root and fifth), bajo sexto and snare on every "and".
function polkaGroove(p,note,bar,b){
 for(const x of [0,1,2,3]){
  const c=roomChordAt(p,bar,x);
  note('bass',b+x,roomTone(p.key,c,x%2?2:0,41),.42,x%2?74:86);
  note('pulse',b+x+.5,38,.1,x%2?52:46);
  for(const i of [0,1,2])note('guitar',b+x+.5,roomTone(p.key,c,i,57),.2,x%2?44:38);
 }
 // Tier 1: a kick under the oom and a run of bass into each phrase.
 for(const x of [0,2])note('pulse',b+x,36,.14,70,1);
 if(bar%2===1){const c=roomChordAt(p,bar+1,0);for(const [x,i] of [[3,2],[3.5,1]])note('bass',b+x,roomTone(p.key,c,i,41),.3,70,1);}
 // Tier 3: a ride cymbal ticks the "and"s with the snare.
 for(const x of [.5,1.5,2.5,3.5])note('pulse',b+x,80,.06,30,3);
 // Tier 4: trumpets punch the "pah" of the phrase's second bar, and a crash at each eight.
 if(bar%2===1)for(const x of [.5,1.5])for(const i of [0,1,2])note('brass',b+x,roomTone(p.key,roomChordAt(p,bar,x),i,65),.2,46,4);
 if(bar%8===0)note('pulse',b,82,.5,40,4);
}
// Reel: bodhrán on the beats with its tipper triplet into beat 3; hard shoes on the eighths.
function reelGroove(p,note,bar,b){
 const c=roomChordAt(p,bar,0), late=roomChordAt(p,bar,2);
 for(const x of [0,1,2,3])note('pulse',b+x,x%2?62:36,.12,x===0?80:x===2?72:56);
 // The bouzouki chops a chord on beats 1 and the "and" of 2; a drone holds the tonic.
 for(const x of [0,1.5,2,3.5])for(const i of [0,1,2])note('guitar',b+x,roomTone(p.key,x<2?c:late,i,52),.3,x%2===0?44:36);
 note('bass',b,p.key-24,3.9,62);
 note('bass',b,roomTone(p.key,c,0,45),1.8,58);
 note('bass',b+2,roomTone(p.key,late,0,45),1.8,52);
 // Tier 1: hard shoes on every eighth, heavier on the beat.
 for(let x=0;x<4;x+=.5)note('pulse',b+x,75,.06,x%1?40:58,1);
 // Tier 2: the bodhrán's tipper triplet into beats 2 and 4.
 for(const s of [0,2])for(const [j,v] of [[0,40],[1,46],[2,52]])note('pulse',b+s+.67+j/9,62,.05,v,2);
 // Tier 4: pipes drone the tonic and fifth, and the line stamps a treble on beat 4 every second bar.
 note('brass',b,p.key-12,3.9,40,4);note('brass',b,p.key-5,3.9,34,4);
 if(bar%2===1)for(const x of [3,3.25,3.5])note('pulse',b+x,75,.05,66,4);
}
// Batucada: surdo on 2 and 4 with the answer on 1 and 3, caixa in sixteenths,
// tamborim's teleco-teco, agogô, and the apito calling every eighth bar.
function sambaGroove(p,note,bar,b){
 const c=roomChordAt(p,bar,0), late=roomChordAt(p,bar,2);
 for(const x of [1,3])note('pulse',b+x,36,.3,88);
 for(const x of [0,2])note('pulse',b+x,58,.2,58);
 for(let x=0;x<4;x+=.25)note('pulse',b+x,38,.05,x%1===.75?50:x%1===0?42:30);
 // Seven-string guitar walks the bass; the cavaquinho strums the syncopation.
 note('bass',b,roomTone(p.key,c,0,36),.9,82);note('bass',b+1,roomTone(p.key,c,2,36),.4,70);
 note('bass',b+2,roomTone(p.key,late,0,36),.9,80);note('bass',b+3,roomTone(p.key,late,2,36),.4,68);
 for(const x of [.5,1.25,2.5,3.25])for(const i of [0,1,2])note('guitar',b+x,roomTone(p.key,x<2?c:late,i,64),.18,x%1===.25?46:38);
 // Tier 1: tamborim teleco-teco, the hands' syncopation.
 for(const x of [0,.75,1.5,2.25,3,3.5])note('pulse',b+x,76,.05,54,1);
 // Tier 2: agogô bell, high and low.
 for(const [x,pitch] of [[0,67],[.5,67],[1,68],[1.75,67],[2.5,68],[3,67]])note('pulse',b+x,pitch,.08,40,2);
 // Tier 3: the apito calls the band into each eight.
 if(bar%8===7)for(const [x,d] of [[2,.4],[2.75,.2],[3,.2],[3.5,.4]])note('pulse',b+x,79,d,48,3);
 // Tier 4: the brass lifts on the "and" of 4 into each phrase.
 if(bar%2===1)for(const i of [0,1,2,3])note('brass',b+3.5,roomTone(p.key,roomChordAt(p,bar+1,0),i,60),.45,52,4);
 if(bar%2===1)for(const i of [0,1,2])note('brass',b+1.5,roomTone(p.key,late,i,60),.3,44,4);
}
// Reel tunes are written as degrees of A Dorian, eight eighths a bar.
const dorian=[0,2,3,5,7,9,10];
const deg=d=>12*Math.floor(d/7)+dorian[((d%7)+7)%7];
const reelBars=[
 [4,0,0,-1,0,1,2,0],[-1,-4,-4,-3,-1,1,3,1],[2,0,4,0,2,0,4,7],[6,4,3,1,-1,1,3,4],
 [4,0,0,-1,0,1,2,4],[3,5,7,5,3,5,3,1],[4,1,-1,1,4,6,4,2],[1,-1,0,4,0,0,0,-3],
 [2,4,6,4,9,6,4,2],[-1,1,3,6,8,6,3,1],[3,5,7,10,7,5,3,5],[7,4,2,4,7,8,9,7],
 [9,7,6,4,2,4,6,9],[8,6,3,6,8,10,8,6],[4,6,8,6,4,1,-1,1],[0,4,2,1,0,-1,0,0],
];
function reelPhrase(a,c){
 const line=[];
 for(const [k,bar] of [a,c].entries())for(const [i,d] of bar.entries()){
  const last=line[line.length-1], beat=k*4+i/2;
  // A repeated note is a cut, so it is written as one longer note.
  if(last&&last[1]===deg(d)&&i>0)last[2]+=.5;else line.push([beat,deg(d),.45]);
 }
 const end=line[line.length-1];if(c===reelBars[15])end[2]=Math.max(end[2],1.4);
 return line;
}
const rP=Array.from({length:8},(_,i)=>reelPhrase(reelBars[2*i],reelBars[2*i+1]));
const polkaPh={
 P1:[[0,12,.5],[.5,9,.5],[1,7,.5],[1.5,9,.5],[2,12,1],[3,16,.5],[3.5,14,.5],[4,12,.5],[4.5,9,.5],[5,7,1],[6,9,.5],[6.5,12,.5],[7,16,1]],
 P2:[[0,14,.5],[.5,11,.5],[1,7,.5],[1.5,11,.5],[2,14,1],[3,17,.5],[3.5,16,.5],[4,14,.5],[4.5,11,.5],[5,7,1],[6,7,.5],[6.5,11,.5],[7,14,1]],
 P3:[[0,19,1],[1,17,.5],[1.5,16,.5],[2,14,.5],[2.5,11,.5],[3,7,1],[4,7,.5],[4.5,11,.5],[5,14,.5],[5.5,17,.5],[6,16,2]],
 P4:[[0,12,.5],[.5,16,.5],[1,19,.5],[1.5,16,.5],[2,12,1],[3,9,1],[4,9,.5],[4.5,7,.5],[5,4,.5],[5.5,7,.5],[6,0,1.5]],
 P5:[[0,17,.5],[.5,12,.5],[1,9,.5],[1.5,12,.5],[2,17,1],[3,21,.5],[3.5,19,.5],[4,17,.5],[4.5,12,.5],[5,9,1],[6,12,.5],[6.5,14,.5],[7,17,1]],
 P6:[[0,16,.5],[.5,12,.5],[1,9,.5],[1.5,12,.5],[2,16,1],[3,14,1],[4,11,.5],[4.5,14,.5],[5,19,.5],[5.5,17,.5],[6,16,.5],[6.5,14,.5],[7,11,1]],
 B1:[[0,9,1],[1,12,.5],[1.5,17,.5],[2,21,1.5],[3.5,19,.5],[4,17,1],[5,12,.5],[5.5,14,.5],[6,17,2]],
 B2:[[0,16,1],[1,19,.5],[1.5,15,.5],[2,12,1.5],[3.5,9,.5],[4,7,1],[5,9,.5],[5.5,12,.5],[6,15,2]],
 B3:[[0,19,.5],[.5,16,.5],[1,12,.5],[1.5,16,.5],[2,19,1],[3,24,1],[4,21,.5],[4.5,19,.5],[5,16,.5],[5.5,15,.5],[6,12,2]],
 B4:[[0,17,.5],[.5,21,.5],[1,17,.5],[1.5,12,.5],[2,9,1],[3,5,1],[4,7,.5],[4.5,11,.5],[5,14,.5],[5.5,16,.5],[6,19,1],[7,17,1]],
};
const sambaPh={
 S1:[[0,7,.5],[.75,9,.25],[1,7,.5],[1.75,4,.75],[2.5,7,.5],[3,12,1],[4.25,11,.25],[4.5,9,.5],[5,7,.5],[5.75,4,.5],[6.5,2,.5],[7,0,1]],
 S2:[[0,9,.5],[.75,13,.25],[1,16,.5],[1.75,13,.75],[2.5,9,.5],[3,7,1],[4.25,9,.25],[4.5,13,.5],[5,16,.5],[5.75,19,.5],[6.5,16,.5],[7,13,1]],
 S3:[[0,14,.5],[.75,17,.25],[1,21,.5],[1.75,17,.75],[2.5,14,.5],[3,9,1],[4.25,11,.25],[4.5,14,.5],[5,17,.5],[5.75,19,.5],[6.5,17,.5],[7,14,1]],
 S4:[[0,16,.5],[.75,14,.25],[1,12,.5],[1.75,7,.75],[2.5,4,.5],[3,7,1],[4.25,5,.25],[4.5,7,.5],[5,11,.5],[5.75,14,.5],[6.5,11,.5],[7,7,1]],
 S4b:[[0,16,.5],[.75,14,.25],[1,12,.5],[1.75,7,.75],[2.5,4,.5],[3,7,1],[4.25,9,.25],[4.5,7,.5],[5,4,.5],[5.75,2,.5],[6.5,0,1.5]],
 S5:[[0,17,1],[1,16,.5],[1.5,17,.5],[2,21,1],[3,17,.5],[3.75,12,.75],[4.5,9,.5],[5,12,.5],[5.75,17,.75],[6.5,21,.5],[7,24,1]],
 S6:[[0,20,1],[1,17,.5],[1.5,20,.5],[2,24,1],[3,20,.5],[3.75,17,.75],[4.5,12,.5],[5,8,.5],[5.75,12,.75],[6.5,17,.5],[7,20,1]],
 S7:[[0,19,.5],[.75,16,.25],[1,12,.5],[1.75,16,.75],[2.5,19,.5],[3,24,1],[4.25,21,.25],[4.5,19,.5],[5,16,.5],[5.75,13,.5],[6.5,9,.5],[7,7,1]],
 S9:[[0,16,.5],[.75,19,.25],[1,23,.5],[1.75,19,.75],[2.5,16,.5],[3,11,1],[4.25,13,.25],[4.5,16,.5],[5,19,.5],[5.75,21,.5],[6.5,19,.5],[7,16,1]],
};
const actTwoPieces=[
 {id:'comedor_polka',title:'Sobremesa',stat:'Gusto',level:'comedor',bars:32,bpms:[120,124,128,132,136],key:53,root:65,mode:'major',
  chords:{F:[0,'M'],C7:[7,'7'],Bb:[5,'M'],F7:[0,'7']},
  form:[['F'],['F'],['C7'],['C7'],['C7'],['C7'],['F'],['F'], ['F'],['F'],['Bb'],['Bb'],['F'],['C7'],['F'],['F'],
   ['Bb'],['Bb'],['F7'],['F7'],['F7'],['F7'],['Bb'],['C7'], ['F'],['F'],['Bb'],['Bb'],['F'],['C7'],['F'],['F']],
  phrases:['P1','P2','P3','P4','P1','P5','P6','P4','B1','B2','B3','B4','P1','P5','P6','P4'].map(k=>polkaPh[k]),
  groove:polkaGroove,programs:{lead:21,guitar:25,bass:32,answer:72,brass:56},style:'Original synth norteño polka instrumental',
  color:'button accordion lead, bajo sexto on the "and"s, tololoche on every beat, snare on the pah, accordion thirds and trumpets at the top',
  tierNames:['Bajo sexto and tololoche','Kick under the oom','Accordion sings','Accordion in thirds','Trumpets at the table'],
  sectionNames:['First course','Second helping','The trio, in B-flat','Sobremesa'],
  success:{plan:[['F',0],['Bb',4],['C7',8],['F',12]],final:false},
  intent:'Quote the polka\'s call over F, then B-flat and C7 bring it home to F; the band thins to the tololoche and snare as Don Charolas lifts the cloche.'},
 {id:'galeria_reel',title:'Trébol',stat:'Drive',level:'galeria',bars:32,bpms:[112,116,120,124,128],key:57,root:69,mode:'dorian',
  chords:{Am:[0,'m'],G:[10,'M'],D:[5,'M'],Em:[7,'m'],C:[3,'M']},
  form:[['Am'],['G'],['Am'],['G'],['Am'],['D'],['Em'],['Am'], ['Am'],['G'],['Am'],['G'],['Am'],['D'],['Em'],['Am'],
   ['C'],['G'],['D'],['Am'],['C'],['G'],['Em'],['Am'], ['C'],['G'],['D'],['Am'],['C'],['G'],['Em'],['Am']],
  phrases:[rP[0],rP[1],rP[2],rP[3],rP[0],rP[1],rP[2],rP[3],rP[4],rP[5],rP[6],rP[7],rP[4],rP[5],rP[6],rP[7]],
  groove:reelGroove,programs:{lead:40,guitar:25,bass:42,answer:78,brass:109},style:'Original synth Celtic reel instrumental',
  color:'driving fiddle in eighths, bouzouki chop, cello drone, bodhrán, hard shoes on every eighth, tin whistle and uilleann pipes at the top',
  tierNames:['Bodhrán and drone','Hard shoes join','Fiddle drives','Double stops and whistle','Pipes and the full line'],
  sectionNames:['The tune','The tune again','The turn','The turn again'],
  success:{plan:[['Am',0],['G',4],['Em',8],['Am',12]],final:false},
  intent:'Quote the reel\'s first bars, then G and E minor turn it home to A; the line stops dead with the shoes and the drone holds.'},
 {id:'terraza_samba',title:'Purpurina',stat:'Joy',level:'terraza',bars:32,bpms:[96,100,104,108,112],key:60,root:72,mode:'major',
  chords:{C:[0,'M'],A7:[9,'7'],Dm:[2,'m'],G7:[7,'7'],C7:[0,'7'],F:[5,'M'],Fm:[5,'m'],Em:[4,'m']},
  form:[['C'],['C'],['A7'],['A7'],['Dm'],['G7'],['C'],['G7'], ['C'],['C'],['A7'],['A7'],['Dm'],['G7'],['C'],['C'],
   ['F'],['F'],['Fm'],['Fm'],['C'],['A7'],['Dm'],['G7'], ['Em'],['A7'],['Dm'],['G7'],['C'],['A7'],['Dm'],['G7']],
  phrases:['S1','S2','S3','S4','S1','S2','S3','S4b','S5','S6','S7','S3','S9','S3','S7','S3'].map(k=>sambaPh[k]),
  groove:sambaGroove,programs:{lead:105,guitar:24,bass:24,answer:66,brass:61},style:'Original synth samba batucada instrumental',
  color:'surdo on 2 and 4, caixa sixteenths, tamborim and agogô, cavaquinho line and strum, apito calls, brass lifts at the top',
  tierNames:['Surdo, caixa and cavaquinho','Tamborim joins','Agogô and the full line','The apito calls','Brass lift'],
  sectionNames:['Arrival','Again, brighter','The turn to F','Home to the fireworks'],
  success:{plan:[['C',0],['A7',4],['G7',8],['C',12]],final:true},
  intent:'Quote the samba\'s call over C, then A7 and G7 bring it home to C; the bateria stops on the downbeat and the surdo rings out under the fireworks.'},
];
const actTwoTracks=p=>tracks.map(t=>({...t,program:p.programs[t.id]??t.program}));
function composeRoom(p){
 const events=[], note=(track,beat,pitch,duration,velocity,minTier=0,maxTier=4)=>events.push({track,beat,pitch,duration,velocity,minTier,maxTier});
 for(let bar=0;bar<p.bars;bar++)p.groove(p,note,bar,bar*4);
 const end=p.bars*4;
 for(const [phrase,line] of p.phrases.entries()){
  const base=phrase*8;
  for(const [i,[offset,interval,duration]] of line.entries()){
   const beat=base+offset, length=Math.min(duration,end-beat), pitch=p.root+interval;
   // The full line from tier 2; a sparser, quieter line below it.
   note('lead',beat,pitch,length,76,2);
   if(i%2===0||i===1||i===line.length-1)note('lead',beat,pitch,Math.min(length*.85,end-beat),58,0,1);
   // Tier 3: a harmony on the strong notes, the accordion's thirds, the fiddle's double stops.
   if(offset%1===0)note('lead',beat,harmonyBelow(p,Math.floor(beat/4),beat%4,pitch),length,54,3);
   // The answer voice doubles the line an octave up at the top, as a whistle or horn.
   if(offset<6)note('answer',beat,pitch+12,Math.min(length*.8,end-beat),36,3);
  }
 }
 events.sort((a,c)=>a.beat-c.beat||a.track.localeCompare(c.track)||a.pitch-c.pitch||a.minTier-c.minTier);
 const adornments=[
  {id:'spark',gesture:'up',quantizeBeats:.25,events:[[0,12,.12],[.25,16,.12],[.5,19,.25]]},
  {id:'dip',gesture:'down',quantizeBeats:.25,events:[[0,12,.16],[.25,7,.16],[.5,0,.3]]},
  {id:'slide',gesture:'left',quantizeBeats:.25,events:[[0,9,.2],[.25,7,.2],[.5,5,.2],[.75,4,.2]]},
  {id:'shine',gesture:'right',quantizeBeats:.25,events:[[0,0,.2],[.25,7,.2],[.5,12,.4]]},
 ].map(a=>({...a,events:a.events.map(([beat,pitch,duration])=>({track:'answer',beat,pitch:p.root+pitch,duration,velocity:62,minTier:0}))}));
 return {schemaVersion:1,id:p.id,title:p.title,stat:p.stat,composer:'Kumbia Kombat original project score',
  license:'See assets/music/LICENSE.md',ppq:PPQ,beatsPerBar:4,bars:p.bars,phraseBars:2,
  key:{midiTonic:p.key,mode:p.mode},style:p.style,color:p.color,tierBpms:p.bpms,
  tiers:p.bpms.map((bpm,tier)=>({tier,bpm,name:p.tierNames[tier]})),
  sections:p.sectionNames.map((name,i)=>({bar:i*8,bars:8,name})),
  tracks:actTwoTracks(p),events,adornments,
  gameplayReference:{authority:`levels/${p.level}.json; score EOF does not approve an opponent`,
   phrasePassesPerTier:2,fullTierChallengePasses:2,cleanTargetSeconds:110},
  transition:{cadenceBars:2,nextLevelCountInBars:1}};
}
// Four bars: the room's call over the first two chords, then the cadence, thinning
// to bass, the kick on 1 and 3 and the tonic answer.
function composeRoomSuccess(p){
 const events=[], note=(track,beat,pitch,duration,velocity)=>events.push({track,beat,pitch,duration,velocity,minTier:0,maxTier:4});
 for(const [name,b] of p.success.plan){
  const chord=p.chords[name], settle=b>=8, last=b===12;
  for(const x of [0,2])note('pulse',b+x,36,.14,settle?56:78);
  if(!settle)for(const x of [.5,1.5,2.5,3.5])note('pulse',b+x,38,.1,48);
  else if(!last)for(const x of [1.5,3.5])note('pulse',b+x,38,.1,34);
  note('bass',b,roomTone(p.key,chord,0,38),last?3.8:1.4,settle?68:84);
  if(!last)note('bass',b+2,roomTone(p.key,chord,2,38),.9,settle?58:74);
  const comp=settle?(last?[]:[[.5,0],[2.5,1]]):[[.5,0],[1.5,1],[2.5,2],[3.5,0]];
  for(const [x,i] of comp)for(const j of [0,1])note('guitar',b+x,roomTone(p.key,chord,i+j,57),.22,settle?34:44);
 }
 const call=p.phrases[0].filter(n=>n[0]<8);
 for(const [x,interval,duration] of call)note('lead',x,p.root+interval,duration,74);
 // The tonic answer: down to the root over the cadence and held.
 const home=p.root;
 for(const [x,,duration] of [[8,7,1],[9,4,.5],[9.5,2,.5],[10,4,1],[11,2,1]]){
  const tone=roomTone(p.root,p.chords[p.success.plan[2][0]],[0,1,2,3][Math.round(x*2)%3],p.root);
  note('lead',x,tone,duration,56);
 }
 note('lead',12,home,3.75,54);
 for(const i of [0,1,2])note('brass',12,roomTone(p.key,p.chords[p.success.plan[3][0]],i,p.key+12),3.75,38);
 for(const i of [0,1,2])note('guitar',12,roomTone(p.key,p.chords[p.success.plan[3][0]],i,57),1.8,38);
 const result=transitionBase(p.id+'_success',p.title+' — Room Approval',p,p.bpms,events,'success');
 result.bars=4;result.phraseBars=4;result.style=p.style;result.parentScore=p.id;result.tierBpms=p.bpms;
 result.key={midiTonic:p.key,mode:p.mode};result.tracks=actTwoTracks(p);result.final=p.success.final;
 result.sections=[{bar:0,bars:2,name:'Recognition'},{bar:2,bars:2,name:'Cadence and the tonic answer'}];
 result.musicalIntent=p.intent;
 return result;
}
// Two bars at the destination's base tempo: its groove on percussion alone, then the
// last room's key turns to the destination's dominant while the answer quotes its call.
function composeActTwoBridge({id,title,from,fromLevel,to,toLevel,percussion,turn,intent}){
 const events=[], note=(track,beat,pitch,duration,velocity)=>events.push({track,beat,pitch,duration,velocity,minTier:0,maxTier:4});
 percussion(note,0);
 percussion(note,4,true);
 for(const [x,[semis,kind],length] of turn){
  note('bass',4+x,roomTone(to.key??to.root,[semis,kind],0,38),length*.9,80);
  for(const i of [0,1,2])note('guitar',4+x+.5,roomTone(to.key??to.root,[semis,kind],i,57),.24,44);
 }
 const motif=(to.motif??to.phrases[0]).filter(n=>n[0]<3.5);
 const lead=to.root??to.key;
 for(const [offset,interval,duration] of motif)note('answer',4+offset,(to.root??lead)+interval+(to.motif?12:0),Math.min(duration,3.75-offset),66);
 const result=transitionBase(id,title,to,to.bpms[0],events,'bridge');
 if(to.programs)result.tracks=actTwoTracks(to);
 if(to.key!==undefined&&to.programs)result.key={midiTonic:to.key,mode:to.mode};
 result.style=to.style??'Original synth bolero-cha instrumental';result.fromScore=from;result.toScore=to.id;
 result.fromLevel=fromLevel;result.toLevel=toLevel;result.musicalIntent=intent;
 result.tempoIntent=`Takes ${toLevel}'s base tempo, ${to.bpms[0]}, at its downbeat, as every bridge does. No pitch or time crossfade.`;
 return result;
}
const [comedorPiece,galeriaPiece,terrazaPiece]=actTwoPieces;
const actTwoBridges=salon=>[
 {id:'billiards_to_comedor',title:'Through the Service Door',from:'crowd_duende',fromLevel:'billiards',to:comedorPiece,toLevel:'comedor',
  percussion:(note,b,second)=>{for(const x of [0,1,2,3]){note('pulse',b+x,36,.14,second?64:70);note('pulse',b+x+.5,38,.1,x%2?52:44);}},
  turn:[[0,[2,'m'],2],[2,[7,'7'],2]],
  intent:'The billiard room\'s G minor becomes ii of F: a bar of oom-pah on kick and snare, then G minor and C7 into the comedor\'s F major while the trumpet quotes its call.'},
 {id:'comedor_to_salon',title:'Coffee in the Mirrors',from:'comedor_polka',fromLevel:'comedor',to:salon,toLevel:'salon',
  percussion:(note,b)=>chachaPercussion(note,b,0),
  turn:[[0,[3,'M'],2],[2,[7,'7'],2]],
  intent:'The polka\'s F major is the relative major of the salon\'s D minor: a bar of güiro and the cha-cha, then F and A7, so the salon\'s downbeat lands as its tonic while the flute quotes its call.'},
 {id:'salon_to_galeria',title:'Down the Long Gallery',from:'salon_bolero',fromLevel:'salon',to:galeriaPiece,toLevel:'galeria',
  percussion:(note,b)=>{for(const x of [0,1,2,3])note('pulse',b+x,x%2?62:36,.12,x===0?80:58);for(let x=0;x<4;x+=.5)note('pulse',b+x,75,.06,x%1?36:54);},
  turn:[[0,[5,'m'],2],[2,[10,'M'],2]],
  intent:'The salon\'s D minor becomes iv of A: a bar of bodhrán and hard shoes, then D minor and G, the Dorian bVII, into the gallery\'s A while the whistle quotes the reel.'},
 {id:'galeria_to_terraza',title:'Up to the Fireworks',from:'galeria_reel',fromLevel:'galeria',to:terrazaPiece,toLevel:'terraza',
  percussion:(note,b,second)=>{for(const x of [1,3])note('pulse',b+x,36,.3,86);for(let x=0;x<4;x+=.25)note('pulse',b+x,38,.05,x%1===.75?50:30);if(second)for(const x of [0,.75,1.5,2.25,3])note('pulse',b+x,76,.05,54);},
  turn:[[0,[9,'m'],2],[2,[7,'7'],2]],
  intent:'The reel\'s A minor is the relative minor of C: a bar of surdo and caixa, then A minor and G7 into the terrace\'s C major while the horn quotes the samba\'s call.'},
];
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
for(const piece of swingPieces){
 const score=composeSwing(piece);
 writeFileSync(resolve(root,`assets/music/scores/${piece.id}.json`),JSON.stringify(score)+'\n');
 for(let tier=0;tier<5;tier++)writeFileSync(resolve(root,`assets/music/midi/${piece.id}_tier${tier}.mid`),midi(score,tier));
 manifest.scores.push({id:score.id,title:score.title,path:`assets/music/scores/${score.id}.json`,bars:score.bars,baseBpm:score.tiers[0].bpm,fullBpm:score.tiers[4].bpm});
 console.log(`${score.id}: ${score.events.length} notes, ${score.bars} bars, five MIDI arrangements`);
 const success=composeSwingSuccess(piece);
 writeFileSync(resolve(root,'assets/music/scores/'+success.id+'.json'),JSON.stringify(success)+'\n');
 writeFileSync(resolve(root,'assets/music/midi/'+success.id+'.mid'),midi(success,4));
 manifest.transitions.successes.push({id:success.id,title:success.title,bars:2,baseBpm:success.tiers[0].bpm,fullBpm:success.tiers[4].bpm,parentScore:piece.id,path:'assets/music/scores/'+success.id+'.json',midiPath:'assets/music/midi/'+success.id+'.mid'});
 console.log(success.id+': original two-bar success phrase');
 const bar=pieces.find(p=>p.id==='bar_swag');
 for(const bridge of [
  composeIntoSwing(piece,{id:'bar_to_pool',title:'Out to the Lawn',fromScore:'bar_swag',clave:[0,1.5,3],intent:'The bar\'s straight C-minor feel ends in a drum break; the bass walks C, F, B-flat into E-flat major and the band starts to swing.'}),
  composeIntoSwing(piece,{id:'garden_to_pool',title:'Up the Lantern Path',fromScore:'garden_mojo',clave:[0,.75,2.5],intent:'The garden\'s A minor dissolves in a drum break; C is common to both keys, and the bass walks C, F, B-flat into E-flat major as the band starts to swing.'}),
  composePoolToBar(piece,bar),
 ]){
  writeFileSync(resolve(root,'assets/music/scores/'+bridge.id+'.json'),JSON.stringify(bridge)+'\n');
  writeFileSync(resolve(root,'assets/music/midi/'+bridge.id+'.mid'),midi(bridge,0));
  manifest.transitions.bridges.push({id:bridge.id,title:bridge.title,bars:2,baseBpm:bridge.tiers[0].bpm,fullBpm:bridge.tiers[4].bpm,fromScore:bridge.fromScore,toScore:bridge.toScore,path:'assets/music/scores/'+bridge.id+'.json',midiPath:'assets/music/midi/'+bridge.id+'.mid'});
  console.log(bridge.id+': original two-bar percussion pivot and pickup');
 }
 const barPiece=pieces.findIndex(p=>p.id==='bar_swag');
 const finale=composeBarFinale(composeSuccess(pieces[barPiece],barPiece),pieces[barPiece]);
 writeFileSync(resolve(root,'assets/music/scores/'+finale.id+'.json'),JSON.stringify(finale)+'\n');
 writeFileSync(resolve(root,'assets/music/midi/'+finale.id+'.mid'),midi(finale,4));
 manifest.transitions.successes.push({id:finale.id,title:finale.title,bars:4,baseBpm:finale.tiers[0].bpm,fullBpm:finale.tiers[4].bpm,parentScore:'bar_swag',path:'assets/music/scores/'+finale.id+'.json',midiPath:'assets/music/midi/'+finale.id+'.mid'});
 console.log(finale.id+': the bar\'s tag with room for the gulp');
}
for(const piece of boleroPieces){
 const score=composeBolero(piece);
 writeFileSync(resolve(root,`assets/music/scores/${piece.id}.json`),JSON.stringify(score)+'\n');
 for(let tier=0;tier<5;tier++)writeFileSync(resolve(root,`assets/music/midi/${piece.id}_tier${tier}.mid`),midi(score,tier));
 manifest.scores.push({id:score.id,title:score.title,path:`assets/music/scores/${score.id}.json`,bars:score.bars,baseBpm:score.tiers[0].bpm,fullBpm:score.tiers[4].bpm});
 console.log(`${score.id}: ${score.events.length} notes, ${score.bars} bars, five MIDI arrangements`);
 const success=composeBoleroSuccess(piece);
 writeFileSync(resolve(root,'assets/music/scores/'+success.id+'.json'),JSON.stringify(success)+'\n');
 writeFileSync(resolve(root,'assets/music/midi/'+success.id+'.mid'),midi(success,4));
 manifest.transitions.successes.push({id:success.id,title:success.title,bars:4,baseBpm:success.tiers[0].bpm,fullBpm:success.tiers[4].bpm,parentScore:piece.id,path:'assets/music/scores/'+success.id+'.json',midiPath:'assets/music/midi/'+success.id+'.mid'});
 console.log(success.id+': four-bar tag resolving to the relative major');
}
// Act two. billiards_to_salon is retired: the comedor now sits between them.
for(const piece of actTwoPieces){
 const score=composeRoom(piece);
 writeFileSync(resolve(root,`assets/music/scores/${piece.id}.json`),JSON.stringify(score)+'\n');
 for(let tier=0;tier<5;tier++)writeFileSync(resolve(root,`assets/music/midi/${piece.id}_tier${tier}.mid`),midi(score,tier));
 manifest.scores.push({id:score.id,title:score.title,path:`assets/music/scores/${score.id}.json`,bars:score.bars,baseBpm:score.tiers[0].bpm,fullBpm:score.tiers[4].bpm});
 console.log(`${score.id}: ${score.events.length} notes, ${score.bars} bars, five MIDI arrangements`);
 const success=composeRoomSuccess(piece);
 writeFileSync(resolve(root,'assets/music/scores/'+success.id+'.json'),JSON.stringify(success)+'\n');
 writeFileSync(resolve(root,'assets/music/midi/'+success.id+'.mid'),midi(success,4));
 manifest.transitions.successes.push({id:success.id,title:success.title,bars:4,baseBpm:success.tiers[0].bpm,fullBpm:success.tiers[4].bpm,parentScore:piece.id,final:success.final,path:'assets/music/scores/'+success.id+'.json',midiPath:'assets/music/midi/'+success.id+'.mid'});
 console.log(success.id+': four-bar tag home to the tonic');
}
for(const spec of actTwoBridges(boleroPieces[0])){
 const bridge=composeActTwoBridge(spec);
 writeFileSync(resolve(root,'assets/music/scores/'+bridge.id+'.json'),JSON.stringify(bridge)+'\n');
 writeFileSync(resolve(root,'assets/music/midi/'+bridge.id+'.mid'),midi(bridge,0));
 manifest.transitions.bridges.push({id:bridge.id,title:bridge.title,bars:2,baseBpm:bridge.tiers[0].bpm,fullBpm:bridge.tiers[4].bpm,fromScore:bridge.fromScore,toScore:bridge.toScore,path:'assets/music/scores/'+bridge.id+'.json',midiPath:'assets/music/midi/'+bridge.id+'.mid'});
 console.log(bridge.id+': original two-bar percussion pivot and pickup');
}
writeFileSync(resolve(root,'assets/music/manifest.json'),JSON.stringify(manifest,null,2)+'\n');
