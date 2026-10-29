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
