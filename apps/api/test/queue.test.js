import test from 'node:test';
import assert from 'node:assert/strict';
import { Queue } from 'bullmq';
import { createQueue, newJobId, QUEUE_NAME, MAX_ATTEMPTS } from '../src/queue.js';
import { createJobHandler } from '../src/processor.js';

const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379';
const NAME = `test-${Date.now().toString(36)}`;

async function redisOk() {
  const q = new Queue('__ping__', { connection: { url: REDIS_URL } });
  try {
    await Promise.race([
      q.waitUntilReady(),
      new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 3000)),
    ]);
    return true;
  } catch {
    return false;
  } finally {
    await q.close().catch(() => {});
  }
}

async function requireRedis(t) {
  if (!(await redisOk())) {
    t.skip(`redis tidak tersedia di ${REDIS_URL} (jalankan redis-server untuk test integrasi)`);
    return false;
  }
  return true;
}

test('newJobId unik berformat job_', () => {
  const a = newJobId();
  const b = newJobId();
  assert.match(a, /^job_[A-Za-z0-9]{12}$/);
  assert.notEqual(a, b);
});

test('enqueue menyimpan job + opsi attempts/backoff', async (t) => {
  if (!(await requireRedis(t))) return;
  const q = createQueue(REDIS_URL, `${NAME}-opts`);
  try {
    const { id } = await q.enqueue({ url: 'https://x/v', creator: '@a' });
    assert.ok(id.startsWith('job_'));
    const raw = new Queue(`${NAME}-opts`, { connection: { url: REDIS_URL } });
    try {
      const got = await raw.getJob(id);
      assert.ok(got, 'job harus ada di redis');
      assert.equal(got.data.url, 'https://x/v');
      assert.equal(got.data.creator, '@a');
      assert.equal(got.opts.attempts, MAX_ATTEMPTS);
      assert.equal(got.opts.backoff.type, 'exponential');
    } finally {
      await raw.close().catch(() => {});
    }
  } finally {
    await q.close();
  }
});

test('startWorker implisit: job convert berhenti di draft_ready (via handler + antrean)', async (t) => {
  if (!(await requireRedis(t))) return;
  const { startWorker } = await import('../src/processor.js');
  const done = [];
  const db = {
    setJobStatus: async (id, status, extra = {}) => {
      done.push([id, status, extra]);
    },
    saveArticle: async () => {},
    getJob: async () => null,
  };
  const name = `${NAME}-run`;
  const q = createQueue(REDIS_URL, name);
  const worker = startWorker({
    queueName: name,
    redisUrl: REDIS_URL,
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    concurrency: 2,
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      json: async () => ({
        articles: { id: { title: 'T', meta: 'M', body_md: 'B' }, en: { title: 'T', meta: 'M', body_md: 'B' } },
        json_ld: {},
      }),
    }),
  });
  try {
    const { id } = await q.enqueue({ url: 'https://x/v' });
    const deadline = Date.now() + 15000;
    while (Date.now() < deadline) {
      if (done.some(([, s]) => s === 'draft_ready')) break;
      await new Promise((r) => setTimeout(r, 200));
    }
    assert.ok(done.some(([i, s]) => i === id && s === 'draft_ready'), `job ${id} harus draft_ready: ${JSON.stringify(done)}`);
  } finally {
    await worker.close().catch(() => {});
    await q.close();
  }
});

test('handler: upload tanpa media -> media_not_ready (tanpa redis)', async () => {
  const handler = createJobHandler({
    db: { setJobStatus: async () => {} },
    workerUrl: 'http://x',
    token: 'T',
    mediaDir: '/tmp/tidak-ada-saba-test',
  });
  await assert.rejects(() => handler({ id: 'job_1', data: { url: '' } }), /media_not_ready/);
});

test('handler: job link langsung diproses (tanpa redis)', async () => {
  const calls = [];
  const handler = createJobHandler({
    db: {
      setJobStatus: async (id, status, extra = {}) => {
        calls.push([id, status, extra]);
      },
      saveArticle: async () => {},
    },
    workerUrl: 'http://worker.test',
    token: 'T',
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      json: async () => ({
        articles: { id: { title: 'T', meta: 'M', body_md: 'B' }, en: { title: 'T', meta: 'M', body_md: 'B' } },
        json_ld: {},
      }),
    }),
  });
  await handler({ id: 'job_2', data: { url: 'https://x/v' } });
  assert.deepEqual(calls.map(([, s]) => s), ['processing', 'draft_ready']);
});
