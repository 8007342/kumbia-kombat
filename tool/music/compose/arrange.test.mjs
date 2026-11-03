import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,rmSync,mkdirSync,writeFileSync,cpSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {tmpdir} from 'node:os';
import {mkdtempSync} from 'node:fs';
import {MODES,makeRng,parseChord,buildTimeline,voiceLead,bassRootFifth,bassWalking,bassTumbao,bassPitch,comp} from './harmony.mjs';
import {applyOp,ops,fitToHarmony,counterLine,fills,shiftDiatonic} from './motif.mjs';
import {arrange,composeSuccess} from './arrange.mjs';
import {midi} from './midi.mjs';
import {evaluate} from './gates.mjs';
import {measure,checkBudget} from './budget.mjs';
import {buildCandidate} from './build_candidate.mjs';

const here=dirname(fileURLToPath(import.meta.url)),briefs=resolve(here,'../briefs');
const loadBrief=()=>JSON.parse(readFileSync(resolve(briefs,'bar_swag.json')));
const loadMotif=p=>JSON.parse(readFileSync(resolve(briefs,p)));
const motifsOf=brief=>Object.fromEntries(Object.entries(brief.motifs).map(([k,p])=>[k,loadMotif(p)]));
const pc=n=>((n%12)+12)%12;

// 2.1 harmony, bass, voice-led accompaniment
test('numerals resolve in their mode',()=>{
 assert.deepEqual(parseChord('i','minor').intervals,[0,3,7]);
 assert.equal(parseChord('VI','minor').root,8);
 assert.equal(parseChord('IV','major').root,5);
 assert.deepEqual(parseChord('V7','minor').intervals,[0,4,7,10]);
 assert.equal(parseChord('bVII','major').root,10);
 assert.deepEqual(parseChord('viio','major').intervals,[0,3,6]);
 assert.throws(()=>parseChord('Q','major'),/"Q"/);
});

test('voice leading moves less than root-position chords and stays in register',()=>{
 const brief=loadBrief(),timeline=buildTimeline(brief),register=[55,79];
 let previous=null,led=0,block=0,lastBlock=null;
 for(const entry of timeline){
  const voiced=voiceLead(previous,entry.pcs,3,register);
  assert.ok(voiced.every(p=>p>=55&&p<=79));
  assert.deepEqual(new Set(voiced.map(pc)),new Set(entry.pcs.slice(0,3).concat(entry.pcs.length>3?[entry.pcs.at(-1)]:[]).filter(x=>voiced.map(pc).includes(x))));
  const root=60+pc(entry.rootPc-60),blocked=entry.chord.intervals.slice(0,3).map(i=>root+i);
  if(previous){
   led+=voiced.reduce((s,p,i)=>s+Math.abs(p-previous[i]),0);
   block+=blocked.reduce((s,p,i)=>s+Math.abs(p-lastBlock[i]),0);
  }
  previous=voiced;lastBlock=blocked;
 }
 assert.ok(led<block*.75,`voice-led motion ${led} vs block-chord motion ${block}`);
});

test('the bass plays the chord root on every downbeat and walks into the next chord',()=>{
 const brief=loadBrief(),timeline=buildTimeline(brief),rng=makeRng(1,'bass');
 timeline.forEach((entry,i)=>{
  const notes=bassRootFifth(entry,rng),down=notes.find(n=>n.beat===entry.bar*4);
  assert.equal(pc(down.pitch),entry.rootPc,`bar ${i}`);
  const next=timeline[(i+1)%timeline.length],walk=bassWalking(entry,next,rng);
  const last=walk.at(-1);
  assert.ok(Math.abs(last.pitch-bassPitch(next.rootPc))<=2,`bar ${i} approach ${last.pitch} to ${bassPitch(next.rootPc)}`);
  assert.equal(last.beat,entry.bar*4+3.5);
 });
});

test('comping uses only chord tones and stays inside each bar',()=>{
 const timeline=buildTimeline(loadBrief());
 for(const style of ['offbeat-dyads','offbeat-triads','arpeggio','montuno','arp16']){
  for(const n of comp(timeline,style,[55,79],makeRng(5,style))){
   const entry=timeline[Math.floor(n.beat/4)];
   assert.ok(entry.pcs.includes(pc(n.pitch)),`${style} beat ${n.beat}`);
   assert.ok(n.beat+n.duration<=(entry.bar+1)*4);
  }
 }
});

