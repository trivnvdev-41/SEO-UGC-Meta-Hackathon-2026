# Processor (Python worker)

Ephemeral media pipeline: `yt-dlp` → `ffmpeg` audio + frames → `purge /tmp`.

## Setup

```bash
export UV_CACHE_DIR=/tmp/uv-cache
uv venv workers/processor/.venv
# editable install: ambil dependency dari pyproject.toml
uv pip install --python workers/processor/.venv/bin/python -e workers/processor
```

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

## Test (stdlib only, tanpa network)

```bash
PYTHONPATH=workers/processor/src workers/processor/.venv/bin/python \
  -m unittest discover -s workers/processor/test -v
```

## Run API worker

```bash
source workers/processor/.venv/bin/activate
uvicorn processor.app:app --app-dir workers/processor/src --port 3002
```
