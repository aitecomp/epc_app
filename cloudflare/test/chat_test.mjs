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
const activity={id:'activity1',title:'test',updatedAt:'2026-11-21T12:00:00Z'};
const putSync=async payload=>req('/members','PUT',JSON.stringify(payload),{'content-type':'application/json'});
const profile={id:'leader',firstName:'سالم',lastName:'أحمد',photo:'photo-data',updatedAt:'2026-11-21T12:00:00Z'};
assert.equal((await putSync({members:[],activities:[activity],leaderProfile:profile})).status,200);
assert.equal((await putSync({members:[],activities:[]})).status,200);
assert.equal((await (await req('/members')).json()).activities[0].id,'activity1');
assert.equal((await (await req('/members')).json()).leaderProfile.photo,'photo-data');
assert.equal((await putSync({members:[],activities:[],deletedActivities:[{id:'activity1',at:'2026-11-21T13:00:00Z'}]})).status,200);
assert.equal((await putSync({members:[],activities:[activity]})).status,200);
assert.equal((await (await req('/members')).json()).activities.length,0);
assert.equal((await (await req('/sync-check','POST')).json()).ok,true);

// 2) Club Feed tests (leader-only publish, public view/like/comment/share)
assert.equal((await req('/feed/posts','POST',JSON.stringify({title:'nope',caption:'member cannot post'}),{'content-type':'application/json'})).status,403);
assert.equal((await guestReq('/feed/posts','POST',JSON.stringify({title:'nope'}),{'content-type':'application/json'})).status,403);
const feedMediaRes=await leaderReq('/feed/media','POST',new Uint8Array([137,80,78,71]),{'content-type':'image/png'});
assert.equal(feedMediaRes.status,200);
const feedMedia=await feedMediaRes.json();
const feedPostRes=await leaderReq('/feed/posts','POST',JSON.stringify({title:'افتتاح الموسم',caption:'تغطية مصورة للحدث',category:'فعالية',mediaId:feedMedia.id}),{'content-type':'application/json'});
assert.equal(feedPostRes.status,200);
const feedPost=(await feedPostRes.json()).post;
assert.equal((await worker.fetch(new Request(feedPost.mediaUrl),env)).status,200);
const likeRes=await (await guestReq(`/feed/posts/${feedPost.id}/like`,'POST')).json();
assert.equal(likeRes.liked,true);assert.equal(likeRes.likesCount,1);
const commentRes=await (await guestReq(`/feed/posts/${feedPost.id}/comments`,'POST',JSON.stringify({text:'رائع جداً!',authorName:'زائر'}),{'content-type':'application/json'})).json();
assert.equal(commentRes.ok,true);assert.equal(commentRes.commentsCount,1);
const shareRes=await (await guestReq(`/feed/posts/${feedPost.id}/share`,'POST')).json();
assert.equal(shareRes.sharesCount,1);
const guestFeed=await (await guestReq('/feed/posts')).json();
assert.equal(guestFeed.posts.length,1);assert.equal(guestFeed.posts[0].likedByMe,true);assert.equal(guestFeed.posts[0].sharesCount,1);

// 3) Join Requests tests (guest submit, leader approve -> member added)
const jrRes=await guestReq('/join-requests','POST',JSON.stringify({
  firstName:'أمين',lastName:'بن علي',email:'amine@example.com',phone:'0550123456',
  branch:'كلية العلوم الاقتصادية والتجارية وعلوم التسيير',specialization:'اقتصاد رقمي',
  level:'السنة الثالثة (L3)',year:'2026/2027',regNumber:'20269999',password:'pass123',motivation:'أرغب في المساهمة في مشاريع النادي'
}),{'content-type':'application/json'});
assert.equal(jrRes.status,200);
const jr=(await jrRes.json()).request;
assert.equal((await req('/join-requests')).status,403);
const jrList=await (await leaderReq('/join-requests')).json();
assert.equal(jrList.pendingCount,1);
const origFetch=globalThis.fetch;
globalThis.fetch=async()=>new Response(JSON.stringify({id:'ok'}),{status:200});
try {
  const decide=await (await leaderReq(`/join-requests/${jr.id}/decide`,'POST',JSON.stringify({decision:'approved',note:'أهلاً بك معنا'}),{'content-type':'application/json'})).json();
  assert.equal(decide.ok,true);assert.equal(decide.memberAdded,true);assert.equal(decide.emailSent,true);
} finally { globalThis.fetch=origFetch; }
const membersAfter=await (await req('/members')).json();
assert.equal(membersAfter.members.some(m=>m.regNumber==='20269999'),true);
const jrStatus=await (await guestReq(`/join-requests/status/${jr.id}`)).json();
assert.equal(jrStatus.status,'approved');

// 4) Ideas & Projects with Voting tests (members only)
assert.equal((await guestReq('/ideas')).status,401);
const ideaCreate=await (await req('/ideas','POST',JSON.stringify({title:'حاضنة أعمال طلابية',description:'منصة لدعم مشاريع الطلبة الاقتصادية',category:'مبادرة اقتصادية'}),{'content-type':'application/json'})).json();
assert.equal(ideaCreate.ok,true);
const ideaVote=await (await leaderReq(`/ideas/${ideaCreate.id}/vote`,'POST')).json();
assert.equal(ideaVote.voted,true);assert.equal(ideaVote.votesCount,2);
const ideaStatus=await (await leaderReq(`/ideas/${ideaCreate.id}/status`,'PATCH',JSON.stringify({status:'approved'}),{'content-type':'application/json'})).json();
assert.equal(ideaStatus.status,'approved');
const ideasList=await (await req('/ideas')).json();
assert.equal(ideasList.ideas.length,1);assert.equal(ideasList.ideas[0].votesCount,2);

console.log('All Worker tests (chat, sync, club feed, join requests, ideas) passed');
