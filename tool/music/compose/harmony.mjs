// Harmony devices: chord parsing, the bar timeline, voice-led accompaniment and bass lines.
// Pure and deterministic; randomness only comes from the seeded generator passed in.

export const MODES={
 major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],dorian:[0,2,3,5,7,9,10],
 mixolydian:[0,2,4,5,7,9,10],phrygian:[0,1,3,5,7,8,10],harmonicMinor:[0,2,3,5,7,8,11],
};
const PITCH={C:0,'C#':1,Db:1,D:2,'D#':3,Eb:3,E:4,F:5,'F#':6,Gb:6,G:7,'G#':8,Ab:8,A:9,'A#':10,Bb:10,B:11};
const ROMAN=['i','ii','iii','iv','v','vi','vii'];

/** Seeded generator (mulberry32). The same seed always yields the same sequence. */
export function makeRng(seed,label=''){
 let h=seed>>>0;
 for(const c of label)h=Math.imul(h^c.charCodeAt(0),16777619)>>>0;
 return ()=>{
  h=(h+0x6D2B79F5)>>>0;let t=h;
  t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);
  return ((t^(t>>>14))>>>0)/4294967296;
 };
}
export const pick=(rng,list)=>list[Math.floor(rng()*list.length)];

/** Tonic in the octave around middle C: A3..G#4. */
export const tonicMidi=root=>{const pc=PITCH[root];return pc<9?60+pc:48+pc};

