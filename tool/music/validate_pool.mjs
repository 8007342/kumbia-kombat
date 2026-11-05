#!/usr/bin/env node
// Checks the pool lawn's music and chart without Flutter. It cannot tell whether
// any of this sounds good or plays well on a phone: nobody here can listen.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const json=path=>JSON.parse(readFileSync(resolve(root,path)));
const score=id=>json(`assets/music/scores/${id}.json`);
const LADDER=[128,136,144,152,160];
const SAME_LIMB_MS=400, GOOD_MS=180, PEAK_RATIO=.875;
const fraction=bpm=>{const r=Math.max(1,3.5+(1-3.5)*(bpm-100)/200);return r/(1+r)};
const heardAt=(s,t)=>s.events.filter(e=>e.minTier<=t&&t<=e.maxTier);
const within=b=>b-Math.floor(b);

function bounds(s){
 assert.equal(s.schemaVersion,1);assert.equal(s.tiers.length,5,`${s.id}: exactly five tiers`);
 assert.equal(s.beatsPerBar,4);assert.equal(s.ppq,480);assert.equal(s.bars%s.phraseBars,0);
 assert.ok(s.tiers.every(t=>Number.isFinite(t.bpm)&&t.bpm>0));
 const length=s.bars*4;let previous=-1;
 for(const e of s.events){
  assert.ok(e.beat>=previous,`${s.id}: sorted`);previous=e.beat;
  assert.ok(e.beat>=0&&e.duration>0&&e.beat+e.duration<=length,`${s.id}: note in form at ${e.beat}`);
  assert.ok(Number.isInteger(e.pitch)&&e.pitch>=0&&e.pitch<=127);
  assert.ok(Number.isInteger(e.velocity)&&e.velocity>=1&&e.velocity<=127);
  assert.ok(Number.isInteger(e.minTier)&&e.minTier>=0&&e.minTier<=e.maxTier&&e.maxTier<=4);
  assert.ok(s.tracks.some(t=>t.id===e.track));
  assert.ok(Number.isInteger(Math.round(e.beat*480*1e6)/1e6),`${s.id}: onset on a tick`);
  // web_audio_backend: pulse pitch below 54 other than 36 and 38 is a zero or negative frequency.
  if(e.track==='pulse')assert.ok([36,38,73,75].includes(e.pitch)||e.pitch>=60,`${s.id}: drum pitch ${e.pitch} has no usable voice`);
 }
 for(let t=0;t<5;t++){
  const seen=new Set();
  for(const e of heardAt(s,t)){const key=`${e.track}:${e.beat}:${e.pitch}`;assert.ok(!seen.has(key),`${s.id}: doubled note ${key} at tier ${t}`);seen.add(key)}
 }
}
// What the runtime synth would do with these notes, from web_audio_backend.dart.
function load(s,t,bpm){
 const notes=heardAt(s,t).map(e=>{
  const noisy=e.track==='pulse'&&[38,73,75].includes(e.pitch);
  let seconds=Math.max(.025,e.duration*60/bpm);if(noisy)seconds=Math.min(seconds,.13);
  let gain=e.velocity/127*.18;
  if(noisy)gain*=e.pitch===73?.45:.7;
  if(e.track==='bass')gain*=1.3;
  if(e.track==='guitar'||e.track==='brass')gain*=.65;
  return {at:e.beat*60/bpm,seconds,gain};
 }).sort((a,b)=>a.at-b.at);
 let maxVoices=0,maxSum=0,first=0;
 for(const now of notes){
  while(notes[first].at+notes[first].seconds+.04<=now.at)first++;
  let voices=0,sum=0;
  for(let i=first;i<notes.length&&notes[i].at<=now.at;i++){
   const n=notes[i], age=now.at-n.at;
   if(age>=n.seconds+.04)continue;
   voices++;
   // The envelope falls to 35% across the note, then to silence in 40 ms.
   sum+=age<n.seconds?n.gain*Math.pow(.35,age/n.seconds):n.gain*.35*Math.pow(.0001/(n.gain*.35),(age-n.seconds)/.04);
  }
  maxVoices=Math.max(maxVoices,voices);maxSum=Math.max(maxSum,sum);
 }
 return {voices:maxVoices,gain:maxSum*.32};
}

