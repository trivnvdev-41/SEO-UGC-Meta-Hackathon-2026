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
  createdAt: row.createdAt?.toISOString?.() ?? row.createdAt,
});

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

    saveArticle: async (a) =>
      client.article.upsert({
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
          jsonLd: JSON.stringify(a.json_ld ?? {}),
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
          jsonLd: JSON.stringify(a.json_ld ?? {}),
        },
      }),

    setJobStatus: async (id, status, { url, error = null, articleId = null, creator = null } = {}) =>
      client.job.upsert({
        where: { id },
        create: { id, url: url ?? '', status, error, articleId, creator },
        update: { status, error, articleId, ...(creator === null ? {} : { creator }) },
      }),

    getJob: async (id) =>
      client.job.findUnique({ where: { id } }),
  };
}
