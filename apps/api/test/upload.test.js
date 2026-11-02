import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { makeApp } from '../src/makeApp.js';

// Fake req/res untuk body biner: data diumpan per chunk.
function callRaw(app, { url, headers = {}, chunks = [] }) {
  return new Promise((resolve) => {
    const handlers = {};
    const req = {
      method: 'POST',
      url,
      headers,
      socket: {},
      on(ev, fn) {
        handlers[ev] = fn;
        return req;
      },
      destroy() {},
      pause() {},
      resume() {},
    };
    const res = {
      writeHead(status) {
        this.status = status;
      },
      end(payload) {
        resolve({ status: this.status, body: payload ? JSON.parse(payload) : null });
      },
    };
    const p = app(req, res);
    // alirkan chunk setelah handler terpasang
    queueMicrotask(() => {
      for (const c of chunks) handlers.data?.(c);
      handlers.end?.();
    });
    return p;
  });
}

const videoHeaders = { 'content-type': 'video/mp4', 'content-length': '4' };

function fakeDb() {
  const calls = [];
  return {
    calls,
    setJobStatus: async (id, status, extra = {}) => {
      calls.push([id, status, extra]);
    },
    getJob: async () => null,
  };
}

function makeUploadApp(db, mediaDir, extra = {}) {
  const added = [];
  const queue = {
    enqueue: async ({ id, url, creator }) => {
      added.push({ id, url, creator });
      return { id };
    },
  };
  const app = makeApp(
    async () => {
      throw new Error('no direct enqueue');
    },
    db,
    {
      upload: {
        queue,
        newJobId: () => 'job_up1',
        mediaDir,
        maxMb: 50,
        ...extra,
      },
    },
  );
  app.added = added;
  return app;
}

test('POST /v1/uploads video → 202 + media_ready + file tersimpan', async () => {
  const db = fakeDb();
  const dir = mkdtempSync(join(tmpdir(), 'upl-'));
  const app = makeUploadApp(db, dir);
  const r = await callRaw(app, {
    url: '/v1/uploads',
    headers: { ...videoHeaders, 'x-creator': '@hebat' },
    chunks: [Buffer.from([0, 1]), Buffer.from([2, 3])],
  });
  assert.equal(r.status, 202);
  assert.equal(r.body.jobId, 'job_up1');
  assert.deepEqual(readdirSync(join(dir, 'job_up1')), ['video.mp4']);
  assert.deepEqual(db.calls, [
    ['job_up1', 'media_ready', { url: '', creator: '@hebat' }],
  ]);
  assert.deepEqual(app.added, [{ id: 'job_up1', url: '', creator: '@hebat' }]);
});

test('bukan video → 400 need_video', async () => {
  const db = fakeDb();
  const dir = mkdtempSync(join(tmpdir(), 'upl-'));
  const app = makeUploadApp(db, dir);
  const r = await callRaw(app, {
    url: '/v1/uploads',
    headers: { 'content-type': 'application/json' },
    chunks: [Buffer.from('{}')],
  });
  assert.equal(r.status, 400);
  assert.equal(r.body.error, 'need_video');
});

test('melebihi batas → 413 + job failed', async () => {
  const db = fakeDb();
  const dir = mkdtempSync(join(tmpdir(), 'upl-'));
  const app = makeUploadApp(db, dir, { maxMb: 0.000005 });
  const r = await callRaw(app, {
    url: '/v1/uploads',
    headers: videoHeaders,
    chunks: [Buffer.alloc(10)],
  });
  assert.equal(r.status, 413);
  assert.equal(db.calls[0][1], 'failed');
});

test('rate limit upload → 429', async () => {
  const db = fakeDb();
  const dir = mkdtempSync(join(tmpdir(), 'upl-'));
  let n = 0;
  const app = makeUploadApp(db, dir, { rateLimiter: () => ++n <= 1 });
  const opts = {
    url: '/v1/uploads',
    headers: videoHeaders,
    chunks: [Buffer.from([0])],
  };
  assert.equal((await callRaw(app, opts)).status, 202);
  assert.equal((await callRaw(app, opts)).status, 429);
});
