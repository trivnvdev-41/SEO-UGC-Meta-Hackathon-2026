import type { Metadata } from "next";
import { HomeView, revalidate as homeRevalidate } from "@/components/HomeView";
import { SITE_URL } from "@/lib/site";

export const revalidate = homeRevalidate;

export const metadata: Metadata = {
  title: "SEO UGC — Ulasan produk jujur dari video kreator",
  description:
    "Ulasan produk dari TikTok dan YouTube Shorts: foto, kelebihan dan kekurangan, serta skor dalam artikel dwibahasa.",
  alternates: {
    canonical: SITE_URL,
    languages: { id: SITE_URL, en: `${SITE_URL}/en`, "x-default": SITE_URL },
  },
};

export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const q = (await searchParams).q ?? "";
  return <HomeView lang="id" q={q} />;
}
