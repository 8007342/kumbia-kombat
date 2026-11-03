// Size budget for one room's score set: its score, success phrase and bridges, as note
// data. MIDI previews are review artefacts that the game does not load, so they don't count.
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {gzipSync} from 'node:zlib';

const here=dirname(fileURLToPath(import.meta.url));
export const loadBudgets=()=>JSON.parse(readFileSync(resolve(here,'../budgets.json')));

export function measure(texts){
 const joined=texts.join('');
 return {bytes:Buffer.byteLength(joined),gzipBytes:gzipSync(joined,{level:9}).length};
}
/** A brief may declare a smaller budget, never a larger one. */
export function checkBudget(size,brief,budgets=loadBudgets()){
 const limit=Math.min(brief.budgetBytes??Infinity,budgets.scoreSetBytes);
 const ok=size.bytes<=limit;
 return {ok,limit,message:ok?'':`score set ${brief.id} is ${size.bytes} bytes, ${size.bytes-limit} over its budget of ${limit}; promotion refused`};
}
