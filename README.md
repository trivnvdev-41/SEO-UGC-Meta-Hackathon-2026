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
3. Ikuti README tiap `apps/*` / `workers/*` per tahap guide.

## Built During Hackathon

- [x] Mobile Share Receiver
- [x] API Gateway + BullMQ queue
- [x] Python worker: yt-dlp + FFmpeg + `/tmp` purge
- [x] STT + artikel multimodal, dua provider terpisah (mock-tested)
- [x] Next.js artikel + JSON-LD + oEmbed

## Pre-existing Dependencies

Next.js, Tailwind, NestJS/Express, Redis/BullMQ, FastAPI, yt-dlp, FFmpeg, Prisma/PostgreSQL, S3/R2.
