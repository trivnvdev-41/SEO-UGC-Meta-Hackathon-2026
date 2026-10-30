"""Upload 2-3 still frame terpilih ke S3/R2.

Env kosong = upload dilewati (images: []) supaya demo tanpa object storage tetap
jalan. Env terisi tapi upload gagal = error (job failed), bukan diam-diam kosong.
"""

from __future__ import annotations

import os
from pathlib import Path

import boto3
from botocore.config import Config

MAX_IMAGES = 3


def _env(name: str) -> str:
    return os.environ.get(name, "").strip()


def config() -> dict | None:
    bucket = _env("S3_BUCKET_NAME")
    endpoint = _env("S3_ENDPOINT")
    access = _env("S3_ACCESS_KEY_ID")
    secret = _env("S3_SECRET_ACCESS_KEY")
    public = _env("S3_PUBLIC_BASE_URL")
    if not (bucket and endpoint and access and secret):
        return None
    return {
        "bucket": bucket,
        "endpoint": endpoint,
        "access": access,
        "secret": secret,
        "public": (public or f"{endpoint.rstrip('/')}/{bucket}").rstrip("/"),
        "region": _env("S3_REGION") or "auto",
    }


def pick_frames(frames: list[str], indices: list[int]) -> list[str]:
    """Ambil frame sesuai indeks pilihan LLM; fallback ke 2 frame pertama."""
    picked = [frames[i] for i in indices if 0 <= i < len(frames)]
    return (picked or frames[:2])[:MAX_IMAGES]


def upload_images(job_id: str, frames: list[str], indices: list[int],
                  client=None) -> list[str]:
    cfg = config()
    if not cfg or not frames:
        return []
    s3 = client or boto3.client(
        "s3",
        endpoint_url=cfg["endpoint"],
        aws_access_key_id=cfg["access"],
        aws_secret_access_key=cfg["secret"],
        region_name=cfg["region"],
        config=Config(signature_version="s3v4"),
    )
    urls = []
    for path in pick_frames(frames, indices):
        key = f"{job_id}/{Path(path).name}"
        s3.upload_file(path, cfg["bucket"], key,
                       ExtraArgs={"ContentType": "image/jpeg"})
        urls.append(f"{cfg['public']}/{key}")
    return urls
