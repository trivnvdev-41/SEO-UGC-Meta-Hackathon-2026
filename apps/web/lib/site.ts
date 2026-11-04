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

/** Halaman unduh aplikasi: /unduh (ID) + /en/unduh (EN, slug ID konsisten). */
export function unduhPath(lang: "id" | "en" = "id"): string {
  return lang === "en" ? "/en/unduh" : "/unduh";
}

export function unduhUrl(lang: "id" | "en" = "id"): string {
  return `${SITE_URL}${unduhPath(lang)}`;
}

/** APK Android dari GitHub Releases (workflow mobile-release). */
export const APK_URL =
  process.env.NEXT_PUBLIC_APK_URL ??
  "https://github.com/trivnvdev-41/saba-meta-hackathon-2026/releases/download/saba-manual/saba-saba-manual.apk";

/** Profil kreator: /kreator/<nama> (+ /en). Nama tanpa @, di-encode. */
export function kreatorPath(slug: string, lang: "id" | "en" = "id"): string {
  const path = `/kreator/${encodeURIComponent(slug)}`;
  return lang === "en" ? `/en${path}` : path;
}

export function kreatorUrl(slug: string, lang: "id" | "en" = "id"): string {
  return `${SITE_URL}${kreatorPath(slug, lang)}`;
}
