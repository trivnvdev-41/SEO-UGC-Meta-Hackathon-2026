import { createServer } from 'node:http';
import { makeApp } from './makeApp.js';
import { CONVERT_QUEUE, createConvertQueue } from './queue.js';
import { createDb } from './db.js';
import { startWorker } from './processor.js';
import { makeRateLimiter } from './rateLimit.js';

const PORT = Number(process.env.PORT ?? 4301);
const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379';
const WORKER_URL = process.env.WORKER_URL ?? '';
const TOKEN = process.env.API_INTERNAL_TOKEN ?? '';

const db = createDb();
const queue = createConvertQueue(REDIS_URL);

// Job row dibuat saat enqueue supaya status bisa dilacak sejak awal.
const enqueue = async ({ url }) => {
  const job = await queue.enqueue({ url });
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
  startWorker({ redisUrl: REDIS_URL, db, workerUrl: WORKER_URL, token: TOKEN });
  console.log(`consumer listening on ${CONVERT_QUEUE}`);
} else {
  console.warn('WORKER_URL kosong: consumer tidak dijalankan');
}
