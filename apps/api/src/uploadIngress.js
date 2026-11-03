import { createWriteStream, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { newJobId as defaultNewJobId } from './queue.js';

// Ingress video langsung dari kreator: raw bytes (bukan multipart).
// POST /v1/uploads, Content-Type: video/*, header opsional x-creator.
// Streaming ke disk (tanpa buffer memori) dengan cap byte. Video mentah
// hanya transit di MEDIA_DIR/<jobId>/video.mp4 lalu dihapus worker.
const VIDEO_NAME = 'video.mp4';

export function maxUploadMb() {
  const raw = (process.env.MAX_VIDEO_MB ?? '').trim();
  return raw && /^\d+$/.test(raw) && Number(raw) > 0 ? Number(raw) : 50;
}

// Simpan stream req ke dest, tolak bila > maxBytes. Resolve byte count.
function streamToFile(req, dest, maxBytes) {
  return new Promise((resolve, reject) => {
    let size = 0;
    let failed = false;
    const out = createWriteStream(dest);
    const abort = (err) => {
      if (failed) return;
      failed = true;
      req.destroy();
      out.destroy();
      rmSync(dest, { force: true });
      reject(err);
    };
    req.on('data', (c) => {
      size += c.length;
      if (size > maxBytes) {
        abort(new Error('video_too_large'));
        return;
      }
      if (!out.write(c)) req.pause();
    });
    out.on('drain', () => req.resume());
    req.on('end', () => {
      if (failed) return;
      out.end(() => resolve(size));
    });
    req.on('error', (e) => abort(e));
    out.on('error', (e) => abort(e));
  });
}

// Referensi sosmed opsional via header x-references (JSON array string).
// Validasi: array ≤3, tiap string https:// ≤500 char. Server TIDAK fetch
// URL ini (tanpa SSRF); hanya disimpan + dirender sebagai kartu referensi.
export function parseReferences(raw) {
  if (!raw) return [];
  let arr;
  try {
    arr = JSON.parse(raw);
  } catch {
    throw new Error('bad_references');
  }
  if (!Array.isArray(arr) || arr.length > 3) throw new Error('bad_references');
  for (const u of arr) {
    if (typeof u !== 'string' || u.length > 500 || !u.startsWith('https://')) {
      throw new Error('bad_references');
    }
  }
  return arr;
}

// POST /v1/uploads -> true bila job dibuat (res 202). False bila ditolak.
// Urutan: simpan file -> tandai media_ready -> antrekan. Worker BullMQ
// hanya melihat job yang medianya sudah ada, jadi tak ada balapan.
export async function handleVideoUpload(req, res, send, { queue, newJobId = defaultNewJobId, db, mediaDir, maxMb, rateLimiter }) {
  const ctype = req.headers['content-type'] ?? '';
  if (!ctype.startsWith('video/')) {
    send(res, 400, { error: 'need_video' });
    return false;
  }
  if (rateLimiter) {
    const ip = req.socket?.remoteAddress ?? 'unknown';
    if (!rateLimiter(`upload:${ip}`)) {
      send(res, 429, { error: 'rate_limited' });
      return false;
    }
  }
  const declared = Number(req.headers['content-length'] ?? 0);
  if (declared > maxMb * 1024 * 1024) {
    send(res, 413, { error: 'video_too_large' });
    return false;
  }
  const creator = (req.headers['x-creator'] ?? '').toString().trim().slice(0, 64);
  let references;
  try {
    references = parseReferences(req.headers['x-references']);
  } catch {
    send(res, 400, { error: 'bad_references' });
    return false;
  }
  const id = newJobId();
  const dir = join(mediaDir, id);
  mkdirSync(dir, { recursive: true });
  try {
    const size = await streamToFile(req, join(dir, VIDEO_NAME), maxMb * 1024 * 1024);
    if (size === 0) throw new Error('empty_video');
  } catch (e) {
    rmSync(dir, { recursive: true, force: true });
    await db.setJobStatus(id, 'failed', { url: '', error: e.message }).catch(() => {});
    send(res, e.message === 'video_too_large' ? 413 : 400, { error: e.message });
    return false;
  }
  try {
    await db.setJobStatus(id, 'media_ready', { url: '', creator: creator || null });
    await queue.enqueue({ id, url: '', creator: creator || null, references });
  } catch {
    rmSync(dir, { recursive: true, force: true });
    await db.setJobStatus(id, 'failed', { url: '', error: 'queue_unavailable' }).catch(() => {});
    send(res, 503, { error: 'queue_unavailable' });
    return false;
  }
  send(res, 202, { jobId: id });
  return true;
}
