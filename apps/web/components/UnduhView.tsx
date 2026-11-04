import Link from "next/link";
import { BrandLogo } from "@/components/BrandLogo";
import { APK_URL } from "@/lib/site";
import type { Lang } from "@/lib/articles";

const T = {
  id: {
    eyebrow: "APLIKASI ANDROID · GRATIS",
    title: "Bawa ulasan jujur ke kantongmu.",
    sub: "Pilih video dari galeri, jadi artikel terstruktur. Vote dan diskusi bareng kreator — semua dari HP.",
    cta: "Download APK",
    note: "Android 8+ · belum di Play Store, install via file",
    back: "← Kembali ke feed",
    stepsTitle: "Cara install",
    steps: [
      ["1", "Unduh APK", "Ketuk tombol download di halaman ini."],
      ["2", "Izinkan install", 'Aktifkan "sumber tak dikenal" saat diminta.'],
      ["3", "Buka SABA", "Install, buka, langsung jelajah."],
    ],
    featTitle: "Kenapa pakai aplikasi?",
    feats: [
      ["Upload galeri", "Pilih video, artikel jadi di server."],
      ["Vote jujur", "Setuju / Kurang, 1 suara per orang."],
      ["Diskusi", "Komentar + profil kreator."],
    ],
    faqTitle: "Sering ditanya",
    faqs: [
      ["Gratis?", "Ya, gratis."],
      ["HP apa?", "Android 8 ke atas. Belum ada iOS."],
      ["Perlu akun?", "Belum — votemu tersimpan di perangkat."],
    ],
    ctaBottom: "Siap coba?",
  },
  en: {
    eyebrow: "FREE ANDROID APP",
    title: "Honest reviews in your pocket.",
    sub: "Pick a video from your gallery, get a structured article. Vote and discuss with creators — all from your phone.",
    cta: "Download APK",
    note: "Android 8+ · not on Play Store yet, sideload via file",
    back: "← Back to feed",
    stepsTitle: "How to install",
    steps: [
      ["1", "Download APK", "Tap the download button on this page."],
      ["2", "Allow install", 'Enable "unknown sources" when asked.'],
      ["3", "Open SABA", "Install, open, start exploring."],
    ],
    featTitle: "Why use the app?",
    feats: [
      ["Gallery upload", "Pick a video, the article is made on server."],
      ["Honest votes", "Agree / Disagree, 1 vote each."],
      ["Discussion", "Comments + creator profiles."],
    ],
    faqTitle: "FAQ",
    faqs: [
      ["Free?", "Yes, free."],
      ["Which phones?", "Android 8+. No iOS yet."],
      ["Account needed?", "Not yet — your votes stay on device."],
    ],
    ctaBottom: "Ready to try?",
  },
} as const;

export function UnduhView({ lang }: { lang: Lang }) {
  const t = T[lang];
  const home = lang === "en" ? "/en" : "/";
  return (
    <div className="min-h-screen bg-canvas font-sans">
      <header className="sticky top-0 z-10 border-b border-line bg-white/90 backdrop-blur">
        <div className="relative mx-auto flex min-h-16 max-w-3xl items-center justify-center px-5">
          <Link
            href={home}
            aria-label={t.back}
            className="absolute left-5 flex h-9 items-center rounded-full bg-canvas px-3 text-xs font-bold text-ink no-underline"
          >
            {t.back}
          </Link>
          <BrandLogo />
        </div>
      </header>
      <main className="mx-auto max-w-3xl px-5 pt-10 pb-16">
        <section className="rounded-2xl border border-line bg-white p-6 text-center shadow-sm">
          <p className="text-xs font-bold tracking-wide text-saba">{t.eyebrow}</p>
          <h1 className="mt-2 text-3xl">{t.title}</h1>
          <p className="mx-auto mt-3 max-w-md text-sm text-muted">{t.sub}</p>
          <a
            href={APK_URL}
            className="mt-5 inline-flex h-12 items-center gap-2 rounded-full bg-saba px-8 text-base font-bold text-white no-underline shadow"
          >
            <span aria-hidden>↓</span> {t.cta}
          </a>
          <p className="mt-2 text-xs text-muted">{t.note}</p>
        </section>

        <section className="mt-4 rounded-2xl border border-line bg-white p-6 shadow-sm">
          <h2 className="mt-0">{t.stepsTitle}</h2>
          <ol className="list-none p-0">
            {t.steps.map(([n, title, desc]) => (
              <li key={n} className="flex gap-3 py-2">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-saba-soft text-sm font-bold text-saba">
                  {n}
                </span>
                <span>
                  <span className="block text-sm font-bold">{title}</span>
                  <span className="block text-xs text-muted">{desc}</span>
                </span>
              </li>
            ))}
          </ol>
        </section>

        <section className="mt-4 rounded-2xl border border-line bg-white p-6 shadow-sm">
          <h2 className="mt-0">{t.featTitle}</h2>
          <div className="grid gap-3 sm:grid-cols-3">
            {t.feats.map(([title, desc]) => (
              <div key={title} className="rounded-xl bg-canvas p-4">
                <p className="text-sm font-bold">{title}</p>
                <p className="mt-1 text-xs text-muted">{desc}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="mt-4 rounded-2xl border border-line bg-white p-6 shadow-sm">
          <h2 className="mt-0">{t.faqTitle}</h2>
          <dl>
            {t.faqs.map(([q, a]) => (
              <div key={q} className="border-b border-canvas py-2 last:border-0">
                <dt className="text-sm font-bold">{q}</dt>
                <dd className="m-0 text-xs text-muted">{a}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section className="mt-4 rounded-2xl bg-saba p-6 text-center text-white shadow-sm">
          <p className="text-lg font-bold">{t.ctaBottom}</p>
          <a
            href={APK_URL}
            className="mt-3 inline-flex h-12 items-center gap-2 rounded-full bg-white px-8 text-base font-bold text-saba no-underline"
          >
            <span aria-hidden>↓</span> {t.cta}
          </a>
        </section>
      </main>
    </div>
  );
}
