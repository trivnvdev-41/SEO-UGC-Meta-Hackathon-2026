import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { ConvertForm } from "@/components/ConvertForm";
import { Reveal } from "@/components/ui/reveal";
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
    hero: "Video kreator, jadi artikel ulasan.",
    sub: "Setiap link TikTok atau YouTube Shorts diubah menjadi artikel terstruktur dengan foto, kelebihan dan kekurangan, serta skor. Siap dibaca dan siap diindeks mesin pencari.",
    searchPh: "Cari sunscreen, ampoule, …",
    searchBtn: "Cari",
    latest: "Ulasan terbaru",
    empty: "Belum ada ulasan yang cocok.",
    how: "Cara kerja",
    steps: [
      ["Bagikan link", "Kreator atau affiliate membagikan link video dari TikTok atau YouTube."],
      ["AI merangkum", "Audio ditranskrip, bingkai terbaik dipilih, lalu disusun jadi artikel dwibahasa dengan JSON-LD."],
      ["Terbit dan terindeks", "Artikel SSR/ISR dengan canonical, hreflang, dan sitemap. Siap muncul di Google dan AI Search."],
    ],
    read: "Baca ulasan",
  },
  en: {
    brand: "SEO UGC",
    hero: "From video to review article.",
    sub: "Every TikTok or YouTube Shorts link becomes a structured article with photos, pros and cons, and a score. Ready to read and ready to index.",
    searchPh: "Search sunscreen, ampoule, …",
    searchBtn: "Search",
    latest: "Latest reviews",
    empty: "No matching reviews yet.",
    how: "How it works",
    steps: [
      ["Share a link", "A creator or affiliate shares a video link from TikTok or YouTube."],
      ["AI summarizes", "Audio is transcribed, the best frames are picked, then composed into a bilingual article with JSON-LD."],
      ["Published and indexed", "SSR/ISR articles with canonical, hreflang, and sitemap. Ready for Google and AI Search."],
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
  const [lead, ...rest] = shown;
  const leadBody = lead ? pickBody(lead, lang) : null;
  const leadRating = lead ? ratingOf(lead.json_ld) : null;

  return (
    <main className="mx-auto max-w-3xl px-5 pt-10 pb-16">
      <header className="mb-10 flex items-center justify-between font-sans">
        <span className="text-sm font-semibold">{t.brand}</span>
        <nav className="flex items-center gap-2">
          <Link href="/">
            <Badge variant={lang === "id" ? "default" : "outline"}>ID</Badge>
          </Link>
          <Link href="/en">
            <Badge variant={lang === "en" ? "default" : "outline"}>EN</Badge>
          </Link>
        </nav>
      </header>

      <section className="mb-10">
        <Reveal>
          <h1>{t.hero}</h1>
          <p className="mt-3 font-sans text-base text-muted">{t.sub}</p>
        </Reveal>
        <Reveal delay={90}>
          <ConvertForm lang={lang} />
        </Reveal>
      </section>

      <section className="mb-12">
        <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
          <h2>{t.latest}</h2>
          <form method="get" className="flex gap-2 font-sans">
            <input
              name="q"
              defaultValue={q}
              placeholder={t.searchPh}
              className="w-44 rounded-xl border border-neutral-200 px-3 py-1.5 text-sm outline-none focus:border-neutral-400 sm:w-56"
            />
            <button
              type="submit"
              className="rounded-xl bg-neutral-900 px-3 py-1.5 text-sm font-semibold text-white"
            >
              {t.searchBtn}
            </button>
          </form>
        </div>
        {shown.length === 0 ? (
          <p className="font-sans text-sm text-muted">{t.empty}</p>
        ) : (
          <>
            {lead && leadBody ? (
              <Reveal>
                <article className="mb-6">
                  {lead.images[0] ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={lead.images[0]}
                      alt=""
                      className="aspect-video w-full rounded-2xl object-cover"
                    />
                  ) : null}
                  <h3 className="mt-4 font-sans text-xl font-bold tracking-tight sm:text-2xl">
                    <Link
                      href={articlePath(lead.id, lang)}
                      className="no-underline hover:underline"
                    >
                      {leadBody.title}
                    </Link>
                  </h3>
                  {lead.creator ? (
                    <p className="mt-1 font-sans text-sm text-muted">
                      {lang === "en" ? `By ${lead.creator}` : `Oleh ${lead.creator}`}
                    </p>
                  ) : null}
                  <p className="mt-1 font-sans text-base text-muted">
                    {leadBody.meta}
                  </p>
                  <p className="mt-3 flex items-center gap-2 font-sans">
                    {leadRating ? (
                      <Badge variant="default">{leadRating.value}/5</Badge>
                    ) : null}
                    <Link href={articlePath(lead.id, lang)}>{t.read} →</Link>
                  </p>
                </article>
              </Reveal>
            ) : null}
            <div className="grid gap-4 sm:grid-cols-2">
              {rest.map((a) => {
              const b = pickBody(a, lang);
              const rating = ratingOf(a.json_ld);
              return (
                <Reveal key={a.id}>
                <Card>
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
                    {a.creator ? (
                      <p className="mt-1 font-sans text-sm text-muted">
                        {lang === "en" ? `By ${a.creator}` : `Oleh ${a.creator}`}
                      </p>
                    ) : null}
                    <p className="mt-1 line-clamp-2 font-sans text-base text-muted">
                      {b.meta}
                    </p>
                    <p className="mt-3 flex items-center gap-2 font-sans">
                      {rating ? (
                        <Badge variant="default">{rating.value}/5</Badge>
                      ) : null}
                      <Link href={articlePath(a.id, lang)}>{t.read} →</Link>
                    </p>
                  </CardContent>
                </Card>
                </Reveal>
              );
            })}
          </div>
          </>
        )}
      </section>

      <section className="mb-12">
        <Reveal>
        <h2 className="mb-4">{t.how}</h2>
        <ol className="grid gap-6 font-sans text-sm sm:grid-cols-3">
          {t.steps.map(([title, desc]) => (
            <li key={title}>
              <p className="font-bold">{title}</p>
              <p className="mt-1 text-base text-muted">{desc}</p>
            </li>
          ))}
        </ol>
        </Reveal>
      </section>

      <footer className="mt-12 font-sans text-sm text-muted">
        SEO UGC — {t.latest.toLowerCase()} · <Link href="/sitemap.xml">sitemap</Link>
      </footer>
    </main>
  );
}
