import type { Metadata } from "next";
import { UnduhView } from "@/components/UnduhView";
import { SITE_URL } from "@/lib/site";

export const revalidate = 3600;

export const metadata: Metadata = {
  title: "Unduh Aplikasi SABA — Android",
  description:
    "Download aplikasi Android SABA gratis: upload video galeri, vote jujur, dan diskusi kreator.",
  alternates: {
    canonical: `${SITE_URL}/unduh`,
    languages: {
      id: `${SITE_URL}/unduh`,
      en: `${SITE_URL}/en/unduh`,
      "x-default": `${SITE_URL}/unduh`,
    },
  },
};

export default async function UnduhPage() {
  return <UnduhView lang="id" />;
}
