import { Queue } from 'bullmq';

export const CONVERT_QUEUE = 'convert-queue';

export function createConvertQueue(redisUrl) {
  const queue = new Queue(CONVERT_QUEUE, { connection: { url: redisUrl } });
  return {
    // AI gateway kadang flaky (pernah 404/400 palsu lalu 200 saat retry):
    // 3x percobaan, jeda eksponensial 10s -> 20s.
    enqueue: ({ url }) => queue.add('convert', { url }, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 10000 },
    }),
    close: () => queue.close(),
  };
}
