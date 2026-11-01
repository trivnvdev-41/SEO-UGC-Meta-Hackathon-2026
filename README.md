# SEO UGC

Turn UGC video links (TikTok / YouTube) into SEO-ready web articles with
**JSON-LD schema** and an **official embed**.

## Structure

| Path | Contents |
|---|---|
| `apps/mobile` | Share Target Receiver (`ACTION_SEND`) |
| `apps/web` | Next.js SSR/ISR public SEO site |
| `apps/api` | Node.js gateway (`POST /v1/convert`) + BullMQ consumer |
| `workers/processor` | Python FastAPI media worker (ephemeral `/tmp`) |

## Run locally

1. Copy env: `cp .env.example .env`
2. Fill the `AI_STT_*` (transcription) and `AI_LLM_*` (article) blocks in `.env` —
   the two roles may use different providers/keys (never commit `.env`).
3. Database (Postgres 16 via Docker, port `55432`):
   ```bash
   docker run -d --name seougc-pg -p 55432:5432 \
     -e POSTGRES_USER=seougc -e POSTGRES_PASSWORD=seougc -e POSTGRES_DB=seougc \
     postgres:16-alpine
   set -a; source .env; set +a           # Prisma CLI needs DATABASE_URL
   npm run db:migrate --prefix apps/api
   npm run db:seed --prefix apps/api
   ```
4. Install dependencies:
   ```bash
   npm install --prefix apps/api
   npm install --prefix apps/web
   UV_CACHE_DIR=/tmp/uv-cache uv pip install --python workers/processor/.venv/bin/python -e workers/processor
   ```
5. `ffmpeg` and `yt-dlp` must be on `PATH` (no sudo: `uv pip install imageio-ffmpeg`,
   then symlink its binary as `ffmpeg`).
6. Start the services (defaults: API `4301`, worker `4302`, web `4320`):
   ```bash
   node --env-file=.env apps/api/src/server.js
   set -a; source .env; set +a
   workers/processor/.venv/bin/uvicorn processor.app:app --app-dir workers/processor/src --port 4302
   npm run dev --prefix apps/web -- -p 4320
   ```
7. Mobile (optional): `cd apps/mobile && flutter run --dart-define=API_BASE=http://10.0.2.2:4301`
8. See each `apps/*` and `workers/*` README for details.

## Tests

| Suite | Command | Count |
|---|---|---|
| API (node:test) | `npm test --prefix apps/api` | 12 |
| Worker (unittest) | `PYTHONPATH=workers/processor/src workers/processor/.venv/bin/python -m unittest discover -s workers/processor/test` | 46 |
| Web unit (vitest) | `npm test --prefix apps/web` | 15 |
| Web E2E (playwright) | `npm run test:e2e --prefix apps/web` | 5 |
| Mobile (flutter) | `cd apps/mobile && flutter test` | 20 |

CI (`.github/workflows/ci.yml`) runs the API, worker, web unit/typecheck, and
mobile suites on every push. E2E needs Postgres + seed data, so it runs locally.

## Local object storage (S3-compatible)

MinIO images are no longer publicly pullable (Docker Hub repo removed, Quay requires
login, dl.min.io returns 410), so the repo uses **s3proxy** with a filesystem backend:

```bash
mkdir -p /tmp/seougc-s3
docker run -d --name seougc-s3 -p 9000:80 \
  -e S3PROXY_AUTHORIZATION=none \
  -e JCLOUDS_PROVIDER=filesystem \
  -e JCLOUDS_FILESYSTEM_BASEDIR=/data \
  -v /tmp/seougc-s3:/data andrewgaul/s3proxy
```

Then create the bucket once (any S3 client) and point `.env` at it:

```env
S3_BUCKET_NAME=seo-ugc-images
S3_ENDPOINT=http://127.0.0.1:9000
S3_REGION=us-east-1
S3_PUBLIC_BASE_URL=http://127.0.0.1:9000/seo-ugc-images
```

`S3PROXY_AUTHORIZATION=none` means anonymous read/write — local demo only, never
expose it publicly.

## Built During Hackathon

- [x] Mobile Share Receiver (Flutter Android `ACTION_SEND`)
- [x] API Gateway + BullMQ queue + consumer (queue → worker → persist)
- [x] Python worker: yt-dlp + FFmpeg + `/tmp` purge (in `finally`)
- [x] STT + multimodal article generation, two independent providers via env (`AI_STT_*`, `AI_LLM_*`)
- [x] Next.js article pages + JSON-LD + oEmbed (TikTok, YouTube)
- [x] SEO: path-based i18n (`/en/article/<id>`), canonical/hreflang, sitemap, robots, escaped JSON-LD
- [x] Security: domain allowlist, internal service token, rate limit, video size/duration caps
- [x] Prisma/PostgreSQL (`Article` + `Job`)
- [x] Playwright E2E (5 tests)
- [x] Image upload to S3/R2 (verified against local s3proxy: 2 files uploaded, public URLs return 200)

## Pre-existing Dependencies

Next.js 15, React 19, TypeScript, Tailwind CSS 4, shadcn/ui, Prisma + PostgreSQL,
Redis + BullMQ, FastAPI + Pydantic, yt-dlp, FFmpeg, boto3, Flutter 3.44, Playwright.
The HTTP gateway uses `node:http` (not Express/NestJS).
