import test from 'node:test';
import assert from 'node:assert/strict';
import { createDb, withGeoMeta } from '../src/db.js';

test('withGeoMeta: author + tanggal deterministik', () => {
  const out = JSON.parse(withGeoMeta('{}', {
    creator: '@hebat',
    nowIso: '2026-11-02T00:00:00.000Z',
  }));
  assert.deepEqual(out.author, { '@type': 'Person', name: '@hebat' });
  assert.equal(out.datePublished, '2026-11-02T00:00:00.000Z');
  assert.equal(out.dateModified, '2026-11-02T00:00:00.000Z');
});

test('withGeoMeta: tanpa kreator -> fallback ke review.author, terakhir Tim SABA', () => {
  const prev = JSON.stringify({
    datePublished: '2026-01-01T00:00:00.000Z',
    review: { '@type': 'Review' },
  });
  const out = JSON.parse(withGeoMeta(prev, {
    publishedAt: '2026-05-05T00:00:00.000Z',
    nowIso: '2026-11-02T00:00:00.000Z',
  }));
  assert.deepEqual(out.author, { '@type': 'Person', name: 'Tim SABA' });
  assert.equal(out.datePublished, '2026-01-01T00:00:00.000Z');
  assert.equal(out.dateModified, '2026-11-02T00:00:00.000Z');
  assert.deepEqual(out.review, { '@type': 'Review' });
});

test('withGeoMeta: fallback pakai nama penulis di review LLM', () => {
  const prev = JSON.stringify({
    review: { '@type': 'Review', author: { '@type': 'Person', name: '@penulis' } },
  });
  const out = JSON.parse(withGeoMeta(prev, {
    nowIso: '2026-11-02T00:00:00.000Z',
  }));
  assert.deepEqual(out.author, { '@type': 'Person', name: '@penulis' });
});

test('withGeoMeta: JSON rusak tidak meledak', () => {
  const out = JSON.parse(withGeoMeta('{{{', { nowIso: '2026-11-02T00:00:00.000Z' }));
  assert.equal(out.dateModified, '2026-11-02T00:00:00.000Z');
});

test('saveArticle: json_ld tersimpan sudah ber-author + bertanggal', async () => {
  let saved = null;
  const fake = {
    article: {
      findUnique: async () => ({
        createdAt: new Date('2026-10-01T00:00:00.000Z'),
        jsonLd: '{}',
      }),
      upsert: async (args) => {
        saved = args;
        return args.create;
      },
    },
  };
  await createDb(fake).saveArticle({
    id: 'x',
    videoUrl: 'https://x/v',
    creator: '@hebat',
    images: [],
    id_body: { title: 't', meta: 'm', body_md: 'b' },
    en_body: { title: 't', meta: 'm', body_md: 'b' },
    json_ld: { '@type': 'Product' },
  });
  const ld = JSON.parse(saved.create.jsonLd);
  assert.deepEqual(ld.author, { '@type': 'Person', name: '@hebat' });
  assert.equal(ld.datePublished, '2026-10-01T00:00:00.000Z');
  assert.ok(ld.dateModified);
});
