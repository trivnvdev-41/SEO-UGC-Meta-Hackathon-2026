import type { Metadata } from "next";
import { UnduhView } from "@/components/UnduhView";
import { SITE_URL } from "@/lib/site";

export const revalidate = 3600;

export const metadata: Metadata = {
  title: "Download SABA App — Android",
  description:
    "Download the free SABA Android app: gallery video upload, honest votes, and creator discussion.",
  alternates: {
    canonical: `${SITE_URL}/en/unduh`,
    languages: {
      id: `${SITE_URL}/unduh`,
      en: `${SITE_URL}/en/unduh`,
      "x-default": `${SITE_URL}/unduh`,
    },
  },
};

export default async function UnduhPageEn() {
  return <UnduhView lang="en" />;
}
