import type { Metadata } from "next";
import { HomeView, revalidate as homeRevalidate } from "@/components/HomeView";
import { SITE_URL } from "@/lib/site";

export const revalidate = homeRevalidate;

export const metadata: Metadata = {
  title: "SEO UGC — Honest product reviews from creator videos",
  description:
    "Product reviews from TikTok, Reels, and YouTube Shorts: photos, pros and cons, and scores in bilingual articles.",
  alternates: {
    canonical: `${SITE_URL}/en`,
    languages: { id: SITE_URL, en: `${SITE_URL}/en`, "x-default": SITE_URL },
  },
};

export default async function HomePageEn({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const q = (await searchParams).q ?? "";
  return <HomeView lang="en" q={q} />;
}
