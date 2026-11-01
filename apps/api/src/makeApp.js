import { isConvertibleUrl } from './validateUrl.js';
import { handleMediaUpload } from './mediaIngress.js';

function send(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (c) => {
      raw += c;
      if (raw.length > 8192) reject(new Error('payload_too_large'));
    });
    req.on('end', () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        reject(new Error('invalid_json'));
      }
    });
  });
}

// enqueue: async ({url}) => {id}. db: lihat src/db.js.
// opts.rateLimiter: (key) => boolean. opts.fetch: {queue, mediaDir, token}
// untuk fetch-worker lokal (GET /v1/queue/next + POST /v1/media/:id).
export function makeApp(enqueue, db, { rateLimiter, fetch } = {}) {
  return async (req, res) => {
    const { pathname } = new URL(req.url, 'http://localhost');

    if (req.method === 'GET' && pathname === '/v1/queue/next') {
      if (!fetch || req.headers.authorization !== `Bearer ${fetch.token}`) {
        return send(res, 401, { error: 'unauthorized' });
      }
      const file = fetch.queue.claim();
      if (!file) {
        res.writeHead(204);
        res.end();
        return;
      }
      try {
        await db.setJobStatus(file.id, 'fetching', { url: file.url });
      } catch {
        fetch.queue.release(file);
        return send(res, 503, { error: 'db_unavailable' });
      }
      return send(res, 200, { id: file.id, url: file.url });
    }

    if (req.method === 'POST' && pathname.startsWith('/v1/media/')) {
      if (!fetch) return send(res, 404, { error: 'not_found' });
      const out = await handleMediaUpload(
        req, res, send, db, fetch.mediaDir, fetch.token);
      if (out) fetch.queue.releaseById(decodeURIComponent(
        pathname.slice('/v1/media/'.length)));
      return out;
    }

    if (req.method === 'GET' && pathname === '/v1/articles') {
      if (!db) return send(res, 503, { error: 'db_unavailable' });
      try {
        return send(res, 200, { ids: await db.listArticleIds() });
      } catch {
        return send(res, 503, { error: 'db_unavailable' });
      }
    }

    if (req.method === 'GET' && pathname.startsWith('/v1/articles/')) {
      if (!db) return send(res, 503, { error: 'db_unavailable' });
      const id = decodeURIComponent(pathname.slice('/v1/articles/'.length));
      if (!id) return send(res, 400, { error: 'invalid_id' });
      try {
        const article = await db.getArticle(id);
        if (!article) return send(res, 404, { error: 'not_found' });
        return send(res, 200, article);
      } catch {
        return send(res, 503, { error: 'db_unavailable' });
      }
    }

    if (req.method !== 'POST' || pathname !== '/v1/convert') {
      return send(res, 404, { error: 'not_found' });
    }

    if (rateLimiter) {
      const ip = req.socket?.remoteAddress ?? 'unknown';
      if (!rateLimiter(ip)) return send(res, 429, { error: 'rate_limited' });
    }

    let body;
    try {
      body = await readJson(req);
    } catch (e) {
      return send(res, 400, { error: e.message });
    }
    const url = typeof body.url === 'string' ? body.url.trim() : '';
    if (!isConvertibleUrl(url)) {
      return send(res, 400, { error: 'invalid_url' });
    }
    try {
      const job = await enqueue({ url });
      return send(res, 202, { jobId: job.id });
    } catch {
      return send(res, 503, { error: 'queue_unavailable' });
    }
  };
}
