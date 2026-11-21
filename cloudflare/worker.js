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
  'Access-Control-Allow-Methods': 'GET,PUT,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'content-type,x-sync-key',
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

export default {
  async fetch(request, env) {
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

    if (!env.SYNC_KEY || key !== env.SYNC_KEY) {
      return json({ error: 'unauthorized' }, 401);
    }

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

      parsed.version = (parsed.version || 0) + 1;
      parsed.updatedAt = new Date().toISOString();

      await env.EPC_BUCKET.put('members.json', JSON.stringify(parsed), {
        httpMetadata: { contentType: 'application/json; charset=utf-8' },
      });

      return json({ ok: true, version: parsed.version, count: parsed.members.length });
    }

    return json({ error: 'method not allowed' }, 405);
  },
};