test('the same brief and seed give byte-identical score JSON and MIDI, and another seed differs',()=>{
 const brief=loadBrief(),m=motifsOf(brief);
 const first=arrange(brief,m),second=arrange(loadBrief(),motifsOf(loadBrief()));
 assert.equal(JSON.stringify(first),JSON.stringify(second));
 for(let tier=0;tier<5;tier++)assert.ok(midi(first,tier).equals(midi(second,tier)));
 assert.equal(JSON.stringify(composeSuccess(brief,m)),JSON.stringify(composeSuccess(loadBrief(),m)));
 assert.notEqual(JSON.stringify(arrange({...loadBrief(),seed:7},m).events),JSON.stringify(first.events));
});

test('building a candidate twice gives identical bytes on disk',()=>{
 const dir=mkdtempSync(resolve(tmpdir(),'candidate-'));
 const brief=resolve(briefs,'bar_swag.json');
 const read=d=>readFileSync(resolve(d,'assets/music/scores/bar_swag.json'));
 buildCandidate(brief,resolve(dir,'a'));buildCandidate(brief,resolve(dir,'b'));
 assert.ok(read(resolve(dir,'a')).equals(read(resolve(dir,'b'))));
 assert.ok(readFileSync(resolve(dir,'a/assets/music/midi/bar_swag_tier4.mid')).equals(readFileSync(resolve(dir,'b/assets/music/midi/bar_swag_tier4.mid'))));
 rmSync(dir,{recursive:true,force:true});
});

