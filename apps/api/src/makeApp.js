import { createHash, randomUUID } from 'node:crypto';
import { newJobId } from './queue.js';
import { handleVideoUpload, maxUploadMb, parseReferences } from './uploadIngress.js';
import { parseDraft } from './db.js';

/// Validasi field draft dari body PATCH/POST. Kembalikan {ok, patch|error}.
function validateDraftPatch(body, draft) {
  const patch = {};
  if (body.title !== undefined) {
    if (typeof body.title !== 'string' || !body.title.trim() || body.title.trim().length > 200) {
      return { ok: false, error: 'bad_title' };
    }
    patch.title = body.title.trim();
  }
  if (body.coverIndex !== undefined) {
    const frames = Array.isArray(draft?.frames) ? draft.frames : [];
    if (!Number.isInteger(body.coverIndex) || body.coverIndex < 0 || body.coverIndex >= frames.length) {
      return { ok: false, error: 'bad_cover' };
    }
    patch.coverIndex = body.coverIndex;
  }
  if (body.transcript !== undefined) {
    if (typeof body.transcript !== 'string' || !body.transcript.trim() || body.transcript.trim().length > 20000) {
      return { ok: false, error: 'bad_transcript' };
    }
    patch.transcript = body.transcript.trim();
  }
  if (body.references !== undefined) {
    try {
      patch.references = parseReferences(JSON.stringify(body.references));
    } catch {
      return { ok: false, error: 'bad_references' };
    }
  }
  return { ok: true, patch };
}

/// Bentuk draft untuk mobile Langkah 2 (tanpa bundle internal LLM).
function publicDraft(draft) {
  return {
    transcript: draft.transcript ?? '',
    confidence: draft.confidence ?? null,
    frames: Array.isArray(draft.frames) ? draft.frames : [],
    selectedIndices: Array.isArray(draft.selectedIndices) ? draft.selectedIndices : [],
    title: draft.title ?? '',
    creator: draft.creator ?? null,
    references: Array.isArray(draft.references) ? draft.references : [],
  };
}

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

// enqueue: dicadangkan (alur link dicabut; upload pakai opts.upload.queue).
// db: lihat src/db.js.
// opts.rateLimiter: (key) => boolean (fallback untuk upload).
// opts.upload: {queue, newJobId, mediaDir, maxMb} untuk POST /v1/uploads.
//   queue yang sama dipakai POST /v1/drafts/:id/publish (kind 'publish').
// opts.voteLimiter: (key) => boolean untuk POST /v1/votes.
export function makeApp(enqueue, db, { rateLimiter, upload, voteLimiter } = {}) {
  return async (req, res) => {
    const { pathname } = new URL(req.url, 'http://localhost');

    if (req.method === 'POST' && pathname === '/v1/uploads') {
      if (!upload) return send(res, 404, { error: 'not_found' });
      return handleVideoUpload(req, res, send, {
        queue: upload.queue, newJobId: upload.newJobId, db,
        mediaDir: upload.mediaDir,
        maxMb: upload.maxMb ?? maxUploadMb(),
        rateLimiter: upload.rateLimiter ?? rateLimiter,
      });
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

    // Draft Langkah 2: baca hasil olah (transkrip + frame + pilihan AI).
    if (req.method === 'GET' && pathname.startsWith('/v1/drafts/')) {
      const id = decodeURIComponent(pathname.slice('/v1/drafts/'.length));
      if (!id || id.includes('/')) return send(res, 400, { error: 'invalid_id' });
      try {
        const job = await db.getJob(id);
        if (!job) return send(res, 404, { error: 'not_found' });
        const draft = parseDraft(job.draft);
        if (!draft) return send(res, 404, { error: 'draft_missing' });
        return send(res, 200, { jobId: id, status: job.status, draft: publicDraft(draft) });
      } catch {
        return send(res, 503, { error: 'db_unavailable' });
      }
    }

    // Draft Langkah 2: ubah judul/cover/transkrip/referensi sebelum publish.
    if (req.method === 'PATCH' && pathname.startsWith('/v1/drafts/')) {
      const id = decodeURIComponent(pathname.slice('/v1/drafts/'.length));
      if (!id || id.includes('/')) return send(res, 400, { error: 'invalid_id' });
      let body;
      try {
        body = await readJson(req);
      } catch (e) {
        return send(res, 400, { error: e.message });
      }
      try {
        const job = await db.getJob(id);
        if (!job) return send(res, 404, { error: 'not_found' });
        const draft = parseDraft(job.draft);
        if (!draft) return send(res, 404, { error: 'draft_missing' });
        const v = validateDraftPatch(body, draft);
        if (!v.ok) return send(res, 400, { error: v.error });
        const next = { ...draft, ...v.patch };
        await db.setJobStatus(id, job.status, {
          url: job.url ?? '',
          error: job.error ?? null,
          articleId: job.articleId ?? null,
          creator: job.creator ?? null,
          draft: JSON.stringify(next),
        });
        return send(res, 200, { jobId: id, status: job.status, draft: publicDraft(next) });
      } catch {
        return send(res, 503, { error: 'db_unavailable' });
      }
    }

    // Draft Langkah 2 -> artikel: antre job publish (mobile poll artikel).
    if (req.method === 'POST' && pathname.endsWith('/publish') && pathname.startsWith('/v1/drafts/')) {
      const id = decodeURIComponent(pathname.slice('/v1/drafts/'.length, -'/publish'.length));
      if (!id || id.includes('/')) return send(res, 400, { error: 'invalid_id' });
      let body;
      try {
        body = await readJson(req);
      } catch (e) {
        return send(res, 400, { error: e.message });
      }
      if (!upload?.queue) return send(res, 503, { error: 'queue_unavailable' });
      try {
        const job = await db.getJob(id);
        if (!job) return send(res, 404, { error: 'not_found' });
        const draft = parseDraft(job.draft);
        if (!draft) return send(res, 404, { error: 'draft_missing' });
        const v = validateDraftPatch(body, draft);
        if (!v.ok) return send(res, 400, { error: v.error });
        const edited = body.edited === true || (v.patch.transcript !== undefined && v.patch.transcript !== draft.transcript);
        const pub = { ...v.patch, edited, origId: id };
        const { id: publishId } = await upload.queue.enqueue({
          id: newJobId(), url: job.url ?? '', creator: job.creator ?? null,
          kind: 'publish', publish: pub,
        });
        await db.setJobStatus(publishId, 'queued', { url: job.url ?? '' });
        return send(res, 202, { jobId: publishId });
      } catch {
        return send(res, 503, { error: 'db_unavailable' });
      }
    }

    // Alur link (/v1/convert) dicabut: pipeline upload-only via /v1/uploads.
    return send(res, 404, { error: 'not_found' });
  };
}
