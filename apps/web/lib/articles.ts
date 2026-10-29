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
