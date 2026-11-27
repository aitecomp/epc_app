import {webcrypto} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
if (!globalThis.crypto) Object.defineProperty(globalThis, "crypto", {value: webcrypto});
const source=await readFile(new URL('../worker.js',import.meta.url),'utf8');
const worker=(await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)).default;
class Bucket {
  constructor(){this.map=new Map();this.version=0;}
  async put(k,value,opts={}) { const previous=this.map.get(k); const cond=opts.onlyIf;
    if (cond?.etagMatches && previous?.etag !== cond.etagMatches) return null;
    if (cond?.etagDoesNotMatch === '*' && previous) return null;
    const bytes=typeof value==='string'?new TextEncoder().encode(value):new Uint8Array(value); const entry={bytes,opts,etag:String(++this.version)};this.map.set(k,entry);return entry; }
  async get(k, options={}){const e=this.map.get(k);if(!e)return null; const range=options.range; const body=range ? e.bytes.slice(range.offset,range.offset+range.length) : e.bytes; return {body,etag:e.etag,size:e.bytes.length,customMetadata:e.opts.customMetadata,httpMetadata:e.opts.httpMetadata,async json(){return JSON.parse(new TextDecoder().decode(e.bytes))},async text(){return new TextDecoder().decode(e.bytes)}}}
  async head(k){return this.get(k)}
  async delete(k){this.map.delete(k)}
  async list({prefix}){return {objects:[...this.map.keys()].filter(k=>k.startsWith(prefix)).sort().map(key=>({key})),truncated:false}}
}
const bucket=new Bucket();await bucket.put('members.json',JSON.stringify({members:[{id:'m1',regNumber:'a',password:'pw',firstName:'Member',updatedAt:'2026-11-20T10:00:00Z'}]}));
const env={EPC_BUCKET:bucket,SYNC_KEY:'secret',CHAT_MEDIA_SECRET:'another-secret',CHAT_LEADER_REG:btoa('leader'),CHAT_LEADER_PASS:btoa('leaderpass')};
const base='https://example.com';
const cred=Buffer.from(JSON.stringify({reg:'a',password:'pw'})).toString('base64');
const leaderCred=Buffer.from(JSON.stringify({reg:'leader',password:'leaderpass'})).toString('base64');
const h={'x-sync-key':'secret','x-chat-auth':cred};
async function req(path,method='GET',body,headers={}){return worker.fetch(new Request(base+path,{method,headers:{...h,...headers},body}),env)}
async function guestReq(path,method='GET',body,headers={}){return worker.fetch(new Request(base+path,{method,headers:{'x-sync-key':'secret','x-guest-id':'g1',...headers},body}),env)}
async function leaderReq(path,method='GET',body,headers={}){return worker.fetch(new Request(base+path,{method,headers:{'x-sync-key':'secret','x-chat-auth':leaderCred,...headers},body}),env)}

// 1) Chat & Sync tests
assert.equal((await req('/chat/messages','GET',undefined,{'x-chat-auth':Buffer.from(JSON.stringify({reg:'a',password:'bad'})).toString('base64')})).status,401);
const put=await req('/chat/media','POST',new Uint8Array([137,80,78,71]),{'content-type':'image/png'});assert.equal(put.status,200);const media=await put.json();
const post=await req('/chat/messages','POST',JSON.stringify({text:'hello',media:media.id}),{'content-type':'application/json'});assert.equal(post.status,200);const {id}=await post.json();
assert.equal((await req('/chat/react','POST',JSON.stringify({id,emoji:'👍'}),{'content-type':'application/json'})).status,200);
const list=await (await req('/chat/messages')).json();assert.equal(list.messages.length,1);assert.equal(list.messages[0].reactions[0].emoji,'👍');
assert.equal((await worker.fetch(new Request(list.messages[0].mediaUrl),env)).status,200);
const partial=await worker.fetch(new Request(list.messages[0].mediaUrl,{headers:{range:'bytes=0-1'}}),env);assert.equal(partial.status,206);assert.equal((await partial.arrayBuffer()).byteLength,2);
assert.equal((await worker.fetch(new Request(base+'/chat/media/'+media.id),env)).status,401);
const replyResult=await req('/chat/messages','POST',JSON.stringify({text:'reply',replyId:id,replyName:'Member',replyText:'hello'}),{'content-type':'application/json'});
assert.equal(replyResult.status,200);
assert.equal((await req('/chat/messages/'+id,'DELETE',undefined,{'x-chat-auth':leaderCred})).status,403);
assert.equal((await req('/chat/messages/'+id,'DELETE')).status,200);
assert.equal((await bucket.head('chat/media/'+media.id)),null);
const remaining=(await (await req('/chat/messages')).json()).messages;
assert.equal(remaining.length,1);assert.equal(remaining[0].text,'reply');assert.equal(remaining[0].replyId,'');assert.equal(remaining[0].replyText,'');
assert.equal((await bucket.list({prefix:`chat/reactions/${id}/`})).objects.length,0);

