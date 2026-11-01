# Fetch-worker lokal (jam kerja)

Unduh video di IP bersih (rumah), kirim media ke server. Reuse
`processor.media` (yt-dlp + ffmpeg). Stdlib-only.

## Env

```bash
SABA_API=https://saba.ink      # API server
FETCH_TOKEN=...                # samakan API_INTERNAL_TOKEN server (600, jangan commit)
FETCH_POLL_SEC=10
YTDLP_COOKIES_FILE=            # opsional, bila platform minta login
```

## Jalan manual

```bash
SABA_API=https://saba.ink FETCH_TOKEN="$FETCH_TOKEN" \
  workers/processor/.venv/bin/python workers/fetcher/fetch.py
```

## Auto-start (systemd user, jam kerja)

```bash
mkdir -p ~/.config/systemd/user
sed -e "s|@REPO|/media/trivnv/DATA/SEO-UGC-Meta-Hackathon-2026|" \
  workers/fetcher/saba-fetcher.service.template \
  > ~/.config/systemd/user/saba-fetcher.service
systemctl --user daemon-reload
systemctl --user enable --now saba-fetcher
# berhenti: systemctl --user stop saba-fetcher
# log: journalctl --user -u saba-fetcher -f
```

File env (`~/.config/saba-fetcher.env`, 600) harus berisi `SABA_API`,
`FETCH_TOKEN`, dan `YTDLP_COOKIES_FILE` bila perlu.
