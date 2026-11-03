import test from 'node:test';
import assert from 'node:assert/strict';
import { makeProcessor, normalizeConcurrency } from '../src/processor.js';

const bundle = {
  transcript: 'review bagus',
  language: 'id',
  creator: 'Kreator Hebat',
  selected_image_indices: [0],
  articles: {
    id: { title: 'Review', meta: 'Meta ID', body_md: '## A' },
    en: { title: 'Review', meta: 'Meta EN', body_md: '## A' },
  },
  json_ld: { '@type': 'Product' },
};

function fakeDb() {
  const calls = [];
  return {
    calls,
    setJobStatus: async (id, status, extra = {}) => {
      calls.push(['job', id, status, extra]);
    },
    saveArticle: async (a) => {
      calls.push(['article', a]);
    },
  };
}

const job = { id: 'job_1', data: { url: '', creator: null } };

test('consumer: worker 200 → artikel tersimpan + job done', async () => {
  const db = fakeDb();
  const seen = [];
  const processor = makeProcessor({
    db,
    workerUrl: 'http://worker.test:4302',
    token: 'T',
    fetchImpl: async (url, init) => {
      seen.push({ url, init });
      return { ok: true, status: 200, json: async () => bundle };
    },
  });

  await processor(job);

  assert.equal(seen[0].url, 'http://worker.test:4302/process');
  assert.equal(seen[0].init.headers.authorization, 'Bearer T');
  assert.deepEqual(JSON.parse(seen[0].init.body), {
    job_id: 'job_1',
  });

  const statuses = db.calls.filter((c) => c[0] === 'job').map((c) => c[2]);
  assert.deepEqual(statuses, ['processing', 'done']);

  const saved = db.calls.find((c) => c[0] === 'article')[1];
  assert.equal(saved.id, 'job_1');
  assert.equal(saved.creator, 'Kreator Hebat');
  assert.equal(saved.id_body.title, 'Review');
  assert.equal(saved.json_ld['@type'], 'Product');
});

test('consumer: creator job diteruskan ke worker', async () => {
  const db = fakeDb();
  let sent;
  const processor = makeProcessor({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    fetchImpl: async (url, init) => {
      sent = JSON.parse(init.body);
      return { ok: true, status: 200, json: async () => bundle };
    },
  });
  await processor({ id: 'job_9', data: { url: '', creator: '@hebat' } });
  assert.equal(sent.creator, '@hebat');
  assert.equal(sent.job_id, 'job_9');
});

test('consumer: worker error → throw, artikel tidak disimpan', async () => {
  const db = fakeDb();
  const processor = makeProcessor({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    fetchImpl: async () => ({ ok: false, status: 500, json: async () => ({}) }),
  });

  await assert.rejects(() => processor(job), /worker_500/);
  assert.equal(db.calls.some((c) => c[0] === 'article'), false);
});

test('consumer: payload tanpa articles → worker_bad_payload', async () => {
  const db = fakeDb();
  const processor = makeProcessor({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => ({}) }),
  });

  await assert.rejects(() => processor(job), /worker_bad_payload/);
});

test('normalizeConcurrency: valid 1..32, fallback untuk sampah', () => {
  assert.equal(normalizeConcurrency('4'), 4);
  assert.equal(normalizeConcurrency('1'), 1);
  assert.equal(normalizeConcurrency(undefined), 2);
  assert.equal(normalizeConcurrency(''), 2);
  assert.equal(normalizeConcurrency('0'), 2);
  assert.equal(normalizeConcurrency('-3'), 2);
  assert.equal(normalizeConcurrency('2.5'), 2);
  assert.equal(normalizeConcurrency('abc'), 2);
  assert.equal(normalizeConcurrency('999'), 2);
});

test('consumer: references job diteruskan ke saveArticle', async () => {
  const db = fakeDb();
  const refs = ['https://instagram.com/p/abc/'];
  const processor = makeProcessor({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => bundle }),
  });
  await processor({ id: 'job_r', data: { url: '', creator: null, references: refs } });
  const saved = db.calls.find((c) => c[0] === 'article')[1];
  assert.deepEqual(saved.references, refs);
});

test('consumer: faqs llm diteruskan ke saveArticle', async () => {
  const db = fakeDb();
  const withFaq = {
    ...bundle,
    articles: {
      id: { ...bundle.articles.id, faqs: [{ q: 'Apa?', a: 'Ini.' }] },
      en: { ...bundle.articles.en, faqs: [{ q: 'What?', a: 'This.' }] },
    },
  };
  const processor = makeProcessor({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => withFaq }),
  });
  await processor({ id: 'job_f', data: { url: '', creator: null } });
  const saved = db.calls.find((c) => c[0] === 'article')[1];
  assert.deepEqual(saved.id_faqs, [{ q: 'Apa?', a: 'Ini.' }]);
  assert.deepEqual(saved.en_faqs, [{ q: 'What?', a: 'This.' }]);
});

test('consumer: media dihapus setelah artikel tersimpan', async () => {
  const { mkdtempSync, mkdirSync, writeFileSync, existsSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const dir = mkdtempSync(join(tmpdir(), 'upl-'));
  mkdirSync(join(dir, 'job_1'), { recursive: true });
  writeFileSync(join(dir, 'job_1', 'video.mp4'), Buffer.from([0, 1]));
  const db = fakeDb();
  const processor = makeProcessor({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    mediaDir: dir,
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => bundle }),
  });
  await processor(job);
  assert.equal(existsSync(join(dir, 'job_1')), false);
  assert.equal(db.calls.some((c) => c[0] === 'article'), true);
});
