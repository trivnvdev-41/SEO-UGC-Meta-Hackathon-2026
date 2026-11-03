import type { Article, ArticleBody } from "./articles";
import { youtubeId } from "./video";

// VideoObject hanya untuk YouTube: embed resmi + thumbnail deterministik.
// Platform lain dirender sebagai kartu referensi (tanpa script pihak ketiga).
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

export interface Faq {
  q: string;
  a: string;
}

/// FAQPage dari faqs LLM (maks 3, buang yang kosong). null bila tak ada.
export function faqPage(faqs: unknown) {
  const items = (Array.isArray(faqs) ? faqs : [])
    .filter(
      (f): f is Faq =>
        !!f &&
        typeof (f as Faq).q === "string" &&
        typeof (f as Faq).a === "string" &&
        (f as Faq).q.trim() !== "" &&
        (f as Faq).a.trim() !== "",
    )
    .slice(0, 3);
  if (items.length === 0) return null;
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: items.map((f) => ({
      "@type": "Question",
      name: f.q.trim(),
      acceptedAnswer: { "@type": "Answer", text: f.a.trim() },
    })),
  };
}
