import { createServer } from 'node:http';
import { makeApp } from './makeApp.js';
import { createConvertQueue } from './queue.js';
import { createDb } from './db.js';

const PORT = Number(process.env.PORT ?? 4301);
const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379';

const { enqueue } = createConvertQueue(REDIS_URL);
createServer(makeApp(enqueue, createDb())).listen(PORT, () => {
  console.log(`api listening on :${PORT}`);
});
