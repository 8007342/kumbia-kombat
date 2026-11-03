// Brief and motif validation. Dependency-free: a small interpreter for the JSON
// Schema subset used by tool/music/schemas, then the cross-references a schema
// cannot express. Every problem names its field.
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const here=dirname(fileURLToPath(import.meta.url));
const load=p=>JSON.parse(readFileSync(resolve(here,p)));
export const BRIEF_SCHEMA=load('../schemas/brief.schema.json');
export const MOTIF_SCHEMA=load('../schemas/motif.schema.json');
const voiceTable=load('../voices.json');
export const KNOWN_VOICES=new Set([...voiceTable.existing,...voiceTable.recipes]);

export function checkSchema(value,schema,path='$',out=[]){
 const typeOf=v=>Array.isArray(v)?'array':v===null?'null':typeof v;
 if(schema.enum&&!schema.enum.includes(value)){out.push(`${path}: ${JSON.stringify(value)} is not one of ${schema.enum.join(', ')}`);return out;}
 if(schema.type){
  const ok=schema.type==='integer'?Number.isInteger(value):typeOf(value)===schema.type;
  if(!ok){out.push(`${path}: expected ${schema.type}`);return out;}
 }
 if(typeof value==='number'){
  if(schema.minimum!==undefined&&value<schema.minimum)out.push(`${path}: below ${schema.minimum}`);
  if(schema.maximum!==undefined&&value>schema.maximum)out.push(`${path}: above ${schema.maximum}`);
 }
 if(typeof value==='string'){
  if(schema.minLength!==undefined&&value.length<schema.minLength)out.push(`${path}: too short`);
  if(schema.pattern&&!new RegExp(schema.pattern).test(value))out.push(`${path}: ${JSON.stringify(value)} does not match ${schema.pattern}`);
 }
 if(Array.isArray(value)){
  if(schema.minItems!==undefined&&value.length<schema.minItems)out.push(`${path}: needs at least ${schema.minItems} items`);
  if(schema.maxItems!==undefined&&value.length>schema.maxItems)out.push(`${path}: allows at most ${schema.maxItems} items`);
  if(schema.items)value.forEach((v,i)=>checkSchema(v,schema.items,`${path}[${i}]`,out));
 }
 if(typeOf(value)==='object'){
  for(const k of schema.required??[])if(!(k in value))out.push(`${path}.${k}: required`);
  for(const [k,v] of Object.entries(value)){
   const sub=schema.properties?.[k];
   if(sub)checkSchema(v,sub,`${path}.${k}`,out);
   else if(schema.additionalProperties===false)out.push(`${path}.${k}: unknown field`);
   else if(schema.additionalProperties&&typeof schema.additionalProperties==='object')checkSchema(v,schema.additionalProperties,`${path}.${k}`,out);
  }
 }
 return out;
}

export function validateMotif(motif){
 const problems=checkSchema(motif,MOTIF_SCHEMA);
 if(problems.length)return problems;
 let previous=-1;
 motif.notes.forEach(([beat,,duration],i)=>{
  if(beat<previous)problems.push(`$.notes[${i}]: out of order`);
  if(beat<0||duration<=0||beat+duration>motif.beats)problems.push(`$.notes[${i}]: outside the motif's ${motif.beats} beats`);
  previous=beat;
 });
 return problems;
}

export function validateBrief(brief,{loadMotif}={}){
 const problems=checkSchema(brief,BRIEF_SCHEMA);
 if(problems.length)return problems;
 const sections=new Set(brief.form.map(f=>f.section));
 const total=brief.form.reduce((s,f)=>s+f.bars,0);
 if(total%2)problems.push(`$.form: total ${total} bars is not a whole number of 2-bar phrases`);
 brief.form.forEach((f,i)=>{if(f.bars%2)problems.push(`$.form[${i}].bars: ${f.bars} does not end on a phrase boundary`)});
 brief.keys.forEach((k,i)=>{if(!sections.has(k.section))problems.push(`$.keys[${i}].section: unknown section "${k.section}"`)});
 for(const s of sections){
  if(!brief.keys.some(k=>k.section===s))problems.push(`$.keys: no key for section "${s}"`);
  if(!brief.harmony[s])problems.push(`$.harmony: no progression for section "${s}"`);
 }
 for(const s of Object.keys(brief.harmony))if(!sections.has(s))problems.push(`$.harmony.${s}: unknown section "${s}"`);
 brief.voices.forEach((v,i)=>{if(!KNOWN_VOICES.has(v))problems.push(`$.voices[${i}]: unknown voice "${v}"`)});
 const declared=new Set(brief.voices),ids=new Set();
 brief.parts.forEach((p,i)=>{
  if(ids.has(p.id))problems.push(`$.parts[${i}].id: duplicate part "${p.id}"`);
  ids.add(p.id);
  if(!KNOWN_VOICES.has(p.voice))problems.push(`$.parts[${i}].voice: unknown voice "${p.voice}"`);
  else if(!declared.has(p.voice))problems.push(`$.parts[${i}].voice: "${p.voice}" is not listed in $.voices`);
  if(p.role==='percussion'&&!p.kit)problems.push(`$.parts[${i}].kit: percussion part "${p.id}" needs a kit`);
  if(p.role==='melody'&&!p.motif)problems.push(`$.parts[${i}].motif: melody part "${p.id}" needs a motif`);
  if(p.motif&&!brief.motifs[p.motif])problems.push(`$.parts[${i}].motif: unknown motif "${p.motif}"`);
  (p.sections??[]).forEach(s=>{if(!sections.has(s))problems.push(`$.parts[${i}].sections: unknown section "${s}"`)});
  for(const s of Object.keys(p.plan??{}))if(!sections.has(s))problems.push(`$.parts[${i}].plan.${s}: unknown section "${s}"`);
 });
 const tracks=brief.parts.map(p=>p.track);
 const voiceOf=new Map();
 brief.parts.forEach((p,i)=>{
  if(voiceOf.has(p.track)&&voiceOf.get(p.track)!==p.voice)problems.push(`$.parts[${i}].voice: track "${p.track}" already plays "${voiceOf.get(p.track)}"`);
  voiceOf.set(p.track,p.voice);
 });
 for(const required of ['pulse','bass','guitar','lead','answer','brass'])
  if(!tracks.includes(required))problems.push(`$.parts: no part on the required track "${required}"`);
 const active=new Set();
 brief.tiers.forEach((t,i)=>{
  for(const id of t.adds){
   if(!ids.has(id))problems.push(`$.tiers[${i}].adds: unknown part "${id}"`);
   else active.add(id);
  }
  for(const id of t.removes??[]){
   if(!ids.has(id))problems.push(`$.tiers[${i}].removes: unknown part "${id}"`);
   else if(!active.has(id))problems.push(`$.tiers[${i}].removes: part "${id}" is not active yet`);
   active.delete(id);
  }
 });
 const introduced=new Set(brief.tiers.flatMap(t=>t.adds));
 for(const id of ids)if(!introduced.has(id))problems.push(`$.parts: part "${id}" never enters any tier`);
 if(loadMotif)for(const [name,path] of Object.entries(brief.motifs)){
  let motif;
  try{motif=loadMotif(path)}catch(error){problems.push(`$.motifs.${name}: cannot read ${path}: ${error.message}`);continue;}
  for(const p of validateMotif(motif))problems.push(`$.motifs.${name} ${p}`);
  if(motif?.provenance&&!motif.provenance.accepted)problems.push(`$.motifs.${name}: ${motif.id} is an unaccepted candidate`);
 }
 return problems;
}
