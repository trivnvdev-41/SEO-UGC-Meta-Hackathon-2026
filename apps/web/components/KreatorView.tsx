import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { avatarTone } from "@/components/HomeView";
import {
  compactViews,
  getArticle,
  listArticleIds,
  listCreators,
  pickBody,
  timeAgo,
  viewsOf,
  type Article,
  type Lang,
} from "@/lib/articles";
import { escapeJsonLd } from "@/lib/jsonld";
import { articlePath, kreatorPath, kreatorUrl, SITE_URL } from "@/lib/site";

function matchSlug(creator: string | null | undefined, slug: string): boolean {
  const name = (creator ?? "").replace(/^@+/, "").trim();
  return name !== "" && (name === slug || encodeURIComponent(name) === slug);
}

async function creatorArticles(
  slug: string,
): Promise<{ name: string; articles: Article[] } | null> {
  const ids = await listArticleIds();
  const all = (
    await Promise.all(ids.map((id) => getArticle(id).catch(() => null)))
  ).filter((a) => a !== null);
  const mine = all.filter((a) => matchSlug(a.creator, slug));
  if (mine.length === 0) return null;
  // Nama kanonis dari artikel pertama (slug tak menyimpan @).
  const name = (mine[0].creator ?? "").replace(/^@+/, "").trim();
  return { name, articles: mine };
}

export async function kreatorMetadata(
  slug: string,
  lang: Lang,
): Promise<Metadata> {
  const found = await creatorArticles(slug);
  if (!found) return {};
  const url = kreatorUrl(found.name, lang);
  const title =
    lang === "en"
      ? `${found.name} — Creator on SABA`
      : `${found.name} — Kreator di SABA`;
  const description =
    lang === "en"
      ? `${found.articles.length} product review articles by ${found.name}.`
      : `${found.articles.length} artikel ulasan produk oleh ${found.name}.`;
  return {
    title,
    description,
    alternates: {
      canonical: url,
      languages: {
        id: kreatorUrl(found.name, "id"),
        en: kreatorUrl(found.name, "en"),
        "x-default": kreatorUrl(found.name, "id"),
      },
    },
  };
}

export async function KreatorView({
  slug,
  lang,
}: {
  slug: string;
  lang: Lang;
}) {
  const found = await creatorArticles(slug);
  if (!found) notFound();
  const { name, articles } = found;
  const homeHref = lang === "en" ? "/en" : "/";

  return (
    <main className="min-h-screen bg-canvas font-sans" id="top">
      <div className="mx-auto max-w-2xl px-3 pt-3 pb-16 sm:px-5">
        <header className="relative flex min-h-9 items-center justify-center">
          <Link
            href={homeHref}
            className="text-[17px] font-bold no-underline"
          >
            SABA
          </Link>
        </header>

        <section className="mt-2 rounded-xl border border-line bg-white p-4 text-center shadow-sm">
          <span
            aria-hidden
            className={`mx-auto flex h-16 w-16 items-center justify-center rounded-full text-2xl font-extrabold ${avatarTone(name)}`}
          >
            {(name.charAt(0) || "S").toUpperCase()}
          </span>
          <h1 className="mt-2 text-[22px] leading-[30px] font-extrabold">
            {name}
          </h1>
          <p className="mt-1 text-[13px] text-[#727687]">
            {lang === "en" ? "Creator" : "Kreator"} •{" "}
            {articles.length}{" "}
            {lang === "en" ? "articles" : "artikel"}
          </p>
        </section>

        <section
          aria-label={lang === "en" ? "Articles" : "Artikel"}
          className="mt-2 rounded-xl border border-line bg-white p-4 shadow-sm"
        >
          <h2 className="text-[15px] font-bold">
            {lang === "en" ? "Articles" : "Artikel"}
          </h2>
          <ul className="mt-2 grid list-none grid-cols-[minmax(0,1fr)] gap-2 p-0">
            {articles.map((a) => {
              const b = pickBody(a, lang);
              const ago = timeAgo(a.createdAt, lang);
              return (
                <li key={a.id}>
                  <Link
                    href={articlePath(a.id, lang)}
                    className="block min-w-0 rounded-xl bg-canvas px-3 py-2.5 no-underline"
                  >
                    <span className="block truncate text-[14px] font-bold">
                      {b.title}
                    </span>
                    <span className="mt-1 block text-xs text-muted">
                      {compactViews(viewsOf(a.id))}{" "}
                      {lang === "en" ? "reads" : "dibaca"}
                      {ago ? ` • ${ago}` : ""}
                    </span>
                  </Link>
                </li>
              );
            })}
          </ul>
        </section>
      </div>

      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: escapeJsonLd({
            "@context": "https://schema.org",
            "@type": "ProfilePage",
            mainEntity: {
              "@type": "Person",
              name,
              url: kreatorUrl(name, lang),
            },
          }),
        }}
      />
    </main>
  );
}

export async function kreatorSlugs(): Promise<string[]> {
  const ids = await listArticleIds();
  const all = (
    await Promise.all(ids.map((id) => getArticle(id).catch(() => null)))
  ).filter((a) => a !== null);
  return listCreators(all)
    .map((c) => c.name.replace(/^@+/, "").trim())
    .filter((s) => s !== "");
}
