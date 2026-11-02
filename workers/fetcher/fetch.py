"""Fetch-worker lokal (jam kerja): unduh di IP bersih, kirim media ke server.

Loop: GET /v1/queue/next -> yt-dlp + ffmpeg (reuse processor.media) ->
POST /v1/media/<job> {creator, audio.mp3, frame_*.jpg} -> purge /tmp lokal.
Stdlib-only (urllib). Berhenti rapi via SIGTERM/SIGINT.
"""

from __future__ import annotations

import io
import json
import os
import secrets
import shutil
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent
                       / "processor" / "src"))

from processor.media import (  # noqa: E402
    AUDIO_NAME,
    FRAME_PATTERN,
    VIDEO_NAME,
    check_size,
    cookies_file,
    download_cmd,
    extract_cmd,
    is_convertible_url,
    job_dir,
    uploader_of,
)

_API = os.environ.get("SABA_API", "https://saba.ink").rstrip("/")
_TOKEN = os.environ.get("FETCH_TOKEN", "")
_POLL = int(os.environ.get("FETCH_POLL_SEC", "10") or 10)
_RUNNING = True


def _stop(*_) -> None:
    global _RUNNING
    _RUNNING = False


def _req(method: str, path: str, body: bytes | None = None,
         ctype: str = "application/json") -> tuple[int, bytes]:
    req = urllib.request.Request(
        f"{_API}{path}", data=body, method=method,
        headers={"Authorization": f"Bearer {_TOKEN}",
                 **({"Content-Type": ctype} if body else {})})
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            return res.status, res.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def _multipart(fields: dict[str, str],
               files: list[tuple[str, str, str, bytes]]) -> tuple[bytes, str]:
    boundary = "----saba" + secrets.token_hex(8)
    buf = io.BytesIO()

    def field(name: str, value: str) -> None:
        buf.write(f"--{boundary}\r\nContent-Disposition: form-data; "
                  f'name="{name}"\r\n\r\n{value}\r\n'.encode())

    for name, value in fields.items():
        field(name, value)
    for name, filename, ctype, data in files:
        buf.write(f'--{boundary}\r\nContent-Disposition: form-data; '
                  f'name="{name}"; filename="{filename}"\r\n'
                  f"Content-Type: {ctype}\r\n\r\n".encode())
        buf.write(data)
    buf.write(f"\r\n--{boundary}--\r\n".encode())
    return buf.getvalue(), f"multipart/form-data; boundary={boundary}"


def _fetch_one(job_id: str, url: str) -> None:
    if not is_convertible_url(url):
        raise ValueError("invalid_url")
    cookies = cookies_file()
    creator = uploader_of(url)
    d = job_dir(job_id)
    d.mkdir(parents=True, exist_ok=True)
    try:
        video = d / VIDEO_NAME
        audio = d / AUDIO_NAME
        subprocess.run(download_cmd(url, video, cookies),
                       check=True, timeout=180)
        dl = (video if video.exists()
              else next(iter(sorted(d.glob("video.*"))), video))
        check_size(dl)
        subprocess.run(extract_cmd(dl, audio, d / FRAME_PATTERN),
                       check=True, timeout=90)
        frames = sorted(str(p) for p in d.glob("frame_*.jpg"))[:10]
        files = [("file", AUDIO_NAME, "audio/mpeg", audio.read_bytes())]
        for p in frames:
            files.append(("file", Path(p).name, "image/jpeg",
                          Path(p).read_bytes()))
        fields = {"creator": creator or ""}
        body, ctype = _multipart(fields, files)
        status, _ = _req("POST", f"/v1/media/{job_id}", body, ctype)
        if status != 200:
            raise RuntimeError(f"media_upload_{status}")
        print(f"[{job_id}] media terkirim ({len(files)} file)", flush=True)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def main() -> int:
    if not _TOKEN:
        print("FETCH_TOKEN kosong", file=sys.stderr)
        return 2
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    print(f"fetcher -> {_API} (poll {_POLL}s)", flush=True)
    while _RUNNING:
        try:
            status, raw = _req("GET", "/v1/queue/next")
        except Exception as e:
            print(f"poll gagal: {e}", flush=True)
            time.sleep(_POLL)
            continue
        if status == 204:
            time.sleep(_POLL)
            continue
        if status == 401:
            print("unauthorized: cek FETCH_TOKEN", file=sys.stderr)
            return 3
        if status != 200:
            time.sleep(_POLL)
            continue
        try:
            job = json.loads(raw.decode())
        except Exception as e:
            print(f"job tak terbaca: {e}", flush=True)
            time.sleep(_POLL)
            continue
        print(f"[{job['id']}] {job['url']}", flush=True)
        try:
            _fetch_one(job["id"], job["url"])
        except Exception as e:
            # Biarkan file .active basi (30 mnt) mengembalikan job ke antrean.
            print(f"[{job['id']}] gagal: {e}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