// ---- room score
const pool=score('pool_swing');bounds(pool);
assert.deepEqual(pool.tiers.map(t=>t.bpm),LADDER);
assert.equal(pool.bars,32);assert.equal(pool.phraseBars,2);
assert.ok(pool.events.every(e=>e.beat+e.duration<=128));
assert.equal(pool.adornments.length,4);
const rows=[];let previousCount=0;
for(let t=0;t<5;t++){
 const heard=heardAt(pool,t), bpm=LADDER[t], off=Math.round(fraction(bpm)*480)/480;
 assert.ok(heard.length>previousCount,'every tier adds notes');previousCount=heard.length;
 for(let bar=0;bar<32;bar++){
  const b=bar*4;
  const ride=heard.filter(e=>e.track==='pulse'&&e.pitch===73&&e.beat>=b&&e.beat<b+4).map(e=>Math.round((e.beat-b)*480));
  assert.deepEqual(ride,[0,1,1+off,2,3,3+off].map(x=>Math.round(x*480)),`ride pattern, bar ${bar}, tier ${t}`);
  const walk=heard.filter(e=>e.track==='bass'&&e.beat>=b&&e.beat<b+4&&within(e.beat)===0).map(e=>e.beat-b);
  assert.deepEqual(walk,[0,1,2,3],`walking bass, bar ${bar}, tier ${t}`);
 }
 const pitches=heard.filter(e=>e.track==='bass').map(e=>e.pitch);
 assert.ok(Math.min(...pitches)>=36&&Math.max(...pitches)<=60,`bass range ${Math.min(...pitches)}-${Math.max(...pitches)}`);
 for(const e of heard)if(within(e.beat)===.5)assert.fail(`straight offbeat at ${e.beat}, tier ${t}`);
 const l=load(pool,t,bpm);assert.ok(l.voices<96,'below the synth voice limit');
 rows.push({tier:t,bpm,notes:heard.length,brass:heard.filter(e=>e.track==='brass').length,offbeat:off.toFixed(3),ratio:(off/(1-off)).toFixed(2),voices:l.voices,peakGain:l.gain.toFixed(2)});
}
const brass=rows.map(r=>r.brass);assert.ok(brass.every((n,i)=>i===0||n>brass[i-1]),'brass builds by tier');assert.equal(brass[0],0);
assert.ok(rows.every((r,i)=>i===0||Number(r.offbeat)<Number(rows[i-1].offbeat)),'swing flattens as tempo rises');
console.log('pool_swing');console.table(rows);
const reference=[];
for(const [id,t,bpm] of [['garden_mojo',4,104],['bar_swag',4,112],['vip_presence',4,124]]){const l=load(score(id),t,bpm);reference.push({score:id,tier:t,bpm,voices:l.voices,peakGain:l.gain.toFixed(2)})}
console.log('For comparison, existing scores at their top tier');console.table(reference);
const topGain=Math.max(...rows.map(r=>Number(r.peakGain))),refGain=Math.max(...reference.map(r=>Number(r.peakGain)));
assert.ok(topGain<=refGain*1.1,`peak gain ${topGain} against existing ${refGain}`);

// ---- transitions
const success=score('pool_swing_success');bounds(success);
assert.equal(success.bars,2);assert.equal(success.kind,'success');assert.equal(success.parentScore,'pool_swing');
assert.deepEqual(success.tiers.map(t=>t.bpm),LADDER);
assert.ok(success.events.every(e=>e.minTier===0&&e.maxTier===4&&e.beat+e.duration<=8));
const garden=score('garden_mojo_success');
assert.deepEqual(Object.keys(garden).filter(k=>!Object.keys(success).includes(k)),[],'same fields as garden_mojo_success');
const bridge=score('bar_to_pool');bounds(bridge);
assert.equal(bridge.bars,2);assert.equal(bridge.kind,'bridge');assert.equal(bridge.fromScore,'bar_swag');assert.equal(bridge.toScore,'pool_swing');
assert.ok(bridge.tiers.every(t=>t.bpm===LADDER[0]),'bridge takes the base tempo, as garden_to_bar does');
assert.ok(bridge.events.filter(e=>e.beat<4).every(e=>e.track==='pulse'),'first bar is percussion');
assert.ok(bridge.events.filter(e=>e.beat<4).every(e=>Number.isInteger(e.beat*4)),'first bar is straight');
assert.ok(bridge.events.every(e=>e.minTier===0&&e.maxTier===4&&e.beat+e.duration<=8));
assert.deepEqual(Object.keys(score('garden_to_bar')).filter(k=>!Object.keys(bridge).includes(k)),[],'same fields as garden_to_bar');
assert.equal(bridge.events.find(e=>e.track==='bass').pitch%12,0,'bass starts on C, the bar\'s tonic');
const lastBass=bridge.events.filter(e=>e.track==='bass').at(-1).pitch;
assert.equal(lastBass%12,10,'bass ends on B-flat, the dominant of E-flat');
const manifest=json('assets/music/manifest.json');
assert.ok(manifest.scores.some(s=>s.id==='pool_swing'));
assert.ok(manifest.transitions.successes.some(s=>s.id==='pool_swing_success'&&s.parentScore==='pool_swing'));
assert.ok(manifest.transitions.bridges.some(s=>s.id==='bar_to_pool'&&s.fromScore==='bar_swag'&&s.toScore==='pool_swing'));
const barLevel=json('levels/bar.json');
assert.ok(manifest.transitions.successes.some(s=>s.id===barLevel.music.successScore),'the bar already has its success score');
console.log('Transitions: pool_swing_success at',success.tiers[4].bpm,'BPM; bar_to_pool at',bridge.tiers[0].bpm,'BPM, entered from',barLevel.music.successScore,'at',score('bar_swag').tiers[4].bpm,'BPM');

