import { permanentRedirect } from "next/navigation";
import { ArticleView, articleMetadata } from "@/components/ArticleView";
import { listArticleIds } from "@/lib/articles";
import { articlePath } from "@/lib/site";

export const revalidate = 3600;
// ISR fallback + await searchParams = DYNAMIC_SERVER_USAGE (500) di prod,
// jadi render SSR murni. SEO tidak berubah (HTML tetap penuh dari server).
export const dynamic = "force-dynamic";

type Props = {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ lang?: string }>;
};

export async function generateStaticParams() {
  return (await listArticleIds()).map((id) => ({ id }));
}

export async function generateMetadata({ params }: Props) {
  return articleMetadata((await params).id, "id");
}

export default async function ArticlePage({ params, searchParams }: Props) {
  const id = (await params).id;
  // URL lama (?lang=en) diarahkan permanen ke path bahasa.
  const lang = (await searchParams).lang;
  if (lang) {
    permanentRedirect(articlePath(id, lang === "en" ? "en" : "id"));
  }
  return <ArticleView id={id} lang="id" />;
}