// 2.2 motif operations, counter-melody, fills, seams
const MOTIF=[[0,0,.5],[1,3,.5],[2,7,1],[4,5,.5],[5,3,.5],[6,2,.5],[7,0,.5]];
const CONTEXT={scale:MODES.minor,beats:8};
test('every motif operation stays inside its phrase and is pure',()=>{
 const before=JSON.stringify(MOTIF);
 for(const name of Object.keys(ops)){
  const out=applyOp(name,MOTIF,CONTEXT);
  assert.ok(out.length>0,name);
  for(const [beat,,duration] of out)assert.ok(beat>=0&&beat+duration<=8.0001,`${name} ${beat}+${duration}`);
  for(let i=1;i<out.length;i++)assert.ok(out[i][0]>=out[i-1][0],`${name} order`);
 }
 assert.equal(JSON.stringify(MOTIF),before);
});
test('operations do what they say',()=>{
 const seq=applyOp('sequence',MOTIF,CONTEXT);
 assert.equal(seq[0][1],3,'two scale steps above the tonic in minor');
 assert.deepEqual(seq.map(n=>n[0]),MOTIF.map(n=>n[0]),'rhythm kept');
 assert.deepEqual(applyOp('answer',MOTIF,CONTEXT).map(n=>n[1]),MOTIF.map(n=>n[1]).reverse());
 assert.equal(applyOp('displace',MOTIF,CONTEXT)[0][0],.5);
 const inverted=applyOp('invert',MOTIF,CONTEXT);
 assert.equal(inverted[0][1],0);assert.ok(inverted[1][1]<0,'contour mirrored');
 assert.equal(pc(applyOp('cadence',MOTIF,CONTEXT).at(-1)[1]),0,'ends on the tonic');
 assert.equal(shiftDiatonic(0,7,MODES.minor),12);
 assert.throws(()=>applyOp('nope',MOTIF,CONTEXT),/"nope"/);
});
test('fitted melodies use chord tones on strong beats, the key elsewhere, and stay in register',()=>{
 const timeline=buildTimeline(loadBrief());
 const fitted=fitToHarmony(MOTIF,{tonic:60,mode:'minor',start:0,chordAt:b=>timeline[Math.floor(b/4)],register:[60,84]});
 fitted.forEach((n,i)=>{
  assert.ok(n.pitch>=60&&n.pitch<=84);
  const beat=MOTIF[i][0],entry=timeline[Math.floor(n.beat/4)];
  if(beat%2===0)assert.ok(entry.pcs.includes(pc(n.pitch)),`strong beat ${beat}`);
  else assert.ok(MODES.minor.includes(pc(n.pitch-60))||entry.pcs.includes(pc(n.pitch)),`beat ${beat}`);
 });
});
test('the counter-line avoids parallel fifths and octaves, and mostly moves against the melody',()=>{
 const brief=loadBrief(),score=arrange(brief,motifsOf(brief));
 const lead=score.events.filter(e=>e.track==='lead'&&e.minTier===3);
 const timeline=buildTimeline(brief);
 const line=counterLine(lead,timeline,[67,91],makeRng(3,'c'));
 const soundingAt=b=>{const h=lead.filter(n=>n.beat<=b&&n.beat+Math.max(n.duration,.25)>b);return h.length?h.at(-1).pitch:lead.filter(n=>n.beat<=b).at(-1)?.pitch??null};
 let parallel=0,contrary=0,moved=0;
 for(let i=1;i<line.length;i++){
  const a=soundingAt(line[i-1].beat),b=soundingAt(line[i].beat);
  if(a===null||b===null||a===b)continue;
  const up=line[i].pitch-line[i-1].pitch,down=b-a;moved++;
  if(up*down<0)contrary++;
  const was=pc(line[i-1].pitch-a),now=pc(line[i].pitch-b);
  if(up*down>0&&was===now&&(now===0||now===7))parallel++;
 }
 assert.equal(parallel,0);
 assert.ok(contrary/moved>.5,`contrary motion ${contrary}/${moved}`);
 const leadOn=new Set(lead.map(n=>n.beat));
 assert.ok(line.every(n=>!leadOn.has(n.beat)),'counter-line fills the gaps between melody attacks');
});
test('fills sit on phrase-ending bars and finish inside them',()=>{
 const timeline=buildTimeline(loadBrief());
 const out=fills(timeline,makeRng(9,'f'));
 assert.ok(out.length);
 for(const n of out){
  const entry=timeline[Math.floor(n.beat/4)];
  assert.ok(entry.barInSection%4===3||entry.barInSection===entry.sectionBars-1,`bar ${entry.bar}`);
  assert.ok(n.beat+n.duration<=(entry.bar+1)*4);
 }
});
test('seams: nothing rings past the form, and melodies close sections on their boundaries',()=>{
 const brief=loadBrief(),score=arrange(brief,motifsOf(brief));
 assert.equal(score.bars*4,brief.form.reduce((s,f)=>s+f.bars,0)*4);
 for(const e of score.events)assert.ok(e.beat+e.duration<=score.bars*4,`note at ${e.beat}`);
 for(const s of score.sections){
  const end=(s.bar+s.bars)*4;
  for(const e of score.events.filter(e=>e.track==='lead'&&e.minTier===3))
   assert.ok(!(e.beat<end&&e.beat+e.duration>end),`lead crosses bar ${s.bar+s.bars}`);
 }
 const last=score.events.filter(e=>e.track==='lead'&&e.minTier===3).at(-1);
 const tonicPc=pc(score.key.midiTonic);
 assert.equal(pc(last.pitch),tonicPc,'the last phrase resolves, so the loop lands on its opening key');
 assert.ok(score.events.some(e=>e.beat===0&&e.track==='pulse'));
});

// 2.3 complete output
test('tiers follow the brief, and the arranged bar passes the gates',()=>{
 const brief=loadBrief(),score=arrange(brief,motifsOf(brief));
 assert.deepEqual(score.tiers.map(t=>t.bpm),[100,103,106,109,112]);
 assert.equal(score.adornments.length,4);
 assert.deepEqual(score.adornments.map(a=>a.id),['spark','dip','slide','shine']);
 assert.deepEqual(new Set(score.tracks.map(t=>t.id)),new Set(['pulse','bass','guitar','lead','answer','brass']));
 const result=evaluate(score);
 assert.deepEqual(result.failures,[]);
 assert.equal(score.provenance.status,'candidate');
});

