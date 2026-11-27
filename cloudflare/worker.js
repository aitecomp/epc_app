/**
 * EPC Sync Worker — مزامنة بيانات نادي رواد الاقتصاد عبر Cloudflare R2
 *
 *   GET  /health                     → فحص الحالة
 *   GET  /app | /app.apk             → تنزيل APK مباشرة
 *   GET/PUT /members                 → مزامنة الأعضاء والنشاطات المجدولة
 *   /chat/*                          → دردشة الأعضاء والوسائط
 *   /feed/*                          → منشورات نشاطات النادي (النشر للقائد فقط، العرض للضيوف والأعضاء)
 *   /join-requests/*                 → طلبات الانضمام للنادي + قرار القائد + إرسال بريد إلكتروني
 *   /ideas/*                         → أفكار ومشاريع الأعضاء بالتصويت (للأعضاء فقط)
 */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,PUT,POST,PATCH,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'content-type,x-sync-key,x-chat-auth,x-guest-id,range',
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
  const head = b64url(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claim = b64url(enc.encode(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })));
  const pem = account.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), c => c.charCodeAt(0));
  const signingKey = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', signingKey, enc.encode(`${head}.${claim}`));
  const assertion = `${head}.${claim}.${b64url(signature)}`;
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  if (!tokenResponse.ok) throw new Error(`OAuth failed: ${tokenResponse.status}`);
  const token = (await tokenResponse.json()).access_token;
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ validate_only: validateOnly, message: { topic: 'epc_activities', android: { priority: 'high', ttl: '86400s' }, data } }),
  });
  if (!response.ok) throw new Error(`FCM failed: ${response.status}`);
  return await response.json();
}

const chatIdPattern = /^[a-zA-Z0-9_-]{1,100}$/;

async function chatActor(request, env) {
  try {
    const rawHeader = request.headers.get('x-chat-auth') || '';
    if (!rawHeader) return null;
    const creds = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(rawHeader), c => c.charCodeAt(0))));
    if (typeof creds.reg !== 'string' || typeof creds.password !== 'string' || !creds.reg || !creds.password) return null;
    if (env.CHAT_LEADER_REG && env.CHAT_LEADER_PASS && creds.reg === atob(env.CHAT_LEADER_REG) && creds.password === atob(env.CHAT_LEADER_PASS)) {
      const obj = await env.EPC_BUCKET.get('members.json');
      const leader = obj ? (await obj.json()).leaderProfile : null;
      return {
        id: creds.reg,
        name: leader ? `${leader.firstName || ''} ${leader.lastName || ''}`.trim() || 'القائد' : 'القائد',
        isLeader: true,
        role: 'القائد',
      };
    }
    const obj = await env.EPC_BUCKET.get('members.json');
    if (!obj) return null;
    const data = await obj.json();
    const member = (data.members || []).find(m => m.regNumber === creds.reg && m.password === creds.password);
    if (!member) return null;
    return {
      id: creds.reg,
      name: `${member.firstName || ''} ${member.lastName || ''}`.trim() || 'عضو',
      isLeader: false,
      role: member.role || 'عضو',
    };
  } catch (_) {
    return null;
  }
}

