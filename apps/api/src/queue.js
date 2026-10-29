import { Queue } from 'bullmq';

export const CONVERT_QUEUE = 'convert-queue';

export function createConvertQueue(redisUrl) {
  const queue = new Queue(CONVERT_QUEUE, { connection: { url: redisUrl } });
  return {
    enqueue: ({ url }) => queue.add('convert', { url }),
    close: () => queue.close(),
  };
}
