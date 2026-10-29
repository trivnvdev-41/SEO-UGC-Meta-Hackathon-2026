import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "SEO UGC",
  description: "Ulasan produk dari video kreator, terstruktur untuk mesin pencari.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  );
}
