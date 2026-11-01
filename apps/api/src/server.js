import { createServer } from 'node:http';
import { makeApp } from './makeApp.js';
import { createFileQueue } from './queue.js';
import { createDb } from './db.js';
import { startPoller } from './processor.js';
import { makeRateLimiter } from './rateLimit.js';

const PORT = Number(process.env.PORT ?? 4301);
const QUEUE_DIR = process.env.QUEUE_DIR ?? './data/queue';
const WORKER_URL = process.env.WORKER_URL ?? '';
const TOKEN = process.env.API_INTERNAL_TOKEN ?? '';

const db = createDb();
const queue = createFileQueue(QUEUE_DIR);

// Job row dibuat saat enqueue supaya status bisa dilacak sejak awal.
const enqueue = async ({ url }) => {
  const job = queue.enqueue({ url });
  await db.setJobStatus(job.id, 'queued', { url }).catch(() => {});
  return job;
};

createServer(
  makeApp(enqueue, db, {
    rateLimiter: makeRateLimiter({
      limit: Number(process.env.RATE_LIMIT_PER_MIN ?? 5),
    }),
  }),
).listen(PORT, () => {
  console.log(`api listening on :${PORT}`);
});

if (WORKER_URL) {
  startPoller({ queue, db, workerUrl: WORKER_URL, token: TOKEN });
  console.log(`poller antrean file di ${QUEUE_DIR}`);
} else {
  console.warn('WORKER_URL kosong: poller tidak dijalankan');
}
