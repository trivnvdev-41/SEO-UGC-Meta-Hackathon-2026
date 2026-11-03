import { KreatorView, kreatorMetadata, kreatorSlugs } from "@/components/KreatorView";

export const revalidate = 3600;
export const dynamic = "force-dynamic";

type Props = {
  params: Promise<{ nama: string }>;
};

export async function generateStaticParams() {
  return (await kreatorSlugs()).map((nama) => ({ nama }));
}

export async function generateMetadata({ params }: Props) {
  return kreatorMetadata(decodeURIComponent((await params).nama), "en");
}

export default async function KreatorPage({ params }: Props) {
  return (
    <KreatorView slug={decodeURIComponent((await params).nama)} lang="en" />
  );
}
