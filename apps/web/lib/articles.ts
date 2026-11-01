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
  creator?: string | null;
  id_body: ArticleBody;
  en_body: ArticleBody;
  json_ld: Record<string, unknown>;
  createdAt?: string;
}

const API_BASE = process.env.API_BASE_URL ?? "http://localhost:4301";
const CACHE = { next: { revalidate: 3600 } };

export async function getArticle(id: string): Promise<Article | null> {
  const res = await fetch(
    `${API_BASE}/v1/articles/${encodeURIComponent(id)}`,
    CACHE,
  );
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`api_${res.status}`);
  return (await res.json()) as Article;
}

export async function listArticleIds(): Promise<string[]> {
  const res = await fetch(`${API_BASE}/v1/articles`, CACHE);
  if (!res.ok) throw new Error(`api_${res.status}`);
  const body = (await res.json()) as { ids: string[] };
  return body.ids;
}

export function pickBody(a: Article, lang: Lang): ArticleBody {
  return lang === "en" ? a.en_body : a.id_body;
}

export function ratingOf(json_ld: Record<string, unknown>): {
  value: string;
  author: string | null;
} | null {
  const review = (json_ld.review ?? {}) as Record<string, unknown>;
  const rating = (review.reviewRating ?? {}) as Record<string, unknown>;
  const author = (review.author ?? {}) as Record<string, unknown>;
  const value = rating.ratingValue;
  if (typeof value !== "string" && typeof value !== "number") return null;
  return {
    value: String(value),
    author: typeof author.name === "string" ? author.name : null,
  };
}

/// Angka lihat semu yang stabil per artikel (demo lokal, tanpa backend).
export function viewsOf(id: string): number {
  let h = 0;
  for (let i = 0; i < id.length; i++) {
    h = (h * 31 + id.charCodeAt(i)) >>> 0;
  }
  return 500 + (h % 9500);
}

export function compactViews(n: number): string {
  if (n >= 1000) {
    const v = n / 1000;
    const s = v >= 100 ? v.toFixed(0) : v.toFixed(1).replace(/\.0$/, "");
    return `${s.replace(".", ",")} rb`;
  }
  return `${n}`;
}

/// "2026-11-01T.." -> "1 Nov 2026" (id) / "Nov 1, 2026" (en).
export function formatDate(iso: string | undefined, lang: Lang): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const bulan = [
    "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
    "Jul", "Agu", "Sep", "Okt", "Nov", "Des",
  ];
  if (lang === "en") {
    const en = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    return `${en[d.getUTCMonth()]} ${d.getUTCDate()}, ${d.getUTCFullYear()}`;
  }
  return `${d.getUTCDate()} ${bulan[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}
