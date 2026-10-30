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
    def test_config_kosong_jika_env_kurang(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(config())
        with patch.dict(os.environ, {"S3_BUCKET_NAME": "b"}, clear=True):
            self.assertIsNone(config())

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


if __name__ == "__main__":
    unittest.main()
