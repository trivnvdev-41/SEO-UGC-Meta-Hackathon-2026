import type { MetadataRoute } from "next";
import {
  getArticle,
  listArticleIds,
  listCreators,
  type Article,
} from "../lib/articles";
import { articleUrl, kreatorUrl, SITE_URL, unduhUrl } from "../lib/site";

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const ids = await listArticleIds();
  const articles = (
    await Promise.all(ids.map((id) => getArticle(id).catch(() => null)))
  ).filter((a): a is Article => a !== null);
  const creators = listCreators(articles).map((c) =>
    c.name.replace(/^@+/, "").trim(),
  );
  return [
    { url: SITE_URL, lastModified: new Date(), priority: 1 },
    ...(["id", "en"] as const).map((lang) => ({
      url: unduhUrl(lang),
      lastModified: new Date(),
      priority: 0.9,
      alternates: { languages: { id: unduhUrl("id"), en: unduhUrl("en") } },
    })),
    ...ids.flatMap((id) =>
      (["id", "en"] as const).map((lang) => ({
        url: articleUrl(id, lang),
        lastModified: new Date(),
        priority: 0.8,
        alternates: {
          languages: {
            id: articleUrl(id, "id"),
            en: articleUrl(id, "en"),
          },
        },
      })),
    ),
    ...creators
      .filter((s) => s !== "")
      .flatMap((slug) =>
        (["id", "en"] as const).map((lang) => ({
          url: kreatorUrl(slug, lang),
          lastModified: new Date(),
          priority: 0.6,
          alternates: {
            languages: {
              id: kreatorUrl(slug, "id"),
              en: kreatorUrl(slug, "en"),
            },
          },
        })),
      ),
  ];
}
