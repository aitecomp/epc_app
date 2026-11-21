/**
 * EPC Sync Worker — مزامنة بيانات أعضاء نادي رواد الاقتصاد عبر Cloudflare R2
 *
 *   GET  /members   → قراءة قاعدة الأعضاء (يتطلب المفتاح)
 *   PUT  /members   → حفظ قاعدة الأعضاء (يتطلب المفتاح)
 *   GET  /health    → فحص الحالة
 *
 * المتغيّرات: EPC_BUCKET (R2) + SYNC_KEY (سرّي)
 */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,PUT,POST,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'content-type,x-sync-key,x-chat-auth,range',
  'Access-Control-Expose-Headers': 'content-range,accept-ranges,content-length',
  'Access-Control-Max-Age': '86400',
};

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });

// OAuth credentials stay only in the Worker secret binding.
const b64url = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes)))
  .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
const enc = new TextEncoder();
async function sendActivityPush(env, data, validateOnly = false) {
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT || '{}');
  if (!account.private_key || !account.client_email || !account.project_id) throw new Error('Firebase credentials not configured');
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(enc.encode(JSON.stringify({alg:'RS256',typ:'JWT'})));
  const claim = b64url(enc.encode(JSON.stringify({iss:account.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})));
  const pem = account.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), c => c.charCodeAt(0));
  const signingKey = await crypto.subtle.importKey('pkcs8', der, {name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'}, false, ['sign']);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', signingKey, enc.encode(`${head}.${claim}`));
  const assertion = `${head}.${claim}.${b64url(signature)}`;
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method:'POST', headers:{'content-type':'application/x-www-form-urlencoded'},
    body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})
  });
  if (!tokenResponse.ok) throw new Error(`OAuth failed: ${tokenResponse.status}`);
  const token = (await tokenResponse.json()).access_token;
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`, {
    method:'POST', headers:{authorization:`Bearer ${token}`,'content-type':'application/json'},
    body:JSON.stringify({validate_only: validateOnly, message:{topic:'epc_activities',android:{priority:'high',ttl:'86400s'},data}})
  });
  if (!response.ok) throw new Error(`FCM failed: ${response.status}`);
  return await response.json();
}

const chatIdPattern = /^[a-zA-Z0-9_-]{1,100}$/;
async function chatActor(request, env) {
  try {
    const creds = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(request.headers.get('x-chat-auth') || ''), c => c.charCodeAt(0))));
    if (typeof creds.reg !== 'string' || typeof creds.password !== 'string' || !creds.reg || !creds.password) return null;
    if (env.CHAT_LEADER_REG && env.CHAT_LEADER_PASS && creds.reg === atob(env.CHAT_LEADER_REG) && creds.password === atob(env.CHAT_LEADER_PASS)) {
      const obj=await env.EPC_BUCKET.get('members.json');
      const leader=obj ? (await obj.json()).leaderProfile : null;
      return {id:creds.reg, name:leader ? `${leader.firstName || ''} ${leader.lastName || ''}`.trim() || 'القائد' : 'القائد'};
    }
    const obj = await env.EPC_BUCKET.get('members.json');
    if (!obj) return null;
    const data = await obj.json();
    const member = (data.members || []).find(m => m.regNumber === creds.reg && m.password === creds.password);
    if (!member) return null;
    return {id: creds.reg, name: `${member.firstName || ''} ${member.lastName || ''}`.trim() || 'عضو'};
  } catch (_) { return null; }
}
async function chatMac(env, data) {
  if (!env.CHAT_MEDIA_SECRET) throw new Error('chat media key missing');
  const key = await crypto.subtle.importKey('raw', enc.encode(env.CHAT_MEDIA_SECRET), {name:'HMAC',hash:'SHA-256'}, false, ['sign']);
  return b64url(await crypto.subtle.sign('HMAC',key,enc.encode(data)));
}
async function mediaUrl(env, origin, id) {
  const expiry = (Math.floor(Date.now()/1800000)+1)*1800;
  const sig = await chatMac(env, `${id}:${expiry}`);
  return `${origin}/chat/media/${encodeURIComponent(id)}?exp=${expiry}&sig=${sig}`;
}
async function serveChatMedia(request, env, id, url) {
  if (!chatIdPattern.test(id)) return json({error:'not found'},404);
  const exp = Number(url.searchParams.get('exp'));
  const sig = url.searchParams.get('sig') || '';
  if (!Number.isSafeInteger(exp) || exp < Math.floor(Date.now()/1000) || exp > Math.floor(Date.now()/1000)+3700 || sig !== await chatMac(env, `${id}:${exp}`)) return json({error:'unauthorized'},401);
  if (!env.CHAT_MEDIA_SECRET) return json({error:'not configured'},503);
  const meta = await env.EPC_BUCKET.head(`chat/media/${id}`);
  if (!meta) return json({error:'not found'},404);
  const match = /^bytes=(\d+)-(\d*)$/.exec(request.headers.get('range') || '');
  let start, end;
  if (match) {
    start=Number(match[1]); end=match[2] ? Math.min(Number(match[2]), meta.size-1) : meta.size-1;
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start > end || start >= meta.size)
      return new Response(null,{status:416,headers:{...CORS,'content-range':`bytes */${meta.size}`}});
  }
  const obj = await env.EPC_BUCKET.get(`chat/media/${id}`, match ? {range:{offset:start,length:end-start+1}} : {});
  if (!obj) return json({error:'not found'},404);
  const headers = new Headers(CORS);
  headers.set('content-type', obj.httpMetadata?.contentType || 'application/octet-stream');
  headers.set('accept-ranges', 'bytes');
  headers.set('content-length', String(match ? end-start+1 : meta.size));
  if (match) headers.set('content-range', `bytes ${start}-${end}/${meta.size}`);
  headers.set('content-disposition', url.searchParams.get('download') === '1' ? 'attachment' : 'inline');
  headers.set('cache-control','private, no-store');
  return new Response(obj.body,{headers,status: match ? 206 : 200});
}
async function chatHandler(request, env, url, ctx) {
  const actor = await chatActor(request,env);
  if (!actor) return json({error:'invalid account'},401);
  const path = url.pathname;
  if (path === '/chat/media' && request.method === 'POST') {
    const type = (request.headers.get('content-type') || '').split(';')[0];
    if (!/^(image\/(jpeg|png|webp|gif)|video\/(mp4|webm|quicktime)|audio\/(mp4|mpeg|ogg|wav|webm|x-m4a))$/.test(type)) return json({error:'unsupported media'},415);
    const length = Number(request.headers.get('content-length') || 0);
    if (length > 15*1024*1024) return json({error:'file exceeds 15 MB'},413);
    const bytes = await request.arrayBuffer();
    if (!bytes.byteLength || bytes.byteLength > 15*1024*1024) return json({error:'file exceeds 15 MB'},413);
    const id = crypto.randomUUID();
    await env.EPC_BUCKET.put(`chat/media/${id}`,bytes,{httpMetadata:{contentType:type},customMetadata:{owner:actor.id}});
    return json({id, type, size:bytes.byteLength});
  }
  if (path === '/chat/messages' && request.method === 'POST') {
    let data; try { data=await request.json(); } catch (_) { return json({error:'invalid json'},400); }
    const text = typeof data.text === 'string' ? data.text.trim().slice(0,4000) : '';
    const media = typeof data.media === 'string' && chatIdPattern.test(data.media) ? data.media : '';
    if (!text && !media) return json({error:'empty message'},400);
    let mediaType = '';
    if (media) { const obj=await env.EPC_BUCKET.head(`chat/media/${media}`); if (!obj || obj.customMetadata?.owner !== actor.id) return json({error:'invalid media'},400); mediaType=obj.httpMetadata?.contentType || ''; }
    const id = `${Date.now().toString().padStart(13,'0')}_${crypto.randomUUID()}`;
    const message = {id, authorId:actor.id, authorName:actor.name, text, media, mediaType,
      replyId:typeof data.replyId === 'string' && chatIdPattern.test(data.replyId) ? data.replyId : '',
      replyText:typeof data.replyText === 'string' ? data.replyText.slice(0,200) : '',
      replyName:typeof data.replyName === 'string' ? data.replyName.slice(0,100) : '',
      createdAt:new Date().toISOString()};
    await env.EPC_BUCKET.put(`chat/messages/${id}`,JSON.stringify(message),{httpMetadata:{contentType:'application/json'}});
    if (ctx && env.FIREBASE_SERVICE_ACCOUNT) {
      const senderHash=b64url(await crypto.subtle.digest('SHA-256',enc.encode(actor.id)));
      ctx.waitUntil(sendActivityPush(env,{kind:'chat',id,senderHash}).catch(e=>console.error('chat push failed',e.message)));
    }
    return json({ok:true,id});
  }
  if (path.startsWith('/chat/messages/') && request.method === 'DELETE') {
    const id=path.slice('/chat/messages/'.length);
    if (!chatIdPattern.test(id)) return json({error:'invalid message'},400);
    const object=await env.EPC_BUCKET.get(`chat/messages/${id}`);
    if (!object) return json({ok:true});
    const message=await object.json();
    if (message.authorId !== actor.id) return json({error:'only author can delete'},403);
    await env.EPC_BUCKET.delete(`chat/messages/${id}`);
    if (typeof message.media === 'string' && chatIdPattern.test(message.media)) {
      await env.EPC_BUCKET.delete(`chat/media/${message.media}`);
    }
    let cursor;
    do {
      const reactions=await env.EPC_BUCKET.list({prefix:`chat/reactions/${id}/`,limit:1000,cursor});
      if (reactions.objects.length) await Promise.all(reactions.objects.map(r=>env.EPC_BUCKET.delete(r.key)));
      cursor=reactions.truncated ? reactions.cursor : undefined;
    } while (cursor);
    return json({ok:true});
  }
  if (path === '/chat/react' && request.method === 'POST') {
    let data; try { data=await request.json(); } catch (_) { return json({error:'invalid json'},400); }
    if (!chatIdPattern.test(data.id || '') || !['','❤️','👍','😂','🎉','😮'].includes(data.emoji)) return json({error:'invalid reaction'},400);
    if (!await env.EPC_BUCKET.head(`chat/messages/${data.id}`)) return json({error:'not found'},404);
    const hash=b64url(await crypto.subtle.digest('SHA-256',enc.encode(actor.id)));
    const key=`chat/reactions/${data.id}/${hash}`;
    if (!data.emoji) await env.EPC_BUCKET.delete(key);
    else await env.EPC_BUCKET.put(key,JSON.stringify({emoji:data.emoji,authorId:actor.id}));
    return json({ok:true});
  }
  if (path === '/chat/messages' && request.method === 'GET') {
    let cursor, keys=[];
    do {
      const page=await env.EPC_BUCKET.list({prefix:'chat/messages/',limit:1000,cursor});
      keys.push(...page.objects.map(o=>o.key)); cursor=page.truncated ? page.cursor : undefined;
    } while (cursor && keys.length < 10000);
    keys=keys.slice(-60);
    const messages=await Promise.all(keys.map(async key => {
      const obj=await env.EPC_BUCKET.get(key); if (!obj) return null;
      const msg=await obj.json();
      if (msg.replyId && !await env.EPC_BUCKET.head(`chat/messages/${msg.replyId}`)) { msg.replyId=''; msg.replyText=''; msg.replyName=''; }
      if (msg.media) msg.mediaUrl=await mediaUrl(env,url.origin,msg.media);
      const reactions=await env.EPC_BUCKET.list({prefix:`chat/reactions/${msg.id}/`,limit:1000});
      msg.reactions=(await Promise.all(reactions.objects.map(async r=>{const ro=await env.EPC_BUCKET.get(r.key);return ro ? await ro.json() : null;}))).filter(Boolean);
      return msg;
    }));
    return json({messages:messages.filter(Boolean),me:actor.id});
  }
  return json({error:'not found'},404);
}

// Merge snapshots by stable IDs and timestamps so a stale device cannot erase data.
function mergeSnapshots(oldData, incoming) {
  const date = v => {const n=Date.parse(v || ''); return Number.isFinite(n) ? n : 0;};
  const byId=(a,b,timeField) => {
    const map=new Map();
    for (const item of [...(Array.isArray(a)?a:[]),...(Array.isArray(b)?b:[])]) {
      if (!item || typeof item.id !== 'string' || !item.id) continue;
      const current=map.get(item.id);
      if (!current || date(item[timeField]) > date(current[timeField])) map.set(item.id,item);
    }
    return [...map.values()];
  };
  const deleted=byId(oldData.deleted,incoming.deleted,'at');
  const deletedActivities=byId(oldData.deletedActivities,incoming.deletedActivities,'at');
  const keep=(items,tombs) => {
    const times=new Map(tombs.map(t=>[t.id,date(t.at)]));
    return items.filter(x=>!times.has(x.id) || date(x.updatedAt)>times.get(x.id));
  };
  return {...oldData,...incoming,
    members:keep(byId(oldData.members,incoming.members,'updatedAt'),deleted),deleted,
    leaderProfile: incoming.leaderProfile && (!oldData.leaderProfile || date(incoming.leaderProfile.updatedAt) > date(oldData.leaderProfile.updatedAt)) ? incoming.leaderProfile : (oldData.leaderProfile || null),
    activities:keep(byId(oldData.activities,incoming.activities,'updatedAt'),deletedActivities),deletedActivities,
    version:(Number(oldData.version)||0)+1,updatedAt:new Date().toISOString()};
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';
    const key = request.headers.get('x-sync-key') || url.searchParams.get('key') || '';

    if (path === '/health') return json({ ok: true, service: 'epc-sync' });

    // ── تنزيل تطبيق الأندرويد مباشرة (بدون مفتاح) ──────────────────────
    if (path === '/app' || path === '/app.apk') {
      const object = (await env.EPC_BUCKET.get('epc-arm64.apk')) ||
        (await env.EPC_BUCKET.get('epc-universal.apk'));
      if (!object) return json({ error: 'apk not uploaded yet' }, 404);
      const headers = new Headers();
      headers.set('content-type', 'application/vnd.android.package-archive');
      headers.set('content-disposition', 'attachment; filename="EPC-Club.apk"');
      headers.set('cache-control', 'no-store');
      headers.set('Access-Control-Allow-Origin', '*');
      if (object.size) headers.set('content-length', String(object.size));
      return new Response(object.body, { headers });
    }

    if (path.startsWith('/chat/media/') && request.method === 'GET') return serveChatMedia(request, env, path.slice('/chat/media/'.length), url);

    if (!env.SYNC_KEY || key !== env.SYNC_KEY) {
      return json({ error: 'unauthorized' }, 401);
    }

    if (path === '/sync-check' && request.method === 'POST') {
      const testKey=`checks/${crypto.randomUUID()}`;
      try {
        const first=await env.EPC_BUCKET.put(testKey,'first',{onlyIf:{etagDoesNotMatch:'*'}});
        const obj=await env.EPC_BUCKET.get(testKey);
        const bad=await env.EPC_BUCKET.put(testKey,'bad',{onlyIf:{etagMatches:'not-an-etag'}});
        const good=await env.EPC_BUCKET.put(testKey,'second',{onlyIf:{etagMatches:obj.etag}});
        return json({ok:!!first && !!obj && !bad && !!good});
      } finally { await env.EPC_BUCKET.delete(testKey); }
    }

    if (path.startsWith('/chat/')) return chatHandler(request, env, url, ctx);

    if (path === '/notify' && request.method === 'POST') {
      let input;
      try { input = await request.json(); } catch (_) { return json({error:'invalid json'}, 400); }
      if (!input || typeof input.id !== 'string' || !input.id || typeof input.title !== 'string' || !input.title || !['create','update','delete'].includes(input.operation) || typeof input.at !== 'string') return json({error:'invalid activity'}, 400);
      const data = {id:input.id.slice(0,200), title:input.title.slice(0,200), place:String(input.place || '').slice(0,200), at:input.at.slice(0,50), operation:input.operation};
      try { await sendActivityPush(env, data, input.validate_only === true); return json({ok:true, validated: input.validate_only === true}); }
      catch (e) { console.error('push failed', e.message); return json({error:'push unavailable'}, 502); }
    }

    // ── رفع نسخة التطبيق (من CI فقط، بالمفتاح) ─────────────────────────
    if (path === '/app' && (request.method === 'PUT' || request.method === 'POST')) {
      const body = await request.arrayBuffer();
      if (!body || body.byteLength < 1024) return json({ error: 'apk required' }, 400);
      await env.EPC_BUCKET.put('epc-arm64.apk', body, {
        httpMetadata: { contentType: 'application/vnd.android.package-archive' },
      });
      return json({ ok: true, size: body.byteLength });
    }

    if (path !== '/members' && path !== '/') return json({ error: 'not found' }, 404);

    if (request.method === 'GET') {
      const object = await env.EPC_BUCKET.get('members.json');
      if (!object) return json({ members: [], deleted: [], version: 0 });
      const body = await object.text();
      return new Response(body, {
        headers: { ...CORS, 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
      });
    }

    if (request.method === 'PUT' || request.method === 'POST') {
      const body = await request.text();
      let parsed;
      try {
        parsed = JSON.parse(body);
      } catch (_) {
        return json({ error: 'invalid json' }, 400);
      }
      if (!parsed || !Array.isArray(parsed.members)) return json({ error: 'members[] required' }, 400);

      for (let attempt=0; attempt<8; attempt++) {
        const prior=await env.EPC_BUCKET.get('members.json');
        const oldData=prior ? await prior.json() : {};
        const merged=mergeSnapshots(oldData,parsed);
        const result=await env.EPC_BUCKET.put('members.json', JSON.stringify(merged), {
          onlyIf: prior ? {etagMatches: prior.etag} : {etagDoesNotMatch: '*'},
          httpMetadata: {contentType:'application/json; charset=utf-8'},
        });
        if (result) return json({ok:true,version:merged.version,count:merged.members.length});
      }
      return json({error:'sync conflict; retry'},409);
    }

    return json({ error: 'method not allowed' }, 405);
  },
};
