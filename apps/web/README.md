# Web (Next.js SEO)

Artikel SSR di `app/article/[id]` + **JSON-LD** + OG tags + **oEmbed player**
(TikTok / Instagram) + switch bahasa `?lang=id|en`.

## Setup

```bash
export npm_config_cache=/tmp/npm-cache
npm install --prefix apps/web --no-bin-links
```

## Run

```bash
node apps/web/node_modules/next/dist/bin/next dev apps/web
```

Buka di browser: `http://localhost:3000/article/contoh-review`

## E2E (Playwright)

```bash
npm run test:e2e --prefix apps/web
```

Menjalankan API (`:4301`) + `next dev` sendiri, lalu uji: H1/embed/JSON-LD,
switch bahasa, dan 404. Butuh Postgres (`seougc-pg`) + data seed.
Screenshot tersimpan di `e2e/__screenshots__/` (gitignored).
