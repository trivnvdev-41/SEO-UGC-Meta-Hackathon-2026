// Seed dev: satu artikel contoh supaya /article/<id> bisa dirender tanpa worker.
import { createDb } from '../src/db.js';

const db = createDb();

await db.saveArticle({
  id: 'contoh-review',
  videoUrl: 'https://www.tiktok.com/@contoh/video/123',
  images: [],
  id_body: {
    title: 'Review Jujur Produk X — Kelebihan dan Kekurangan',
    meta: 'Ulasan jujur Produk X dari video kreator: kelebihan, kekurangan, dan kesimpulan.',
    body_md: '## Kelebihan\n\n- Bahan solid\n\n## Kekurangan\n\n- Harga premium',
  },
  en_body: {
    title: 'Honest Review of Product X — Pros and Cons',
    meta: 'Honest review of Product X from a creator video: pros, cons, and verdict.',
    body_md: '## Pros\n\n- Solid build\n\n## Cons\n\n- Premium price',
  },
  json_ld: {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: 'Produk X',
    review: {
      '@type': 'Review',
      reviewRating: { '@type': 'Rating', ratingValue: '4' },
      author: { '@type': 'Person', name: 'Kreator' },
    },
  },
});

console.log('seed: contoh-review');
process.exit(0);
