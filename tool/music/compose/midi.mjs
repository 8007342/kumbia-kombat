// Standard MIDI export of a score at one tier. Same format as tool/music/generate.mjs,
// which stays untouched until the owner has heard the new scores.
const PPQ=480;
function variable(n){const a=[n&127];while(n>>=7)a.unshift((n&127)|128);return Buffer.from(a)}
const u16=n=>{const b=Buffer.alloc(2);b.writeUInt16BE(n);return b};
const u32=n=>{const b=Buffer.alloc(4);b.writeUInt32BE(n);return b};
const chunk=(id,b)=>Buffer.concat([Buffer.from(id),u32(b.length),b]);
export function midi(score,tier=4){
 const tempo=Math.round(60000000/score.tiers[tier].bpm);
 const meta=Buffer.from([0,0xff,0x51,3,(tempo>>16)&255,(tempo>>8)&255,tempo&255,0,0xff,0x58,4,4,2,24,8,0,0xff,0x2f,0]);
 const chunks=[chunk('MTrk',meta)];
 for(const t of score.tracks){
  const ev=[{tick:0,priority:0,data:Buffer.from([0xc0|t.channel,t.program])}];
  for(const e of score.events.filter(e=>e.track===t.id&&e.minTier<=tier&&e.maxTier>=tier)){
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
