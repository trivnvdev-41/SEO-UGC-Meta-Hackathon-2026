import { existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { Worker } from 'bullmq';
import { MAX_ATTEMPTS, QUEUE_NAME } from './queue.js';

// Handler murni: worker HTTP -> artikel + status job. Diinject agar ter-test.
// Bentuk job internal: { id, data: { url?, creator? } } (url '' = upload).
export function makeProcessor({ db, workerUrl, token, fetchImpl = fetch }) {
  return async (job) => {
    const url = job.data.url ?? '';
    const creator = job.data.creator ?? null;
    const references = job.data.references ?? [];
    await db.setJobStatus(job.id, 'processing', { url });

    const res = await fetchImpl(`${workerUrl}/process`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        job_id: job.id,
        ...(creator ? { creator } : {}),
      }),
    });
    if (!res.ok) throw new Error(`worker_${res.status}`);

    const b = await res.json();
    if (!b?.articles?.id || !b?.articles?.en) throw new Error('worker_bad_payload');

    await db.saveArticle({
      id: job.id,
      videoUrl: url,
      creator: b.creator ?? null,
      images: b.images ?? [],
      id_body: b.articles.id,
      en_body: b.articles.en,
      json_ld: b.json_ld ?? {},
      references,
      id_faqs: b.articles.id?.faqs ?? [],
      en_faqs: b.articles.en?.faqs ?? [],
    });
    await db.setJobStatus(job.id, 'done', { url, articleId: job.id });
  };
}

// Media dianggap siap bila video.mp4 ada, atau audio.mp3 + ≥1 frame.
function mediaPresent(mediaDir, jobId) {
  if (!mediaDir) return false;
  const dir = join(mediaDir, jobId);
  try {
    if (existsSync(join(dir, 'video.mp4'))) return true;
    if (!existsSync(join(dir, 'audio.mp3'))) return false;
    return readdirSync(dir).some((f) => /^frame_\d{3}\.jpg$/.test(f));
  } catch {
    return false;
  }
}

// Handler BullMQ: cek kesiapan media, lalu proses. Diekspor agar ter-test
// tanpa Redis; startWorker hanya memasang wiring BullMQ di atasnya.
export function createJobHandler({ db, workerUrl, token, fetchImpl, mediaDir = '' }) {
  const process = makeProcessor({ db, workerUrl, token, fetchImpl });
  return async (bullJob) => {
    const job = { id: bullJob.id, data: bullJob.data ?? {} };
    if (!job.data.url && !mediaPresent(mediaDir, job.id)) {
      throw new Error('media_not_ready');
    }
    await process(job);
  };
}

// Worker BullMQ: event-driven (tanpa polling), concurrency via opts.
// Job upload (url kosong) yang medianya belum tersimpan dilempar agar
// dijadwal ulang via backoff, bukan diproses setengah jalan.
export function normalizeConcurrency(raw, fallback = 2) {
  const n = Number(raw);
  return Number.isInteger(n) && n >= 1 && n <= 32 ? n : fallback;
}
export function startWorker({
  queueName = QUEUE_NAME,
  redisUrl,
  connection,
  db,
  workerUrl,
  token,
  concurrency = 2,
  mediaDir = '',
  fetchImpl,
} = {}) {
  const handler = createJobHandler({ db, workerUrl, token, fetchImpl, mediaDir });
  const worker = new Worker(queueName, handler, {
    connection: connection ?? { url: redisUrl },
    concurrency,
  });
  worker.on('failed', async (job, err) => {
    if (!job) return;
    if (job.attemptsMade >= MAX_ATTEMPTS) {
      await db
        .setJobStatus(job.id, 'failed', {
          url: job.data?.url ?? '',
          error: String(err?.message ?? err).slice(0, 500),
        })
        .catch(() => {});
    }
  });
  return worker;
}
