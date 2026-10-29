import { Worker } from 'bullmq';
import { CONVERT_QUEUE } from './queue.js';

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
      images: b.images ?? [],
      id_body: b.articles.id,
      en_body: b.articles.en,
      json_ld: b.json_ld ?? {},
    });
    await db.setJobStatus(job.id, 'done', { url, articleId: job.id });
  };
}

export function startWorker({ redisUrl, ...opts }) {
  const worker = new Worker(CONVERT_QUEUE, makeProcessor(opts), {
    connection: { url: redisUrl },
  });
  worker.on('failed', (job, err) => {
    if (!job) return;
    opts.db
      .setJobStatus(job.id, 'failed', { error: String(err?.message ?? err).slice(0, 500) })
      .catch(() => {});
  });
  return worker;
}
