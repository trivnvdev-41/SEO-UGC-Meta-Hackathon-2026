"""Ephemeral media pipeline: upload -> audio + frames -> purge.

File video mentah hanya hidup di MEDIA_DIR/<job_id> (upload) dan
/tmp/{job_id} (hasil olah) selama pemrosesan.
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
_DEFAULT_MAX_MB = 50
_DEFAULT_MAX_SECONDS = 180
_FFMPEG_TIMEOUT = 60
_SOCKET_TIMEOUT = 30


def _check_job_id(job_id: str) -> str:
    if not _JOB_RE.match(job_id):
        raise ValueError("invalid_job_id")
    return job_id


def max_filesize_mb() -> int:
    raw = os.environ.get("MAX_VIDEO_MB", "").strip()
    return int(raw) if raw.isdigit() and int(raw) > 0 else _DEFAULT_MAX_MB


def max_seconds() -> int:
    raw = os.environ.get("MAX_VIDEO_SECONDS", "").strip()
    return int(raw) if raw.isdigit() and int(raw) > 0 else _DEFAULT_MAX_SECONDS


def check_size(video: Path, max_mb: int | None = None) -> None:
    """Guard terakhir: ukuran nyata di disk, bukan klaim extractor."""
    limit = (max_mb or max_filesize_mb()) * 1024 * 1024
    if video.exists() and video.stat().st_size > limit:
        raise ValueError("video_too_large")


def job_dir(job_id: str) -> Path:
    return TMP_ROOT / _check_job_id(job_id)


def extract_cmd(video: Path, audio: Path, pattern: Path) -> list[str]:
    """Satu pass ffmpeg: audio.mp3 + 10 frame sekaligus (hemat 1x decode)."""
    return ["ffmpeg", "-y", "-i", str(video),
            "-map", "0:a?", "-acodec", "libmp3lame", "-q:a", "4", str(audio),
            "-map", "0:v?", "-vf", "fps=1/3", "-frames:v", "10", str(pattern)]


def video_inbox(job_id: str) -> Path | None:
    """Video mentah hasil upload langsung (MEDIA_DIR/<job_id>/video.mp4)."""
    root = os.environ.get("MEDIA_DIR", "").strip()
    if not root:
        return None
    v = Path(root) / _check_job_id(job_id) / VIDEO_NAME
    return v if v.is_file() else None


def probe_duration(video: Path, run=subprocess.run) -> float:
    """Durasi detik via ffprobe; ValueError bila tak terbaca."""
    out = run(["ffprobe", "-v", "error", "-show_entries",
               "format=duration", "-of", "default=noprint_wrappers=1:nokey=1",
               str(video)],
              capture_output=True, text=True, timeout=_SOCKET_TIMEOUT)
    try:
        return float((out.stdout or "").strip())
    except (ValueError, AttributeError):
        raise ValueError("video_unreadable")


def pipeline(job_id: str, run=subprocess.run,
             creator: str | None = None) -> dict:
    """Upload-only: video mentah dari MEDIA_DIR/<job_id>/video.mp4.

    Tanpa video upload -> ValueError("no_video") (400 ke gateway).
    """
    raw = video_inbox(job_id)
    if raw is None:
        raise ValueError("no_video")
    check_size(raw)
    if probe_duration(raw, run) > max_seconds():
        raise ValueError("video_too_long")
    d = job_dir(job_id)
    d.mkdir(parents=True, exist_ok=True)
    audio = d / AUDIO_NAME
    run(extract_cmd(raw, audio, d / FRAME_PATTERN),
        check=True, timeout=_FFMPEG_TIMEOUT)
    frames = sorted(str(p) for p in d.glob("frame_*.jpg"))[:10]
    return {"job_id": job_id, "video": str(raw),
            "audio": str(audio), "frames": frames,
            "creator": creator or None, "local": True}


def purge(job_id: str) -> None:
    """Hapus /tmp/{job_id} — panggil setelah upload selesai."""
    shutil.rmtree(job_dir(job_id), ignore_errors=True)
