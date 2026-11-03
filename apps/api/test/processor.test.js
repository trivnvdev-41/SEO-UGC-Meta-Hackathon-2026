import test from 'node:test';
import assert from 'node:assert/strict';
import { makeProcessor, makePublisher, normalizeConcurrency } from '../src/processor.js';

const bundle = {
  transcript: 'review bagus',
  language: 'id',
  creator: 'Kreator Hebat',
  selected_image_indices: [0],
  frame_options: ['https://cdn.test/f0.jpg', 'https://cdn.test/f1.jpg'],
  articles: {
    id: { title: 'Review', meta: 'Meta ID', body_md: '## A' },
    en: { title: 'Review', meta: 'Meta EN', body_md: '## A' },
  },
  json_ld: { '@type': 'Product' },
  images: ['https://cdn.test/f0.jpg'],
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

test('consumer: worker 200 → DRAFT tersimpan + job draft_ready', async () => {
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
  assert.deepEqual(statuses, ['processing', 'draft_ready']);
  // Artikel BELUM lahir di tahap convert.
  assert.equal(db.calls.some((c) => c[0] === 'article'), false);

  const draftCall = db.calls.find((c) => c[2] === 'draft_ready');
  const draft = JSON.parse(draftCall[3].draft);
  assert.equal(draft.transcript, 'review bagus');
  assert.deepEqual(draft.frames, bundle.frame_options);
  assert.deepEqual(draft.selectedIndices, [0]);
  assert.equal(draft.title, 'Review');
  assert.equal(draft.creator, 'Kreator Hebat');
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

function fakeDraftDb(draft, { draftId = null } = {}) {
  const calls = [];
  return {
    calls,
    setJobStatus: async (id, status, extra = {}) => {
      calls.push(['job', id, status, extra]);
    },
    saveArticle: async (a) => {
      calls.push(['article', a]);
    },
    // Draft hanya ada di job asal; job publish baru tak punya draft.
    getJob: async (id) => {
      if (draftId !== null && id !== draftId) {
        return { id, url: '', creator: null, status: 'queued', articleId: null, error: null, draft: null };
      }
      return {
        id, url: '', creator: null, status: 'draft_ready',
        articleId: null, error: null,
        draft: JSON.stringify(draft),
      };
    },
  };
}

const draftFixture = {
  transcript: 'review bagus',
  confidence: 92.5,
  frames: ['https://cdn.test/f0.jpg', 'https://cdn.test/f1.jpg'],
  selectedIndices: [0],
  title: 'Review',
  creator: '@hebat',
  references: ['https://instagram.com/p/abc/'],
  articles: {
    id: { title: 'Review', meta: 'Meta ID', body_md: '## A', faqs: [{ q: 'Apa?', a: 'Ini.' }] },
    en: { title: 'Review', meta: 'Meta EN', body_md: '## A', faqs: [{ q: 'What?', a: 'This.' }] },
  },
  json_ld: { '@type': 'Product' },
  images: ['https://cdn.test/f0.jpg'],
};

test('consumer: references + faqs tersimpan di draft (bukan artikel)', async () => {
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
  await processor({ id: 'job_f', data: { url: '', creator: null, references: ['https://instagram.com/p/abc/'] } });
  const draft = JSON.parse(db.calls.find((c) => c[2] === 'draft_ready')[3].draft);
  assert.deepEqual(draft.references, ['https://instagram.com/p/abc/']);
  assert.deepEqual(draft.articles.id.faqs, [{ q: 'Apa?', a: 'Ini.' }]);
  assert.equal(db.calls.some((c) => c[0] === 'article'), false);
});

test('publish tanpa edit: finalisasi langsung tanpa panggil worker', async () => {
  const db = fakeDraftDb(draftFixture);
  let fetched = 0;
  const publish = makePublisher({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    fetchImpl: async () => {
      fetched += 1;
      return { ok: true, status: 200, json: async () => ({}) };
    },
  });
  const out = await publish('job_f', { edited: false });
  assert.deepEqual(out, { id: 'job_f' });
  assert.equal(fetched, 0);
  const saved = db.calls.find((c) => c[0] === 'article')[1];
  assert.equal(saved.id, 'job_f');
  assert.equal(saved.id_body.title, 'Review');
  assert.deepEqual(saved.id_faqs, [{ q: 'Apa?', a: 'Ini.' }]);
  assert.deepEqual(saved.references, ['https://instagram.com/p/abc/']);
  const statuses = db.calls.filter((c) => c[0] === 'job').map((c) => c[2]);
  assert.deepEqual(statuses, ['done']);
});

test('publish dengan judul+cover: override tanpa regen', async () => {
  const db = fakeDraftDb(draftFixture);
  let fetched = 0;
  const publish = makePublisher({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    fetchImpl: async () => {
      fetched += 1;
      return { ok: true, status: 200, json: async () => ({}) };
    },
  });
  await publish('job_f', { title: 'Judul Baru', coverIndex: 1, edited: false });
  assert.equal(fetched, 0);
  const saved = db.calls.find((c) => c[0] === 'article')[1];
  assert.equal(saved.id_body.title, 'Judul Baru');
  assert.equal(saved.images[0], 'https://cdn.test/f1.jpg');
});

test('publish dengan transkrip editan: regen via /regenerate', async () => {
  const db = fakeDraftDb(draftFixture);
  const seen = [];
  const regenBundle = {
    articles: {
      id: { title: 'Regen', meta: 'M', body_md: 'B', faqs: [] },
      en: { title: 'Regen', meta: 'M', body_md: 'B', faqs: [] },
    },
    json_ld: { '@type': 'Product' },
    selected_image_indices: [0],
  };
  const publish = makePublisher({
    db,
    workerUrl: 'http://worker.test:4302',
    token: 'T',
    fetchImpl: async (url, init) => {
      seen.push({ url, init });
      return { ok: true, status: 200, json: async () => regenBundle };
    },
  });
  await publish('job_f', { transcript: 'ulasan baru yang beda', edited: true });
  assert.equal(seen[0].url, 'http://worker.test:4302/regenerate');
  const sent = JSON.parse(seen[0].init.body);
  assert.equal(sent.transcript, 'ulasan baru yang beda');
  assert.deepEqual(sent.frame_urls, draftFixture.frames);
  const saved = db.calls.find((c) => c[0] === 'article')[1];
  assert.equal(saved.id_body.title, 'Regen');
});

test('publish regen: gambar ikut cover + pilihan regen', async () => {
  const db = fakeDraftDb({
    ...draftFixture,
    frames: ['https://cdn.test/f0.jpg', 'https://cdn.test/f1.jpg', 'https://cdn.test/f2.jpg'],
  });
  const regenBundle = {
    articles: {
      id: { title: 'R', meta: 'M', body_md: 'B', faqs: [] },
      en: { title: 'R', meta: 'M', body_md: 'B', faqs: [] },
    },
    json_ld: {},
    selected_image_indices: [2, 0],
  };
  const publish = makePublisher({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => regenBundle }),
  });
  await publish('job_f', { transcript: 'baru', coverIndex: 1, edited: true });
  const saved = db.calls.find((c) => c[0] === 'article')[1];
  // ordered = [f1, f0, f2]; regen pilih [2,0] -> f2 lalu f1(cover, dedup)
  assert.deepEqual(saved.images, [
    'https://cdn.test/f1.jpg',
    'https://cdn.test/f2.jpg',
    'https://cdn.test/f0.jpg',
  ]);
});

test('publish: media draft dihapus setelah artikel tersimpan', async () => {
  const { mkdtempSync, mkdirSync, writeFileSync, existsSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const dir = mkdtempSync(join(tmpdir(), 'upl-'));
  mkdirSync(join(dir, 'job_orig'), { recursive: true });
  writeFileSync(join(dir, 'job_orig', 'video.mp4'), Buffer.from([0, 1]));
  const db = fakeDraftDb(draftFixture);
  const publish = makePublisher({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    mediaDir: dir,
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => ({}) }),
  });
  await publish('job_new', { edited: false, origId: 'job_orig' });
  assert.equal(existsSync(join(dir, 'job_orig')), false);
  assert.equal(db.calls.some((c) => c[0] === 'article'), true);
});

test('draft diambil dari job asal (origId), bukan job publish', async () => {
  const db = fakeDraftDb(draftFixture, { draftId: 'job_orig' });
  const publish = makePublisher({
    db,
    workerUrl: 'http://worker.test',
    token: 'T',
    fetchImpl: async () => { throw new Error('must not call worker'); },
  });
  const out = await publish('job_new', { edited: false, origId: 'job_orig' });
  assert.deepEqual(out, { id: 'job_new' });
  const saved = db.calls.find((c) => c[0] === 'article')[1];
  assert.equal(saved.creator, '@hebat');
});

test('publish tanpa draft -> draft_missing', async () => {
  const db = {
    getJob: async () => ({ id: 'x', status: 'processing', draft: null }),
    setJobStatus: async () => {},
    saveArticle: async () => { throw new Error('must not save'); },
  };
  const publish = makePublisher({
    db, workerUrl: 'http://worker.test', token: 'T',
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => ({}) }),
  });
  await assert.rejects(() => publish('x', {}), /draft_missing/);
});
