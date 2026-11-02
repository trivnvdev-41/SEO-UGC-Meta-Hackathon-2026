import type { Metadata } from "next";
import { JelajahView } from "@/components/JelajahView";
import { SITE_URL } from "@/lib/site";

export const revalidate = 3600;

export const metadata: Metadata = {
  title: "Explore — SABA",
  description: "Browse topics, communities, and creators on SABA.",
  alternates: {
    canonical: `${SITE_URL}/en/jelajah`,
    languages: {
      id: `${SITE_URL}/jelajah`,
      en: `${SITE_URL}/en/jelajah`,
      "x-default": `${SITE_URL}/jelajah`,
    },
  },
};

export default async function JelajahPageEn() {
  return <JelajahView lang="en" />;
}
