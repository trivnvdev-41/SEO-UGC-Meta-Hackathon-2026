export type Lang = "id" | "en";

export interface ArticleBody {
  title: string;
  meta: string;
  body_md: string;
}

export interface Article {
  id: string;
  images: string[];
  videoUrl: string;
  id_body: ArticleBody;
  en_body: ArticleBody;
  json_ld: Record<string, unknown>;
}

// shortcut: fixture lokal; ganti query Postgres saat DB wiring ada.
const FIXTURE: Article = {
  id: "contoh-review",
  images: [],
  videoUrl: "https://www.tiktok.com/@contoh/video/123",
  id_body: {
    title: "Review Jujur Produk X — Kelebihan dan Kekurangan",
    meta: "Ulasan jujur Produk X dari video kreator: kelebihan, kekurangan, dan kesimpulan.",
    body_md: "## Kelebihan\n\n- Bahan solid\n\n## Kekurangan\n\n- Harga premium",
  },
  en_body: {
    title: "Honest Review of Product X — Pros and Cons",
    meta: "Honest review of Product X from a creator video: pros, cons, and verdict.",
    body_md: "## Pros\n\n- Solid build\n\n## Cons\n\n- Premium price",
  },
  json_ld: {
    "@context": "https://schema.org",
    "@type": "Product",
    name: "Produk X",
    review: {
      "@type": "Review",
      reviewRating: { "@type": "Rating", ratingValue: "4" },
      author: { "@type": "Person", name: "Kreator" },
    },
  },
};

export function getArticle(id: string): Article | null {
  return id === FIXTURE.id ? FIXTURE : null;
}

export function pickBody(a: Article, lang: Lang): ArticleBody {
  return lang === "en" ? a.en_body : a.id_body;
}
