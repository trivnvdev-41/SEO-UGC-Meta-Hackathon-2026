import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const toArticle = (row) => ({
  id: row.id,
  images: JSON.parse(row.images || '[]'),
  videoUrl: row.videoUrl,
  creator: row.creator ?? null,
  id_body: { title: row.idTitle, meta: row.idMeta, body_md: row.idBody },
  en_body: { title: row.enTitle, meta: row.enMeta, body_md: row.enBody },
  json_ld: JSON.parse(row.jsonLd || '{}'),
  references: JSON.parse(row.references || '[]'),
  createdAt: row.createdAt?.toISOString?.() ?? row.createdAt,
});

// GEO: pastikan json_ld selalu membawa author kreator + tanggal terbit/ubah
// yang deterministik (injeksi server-side, bukan andalkan output LLM).
// nowIso diinject agar ter-test.
export function withGeoMeta(jsonLd, { creator, publishedAt = null, nowIso = null } = {}) {
  let ld = {};
  try {
    const parsed = typeof jsonLd === 'string' ? JSON.parse(jsonLd) : (jsonLd ?? {});
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) ld = parsed;
  } catch {
    ld = {};
  }
  const out = { ...ld };
  if (creator) {
    out.author = { '@type': 'Person', name: creator };
  } else {
    // Fallback GEO: kreator kosong (artikel lama/seed) -> pakai nama penulis
    // di review LLM, terakhir Tim SABA. Author tak boleh hilang (E-E-A-T).
    const ra = ld.review?.author;
    const fallback = typeof ra === 'string' ? ra : ra?.name;
    out.author = { '@type': 'Person', name: fallback || 'Tim SABA' };
  }
  const now = nowIso ?? new Date().toISOString();
  const prev = typeof out.datePublished === 'string' && out.datePublished ? out.datePublished : null;
  out.datePublished = prev ?? publishedAt ?? now;
  out.dateModified = now;
  return JSON.stringify(out);
}

// client diinject agar route ter-test tanpa DB.
export function createDb(client = prisma) {
  return {
    listArticleIds: async () =>
      (await client.article.findMany({
        select: { id: true },
        orderBy: { createdAt: 'desc' },
      })).map((r) => r.id),

    getArticle: async (id) => {
      const row = await client.article.findUnique({ where: { id } });
      return row ? toArticle(row) : null;
    },


    saveArticle: async (a) => {
      const prev = await client.article.findUnique({
        where: { id: a.id },
        select: { createdAt: true, jsonLd: true },
      }).catch(() => null);
      const publishedAt = prev?.createdAt?.toISOString?.() ?? null;
      const jsonLd = withGeoMeta(a.json_ld ?? (prev?.jsonLd || '{}'), {
        creator: a.creator ?? null,
        publishedAt,
      });
      return client.article.upsert({
        where: { id: a.id },
        create: {
          id: a.id,
          videoUrl: a.videoUrl,
          creator: a.creator ?? null,
          images: JSON.stringify(a.images ?? []),
          idTitle: a.id_body.title,
          idMeta: a.id_body.meta,
          idBody: a.id_body.body_md,
          enTitle: a.en_body.title,
          enMeta: a.en_body.meta,
          enBody: a.en_body.body_md,
          jsonLd,
          references: JSON.stringify(a.references ?? []),
        },
        update: {
          videoUrl: a.videoUrl,
          creator: a.creator ?? null,
          images: JSON.stringify(a.images ?? []),
          idTitle: a.id_body.title,
          idMeta: a.id_body.meta,
          idBody: a.id_body.body_md,
          enTitle: a.en_body.title,
          enMeta: a.en_body.meta,
          enBody: a.en_body.body_md,
          jsonLd,
          references: JSON.stringify(a.references ?? []),
        },
      });
    },

    setJobStatus: async (id, status, { url, error = null, articleId = null, creator = null } = {}) =>
      client.job.upsert({
        where: { id },
        create: { id, url: url ?? '', status, error, articleId, creator },
        update: { status, error, articleId, ...(creator === null ? {} : { creator }) },
      }),

    getJob: async (id) =>
      client.job.findUnique({ where: { id } }),

    // Vote: toggle 1 suara aktif per voter per artikel.
    // value: 1 (setuju), -1 (kurang setuju), 0 = cabut suara.
    setVote: async (articleId, voterKey, value) => {
      if (value === 0) {
        await client.vote.deleteMany({ where: { articleId, voterKey } });
      } else {
        await client.vote.upsert({
          where: { articleId_voterKey: { articleId, voterKey } },
          create: { articleId, voterKey, value },
          update: { value },
        });
      }
    },

    getVotes: async (articleId) => {
      const rows = await client.vote.findMany({ where: { articleId } });
      const up = rows.filter((r) => r.value > 0).length;
      const down = rows.filter((r) => r.value < 0).length;
      return { up, down, score: up - down };
    },

    getMyVote: async (articleId, voterKey) => {
      const row = await client.vote.findUnique({
        where: { articleId_voterKey: { articleId, voterKey } },
      });
      return row ? row.value : 0;
    },
  };
}
