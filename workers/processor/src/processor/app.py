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


app = FastAPI(title="seo-ugc-processor", lifespan=lifespan)


class ConvertJob(BaseModel):
    job_id: str
    url: str


@app.post("/process", dependencies=[Depends(require_token)])
def process(job: ConvertJob):
    try:
        media = pipeline(job.job_id, job.url)
        bundle = enrich(media["audio"], media["frames"])
        bundle["images"] = upload_images(
            job.job_id, media["frames"],
            bundle.get("selected_image_indices") or [])
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    finally:
        # Satu titik keluar: /tmp/{job_id} tidak bocor walau download/enrich/upload gagal.
        purge(job.job_id)
    return {"job_id": job.job_id, "url": job.url, **bundle}
