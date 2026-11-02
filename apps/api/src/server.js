import { createServer } from 'node:http';
import { makeApp } from './makeApp.js';
import { createQueue, newJobId, QUEUE_NAME } from './queue.js';
import { createDb } from './db.js';
import { startWorker } from './processor.js';
import { makeRateLimiter } from './rateLimit.js';

const PORT = Number(process.env.PORT ?? 4301);
const REDIS_URL = process.env.REDIS_URL ?? '';
if (!REDIS_URL) {
  console.error('REDIS_URL kosong: antrean butuh Redis. Contoh: redis://localhost:6379');
  process.exit(1);
}
const MEDIA_DIR = process.env.MEDIA_DIR ?? './data/media';
const WORKER_URL = process.env.WORKER_URL ?? '';
const TOKEN = process.env.API_INTERNAL_TOKEN ?? '';

const db = createDb();
const queue = createQueue(REDIS_URL, QUEUE_NAME);

// Job row dibuat saat enqueue supaya status bisa dilacak sejak awal.
const enqueue = async ({ url, creator = null }) => {
  const { id } = await queue.enqueue({ id: newJobId(), url, creator });
  await db.setJobStatus(id, 'queued', { url }).catch(() => {});
  return { id };
};

createServer(
  makeApp(enqueue, db, {
    rateLimiter: makeRateLimiter({
      limit: Number(process.env.RATE_LIMIT_PER_MIN ?? 5),
    }),
    upload: {
      queue, newJobId, mediaDir: MEDIA_DIR,
      maxMb: Number(process.env.MAX_VIDEO_MB ?? 50) || 50,
    },
    voteLimiter: makeRateLimiter({
      limit: Number(process.env.RATE_LIMIT_VOTE_PER_MIN ?? 30),
    }),
  }),
).listen(PORT, () => {
  console.log(`api listening on :${PORT}`);
});

if (WORKER_URL) {
  startWorker({
    redisUrl: REDIS_URL,
    db,
    workerUrl: WORKER_URL,
    token: TOKEN,
    concurrency: 2,
    mediaDir: MEDIA_DIR,
  });
  console.log(`worker bullmq aktif (concurrency 2) di antrean ${QUEUE_NAME}`);
} else {
  console.warn('WORKER_URL kosong: worker tidak dijalankan');
}
