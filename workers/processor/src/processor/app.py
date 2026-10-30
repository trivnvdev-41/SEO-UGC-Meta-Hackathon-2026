from contextlib import asynccontextmanager

from fastapi import FastAPI
from pydantic import BaseModel

from processor.ai import enrich, settings
from processor.media import pipeline, purge
from processor.storage import upload_images


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Gagal cepat: sebut nama var yang hilang, tanpa pernah mencetak nilainya.
    for role in ("stt", "llm"):
        try:
            settings(role)
        except RuntimeError as e:
            raise RuntimeError(f"worker config: {e}") from e
    yield


app = FastAPI(title="seo-ugc-processor", lifespan=lifespan)


class ConvertJob(BaseModel):
    job_id: str
    url: str


@app.post("/process")
def process(job: ConvertJob):
    try:
        media = pipeline(job.job_id, job.url)
        bundle = enrich(media["audio"], media["frames"])
        bundle["images"] = upload_images(
            job.job_id, media["frames"],
            bundle.get("selected_image_indices") or [])
    finally:
        # Satu titik keluar: /tmp/{job_id} tidak bocor walau download/enrich/upload gagal.
        purge(job.job_id)
    return {"job_id": job.job_id, "url": job.url, **bundle}
