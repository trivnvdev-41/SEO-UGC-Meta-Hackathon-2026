import unittest
from pathlib import Path

from processor.media import (
    audio_cmd,
    download_cmd,
    frames_cmd,
    job_dir,
    pipeline,
    purge,
)


class MediaTest(unittest.TestCase):
    def test_download_cmd_pin_output(self):
        cmd = download_cmd("https://vt.tiktok.com/x/", Path("/tmp/j1/video.mp4"))
        self.assertEqual(cmd[:3], ["yt-dlp", "-o", "/tmp/j1/video.mp4"])
        self.assertEqual(cmd[-1], "https://vt.tiktok.com/x/")

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
        purge("testjob1")

    def test_purge_removes_dir(self):
        d = job_dir("testjob2")
        d.mkdir(parents=True, exist_ok=True)
        (d / "video.mp4").touch()
        purge("testjob2")
        self.assertFalse(d.exists())

    def test_bad_job_id_rejected(self):
        with self.assertRaises(ValueError):
            job_dir("../escape")


if __name__ == "__main__":
    unittest.main()
