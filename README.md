# SEO UGC

Konversi link video UGC (TikTok / IG Reels) menjadi artikel web SEO + **JSON-LD Schema** + **official embed**.

## Struktur

| Path | Isi |
|---|---|
| `apps/mobile` | Share Target Receiver (`ACTION_SEND`) |
| `apps/web` | Next.js SSR/ISR public SEO web |
| `apps/api` | Node.js Gateway (`POST /v1/convert`) |
| `workers/processor` | Python FastAPI media worker (`/tmp` ephemeral) |

## Menjalankan lokal

1. Copy env: `cp .env.example .env`
2. Isi blok `AI_STT_*` (transcribe) dan `AI_LLM_*` (artikel) di `.env` — dua provider/key boleh beda (jangan commit).
3. Database (Postgres 16 via Docker, port `55432`):
   ```bash
   docker run -d --name seougc-pg -p 55432:5432 \
     -e POSTGRES_USER=seougc -e POSTGRES_PASSWORD=seougc -e POSTGRES_DB=seougc \
     postgres:16-alpine
   set -a; source .env; set +a           # Prisma CLI butuh DATABASE_URL
   npm run db:migrate --prefix apps/api
   npm run db:seed --prefix apps/api
   ```
4. Install dependency:
   ```bash
   npm install --prefix apps/api
   npm install --prefix apps/web
   UV_CACHE_DIR=/tmp/uv-cache uv pip install --python workers/processor/.venv/bin/python -e workers/processor
   ```
5. Butuh `ffmpeg` + `yt-dlp` di `PATH` (tanpa sudo: `uv pip install imageio-ffmpeg`, lalu symlink binernya sebagai `ffmpeg`).
6. Jalankan (port default `4301` API, `4302` worker, `3000` web — lihat `.env`):
   ```bash
   node --env-file=.env apps/api/src/server.js
   set -a; source .env; set +a
   workers/processor/.venv/bin/uvicorn processor.app:app --app-dir workers/processor/src --port 4302
   npm run dev --prefix apps/web
   ```
7. Mobile (opsional): `cd apps/mobile && flutter run --dart-define=API_BASE=http://10.0.2.2:4301`
8. Ikuti README tiap `apps/*` / `workers/*` untuk detail per tahap.

## Built During Hackathon

- [x] Mobile Share Receiver (Flutter, Android `ACTION_SEND`; iOS extension masih sumber, belum ter-wire)
- [x] API Gateway + BullMQ queue + consumer (queue → worker → persist)
- [x] Python worker: yt-dlp + FFmpeg + `/tmp` purge (`finally`)
- [x] STT + artikel multimodal, dua provider terpisah via env (`AI_STT_*`, `AI_LLM_*`)
- [x] Next.js artikel + JSON-LD + oEmbed (TikTok, Instagram, YouTube)
- [x] SEO: canonical/hreflang, sitemap, robots, JSON-LD di-escape
- [x] Security: allowlist domain, token internal, rate limit, batas ukuran/durasi video
- [x] Prisma/PostgreSQL (Article + Job)
- [x] Playwright E2E (3 test)
- [ ] Upload gambar ke S3/R2 (kode + test siap, menunggu credential)

## Pre-existing Dependencies

Next.js 15, React 19, TypeScript, Tailwind CSS 4, shadcn/ui, Prisma + PostgreSQL,
Redis + BullMQ, FastAPI + Pydantic, yt-dlp, FFmpeg, boto3, Flutter 3.44,
Playwright. HTTP gateway memakai `node:http` (bukan Express/NestJS).