// ---- level file: the fields lib/gameplay/level_definition.dart reads, and no others
const level=json('levels/pool-garden.json');
assert.deepEqual(Object.keys(level).sort(),['background','chart','copy','crowd','departure','id','music','rules','scenery','stage','title'].sort());
assert.deepEqual(Object.keys(level.chart).sort(),['callBeats','flourishDestination','introBeats','limbs','offsets','variants']);
assert.deepEqual(Object.keys(level.music).sort(),['leadShape','score','successScore']);
assert.deepEqual(Object.keys(level.rules).sort(),['cleanSeconds','earlyHitRatio','finalChallenges','metric','resetAfterFailures','successesPerTier']);
assert.deepEqual(Object.keys(level.copy).sort(),['clearedClaim','clearedTitle','invitation','resetLine']);
assert.ok(['sine','square','sawtooth','triangle'].includes(level.music.leadShape));
assert.equal(level.music.score,'pool_swing');assert.equal(level.music.successScore,'pool_swing_success');
assert.equal(level.title,'THE POOL LAWN');assert.ok(['Sabor','Grace'].includes(level.rules.metric));
assert.ok(!JSON.stringify(json('levels/index.json')).includes('pool-garden'),'still out of the campaign');
const chart=level.chart, LIMBS=['leftHand','rightHand','leftFoot','rightFoot'];
assert.equal(chart.callBeats,8);
assert.equal(chart.offsets.length,chart.limbs.length);
assert.ok(LIMBS.includes(chart.flourishDestination));
assert.ok(chart.offsets.every((o,i)=>o>=0&&o<8&&(i===0||o>chart.offsets[i-1])));
assert.ok(chart.variants.every(v=>v.length===chart.limbs.length&&v.every(l=>LIMBS.includes(l))));
assert.notDeepEqual(chart.offsets,json('levels/garden.json').chart.offsets);
assert.notDeepEqual(chart.offsets,barLevel.chart.offsets);

// ---- chart at every tier, as limbsFor in lib/gameplay/garden_session.dart picks patterns
const patterns=[];
for(let t=0;t<4;t++)patterns.push({tier:t,limbs:t===0?chart.limbs:chart.variants[t-1]});
for(let peak=0;peak<level.rules.finalChallenges;peak++)patterns.push({tier:4,limbs:chart.variants[(3+peak)%chart.variants.length]});
const side=l=>l.startsWith('left')?'left':'right';
const chartRows=[];
for(const {tier,limbs} of patterns){
 const beatMs=60000/LADDER[tier];
 let sameLimb=Infinity,sameThumb=Infinity,any=Infinity;
 for(let i=0;i<limbs.length;i++)for(let j=i+1;j<limbs.length;j++){
  const ms=(chart.offsets[j]-chart.offsets[i])*beatMs;
  any=Math.min(any,ms);
  if(limbs[i]===limbs[j])sameLimb=Math.min(sameLimb,ms);
  if(side(limbs[i])===side(limbs[j]))sameThumb=Math.min(sameThumb,ms);
 }
 assert.ok(sameLimb>=SAME_LIMB_MS,`same limb ${sameLimb} ms at tier ${tier}`);
 assert.ok(sameLimb>2*GOOD_MS,'same-limb good windows never touch');
 assert.ok(sameThumb>=beatMs-1e-6,`same thumb inside one beat at tier ${tier}`);
 const pairs=new Set(limbs.slice(1).map((l,i)=>limbs[i]+'>'+l));
 chartRows.push({tier,bpm:LADDER[tier],limbsUsed:new Set(limbs).size,limbChanges:pairs.size,minSameLimbMs:Math.round(sameLimb),minSameThumbMs:Math.round(sameThumb),minAnyMs:Math.round(any),tapsPerSec:(limbs.length/(8*beatMs/1000)).toFixed(2),cueLeadMs:Math.round(2*beatMs)});
}
console.log('Chart',JSON.stringify(chart.offsets));console.table(chartRows);
const tierChanges=t=>Math.max(...chartRows.filter(r=>r.tier===t).map(r=>r.limbChanges));
assert.ok(tierChanges(2)>tierChanges(0)&&tierChanges(2)>tierChanges(1)&&tierChanges(2)>tierChanges(3)&&tierChanges(2)>tierChanges(4),'limb load peaks at the middle tier');
// Swung chart notes against the music they sit on.
for(let t=0;t<5;t++){
 const beatMs=60000/LADDER[t];
 for(const o of chart.offsets.filter(o=>within(o)!==0)){
  const music=Math.floor(o)+fraction(LADDER[t]);
  const ms=Math.abs(o-music)*beatMs;
  assert.ok(ms<=20,`chart offbeat ${o} is ${ms} ms from the music at tier ${t}`);
 }
}
// A swung offbeat must not crowd the note after it.
const gaps=chart.offsets.slice(1).map((o,i)=>o-chart.offsets[i]);
assert.ok(Math.min(...gaps)>=.75,'at least three quarters of a beat between taps');
// The peak's hard-coded ratio in lib/gameplay/progression.dart still allows one miss.
assert.equal(Math.ceil(chart.offsets.length*PEAK_RATIO),chart.offsets.length-1,'peak allows one dropped note');
// A tier request must land on the phrase boundary after the next call begins, not
// at a response. Game lookahead is .3 s (garden_page.dart); boundaries are every 8 beats.
for(const bpm of LADDER){
 const lastMs=chart.offsets.at(-1)+(GOOD_MS+300)/(60000/bpm);
 const start=chart.introBeats, resolved=start+8+lastMs;
 const boundary=(Math.floor(resolved/8)+1)*8;
 const nextCall=start+16;
 assert.ok(boundary>nextCall&&boundary<nextCall+8,`tier change at ${bpm} BPM lands at call offset ${boundary-nextCall}`);
}
console.log('Tier changes land 4 beats into the next call at every tempo (intro',chart.introBeats,'beats, phrase boundaries every 8).');

