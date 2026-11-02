import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { FollowButton, ShareButton } from "@/components/ArticleExtras";
import { Comments } from "@/components/Comments";
import { FeedActions } from "@/components/FeedActions";
import { Reveal } from "@/components/ui/reveal";
import { avatarTone } from "@/components/HomeView";
import { ButtonKembali as IconBack } from "@/components/icons";
import {
  compactViews,
  getArticle,
  pickBody,
  ratingOf,
  timeAgo,
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
  const community = (brand || a.creator || (lang === "en" ? "review" : "ulasan")).replace(/^@/, "");
  const ago = timeAgo(a.createdAt, lang);
  const votes = a.votes ?? { up: 0, down: 0, score: 0, myVote: 0 as const };

  return (
    <main className="min-h-screen bg-canvas font-sans" id="top">
      <div className="mx-auto max-w-2xl px-3 pt-3 pb-16 sm:px-5">
        <header className="flex items-center gap-2">
          <a
            href={homeHref}
            aria-label={lang === "en" ? "Back" : "Kembali"}
            className="flex h-9 w-9 items-center justify-center rounded-full border border-line bg-white no-underline"
          >
            <IconBack width="1.1em" height="1.1em" />
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
            <ShareButton
              path={articlePath(id, lang)}
              label={lang === "en" ? "Share" : "Bagikan"}
            />
          </nav>
        </header>
        <p className="mt-3 truncate text-xs text-muted">
          <Link href={homeHref}>{lang === "en" ? "Home" : "Beranda"}</Link>
          {" / "}
          <span>
            c/{brand || (lang === "en" ? "review" : "ulasan")}
          </span>
        </p>

        <section
          aria-label={lang === "en" ? "Community" : "Komunitas"}
          className="mt-2 flex items-center gap-2 rounded-xl border border-line bg-white p-3 shadow-sm"
        >
          <span className="min-w-0">
            <span className="block truncate text-[17px] font-semibold">
              @{community}
              <span
                aria-hidden
                className="mx-1.5 inline-block h-1.5 w-1.5 rounded-full bg-saba align-middle"
              />
              <span className="text-[13px] font-normal text-[#727687]">
                {lang === "en" ? "Community" : "Komunitas"}
              </span>
            </span>
            <span className="block text-[13px] text-[#424656]">
              {compactViews(viewsOf(a.id))}{" "}
              {lang === "en" ? "reads" : "dibaca"}
            </span>
          </span>
          <span className="ml-auto">
            <FollowButton
              id={community}
              label={lang === "en" ? "Follow" : "Ikuti"}
              following={lang === "en" ? "Following" : "Diikuti"}
            />
          </span>
        </section>

        <article className="mt-2 rounded-xl border border-line bg-white p-4 shadow-sm">
          <div className="flex items-center gap-2">
            <span
              aria-hidden
              className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-full text-base font-bold ${avatarTone(a.id)}`}
            >
              @
            </span>
            <span className="min-w-0">
              <span className="flex flex-wrap items-center gap-1.5 text-[17px] font-bold">
                @{community}
                {a.creator ? (
                  <span className="rounded-full bg-saba-soft px-1.5 py-0.5 text-[10px] font-normal text-saba">
                    OP
                  </span>
                ) : null}
              </span>
              {ago ? (
                <span className="block text-[13px] text-[#727687]">
                  {ago}
                </span>
              ) : null}
            </span>
          </div>

          <h1 className="mt-2 text-[22px] leading-[30px] font-extrabold tracking-[-0.5px]">
            {body.title}
          </h1>
          <p className="mt-2 text-[15px] text-[#424656]">{body.meta}</p>
          {brand ? (
            <p className="mt-2">
              <span className="inline-block rounded-full bg-canvas px-2.5 py-1 text-[11px] font-bold text-saba">
                #{brand.replace(/\s+/g, "")}
              </span>
            </p>
          ) : null}
          {rating ? (
            <p className="mt-3 text-sm">
              <Badge variant="default">
                {rating.value}/5
                {rating.author ? ` · ${rating.author}` : null}
              </Badge>
            </p>
          ) : null}

          {photos.length ? (
            <Reveal>
              <section aria-label={lang === "en" ? "Product photos" : "Foto produk"} className="my-4">
                <div className="grid grid-cols-2 gap-2.5">
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
                            ? "aspect-video w-full rounded-t-xl object-cover"
                            : "aspect-square w-full rounded-t-xl object-cover"
                        }
                      />
                      <figcaption className="rounded-b-xl bg-canvas px-2.5 py-1.5 text-[13px] font-bold text-[#424656]">
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
              <figure className="my-4">
                <div className="aspect-video w-full overflow-hidden rounded-t-xl bg-neutral-100">
                  <iframe
                    src={video.embedUrl}
                    title={body.title}
                    className="h-full w-full border-0"
                    loading="lazy"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowFullScreen
                  />
                </div>
                {a.videoUrl ? (
                  <figcaption className="rounded-b-xl bg-canvas px-2.5 py-1.5 text-[13px] font-bold text-[#424656]">
                    <a href={a.videoUrl} target="_blank" rel="noreferrer">
                      {lang === "en" ? "Watch the original video" : "Tonton video asli"}
                    </a>
                  </figcaption>
                ) : null}
              </figure>
            </Reveal>
          ) : a.videoUrl ? (
            <p className="my-4 text-sm">
              <a href={a.videoUrl} target="_blank" rel="noreferrer">
                {lang === "en" ? "Watch the original video" : "Tonton video asli"}
              </a>
            </p>
          ) : null}

          <div className="text-[16px] leading-[26px] text-[#424656]">
            {renderMd(body.body_md)}
          </div>

          <FeedActions
            id={a.id}
            initial={votes}
            path={articlePath(a.id, lang)}
            lang={lang}
            t={{ copied: lang === "en" ? "Copied!" : "Disalin!" }}
          />
        </article>

        <div className="mt-2 rounded-xl border border-line bg-white p-4 shadow-sm">
          <Comments
            id={a.id}
            lang={lang}
            handle={community}
            t={
              lang === "en"
                ? {
                    title: "Community Answers",
                    empty: "No answers yet. Be the first to share your take.",
                    namePh: "Your name (required)",
                    textPh: `Reply to @${community}…`,
                    send: "Send reply",
                    needName: "Fill your name first (min. 2 characters).",
                  }
                : {
                    title: "Tanggapan & Jawaban Komunitas",
                    empty:
                      "Belum ada tanggapan. Jadilah yang pertama menanggapi.",
                    namePh: "Nama kamu (wajib)",
                    textPh: `Balas ke @${community}…`,
                    send: "Kirim tanggapan",
                    needName: "Isi nama dulu (min. 2 karakter).",
                  }
            }
          />
        </div>
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