// 2) Club Feed tests (HEAD + GET media, leader-only publish)
assert.equal((await req('/feed/posts','POST',JSON.stringify({title:'nope'}),{'content-type':'application/json'})).status,403);
const feedMediaRes=await leaderReq('/feed/media?kind=image','POST',new Uint8Array([137,80,78,71]),{'content-type':'application/octet-stream'});
assert.equal(feedMediaRes.status,200);
const feedMedia=await feedMediaRes.json();
const feedPostRes=await leaderReq('/feed/posts','POST',JSON.stringify({title:'افتتاح الموسم',caption:'تغطية مصورة',category:'فعالية',mediaId:feedMedia.id,mediaType:feedMedia.type}),{'content-type':'application/json'});
assert.equal(feedPostRes.status,200);
const feedPost=(await feedPostRes.json()).post;
assert.equal((await worker.fetch(new Request(feedPost.mediaUrl,{method:'HEAD'}),env)).status,200);
assert.equal((await worker.fetch(new Request(feedPost.mediaUrl),env)).status,200);

// 3) Join Requests tests (notification-only, no email)
const jrRes=await guestReq('/join-requests','POST',JSON.stringify({
  firstName:'أمين',lastName:'بن علي',phone:'0550123456',
  branch:'كلية العلوم الاقتصادية والتجارية وعلوم التسيير',specialization:'اقتصاد رقمي',
  level:'السنة الثالثة (L3)',year:'2026/2027',regNumber:'20269999',password:'pass123',motivation:'أرغب في المساهمة'
}),{'content-type':'application/json'});
assert.equal(jrRes.status,200);
const jr=(await jrRes.json()).request;
const decide=await (await leaderReq(`/join-requests/${jr.id}/decide`,'POST',JSON.stringify({decision:'approved',note:'مرحباً بك'}),{'content-type':'application/json'})).json();
assert.equal(decide.ok,true);assert.equal(decide.memberAdded,true);
const membersAfter=await (await req('/members')).json();
assert.equal(membersAfter.members.some(m=>m.regNumber==='20269999'),true);

// 4) Ideas & Polls (agree/disagree percentages)
assert.equal((await guestReq('/ideas')).status,401);
const ideaCreate=await (await req('/ideas','POST',JSON.stringify({title:'حاضنة أعمال',description:'منصة طلابية',category:'مبادرة اقتصادية'}),{'content-type':'application/json'})).json();
assert.equal(ideaCreate.idea.agreePercent,100);
const disagreeVote=await (await leaderReq(`/ideas/${ideaCreate.id}/vote`,'POST',JSON.stringify({choice:'disagree'}),{'content-type':'application/json'})).json();
assert.equal(disagreeVote.agreeCount,1);assert.equal(disagreeVote.disagreeCount,1);assert.equal(disagreeVote.agreePercent,50);assert.equal(disagreeVote.disagreePercent,50);

console.log('All v1.17.0 Worker tests passed');
