import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Embed } from "../../../components/Embed";
import { Badge } from "../../../components/ui/badge";
import { Card, CardContent } from "../../../components/ui/card";
import { getArticle, listArticleIds, pickBody, type Lang } from "../../../lib/articles";
import { articleUrl } from "../../../lib/site";
import { videoObject } from "../../../lib/structured";
import { escapeJsonLd } from "../../../lib/jsonld";
import { renderMd } from "../../../lib/markdown";

export const revalidate = 3600;

function langOf(sp: { lang?: string }): Lang {
  return sp.lang === "en" ? "en" : "id";
}

export async function generateStaticParams() {
  return (await listArticleIds()).map((id) => ({ id }));
}

export async function generateMetadata(
  { params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ lang?: string }> },
): Promise<Metadata> {
  const id = (await params).id;
  const a = await getArticle(id);
  if (!a) return {};

  const lang = langOf(await searchParams);
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

export default async function ArticlePage(
  { params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ lang?: string }> },
) {
  const id = (await params).id;
  const a = await getArticle(id);
  if (!a) notFound();
  const lang = langOf(await searchParams);
  const body = pickBody(a, lang);
  const ld = escapeJsonLd(a.json_ld);
  const video = videoObject(a, body);
  return (
    <main className="mx-auto max-w-2xl px-5 pt-10 pb-16">
      <nav className="mb-6 flex items-center gap-2 font-sans text-xs">
        <a href="?lang=id">
          <Badge variant={lang === "id" ? "default" : "outline"}>ID</Badge>
        </a>
        <a href="?lang=en">
          <Badge variant={lang === "en" ? "default" : "outline"}>EN</Badge>
        </a>
      </nav>

      <h1>{body.title}</h1>
      <p className="mt-2 font-sans text-base text-muted">{body.meta}</p>

      <Card className="my-6 overflow-hidden">
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
          className="my-4 w-full rounded-lg"
        />
      ))}

      {renderMd(body.body_md)}

      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: ld }}
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
