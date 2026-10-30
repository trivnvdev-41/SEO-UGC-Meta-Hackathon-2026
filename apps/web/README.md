# Web (Next.js SEO)

Artikel SSR/ISR di `app/article/[id]` + **JSON-LD** + OG/Twitter tags + embed
resmi (TikTok, Instagram, YouTube) + switch bahasa `?lang=id|en`.
Styling: **Tailwind CSS 4** + **shadcn/ui** (`components/ui`).

## Setup

```bash
npm install --prefix apps/web
cp .env.example .env            # isi API_BASE_URL + NEXT_PUBLIC_SITE_URL
```

Butuh API hidup (`apps/api`) karena halaman dan `sitemap.xml` mengambil data
dari `GET /v1/articles`.

## Run

```bash
node --env-file=.env apps/api/src/server.js        # API :4301
npm run dev --prefix apps/web -- -p 4320           # web  :4320
```

Buka `http://localhost:4320/article/contoh-review`.

Note: `next build` also needs a running API (for `generateStaticParams`).

## Struktur

| Path | Isi |
|---|---|
| `app/article/[id]/page.tsx` | SSR/ISR artikel, metadata, JSON-LD (di-escape), `renderMd` |
| `app/sitemap.ts`, `app/robots.ts` | sitemap + robots |
| `components/Embed.tsx` | iframe YouTube (`youtube-nocookie`), oEmbed TikTok/Instagram |
| `components/ui/` | komponen shadcn (`card`, `badge`) |
| `lib/articles.ts` | fetch artikel dari API (ISR 1 jam) |
| `lib/site.ts` | URL kanonik + helper per bahasa |

## E2E (Playwright)

```bash
npm run test:e2e --prefix apps/web
```

Menjalankan API (`:4301`) + `next dev` (`:4320`) sendiri, lalu uji: H1/embed/JSON-LD,
switch bahasa, dan 404. Butuh Postgres (`seougc-pg`) + data seed.
Screenshots land in `e2e/__screenshots__/` (gitignored); copies used for issues
live in `docs/e2e/`.
