import { listArticleIds } from "@/lib/articles";
import { articleUrl, SITE_URL } from "@/lib/site";

export const revalidate = 3600;

// llms.txt: ringkasan situs untuk AI search engine (ChatGPT, Perplexity, dll).
export async function GET() {
  const ids = await listArticleIds();
  const lines = [
    "# SEO UGC",
    "",
    "> Product review articles generated from UGC videos (TikTok, Instagram Reels,",
    "> YouTube Shorts). Each article is available in Indonesian and English and",
    "> ships Product/Review JSON-LD plus the official video embed.",
    "",
    "## Articles",
    "",
    ...ids.flatMap((id) => [
      `- [${id}](${articleUrl(id, "id")})`,
      `- [${id} (English)](${articleUrl(id, "en")})`,
    ]),
    "",
    "## Notes",
    "",
    "- Language switch: append `?lang=en` to any article URL.",
    "- Structured data: `application/ld+json` (Product + Review; VideoObject for YouTube).",
    `- Sitemap: ${SITE_URL}/sitemap.xml`,
    "",
  ];

  return new Response(lines.join("\n"), {
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "public, max-age=0, s-maxage=3600",
    },
  });
}
