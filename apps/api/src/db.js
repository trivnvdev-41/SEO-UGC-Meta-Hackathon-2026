import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const toArticle = (row) => ({
  id: row.id,
  images: row.images,
  videoUrl: row.videoUrl,
  id_body: { title: row.idTitle, meta: row.idMeta, body_md: row.idBody },
  en_body: { title: row.enTitle, meta: row.enMeta, body_md: row.enBody },
  json_ld: row.jsonLd,
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
          images: a.images,
          idTitle: a.id_body.title,
          idMeta: a.id_body.meta,
          idBody: a.id_body.body_md,
          enTitle: a.en_body.title,
          enMeta: a.en_body.meta,
          enBody: a.en_body.body_md,
          jsonLd: a.json_ld,
        },
        update: {
          videoUrl: a.videoUrl,
          images: a.images,
          idTitle: a.id_body.title,
          idMeta: a.id_body.meta,
          idBody: a.id_body.body_md,
          enTitle: a.en_body.title,
          enMeta: a.en_body.meta,
          enBody: a.en_body.body_md,
          jsonLd: a.json_ld,
        },
      }),

    setJobStatus: async (id, status, { url, error = null, articleId = null } = {}) =>
      client.job.upsert({
        where: { id },
        create: { id, url: url ?? '', status, error, articleId },
        update: { status, error, articleId },
      }),
  };
}
