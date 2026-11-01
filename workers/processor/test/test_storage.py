import os
import unittest
from unittest.mock import patch

from processor.storage import config, pick_frames, upload_images

FULL = {
    "S3_BUCKET_NAME": "bucket",
    "S3_ENDPOINT": "https://s3.test",
    "S3_ACCESS_KEY_ID": "AK",
    "S3_SECRET_ACCESS_KEY": "SK",
    "S3_PUBLIC_BASE_URL": "https://cdn.test",
    "S3_REGION": "auto",
}
FRAMES = ["/tmp/j/frame_001.jpg", "/tmp/j/frame_002.jpg",
          "/tmp/j/frame_003.jpg", "/tmp/j/frame_004.jpg"]


class FakeS3:
    def __init__(self):
        self.calls = []

    def upload_file(self, path, bucket, key, ExtraArgs=None):
        self.calls.append((path, bucket, key, ExtraArgs))


class StorageTest(unittest.TestCase):
    def test_config_kosong_tanpa_bucket(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(config())
        with patch.dict(os.environ, {"S3_ENDPOINT": "https://s3.test"},
                             clear=True):
            self.assertIsNone(config())

    def test_config_aws_tanpa_key(self):
        env = {"S3_BUCKET_NAME": "bucket", "S3_REGION": "ap-southeast-1"}
        with patch.dict(os.environ, env, clear=True):
            cfg = config()
        self.assertEqual(cfg["public"],
                         "https://bucket.s3.ap-southeast-1.amazonaws.com")
        self.assertNotIn("endpoint", cfg)
        self.assertNotIn("access", cfg)  # pakai default credential chain

    def test_upload_tanpa_config_dilewati(self):
        s3 = FakeS3()
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(upload_images("j", FRAMES, [0], client=s3), [])
        self.assertEqual(s3.calls, [])

    def test_upload_pakai_indeks_pilihan_llm(self):
        s3 = FakeS3()
        with patch.dict(os.environ, FULL, clear=True):
            urls = upload_images("job_9", FRAMES, [2, 0], client=s3)
        self.assertEqual(urls, ["https://cdn.test/job_9/frame_003.jpg",
                                "https://cdn.test/job_9/frame_001.jpg"])
        self.assertEqual(s3.calls[0][1], "bucket")
        self.assertEqual(s3.calls[0][3], {"ContentType": "image/jpeg"})

    def test_upload_fallback_dan_batas_tiga(self):
        self.assertEqual(pick_frames(FRAMES, []), FRAMES[:2])
        self.assertEqual(pick_frames(FRAMES, [99]), FRAMES[:2])
        self.assertEqual(len(pick_frames(FRAMES, [0, 1, 2, 3])), 3)

    def test_upload_gagal_raise(self):
        class Boom:
            def upload_file(self, *a, **k):
                raise RuntimeError("s3 down")

        with patch.dict(os.environ, FULL, clear=True), \
                self.assertRaises(RuntimeError):
            upload_images("job_9", FRAMES, [0], client=Boom())

    def test_lokal_salin_dan_url(self):
        import tempfile
        from pathlib import Path
        from processor.storage import _save_local

        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "src"
            src.mkdir()
            f1 = src / "frame_001.jpg"
            f1.write_bytes(b"IMG1")
            (src / "frame_002.jpg").write_bytes(b"IMG2")
            env = {"LOCAL_IMAGE_DIR": str(Path(tmp) / "img"),
                   "LOCAL_PUBLIC_BASE_URL": "https://saba.ink/images"}
            with patch.dict(os.environ, env, clear=True):
                urls = upload_images("job_7", [str(f1)], [0])
            self.assertEqual(
                urls, ["https://saba.ink/images/job_7/frame_001.jpg"])
            self.assertEqual(
                (Path(tmp) / "img" / "job_7" / "frame_001.jpg").read_bytes(),
                b"IMG1")

    def test_lokal_tanpa_base_url_raise(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp, \
                patch.dict(os.environ, {"LOCAL_IMAGE_DIR": tmp},
                           clear=True), \
                self.assertRaises(RuntimeError):
            upload_images("j", ["/tmp/x.jpg"], [0])


if __name__ == "__main__":
    unittest.main()
