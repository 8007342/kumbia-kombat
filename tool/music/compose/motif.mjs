// Motif operations, counter-melody and fills. A motif is a list of
// [beat, semitones above the tonic, duration]; every operation returns a new list.
import {MODES,pick} from './harmony.mjs';

const pcOf=n=>((n%12)+12)%12;
export function nearestDegree(semi,scale){
 const octave=Math.floor(semi/12),pc=pcOf(semi);
 let best=0,bestDistance=99;
 scale.forEach((s,i)=>{const d=Math.abs(s-pc);if(d<bestDistance){best=i;bestDistance=d}});
 return octave*scale.length+best;
}
const degreeToSemi=(degree,scale)=>{
 const octave=Math.floor(degree/scale.length),i=((degree%scale.length)+scale.length)%scale.length;
 return octave*12+scale[i];
};
export const shiftDiatonic=(semi,steps,scale)=>degreeToSemi(nearestDegree(semi,scale)+steps,scale);

export const ops={
 statement:notes=>notes.map(n=>[...n]),
 /** The same contour on a higher scale step. */
 sequence:(notes,{scale})=>notes.map(([b,s,d])=>[b,shiftDiatonic(s,2,scale),d]),
 /** Rhythmic displacement: everything an eighth later, wrapping within the phrase. */
 displace:(notes,{beats})=>notes.map(([b,s,d])=>[(b+.5)%beats,s,d]).sort((a,b)=>a[0]-b[0]),
 /** Mirror the contour around the first note. */
 invert:(notes,{scale})=>{
  const axis=nearestDegree(notes[0][1],scale);
  return notes.map(([b,s,d])=>[b,degreeToSemi(2*axis-nearestDegree(s,scale),scale),d]);
 },
 /** Develop the opening cell: state it, then repeat it a step up in the second half. */
 fragment:(notes,{beats,scale})=>{
  const half=beats/2,cell=notes.filter(n=>n[0]<half);
  return [...cell,...cell.map(([b,s,d])=>[b+half,shiftDiatonic(s,1,scale),d])];
 },
 /** Split the longest note with an upper neighbour. */
 ornament:(notes,{scale})=>{
  const longest=notes.reduce((best,n,i)=>n[2]>notes[best][2]?i:best,0);
  return notes.flatMap(([b,s,d],i)=>i!==longest||d<.5?[[b,s,d]]:
   [[b,s,d/2],[b+d/2,shiftDiatonic(s,1,scale),d/4],[b+d*.75,s,d/4]]);
 },
 /** Same rhythm, pitches in reverse order: a reply that shares the call's material. */
 answer:notes=>{
  const pitches=notes.map(n=>n[1]).reverse();
  return notes.map(([b,,d],i)=>[b,pitches[i],d]);
 },
 /** Land on the tonic near the phrase end, so the section closes. */
 cadence:(notes,{beats,scale})=>{
  const body=notes.filter(n=>n[0]<beats-2.5);
  const from=body.length?body.at(-1)[1]:scale[2];
  const step=nearestDegree(from,scale)>nearestDegree(0,scale)?-1:1;
  return [...body,[beats-2,shiftDiatonic(0,step*2,scale),.5],[beats-1.5,shiftDiatonic(0,step,scale),.5],[beats-1,0,.75]];
 },
};
export function applyOp(name,notes,context){
 if(!ops[name])throw new Error(`unknown motif operation "${name}"`);
 return ops[name](notes,context);
}

/**
 * Fit notes to the key and to the chord sounding under them. Strong beats take the nearest
 * chord tone, other notes the nearest scale tone, so a developed motif still follows the
 * harmony rather than being pasted over it.
 */
