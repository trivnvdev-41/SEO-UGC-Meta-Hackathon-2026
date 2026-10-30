import type { MetadataRoute } from "next";
import { listArticleIds } from "../lib/articles";
import { articleUrl, SITE_URL } from "../lib/site";

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const ids = await listArticleIds();
  return [
    { url: SITE_URL, lastModified: new Date(), priority: 1 },
    ...ids.flatMap((id) =>
      (["id", "en"] as const).map((lang) => ({
        url: articleUrl(id, lang),
        lastModified: new Date(),
        priority: 0.8,
      })),
    ),
  ];
}
