import test from 'node:test';
import assert from 'node:assert/strict';
import { isConvertibleUrl } from '../src/validateUrl.js';
import { makeApp } from '../src/makeApp.js';

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

test('URL valid lolos, pendek/gagal ditolak', () => {
  assert.equal(isConvertibleUrl('https://vt.tiktok.com/abc123/'), true);
  assert.equal(isConvertibleUrl('not-a-url'), false);
  assert.equal(isConvertibleUrl(''), false);
  assert.equal(isConvertibleUrl(null), false);
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