async function chatMac(env, data) {
  if (!env.CHAT_MEDIA_SECRET) throw new Error('chat media key missing');
  const key = await crypto.subtle.importKey('raw', enc.encode(env.CHAT_MEDIA_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return b64url(await crypto.subtle.sign('HMAC', key, enc.encode(data)));
}

async function mediaUrl(env, origin, id) {
  const expiry = (Math.floor(Date.now() / 1800000) + 1) * 1800;
  const sig = await chatMac(env, `${id}:${expiry}`);
  return `${origin}/chat/media/${encodeURIComponent(id)}?exp=${expiry}&sig=${sig}`;
}

async function serveR2Media(request, env, r2Key, url, isPublic = false) {
  const meta = await env.EPC_BUCKET.head(r2Key);
  if (!meta) return json({ error: 'not found' }, 404);
  const match = /^bytes=(\d+)-(\d*)$/.exec(request.headers.get('range') || '');
  let start, end;
  if (match) {
    start = Number(match[1]);
    end = match[2] ? Math.min(Number(match[2]), meta.size - 1) : meta.size - 1;
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start > end || start >= meta.size) {
      return new Response(null, { status: 416, headers: { ...CORS, 'content-range': `bytes */${meta.size}` } });
    }
  }
  const obj = await env.EPC_BUCKET.get(r2Key, match ? { range: { offset: start, length: end - start + 1 } } : {});
  if (!obj) return json({ error: 'not found' }, 404);
  const headers = new Headers(CORS);
  headers.set('content-type', obj.httpMetadata?.contentType || 'application/octet-stream');
  headers.set('accept-ranges', 'bytes');
  headers.set('content-length', String(match ? end - start + 1 : meta.size));
  if (match) headers.set('content-range', `bytes ${start}-${end}/${meta.size}`);
  headers.set('content-disposition', url.searchParams.get('download') === '1' ? 'attachment' : 'inline');
  headers.set('cache-control', isPublic ? 'public, max-age=86400' : 'private, no-store');
  return new Response(obj.body, { headers, status: match ? 206 : 200 });
}

async function serveChatMedia(request, env, id, url) {
  if (!chatIdPattern.test(id)) return json({ error: 'not found' }, 404);
  const exp = Number(url.searchParams.get('exp'));
  const sig = url.searchParams.get('sig') || '';
  if (!Number.isSafeInteger(exp) || exp < Math.floor(Date.now() / 1000) || exp > Math.floor(Date.now() / 1000) + 3700 || sig !== await chatMac(env, `${id}:${exp}`)) {
    return json({ error: 'unauthorized' }, 401);
  }
  if (!env.CHAT_MEDIA_SECRET) return json({ error: 'not configured' }, 503);
  return serveR2Media(request, env, `chat/media/${id}`, url, false);
}

async function chatHandler(request, env, url, ctx) {
  const actor = await chatActor(request, env);
  if (!actor) return json({ error: 'invalid account' }, 401);
  const path = url.pathname;
  if (path === '/chat/media' && request.method === 'POST') {
    const type = (request.headers.get('content-type') || '').split(';')[0];
    if (!/^(image\/(jpeg|png|webp|gif)|video\/(mp4|webm|quicktime)|audio\/(mp4|mpeg|ogg|wav|webm|x-m4a))$/.test(type)) return json({ error: 'unsupported media' }, 415);
    const length = Number(request.headers.get('content-length') || 0);
    if (length > 15 * 1024 * 1024) return json({ error: 'file exceeds 15 MB' }, 413);
    const bytes = await request.arrayBuffer();
    if (!bytes.byteLength || bytes.byteLength > 15 * 1024 * 1024) return json({ error: 'file exceeds 15 MB' }, 413);
    const id = crypto.randomUUID();
    await env.EPC_BUCKET.put(`chat/media/${id}`, bytes, { httpMetadata: { contentType: type }, customMetadata: { owner: actor.id } });
    return json({ id, type, size: bytes.byteLength });
  }
  if (path === '/chat/messages' && request.method === 'POST') {
    let data; try { data = await request.json(); } catch (_) { return json({ error: 'invalid json' }, 400); }
    const text = typeof data.text === 'string' ? data.text.trim().slice(0, 4000) : '';
    const media = typeof data.media === 'string' && chatIdPattern.test(data.media) ? data.media : '';
    if (!text && !media) return json({ error: 'empty message' }, 400);
    let mediaType = '';
    if (media) {
      const obj = await env.EPC_BUCKET.head(`chat/media/${media}`);
      if (!obj || obj.customMetadata?.owner !== actor.id) return json({ error: 'invalid media' }, 400);
      mediaType = obj.httpMetadata?.contentType || '';
    }
    const id = `${Date.now().toString().padStart(13, '0')}_${crypto.randomUUID()}`;
    const message = {
      id,
      authorId: actor.id,
      authorName: actor.name,
      text,
      media,
      mediaType,
      replyId: typeof data.replyId === 'string' && chatIdPattern.test(data.replyId) ? data.replyId : '',
      replyText: typeof data.replyText === 'string' ? data.replyText.slice(0, 200) : '',
      replyName: typeof data.replyName === 'string' ? data.replyName.slice(0, 100) : '',
      createdAt: new Date().toISOString(),
    };
    await env.EPC_BUCKET.put(`chat/messages/${id}`, JSON.stringify(message), { httpMetadata: { contentType: 'application/json' } });
    if (ctx && env.FIREBASE_SERVICE_ACCOUNT) {
      const senderHash = b64url(await crypto.subtle.digest('SHA-256', enc.encode(actor.id)));
      ctx.waitUntil(sendActivityPush(env, { kind: 'chat', id, senderHash }).catch(e => console.error('chat push failed', e.message)));
    }
    return json({ ok: true, id });
  }
  if (path.startsWith('/chat/messages/') && request.method === 'DELETE') {
    const id = path.slice('/chat/messages/'.length);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid message' }, 400);
    const object = await env.EPC_BUCKET.get(`chat/messages/${id}`);
    if (!object) return json({ ok: true });
    const message = await object.json();
    if (message.authorId !== actor.id) return json({ error: 'only author can delete' }, 403);
    await env.EPC_BUCKET.delete(`chat/messages/${id}`);
    if (typeof message.media === 'string' && chatIdPattern.test(message.media)) {
      await env.EPC_BUCKET.delete(`chat/media/${message.media}`);
    }
    let cursor;
    do {
      const reactions = await env.EPC_BUCKET.list({ prefix: `chat/reactions/${id}/`, limit: 1000, cursor });
      if (reactions.objects.length) await Promise.all(reactions.objects.map(r => env.EPC_BUCKET.delete(r.key)));
      cursor = reactions.truncated ? reactions.cursor : undefined;
    } while (cursor);
    return json({ ok: true });
  }
  if (path === '/chat/react' && request.method === 'POST') {
    let data; try { data = await request.json(); } catch (_) { return json({ error: 'invalid json' }, 400); }
    if (!chatIdPattern.test(data.id || '') || !['', '❤️', '👍', '😂', '🎉', '😮'].includes(data.emoji)) return json({ error: 'invalid reaction' }, 400);
    if (!await env.EPC_BUCKET.head(`chat/messages/${data.id}`)) return json({ error: 'not found' }, 404);
    const hash = b64url(await crypto.subtle.digest('SHA-256', enc.encode(actor.id)));
    const key = `chat/reactions/${data.id}/${hash}`;
    if (!data.emoji) await env.EPC_BUCKET.delete(key);
    else await env.EPC_BUCKET.put(key, JSON.stringify({ emoji: data.emoji, authorId: actor.id }));
    return json({ ok: true });
  }
  if (path === '/chat/messages' && request.method === 'GET') {
    let cursor, keys = [];
    do {
      const page = await env.EPC_BUCKET.list({ prefix: 'chat/messages/', limit: 1000, cursor });
      keys.push(...page.objects.map(o => o.key));
      cursor = page.truncated ? page.cursor : undefined;
    } while (cursor && keys.length < 10000);
    keys = keys.slice(-60);
    const messages = await Promise.all(keys.map(async key => {
      const obj = await env.EPC_BUCKET.get(key);
      if (!obj) return null;
      const msg = await obj.json();
      if (msg.replyId && !await env.EPC_BUCKET.head(`chat/messages/${msg.replyId}`)) { msg.replyId = ''; msg.replyText = ''; msg.replyName = ''; }
      if (msg.media) msg.mediaUrl = await mediaUrl(env, url.origin, msg.media);
      const reactions = await env.EPC_BUCKET.list({ prefix: `chat/reactions/${msg.id}/`, limit: 1000 });
      msg.reactions = (await Promise.all(reactions.objects.map(async r => { const ro = await env.EPC_BUCKET.get(r.key); return ro ? await ro.json() : null; }))).filter(Boolean);
      return msg;
    }));
    return json({ messages: messages.filter(Boolean), me: actor.id });
  }
  return json({ error: 'not found' }, 404);
}

// ── 1) منشورات نشاطات النادي العامة (النشر للقائد فقط، العرض والتفاعل للجميع) ──
async function feedHandler(request, env, url) {
  const path = url.pathname;
  const actor = await chatActor(request, env);
  const guestId = (request.headers.get('x-guest-id') || '').trim().slice(0, 80);
  const viewerId = actor ? `member:${actor.id}` : (guestId ? `guest:${guestId}` : '');

  // رفع صورة أو فيديو لمنشور نشاط (القائد فقط)
  if (path === '/feed/media' && request.method === 'POST') {
    if (!actor || !actor.isLeader) return json({ error: 'leader only' }, 403);
    const type = (request.headers.get('content-type') || '').split(';')[0];
    if (!/^(image\/(jpeg|png|webp|gif)|video\/(mp4|webm|quicktime))$/.test(type)) {
      return json({ error: 'unsupported media' }, 415);
    }
    const length = Number(request.headers.get('content-length') || 0);
    if (length > 25 * 1024 * 1024) return json({ error: 'file exceeds 25 MB' }, 413);
    const bytes = await request.arrayBuffer();
    if (!bytes.byteLength || bytes.byteLength > 25 * 1024 * 1024) return json({ error: 'file exceeds 25 MB' }, 413);
    const id = crypto.randomUUID();
    await env.EPC_BUCKET.put(`feed/media/${id}`, bytes, {
      httpMetadata: { contentType: type },
      customMetadata: { owner: actor.id },
    });
    return json({ id, type, size: bytes.byteLength, mediaUrl: `${url.origin}/feed/media/${encodeURIComponent(id)}` });
  }

  // نشر منشور نشاط جديد (القائد فقط)
  if (path === '/feed/posts' && request.method === 'POST') {
    if (!actor || !actor.isLeader) return json({ error: 'leader only' }, 403);
    let data; try { data = await request.json(); } catch (_) { return json({ error: 'invalid json' }, 400); }
    const title = typeof data.title === 'string' ? data.title.trim().slice(0, 160) : '';
    const caption = typeof data.caption === 'string' ? data.caption.trim().slice(0, 4000) : '';
    const category = typeof data.category === 'string' && data.category.trim() ? data.category.trim().slice(0, 40) : 'فعالية';
    const location = typeof data.location === 'string' ? data.location.trim().slice(0, 120) : '';
    const mediaId = typeof data.mediaId === 'string' && chatIdPattern.test(data.mediaId) ? data.mediaId : '';
    if (!title && !caption && !mediaId) return json({ error: 'empty post' }, 400);
    let mediaType = '';
    if (mediaId) {
      const obj = await env.EPC_BUCKET.head(`feed/media/${mediaId}`);
      if (!obj) return json({ error: 'invalid media' }, 400);
      mediaType = obj.httpMetadata?.contentType || '';
    }
    const id = `${Date.now().toString().padStart(13, '0')}_${crypto.randomUUID()}`;
    const post = {
      id,
      title,
      caption,
      category,
      location,
      mediaId,
      mediaType,
      authorId: actor.id,
      authorName: actor.name,
      likes: [],
      comments: [],
      sharesCount: 0,
      createdAt: new Date().toISOString(),
    };
    await env.EPC_BUCKET.put(`feed/posts/${id}`, JSON.stringify(post), { httpMetadata: { contentType: 'application/json' } });
    return json({
      ok: true,
      post: {
        ...post,
        mediaUrl: mediaId ? `${url.origin}/feed/media/${encodeURIComponent(mediaId)}` : '',
        likesCount: 0,
        likedByMe: false,
        commentsCount: 0,
      },
    });
  }

  // جلب منشورات نشاطات النادي (للضيوف والأعضاء والقائد)
  if (path === '/feed/posts' && request.method === 'GET') {
    let cursor, keys = [];
    do {
      const page = await env.EPC_BUCKET.list({ prefix: 'feed/posts/', limit: 1000, cursor });
      keys.push(...page.objects.map(o => o.key));
      cursor = page.truncated ? page.cursor : undefined;
    } while (cursor && keys.length < 2000);
    keys = keys.slice(-80).reverse();
    const posts = (await Promise.all(keys.map(async key => {
      const obj = await env.EPC_BUCKET.get(key);
      if (!obj) return null;
      const p = await obj.json();
      const likes = Array.isArray(p.likes) ? p.likes : [];
      const comments = Array.isArray(p.comments) ? p.comments : [];
      return {
        id: p.id,
        title: p.title || '',
        caption: p.caption || '',
        category: p.category || 'فعالية',
        location: p.location || '',
        mediaId: p.mediaId || '',
        mediaType: p.mediaType || '',
        mediaUrl: p.mediaId ? `${url.origin}/feed/media/${encodeURIComponent(p.mediaId)}` : '',
        authorName: p.authorName || 'قائد النادي',
        createdAt: p.createdAt,
        likesCount: likes.length,
        likedByMe: viewerId ? likes.includes(viewerId) : false,
        commentsCount: comments.length,
        comments,
        sharesCount: Number(p.sharesCount) || 0,
      };
    }))).filter(Boolean);
    return json({ posts });
  }

  // حذف منشور (القائد فقط)
  const deleteMatch = /^\/feed\/posts\/([^/]+)$/.exec(path);
  if (deleteMatch && request.method === 'DELETE') {
    if (!actor || !actor.isLeader) return json({ error: 'leader only' }, 403);
    const id = decodeURIComponent(deleteMatch[1]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid post' }, 400);
    const obj = await env.EPC_BUCKET.get(`feed/posts/${id}`);
    if (!obj) return json({ ok: true });
    const post = await obj.json();
    await env.EPC_BUCKET.delete(`feed/posts/${id}`);
    if (post.mediaId && chatIdPattern.test(post.mediaId)) {
      await env.EPC_BUCKET.delete(`feed/media/${post.mediaId}`);
    }
    return json({ ok: true });
  }

  // إعجاب (قلب) على منشور
  const likeMatch = /^\/feed\/posts\/([^/]+)\/like$/.exec(path);
  if (likeMatch && request.method === 'POST') {
    const id = decodeURIComponent(likeMatch[1]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid post' }, 400);
    if (!viewerId) return json({ error: 'viewer id required' }, 400);
    const obj = await env.EPC_BUCKET.get(`feed/posts/${id}`);
    if (!obj) return json({ error: 'not found' }, 404);
    const post = await obj.json();
    const likes = Array.isArray(post.likes) ? post.likes : [];
    const idx = likes.indexOf(viewerId);
    let liked;
    if (idx >= 0) { likes.splice(idx, 1); liked = false; }
    else { likes.push(viewerId); liked = true; }
    post.likes = likes;
    await env.EPC_BUCKET.put(`feed/posts/${id}`, JSON.stringify(post), { httpMetadata: { contentType: 'application/json' } });
    return json({ ok: true, liked, likesCount: likes.length });
  }

  // تعليق على منشور
  const commentMatch = /^\/feed\/posts\/([^/]+)\/comments$/.exec(path);
  if (commentMatch && request.method === 'POST') {
    const id = decodeURIComponent(commentMatch[1]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid post' }, 400);
    let data; try { data = await request.json(); } catch (_) { return json({ error: 'invalid json' }, 400); }
    const text = typeof data.text === 'string' ? data.text.trim().slice(0, 1000) : '';
    if (!text) return json({ error: 'empty comment' }, 400);
    const obj = await env.EPC_BUCKET.get(`feed/posts/${id}`);
    if (!obj) return json({ error: 'not found' }, 404);
    const post = await obj.json();
    const authorName = actor ? actor.name : ((typeof data.authorName === 'string' ? data.authorName.trim().slice(0, 60) : '') || 'ضيف');
    const comment = {
      id: `${Date.now()}_${crypto.randomUUID().slice(0, 8)}`,
      authorId: viewerId || 'guest',
      authorName,
      authorRole: actor ? actor.role : 'ضيف',
      text,
      createdAt: new Date().toISOString(),
    };
    post.comments = [...(Array.isArray(post.comments) ? post.comments : []), comment].slice(-300);
    await env.EPC_BUCKET.put(`feed/posts/${id}`, JSON.stringify(post), { httpMetadata: { contentType: 'application/json' } });
    return json({ ok: true, comment, commentsCount: post.comments.length });
  }

  // حذف تعليق (القائد أو صاحب التعليق)
  const delCommentMatch = /^\/feed\/posts\/([^/]+)\/comments\/([^/]+)$/.exec(path);
  if (delCommentMatch && request.method === 'DELETE') {
    const id = decodeURIComponent(delCommentMatch[1]);
    const cid = decodeURIComponent(delCommentMatch[2]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid post' }, 400);
    const obj = await env.EPC_BUCKET.get(`feed/posts/${id}`);
    if (!obj) return json({ error: 'not found' }, 404);
    const post = await obj.json();
    const comments = Array.isArray(post.comments) ? post.comments : [];
    const target = comments.find(c => c.id === cid);
    if (!target) return json({ ok: true });
    if (!(actor && actor.isLeader) && target.authorId !== viewerId) return json({ error: 'forbidden' }, 403);
    post.comments = comments.filter(c => c.id !== cid);
    await env.EPC_BUCKET.put(`feed/posts/${id}`, JSON.stringify(post), { httpMetadata: { contentType: 'application/json' } });
    return json({ ok: true, commentsCount: post.comments.length });
  }

  // تسجيل مشاركة لمنشور
  const shareMatch = /^\/feed\/posts\/([^/]+)\/share$/.exec(path);
  if (shareMatch && request.method === 'POST') {
    const id = decodeURIComponent(shareMatch[1]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid post' }, 400);
    const obj = await env.EPC_BUCKET.get(`feed/posts/${id}`);
    if (!obj) return json({ error: 'not found' }, 404);
    const post = await obj.json();
    post.sharesCount = (Number(post.sharesCount) || 0) + 1;
    await env.EPC_BUCKET.put(`feed/posts/${id}`, JSON.stringify(post), { httpMetadata: { contentType: 'application/json' } });
    return json({ ok: true, sharesCount: post.sharesCount });
  }

  return json({ error: 'not found' }, 404);
}

// ── 2) إرسال بريد القبول أو الرفض للمتقدم للانضمام ────────────────────────
function buildDecisionEmail(req, decision, note) {
  const fullName = `${req.firstName} ${req.lastName}`.trim();
  const approved = decision === 'approved';
  const subject = approved
    ? '🎉 مبروك! تم قبول طلب انضمامك إلى نادي رواد الاقتصاد (EPC)'
    : 'بخصوص طلب انضمامك إلى نادي رواد الاقتصاد (EPC)';
  const safeNote = (note || '').replace(/[<>&]/g, c => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' }[c]));
  const html = `
  <div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;background:#f4f6f9;padding:24px;">
    <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:18px;overflow:hidden;border:1px solid #e4e9ed;">
      <div style="background:linear-gradient(135deg,#08172A,#132A43);padding:26px 24px;text-align:center;">
        <h1 style="margin:0;color:#ffffff;font-size:22px;">نادي رواد الاقتصاد — EPC</h1>
        <p style="margin:6px 0 0;color:#E7CD98;font-size:12px;letter-spacing:1.5px;">ECONOMICS PIONEERS CLUB</p>
      </div>
      <div style="padding:26px 24px;color:#101D30;line-height:1.8;font-size:15px;">
        <p>مرحباً <strong>${fullName}</strong>،</p>
        ${approved ? `
          <div style="background:#ecfdf5;border:1px solid #a7f3d0;border-radius:12px;padding:16px;margin:16px 0;color:#065f46;">
            <strong>يسعدنا إبلاغك بقبول طلب انضمامك رسمياً إلى نادي رواد الاقتصاد!</strong>
          </div>
          <p>يمكنك الآن تسجيل الدخول إلى تطبيق النادي باستخدام بياناتك التي اخترتها عند التقديم:</p>
          <ul style="background:#f8fafc;border-radius:12px;padding:14px 28px;border:1px solid #e2e8f0;">
            <li><strong>رقم التسجيل:</strong> ${req.regNumber}</li>
            <li><strong>التخصص:</strong> ${req.specialization}</li>
            <li><strong>المستوى:</strong> ${req.level}</li>
          </ul>
          ${safeNote ? `<p><strong>ملاحظة القائد:</strong> ${safeNote}</p>` : ''}
          <p>نتطلع لمشاركتك الفاعلة معنا في الفعاليات والأفكار والمشاريع القادمة.</p>
        ` : `
          <div style="background:#fef2f2;border:1px solid #fecaca;border-radius:12px;padding:16px;margin:16px 0;color:#991b1b;">
            نشكرك على اهتمامك بالانضمام إلى نادي رواد الاقتصاد. نعتذر لعدم تمكّننا من قبول طلبك في هذه الدورة.
          </div>
          ${safeNote ? `<p><strong>ملاحظة القائد:</strong> ${safeNote}</p>` : ''}
          <p>يمكنك متابعة نشاطات النادي المفتوحة للجميع وإعادة التقديم في الدورات القادمة.</p>
        `}
        <p style="margin-top:24px;color:#667587;font-size:13px;">مع أطيب التحيات،<br>قيادة نادي رواد الاقتصاد — جامعة غيليزان</p>
      </div>
    </div>
  </div>`;
  const text = approved
    ? `مرحباً ${fullName}،\n\nمبروك! تم قبول طلب انضمامك رسمياً إلى نادي رواد الاقتصاد (EPC).\nيمكنك الآن تسجيل الدخول برقم التسجيل: ${req.regNumber} وكلمة المرور التي اخترتها.${note ? `\nملاحظة القائد: ${note}` : ''}\n\nقيادة نادي رواد الاقتصاد`
    : `مرحباً ${fullName}،\n\nنشكرك على اهتمامك بنادي رواد الاقتصاد (EPC). نعتذر لعدم قبول طلبك في هذه الدورة.${note ? `\nملاحظة القائد: ${note}` : ''}\n\nقيادة نادي رواد الاقتصاد`;
  return { subject, html, text };
}

async function sendDecisionEmail(env, req, decision, note) {
  if (!req.email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(req.email)) {
    return { emailSent: false, emailError: 'invalid email' };
  }
  const { subject, html, text } = buildDecisionEmail(req, decision, note);
  const fromAddress = env.MAIL_FROM || 'noreply@epc-club.dz';
  const fromName = 'نادي رواد الاقتصاد — EPC';

  // 1) Resend API (إن كان مضبوطاً)
  if (env.RESEND_API_KEY) {
    try {
      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, 'content-type': 'application/json' },
        body: JSON.stringify({ from: `${fromName} <${fromAddress}>`, to: [req.email], subject, html, text }),
      });
      if (r.ok) return { emailSent: true, provider: 'resend' };
      return { emailSent: false, emailError: `resend:${r.status}` };
    } catch (e) {
      return { emailSent: false, emailError: `resend:${e.message}` };
    }
  }

  // 2) Brevo API (إن كان مضبوطاً)
  if (env.BREVO_API_KEY) {
    try {
      const r = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: { 'api-key': env.BREVO_API_KEY, 'content-type': 'application/json' },
        body: JSON.stringify({
          sender: { name: fromName, email: fromAddress },
          to: [{ email: req.email, name: `${req.firstName} ${req.lastName}`.trim() }],
          subject,
          htmlContent: html,
          textContent: text,
        }),
      });
      if (r.ok) return { emailSent: true, provider: 'brevo' };
      return { emailSent: false, emailError: `brevo:${r.status}` };
    } catch (e) {
      return { emailSent: false, emailError: `brevo:${e.message}` };
    }
  }

  // 3) Webhook مخصص لإرسال البريد إن كان مضبوطاً
  if (env.EMAIL_WEBHOOK_URL) {
    try {
      const r = await fetch(env.EMAIL_WEBHOOK_URL, {
        method: 'POST',
        headers: { 'content-type': 'application/json', ...(env.EMAIL_WEBHOOK_SECRET ? { 'x-webhook-secret': env.EMAIL_WEBHOOK_SECRET } : {}) },
        body: JSON.stringify({ to: req.email, subject, html, text, decision, applicant: `${req.firstName} ${req.lastName}`.trim() }),
      });
      if (r.ok) return { emailSent: true, provider: 'webhook' };
      return { emailSent: false, emailError: `webhook:${r.status}` };
    } catch (e) {
      return { emailSent: false, emailError: `webhook:${e.message}` };
    }
  }

  // 4) MailChannels fallback على Cloudflare Workers
  try {
    const r = await fetch('https://api.mailchannels.net/tx/v1/send', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        personalizations: [{ to: [{ email: req.email, name: `${req.firstName} ${req.lastName}`.trim() }] }],
        from: { email: fromAddress, name: fromName },
        subject,
        content: [
          { type: 'text/plain', value: text },
          { type: 'text/html', value: html },
        ],
      }),
    });
    if (r.ok) return { emailSent: true, provider: 'mailchannels' };
    return { emailSent: false, emailError: `mailchannels:${r.status}` };
  } catch (e) {
    return { emailSent: false, emailError: `mailchannels:${e.message}` };
  }
}

