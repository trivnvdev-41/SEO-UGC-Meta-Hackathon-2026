import Link from "next/link";
import { FollowButton } from "@/components/ArticleExtras";
import { Margin as IconSearch } from "@/components/icons";
import { ButtonKembali as IconBack } from "@/components/icons";
import {
  brandOf,
  compactViews,
  getArticle,
  listArticleIds,
  pickBody,
  trendingOf,
  viewsOf,
  type Lang,
} from "@/lib/articles";
import { articlePath } from "@/lib/site";

const T = {
  id: {
    title: "Jelajah",
    back: "Kembali",
    searchPh: "Cari di SABA…",
    all: "Semua",
    topics: "Topik",
    communities: "Komunitas",
    creators: "Kreator",
    browseTopics: "Jelajahi topik",
    followFav: "Ikuti favoritmu",
    follow: "Ikuti",
    following: "Diikuti",
    hot: "Hot hari ini",
    seeAll: "Lihat Semua",
    hotUnit: "panas",
    empty: "Belum ada yang bisa dijelajahi.",
  },
  en: {
    title: "Explore",
    back: "Back",
    searchPh: "Search SABA…",
    all: "All",
    topics: "Topics",
    communities: "Communities",
    creators: "Creators",
    browseTopics: "Browse topics",
    followFav: "Follow your favorites",
    follow: "Follow",
    following: "Following",
    hot: "Hot today",
    seeAll: "See all",
    hotUnit: "hot",
    empty: "Nothing to explore yet.",
  },
} as const;

/// Halaman Jelajah (mock 05): cari + pil filter + topik/komunitas/kreator + hot.
/// Semua data real; "Terakhir dicari" dilewati (butuh riwayat yang tidak ada).
export async function JelajahView({ lang }: { lang: Lang }) {
  const t = T[lang];
  const home = lang === "en" ? "/en" : "/";
  const base = lang === "en" ? "/en/jelajah" : "/jelajah";
  const ids = await listArticleIds().catch(() => [] as string[]);
  const articles = (
    await Promise.all(ids.map((id) => getArticle(id).catch(() => null)))
  ).filter((a) => a !== null);
  const brands = [...new Set(articles.map(brandOf).filter(Boolean))];
  const creators = [
    ...new Set(
      articles.map((a) => (a.creator ?? "").replace(/^@/, "")).filter(Boolean),
    ),
  ];
  const hot = trendingOf(articles);

  return (
    <div className="min-h-screen bg-canvas font-sans" id="top">
      <header className="sticky top-0 z-10 border-b border-line bg-white/90 backdrop-blur">
        <div className="relative mx-auto flex min-h-16 max-w-3xl items-center justify-center px-5">
          <a
            href={home}
            aria-label={t.back}
            className="absolute left-5 flex h-9 w-9 items-center justify-center rounded-full bg-canvas no-underline"
          >
            <IconBack width="1.1em" height="1.1em" />
          </a>
          <p className="text-[17px] font-normal">{t.title}</p>
        </div>
      </header>

      <main className="mx-auto flex max-w-3xl flex-col gap-3 px-3 pt-3 pb-16">
        <form
          method="get"
          action={home}
          className="relative flex min-w-0 flex-1 items-center gap-2 rounded-full border border-line bg-white px-3.5 py-3"
        >
          <IconSearch width="1.1em" height="1.1em" className="shrink-0" />
          <input
            name="q"
            placeholder={t.searchPh}
            aria-label={t.searchPh}
            className="w-full bg-transparent text-sm outline-none placeholder:text-neutral-500"
          />
        </form>

        <nav
          aria-label={t.title}
          className="flex gap-2 overflow-x-auto"
        >
          <Link
            href={home}
            className="shrink-0 rounded-full bg-saba px-3 py-2 text-xs text-white no-underline"
          >
            {t.all}
          </Link>
          {[
            [t.topics, `${base}#topik`],
            [t.communities, `${base}#komunitas`],
            [t.creators, `${base}#kreator`],
          ].map(([label, href]) => (
            <Link
              key={href}
              href={href}
              className="shrink-0 rounded-full border border-line bg-white px-3 py-2 text-xs text-ink no-underline"
            >
              {label}
            </Link>
          ))}
        </nav>

        {brands.length > 0 ? (
          <section
            id="topik"
            aria-label={t.topics}
            className="rounded-xl border border-line bg-white p-3.5 shadow-sm"
          >
            <p className="text-[15px]">{t.browseTopics}</p>
            <div className="mt-2.5 flex flex-wrap gap-2">
              {brands.map((b) => (
                <Link
                  key={b}
                  href={`${home}?brand=${encodeURIComponent(b)}`}
                  className="rounded-full bg-saba-soft px-3 py-2 text-xs font-bold text-saba no-underline"
                >
                  @{b}
                </Link>
              ))}
            </div>
          </section>
        ) : null}

        <section
          id="komunitas"
          aria-label={t.communities}
          className="rounded-xl border border-line bg-white p-3.5 shadow-sm"
        >
          <p className="text-[15px]">
            {t.communities} • {t.followFav}
          </p>
          {brands.length === 0 ? (
            <p className="mt-2 text-sm text-muted">{t.empty}</p>
          ) : (
            <div className="mt-2.5 flex flex-wrap gap-2">
              {brands.map((b) => (
                <span
                  key={b}
                  className="flex items-center gap-1.5 rounded-full bg-canvas px-3 py-2 text-xs"
                >
                  <span className="font-bold">@{b}</span>
                  <FollowButton
                    id={b}
                    label={t.follow}
                    following={t.following}
                  />
                </span>
              ))}
            </div>
          )}
        </section>

        {creators.length > 0 ? (
          <section
            id="kreator"
            aria-label={t.creators}
            className="rounded-xl border border-line bg-white p-3.5 shadow-sm"
          >
            <p className="text-[15px]">{t.creators}</p>
            <div className="mt-2.5 flex flex-wrap gap-2">
              {creators.map((c) => (
                <Link
                  key={c}
                  href={`${home}?q=${encodeURIComponent(`@${c}`)}`}
                  className="rounded-full border border-line bg-white px-3 py-2 text-xs no-underline"
                >
                  @{c}
                </Link>
              ))}
            </div>
          </section>
        ) : null}

        {hot.length > 0 ? (
          <section
            aria-label={t.hot}
            className="rounded-xl border border-line bg-white p-3.5 shadow-sm"
          >
            <p className="flex items-center justify-between text-[15px]">
              {t.hot}
              <Link
                href={`${home}?tab=populer`}
                className="text-xs font-bold text-saba no-underline"
              >
                {t.seeAll} ›
              </Link>
            </p>
            <ol className="mt-2.5 grid list-none grid-cols-[minmax(0,1fr)] gap-2 p-0">
              {hot.map((a, i) => {
                const b = pickBody(a, lang);
                const v =
                  typeof a.votes?.score === "number"
                    ? a.votes.score
                    : viewsOf(a.id);
                return (
                  <li key={a.id}>
                    <Link
                      href={articlePath(a.id, lang)}
                      className="block truncate text-sm no-underline"
                    >
                      <span className="font-bold">{i + 1}.</span> {b.title}{" "}
                      <span className="text-muted">
                        • {compactViews(v)} {t.hotUnit}
                      </span>
                    </Link>
                  </li>
                );
              })}
            </ol>
          </section>
        ) : null}
      </main>
    </div>
  );
}
