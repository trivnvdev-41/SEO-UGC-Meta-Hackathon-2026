export const SITE_URL = (
  process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"
).replace(/\/$/, "");

/** Path relatif: dipakai untuk <a href> dan redirect (tidak boleh absolut). */
export function articlePath(id: string, lang: "id" | "en" = "id"): string {
  const path = `/article/${encodeURIComponent(id)}`;
  return lang === "en" ? `/en${path}` : path;
}

/** URL absolut: hanya untuk canonical, hreflang, sitemap, llms.txt. */
export function articleUrl(id: string, lang: "id" | "en" = "id"): string {
  return `${SITE_URL}${articlePath(id, lang)}`;
}

/** Profil kreator: /kreator/<nama> (+ /en). Nama tanpa @, di-encode. */
export function kreatorPath(slug: string, lang: "id" | "en" = "id"): string {
  const path = `/kreator/${encodeURIComponent(slug)}`;
  return lang === "en" ? `/en${path}` : path;
}

export function kreatorUrl(slug: string, lang: "id" | "en" = "id"): string {
  return `${SITE_URL}${kreatorPath(slug, lang)}`;
}
