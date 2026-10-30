import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Embed } from "@/components/Embed";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { getArticle, pickBody, ratingOf, type Lang } from "@/lib/articles";
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

  return (
    <main className="mx-auto max-w-2xl px-5 pt-10 pb-16">
      <header className="mb-8 border-b pb-4 font-sans">
        <a href={lang === "en" ? "/en" : "/"} className="text-sm font-semibold">
          SEO UGC
        </a>
      </header>
      <nav className="mb-6 flex items-center gap-2 font-sans text-xs">
        <Link href={articlePath(id, "id")}>
          <Badge variant={lang === "id" ? "default" : "outline"}>ID</Badge>
        </Link>
        <Link href={articlePath(id, "en")}>
          <Badge variant={lang === "en" ? "default" : "outline"}>EN</Badge>
        </Link>
      </nav>

      <h1>{body.title}</h1>
      <p className="mt-2 font-sans text-base text-muted">{body.meta}</p>
      {rating ? (
        <p className="mt-3 font-sans text-sm">
          <Badge variant="default">
            ★ {rating.value}/5
            {rating.author ? ` · ${rating.author}` : null}
          </Badge>
        </p>
      ) : null}

      <Card className="my-6 overflow-hidden rounded-2xl shadow-[0_8px_24px_rgba(0,0,0,0.10)]">
        <CardContent className="p-3">
          <Embed url={a.videoUrl} />
        </CardContent>
      </Card>

      {a.images.map((src) => (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          key={src}
          src={src}
          alt={body.title}
          loading="lazy"
          className="my-4 w-full rounded-2xl shadow-[0_8px_24px_rgba(0,0,0,0.10)]"
        />
      ))}

      {renderMd(body.body_md)}

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
