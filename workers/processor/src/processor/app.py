from contextlib import asynccontextmanager
import os

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel

from processor.ai import enrich, settings
from processor.media import pipeline, purge
from processor.storage import upload_images


def require_token(authorization: str | None = Header(default=None)) -> None:
    """Gateway-only: /process tidak boleh bisa dipanggil tanpa API_INTERNAL_TOKEN."""
    token = os.environ.get("API_INTERNAL_TOKEN", "").strip()
    if not token:
        raise HTTPException(status_code=500, detail="missing:API_INTERNAL_TOKEN")
    if authorization != f"Bearer {token}":
        raise HTTPException(status_code=401, detail="unauthorized")


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Gagal cepat: sebut nama var yang hilang, tanpa pernah mencetak nilainya.
    for role in ("stt", "llm"):
        try:
            settings(role)
        except RuntimeError as e:
            raise RuntimeError(f"worker config: {e}") from e
    if not os.environ.get("API_INTERNAL_TOKEN", "").strip():
        raise RuntimeError("worker config: missing:API_INTERNAL_TOKEN")
    yield


app = FastAPI(title="saba-processor", lifespan=lifespan)


class ConvertJob(BaseModel):
    job_id: str
    creator: str | None = None


@app.post("/process", dependencies=[Depends(require_token)])
def process(job: ConvertJob):
    try:
        media = pipeline(job.job_id, creator=job.creator)
        bundle = enrich(media["audio"], media["frames"],
                        creator=media.get("creator"), verbose_stt=True)
        bundle["creator"] = media.get("creator")
        bundle["images"] = upload_images(
            job.job_id, media["frames"],
            bundle.get("selected_image_indices") or [])
        # Opsi sampul Langkah 2: pilihan AI dulu, dilengkapi sampai 6.
        # Indeks diremap ke posisi baru agar praseleksi mobile selalu valid
        # (LLM memilih dari 10 frame ekstrak, bukan dari 6 yang diupload).
        sel = [i for i in (bundle.get("selected_image_indices") or [])
               if isinstance(i, int) and 0 <= i < len(media["frames"])]
        take = (sel + [i for i in range(len(media["frames"]))
                       if i not in sel])[:6]
        bundle["frame_options"] = upload_images(
            job.job_id, media["frames"], take, max_n=6)
        pos = {old: new for new, old in enumerate(take)}
        bundle["selected_image_indices"] = [pos[i] for i in sel
                                            if i in pos]
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    finally:
        # /tmp/{job_id} ephemeral: selalu dibersihkan, sukses maupun gagal.
        # Video sumber di MEDIA_DIR/<job_id>/ JANGAN dihapus di sini:
        # kepemilikannya di gateway, yang menghapus hanya SETELAH artikel
        # tersimpan (lihat saveArticle di API). Menghapus di sini membuat
        # retry BullMQ selalu gagal media_not_ready + video user hilang.
        purge(job.job_id)
    return {"job_id": job.job_id, **bundle}


class RegenJob(BaseModel):
    job_id: str
    transcript: str
    frame_urls: list[str] = []
    creator: str | None = None


def _allowed_frame_url(url: str) -> bool:
    """Batasi unduhan frame ke host storage sendiri (anti-SSRF)."""
    from urllib.parse import urlparse
    allowed: set[str] = set()
    for env in ("S3_PUBLIC_BASE_URL", "S3_ENDPOINT", "LOCAL_PUBLIC_BASE_URL"):
        v = os.environ.get(env, "").strip()
        if v:
            try:
                h = urlparse(v).hostname
                if h:
                    allowed.add(h)
            except ValueError:
                pass
    try:
        return bool(urlparse(url).hostname in allowed)
    except ValueError:
        return False


def _fetch_frame_bytes(urls: list[str]) -> list[str]:
    """Unduh maks 6 frame -> base64. Hanya host storage sendiri."""
    import base64
    import urllib.request
    out = []
    for u in urls[:6]:
        if not _allowed_frame_url(u):
            raise ValueError("frame_url_forbidden")
        with urllib.request.urlopen(u, timeout=30) as res:
            raw = res.read()
        if not raw or len(raw) > 5 * 1024 * 1024:
            raise ValueError("frame_bad_bytes")
        out.append(base64.b64encode(raw).decode())
    if not out:
        raise ValueError("frame_empty")
    return out


@app.post("/regenerate", dependencies=[Depends(require_token)])
def regenerate(job: RegenJob):
    """Artikel ulang dari transkrip editan + frame pilihan (Langkah 2).
    Dipakai saat user mengubah transkrip/judul di draft; tanpa STT ulang."""
    from processor.ai import generate_article
    transcript = (job.transcript or "").strip()[:20000]
    if not transcript:
        raise HTTPException(status_code=400, detail="empty_transcript")
    try:
        images = _fetch_frame_bytes(job.frame_urls)
        bundle = generate_article(transcript, images, creator=job.creator)
        return {"job_id": job.job_id, **bundle}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
