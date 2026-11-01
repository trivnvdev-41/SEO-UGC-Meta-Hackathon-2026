import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { ConvertForm } from "@/components/ConvertForm";
import { Reveal } from "@/components/ui/reveal";
import {
  getArticle,
  listArticleIds,
  pickBody,
  ratingOf,
  type Article,
  type Lang,
} from "@/lib/articles";
import { articlePath } from "@/lib/site";
import { sourceLabel } from "@/lib/video";

export const revalidate = 3600;

const T = {
  id: {
    brand: "SABA",
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
    brand: "SABA",
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

  return (
    <div className="min-h-screen bg-canvas font-sans">
      <header className="sticky top-0 z-10 border-b border-line bg-white">
        <div className="mx-auto flex max-w-3xl items-center gap-3 px-5 py-2.5">
          <Link
            href={lang === "en" ? "/en" : "/"}
            className="flex items-center gap-2 no-underline"
          >
            <span className="flex h-8 w-8 items-center justify-center rounded-full bg-saba text-base font-bold text-white">
              S
            </span>
            <span className="text-[15px] font-extrabold tracking-tight">
              {t.brand}
            </span>
          </Link>
          <form method="get" className="ml-auto flex flex-1 gap-2">
            <input
              name="q"
              defaultValue={q}
              placeholder={t.searchPh}
              className="w-full rounded-full border border-transparent bg-canvas px-4 py-1.5 text-sm outline-none placeholder:text-neutral-500 focus:border-saba focus:bg-white"
            />
            <button
              type="submit"
              className="shrink-0 rounded-full bg-saba px-4 py-1.5 text-sm font-semibold text-white"
            >
              {t.searchBtn}
            </button>
          </form>
          <nav className="flex items-center gap-1.5">
            <Link href="/">
              <Badge variant={lang === "id" ? "default" : "outline"}>
                ID
              </Badge>
            </Link>
            <Link href="/en">
              <Badge variant={lang === "en" ? "default" : "outline"}>
                EN
              </Badge>
            </Link>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-5 pt-6 pb-16">
        <section className="mb-6">
          <Reveal>
            <h1 className="text-2xl sm:text-3xl">{t.hero}</h1>
            <p className="mt-2 text-base text-muted">{t.sub}</p>
          </Reveal>
          <Reveal delay={90}>
            <ConvertForm lang={lang} />
          </Reveal>
        </section>

        <section className="mb-10">
          <h2 className="mb-3">{t.latest}</h2>
          {shown.length === 0 ? (
            <p className="text-sm text-muted">{t.empty}</p>
          ) : (
            <div className="grid gap-3">
              {shown.map((a) => (
                <FeedCard key={a.id} a={a} lang={lang} read={t.read} />
              ))}
            </div>
          )}
        </section>

        <section className="mb-10 rounded-2xl border border-line bg-white p-5">
          <Reveal>
            <h2 className="mt-0 mb-3">{t.how}</h2>
            <ol className="grid gap-4 text-sm sm:grid-cols-3">
              {t.steps.map(([title, desc]) => (
                <li key={title}>
                  <p className="font-bold">{title}</p>
                  <p className="mt-1 text-muted">{desc}</p>
                </li>
              ))}
            </ol>
          </Reveal>
        </section>

        <footer className="mt-10 text-sm text-muted">
          {t.brand} — {t.latest.toLowerCase()} ·{" "}
          <Link href="/sitemap.xml">sitemap</Link>
        </footer>
      </main>
    </div>
  );
}

/// Kartu feed: seluruh kartu 1 link ke halaman detail.
function FeedCard({
  a,
  lang,
  read,
}: {
  a: Article;
  lang: Lang;
  read: string;
}) {
  const b = pickBody(a, lang);
  const rating = ratingOf(a.json_ld);
  const source = sourceLabel(a.videoUrl);
  const brand = (() => {
    try {
      const ld = a.json_ld as Record<string, unknown>;
      const br = ld.brand as Record<string, unknown> | undefined;
      return typeof br?.name === "string" ? br.name : "";
    } catch {
      return "";
    }
  })();
  return (
    <Reveal>
      <Link
        href={articlePath(a.id, lang)}
        className="block rounded-2xl border border-line bg-white p-4 no-underline transition-shadow hover:shadow-md"
      >
        <p className="text-xs font-bold">
          c/{brand || (lang === "en" ? "review" : "ulasan")}
          {a.creator ? (
            <span className="font-medium text-muted"> • {a.creator}</span>
          ) : null}
        </p>
        <p className="mt-1.5 text-[17px] leading-snug font-bold">
          {b.title}
        </p>
        <p className="mt-1 line-clamp-3 text-[15px] leading-relaxed text-muted">
          {b.meta}
        </p>
        {a.images[0] ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={a.images[0]}
            alt=""
            loading="lazy"
            className="mt-3 aspect-video w-full rounded-xl object-cover"
          />
        ) : null}
        <p className="mt-3 flex items-center gap-2 text-sm">
          {rating ? (
            <Badge variant="default">{rating.value}/5</Badge>
          ) : null}
          {source ? (
            <span className="text-xs font-medium text-muted">{source}</span>
          ) : null}
          <span className="ml-auto text-xs font-semibold text-saba">
            {read} →
          </span>
        </p>
      </Link>
    </Reveal>
  );
}
