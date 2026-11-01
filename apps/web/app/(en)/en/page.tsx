import type { Metadata } from "next";
import { HomeView } from "@/components/HomeView";
import { SITE_URL } from "@/lib/site";

export const revalidate = 3600;

export const metadata: Metadata = {
  title: "SABA — Honest product reviews from creator videos",
  description:
    "Product reviews from TikTok and YouTube Shorts: photos, pros and cons, and scores in bilingual articles.",
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
