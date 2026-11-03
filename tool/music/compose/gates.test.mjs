// node --test tool/music/compose/
import test from 'node:test';
import assert from 'node:assert/strict';
import {evaluate} from './gates.mjs';

const TRACKS=['pulse','bass','guitar','lead','answer','brass'].map((id,channel)=>({id,channel,program:0,voice:id}));
const base={id:'fixture',beatsPerBar:4,bars:16,phraseBars:2,tracks:TRACKS,sections:[{bar:0,bars:8,name:'A'},{bar:8,bars:8,name:'B'}]};
const note=(track,beat,pitch,duration=.5,velocity=70,minTier=0,maxTier=4)=>({track,beat,pitch,duration,velocity,minTier,maxTier});

// One bar's pattern, transposed through the piece, in every pitched voice.
function transposedRepeat(){
 const events=[];
 for(let bar=0;bar<16;bar++){
  const b=bar*4,t=[0,5,7,3][bar%4];
  events.push(note('pulse',b,36));
  for(const [x,i] of [[0,0],[1,4],[2,7],[3,4]])events.push(note('lead',b+x,60+t+i,.5,70,3));
  events.push(note('bass',b,36+t),note('bass',b+2,43+t));
  for(const x of [.5,1.5,2.5,3.5])events.push(note('guitar',b+x,60+t,.25,50,1));
  events.push(note('answer',b+2,72+t,.5,50,2),note('answer',b+3,76+t,.5,50,2));
  events.push(note('brass',b,72+t,1,50,4));
 }
 return {...base,events};
}
// Seeded variety, with each tier adding structure.
function varied(){
 let seed=99;const rnd=n=>{seed=(seed*1664525+1013904223)>>>0;return seed%n};
 const events=[];const scale=[0,2,3,5,7,8,10];const grid=[0,.5,.75,1,1.5,2,2.25,2.5,3,3.5];
 const roots=[0,5,8,7,0,3,10,7,5,8,3,7,0,10,5,7];
 for(let bar=0;bar<16;bar++){
  const b=bar*4,root=roots[bar];
  events.push(note('pulse',b,36),note('pulse',b+2,36));
  for(let i=0;i<4;i++)events.push(note('pulse',b+i+.5,73,.1,40,1));
  events.push(note('bass',b,36+root),note('bass',b+1.25+rnd(3)*.5,43+rnd(5)),note('bass',b+3.5,36+rnd(12),.25,60,1));
  for(let i=0;i<3;i++)events.push(note('guitar',b+[.5,1.25,2.75,3.25][rnd(4)]+i*.01,60+scale[rnd(7)],.25,50,2));
  const count=4+rnd(3);const at=new Set();while(at.size<count)at.add(grid[rnd(grid.length)]);
  for(const x of at)events.push(note('lead',b+x,60+scale[rnd(7)]+(rnd(2)?12:0),.25,70,3));
  for(let i=0;i<3;i++)events.push(note('lead',b+.25+i,67+scale[rnd(7)],.2,50,0,2));
  const answerAt=[.25,1.75,2.25,3.25,3.75];const n=2+rnd(3);
  for(let i=0;i<n;i++)events.push(note('answer',b+answerAt[(i+rnd(5))%5]+i*.002,72+scale[rnd(7)],.2,50,2));
  events.push(note('brass',b+rnd(4)+.75*rnd(2),72+scale[rnd(7)],.5,50,4));
 }
 events.sort((a,b)=>a.beat-b.beat);
 return {...base,events};
}

test('a transposed-repeat score fails and names the repeated material',()=>{
 const result=evaluate(transposedRepeat());
 assert.equal(result.passed,false);
 const repetition=result.failures.find(f=>f.gate==='repetition');
 assert.ok(repetition,'repetition gate fires');
 assert.match(repetition.message,/(bass|guitar|lead|answer|brass): one pattern .* fills \d+ bars/);
 assert.ok(result.metrics.barRepeat>.9,`barRepeat ${result.metrics.barRepeat}`);
});

test('a tier that is only louder fails louder-not-richer',()=>{
 const events=varied().events;
 // Tier 4 replays tier 3's notes at higher velocity and adds nothing.
 const tier3=events.filter(n=>n.minTier<=3&&n.maxTier>=3);
 const score={...base,events:[...events.filter(n=>!(n.minTier<=3&&n.maxTier>=3)),
  ...tier3.map(n=>({...n,maxTier:3,minTier:Math.min(n.minTier,3)})),
  ...tier3.map(n=>({...n,minTier:4,maxTier:4,velocity:Math.min(127,n.velocity+30)}))].sort((a,b)=>a.beat-b.beat)};
 const result=evaluate(score);
 assert.ok(result.failures.some(f=>f.gate==='louder-not-richer'),JSON.stringify(result.failures));
});

test('a varied score that builds passes every gate',()=>{
 const result=evaluate(varied());
 assert.deepEqual(result.failures,[]);
 assert.equal(result.passed,true);
});

test('static harmony fails the harmony gate',()=>{
 const score=varied();
 score.events=score.events.map(n=>n.track==='bass'?{...n,pitch:36}:n);
 assert.ok(evaluate(score).failures.some(f=>f.gate==='harmony'));
});

test('tiers without added notes fail the build gate',()=>{
 const score=varied();
 score.events=score.events.map(n=>({...n,minTier:0,maxTier:4}));
 assert.ok(evaluate(score).failures.some(f=>f.gate==='build'));
});
