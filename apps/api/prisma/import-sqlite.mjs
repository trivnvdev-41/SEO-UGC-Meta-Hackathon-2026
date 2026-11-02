// Impor sekali jalan: SQLite (DATABASE_URL_SQLITE) -> PostgreSQL (DATABASE_URL).
// Urutan FK-aman: Article -> Job -> Vote. Akhiri dengan hitung baris per tabel;
// keluar non-zero bila ada selisih. Baca-only terhadap sumber (tak pernah tulis).
import { PrismaClient as SqliteClient } from '../src/generated/sqlite-import/index.js';
import { PrismaClient } from '@prisma/client';

const SQLITE_URL = process.env.DATABASE_URL_SQLITE ?? '';
if (!SQLITE_URL) {
  console.error('DATABASE_URL_SQLITE kosong');
  process.exit(2);
}

const src = new SqliteClient({ datasources: { db: { url: SQLITE_URL } } });
const dst = new PrismaClient();

const counts = async (p) => ({
  Article: await p.article.count(),
  Job: await p.job.count(),
  Vote: await p.vote.count(),
});

try {
  const before = await counts(src);
  for (const a of await src.article.findMany()) {
    await dst.article.upsert({
      where: { id: a.id },
      create: { ...a },
      update: { ...a },
    });
  }
  for (const j of await src.job.findMany()) {
    await dst.job.upsert({
      where: { id: j.id },
      create: { ...j },
      update: { ...j },
    });
  }
  for (const v of await src.vote.findMany()) {
    await dst.vote.upsert({
      where: { id: v.id },
      create: { ...v },
      update: { ...v },
    });
  }
  const afterSrc = await counts(src);
  const afterDst = await dst.article.count().then(async (Article) => ({
    Article,
    Job: await dst.job.count(),
    Vote: await dst.vote.count(),
  }));
  console.log(JSON.stringify({ src: afterSrc, dst: afterDst }));
  const ok = ['Article', 'Job', 'Vote'].every((t) => afterDst[t] >= before[t]);
  if (!ok) {
    console.error('SELISIH: dst kurang dari src');
    process.exit(1);
  }
  console.log(`IMPORT_OK src=${JSON.stringify(before)}`);
} finally {
  await src.$disconnect();
  await dst.$disconnect();
}
