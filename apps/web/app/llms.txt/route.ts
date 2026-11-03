import {
  getArticle,
  listArticleIds,
  listCreators,
  pickBody,
  type Article,
} from "@/lib/articles";
import { articleUrl, kreatorUrl, SITE_URL } from "@/lib/site";

export const revalidate = 3600;

const oneLine = (s: string) => s.replace(/\s+/g, " ").trim().slice(0, 200);

// llms.txt: ringkasan situs untuk AI search engine (ChatGPT, Perplexity, dll).
export async function GET() {
  const ids = await listArticleIds();
  const articles = (
    await Promise.all(ids.map((id) => getArticle(id).catch(() => null)))
  ).filter((a): a is Article => a !== null);
  const lines = [
    "# SABA",
    "",
    "> Honest product review articles generated from creators' own video",
    "> uploads. Each article is available in Indonesian and English and",
    "> ships Product/Review JSON-LD plus the official video embed.",
    "> A social-media link may be attached only as an extra reference;",
    "> videos are never pulled from social media.",
    "",
    "## Articles",
    "",
    ...articles.flatMap((a) => {
      const idBody = pickBody(a, "id");
      const title = oneLine(idBody.title) || a.id;
      const meta = oneLine(idBody.meta);
      return [
        `- [${title}](${articleUrl(a.id, "id")})${meta ? `: ${meta}` : ""}`,
        `  - English: [${oneLine(pickBody(a, "en").title) || a.id}](${articleUrl(a.id, "en")})`,
      ];
    }),
    "",
    "## Creators",
    "",
    ...listCreators(articles)
      .slice(0, 20)
      .map((c) => {
        const slug = c.name.replace(/^@+/, "").trim();
        return `- [${c.name} (${c.count} articles)](${kreatorUrl(slug, "id")})`;
      }),
    "",
    "## How it works",
    "",
    "- Upload a video; the audio is transcribed",
    "  and the best frames become a bilingual review article with JSON-LD.",
    "- English version lives under `/en/article/<id>` (hreflang pairs both URLs).",
    "- Structured data: `application/ld+json` (Product + Review + VideoObject).",
    "",
    "## FAQ",
    "",
    "- Are articles AI-generated? Yes, from the creator's own video voice and frames, with the original video embedded.",
    "- Which languages? Indonesian and English, every article.",
    "",
    "## Notes",
    "",
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
