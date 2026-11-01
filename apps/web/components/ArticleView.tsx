import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Comments } from "@/components/Comments";
import { Reveal } from "@/components/ui/reveal";
import {
  compactViews,
  formatDate,
  getArticle,
  pickBody,
  ratingOf,
  viewsOf,
  type Lang,
} from "@/lib/articles";
import { escapeJsonLd } from "@/lib/jsonld";
import { renderMd } from "@/lib/markdown";
import { articlePath, articleUrl } from "@/lib/site";
import { videoObject } from "@/lib/structured";

export async function articleMetadata(id: string, lang: Lang): Promise<Metadata> {
  const a = await getArticle(id);
  if (!a) return {};

  const body = pickBody(a, lang);
  const url = articleUrl(id, lang);

  return {
    title: body.title,
    description: body.meta,
    alternates: {
      canonical: url,
      languages: {
        id: articleUrl(id, "id"),
        en: articleUrl(id, "en"),
        "x-default": articleUrl(id, "id"),
      },
    },
    openGraph: {
      type: "article",
      url,
      title: body.title,
      description: body.meta,
      images: a.images.length ? a.images : undefined,
    },
    twitter: {
      card: a.images.length ? "summary_large_image" : "summary",
      title: body.title,
      description: body.meta,
      images: a.images.length ? a.images : undefined,
    },
  };
}

export async function ArticleView({ id, lang }: { id: string; lang: Lang }) {
  const a = await getArticle(id);
  if (!a) notFound();

  const body = pickBody(a, lang);
  const video = videoObject(a, body);
  const rating = ratingOf(a.json_ld);
  const photos = a.images.slice(0, 3);
  const homeHref = lang === "en" ? "/en" : "/";
  let brand = "";
  try {
    const br = (a.json_ld as Record<string, unknown>).brand as
      | Record<string, unknown>
      | undefined;
    if (typeof br?.name === "string") brand = br.name;
  } catch {
    brand = "";
  }

  return (
    <main className="mx-auto max-w-2xl px-5 pt-5 pb-16">
      <header className="mb-6 font-sans">
        <div className="flex items-center gap-2">
          <a
            href={homeHref}
            aria-label={lang === "en" ? "Back" : "Kembali"}
            className="flex h-8 w-8 items-center justify-center rounded-full border border-line no-underline"
          >
            <span aria-hidden>←</span>
          </a>
          <a
            href={homeHref}
            className="flex items-center gap-2 no-underline"
          >
            <span className="flex h-7 w-7 items-center justify-center rounded-full bg-saba text-sm font-bold text-white">
              S
            </span>
            <span className="text-sm font-extrabold tracking-tight">
              SABA
            </span>
          </a>
          <nav className="ml-auto flex items-center gap-1.5">
            <Link href={articlePath(id, "id")}>
              <Badge variant={lang === "id" ? "default" : "outline"}>
                ID
              </Badge>
            </Link>
            <Link href={articlePath(id, "en")}>
              <Badge variant={lang === "en" ? "default" : "outline"}>
                EN
              </Badge>
            </Link>
          </nav>
        </div>
        <p className="mt-3 truncate text-xs text-muted">
          <Link href={homeHref}>{lang === "en" ? "Home" : "Beranda"}</Link>
          {" / "}
          <span>
            c/{brand || (lang === "en" ? "review" : "ulasan")}
          </span>
        </p>
      </header>

      <h1 className="text-[clamp(1.75rem,1rem+3vw,2.75rem)] leading-[1.1]">
        {body.title}
      </h1>
      {a.creator ? (
        <p className="mt-2 font-sans text-sm text-muted">
          {lang === "en" ? `By ${a.creator}` : `Oleh ${a.creator}`}
        </p>
      ) : null}
      <p className="mt-2 font-sans text-base text-muted">{body.meta}</p>
      <p className="mt-2 font-sans text-xs text-muted">
        {[
          formatDate(a.createdAt, lang)
            ? lang === "en"
              ? `Released ${formatDate(a.createdAt, lang)}`
              : `Rilis ${formatDate(a.createdAt, lang)}`
            : null,
          lang === "en"
            ? `${compactViews(viewsOf(a.id))} views`
            : `${compactViews(viewsOf(a.id))} dilihat`,
          a.creator ?? null,
        ]
          .filter(Boolean)
          .join(" • ")}
      </p>
      {rating ? (
        <p className="mt-3 font-sans text-sm">
          <Badge variant="default">
            {rating.value}/5
            {rating.author ? ` · ${rating.author}` : null}
          </Badge>
        </p>
      ) : null}

      {photos.length ? (
        <Reveal>
        <section aria-label={lang === "en" ? "Product photos" : "Foto produk"} className="my-6">
          <div className="grid grid-cols-2 gap-3">
            {photos.map((src, i) => (
              <figure
                key={src}
                className={i === 0 ? "col-span-2" : undefined}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={src}
                  alt={`${body.title} — ${lang === "en" ? "photo" : "foto"} ${i + 1}`}
                  loading={i === 0 ? undefined : "lazy"}
                    className={
                      i === 0
                        ? "aspect-video w-full rounded-2xl object-cover"
                        : "aspect-square w-full rounded-2xl object-cover"
                    }
                />
                      <figcaption className="mt-1 font-sans text-sm text-muted">
                  {lang === "en" ? "Photo" : "Foto"} {i + 1}
                  {photos.length > 1 ? ` / ${photos.length}` : null}
                </figcaption>
              </figure>
            ))}
          </div>
        </section>
        </Reveal>
      ) : null}

      {video ? (
        <Reveal>
        <figure className="my-6">
          <div className="aspect-video w-full overflow-hidden rounded-2xl bg-neutral-100">
            <iframe
              src={video.embedUrl}
              title={body.title}
              className="h-full w-full border-0"
              loading="lazy"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowFullScreen
            />
          </div>
          <figcaption className="mt-1 font-sans text-sm text-muted">
            <a href={a.videoUrl} target="_blank" rel="noreferrer">
              {lang === "en" ? "Watch the original video" : "Tonton video asli"}
            </a>
          </figcaption>
        </figure>
        </Reveal>
      ) : (
        <p className="my-4 font-sans text-sm">
          <a href={a.videoUrl} target="_blank" rel="noreferrer">
            {lang === "en" ? "Watch the original video" : "Tonton video asli"}
          </a>
        </p>
      )}

      {renderMd(body.body_md)}

      <div className="mt-8 rounded-2xl border border-line bg-white p-4 font-sans sm:p-5">
        <Comments
          id={a.id}
          lang={lang}
          t={
            lang === "en"
              ? {
                  title: "Comments",
                  empty: "No comments yet. Be the first to share your take.",
                  namePh: "Your name (required)",
                  emailPh: "Email (optional)",
                  textPh: "Write a comment…",
                  send: "Send comment",
                  needName: "Fill your name first (min. 2 characters).",
                }
              : {
                  title: "Komentar",
                  empty:
                    "Belum ada komentar. Jadilah yang pertama menanggapi.",
                  namePh: "Nama kamu (wajib)",
                  emailPh: "Email (opsional)",
                  textPh: "Tulis komentar…",
                  send: "Kirim komentar",
                  needName: "Isi nama dulu (min. 2 karakter).",
                }
          }
        />
      </div>

      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: escapeJsonLd(a.json_ld) }}
      />
      {video ? (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: escapeJsonLd(video) }}
        />
      ) : null}
    </main>
  );
}