/** "bVII" or "V7" in a mode -> {root: semitones above the tonic, intervals, numeral}. */
export function parseChord(numeral,mode){
 const m=/^([b#]?)(i{1,3}|iv|v|vi{0,2}|I{1,3}|IV|V|VI{0,2})(o|7)?$/.exec(numeral);
 if(!m)throw new Error(`unknown chord numeral "${numeral}"`);
 const [,accidental,roman,suffix]=m;
 const degree=ROMAN.indexOf(roman.toLowerCase());
 const upper=roman===roman.toUpperCase();
 const root=(MODES[mode][degree]+(accidental==='b'?-1:accidental==='#'?1:0)+12)%12;
 const intervals=suffix==='o'?[0,3,6]:[0,upper?4:3,7];
 if(suffix==='7')intervals.push(10);
 return {numeral,root,intervals};
}

/** One entry per bar: section, key and chord (with absolute pitch classes). */
export function buildTimeline(brief){
 const rhythm=brief.harmonicRhythmBars??1,keys=new Map(brief.keys.map(k=>[k.section,k])),bars=[];
 let bar=0;
 for(const [formIndex,form] of brief.form.entries()){
  const key=keys.get(form.section),tonic=tonicMidi(key.root),progression=brief.harmony[form.section];
  for(let i=0;i<form.bars;i++,bar++){
   const chord=parseChord(progression[Math.floor(i/rhythm)%progression.length],key.mode);
   bars.push({bar,section:form.section,formIndex,barInSection:i,sectionBars:form.bars,tonic,mode:key.mode,chord,
    pcs:chord.intervals.map(x=>(((tonic+chord.root+x)%12)+12)%12),rootPc:((tonic+chord.root)%12+12)%12});
  }
 }
 return bars;
}

/**
 * The voicing of `pcs` nearest to `previous`, inside [low, high]. Chooses inversions so
 * voices move as little as possible, which is what makes comping sound connected.
 */
export function voiceLead(previous,pcs,size,[low,high]){
 const tones=pcs.length>size?(size===2?[pcs[1],pcs[pcs.length-1]]:[pcs[0],pcs[1],pcs[pcs.length-1]]):pcs.slice(0,size);
 const options=tones.map(pc=>{const out=[];for(let p=low;p<=high;p++)if(((p%12)+12)%12===pc)out.push(p);return out});
 if(options.some(o=>!o.length))throw new Error(`register ${low}-${high} cannot hold pitch classes ${tones}`);
 let combos=[[]];
 for(const o of options)combos=combos.flatMap(c=>o.map(p=>[...c,p]));
 const center=(low+high)/2;
 const spread=c=>Math.max(...c)-Math.min(...c);
 const usable=combos.filter(c=>new Set(c).size===c.length&&spread(c)<=14);
 const cost=c=>{
  const sorted=[...c].sort((a,b)=>a-b);
  if(!previous)return Math.abs(sorted[Math.floor(sorted.length/2)]-center);
  const before=[...previous].sort((a,b)=>a-b);
  return sorted.reduce((s,p,i)=>s+Math.abs(p-before[Math.min(i,before.length-1)]),0)+Math.abs(sorted[0]-center)*.01;
 };
 const best=(usable.length?usable:combos).map(c=>({c:[...c].sort((a,b)=>a-b),v:cost(c)}))
  .sort((a,b)=>a.v-b.v||a.c.join().localeCompare(b.c.join()))[0];
 return best.c;
}

export const bassPitch=pc=>{let p=36+pc;if(p>43)p-=12;return p};

const FIFTH_PATTERNS=[
 [[0,'root',.8],[2,'fifth',.7]],
 [[0,'root',1.4],[2,'fifth',.5],[3,'root',.4]],
 [[0,'root',.6],[1.5,'root',.3],[2,'fifth',.7]],
 [[0,'root',.8],[2.5,'fifth',.4],[3,'third',.5]],
];
/** The always-present bass: root on the downbeat, the chord's fifth or third around it. */
export function bassRootFifth(entry,rng){
 const root=bassPitch(entry.rootPc),fifth=root+(entry.chord.intervals[2]),third=root+entry.chord.intervals[1];
 const bar=entry.bar*4,pattern=entry.barInSection===0?FIFTH_PATTERNS[0]:pick(rng,FIFTH_PATTERNS);
 return pattern.map(([x,tone,duration])=>({beat:bar+x,pitch:tone==='root'?root:tone==='fifth'?fifth-12:third,duration}));
}
/** Passing notes between chords: the last note steps into the next bar's root. */
export function bassWalking(entry,next,rng){
 const root=bassPitch(entry.rootPc),target=next?bassPitch(next.rootPc):root,bar=entry.bar*4;
 const mid=root+pick(rng,[entry.chord.intervals[1],12,entry.chord.intervals[2]-12]);
 const approach=target>root?target-pick(rng,[1,2]):target+pick(rng,[1,2]);
 return [{beat:bar+1.5,pitch:mid,duration:.3},{beat:bar+3.5,pitch:approach,duration:.3}];
}
export const bassPedal=entry=>[{beat:entry.bar*4,pitch:bassPitch(entry.rootPc),duration:3.9}];

const COMP_RHYTHMS={
 'offbeat-dyads':[[.5,2.5],[.5,2.5],[.5,1.5,3.5],[.5,2.75]],
 'offbeat-triads':[[.5,1.5,2.5,3.5],[.5,1.5,2.5,3.5],[.5,1.5,2.75,3.5],[.5,2,2.5,3.5],[.5,1.25,2.5,3.25]],
};
/** Voice-led comping across the timeline; each chord is the nearest inversion to the last. */
export function comp(timeline,style,register,rng){
 const size=style==='offbeat-dyads'?2:3,out=[];let previous=null;
 for(const entry of timeline){
  const voiced=voiceLead(previous,entry.pcs,size,register);previous=voiced;
  if(style==='arpeggio'){
   const order=pick(rng,[[0,1,2,1],[2,1,0,1],[0,2,1,2]]);
   order.forEach((v,i)=>out.push({beat:entry.bar*4+.5+i,pitch:voiced[v%voiced.length],duration:.3}));
   continue;
  }
  const rhythm=entry.barInSection%4===3?COMP_RHYTHMS[style].at(-1):pick(rng,COMP_RHYTHMS[style]);
  for(const x of rhythm)for(const pitch of voiced)out.push({beat:entry.bar*4+x,pitch,duration:.24});
 }
 return out;
}
/** Sustained chords for a pad part. */
export function pad(timeline,register){
 const out=[];let previous=null;
 for(const entry of timeline){
  const voiced=voiceLead(previous,entry.pcs,3,register);previous=voiced;
  for(const pitch of voiced)out.push({beat:entry.bar*4,pitch,duration:3.9});
 }
 return out;
}
