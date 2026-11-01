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
from urllib.parse import urlparse

TMP_ROOT = Path("/tmp")
VIDEO_NAME = "video.mp4"
AUDIO_NAME = "audio.mp3"
FRAME_PATTERN = "frame_%03d.jpg"

_JOB_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
# Defense in depth: gateway sudah memfilter, worker menolak host lain juga.
_ALLOWED_HOST = re.compile(
    r"(^|\.)(tiktok\.com|youtube\.com|youtu\.be)$", re.I)
_YOUTUBE_HOST = re.compile(r"(^|\.)(youtube\.com|youtu\.be)$", re.I)
_DEFAULT_MAX_MB = 50
_DEFAULT_MAX_SECONDS = 180
_DEFAULT_MAX_SECONDS_YOUTUBE = 600
_DOWNLOAD_TIMEOUT = 120
_FFMPEG_TIMEOUT = 60
_SOCKET_TIMEOUT = 30


def _check_job_id(job_id: str) -> str:
    if not _JOB_RE.match(job_id):
        raise ValueError("invalid_job_id")
    return job_id


def is_convertible_url(url: str) -> bool:
    try:
        p = urlparse(url)
    except ValueError:
        return False
    if p.scheme != "https" or p.username or p.password:
        return False
    host = (p.hostname or "").lower()
    return bool(_ALLOWED_HOST.search(host))


def max_filesize_mb() -> int:
    raw = os.environ.get("MAX_VIDEO_MB", "").strip()
    return int(raw) if raw.isdigit() and int(raw) > 0 else _DEFAULT_MAX_MB


def max_seconds() -> int:
    raw = os.environ.get("MAX_VIDEO_SECONDS", "").strip()
    return int(raw) if raw.isdigit() and int(raw) > 0 else _DEFAULT_MAX_SECONDS


def is_youtube(url: str) -> bool:
    try:
        host = (urlparse(url).hostname or "").lower()
    except ValueError:
        return False
    return bool(_YOUTUBE_HOST.search(host))


def max_seconds_for(url: str) -> int:
    """YouTube boleh lebih panjang (Shorts & video ≤10 menit), platform lain 180s."""
    if not is_youtube(url):
        return max_seconds()
    raw = os.environ.get("MAX_VIDEO_SECONDS_YOUTUBE", "").strip()
    return (int(raw) if raw.isdigit() and int(raw) > 0
            else _DEFAULT_MAX_SECONDS_YOUTUBE)


def check_size(video: Path, max_mb: int | None = None) -> None:
    """Guard terakhir: ukuran nyata di disk, bukan klaim extractor."""
    limit = (max_mb or max_filesize_mb()) * 1024 * 1024
    if video.exists() and video.stat().st_size > limit:
        raise ValueError("video_too_large")


def job_dir(job_id: str) -> Path:
    return TMP_ROOT / _check_job_id(job_id)


def download_cmd(url: str, out: Path, cookies: str | None = None,
                 max_mb: int | None = None,
                 max_sec: int | None = None) -> list[str]:
    cmd = ["yt-dlp", "-o", str(out),
           # 720p cukup untuk STT + still image; best-quality bikin unduh lambat.
           "-f", "bv*[height<=720]+ba/b[height<=720]/b",
           "--max-filesize", f"{max_mb or max_filesize_mb()}M",
           "--socket-timeout", str(_SOCKET_TIMEOUT),
           "--match-filter",
           f"duration <= {max_sec or max_seconds_for(url)}"]
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


def _handle_of(uploader: str, uploader_url: str, uploader_id: str,
               url: str) -> str | None:
    """Handle '@...' untuk nama kreator di artikel (tanpa kata 'kreator').

    YouTube: ambil dari uploader_url (…/​@handle). TikTok: '@' + uploader_id
    (unique id). Fallback: nama display apa adanya."""
    for line in uploader_url.splitlines():
        line = line.strip()
        if "/@" in line:
            handle = "@" + line.split("/@")[-1].split("/")[0].split("?")[0]
            if len(handle) > 1:
                return handle
    if is_youtube(url):
        return uploader or None
    if uploader_id and uploader_id != "NA":
        return "@" + uploader_id.splitlines()[0].strip()
    return uploader or None


def uploader_of(url: str, run=subprocess.run) -> str | None:
    """Handle/nama kreator via yt-dlp tanpa mengunduh; None bila tak diketahui.

    Dipakai untuk byline + judul artikel. Gagal = None (bukan error),
    agar satu metadata tak menggagalkan seluruh job.
    """
    if not is_convertible_url(url):
        raise ValueError("invalid_url")
    cmd = ["yt-dlp", "--skip-download", "--no-warnings",
           "--print", "%(uploader)s\\t%(uploader_url)s\\t%(uploader_id)s",
           "--socket-timeout", str(_SOCKET_TIMEOUT)]
    cookies = cookies_file()
    if cookies:
        cmd += ["--cookies", cookies]
    cmd.append(url)
    try:
        out = run(cmd, capture_output=True, text=True,
                  check=True, timeout=_SOCKET_TIMEOUT)
        stdout = out.stdout or ""
    except Exception:
        return None
    for raw in stdout.strip().splitlines():
        parts = [p.strip() for p in raw.split("\t")]
        parts += [""] * (3 - len(parts))
        name, uurl, uid = parts[0], parts[1], parts[2]
        if name == "NA":
            name = ""
        handle = _handle_of(name, uurl, uid, url)
        if handle:
            return handle
    return None


def audio_cmd(video: Path, audio: Path) -> list[str]:
    return ["ffmpeg", "-y", "-i", str(video),
            "-vn", "-acodec", "libmp3lame", "-q:a", "4", str(audio)]


def frames_cmd(video: Path, pattern: Path) -> list[str]:
    # Berhenti di 10 frame: pipeline hanya memakai 10 pertama.
    return ["ffmpeg", "-y", "-i", str(video),
            "-vf", "fps=1/3", "-frames:v", "10", str(pattern)]


def pipeline(job_id: str, url: str, run=subprocess.run) -> dict:
    """Unduh video ke /tmp/{job_id}, ekstrak audio.mp3 + frame_*.jpg."""
    if not is_convertible_url(url):
        raise ValueError("invalid_url")
    cookies = cookies_file()  # validasi sebelum membuat direktori job
    creator = uploader_of(url, run)
    d = job_dir(job_id)
    d.mkdir(parents=True, exist_ok=True)
    video = d / VIDEO_NAME
    audio = d / AUDIO_NAME
    run(download_cmd(url, video, cookies), check=True, timeout=_DOWNLOAD_TIMEOUT)
    # yt-dlp menambah ekstensi kontainer saat merge (video.mp4 -> video.mp4.webm).
    dl = video if video.exists() else next(iter(sorted(d.glob("video.*"))), video)
    check_size(dl)
    run(audio_cmd(dl, audio), check=True, timeout=_FFMPEG_TIMEOUT)
    run(frames_cmd(dl, d / FRAME_PATTERN), check=True, timeout=_FFMPEG_TIMEOUT)
    frames = sorted(str(p) for p in d.glob("frame_*.jpg"))[:10]
    return {"job_id": job_id, "video": str(dl),
            "audio": str(audio), "frames": frames, "creator": creator}


def purge(job_id: str) -> None:
    """Hapus /tmp/{job_id} — panggil setelah upload selesai."""
    shutil.rmtree(job_dir(job_id), ignore_errors=True)
