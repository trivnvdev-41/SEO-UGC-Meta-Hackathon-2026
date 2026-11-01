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
      body: JSON.stringify({ job_id: job.id, url }),
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

// Poller antrean file: klaim -> proses -> done/fail. Satu job per tick.
export function startPoller({ queue, intervalMs = 5000, ...opts }) {
  const process = makeProcessor(opts);
  const timer = setInterval(async () => {
    const file = queue.claim();
    if (!file) return;
    const job = { id: file.id, data: { url: file.url } };
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
