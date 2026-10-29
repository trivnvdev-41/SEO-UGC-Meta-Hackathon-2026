"""Ephemeral media pipeline: download -> audio + frames -> purge.

File video mentah hanya hidup di /tmp/{job_id} selama pemrosesan.
Urutan produksi: pipeline() -> upload still images ke S3 -> purge().
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path

TMP_ROOT = Path("/tmp")
VIDEO_NAME = "video.mp4"
AUDIO_NAME = "audio.mp3"
FRAME_PATTERN = "frame_%03d.jpg"

_JOB_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")


def _check_job_id(job_id: str) -> str:
    if not _JOB_RE.match(job_id):
        raise ValueError("invalid_job_id")
    return job_id


def job_dir(job_id: str) -> Path:
    return TMP_ROOT / _check_job_id(job_id)


def download_cmd(url: str, out: Path, cookies: str | None = None) -> list[str]:
    cmd = ["yt-dlp", "-o", str(out)]
    if cookies:
        cmd += ["--cookies", cookies]
    cmd.append(url)
    return cmd


def cookies_file() -> str | None:
    """Path cookie jar dari env; None kalau tidak diset. Gagal cepat kalau hilang."""
    raw = os.environ.get("YTDLP_COOKIES_FILE", "").strip()
    if not raw:
        return None
    if not Path(raw).is_file():
        raise RuntimeError("missing_file:YTDLP_COOKIES_FILE")
    return raw


def audio_cmd(video: Path, audio: Path) -> list[str]:
    return ["ffmpeg", "-y", "-i", str(video),
            "-vn", "-acodec", "libmp3lame", "-q:a", "4", str(audio)]


def frames_cmd(video: Path, pattern: Path) -> list[str]:
    return ["ffmpeg", "-y", "-i", str(video),
            "-vf", "fps=1/3", str(pattern)]


def pipeline(job_id: str, url: str, run=subprocess.run) -> dict:
    """Unduh video ke /tmp/{job_id}, ekstrak audio.mp3 + frame_*.jpg."""
    cookies = cookies_file()  # validasi sebelum membuat direktori job
    d = job_dir(job_id)
    d.mkdir(parents=True, exist_ok=True)
    video = d / VIDEO_NAME
    audio = d / AUDIO_NAME
    run(download_cmd(url, video, cookies), check=True)
    run(audio_cmd(video, audio), check=True)
    run(frames_cmd(video, d / FRAME_PATTERN), check=True)
    return {"job_id": job_id, "video": str(video),
            "audio": str(audio), "frames": str(d / FRAME_PATTERN)}


def purge(job_id: str) -> None:
    """Hapus /tmp/{job_id} — panggil setelah upload selesai."""
    shutil.rmtree(job_dir(job_id), ignore_errors=True)
