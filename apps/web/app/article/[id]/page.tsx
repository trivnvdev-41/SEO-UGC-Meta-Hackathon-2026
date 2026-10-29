import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Embed } from "../../../components/Embed";
import { getArticle, listArticleIds, pickBody, type Lang } from "../../../lib/articles";

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
  const a = await getArticle((await params).id);
  if (!a) return {};
  const body = pickBody(a, langOf(await searchParams));
  return {
    title: body.title,
    description: body.meta,
    openGraph: {
      title: body.title,
      description: body.meta,
      images: a.images.length ? a.images : undefined,
    },
  };
}

function renderMd(md: string) {
  // shortcut: renderer md minimal (heading + list + paragraf),
  // ganti markdown lib saat butuh tabel/gfm.
  return md.split("\n\n").map((block, i) => {
    if (block.startsWith("## ")) return <h2 key={i}>{block.slice(3)}</h2>;
    if (block.startsWith("# ")) return <h1 key={i}>{block.slice(2)}</h1>;
    if (block.startsWith("- ")) {
      return (
        <ul key={i}>
          {block.split("\n").map((li, j) => (
            <li key={j}>{li.replace(/^- /, "")}</li>
          ))}
        </ul>
      );
    }
    return <p key={i}>{block}</p>;
  });
}

export default async function ArticlePage(
  { params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ lang?: string }> },
) {
  const a = await getArticle((await params).id);
  if (!a) notFound();
  const body = pickBody(a, langOf(await searchParams));
  return (
    <main className="article">
      <p className="lang-switch">
        <a href="?lang=id">ID</a> · <a href="?lang=en">EN</a>
      </p>
      <h1>{body.title}</h1>
      <p className="meta">{body.meta}</p>
      <Embed url={a.videoUrl} />
      {a.images.map((src) => (
        // eslint-disable-next-line @next/next/no-img-element
        <img key={src} src={src} alt={body.title} loading="lazy" />
      ))}
      {renderMd(body.body_md)}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(a.json_ld) }}
      />
    </main>
  );
}
