# Processor (Python worker — SABA)

Ephemeral media pipeline untuk **SABA** (upload-only): video dari
`MEDIA_DIR/<job_id>/video.mp4` → `ffmpeg` audio + frames → upload → `purge /tmp`.

## Setup

```bash
export UV_CACHE_DIR=/tmp/uv-cache
uv venv workers/processor/.venv
# editable install: dependencies come from pyproject.toml
uv pip install --python workers/processor/.venv/bin/python -e workers/processor
```

`ffmpeg` (+ `ffprobe` untuk cek durasi) must be on `PATH` at runtime. Without sudo:
`uv pip install --python workers/processor/.venv/bin/python imageio-ffmpeg`, then
symlink `$(python -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')`
as `ffmpeg` in a directory on `PATH`.

## AI provider (two roles, may use different providers)

| Role | Env | Endpoint |
|---|---|---|
| `stt` (transcription) | `AI_STT_BASE_URL`, `AI_STT_API_KEY`, `AI_STT_MODEL` | `/audio/transcriptions` |
| `llm` (article) | `AI_LLM_BASE_URL`, `AI_LLM_API_KEY`, `AI_LLM_MODEL` | `/chat/completions` |

There is no fallback between roles — leave one empty and the worker refuses to start
with `worker config: missing:<VAR_NAME>` (key values are never printed). Base URLs
must end with `/v1`. Env is read at call time, so `source .env` before starting is
enough.
Module: `src/processor/ai.py` (`settings`, `transcribe_audio`, `generate_article`, `enrich`).

## Resource limits

| Env | Default | Effect |
|---|---|---|
| `MAX_VIDEO_MB` | 50 | on-disk size check (`video_too_large`) |
| `MAX_VIDEO_SECONDS` | 180 | `ffprobe` duration check (`video_too_long`) |

Timeouts: ffmpeg 60s, `--socket-timeout 30` — a stalled process fails
fast instead of holding the worker. Tanpa video upload, `/process`
menolak dengan `no_video` (400).

## Object storage (optional)

`upload_images()` uploads the 2–3 frames picked by the LLM (`selected_image_indices`,
falling back to the first 2 frames) to S3/R2. Requires `S3_BUCKET_NAME`,
`S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` (plus `S3_PUBLIC_BASE_URL`,
`S3_REGION`). Empty env = upload skipped; complete env but a failed upload = job
failed (and `/tmp` is still cleaned up). For AWS you can omit the keys and rely on
the default credential chain (`~/.aws` profile).

## Test (no network)

```bash
PYTHONPATH=workers/processor/src workers/processor/.venv/bin/python \
  -m unittest discover -s workers/processor/test -v
```

## Run the worker API

```bash
set -a; source .env; set +a
workers/processor/.venv/bin/uvicorn processor.app:app \
  --app-dir workers/processor/src --port 4302
```
