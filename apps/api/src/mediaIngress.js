import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// Ingress media dari fetch-worker lokal: audio.mp3 + frames + creator.
// Hanya untuk client yang kita kendalikan (format multipart kami), jadi
// parser minimal. Batas: 1 audio + 10 frame, total ≤ MAX_MEDIA_BYTES.
const MAX_FILES = 11;
const MAX_MEDIA_BYTES = 60 * 1024 * 1024;
const ALLOWED_AUDIO = new Set(['audio.mp3']);
const FRAME_RE = /^frame_\d{3}\.jpg$/;

function splitBuffer(buf, sep) {
  const out = [];
  let i = 0;
  while (true) {
    const j = buf.indexOf(sep, i);
    if (j < 0) {
      out.push(buf.subarray(i));
      break;
    }
    out.push(buf.subarray(i, j));
    i = j + sep.length;
  }
  return out;
}

export function parseMultipart(req, body) {
  const ctype = req.headers['content-type'] ?? '';
  const m = /boundary=(.+)$/.exec(ctype);
  if (!m) throw new Error('missing_boundary');
  const sep = Buffer.from(`--${m[1].trim().replaceAll('"', '')}`);
  const fields = {};
  const files = [];
  for (const part of splitBuffer(body, sep)) {
    if (part.length < 8 || part.subarray(0, 2).equals(Buffer.from('--'))) {
      continue;
    }
    const headEnd = part.indexOf('\r\n\r\n');
    if (headEnd < 0) throw new Error('bad_part');
    const head = part.subarray(0, headEnd).toString('latin1');
    let data = part.subarray(headEnd + 4);
    if (data.subarray(-2).equals(Buffer.from('\r\n'))) {
      data = data.subarray(0, -2);
    }
    const name = /name="([^"]+)"/.exec(head)?.[1];
    const filename = /filename="([^"]+)"/.exec(head)?.[1];
    if (!name) throw new Error('bad_part');
    if (filename) {
      files.push({ fieldname: name, filename, data: Buffer.from(data) });
    } else {
      fields[name] = data.toString('utf8');
    }
  }
  return { fields, files };
}

export function readBody(req, maxBytes = MAX_MEDIA_BYTES) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > maxBytes) {
        reject(new Error('media_too_large'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function checkAuth(req, token) {
  return !!token && req.headers.authorization === `Bearer ${token}`;
}

// POST /v1/media/<jobId> -> true bila media tersimpan (db media_ready).
// Mengembalikan false bila ditolak (res sudah dikirim).
export async function handleMediaUpload(req, res, send, db, mediaDir, token) {
  const sendJson = send;
  if (!checkAuth(req, token)) {
    return sendJson(res, 401, { error: 'unauthorized' });
  }
  const id = decodeURIComponent(req.url.split('/v1/media/')[1] ?? '');
  if (!id) return sendJson(res, 400, { error: 'invalid_id' });
  let job = null;
  try {
    job = await db.getJob(id);
  } catch {
    return sendJson(res, 503, { error: 'db_unavailable' });
  }
  if (!job) return sendJson(res, 404, { error: 'unknown_job' });

  let body;
  try {
    body = await readBody(req);
  } catch (e) {
    return sendJson(res, 413, { error: e.message });
  }
  let parsed;
  try {
    parsed = parseMultipart(req, body);
  } catch (e) {
    return sendJson(res, 400, { error: e.message });
  }
  const { fields, files } = parsed;
  if (files.length === 0 || files.length > MAX_FILES) {
    return sendJson(res, 400, { error: 'bad_files' });
  }
  const audio = files.filter((f) => ALLOWED_AUDIO.has(f.filename));
  const frames = files.filter((f) => FRAME_RE.test(f.filename));
  if (audio.length !== 1 || audio.length + frames.length !== files.length) {
    return sendJson(res, 400, { error: 'bad_files' });
  }

  mkdirSync(join(mediaDir, id), { recursive: true });
  const saved = [];
  for (const f of [...audio, ...frames]) {
    const name = f.filename;
    if (name.includes('/') || name.includes('..')) {
      return sendJson(res, 400, { error: 'bad_filename' });
    }
    writeFileSync(join(mediaDir, id, name), f.data);
    saved.push(name);
  }
  try {
    await db.setJobStatus(id, 'media_ready', {
      url: job.url,
      creator: typeof fields.creator === 'string' ? fields.creator : null,
    });
  } catch {
    sendJson(res, 503, { error: 'db_unavailable' });
    return false;
  }
  sendJson(res, 200, { ok: true, files: saved });
  return true;
}
