import {webcrypto} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
if (!globalThis.crypto) Object.defineProperty(globalThis, "crypto", {value: webcrypto});
const source=await readFile(new URL('../worker.js',import.meta.url),'utf8');
const worker=(await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)).default;
class Bucket {
  constructor(){this.map=new Map()}
  async put(k,value,opts={}) { const bytes=typeof value==='string'?new TextEncoder().encode(value):new Uint8Array(value);this.map.set(k,{bytes,opts}); }
  async get(k, options={}){const e=this.map.get(k);if(!e)return null; const range=options.range; const body=range ? e.bytes.slice(range.offset,range.offset+range.length) : e.bytes; return {body,size:e.bytes.length,customMetadata:e.opts.customMetadata,httpMetadata:e.opts.httpMetadata,async json(){return JSON.parse(new TextDecoder().decode(e.bytes))},async text(){return new TextDecoder().decode(e.bytes)}}}
  async head(k){return this.get(k)}
  async delete(k){this.map.delete(k)}
  async list({prefix}){return {objects:[...this.map.keys()].filter(k=>k.startsWith(prefix)).sort().map(key=>({key})),truncated:false}}
}
const bucket=new Bucket();await bucket.put('members.json',JSON.stringify({members:[{regNumber:'a',password:'pw',firstName:'Member'}]}));
const env={EPC_BUCKET:bucket,SYNC_KEY:'secret',CHAT_MEDIA_SECRET:'another-secret',CHAT_LEADER_REG:btoa('leader'),CHAT_LEADER_PASS:btoa('leaderpass')};
const base='https://example.com';
const cred=Buffer.from(JSON.stringify({reg:'a',password:'pw'})).toString('base64');
const h={'x-sync-key':'secret','x-chat-auth':cred};
async function req(path,method='GET',body,headers={}){return worker.fetch(new Request(base+path,{method,headers:{...h,...headers},body}),env)}
assert.equal((await req('/chat/messages','GET',undefined,{'x-chat-auth':Buffer.from(JSON.stringify({reg:'a',password:'bad'})).toString('base64')})).status,401);
const put=await req('/chat/media','POST',new Uint8Array([137,80,78,71]),{'content-type':'image/png'});assert.equal(put.status,200);const media=await put.json();
const post=await req('/chat/messages','POST',JSON.stringify({text:'hello',media:media.id}),{'content-type':'application/json'});assert.equal(post.status,200);const {id}=await post.json();
assert.equal((await req('/chat/react','POST',JSON.stringify({id,emoji:'👍'}),{'content-type':'application/json'})).status,200);
const list=await (await req('/chat/messages')).json();assert.equal(list.messages.length,1);assert.equal(list.messages[0].reactions[0].emoji,'👍');
assert.equal((await worker.fetch(new Request(list.messages[0].mediaUrl),env)).status,200);
const partial=await worker.fetch(new Request(list.messages[0].mediaUrl,{headers:{range:'bytes=0-1'}}),env);assert.equal(partial.status,206);assert.equal((await partial.arrayBuffer()).byteLength,2);
assert.equal((await worker.fetch(new Request(base+'/chat/media/'+media.id),env)).status,401);
console.log('Chat worker tests passed');
