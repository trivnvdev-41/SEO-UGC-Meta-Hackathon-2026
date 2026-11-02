import { MAX_ATTEMPTS } from './queue.js';

// Handler murni: worker HTTP -> artikel + status job. Diinject agar ter-test.
export function makeProcessor({ db, workerUrl, token, fetchImpl = fetch }) {
  return async (job) => {
    const url = job.data.url;
    await db.setJobStatus(job.id, 'processing', { url });

    const res = await fetchImpl(`${workerUrl}/process`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        job_id: job.id,
        url,
        ...(job.creator ? { creator: job.creator } : {}),
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
    });
    await db.setJobStatus(job.id, 'done', { url, articleId: job.id });
  };
}

// Poller antrean file: job media_ready atau queued. File yang tak bisa
// diproses dilepas dan lanjut ke file berikut (maks SCAN_PER_TICK) agar satu
// file basi tak memblokir antrean. Satu job diproses per tick.
const SCAN_PER_TICK = 10;
export function startPoller({ queue, intervalMs = 5000, ...opts }) {
  const process = makeProcessor(opts);
  let busy = false; // tick tumpang-tindih = sumber balapan file .active
  const timer = setInterval(async () => {
    if (busy) return;
    busy = true;
    const claimed = [];
    let job = null;
    let file = null;
    try {
      for (let i = 0; i < SCAN_PER_TICK; i++) {
        const f = queue.claim();
        if (!f) break;
        claimed.push(f);
        let row = null;
        try {
          row = await opts.db.getJob(f.id);
        } catch {
          break;
        }
        if (!row || row.status === 'done' || row.status === 'failed') {
          queue.discard(f.id); // file basi terminal: buang, jangan dilepas
          const at = claimed.indexOf(f);
          if (at >= 0) claimed.splice(at, 1);
          continue;
        }
        if (row.status === 'media_ready' || row.status === 'queued') {
          job = { id: f.id, data: { url: f.url } };
          file = f;
          if (row.creator) job.creator = row.creator;
          break;
        }
      }
    } finally {
      for (const f of claimed) {
        if (f !== file) {
          try {
            queue.release(f);
          } catch {
            // balapan: abaikan
          }
        }
      }
      busy = false;
    }
    if (!job) return;
    try {
      await process(job);
      queue.done(file);
    } catch (err) {
      const msg = String(err?.message ?? err).slice(0, 500);
      queue.fail(file, msg);
      if (file.attempts + 1 >= MAX_ATTEMPTS) {
        await opts.db
          .setJobStatus(job.id, 'failed', { error: msg })
          .catch(() => {});
      }
    }
  }, intervalMs);
  timer.unref?.();
  return { close: () => clearInterval(timer) };
}
