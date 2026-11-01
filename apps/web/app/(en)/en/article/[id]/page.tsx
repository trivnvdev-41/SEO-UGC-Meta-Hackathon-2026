import { ArticleView, articleMetadata } from "@/components/ArticleView";
import { listArticleIds } from "@/lib/articles";

export const revalidate = 3600;
// Lihat (id)/article/[id]/page.tsx: paksa SSR murni agar tak 500 di prod.
export const dynamic = "force-dynamic";

type Props = { params: Promise<{ id: string }> };

export async function generateStaticParams() {
  return (await listArticleIds()).map((id) => ({ id }));
}

export async function generateMetadata({ params }: Props) {
  return articleMetadata((await params).id, "en");
}

export default async function ArticlePage({ params }: Props) {
  return <ArticleView id={(await params).id} lang="en" />;
}
