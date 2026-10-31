import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  getArticle,
  listArticleIds,
  pickBody,
  ratingOf,
  type Lang,
} from "@/lib/articles";
import { articlePath } from "@/lib/site";

export const revalidate = 3600;

const T = {
  id: {
    brand: "SEO UGC",
    hero: "Ulasan produk jujur dari video kreator.",
    sub: "Setiap link TikTok, Reels, atau YouTube Shorts diubah menjadi artikel terstruktur dengan foto, kelebihan–kekurangan, dan skor — siap dibaca dan siap diindeks mesin pencari.",
    searchPh: "Cari sunscreen, ampoule, …",
    searchBtn: "Cari",
    latest: "Ulasan terbaru",
    empty: "Belum ada ulasan yang cocok.",
    how: "Cara kerja",
    steps: [
      ["1. Bagikan link", "Kreator atau affiliate membagikan link video dari TikTok, Instagram, atau YouTube."],
      ["2. AI merangkum", "Audio ditranskrip, bingkai terbaik dipilih, lalu disusun jadi artikel dwibahasa dengan JSON-LD."],
      ["3. Terbit & terindeks", "Artikel SSR/ISR dengan canonical, hreflang, dan sitemap — siap muncul di Google dan AI Search."],
    ],
    read: "Baca ulasan",
  },
  en: {
    brand: "SEO UGC",
    hero: "Honest product reviews from creator videos.",
    sub: "Every TikTok, Reels, or YouTube Shorts link becomes a structured article with photos, pros and cons, and a score — ready to read and ready to index.",
    searchPh: "Search sunscreen, ampoule, …",
    searchBtn: "Search",
    latest: "Latest reviews",
    empty: "No matching reviews yet.",
    how: "How it works",
    steps: [
      ["1. Share a link", "A creator or affiliate shares a video link from TikTok, Instagram, or YouTube."],
      ["2. AI summarizes", "Audio is transcribed, the best frames are picked, then composed into a bilingual article with JSON-LD."],
      ["3. Published & indexed", "SSR/ISR articles with canonical, hreflang, and sitemap — ready for Google and AI Search."],
    ],
    read: "Read review",
  },
} as const;

export async function HomeView({ lang, q }: { lang: Lang; q: string }) {
  const t = T[lang];
  const ids = await listArticleIds().catch(() => [] as string[]);
  const articles = (
    await Promise.all(ids.map((id) => getArticle(id).catch(() => null)))
  ).filter((a) => a !== null);
  const query = q.trim().toLowerCase();
  const shown = query
    ? articles.filter((a) => {
        const b = pickBody(a, lang);
        return `${b.title} ${b.meta}`.toLowerCase().includes(query);
      })
    : articles;

  return (
    <main className="mx-auto max-w-3xl px-5 pt-10 pb-16">
      <header className="mb-10 flex items-center justify-between border-b pb-4 font-sans">
        <span className="text-sm font-semibold">{t.brand}</span>
        <nav className="flex gap-2 text-xs">
          <Link href="/">
            <Badge variant={lang === "id" ? "default" : "outline"}>ID</Badge>
          </Link>
          <Link href="/en">
            <Badge variant={lang === "en" ? "default" : "outline"}>EN</Badge>
          </Link>
        </nav>
      </header>

      <section className="mb-10">
        <h1>{t.hero}</h1>
        <p className="mt-3 font-sans text-base text-muted">{t.sub}</p>
        <form method="get" className="mt-5 flex gap-2 font-sans">
          <input
            name="q"
            defaultValue={q}
            placeholder={t.searchPh}
            className="w-full rounded-xl border border-neutral-200 px-4 py-2 text-sm outline-none focus:border-neutral-400"
          />
          <button
            type="submit"
            className="rounded-xl bg-ink px-4 py-2 text-sm font-semibold text-white"
          >
            {t.searchBtn}
          </button>
        </form>
      </section>

      <section className="mb-12">
        <h2 className="mb-4">{t.latest}</h2>
        {shown.length === 0 ? (
          <p className="font-sans text-sm text-muted">{t.empty}</p>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2">
            {shown.map((a) => {
              const b = pickBody(a, lang);
              const rating = ratingOf(a.json_ld);
              return (
                <Card key={a.id}>
                  {a.images[0] ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={a.images[0]}
                      alt=""
                      loading="lazy"
                      className="aspect-video w-full rounded-t-2xl object-cover"
                    />
                  ) : null}
                  <CardContent>
                    <Link
                      href={articlePath(a.id, lang)}
                      className="font-sans font-bold no-underline hover:underline"
                    >
                      {b.title}
                    </Link>
                    <p className="mt-1 line-clamp-2 font-sans text-sm text-muted">
                      {b.meta}
                    </p>
                    <p className="mt-3 flex items-center gap-2 font-sans text-xs">
                      {rating ? (
                        <Badge variant="default">★ {rating.value}/5</Badge>
                      ) : null}
                      <Link href={articlePath(a.id, lang)}>{t.read} →</Link>
                    </p>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )}
      </section>

      <section className="border-t pt-8">
        <h2 className="mb-4">{t.how}</h2>
        <ol className="grid gap-4 font-sans text-sm sm:grid-cols-3">
          {t.steps.map(([title, desc]) => (
            <li key={title} className="rounded-2xl border border-neutral-200 p-4">
              <p className="font-bold">{title}</p>
              <p className="mt-1 text-muted">{desc}</p>
            </li>
          ))}
        </ol>
      </section>

      <footer className="mt-12 border-t pt-4 font-sans text-xs text-muted">
        SEO UGC — {t.latest.toLowerCase()} · <Link href="/sitemap.xml">sitemap</Link>
      </footer>
    </main>
  );
}
