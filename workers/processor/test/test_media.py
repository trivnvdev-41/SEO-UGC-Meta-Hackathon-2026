import unittest
from pathlib import Path
from unittest.mock import patch

from processor.media import (
    N_FRAMES,
    check_size,
    extract_cmd,
    job_dir,
    max_filesize_mb,
    max_seconds,
    pipeline,
    probe_duration,
    purge,
    spread_fps,
    video_inbox,
)


def _inbox(tmp, job_id="jobvUp"):
    inbox = Path(tmp) / job_id
    inbox.mkdir()
    (inbox / "video.mp4").write_bytes(b"v" * 100)
    return inbox


def _ffmpeg_ok(job_id="jobvUp"):
    def fake_run(cmd, **kw):
        if cmd[0] == "ffprobe":
            from types import SimpleNamespace
            return SimpleNamespace(stdout="60.0\n")
        if cmd[0] == "ffmpeg":
            jd = Path("/tmp") / job_id
            jd.mkdir(parents=True, exist_ok=True)
            (jd / "audio.mp3").write_bytes(b"x")
            (jd / "frame_001.jpg").write_bytes(b"x")
        return None
    return fake_run


class MediaTest(unittest.TestCase):
    def test_check_size_tolak_file_raksasa(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            video = Path(tmp) / "video.mp4"
            video.write_bytes(b"x" * (1024 * 1024 + 1))
            with self.assertRaises(ValueError) as cm:
                check_size(video, max_mb=1)
            self.assertEqual(str(cm.exception), "video_too_large")
            check_size(video, max_mb=2)  # lolos

    def test_batas_default(self):
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(max_filesize_mb(), 50)
            self.assertEqual(max_seconds(), 180)

    def test_pipeline_tanpa_upload_ditolak(self):
        with patch.dict("os.environ", {}, clear=True), \
                self.assertRaises(ValueError) as cm:
            pipeline("novideo", run=lambda *a, **k: None)
        self.assertEqual(str(cm.exception), "no_video")

    def test_pipeline_video_upload_tanpa_unduh(self):
        import os
        import tempfile
        from processor import media

        with tempfile.TemporaryDirectory() as tmp:
            inbox = _inbox(tmp)
            env = {"MEDIA_DIR": tmp}
            try:
                with patch.dict(os.environ, env, clear=True):
                    self.assertEqual(
                        video_inbox("jobvUp"), inbox / "video.mp4")
                    out = media.pipeline("jobvUp", run=_ffmpeg_ok(),
                                         creator="@kreator")
            finally:
                media.purge("jobvUp")
        self.assertTrue(out["local"])
        self.assertEqual(out["creator"], "@kreator")
        self.assertTrue(out["audio"].endswith("audio.mp3"))
        self.assertEqual(len(out["frames"]), 1)

    def test_pipeline_video_upload_kepanjangan_ditolak(self):
        import os
        import tempfile
        from types import SimpleNamespace
        from processor import media

        def fake_run(cmd, **kw):
            return SimpleNamespace(stdout="9999.0\n")

        with tempfile.TemporaryDirectory() as tmp:
            _inbox(tmp, "joblong")
            env = {"MEDIA_DIR": tmp}
            with patch.dict(os.environ, env, clear=True), \
                    self.assertRaises(ValueError) as cm:
                media.pipeline("joblong", run=fake_run)
            self.assertEqual(str(cm.exception), "video_too_long")

    def test_pipeline_frames_list_dari_glob(self):
        import tempfile
        from processor import media

        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp) / "frames"
            d.mkdir()
            (d / "frame_001.jpg").write_bytes(b"x")
            (d / "frame_002.jpg").write_bytes(b"x")
            got = sorted(str(p) for p in d.glob("frame_*.jpg"))[:N_FRAMES]
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

    def test_extract_cmd_satu_pass_audio_dan_frame(self):
        cmd = extract_cmd(Path("/tmp/j/v.mp4"), Path("/tmp/j/a.mp3"),
                          Path("/tmp/j/frame_%03d.jpg"), fps="0.0889")
        self.assertEqual(cmd.count("-i"), 1)
        self.assertIn("libmp3lame", cmd)
        self.assertIn("fps=0.0889", cmd)
        self.assertIn(str(N_FRAMES), cmd)
        self.assertEqual(cmd[0], "ffmpeg")

    def test_spread_fps_merata_sepanjang_durasi(self):
        # Video 90 dtk: 8 frame tersebar ~11 dtk sekali, frame terakhir ~detik 79.
        fps = float(spread_fps(90.0))
        self.assertAlmostEqual(fps, 8 / 90, places=4)
        self.assertGreaterEqual((N_FRAMES - 1) / fps, 75)
        # Video pendek: min 1 dtk antar frame, bukan fps raksasa.
        self.assertEqual(spread_fps(4.0), "1.0000")
        self.assertEqual(spread_fps(0.0), "1/3")

    def test_probe_duration_tak_terbaca(self):
        from types import SimpleNamespace
        with self.assertRaises(ValueError):
            probe_duration(Path("/tmp/x.mp4"),
                           run=lambda *a, **k: SimpleNamespace(stdout=""))


if __name__ == "__main__":
    unittest.main()
