import unittest
from pathlib import Path
from unittest.mock import patch

from processor.media import (
    audio_cmd,
    check_size,
    cookies_file,
    download_cmd,
    frames_cmd,
    is_convertible_url,
    job_dir,
    pipeline,
    purge,
)


class MediaTest(unittest.TestCase):
    def test_download_cmd_pin_output(self):
        cmd = download_cmd("https://vt.tiktok.com/x/", Path("/tmp/j1/video.mp4"))
        self.assertEqual(cmd[:3], ["yt-dlp", "-o", "/tmp/j1/video.mp4"])
        self.assertIn("--max-filesize", cmd)
        self.assertEqual(cmd[-1], "https://vt.tiktok.com/x/")

    def test_download_cmd_batas_ukuran(self):
        cmd = download_cmd("https://vt.tiktok.com/x/", Path("/tmp/v.mp4"),
                           max_mb=12, max_sec=90)
        self.assertEqual(cmd[cmd.index("--max-filesize") + 1], "12M")
        self.assertEqual(cmd[cmd.index("--match-filter") + 1], "duration <= 90")
        self.assertEqual(cmd[cmd.index("--socket-timeout") + 1], "30")

    def test_check_size_tolak_file_raksasa(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            video = Path(tmp) / "video.mp4"
            video.write_bytes(b"x" * (1024 * 1024 + 1))
            with self.assertRaises(ValueError) as cm:
                check_size(video, max_mb=1)
            self.assertEqual(str(cm.exception), "video_too_large")
            check_size(video, max_mb=2)  # lolos

    def test_pipeline_pakai_timeout(self):
        seen = []
        pipeline("testjob4", "https://vt.tiktok.com/x/",
                 run=lambda cmd, **kw: seen.append(kw.get("timeout")))
        self.assertEqual(seen, [120, 60, 60])
        purge("testjob4")

    def test_pipeline_tolak_video_terlalu_besar(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            def fake_run(cmd, **kw):
                if cmd[0] == "yt-dlp":
                    Path(cmd[2]).write_bytes(b"x" * (2 * 1024 * 1024))
            with patch.dict("os.environ", {"MAX_VIDEO_MB": "1"}, clear=True), \
                    patch("processor.media.TMP_ROOT", root), \
                    self.assertRaises(ValueError) as cm:
                pipeline("toolarge", "https://vt.tiktok.com/x/", run=fake_run)
            self.assertEqual(str(cm.exception), "video_too_large")
            purge("toolarge")

    def test_download_cmd_pakai_cookies(self):
        cmd = download_cmd("https://vt.tiktok.com/x/",
                           Path("/tmp/j1/video.mp4"), "/tmp/ck.txt")
        self.assertEqual(cmd[-1], "https://vt.tiktok.com/x/")
        self.assertEqual(cmd[-3:], ["--cookies", "/tmp/ck.txt", cmd[-1]])

    def test_cookies_file_env(self):
        with patch.dict("os.environ", {}, clear=True):
            self.assertIsNone(cookies_file())
        with patch.dict("os.environ", {"YTDLP_COOKIES_FILE": ""}, clear=True):
            self.assertIsNone(cookies_file())

    def test_cookies_file_hilang_gagal_cepat(self):
        env = {"YTDLP_COOKIES_FILE": "/tmp/tidak-ada-cookies.txt"}
        with patch.dict("os.environ", env, clear=True), \
                self.assertRaises(RuntimeError) as cm:
            cookies_file()
        self.assertIn("YTDLP_COOKIES_FILE", str(cm.exception))
        self.assertNotIn("/tmp/tidak-ada", str(cm.exception))

    def test_audio_cmd_mp3_lame(self):
        cmd = audio_cmd(Path("/tmp/j1/video.mp4"), Path("/tmp/j1/audio.mp3"))
        self.assertIn("libmp3lame", cmd)
        self.assertEqual(cmd[-1], "/tmp/j1/audio.mp3")

    def test_frames_cmd_pattern(self):
        cmd = frames_cmd(Path("/tmp/j1/video.mp4"), Path("/tmp/j1/frame_%03d.jpg"))
        self.assertIn("fps=1/3", cmd)

    def test_pipeline_runs_three_steps(self):
        seen = []
        out = pipeline("testjob1", "https://vt.tiktok.com/x/",
                       run=lambda cmd, **kw: seen.append(cmd) or None)
        self.assertEqual(len(seen), 3)
        self.assertTrue(out["audio"].endswith("audio.mp3"))
        self.assertIsInstance(out["frames"], list)
        purge("testjob1")

    def test_pipeline_frames_list_dari_glob(self):
        import tempfile
        from processor import media

        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp) / "frames"
            d.mkdir()
            (d / "frame_001.jpg").write_bytes(b"x")
            (d / "frame_002.jpg").write_bytes(b"x")
            got = sorted(str(p) for p in d.glob("frame_*.jpg"))[:10]
        self.assertEqual([Path(p).name for p in got],
                         ["frame_001.jpg", "frame_002.jpg"])
        self.assertTrue(media.FRAME_PATTERN.endswith(".jpg"))

    def test_purge_removes_dir(self):
        d = job_dir("testjob2")
        d.mkdir(parents=True, exist_ok=True)
        (d / "video.mp4").touch()
        purge("testjob2")
        self.assertFalse(d.exists())

    def test_bad_job_id_rejected(self):
        with self.assertRaises(ValueError):
            job_dir("../escape")

    def test_url_allowlist(self):
        self.assertTrue(is_convertible_url("https://vt.tiktok.com/x/"))
        self.assertTrue(is_convertible_url("https://www.instagram.com/reel/a/"))
        self.assertFalse(is_convertible_url("http://169.254.169.254/x"))
        self.assertFalse(is_convertible_url("https://evil.com/v/1"))
        self.assertFalse(is_convertible_url("https://tiktok.com.evil.com/x"))
        self.assertFalse(is_convertible_url("http://www.tiktok.com/@a/video/1"))

    def test_pipeline_tolak_url_tidak_diizinkan(self):
        seen = []
        with self.assertRaises(ValueError):
            pipeline("testjob3", "http://169.254.169.254/latest",
                     run=lambda *a, **k: seen.append(a))
        self.assertEqual(seen, [])


if __name__ == "__main__":
    unittest.main()
