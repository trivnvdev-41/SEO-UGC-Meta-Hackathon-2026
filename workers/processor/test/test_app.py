import unittest
from unittest.mock import patch

from processor.app import ConvertJob, process


JOB = ConvertJob(job_id="j1", url="https://vt.tiktok.com/x/")


class AppTest(unittest.TestCase):
    def test_purge_setelah_enrich_sukses(self):
        order = []
        with patch("processor.app.pipeline",
                   side_effect=lambda *a: order.append("pipeline") or {
                       "audio": "/tmp/j1/audio.mp3", "frames": ["/tmp/j1/frame_001.jpg"]}), \
                patch("processor.app.enrich",
                      side_effect=lambda *a: order.append("enrich") or {
                          "articles": {"id": {}, "en": {}}, "json_ld": {}}), \
                patch("processor.app.purge",
                      side_effect=lambda *a: order.append("purge")), \
                patch("processor.app.upload_images",
                      side_effect=lambda *a: order.append("upload") or ["https://cdn/x.jpg"]):
            out = process(JOB)
        self.assertEqual(order, ["pipeline", "enrich", "upload", "purge"])
        self.assertEqual(out["job_id"], "j1")
        self.assertIn("articles", out)
        self.assertEqual(out["images"], ["https://cdn/x.jpg"])

    def test_purge_tetap_jalan_walau_pipeline_gagal(self):
        with patch("processor.app.pipeline", side_effect=RuntimeError("yt-dlp")), \
                patch("processor.app.purge") as purge, \
                self.assertRaises(RuntimeError):
            process(JOB)
        purge.assert_called_once_with("j1")

    def test_purge_tetap_jalan_walau_enrich_gagal(self):
        with patch("processor.app.pipeline",
                   return_value={"audio": "a", "frames": []}), \
                patch("processor.app.enrich", side_effect=RuntimeError("ai")), \
                patch("processor.app.purge") as purge, \
                self.assertRaises(RuntimeError):
            process(JOB)
        purge.assert_called_once_with("j1")


if __name__ == "__main__":
    unittest.main()
