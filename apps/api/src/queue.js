import { randomUUID } from 'node:crypto';
import { Queue } from 'bullmq';

// Antrean Redis + BullMQ (pengganti antrean file + poller).
// Retry/backoff/attempt diurus BullMQ, bukan kode manual.
export const QUEUE_NAME = 'convert';
export const MAX_ATTEMPTS = 3;

export function newJobId() {
  return `job_${randomUUID().replaceAll('-', '').slice(0, 12)}`;
}

export function createQueue(redisUrl, name = QUEUE_NAME) {
  const queue = new Queue(name, { connection: { url: redisUrl } });
  return {
    // Tambah job. id opsional (dibuatkan bila kosong). Cegah duplikat id.
    enqueue: async ({ id = newJobId(), url, creator = null }) => {
      await queue.add(
        'convert',
        { url: url ?? '', creator },
        {
          jobId: id,
          attempts: MAX_ATTEMPTS,
          backoff: { type: 'exponential', delay: 5000 },
          removeOnComplete: 100,
          removeOnFail: 500,
        },
      );
      return { id };
    },
    close: () => queue.close(),
  };
}
