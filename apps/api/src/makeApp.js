import { createHash, randomUUID } from 'node:crypto';
import { isConvertibleUrl } from './validateUrl.js';
import { handleMediaUpload } from './mediaIngress.js';
import { handleVideoUpload, maxUploadMb } from './uploadIngress.js';

// Identitas tanpa akun: cookie saba_v (uuid) + hash IP+UA sebagai pengikat.
// Tanpa cookie + tanpa IP yang stabil -> voter anonim (tetap boleh vote,
// tapi 1 browser 1 suara hanya bila cookie bertahan).
function voterKeyOf(req) {
  const cookies = req.headers.cookie ?? '';
  const m = /saba_v=([A-Za-z0-9_-]{1,64})/.exec(cookies);
  if (m) return m[1];
  const ua = req.headers['user-agent'] ?? '';
  const ip = req.socket?.remoteAddress ?? 'unknown';
  return `anon_${createHash('sha256').update(`${ip}|${ua}`).digest('hex').slice(0, 32)}`;
}

const ZERO_VOTES = { up: 0, down: 0, score: 0, myVote: 0 };

async function articleVotes(db, id, voterKey) {
  if (typeof db?.getVotes !== 'function') return { ...ZERO_VOTES };
  try {
    const v = await db.getVotes(id);
    let myVote = 0;
    if (typeof db?.getMyVote === 'function' && voterKey) {
      myVote = (await db.getMyVote(id, voterKey)) || 0;
    }
    return { up: v.up ?? 0, down: v.down ?? 0, score: v.score ?? 0, myVote };
  } catch {
    return { ...ZERO_VOTES };
  }
}

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
// opts.upload: {queue, mediaDir, maxMb} untuk POST /v1/uploads.
// opts.voteLimiter: (key) => boolean untuk POST /v1/votes.
export function makeApp(enqueue, db, { rateLimiter, fetch, upload, voteLimiter } = {}) {
  return async (req, res) => {
    const { pathname } = new URL(req.url, 'http://localhost');

    if (req.method === 'POST' && pathname === '/v1/uploads') {
      if (!upload) return send(res, 404, { error: 'not_found' });
      return handleVideoUpload(req, res, send, {
        enqueue, db, mediaDir: upload.mediaDir,
        maxMb: upload.maxMb ?? maxUploadMb(),
        rateLimiter: upload.rateLimiter ?? rateLimiter,
      });
    }

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

    if (req.method === 'GET' && pathname === '/v1/votes') {
      const { searchParams } = new URL(req.url, 'http://localhost');
      const articleId = searchParams.get('articleId') ?? '';
      if (!articleId) return send(res, 400, { error: 'invalid_id' });
      const votes = await articleVotes(db, articleId, voterKeyOf(req));
      const headers = { 'content-type': 'application/json' };
      const out = { ...votes };
      if (!/saba_v=/.test(req.headers.cookie ?? '')) {
        out.voterNew = true;
        headers['set-cookie'] =
          `saba_v=${randomUUID().replaceAll('-', '')}; Path=/; Max-Age=31536000; SameSite=Lax`;
      }
      res.writeHead(200, headers);
      res.end(JSON.stringify(out));
      return;
    }

    if (req.method === 'POST' && pathname === '/v1/votes') {
      if (!db || typeof db.setVote !== 'function') {
        return send(res, 503, { error: 'db_unavailable' });
      }
      if (voteLimiter) {
        const ip = req.socket?.remoteAddress ?? 'unknown';
        if (!voteLimiter(ip)) return send(res, 429, { error: 'rate_limited' });
      }
      let body;
      try {
        body = await readJson(req);
      } catch (e) {
        return send(res, 400, { error: e.message });
      }
      const articleId = typeof body.articleId === 'string' ? body.articleId : '';
      const value = body.value === -1 ? -1 : body.value === 1 ? 1 : null;
      if (!articleId || value === null) {
        return send(res, 400, { error: 'bad_vote' });
      }
      let voter = voterKeyOf(req);
      let freshCookie = null;
      if (voter.startsWith('anon_')) {
        voter = randomUUID().replaceAll('-', '');
        freshCookie =
          `saba_v=${voter}; Path=/; Max-Age=31536000; SameSite=Lax`;
      }
      try {
        const mine = typeof db.getMyVote === 'function'
          ? await db.getMyVote(articleId, voter)
          : 0;
        await db.setVote(articleId, voter, mine === value ? 0 : value);
        const votes = await articleVotes(db, articleId, voter);
        const headers = { 'content-type': 'application/json' };
        if (freshCookie) headers['set-cookie'] = freshCookie;
        res.writeHead(200, headers);
        res.end(JSON.stringify(votes));
        return;
      } catch {
        return send(res, 503, { error: 'db_unavailable' });
      }
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
        const votes = await articleVotes(db, id, voterKeyOf(req));
        return send(res, 200, { ...article, votes });
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
