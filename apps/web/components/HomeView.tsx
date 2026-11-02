import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { FeedActions } from "@/components/FeedActions";
import { Reveal } from "@/components/ui/reveal";
import { ButtonNotifikasi, Margin as IconSearch } from "@/components/icons";
import {
  Container as IconFlame1,
  Container2 as IconFlame2,
} from "@/components/icons";
import {
  brandOf,
  compactViews,
  getArticle,
  listArticleIds,
  pickBody,
  ratingOf,
  scoreOf,
  sortFeed,
  timeAgo,
  trendingOf,
  viewsOf,
  type Article,
  type FeedTab,
  type Lang,
} from "@/lib/articles";
import { articlePath } from "@/lib/site";
import { sourceLabel } from "@/lib/video";
import { videoObject } from "@/lib/structured";

export const revalidate = 3600;

const TABS: { id: FeedTab; idLabel: string; enLabel: string }[] = [
  { id: "untuk-anda", idLabel: "Untuk Anda", enLabel: "For You" },
  { id: "populer", idLabel: "Populer", enLabel: "Popular" },
  { id: "terbaru", idLabel: "Terbaru", enLabel: "Latest" },
];

const T = {
  id: {
    brand: "SABA",
    searchPh: "Cari sunscreen, ampoule, …",
    searchBtn: "Cari",
    hot: "Panas",
    latest: "Ulasan terbaru",
    empty: "Belum ada ulasan yang cocok.",
    read: "Baca ulasan",
    trending: "TOPIK PALING RAMAI SAAT INI",
    trendingSub: "Popularitas",
    seeAll: "Lihat Semua",
    copied: "Disalin!",
  },
  en: {
    brand: "SABA",
    searchPh: "Search sunscreen, ampoule, …",
    searchBtn: "Search",
    hot: "Hot",
    latest: "Latest reviews",
    empty: "No matching reviews yet.",
    read: "Read review",
    trending: "TRENDING TOPICS RIGHT NOW",
    trendingSub: "Popularity",
    seeAll: "See all",
    copied: "Copied!",
  },
} as const;

function hrefWith(
  lang: Lang,
  params: { q?: string; tab?: string; brand?: string },
  keep: { q: string; tab: FeedTab; brand: string },
) {
  const q = params.q !== undefined ? params.q : keep.q;
  const tab = params.tab !== undefined ? params.tab : keep.tab;
  const brand = params.brand !== undefined ? params.brand : keep.brand;
  const s = new URLSearchParams();
  if (q) s.set("q", q);
  if (tab !== "untuk-anda") s.set("tab", tab);
  if (brand) s.set("brand", brand);
  const qs = s.toString();
  const base = lang === "en" ? "/en" : "/";
  return qs ? `${base}?${qs}` : base;
}

