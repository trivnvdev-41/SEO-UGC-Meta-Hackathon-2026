import type { Metadata } from "next";
import { JelajahView } from "@/components/JelajahView";
import { SITE_URL } from "@/lib/site";

export const revalidate = 3600;

export const metadata: Metadata = {
  title: "Jelajah — SABA",
  description: "Jelajahi topik, komunitas, dan kreator di SABA.",
  alternates: {
    canonical: `${SITE_URL}/jelajah`,
    languages: {
      id: `${SITE_URL}/jelajah`,
      en: `${SITE_URL}/en/jelajah`,
      "x-default": `${SITE_URL}/jelajah`,
    },
  },
};

export default async function JelajahPage() {
  return <JelajahView lang="id" />;
}
