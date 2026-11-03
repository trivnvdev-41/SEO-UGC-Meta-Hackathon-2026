import unittest
from unittest.mock import patch

from processor.app import ConvertJob, process, require_token


JOB = ConvertJob(job_id="j1", creator="@kreator")


class AppTest(unittest.TestCase):
    def test_purge_setelah_enrich_sukses(self):
        order = []
        with patch("processor.app.pipeline",
                   side_effect=lambda *a, **k: order.append("pipeline") or {
                       "audio": "/tmp/j1/audio.mp3", "frames": ["/tmp/j1/frame_001.jpg"],
                       "creator": "Kreator Hebat"}), \
                patch("processor.app.enrich",
                      side_effect=lambda *a, **k: order.append("enrich") or {
                          "articles": {"id": {}, "en": {}}, "json_ld": {}}) as en, \
                patch("processor.app.purge",
                      side_effect=lambda *a: order.append("purge")), \
                patch("processor.app.upload_images",
                      side_effect=lambda *a, **k: order.append("upload") or ["https://cdn/x.jpg"]):
            out = process(JOB)
        self.assertEqual(
            order, ["pipeline", "enrich", "upload", "upload", "purge"])
        self.assertEqual(out["job_id"], "j1")
        self.assertIn("articles", out)
        self.assertEqual(out["creator"], "Kreator Hebat")
        self.assertEqual(out["images"], ["https://cdn/x.jpg"])

    def test_purge_tetap_jalan_walau_pipeline_gagal(self):
        with patch("processor.app.pipeline", side_effect=RuntimeError("ffmpeg")), \
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

    def test_token_wajib(self):
        import os
        with patch.dict(os.environ, {"API_INTERNAL_TOKEN": "T"}, clear=True):
            require_token("Bearer T")  # tidak raise
            for bad in (None, "T", "Bearer salah"):
                with self.assertRaises(Exception) as cm:
                    require_token(bad)
                self.assertEqual(getattr(cm.exception, "status_code", None), 401)

    def test_token_belum_diset_fail_closed(self):
        import os
        with patch.dict(os.environ, {}, clear=True), \
                self.assertRaises(Exception) as cm:
            require_token("Bearer apa-saja")
        self.assertEqual(getattr(cm.exception, "status_code", None), 500)

    def test_tanpa_video_jadi_400(self):
        with patch("processor.app.pipeline",
                   side_effect=ValueError("no_video")), \
                patch("processor.app.purge") as purge, \
                self.assertRaises(Exception) as cm:
            process(JOB)
        self.assertEqual(getattr(cm.exception, "status_code", None), 400)
        purge.assert_called_once_with("j1")

    def test_media_sumber_tidak_dihapus_worker(self):
        # Regression job_6a2a: finally app.py dulu rmtree MEDIA_DIR/<job>,
        # sehingga retry selalu media_not_ready. Sekarang worker hanya purge /tmp;
        # penghapusan sumber milik gateway setelah artikel tersimpan.
        import os
        import tempfile
        from pathlib import Path
        tmp = Path(tempfile.mkdtemp())
        (tmp / "j9" / "video.mp4").parent.mkdir(parents=True, exist_ok=True)
        (tmp / "j9" / "video.mp4").write_bytes(b"\x00")
        with patch.dict(os.environ, {"MEDIA_DIR": str(tmp)}), \
                patch("processor.app.pipeline",
                      return_value={"audio": "a", "frames": []}), \
                patch("processor.app.enrich", side_effect=RuntimeError("ai")), \
                self.assertRaises(RuntimeError):
            process(ConvertJob(job_id="j9"))
        self.assertTrue((tmp / "j9" / "video.mp4").is_file())


    def test_process_kirim_frame_options_6_dan_confidence(self):
        frames = ["f%d" % i for i in range(10)]
        bundle = {"transcript": "halo", "language": "id", "confidence": 92.5,
                  "articles": {"id": {}, "en": {}}, "json_ld": {},
                  "selected_image_indices": [1, 4]}
        with patch("processor.app.pipeline",
                   return_value={"audio": "a", "frames": frames,
                                 "creator": None}):
            with patch("processor.app.enrich", return_value=bundle):
                with patch("processor.app.upload_images",
                            side_effect=lambda j, f, idx, **k:
                            ["https://cdn/%s" % i for i in idx]) as up:
                    with patch("processor.app.purge"):
                        out = process(JOB)
        self.assertEqual(out["confidence"], 92.5)
        self.assertEqual(len(out["frame_options"]), 6)
        # upload dipanggil 2x: gambar artikel + 6 opsi sampul
        self.assertEqual(up.call_count, 2)

    def test_regenerate_tolak_host_luar(self):
        from processor.app import RegenJob, regenerate as regen
        with self.assertRaises(Exception) as cm:
            regen(RegenJob(job_id="j9", transcript="halo dunia",
                           frame_urls=["https://evil.test/x.jpg"]))
        self.assertIn("frame_url_forbidden", str(cm.exception))

    def test_regenerate_sukses_dari_frame_sendiri(self):
        import os
        from processor import app as appmod
        with patch.dict(os.environ,
                        {"S3_PUBLIC_BASE_URL": "https://cdn.test/bkt"}):
            with patch.object(appmod, "_fetch_frame_bytes",
                              return_value=["aGVsbG8="]) as fb:
                with patch("processor.ai.generate_article",
                            return_value={"articles": {"id": {}, "en": {}},
                                          "json_ld": {}}) as ga:
                    out = appmod.regenerate(appmod.RegenJob(
                        job_id="j9", transcript="halo dunia",
                        frame_urls=["https://cdn.test/j9/frame_001.jpg"],
                        creator="@kreator"))
        fb.assert_called_once()
        self.assertEqual(ga.call_args[0][0], "halo dunia")
        self.assertIn("articles", out)


if __name__ == "__main__":
    unittest.main()
