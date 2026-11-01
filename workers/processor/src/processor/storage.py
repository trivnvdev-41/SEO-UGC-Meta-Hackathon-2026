"""Simpan 2-3 still frame terpilih: S3/R2 atau disk lokal.

Prioritas: S3 (S3_BUCKET_NAME terisi) -> lokal (LOCAL_IMAGE_DIR terisi)
-> lewati (images: []). Backend terpilih yang gagal = error (job failed),
bukan diam-diam kosong.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path

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
    if cfg and frames:
        return _upload_s3(cfg, job_id, frames, indices, client)
    local = _env("LOCAL_IMAGE_DIR")
    if local and frames:
        return _save_local(local, job_id, frames, indices)
    return []


def _upload_s3(cfg: dict, job_id: str, frames: list[str],
               indices: list[int], client=None) -> list[str]:
    import boto3
    from botocore.config import Config
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


def _save_local(root: str, job_id: str, frames: list[str],
                indices: list[int]) -> list[str]:
    """Salin frame ke <root>/<job_id>/; URL dari LOCAL_PUBLIC_BASE_URL."""
    base = _env("LOCAL_PUBLIC_BASE_URL").rstrip("/")
    if not base:
        raise RuntimeError("missing:LOCAL_PUBLIC_BASE_URL")
    dest = Path(root) / job_id
    dest.mkdir(parents=True, exist_ok=True)
    urls = []
    for path in pick_frames(frames, indices):
        target = dest / Path(path).name
        shutil.copyfile(path, target)
        urls.append(f"{base}/{job_id}/{target.name}")
    return urls