export async function HomeView({
  lang,
  q,
  tab,
  brand,
}: {
  lang: Lang;
  q: string;
  tab: FeedTab;
  brand: string;
}) {
  const t = T[lang];
  const ids = await listArticleIds().catch(() => [] as string[]);
  const articles = (
    await Promise.all(ids.map((id) => getArticle(id).catch(() => null)))
  ).filter((a) => a !== null);
  const brands = [...new Set(articles.map(brandOf).filter(Boolean))];
  const query = q.trim().toLowerCase();
  const filtered = articles.filter((a) => {
    const b = pickBody(a, lang);
    const hitQ =
      !query || `${b.title} ${b.meta}`.toLowerCase().includes(query);
    return hitQ && (!brand || brandOf(a) === brand);
  });
  const shown = sortFeed(filtered, tab);
  const trending = trendingOf(articles);
  const keep = { q, tab, brand };

  return (
    <div className="min-h-screen bg-canvas font-sans" id="top">
      <header className="sticky top-0 z-10 border-b border-line bg-white/90 backdrop-blur">
        <div className="mx-auto max-w-3xl px-5 pt-2.5 pb-2">
          <div className="flex items-center gap-3">
            <Link
              href={lang === "en" ? "/en" : "/"}
              className="flex shrink-0 items-center gap-2 no-underline"
            >
              <span className="flex h-8 w-8 items-center justify-center rounded-xl bg-saba text-base font-bold text-white shadow">
                S
              </span>
              <span className="text-[16px] font-extrabold tracking-tight">
                {t.brand}
              </span>
            </Link>
            <form
              method="get"
              className="relative ml-auto flex min-w-0 flex-1 gap-2"
            >
              <IconSearch
                width="15"
                height="15"
                className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-muted"
              />
              <input
                name="q"
                defaultValue={q}
                placeholder={t.searchPh}
                className="w-full rounded-full border border-transparent bg-canvas py-1.5 pr-16 pl-9 text-sm outline-none placeholder:text-neutral-500 focus:border-saba focus:bg-white"
              />
              <span className="absolute top-1/2 right-2 -translate-y-1/2 rounded-full bg-saba-soft px-2 py-0.5 text-[11px] font-bold text-saba">
                {t.hot}
              </span>
            </form>
            <Link
              href="#ramai"
              aria-label="Notifikasi"
              className="relative flex h-9 w-9 shrink-0 items-center justify-center rounded-full no-underline"
            >
              <ButtonNotifikasi width="1.35em" height="1.35em" />
            </Link>
            <nav className="flex shrink-0 items-center gap-1.5">
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
          <div className="mt-2 flex gap-1 overflow-x-auto">
            {TABS.map((tb) => {
              const label = lang === "en" ? tb.enLabel : tb.idLabel;
              const on = tab === tb.id && !brand;
              return (
                <Link
                  key={tb.id}
                  href={hrefWith(lang, { tab: tb.id, brand: "" }, keep)}
                  className={`shrink-0 rounded-full px-2.5 py-1.5 text-xs font-bold no-underline ${
                    on ? "bg-saba text-white shadow" : "text-muted"
                  }`}
                >
                  {label}
                </Link>
              );
            })}
            {brands.map((b) => (
              <Link
                key={b}
                href={hrefWith(lang, { brand: b === brand ? "" : b }, keep)}
                className={`shrink-0 rounded-full px-2.5 py-1.5 text-xs no-underline ${
                  brand === b
                    ? "bg-saba-soft font-bold text-saba"
                    : "font-normal text-muted"
                }`}
              >
                {b}
              </Link>
            ))}
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-5 pt-6 pb-16">
        {trending.length > 0 ? (
          <section
            id="ramai"
            aria-label={t.trending}
            className="mb-4 rounded-2xl border border-line bg-white p-4 shadow-sm"
          >
            <div className="mb-2 flex items-center justify-between border-b border-canvas pb-2">
              <p className="flex items-center gap-1.5 text-xs font-bold tracking-wide">
                <span className="h-2 w-2 rounded-full bg-[#FF5A00]" />
                {t.trending}
              </p>
              <Link
                href={hrefWith(lang, { tab: "populer", brand: "" }, keep)}
                className="text-[11px] font-bold text-saba no-underline"
              >
                {t.seeAll} →
              </Link>
            </div>
            <ol className="list-none p-0">
              {trending.map((a, i) => {
                const b = pickBody(a, lang);
                const votes = typeof a.votes?.score === "number" ? a.votes.score : viewsOf(a.id);
                const rank =
                  i === 0
                    ? "text-[#FF5A00]"
                    : i === 1
                      ? "text-[#F59E0B]"
                      : "text-[#8590A6]";
                const pop =
                  i === 0
                    ? "text-[#FF5A00]"
                    : i === 1
                      ? "text-[#D97706]"
                      : "text-[#8590A6]";
                return (
                  <li key={a.id}>
                    <Link
                      href={articlePath(a.id, lang)}
                      className="flex items-start gap-2.5 py-1 no-underline"
                    >
                      <span
                        className={`w-4 shrink-0 text-center text-sm font-bold ${rank}`}
                      >
                        {i + 1}
                      </span>
                      <span className="min-w-0">
                        <span className="block truncate text-xs font-bold">
                          {b.title}
                        </span>
                        <span className={`flex items-center gap-1 text-[10px] ${pop}`}>
                          {i < 2 ? (
                            i === 0 ? (
                              <IconFlame1 width="0.9em" height="0.9em" />
                            ) : (
                              <IconFlame2 width="0.9em" height="0.9em" />
                            )
                          ) : (
                            <IconFlame2
                              width="0.9em"
                              height="0.9em"
                              style={{ filter: "grayscale(1)", opacity: 0.7 }}
                            />
                          )}
                          {compactViews(votes)} {t.trendingSub}
                          {a.creator ? (
                            <span className="text-[#8590A6]">
                              {" "}
                              • @{a.creator.replace(/^@/, "")}
                            </span>
                          ) : null}
                        </span>
                      </span>
                    </Link>
                  </li>
                );
              })}
            </ol>
          </section>
        ) : null}

        <section className="mb-10">
          <h2 className="mb-3">{t.latest}</h2>
          {shown.length === 0 ? (
            <p className="text-sm text-muted">{t.empty}</p>
          ) : (
            <div className="grid gap-3">
              {shown.map((a) => (
                <FeedCard key={a.id} a={a} lang={lang} read={t.read} copied={t.copied} />
              ))}
            </div>
          )}
        </section>

        <footer className="mt-10 text-sm text-muted">
          {t.brand} — {t.latest.toLowerCase()} ·{" "}
          <Link href="/sitemap.xml">sitemap</Link>
        </footer>
      </main>

    </div>
  );
}