// 2.4 size budget
test('an over-budget score set fails, naming the overrun; a brief can only tighten the budget',()=>{
 const size=measure(['x'.repeat(1000)]);
 const budgets={scoreSetBytes:900};
 const over=checkBudget(size,{id:'fixture'},budgets);
 assert.equal(over.ok,false);
 assert.match(over.message,/fixture is 1000 bytes, 100 over its budget of 900; promotion refused/);
 assert.equal(checkBudget(size,{id:'fixture',budgetBytes:5000},budgets).ok,false,'a brief cannot raise the budget');
 assert.equal(checkBudget(size,{id:'fixture',budgetBytes:500},{scoreSetBytes:5000}).ok,false);
 assert.equal(checkBudget(size,{id:'fixture'},{scoreSetBytes:1000}).ok,true);
});
test('the candidate build reports an overrun and is never promotable',()=>{
 const dir=mkdtempSync(resolve(tmpdir(),'candidate-'));
 const result=buildCandidate(resolve(briefs,'bar_swag.json'),resolve(dir,'a'),{scoreSetBytes:1000});
 assert.equal(result.budget.ok,false);
 assert.match(result.budget.message,/promotion refused/);
 assert.equal(result.promotable,false);
 assert.equal(result.listeningApproval,false);
 const ok=buildCandidate(resolve(briefs,'bar_swag.json'),resolve(dir,'b'));
 assert.equal(ok.budget.ok,true);
 assert.equal(ok.promotable,false,'even a passing build awaits listening approval');
 rmSync(dir,{recursive:true,force:true});
});
test('an invalid brief builds nothing and names the problem',()=>{
 const dir=mkdtempSync(resolve(tmpdir(),'candidate-'));
 mkdirSync(resolve(dir,'motifs'));
 cpSync(resolve(briefs,'motifs'),resolve(dir,'motifs'),{recursive:true});
 const brief=loadBrief();brief.voices.push('kazooOfDoom');
 writeFileSync(resolve(dir,'bad.json'),JSON.stringify(brief));
 const result=buildCandidate(resolve(dir,'bad.json'),resolve(dir,'out'));
 assert.equal(result.status,'invalid-brief');
 assert.ok(result.problems.some(p=>p.includes('kazooOfDoom')));
 assert.equal(existsSync(resolve(dir,'out')),false);
 rmSync(dir,{recursive:true,force:true});
});

// Level styles
const gardenBrief=()=>JSON.parse(readFileSync(resolve(briefs,'garden_mojo.json')));
test('a tumbao anticipates: no downbeat, the and of 2, and the next root on 4',()=>{
 const timeline=buildTimeline(gardenBrief()),rng=makeRng(3,'tumbao');
 timeline.slice(1).forEach((entry,i)=>{
  const next=timeline[(i+2)%timeline.length],beats=bassTumbao(entry,next,rng);
  const at=x=>beats.find(n=>n.beat===entry.bar*4+x);
  assert.equal(at(0),undefined,`bar ${entry.bar}`);
  assert.ok(at(1.5));
  assert.equal(at(3).pitch,bassPitch(next.rootPc));
 });
});
test('a section-limited part only sounds in its sections',()=>{
 const brief=gardenBrief(),score=arrange(brief,motifsOf(brief));
 const lift=score.events.filter(e=>e.track==='brass'&&e.minTier===3);
 assert.ok(lift.length);
 assert.ok(lift.every(e=>Math.floor(e.beat/4)>=16&&Math.floor(e.beat/4)<24));
});
test('both level briefs pass every gate, including Latin identity in every tier',()=>{
 for(const brief of [gardenBrief(),loadBrief()]){
  const result=evaluate(arrange(brief,motifsOf(brief)));
  assert.deepEqual(result.failures,[],brief.id);
  for(const l of result.metrics.latinIdentity)assert.ok(l.share>=.75,`${brief.id} tier ${l.tier}`);
 }
});
test('Garden carries clave and tumbao from tier 0, and Bar a cumbia base',()=>{
 const garden=gardenBrief(),bar=loadBrief();
 const g=evaluate(arrange(garden,motifsOf(garden))).metrics.latinIdentity[0];
 assert.ok(g.clave>=.9&&g.tumbao>=.9,JSON.stringify(g));
 const b=evaluate(arrange(bar,motifsOf(bar))).metrics.latinIdentity[0];
 assert.ok(b.cumbia>=.9,JSON.stringify(b));
});
test('an unknown part section is refused by name',async()=>{
 const {validateBrief}=await import('./brief.mjs');
 const brief=gardenBrief();brief.parts.find(p=>p.id==='mambo').sections=['Z'];
 assert.ok(validateBrief(brief).some(p=>/sections.*"Z"/.test(p)));
});
