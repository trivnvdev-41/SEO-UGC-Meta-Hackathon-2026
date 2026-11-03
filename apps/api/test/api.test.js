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
