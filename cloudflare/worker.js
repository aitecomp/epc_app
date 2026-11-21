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

    // ── تنزيل تطبيق الأندرويد مباشرة (بدون مفتاح) ──────────────────────
    if (path === '/app' || path === '/app.apk') {
      const object = await env.EPC_BUCKET.get('epc-arm64.apk');
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