// The per-tier rhythm in plan/levels/pool-garden.md, which the chart format cannot
// hold yet: one offset list serves all tiers. Taps per second must peak at tier 2.
const proposed=[[0,1.75,3,4,5.75],[0,1,1.75,3,4,5.75],chart.offsets,[0,1,1.75,3,4,5.75,6.75],[0,1.75,3,4,5.75,6.75]];
const proposedRates=proposed.map((o,t)=>o.length/(8*60/LADDER[t]));
assert.ok(proposedRates.every((r,t)=>t===2||r<proposedRates[2]),'proposed density peaks at tier 2');
assert.ok(proposedRates[4]<proposedRates[3],'proposed fastest tier is sparser');
console.log('Proposed per-tier taps/s, not playable yet:',proposedRates.map(r=>r.toFixed(2)).join(', '));

// ---- marks
const {stage}=level;
const [a,b]=stage.challengers;
assert.deepEqual([a.id,b.id,a.atlas,b.atlas],['swing-a','swing-b','swing-a','swing-b']);
assert.equal(stage.challengers.length,2);
const height=y=>level.stage.floor.referenceHeight*(y-level.stage.floor.horizonY)/(level.stage.floor.referenceFootY-level.stage.floor.horizonY);
const halfWidth=y=>height(y)*.25;
const heroTop=stage.heroHome[1]-.05;
for(const m of [a.mark,b.mark,a.yieldMark,b.yieldMark]){
 assert.ok(m[1]>=.42&&m[1]<=.58,`foot y ${m[1]} in 0.42-0.58`);
 assert.ok(m[0]-halfWidth(m[1])>=.153&&m[0]+halfWidth(m[1])<=.847,'inside what a phone shows');
 assert.ok(m[1]<heroTop,'feet stay above Macron\'s head');
}
const apart=(p,q)=>Math.abs(p[0]-q[0])>=halfWidth(p[1])+halfWidth(q[1]);
assert.ok(apart(a.mark,b.mark)&&apart(a.yieldMark,b.yieldMark),'the two dancers do not stand in each other');
const route=level.departure.waypoints.map(w=>[w.x,w.y]);
const routeXAt=y=>{for(let i=1;i<route.length;i++){const [x0,y0]=route[i-1],[x1,y1]=route[i];if(y<=y0&&y>=y1)return x0+(x1-x0)*(y0-y)/(y0-y1)}return null};
for(const m of [a.yieldMark,b.yieldMark]){const x=routeXAt(m[1]);assert.ok(Math.abs(m[0]-x)>=halfWidth(m[1])+.03,`yield mark ${m} clears the route at x ${x}`)}
console.log('Marks clear of Macron, the phone crop, each other and the exit route.');

// ---- untouched scores
const changed=execFileSync('git',['status','--short','--','assets/music/scores','assets/music/midi'],{cwd:root,encoding:'utf8'}).split('\n').filter(line=>line.startsWith(' M')||line.startsWith('M '));
assert.deepEqual(changed,[],'no existing score or MIDI file differs from git');
console.log('PASS: pool lawn music and chart. Not tested: how any of it sounds, or how it plays on a phone.');