// ── 3) طلبات الانضمام للنادي ───────────────────────────────────────────────
async function joinRequestsHandler(request, env, url) {
  const path = url.pathname;

  // إرسال طلب انضمام جديد (متاح للضيوف بدون حساب)
  if (path === '/join-requests' && request.method === 'POST') {
    let data; try { data = await request.json(); } catch (_) { return json({ error: 'invalid json' }, 400); }
    const firstName = String(data.firstName || '').trim().slice(0, 60);
    const lastName = String(data.lastName || '').trim().slice(0, 60);
    const email = String(data.email || '').trim().slice(0, 120);
    const phone = String(data.phone || '').trim().slice(0, 40);
    const branch = String(data.branch || '').trim().slice(0, 120);
    const specialization = String(data.specialization || '').trim().slice(0, 120);
    const level = String(data.level || '').trim().slice(0, 60);
    const year = String(data.year || '2026/2027').trim().slice(0, 20);
    const regNumber = String(data.regNumber || '').trim().slice(0, 40);
    const password = String(data.password || '').slice(0, 60);
    const motivation = String(data.motivation || '').trim().slice(0, 1500);
    const photo = typeof data.photo === 'string' && data.photo.length < 1500000 ? data.photo : '';

    if (!firstName || !lastName || !email || !phone || !regNumber || password.length < 4) {
      return json({ error: 'يرجى تعبئة جميع الحقول المطلوبة' }, 400);
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ error: 'صيغة البريد الإلكتروني غير صحيحة' }, 400);
    }

    // التحقق من عدم وجود رقم التسجيل مسبقاً
    const membersObj = await env.EPC_BUCKET.get('members.json');
    if (membersObj) {
      const mData = await membersObj.json();
      if ((mData.members || []).some(m => m.regNumber === regNumber)) {
        return json({ error: 'رقم التسجيل مسجّل بالفعل كعضو في النادي' }, 409);
      }
    }

    const id = `${Date.now().toString().padStart(13, '0')}_${crypto.randomUUID().slice(0, 8)}`;
    const joinReq = {
      id,
      firstName,
      lastName,
      email,
      phone,
      branch,
      specialization,
      level,
      year,
      regNumber,
      password,
      motivation,
      photo,
      status: 'pending',
      leaderNote: '',
      createdAt: new Date().toISOString(),
      reviewedAt: '',
    };
    await env.EPC_BUCKET.put(`join_requests/${id}`, JSON.stringify(joinReq), {
      httpMetadata: { contentType: 'application/json' },
    });
    return json({
      ok: true,
      request: {
        id: joinReq.id,
        firstName: joinReq.firstName,
        lastName: joinReq.lastName,
        email: joinReq.email,
        regNumber: joinReq.regNumber,
        status: joinReq.status,
        createdAt: joinReq.createdAt,
      },
    });
  }

  // استعلام الضيف عن حالة طلبه
  const statusMatch = /^\/join-requests\/status\/([^/]+)$/.exec(path);
  if (statusMatch && request.method === 'GET') {
    const id = decodeURIComponent(statusMatch[1]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid id' }, 400);
    const obj = await env.EPC_BUCKET.get(`join_requests/${id}`);
    if (!obj) return json({ error: 'not found' }, 404);
    const r = await obj.json();
    return json({
      id: r.id,
      firstName: r.firstName,
      lastName: r.lastName,
      email: r.email,
      regNumber: r.regNumber,
      status: r.status,
      leaderNote: r.leaderNote || '',
      createdAt: r.createdAt,
      reviewedAt: r.reviewedAt || '',
    });
  }

  // المسارات التالية للقائد فقط
  const actor = await chatActor(request, env);
  if (!actor || !actor.isLeader) return json({ error: 'leader only' }, 403);

  // عرض جميع طلبات الانضمام للقائد
  if (path === '/join-requests' && request.method === 'GET') {
    let cursor, keys = [];
    do {
      const page = await env.EPC_BUCKET.list({ prefix: 'join_requests/', limit: 1000, cursor });
      keys.push(...page.objects.map(o => o.key));
      cursor = page.truncated ? page.cursor : undefined;
    } while (cursor && keys.length < 1000);
    keys = keys.slice(-200).reverse();
    const requests = (await Promise.all(keys.map(async key => {
      const obj = await env.EPC_BUCKET.get(key);
      if (!obj) return null;
      const r = await obj.json();
      return { ...r, password: '' };
    }))).filter(Boolean);
    const pendingCount = requests.filter(r => r.status === 'pending').length;
    return json({ requests, pendingCount });
  }

  // قبول أو رفض طلب انضمام (القائد فقط) + إضافة العضو عند القبول + إرسال بريد تلقائي
  const decideMatch = /^\/join-requests\/([^/]+)\/decide$/.exec(path);
  if (decideMatch && request.method === 'POST') {
    const id = decodeURIComponent(decideMatch[1]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid id' }, 400);
    let data; try { data = await request.json(); } catch (_) { return json({ error: 'invalid json' }, 400); }
    const decision = data.decision;
    const note = typeof data.note === 'string' ? data.note.trim().slice(0, 500) : '';
    if (!['approved', 'rejected'].includes(decision)) return json({ error: 'invalid decision' }, 400);

    const obj = await env.EPC_BUCKET.get(`join_requests/${id}`);
    if (!obj) return json({ error: 'not found' }, 404);
    const joinReq = await obj.json();

    let memberAdded = false;
    if (decision === 'approved' && joinReq.status !== 'approved') {
      const nowIso = new Date().toISOString();
      const newMember = {
        id: `m_${Date.now()}_${crypto.randomUUID().slice(0, 6)}`,
        firstName: joinReq.firstName,
        lastName: joinReq.lastName,
        specialization: joinReq.specialization,
        branch: joinReq.branch,
        level: joinReq.level,
        year: joinReq.year || '2026/2027',
        regNumber: joinReq.regNumber,
        password: joinReq.password,
        phone: joinReq.phone,
        email: joinReq.email,
        role: 'عضو',
        photo: joinReq.photo || '',
        joinedAt: nowIso,
        updatedAt: nowIso,
      };
      for (let attempt = 0; attempt < 8; attempt++) {
        const prior = await env.EPC_BUCKET.get('members.json');
        const oldData = prior ? await prior.json() : { members: [], deleted: [], activities: [], deletedActivities: [] };
        const exists = (oldData.members || []).some(m => m.regNumber === newMember.regNumber);
        const merged = exists
          ? oldData
          : mergeSnapshots(oldData, { members: [...(oldData.members || []), newMember] });
        const result = await env.EPC_BUCKET.put('members.json', JSON.stringify(merged), {
          onlyIf: prior ? { etagMatches: prior.etag } : { etagDoesNotMatch: '*' },
          httpMetadata: { contentType: 'application/json; charset=utf-8' },
        });
        if (result) { memberAdded = !exists; break; }
      }
    }

    joinReq.status = decision;
    joinReq.leaderNote = note;
    joinReq.reviewedAt = new Date().toISOString();
    await env.EPC_BUCKET.put(`join_requests/${id}`, JSON.stringify(joinReq), {
      httpMetadata: { contentType: 'application/json' },
    });

    const emailResult = await sendDecisionEmail(env, joinReq, decision, note);
    const emailPreview = buildDecisionEmail(joinReq, decision, note);
    return json({
      ok: true,
      status: decision,
      memberAdded,
      emailSent: emailResult.emailSent,
      emailError: emailResult.emailError || '',
      emailSubject: emailPreview.subject,
      emailText: emailPreview.text,
    });
  }

  return json({ error: 'not found' }, 404);
}

// ── 4) قسم الأفكار والمشاريع بالتصويت (خاص بأعضاء النادي والقائد فقط) ──────
async function ideasHandler(request, env, url) {
  const actor = await chatActor(request, env);
  if (!actor) return json({ error: 'members only' }, 401);
  const path = url.pathname;

  // جلب قائمة الأفكار والمشاريع
  if (path === '/ideas' && request.method === 'GET') {
    let cursor, keys = [];
    do {
      const page = await env.EPC_BUCKET.list({ prefix: 'ideas/', limit: 1000, cursor });
      keys.push(...page.objects.map(o => o.key));
      cursor = page.truncated ? page.cursor : undefined;
    } while (cursor && keys.length < 1000);
    keys = keys.slice(-200).reverse();
    const ideas = (await Promise.all(keys.map(async key => {
      const obj = await env.EPC_BUCKET.get(key);
      if (!obj) return null;
      const item = await obj.json();
      const votes = Array.isArray(item.votes) ? item.votes : [];
      const comments = Array.isArray(item.comments) ? item.comments : [];
      return {
        id: item.id,
        title: item.title,
        description: item.description,
        category: item.category || 'مشروع',
        expectedImpact: item.expectedImpact || '',
        status: item.status || 'proposed',
        authorId: item.authorId,
        authorName: item.authorName,
        authorRole: item.authorRole || 'عضو',
        votesCount: votes.length,
        votedByMe: votes.includes(actor.id),
        commentsCount: comments.length,
        comments,
        isMine: item.authorId === actor.id,
        createdAt: item.createdAt,
      };
    }))).filter(Boolean);
    return json({ ideas });
  }

  // نشر فكرة أو مشروع جديد
  if (path === '/ideas' && request.method === 'POST') {
    let data; try { data = await request.json(); } catch (_) { return json({ error: 'invalid json' }, 400); }
    const title = String(data.title || '').trim().slice(0, 140);
    const description = String(data.description || '').trim().slice(0, 3000);
    const category = String(data.category || 'مشروع').trim().slice(0, 40);
    const expectedImpact = String(data.expectedImpact || '').trim().slice(0, 300);
    if (!title || !description) return json({ error: 'عنوان الفكرة ووصفها مطلوبان' }, 400);
    const id = `${Date.now().toString().padStart(13, '0')}_${crypto.randomUUID().slice(0, 8)}`;
    const idea = {
      id,
      title,
      description,
      category,
      expectedImpact,
      status: 'proposed',
      authorId: actor.id,
      authorName: actor.name,
      authorRole: actor.role,
      votes: [actor.id],
      comments: [],
      createdAt: new Date().toISOString(),
    };
    await env.EPC_BUCKET.put(`ideas/${id}`, JSON.stringify(idea), {
      httpMetadata: { contentType: 'application/json' },
    });
    return json({ ok: true, id, idea: { ...idea, votesCount: 1, votedByMe: true, commentsCount: 0, isMine: true } });
  }

  // التصويت لفكرة / إلغاء التصويت
  const voteMatch = /^\/ideas\/([^/]+)\/vote$/.exec(path);
  if (voteMatch && request.method === 'POST') {
    const id = decodeURIComponent(voteMatch[1]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid id' }, 400);
    const obj = await env.EPC_BUCKET.get(`ideas/${id}`);
    if (!obj) return json({ error: 'not found' }, 404);
    const idea = await obj.json();
    const votes = Array.isArray(idea.votes) ? idea.votes : [];
    const idx = votes.indexOf(actor.id);
    let voted;
    if (idx >= 0) { votes.splice(idx, 1); voted = false; }
    else { votes.push(actor.id); voted = true; }
    idea.votes = votes;
    await env.EPC_BUCKET.put(`ideas/${id}`, JSON.stringify(idea), { httpMetadata: { contentType: 'application/json' } });
    return json({ ok: true, voted, votesCount: votes.length });
  }

  // إضافة تعليق على فكرة
  const commentMatch = /^\/ideas\/([^/]+)\/comments$/.exec(path);
  if (commentMatch && request.method === 'POST') {
    const id = decodeURIComponent(commentMatch[1]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid id' }, 400);
    let data; try { data = await request.json(); } catch (_) { return json({ error: 'invalid json' }, 400); }
    const text = String(data.text || '').trim().slice(0, 1000);
    if (!text) return json({ error: 'empty comment' }, 400);
    const obj = await env.EPC_BUCKET.get(`ideas/${id}`);
    if (!obj) return json({ error: 'not found' }, 404);
    const idea = await obj.json();
    const comment = {
      id: `${Date.now()}_${crypto.randomUUID().slice(0, 8)}`,
      authorId: actor.id,
      authorName: actor.name,
      authorRole: actor.role,
      text,
      createdAt: new Date().toISOString(),
    };
    idea.comments = [...(Array.isArray(idea.comments) ? idea.comments : []), comment].slice(-200);
    await env.EPC_BUCKET.put(`ideas/${id}`, JSON.stringify(idea), { httpMetadata: { contentType: 'application/json' } });
    return json({ ok: true, comment, commentsCount: idea.comments.length });
  }

  // تحديث حالة المشروع (القائد فقط)
  const statusMatch = /^\/ideas\/([^/]+)\/status$/.exec(path);
  if (statusMatch && (request.method === 'PATCH' || request.method === 'POST')) {
    if (!actor.isLeader) return json({ error: 'leader only' }, 403);
    const id = decodeURIComponent(statusMatch[1]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid id' }, 400);
    let data; try { data = await request.json(); } catch (_) { return json({ error: 'invalid json' }, 400); }
    if (!['proposed', 'reviewing', 'approved', 'completed'].includes(data.status)) {
      return json({ error: 'invalid status' }, 400);
    }
    const obj = await env.EPC_BUCKET.get(`ideas/${id}`);
    if (!obj) return json({ error: 'not found' }, 404);
    const idea = await obj.json();
    idea.status = data.status;
    await env.EPC_BUCKET.put(`ideas/${id}`, JSON.stringify(idea), { httpMetadata: { contentType: 'application/json' } });
    return json({ ok: true, status: idea.status });
  }

  // حذف فكرة (القائد أو صاحب الفكرة)
  const deleteMatch = /^\/ideas\/([^/]+)$/.exec(path);
  if (deleteMatch && request.method === 'DELETE') {
    const id = decodeURIComponent(deleteMatch[1]);
    if (!chatIdPattern.test(id)) return json({ error: 'invalid id' }, 400);
    const obj = await env.EPC_BUCKET.get(`ideas/${id}`);
    if (!obj) return json({ ok: true });
    const idea = await obj.json();
    if (!actor.isLeader && idea.authorId !== actor.id) return json({ error: 'forbidden' }, 403);
    await env.EPC_BUCKET.delete(`ideas/${id}`);
    return json({ ok: true });
  }

  return json({ error: 'not found' }, 404);
}

// Merge snapshots by stable IDs and timestamps so a stale device cannot erase data.
function mergeSnapshots(oldData, incoming) {
  const date = v => { const n = Date.parse(v || ''); return Number.isFinite(n) ? n : 0; };
  const byId = (a, b, timeField) => {
    const map = new Map();
    for (const item of [...(Array.isArray(a) ? a : []), ...(Array.isArray(b) ? b : [])]) {
      if (!item || typeof item.id !== 'string' || !item.id) continue;
      const current = map.get(item.id);
      if (!current || date(item[timeField]) > date(current[timeField])) map.set(item.id, item);
    }
    return [...map.values()];
  };
  const deleted = byId(oldData.deleted, incoming.deleted, 'at');
  const deletedActivities = byId(oldData.deletedActivities, incoming.deletedActivities, 'at');
  const keep = (items, tombs) => {
    const times = new Map(tombs.map(t => [t.id, date(t.at)]));
    return items.filter(x => !times.has(x.id) || date(x.updatedAt) > times.get(x.id));
  };
  return {
    ...oldData,
    ...incoming,
    members: keep(byId(oldData.members, incoming.members, 'updatedAt'), deleted),
    deleted,
    leaderProfile: incoming.leaderProfile && (!oldData.leaderProfile || date(incoming.leaderProfile.updatedAt) > date(oldData.leaderProfile.updatedAt))
      ? incoming.leaderProfile
      : (oldData.leaderProfile || null),
    activities: keep(byId(oldData.activities, incoming.activities, 'updatedAt'), deletedActivities),
    deletedActivities,
    version: (Number(oldData.version) || 0) + 1,
    updatedAt: new Date().toISOString(),
  };
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

    if (path.startsWith('/chat/media/') && request.method === 'GET') {
      return serveChatMedia(request, env, path.slice('/chat/media/'.length), url);
    }

    // وسائط منشورات النادي متاحة للضيوف والأعضاء
    if (path.startsWith('/feed/media/') && request.method === 'GET') {
      const mediaId = decodeURIComponent(path.slice('/feed/media/'.length));
      if (!chatIdPattern.test(mediaId)) return json({ error: 'not found' }, 404);
      return serveR2Media(request, env, `feed/media/${mediaId}`, url, true);
    }

    if (!env.SYNC_KEY || key !== env.SYNC_KEY) {
      return json({ error: 'unauthorized' }, 401);
    }

    if (path === '/sync-check' && request.method === 'POST') {
      const testKey = `checks/${crypto.randomUUID()}`;
      try {
        const first = await env.EPC_BUCKET.put(testKey, 'first', { onlyIf: { etagDoesNotMatch: '*' } });
        const obj = await env.EPC_BUCKET.get(testKey);
        const bad = await env.EPC_BUCKET.put(testKey, 'bad', { onlyIf: { etagMatches: 'not-an-etag' } });
        const good = await env.EPC_BUCKET.put(testKey, 'second', { onlyIf: { etagMatches: obj.etag } });
        return json({ ok: !!first && !!obj && !bad && !!good });
      } finally { await env.EPC_BUCKET.delete(testKey); }
    }

    if (path.startsWith('/chat/')) return chatHandler(request, env, url, ctx);
    if (path.startsWith('/feed/')) return feedHandler(request, env, url);
    if (path === '/join-requests' || path.startsWith('/join-requests/')) return joinRequestsHandler(request, env, url);
    if (path === '/ideas' || path.startsWith('/ideas/')) return ideasHandler(request, env, url);

    if (path === '/notify' && request.method === 'POST') {
      let input;
      try { input = await request.json(); } catch (_) { return json({ error: 'invalid json' }, 400); }
      if (!input || typeof input.id !== 'string' || !input.id || typeof input.title !== 'string' || !input.title || !['create', 'update', 'delete'].includes(input.operation) || typeof input.at !== 'string') {
        return json({ error: 'invalid activity' }, 400);
      }
      const data = { id: input.id.slice(0, 200), title: input.title.slice(0, 200), place: String(input.place || '').slice(0, 200), at: input.at.slice(0, 50), operation: input.operation };
      try { await sendActivityPush(env, data, input.validate_only === true); return json({ ok: true, validated: input.validate_only === true }); }
      catch (e) { console.error('push failed', e.message); return json({ error: 'push unavailable' }, 502); }
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

      for (let attempt = 0; attempt < 8; attempt++) {
        const prior = await env.EPC_BUCKET.get('members.json');
        const oldData = prior ? await prior.json() : {};
        const merged = mergeSnapshots(oldData, parsed);
        const result = await env.EPC_BUCKET.put('members.json', JSON.stringify(merged), {
          onlyIf: prior ? { etagMatches: prior.etag } : { etagDoesNotMatch: '*' },
          httpMetadata: { contentType: 'application/json; charset=utf-8' },
        });
        if (result) return json({ ok: true, version: merged.version, count: merged.members.length });
      }
      return json({ error: 'sync conflict; retry' }, 409);
    }

    return json({ error: 'method not allowed' }, 405);
  },
};
