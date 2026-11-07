# SABA

**Ulasan produk jujur dari video kreator.** SABA turns direct video
uploads into SEO-ready web articles — with **JSON-LD schema** and the
**official video embed**. A social-media link may be attached only as an
extra reference for the article; videos are never pulled from social
media. Readers then discuss each review in a forum-style app.

**Live:** [saba.ink](https://saba.ink)

> Nama produk: **SABA**. Slug teknis semuanya `saba` (domain `saba.ink`, DB/user
> `saba`, channel `saba/share`, applicationId `ink.saba.app`).

## Structure

| Path                  | Contents                                                                                                      |
| --------------------- | ------------------------------------------------------------------------------------------------------------- |
| `apps/mobile`       | Flutter forum app (**SABA**): home, upload video galeri → `POST /v1/uploads`, vote, komentar, profil |
| `apps/web`          | Next.js SSR/ISR public SEO site (route groups `app/(id)/` + `app/(en)/`)                                  |
| `apps/api`          | Node.js `node:http` gateway + BullMQ queue/consumer + Prisma/PostgreSQL (`Article` + `Job`)             |
| `workers/processor` | Python FastAPI media worker (ephemeral `/tmp`)                                                              |

## Run locally

1. Copy env: `cp .env.example .env`
2. Fill the `AI_STT_*` (transcription) and `AI_LLM_*` (article) blocks in `.env` —
   the two roles may use different providers/keys (never commit `.env`).
3. Database (Postgres 16 via Docker, port `55432`):
   ```bash
    docker run -d --name saba-pg -p 55432:5432 \
      -e POSTGRES_USER=saba -e POSTGRES_PASSWORD=saba -e POSTGRES_DB=saba \
     postgres:16-alpine
   set -a; source .env; set +a           # Prisma CLI needs DATABASE_URL
   npm run db:migrate --prefix apps/api
   npm run db:seed --prefix apps/api
   ```
4. Install dependencies + Redis (antrean BullMQ):
   ```bash
   npm install --prefix apps/api
   npm install --prefix apps/web
    docker run -d --name saba-redis -p 6379:6379 redis:7-alpine
   UV_CACHE_DIR=/tmp/uv-cache uv pip install --python workers/processor/.venv/bin/python -e workers/processor
   ```
5. `ffmpeg` must be on `PATH` (no sudo: `uv pip install imageio-ffmpeg`,
   then symlink its binary as `ffmpeg`).
6. Start the services (defaults: API `4301`, worker `4302`, web `4320`;
   API butuh `REDIS_URL`, mis. `redis://localhost:6379`):
   ```bash
   node --env-file=.env apps/api/src/server.js
   set -a; source .env; set +a
   workers/processor/.venv/bin/uvicorn processor.app:app --app-dir workers/processor/src --port 4302
   npm run dev --prefix apps/web -- -p 4320
   ```
7. Mobile (optional): `cd apps/mobile && flutter run --dart-define=API_BASE=http://10.0.2.2:4301`
8. See `apps/api/README.md` and each `apps/*` and `workers/*` README for details.

## AI providers

Two independent providers, one per role (no fallback between roles):

| Role               | Provider    | Model                            |
| ------------------ | ----------- | -------------------------------- |
| Transcription (STT)| **Meta** ASR| `muse-voice-transcribe-1.0`      |
| Article generation | **Baseten** | `meta-models/muse-spark-open-1026` |

Only the provider and model names are shown here — base URLs and API keys live in
`.env` (`AI_STT_*`, `AI_LLM_*`) and are never committed.

## Tests

| Suite           | Command                        | Count |
| --------------- | ------------------------------ | ----- |
| API (node:test) | `npm test --prefix apps/api` | 28    |

> Test API butuh Redis jalan (`REDIS_URL`, default `redis://localhost:6379`);
> tanpa Redis, 2 test integrasi antrean otomatis skip.
> | Worker (unittest) | `PYTHONPATH=workers/processor/src workers/processor/.venv/bin/python -m unittest discover -s workers/processor/test` | 36 |
> | Web unit (vitest) | `npm test --prefix apps/web` | 25 |
> | Web E2E (playwright) | `npm run test:e2e --prefix apps/web` | 5 |
> | Mobile (flutter) | `cd apps/mobile && flutter test` | 20 |

CI (`.github/workflows/ci.yml`) runs the API, worker, web unit/typecheck, and
mobile suites on every push. E2E needs Postgres + seed data, so it runs locally.

## Backup (server)

- Postgres: cron harian 02:00 (`/opt/saba/pg-backup.sh` → `/opt/saba/backup/pg-saba-<tgl>.dump`, retensi 7 hari).
- Rollback ke SQLite: stop `saba-api`, kembalikan `DATABASE_URL` ke `file:/opt/saba/data/saba.db` (arsip di `/opt/saba/backup/`), start ulang.

## Local object storage (S3-compatible)

MinIO images are no longer publicly pullable (Docker Hub repo removed, Quay requires
login, dl.min.io returns 410), so the repo uses **s3proxy** with a filesystem backend:

```bash
    mkdir -p /tmp/saba-s3
    docker run -d --name saba-s3 -p 9000:80 \
  -e S3PROXY_AUTHORIZATION=none \
  -e JCLOUDS_PROVIDER=filesystem \
  -e JCLOUDS_FILESYSTEM_BASEDIR=/data \
  -v /tmp/saba-s3:/data andrewgaul/s3proxy
```

Then create the bucket once (any S3 client) and point `.env` at it:

```env
S3_BUCKET_NAME=saba-images
S3_ENDPOINT=http://127.0.0.1:9000
S3_REGION=us-east-1
S3_PUBLIC_BASE_URL=http://127.0.0.1:9000/saba-images
```

`S3PROXY_AUTHORIZATION=none` means anonymous read/write — local demo only, never
expose it publicly.

## Built During Hackathon

- [X] Mobile forum app (Flutter Android): home, upload video galeri → `POST /v1/uploads`, vote, komentar, profil
- [X] API Gateway (`node:http`) + BullMQ queue + consumer (queue → worker → persist) + Prisma/PostgreSQL (`Article` + `Job`)
- [X] Python worker: upload → FFmpeg + `/tmp` purge (in `finally`)
- [X] STT + multimodal article generation, two independent providers via env (`AI_STT_*`, `AI_LLM_*`)
- [X] Next.js article pages + JSON-LD + social embeds + jelajah/forum pages
- [X] SEO: path-based i18n (`/article/<id>` ID, `/en/article/<id>` EN), canonical/hreflang, sitemap, robots, escaped JSON-LD
- [X] Security: domain allowlist, internal service token, rate limit, video size/duration caps
- [X] Playwright E2E (5 tests)
- [X] Image upload to S3/R2 (verified against local s3proxy: 2 files uploaded, public URLs return 200)

## Pre-existing Dependencies

Next.js 15, React 19, TypeScript, Tailwind CSS 4, shadcn/ui, Prisma + PostgreSQL,
Redis + BullMQ, FastAPI + Pydantic, FFmpeg, boto3, Flutter 3.44, Playwright.
The HTTP gateway uses `node:http` (not Express/NestJS).
