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

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';
    const key = request.headers.get('x-sync-key') || url.searchParams.get('key') || '';

    if (path === '/health') return json({ ok: true, service: 'epc-sync' });

    if (!env.SYNC_KEY || key !== env.SYNC_KEY) {
      return json({ error: 'unauthorized' }, 401);
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
