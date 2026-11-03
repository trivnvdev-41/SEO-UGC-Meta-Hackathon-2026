# API (Node.js gateway)

Gateway `node:http` (tanpa framework) untuk **SABA**: terima upload video,
antrean BullMQ, persist via Prisma/PostgreSQL.

## Endpoints

| Method | Path | Keterangan |
|---|---|---|
| `POST` | `/v1/uploads` | Upload video langsung (raw `video/*` bytes, dari mobile) |
| `GET` | `/v1/articles` | Daftar artikel (dipakai web + sitemap) |
| `GET` | `/v1/articles/:id` | Detail artikel |
| `GET/POST` | `/v1/votes` | Vote forum (rate-limit 30/menit per IP) |

## Setup

```bash
npm install --prefix apps/api
cp .env.example .env            # dari root repo; isi DATABASE_URL + REDIS_URL
set -a; source .env; set +a
npm run db:migrate --prefix apps/api
npm run db:seed --prefix apps/api
```

## Run

```bash
node --env-file=.env apps/api/src/server.js   # :4301, dari root repo
```

Butuh Postgres (`saba-pg`, port `55432`) + Redis (`REDIS_URL`,
default `redis://localhost:6379`). Consumer BullMQ jalan di proses yang
sama (`src/queue.js` → worker `http://localhost:4302`).

## Struktur

| Path | Isi |
|---|---|
| `src/server.js` | entrypoint |
| `src/makeApp.js` | routing + rate limit |
| `src/queue.js` | BullMQ producer/consumer |
| `src/uploadIngress.js` | terima + simpan upload ke `MEDIA_DIR` |
| `src/validateUrl.js` | allowlist domain + tolak SSRF |
| `prisma/` | schema + `seed.mjs` |

## Test

```bash
npm test --prefix apps/api
```

Butuh Redis jalan; tanpa Redis, 2 test antrean otomatis skip.
