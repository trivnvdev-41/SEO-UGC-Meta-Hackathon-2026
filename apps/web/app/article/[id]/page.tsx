import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Embed } from "../../../components/Embed";
import { getArticle, listArticleIds, pickBody, type Lang } from "../../../lib/articles";
import { articleUrl } from "../../../lib/site";

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

// Markdown minimal: heading, list, bold, link. Teks dirender sebagai node React
// (auto-escaped), jadi tidak ada HTML mentah dari output model.
function inline(text: string, keyPrefix: string): React.ReactNode[] {
  const out: React.ReactNode[] = [];
  const re = /\*\*(.+?)\*\*|\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let i = 0;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) out.push(text.slice(last, m.index));
    out.push(
      m[1] ? (
        <strong key={`${keyPrefix}-b${i}`}>{m[1]}</strong>
      ) : (
        <a key={`${keyPrefix}-a${i}`} href={m[3]} rel="nofollow noopener">
          {m[2]}
        </a>
      ),
    );
    last = m.index + m[0].length;
    i += 1;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

function renderMd(md: string) {
  // shortcut: renderer md minimal (heading + list + bold/link),
  // ganti markdown lib saat butuh tabel/gfm.
  return md.split("\n\n").map((block, i) => {
    const lines = block.split("\n");
    if (block.startsWith("## ")) return <h2 key={i}>{inline(block.slice(3), `h${i}`)}</h2>;
    // H1 sudah dipakai judul artikel, jadi heading level 1 dari model jadi h2.
    if (block.startsWith("# ")) return <h2 key={i}>{inline(block.slice(2), `h${i}`)}</h2>;
    if (lines.every((l) => l.startsWith("- "))) {
      return (
        <ul key={i}>
          {lines.map((li, j) => (
            <li key={j}>{inline(li.slice(2), `l${i}-${j}`)}</li>
          ))}
        </ul>
      );
    }
    return <p key={i}>{inline(block, `p${i}`)}</p>;
  });
}

export default async function ArticlePage(
  { params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ lang?: string }> },
) {
  const id = (await params).id;
  const a = await getArticle(id);
  if (!a) notFound();
  const body = pickBody(a, langOf(await searchParams));
  const ld = JSON.stringify(a.json_ld).replace(/</g, "\\u003c");
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
        dangerouslySetInnerHTML={{ __html: ld }}
      />
    </main>
  );
}
