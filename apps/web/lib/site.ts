export const SITE_URL = (
  process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"
).replace(/\/$/, "");

export function articleUrl(id: string, lang: "id" | "en" = "id"): string {
  const base = `${SITE_URL}/article/${encodeURIComponent(id)}`;
  return lang === "en" ? `${base}?lang=en` : base;
}
