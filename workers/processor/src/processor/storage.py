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
    """None kalau bucket belum diset. Key opsional: tanpa key, boto3 pakai
    default credential chain (AWS profile/env/instance role).
    Tanpa endpoint = mode AWS asli; set S3_ENDPOINT untuk R2/lokal."""
    bucket = _env("S3_BUCKET_NAME")
    if not bucket:
        return None
    endpoint = _env("S3_ENDPOINT")
    access = _env("S3_ACCESS_KEY_ID")
    secret = _env("S3_SECRET_ACCESS_KEY")
    region = _env("S3_REGION") or "us-east-1"
    public = _env("S3_PUBLIC_BASE_URL")
    if not public:
        public = (f"{endpoint.rstrip('/')}/{bucket}" if endpoint
                  else f"https://{bucket}.s3.{region}.amazonaws.com")
    cfg = {"bucket": bucket, "public": public.rstrip("/"), "region": region}
    if endpoint:
        cfg["endpoint"] = endpoint
    if access and secret:
        cfg["access"] = access
        cfg["secret"] = secret
    return cfg


def pick_frames(frames: list[str], indices: list[int]) -> list[str]:
    """Ambil frame sesuai indeks pilihan LLM; fallback ke 2 frame pertama."""
    picked = [frames[i] for i in indices if 0 <= i < len(frames)]
    return (picked or frames[:2])[:MAX_IMAGES]


def upload_images(job_id: str, frames: list[str], indices: list[int],
                  client=None) -> list[str]:
    cfg = config()
    if not cfg or not frames:
        return []
    if client is None:
        kwargs = {
            "region_name": cfg["region"],
            "config": Config(signature_version="s3v4"),
        }
        if cfg.get("endpoint"):
            kwargs["endpoint_url"] = cfg["endpoint"]
        if cfg.get("access"):
            kwargs["aws_access_key_id"] = cfg["access"]
            kwargs["aws_secret_access_key"] = cfg["secret"]
        client = boto3.client("s3", **kwargs)
    urls = []
    for path in pick_frames(frames, indices):
        key = f"{job_id}/{Path(path).name}"
        client.upload_file(path, cfg["bucket"], key,
                       ExtraArgs={"ContentType": "image/jpeg"})
        urls.append(f"{cfg['public']}/{key}")
    return urls
