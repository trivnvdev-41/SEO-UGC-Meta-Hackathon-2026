import type { Metadata } from "next";
import { HomeView } from "@/components/HomeView";
import { SITE_URL } from "@/lib/site";

export const revalidate = 3600;

export const metadata: Metadata = {
  title: "SABA — Ulasan produk jujur dari video kreator",
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
