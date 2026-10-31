import type { Article, ArticleBody } from "./articles";
import { youtubeId } from "./video";

// VideoObject hanya untuk YouTube: embed resmi + thumbnail deterministik.
// Platform lain (TikTok) tetap pakai Product/Review dari model.
export function videoObject(a: Article, body: ArticleBody) {
  const id = youtubeId(a.videoUrl);
  if (!id) return null;
  return {
    "@context": "https://schema.org",
    "@type": "VideoObject",
    name: body.title,
    description: body.meta,
    embedUrl: `https://www.youtube-nocookie.com/embed/${id}`,
    thumbnailUrl: [`https://i.ytimg.com/vi/${id}/hqdefault.jpg`],
    ...(a.createdAt ? { uploadDate: a.createdAt } : {}),
  };
}
