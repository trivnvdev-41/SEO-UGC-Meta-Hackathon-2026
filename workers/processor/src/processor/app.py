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
        # Opsi sampul Langkah 2: 6 frame pertama, pilihan AI ikut terkirim
        # via selected_image_indices agar mobile tinggal praseleksi.
        bundle["frame_options"] = upload_images(
            job.job_id, media["frames"], list(range(6)), max_n=6)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    finally:
        # /tmp/{job_id} ephemeraL: selalu dibersihkan, sukses maupun gagal.
        # Video sumber di MEDIA_DIR/<job_id>/ JANGAN dihapus di sini:
        # kepemilikannya di gateway, yang menghapus hanya SETELAH artikel
        # tersimpan (lihat saveArticle di API). Menghapus di sini membuat
        # retry BullMQ selalu gagal media_not_ready + video user hilang.
        purge(job.job_id)
    return {"job_id": job.job_id, **bundle}
