import test from 'node:test';
import assert from 'node:assert/strict';
import { makeApp } from '../src/makeApp.js';

function call(app, { method = 'GET', url = '/', body = {} } = {}) {
  return new Promise((resolve) => {
    const chunks = [];
    const req = {
      method,
      url,
      headers: {},
      socket: {},
      on(ev, fn) {
        if (ev === 'data') fn(JSON.stringify(body));
        if (ev === 'end') fn();
      },
    };
    const res = {
      writeHead(status, headers) {
        this.status = status;
        this.headers = headers;
      },
      end(payload) {
        resolve({
          status: this.status,
          body: payload ? JSON.parse(payload) : null,
        });
      },
    };
    app(req, res);
  });
}

test('POST /v1/convert yang dicabut → 404', async () => {
  const app = makeApp(async () => ({ id: 'x' }));
  const r = await call(app, {
    method: 'POST',
    url: '/v1/convert',
    body: { url: 'https://vt.tiktok.com/abc/' },
  });
  assert.equal(r.status, 404);
  assert.equal(r.body.error, 'not_found');
});

const fakeDb = {
  listArticleIds: async () => ['a1', 'a2'],
  getArticle: async (id) =>
    id === 'a1'
      ? {
          id: 'a1',
          images: [],
          videoUrl: 'https://www.tiktok.com/@x/video/1',
          id_body: { title: 'T', meta: 'M', body_md: 'B' },
          en_body: { title: 'T', meta: 'M', body_md: 'B' },
          json_ld: {},
        }
      : null,
};

test('GET /v1/articles → daftar id', async () => {
  const r = await call(makeApp(async () => ({ id: 'x' }), fakeDb), {
    method: 'GET',
    url: '/v1/articles',
  });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.ids, ['a1', 'a2']);
});

test('GET /v1/articles/:id → artikel / 404', async () => {
  const app = makeApp(async () => ({ id: 'x' }), fakeDb);
  const ok = await call(app, { method: 'GET', url: '/v1/articles/a1' });
  assert.equal(ok.status, 200);
  assert.equal(ok.body.id, 'a1');
  const miss = await call(app, { method: 'GET', url: '/v1/articles/nope' });
  assert.equal(miss.status, 404);
});

test('DB error → 503', async () => {
  const app = makeApp(async () => ({ id: 'x' }), {
    listArticleIds: async () => {
      throw new Error('pg down');
    },
  });
  const r = await call(app, { method: 'GET', url: '/v1/articles' });
  assert.equal(r.status, 503);
});

const draftRow = {
  id: 'job_d1',
  url: '',
  creator: '@tes',
  status: 'draft_ready',
  articleId: null,
  error: null,
  draft: JSON.stringify({
    transcript: 'halo dunia',
    confidence: 92.5,
    frames: ['https://cdn.test/f0.jpg', 'https://cdn.test/f1.jpg'],
    selectedIndices: [0],
    title: 'Judul Draft',
    creator: '@tes',
    references: [],
    articles: {
      id: { title: 'Judul Draft', meta: 'M', body_md: 'B' },
      en: { title: 'Title', meta: 'M', body_md: 'B' },
    },
    json_ld: {},
    images: ['https://cdn.test/f0.jpg'],
  }),
};

function draftApp(over = {}) {
  const calls = [];
  const db = {
    getJob: async (id) => (id === 'job_d1' ? { ...draftRow } : null),
    setJobStatus: async (id, status, extra = {}) => {
      calls.push([id, status, extra]);
    },
    saveArticle: async () => {},
  };
  const added = [];
  const queue = {
    enqueue: async (job) => {
      added.push(job);
      return { id: job.id };
    },
  };
  const app = makeApp(async () => ({ id: 'x' }), db, {
    upload: { queue, newJobId: () => 'job_pub1', mediaDir: '/tmp/x', maxMb: 50 },
    ...over,
  });
  return { app, calls, added };
}

test('GET /v1/drafts/:id → draft publik', async () => {
  const { app } = draftApp();
  const r = await call(app, { method: 'GET', url: '/v1/drafts/job_d1' });
  assert.equal(r.status, 200);
  assert.equal(r.body.status, 'draft_ready');
  assert.equal(r.body.draft.title, 'Judul Draft');
  assert.deepEqual(r.body.draft.frames, ['https://cdn.test/f0.jpg', 'https://cdn.test/f1.jpg']);
  assert.ok(!('articles' in r.body.draft), 'bundle internal tidak bocor');
  const miss = await call(app, { method: 'GET', url: '/v1/drafts/nope' });
  assert.equal(miss.status, 404);
});

test('PATCH /v1/drafts/:id validasi + simpan', async () => {
  const { app, calls } = draftApp();
  const r = await call(app, {
    method: 'PATCH', url: '/v1/drafts/job_d1',
    body: { title: 'Judul Baru', coverIndex: 1 },
  });
  assert.equal(r.status, 200);
  assert.equal(r.body.draft.title, 'Judul Baru');
  const bad = await call(app, {
    method: 'PATCH', url: '/v1/drafts/job_d1', body: { coverIndex: 9 },
  });
  assert.equal(bad.status, 400);
  const badRef = await call(app, {
    method: 'PATCH', url: '/v1/drafts/job_d1', body: { references: ['http://x'] },
  });
  assert.equal(badRef.status, 400);
  assert.ok(calls.length >= 1);
});

test('POST /v1/drafts/:id/publish → antre job publish', async () => {
  const { app, added } = draftApp();
  const r = await call(app, {
    method: 'POST', url: '/v1/drafts/job_d1/publish',
    body: { title: 'Final', edited: false },
  });
  assert.equal(r.status, 202);
  assert.ok(r.body.jobId);
  assert.equal(added[0].kind, 'publish');
  assert.equal(added[0].publish.title, 'Final');
  assert.equal(added[0].publish.origId, 'job_d1');
  const miss = await call(app, { method: 'POST', url: '/v1/drafts/nope/publish', body: {} });
  assert.equal(miss.status, 404);
});
