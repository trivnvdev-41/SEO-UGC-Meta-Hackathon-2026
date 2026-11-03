# Web (Next.js SEO — SABA)

Artikel SSR/ISR di `app/(id)/article/[id]` (ID) + `app/(en)/en/article/[id]`
(EN) + halaman forum `jelajah` — **JSON-LD** + OG/Twitter tags + galeri
maksimal 3 foto produk + tautan video asli.
Styling: **Tailwind CSS 4** + **shadcn/ui** (`components/ui`).

## Setup

```bash
npm install --prefix apps/web
cp .env.example .env            # dari root repo; isi API_BASE_URL + NEXT_PUBLIC_SITE_URL
```

Butuh API hidup (`apps/api`) karena halaman dan `sitemap.xml` mengambil data
dari `GET /v1/articles`.

## Run

```bash
node --env-file=.env apps/api/src/server.js        # API :4301
npm run dev --prefix apps/web -- -p 4320           # web  :4320
```

Buka `http://localhost:4320/` (atau `/en` untuk English,
`/jelajah` untuk forum). `NEXT_PUBLIC_SITE_URL` default
`http://localhost:3000` bila env tidak di-set — samakan dengan port yang
dipakai (`-p 4320`) agar canonical/sitemap benar.

Note: `next build` also needs a running API (for `generateStaticParams`).

## Struktur

| Path | Isi |
|---|---|
| `app/(id)/article/[id]/page.tsx` | SSR/ISR artikel (ID), metadata, JSON-LD (di-escape), `renderMd` |
| `app/(en)/en/article/[id]/page.tsx` | varian English |
| `app/(id)/jelajah/page.tsx`, `app/(en)/en/jelajah/page.tsx` | halaman forum + canonical/hreflang |
| `app/sitemap.ts`, `app/robots.ts`, `app/llms.txt/` | sitemap + robots + llms.txt |
| `components/` (`HomeView`, `JelajahView`, `ArticleView`, `Comments`, `FeedActions`) | tampilan forum + artikel |
| `components/ui/` | komponen shadcn (`card`, `badge`) |
| `lib/articles.ts` | fetch artikel dari API (ISR 1 jam) |
| `lib/site.ts` | URL kanonik + helper per bahasa (`/en/article/...`) |

## E2E (Playwright)

```bash
npm run test:e2e --prefix apps/web
```

Menjalankan API (`:4301`) + `next dev` (`:4320`) sendiri, lalu uji: H1/galeri foto/JSON-LD,
switch bahasa, dan 404. Butuh Postgres (`seougc-pg`) + data seed.
Screenshots land in `e2e/__screenshots__/` (gitignored); copies used for issues
live in `docs/e2e/`.
