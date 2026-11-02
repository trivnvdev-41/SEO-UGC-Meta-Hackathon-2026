import test from 'node:test';
import assert from 'node:assert/strict';
import { makeApp } from '../src/makeApp.js';

// Fake DB dengan store vote in-memory.
function fakeDb() {
  const votes = new Map(); // `${articleId}|${voterKey}` -> value
  return {
    calls: [],
    getArticle: async (id) =>
      id === 'a1'
        ? {
            id: 'a1',
            images: [],
            videoUrl: 'https://x/v',
            id_body: { title: 'T', meta: 'M', body_md: 'B' },
            en_body: { title: 'T', meta: 'M', body_md: 'B' },
            json_ld: {},
          }
        : null,
    setVote: async (articleId, voterKey, value) => {
      if (value === 0) votes.delete(`${articleId}|${voterKey}`);
      else votes.set(`${articleId}|${voterKey}`, value);
    },
    getVotes: async (articleId) => {
      let up = 0;
      let down = 0;
      for (const [k, v] of votes) {
        if (k.startsWith(`${articleId}|`)) {
          if (v > 0) up++;
          else down++;
        }
      }
      return { up, down, score: up - down };
    },
    getMyVote: async (articleId, voterKey) =>
      votes.get(`${articleId}|${voterKey}`) ?? 0,
  };
}

function callRaw(app, { method = 'GET', url, headers = {}, body = null }) {
  return new Promise((resolve) => {
    const req = {
      method,
      url,
      headers,
      socket: { remoteAddress: '127.0.0.1' },
      on(ev, fn) {
        if (ev === 'data' && body !== null) fn(JSON.stringify(body));
        if (ev === 'end') fn();
      },
      destroy() {},
    };
    const res = {
      status: 0,
      headers: {},
      writeHead(status, headers) {
        this.status = status;
        this.headers = headers ?? {};
      },
      end(payload) {
        resolve({
          status: this.status,
          headers: this.headers,
          body: payload ? JSON.parse(payload) : null,
        });
      },
    };
    app(req, res);
  });
}

test('POST /v1/votes: vote baru -> cookie saba_v + count 1', async () => {
  const app = makeApp(async () => ({ id: 'x' }), fakeDb(), {});
  const r = await callRaw(app, {
    method: 'POST',
    url: '/v1/votes',
    body: { articleId: 'a1', value: 1 },
  });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { up: 1, down: 0, score: 1, myVote: 1 });
  assert.match(r.headers['set-cookie'] ?? '', /saba_v=/);
});

test('POST /v1/votes: nilai sama -> unvote (toggle)', async () => {
  const db = fakeDb();
  const app = makeApp(async () => ({ id: 'x' }), db, {});
  const cookie = 'saba_v=voter1';
  const base = { method: 'POST', url: '/v1/votes', headers: { cookie } };
  const r1 = await callRaw(app, { ...base, body: { articleId: 'a1', value: 1 } });
  assert.equal(r1.body.score, 1);
  const r2 = await callRaw(app, { ...base, body: { articleId: 'a1', value: 1 } });
  assert.equal(r2.body.score, 0);
  assert.equal(r2.body.myVote, 0);
  const r3 = await callRaw(app, { ...base, body: { articleId: 'a1', value: -1 } });
  assert.deepEqual([r3.body.up, r3.body.down], [0, 1]);
});

test('POST /v1/votes: value tak valid -> 400', async () => {
  const app = makeApp(async () => ({ id: 'x' }), fakeDb(), {});
  for (const body of [
    { articleId: 'a1', value: 2 },
    { articleId: '', value: 1 },
    { articleId: 'a1' },
  ]) {
    const r = await callRaw(app, { method: 'POST', url: '/v1/votes', body });
    assert.equal(r.status, 400);
  }
});

test('GET /v1/votes: count + myVote dari cookie', async () => {
  const db = fakeDb();
  const app = makeApp(async () => ({ id: 'x' }), db, {});
  await callRaw(app, {
    method: 'POST',
    url: '/v1/votes',
    headers: { cookie: 'saba_v=voter9' },
    body: { articleId: 'a1', value: 1 },
  });
  const r = await callRaw(app, {
    url: '/v1/votes?articleId=a1',
    headers: { cookie: 'saba_v=voter9' },
  });
  assert.equal(r.status, 200);
  assert.equal(r.body.myVote, 1);
  assert.equal(r.body.score, 1);
  const anon = await callRaw(app, { url: '/v1/votes?articleId=a1' });
  assert.equal(anon.body.myVote, 0);
  assert.equal(anon.body.score, 1);
});

test('GET /v1/articles/:id menyertakan votes', async () => {
  const app = makeApp(async () => ({ id: 'x' }), fakeDb(), {});
  const r = await callRaw(app, { method: 'GET', url: '/v1/articles/a1' });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.votes, { up: 0, down: 0, score: 0, myVote: 0 });
});

test('rate limit vote -> 429', async () => {
  const app = makeApp(async () => ({ id: 'x' }), fakeDb(), {
    voteLimiter: () => false,
  });
  const r = await callRaw(app, {
    method: 'POST',
    url: '/v1/votes',
    body: { articleId: 'a1', value: 1 },
  });
  assert.equal(r.status, 429);
});