export function fitToHarmony(notes,{tonic,mode,start,chordAt,register,previous=null}){
 const scale=MODES[mode],out=[];let last=previous;
 for(const [beat,semi,duration] of notes){
  const when=start+beat,chord=chordAt(when);
  const strong=beat%2===0||(beat%1===0&&duration>=.5);
  let pitch;
  const raw=tonic+semi;
  if(strong&&chord){
   const options=[];
   for(let p=raw-11;p<=raw+11;p++)if(chord.pcs.includes(pcOf(p)))options.push(p);
   pitch=options.sort((a,b)=>Math.abs(a-raw)-Math.abs(b-raw)||a-b)[0];
  }else pitch=tonic+degreeToSemi(nearestDegree(semi,scale),scale);
  const [low,high]=register;
  while(pitch<low)pitch+=12;
  while(pitch>high)pitch-=12;
  if(last!==null){
   if(pitch-last>9&&pitch-12>=low)pitch-=12;
   else if(last-pitch>9&&pitch+12<=high)pitch+=12;
  }
  out.push({beat:when,pitch,duration});
  last=pitch;
 }
 return out;
}

const interval=(a,b)=>pcOf(a-b);
const PERFECT=new Set([0,7]);
/**
 * A species-style counter-line against a melody: it moves mostly by step, prefers contrary
 * motion, avoids the melody's onsets, and never forms parallel fifths or octaves with it.
 */
export function counterLine(melody,timeline,register,rng){
 const sounding=beat=>{
  const hits=melody.filter(n=>n.beat<=beat&&n.beat+Math.max(n.duration,.25)>beat);
  if(hits.length)return hits.at(-1).pitch;
  const before=melody.filter(n=>n.beat<=beat);
  return before.length?before.at(-1).pitch:null;
 };
 const onsets=new Set(melody.map(n=>n.beat));
 const out=[];let last=null,lastMelody=null;
 for(const entry of timeline){
  const bar=entry.bar*4,scale=MODES[entry.mode];
  const grid=[.25,.75,1.25,1.75,2.25,2.75,3.25,3.75,1,2,3].filter(x=>!onsets.has(bar+x));
  const count=2+Math.floor(rng()*3),chosen=new Set();
  while(chosen.size<Math.min(count,grid.length))chosen.add(pick(rng,grid));
  for(const x of [...chosen].sort((a,b)=>a-b)){
   const beat=bar+x,against=sounding(beat);
   const options=[];
   for(let p=register[0];p<=register[1];p++){
    const pc=pcOf(p),inChord=entry.pcs.includes(pc),inScale=scale.includes(pcOf(p-entry.tonic));
    if(!inChord&&!inScale)continue;
    if(against!==null&&p===against)continue;
    if(last!==null&&against!==null&&lastMelody!==null&&against!==lastMelody){
     const parallel=(p>last&&against>lastMelody)||(p<last&&against<lastMelody);
     if(parallel&&PERFECT.has(interval(p,against))&&interval(p,against)===interval(last,lastMelody))continue;
    }
    let cost=last===null?Math.abs(p-(register[0]+register[1])/2)*.2:Math.abs(p-last);
    if(last!==null&&p===last)cost+=3;
    if(inChord)cost-=1.5;
    if(last!==null&&against!==null&&lastMelody!==null&&against!==lastMelody){
     const contrary=(p-last)*(against-lastMelody)<0;
     if(contrary)cost-=3;
    }
    options.push({p,cost:cost+rng()*.5});
   }
   if(!options.length)continue;
   const best=options.sort((a,b)=>a.cost-b.cost||a.p-b.p)[0].p;
   out.push({beat,pitch:best,duration:.35});
   last=best;lastMelody=against;
  }
 }
 return out;
}

const FILLS=[
 [[0,65],[.25,64],[.5,60],[.75,65]],
 [[0,63],[.25,63],[.5,64],[.75,65]],
 [[0,60],[.25,64],[.5,65],[.75,75]],
 [[.25,64],[.5,65],[.75,60]],
];
/**
 * Percussion fills in the last beat of phrase-ending bars, with a longer lead-in at the
 * section end. They always finish inside the bar, so a phrase boundary stays clean.
 */
export function fills(timeline,rng){
 const out=[];
 for(const entry of timeline){
  const isSectionEnd=entry.barInSection===entry.sectionBars-1;
  if(entry.barInSection%4!==3&&!isSectionEnd)continue;
  const bar=entry.bar*4;
  const cell=pick(rng,FILLS);
  for(const [x,pitch] of cell)out.push({beat:bar+3+x,pitch,duration:.1});
  if(isSectionEnd)for(const [x,pitch] of pick(rng,FILLS))out.push({beat:bar+2+x,pitch,duration:.1});
 }
 return out;
}