/// Warna avatar per mock: biru / hijau / ungu, stabil per artikel.
const AVATAR = [
  "bg-[#E7F3FF] text-[#0866FF]",
  "bg-[#ECFDF5] text-[#059669]",
  "bg-[#FAF5FF] text-[#9333EA]",
] as const;

export function avatarTone(id: string): (typeof AVATAR)[number] {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h + id.charCodeAt(i)) % 997;
  return AVATAR[h % AVATAR.length];
}

/// Kartu feed: seluruh kartu 1 link ke halaman detail.
function FeedCard({
  a,
  lang,
  read,
  copied,
}: {
  a: Article;
  lang: Lang;
  read: string;
  copied: string;
}) {
  const b = pickBody(a, lang);
  const rating = ratingOf(a.json_ld);
  const source = sourceLabel(a.videoUrl);
  const brand = brandOf(a);
  const video = videoObject(a, b);
  const votes = a.votes ?? { up: 0, down: 0, score: 0, myVote: 0 as const };
  const handle = (brand || a.creator || (lang === "en" ? "review" : "ulasan")).replace(/^@/, "");
  const byline =
    a.creator && brand && a.creator.replace(/^@/, "") !== brand
      ? lang === "en"
        ? `published by ${a.creator.replace(/^@/, "")}`
        : `diterbitkan oleh ${a.creator.replace(/^@/, "")}`
      : (source ?? "");
  const ago = timeAgo(a.createdAt, lang);
  return (
    <Reveal>
      <div className="rounded-[12px] border border-line bg-white p-[14px] shadow-sm">
        <div className="flex items-center gap-2">
          <span
            aria-hidden
            className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold ${avatarTone(a.id)}`}
          >
            @
          </span>
          <span className="min-w-0">
            <span className="block truncate text-xs font-bold">
              @{handle}
              {byline ? (
                <span className="font-normal text-[#8590A6]">
                  {" "}
                  • {byline}
                </span>
              ) : null}
            </span>
            {ago ? (
              <span className="block text-[10px] text-[#8590A6]">{ago}</span>
            ) : null}
          </span>
          {source ? (
            <span className="ml-auto shrink-0 rounded-full bg-saba-soft px-2 py-0.5 text-[10px] font-bold text-saba">
              {source}
            </span>
          ) : null}
        </div>
        <Link
          href={articlePath(a.id, lang)}
          className="mt-2 block text-[15px] leading-snug font-bold no-underline"
        >
          {b.title}
        </Link>
        <p className="mt-1 line-clamp-3 text-xs leading-relaxed text-[#444444]">
          {b.meta}
        </p>
        {video ? (
          <Link
            href={articlePath(a.id, lang)}
            aria-label={read}
            className="relative mt-2.5 block aspect-video w-full overflow-hidden rounded-xl bg-neutral-100 no-underline"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={video.thumbnailUrl[0]}
              alt=""
              loading="lazy"
              className="absolute inset-0 h-full w-full object-cover"
            />
            <span className="absolute inset-0 flex items-center justify-center">
              <span className="flex h-12 w-12 items-center justify-center rounded-full bg-saba text-xl text-white shadow-md">
                ▶
              </span>
            </span>
            <span className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 via-black/30 to-transparent p-2.5 pt-8 text-xs text-white">
              {lang === "en" ? "Watch video" : "Tonton video"}
            </span>
          </Link>
        ) : a.images[0] ? (
          <Link
            href={articlePath(a.id, lang)}
            aria-label={read}
            className="relative mt-2.5 block aspect-video w-full overflow-hidden rounded-xl no-underline"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={a.images[0]}
              alt=""
              loading="lazy"
              className="absolute inset-0 h-full w-full object-cover"
            />
            {source ? (
              <span className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 via-black/30 to-transparent p-2.5 pt-8 text-xs text-white">
                {source}
              </span>
            ) : null}
          </Link>
        ) : null}
        <p className="mt-2.5 flex items-center gap-2 text-sm">
          {rating ? (
            <Badge variant="default">{rating.value}/5</Badge>
          ) : null}
          <span className="text-xs text-muted">
            {compactViews(viewsOf(a.id))}
          </span>
          <Link
            href={articlePath(a.id, lang)}
            className="ml-auto text-xs font-semibold text-saba no-underline"
          >
            {read} →
          </Link>
        </p>
        <FeedActions
          id={a.id}
          initial={votes}
          path={articlePath(a.id, lang)}
          lang={lang}
          t={{ copied }}
        />
      </div>
    </Reveal>
  );
}
