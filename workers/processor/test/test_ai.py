import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from processor import ai


def _mp3(tmp) -> str:
    p = Path(tmp) / "audio.mp3"
    p.write_bytes(b"ID3fake-audio")
    return str(p)


class FakeRes:
    def __init__(self, payload: bytes):
        self._payload = payload

    def read(self):
        return self._payload

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def _fake_urlopen_factory(captured, payload: bytes):
    def _fake(req, timeout=None):
        captured["url"] = req.full_url
        captured["auth"] = req.get_header("Authorization")
        captured["ctype"] = req.get_header("Content-type")
        captured["body"] = req.data
        return FakeRes(payload)
    return _fake


class AiTest(unittest.TestCase):
    def test_transcribe_posts_multipart(self):
        cap = {}
        payload = json.dumps(
            {"text": "review bagus", "language": "id"}).encode()
        with tempfile.TemporaryDirectory() as tmp, patch(
                "urllib.request.urlopen",
                _fake_urlopen_factory(cap, payload)):
            out = ai.transcribe_audio(_mp3(tmp), "K",
                                      model="m-vox", base="https://fw.test")
        self.assertEqual(out, {"text": "review bagus", "language": "id"})
        self.assertTrue(cap["url"].endswith("/audio/transcriptions"))
        self.assertEqual(cap["auth"], "Bearer K")
        self.assertIn("multipart/form-data", cap["ctype"])
        self.assertIn(b"audio.mp3", cap["body"])

    def test_meta_asr_posts_request_plus_wav(self):
        cap = {}
        payload = json.dumps(
            {"transcript": "halo", "sessionId": "s"}).encode()
        with tempfile.TemporaryDirectory() as tmp, patch(
                "urllib.request.urlopen",
                _fake_urlopen_factory(cap, payload)), patch.object(
                ai, "_wav16k", return_value=Path(_mp3(tmp))):
            out = ai.transcribe_meta_asr(
                _mp3(tmp), "K", model="m-vox",
                endpoint="https://m.test/v1/asr/transcribe")
        self.assertEqual(out, {"text": "halo", "language": None})
        self.assertEqual(cap["url"], "https://m.test/v1/asr/transcribe")
        self.assertIn(b'name="request"', cap["body"])
        self.assertIn(b'name="audio"', cap["body"])
        self.assertIn(b'"audioEncoding": "WAV"', cap["body"])

    def test_enrich_meta_asr_mode(self):
        with patch.dict(os.environ, {"AI_STT_MODE": "meta-asr"}), \
             patch.object(ai, "transcribe_meta_asr",
                          return_value={"text": "t", "language": None}) as m, \
             patch.object(ai, "transcribe_audio") as o, \
             patch.object(ai, "generate_article", return_value={}):
            ai.enrich("/tmp/j/audio.mp3", [])
        m.assert_called_once()
        o.assert_not_called()

    def test_generate_posts_images_json(self):
        cap = {}
        bundle = {"selected_image_indices": [1], "articles": {},
                  "json_ld": {}}
        payload = json.dumps(
            {"choices": [{"message": {"content": json.dumps(bundle)}}]}
        ).encode()
        with patch("urllib.request.urlopen",
                   _fake_urlopen_factory(cap, payload)):
            out = ai.generate_article("teks", ["B64A", "B64B"], "K",
                                      model="m-spark", base="https://fw.test")
        self.assertEqual(out["selected_image_indices"], [1])
        self.assertTrue(cap["url"].endswith("/chat/completions"))
        body = json.loads(cap["body"])
        self.assertEqual(body["response_format"], {"type": "json_object"})
        imgs = [c for c in body["messages"][0]["content"]
                if c["type"] == "image_url"]
        self.assertEqual(len(imgs), 2)
        self.assertTrue(imgs[0]["image_url"]["url"].startswith(
            "data:image/jpeg;base64,"))

    def test_prompt_sebut_kreator_di_judul(self):
        cap = {}
        payload = json.dumps(
            {"choices": [{"message": {"content": "{}"}}]}
        ).encode()
        with patch("urllib.request.urlopen",
                   _fake_urlopen_factory(cap, payload)):
            ai.generate_article("teks", [], "K", model="m", base="https://t",
                                creator="Kreator Hebat")
        text = json.loads(cap["body"])["messages"][0]["content"][0]["text"]
        self.assertIn("Kreator Hebat", text)
        self.assertIn("JUDUL", text)
        self.assertIn("DILARANG", text)

    def test_prompt_larang_karang_nama_tanpa_kreator(self):
        cap = {}
        payload = json.dumps(
            {"choices": [{"message": {"content": "{}"}}]}
        ).encode()
        with patch("urllib.request.urlopen",
                   _fake_urlopen_factory(cap, payload)):
            ai.generate_article("teks", [], "K", model="m", base="https://t")
        text = json.loads(cap["body"])["messages"][0]["content"][0]["text"]
        self.assertIn("JANGAN mengarang", text)

    def test_enrich_wires_stt_then_spark(self):
        with patch.object(ai, "transcribe_audio",
                          return_value={"text": "t", "language": "id"}), \
             patch.object(ai, "generate_article",
                          return_value={"selected_image_indices": [0]}) as gen:
            out = ai.enrich("/tmp/j/audio.mp3", [])
        self.assertEqual(out["transcript"], "t")
        self.assertEqual(out["selected_image_indices"], [0])
        gen.assert_called_once()

    def test_enrich_tanpa_key_bersama_antar_peran(self):
        import inspect
        self.assertNotIn("api_key", inspect.signature(ai.enrich).parameters)

    def test_missing_model_raises(self):
        with tempfile.TemporaryDirectory() as tmp, \
                self.assertRaises(RuntimeError):
            ai.transcribe_audio(_mp3(tmp), "K", model="")

    def test_stt_dan_llm_pakai_provider_berbeda(self):
        env = {
            "AI_STT_BASE_URL": "https://stt.test/v1/",
            "AI_STT_API_KEY": "K-STT",
            "AI_STT_MODEL": "m-stt",
            "AI_LLM_BASE_URL": "https://llm.test/v1",
            "AI_LLM_API_KEY": "K-LLM",
            "AI_LLM_MODEL": "m-llm",
        }
        seen = []

        def fake(req, timeout=None):
            seen.append((req.full_url, req.get_header("Authorization")))
            if req.full_url.endswith("/audio/transcriptions"):
                return FakeRes(json.dumps(
                    {"text": "t", "language": "id"}).encode())
            return FakeRes(json.dumps(
                {"choices": [{"message": {"content": "{}"}}]}).encode())

        with tempfile.TemporaryDirectory() as tmp, \
                patch.dict(os.environ, env, clear=True), \
                patch("urllib.request.urlopen", fake):
            ai.transcribe_audio(_mp3(tmp))
            ai.generate_article("teks", [])

        self.assertEqual(seen[0], (
            "https://stt.test/v1/audio/transcriptions", "Bearer K-STT"))
        self.assertEqual(seen[1], (
            "https://llm.test/v1/chat/completions", "Bearer K-LLM"))

    def test_env_hilang_sebut_nama_var_tanpa_nilai(self):
        env = {"AI_LLM_BASE_URL": "https://llm.test/v1",
               "AI_LLM_API_KEY": "RAHASIA-JANGAN-MUNCUL",
               "AI_LLM_MODEL": "m-llm"}
        with patch.dict(os.environ, env, clear=True), \
                self.assertRaises(RuntimeError) as cm:
            ai.settings("stt")
        msg = str(cm.exception)
        self.assertIn("AI_STT_BASE_URL", msg)
        self.assertNotIn("RAHASIA-JANGAN-MUNCUL", msg)


if __name__ == "__main__":
    unittest.main()
