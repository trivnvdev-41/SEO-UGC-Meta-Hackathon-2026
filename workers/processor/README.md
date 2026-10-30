# Processor (Python worker)

Ephemeral media pipeline: `yt-dlp` → `ffmpeg` audio + frames → `purge /tmp`.

## Setup

```bash
export UV_CACHE_DIR=/tmp/uv-cache
uv venv workers/processor/.venv
# editable install: ambil dependency dari pyproject.toml
uv pip install --python workers/processor/.venv/bin/python -e workers/processor
```

Opsional: `YTDLP_COOKIES_FILE` (path absolut cookie jar Netscape) kalau TikTok/IG
minta login. Kosong = perilaku normal; path tidak ada = worker gagal cepat dengan
`missing_file:YTDLP_COOKIES_FILE`. File cookie ada di `.gitignore`.

Butuh `ffmpeg` di PATH saat runtime. Tanpa sudo:
`uv pip install --python workers/processor/.venv/bin/python imageio-ffmpeg`, lalu
symlink `$(python -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')`
sebagai `ffmpeg` di direktori yang ada di PATH.

## AI provider (dua peran, boleh beda provider)

| Peran | Env | Endpoint |
|---|---|---|
| `stt` (transcribe) | `AI_STT_BASE_URL`, `AI_STT_API_KEY`, `AI_STT_MODEL` | `/audio/transcriptions` |
| `llm` (artikel) | `AI_LLM_BASE_URL`, `AI_LLM_API_KEY`, `AI_LLM_MODEL` | `/chat/completions` |

Tidak ada fallback antar peran — kosongkan salah satu dan worker menolak
start dengan pesan `worker config: missing:<NAMA_VAR>` (nilai key tidak
pernah dicetak). Base URL harus berakhir `/v1`. Env dibaca saat dipanggil,
jadi `source .env` sebelum start sudah cukup.
Modul: `src/processor/ai.py` (`settings`, `transcribe_audio`, `generate_article`, `enrich`).

## Object storage (opsional)

`upload_images()` mengunggah 2-3 frame pilihan LLM (`selected_image_indices`,
fallback 2 frame pertama) ke S3/R2. Butuh `S3_BUCKET_NAME`, `S3_ENDPOINT`,
`S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` (+ `S3_PUBLIC_BASE_URL`, `S3_REGION`).
Env kosong = upload dilewati; env lengkap tapi upload gagal = job failed
(dan `/tmp` tetap dibersihkan).

## Test (tanpa network)

```bash
PYTHONPATH=workers/processor/src workers/processor/.venv/bin/python \
  -m unittest discover -s workers/processor/test -v
```

## Run API worker

```bash
source workers/processor/.venv/bin/activate
uvicorn processor.app:app --app-dir workers/processor/src --port 3002
```
