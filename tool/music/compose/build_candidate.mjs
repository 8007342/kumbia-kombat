#!/usr/bin/env node
// Build one room from its brief into a candidate copy of the score pack. assets/music is
// never written: nothing is promoted until a person has listened and approved.
//
//   node tool/music/compose/build_candidate.mjs tool/music/briefs/bar_swag.json [--out <dir>]
//   node tool/music/validate.mjs --root build/music-candidates/bar_swag
//   node tool/music/compose/gates.mjs --root build/music-candidates/bar_swag bar_swag
//
// Exits 1 for an invalid brief, 2 for a size-budget overrun, 3 for failed gates.
import {readFileSync,writeFileSync,mkdirSync,cpSync,rmSync} from 'node:fs';
import {resolve,dirname,relative} from 'node:path';
import {fileURLToPath} from 'node:url';
import {validateBrief} from './brief.mjs';
import {arrange,composeSuccess,composeBridge,bridgeTargetFromBrief,bridgeTargetFromScore} from './arrange.mjs';
import {midi} from './midi.mjs';
import {evaluate} from './gates.mjs';
import {measure,checkBudget,loadBudgets} from './budget.mjs';

const repo=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');
const readJson=p=>JSON.parse(readFileSync(p));

export function buildCandidate(briefPath,outDir,budgets=loadBudgets()){
 const brief=readJson(briefPath),briefDir=dirname(briefPath);
 const loadMotif=p=>readJson(resolve(briefDir,p));
 const problems=validateBrief(brief,{loadMotif});
 if(problems.length)return {status:'invalid-brief',problems};
 const motifs=Object.fromEntries(Object.entries(brief.motifs).map(([k,p])=>[k,loadMotif(p)]));

 const score=arrange(brief,motifs),success=composeSuccess(brief,motifs);
 const shipped=readJson(resolve(repo,'assets/music/manifest.json'));
 const here=bridgeTargetFromBrief(brief,motifs);
 const bridges=[];
 for(const entry of shipped.transitions.bridges){
  const intent=brief.transitions?.bridgeIntent??'A percussion pivot lets the previous key settle.';
  if(entry.toScore===brief.id)bridges.push(composeBridge(entry.id,entry.title,entry.fromScore,here,brief.seed,intent));
  else if(entry.fromScore===brief.id){
   const next=readJson(resolve(repo,shipped.scores.find(s=>s.id===entry.toScore).path));
   bridges.push(composeBridge(entry.id,entry.title,brief.id,bridgeTargetFromScore(next),brief.seed,intent));
  }
 }

 rmSync(outDir,{recursive:true,force:true});
 mkdirSync(resolve(outDir,'assets'),{recursive:true});
 cpSync(resolve(repo,'assets/music'),resolve(outDir,'assets/music'),{recursive:true});
 const manifest=readJson(resolve(outDir,'assets/music/manifest.json'));
 const write=(rel,text)=>writeFileSync(resolve(outDir,rel),text);
 const scorePath=s=>`assets/music/scores/${s.id}.json`;
 const rendered=new Map();
 for(const s of [score,success,...bridges]){
  const text=JSON.stringify(s)+'\n';
  rendered.set(scorePath(s),text);
  write(scorePath(s),text);
 }
 for(let tier=0;tier<5;tier++)write(`assets/music/midi/${score.id}_tier${tier}.mid`,midi(score,tier));
 write(`assets/music/midi/${success.id}.mid`,midi(success,4));
 for(const b of bridges)write(`assets/music/midi/${b.id}.mid`,midi(b,0));

 const room=manifest.scores.find(s=>s.id===score.id);
 if(room)Object.assign(room,{title:score.title,bars:score.bars,baseBpm:score.tiers[0].bpm,fullBpm:score.tiers[4].bpm});
 const sEntry=manifest.transitions.successes.find(s=>s.id===success.id);
 if(sEntry)Object.assign(sEntry,{title:success.title,baseBpm:success.tiers[0].bpm,fullBpm:success.tiers[4].bpm});
 for(const b of bridges)Object.assign(manifest.transitions.bridges.find(e=>e.id===b.id),{baseBpm:b.tiers[0].bpm,fullBpm:b.tiers[4].bpm});
 write('assets/music/manifest.json',JSON.stringify(manifest,null,2)+'\n');

 const size=measure([...rendered.values()]);
 const budget=checkBudget(size,brief,budgets);
 const gates=evaluate(score);
 const report={id:brief.id,status:'candidate',promotable:false,listeningApproval:false,
  note:'Measured gates are not evidence that this sounds good. A person must listen before promotion.',
  size,budget,gates:{passed:gates.passed,failures:gates.failures,metrics:gates.metrics},files:[...rendered.keys()]};
 write('candidate.json',JSON.stringify(report,null,1)+'\n');
 return {...report,outDir};
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);
 const briefArg=args.find(a=>!a.startsWith('--')&&args[args.indexOf(a)-1]!=='--out');
 if(!briefArg){console.error('usage: build_candidate.mjs <brief.json> [--out <dir>]');process.exit(1)}
 const brief=resolve(briefArg);
 const outIndex=args.indexOf('--out');
 const out=outIndex>=0?resolve(args[outIndex+1]):resolve(repo,'build/music-candidates',readJson(brief).id);
 const result=buildCandidate(brief,out);
 if(result.status==='invalid-brief'){for(const p of result.problems)console.error(p);process.exit(1)}
 console.log(`${result.id}: candidate at ${relative(process.cwd(),out)}`);
 console.log(`size ${result.size.bytes} bytes JSON, ${result.size.gzipBytes} gzipped; budget ${result.budget.limit}`);
 console.log(`gates ${result.gates.passed?'pass':'FAIL'}`);
 for(const f of result.gates.failures)console.log(`  ${f.gate}: ${f.message}`);
 console.log('not promotable: awaiting listening approval');
 if(!result.budget.ok){console.error(result.budget.message);process.exit(2)}
 if(!result.gates.passed)process.exit(3);
}
