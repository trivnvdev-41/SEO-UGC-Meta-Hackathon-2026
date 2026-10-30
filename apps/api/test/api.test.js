import test from 'node:test';
import assert from 'node:assert/strict';
import { isConvertibleUrl } from '../src/validateUrl.js';
import { makeApp } from '../src/makeApp.js';
import { makeRateLimiter } from '../src/rateLimit.js';

function call(app, { method = 'POST', url = '/v1/convert', body = {} } = {}) {
  return new Promise((resolve) => {
    const chunks = [];
    const req = {
      method,
      url,
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
        resolve({ status: this.status, body: JSON.parse(payload) });
      },
    };
    app(req, res);
  });
}

test('URL valid lolos, host lain/format salah ditolak', () => {
  assert.equal(isConvertibleUrl('https://vt.tiktok.com/abc123/'), true);
  assert.equal(isConvertibleUrl('https://www.instagram.com/reel/abc/'), true);
  assert.equal(isConvertibleUrl('https://www.youtube.com/shorts/abc123XYZ_-'), true);
  assert.equal(isConvertibleUrl('https://youtu.be/abc123XYZ_-'), true);
  assert.equal(isConvertibleUrl('not-a-url'), false);
  assert.equal(isConvertibleUrl(''), false);
  assert.equal(isConvertibleUrl(null), false);
});

test('SSRF/domain lain ditolak', () => {
  assert.equal(isConvertibleUrl('http://169.254.169.254/latest/meta-data'), false);
  assert.equal(isConvertibleUrl('https://evil.com/video/1'), false);
  assert.equal(isConvertibleUrl('https://tiktok.com.evil.com/x'), false);
  assert.equal(isConvertibleUrl('https://youtube.com.evil.com/x'), false);
  assert.equal(isConvertibleUrl('https://user:pw@tiktok.com/x'), false);
  assert.equal(isConvertibleUrl('http://www.tiktok.com/@a/video/1'), false);
});

test('POST /v1/convert → 202 + jobId untuk URL valid', async () => {
  const seen = [];
  const app = makeApp(async (job) => {
    seen.push(job);
    return { id: 'job_test1' };
  });
  const r = await call(app, { body: { url: 'https://vt.tiktok.com/abc/' } });
  assert.equal(r.status, 202);
  assert.equal(r.body.jobId, 'job_test1');
  assert.equal(seen.length, 1);
});

test('POST /v1/convert → 400 untuk URL invalid', async () => {
  const app = makeApp(async () => ({ id: 'x' }));
  const r = await call(app, { body: { url: 'bukan-url' } });
  assert.equal(r.status, 400);
  assert.equal(r.body.error, 'invalid_url');
});

test('queue mati → 503', async () => {
  const app = makeApp(async () => {
    throw new Error('redis down');
  });
  const r = await call(app, { body: { url: 'https://vt.tiktok.com/abc/' } });
  assert.equal(r.status, 503);
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

test('rate limit: request ke-(limit+1) → 429', async () => {
  const app = makeApp(
    async () => ({ id: 'job_rl' }),
    null,
    { rateLimiter: makeRateLimiter({ limit: 2 }) },
  );
  const body = { url: 'https://vt.tiktok.com/abc/' };
  assert.equal((await call(app, { body })).status, 202);
  assert.equal((await call(app, { body })).status, 202);
  const third = await call(app, { body });
  assert.equal(third.status, 429);
  assert.equal(third.body.error, 'rate_limited');
});
