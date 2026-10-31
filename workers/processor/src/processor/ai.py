"""AI per peran, dua provider terpisah (OpenAI-compatible).

Peran `stt` dan `llm` punya base URL, key, dan model sendiri — tidak ada
fallback antar peran, jadi boleh beda provider. Key hanya dari env/arg dan
tidak pernah dicetak. Stdlib-only (urllib).
"""

from __future__ import annotations

import base64
import io
import json
import os
import secrets
import urllib.request
from pathlib import Path

_TIMEOUT = 120
_MAX_IMAGES = 8  # provider max 8 (was 10 -> 400 Too many images)
_ROLES = ("stt", "llm")


def _require(name: str, value: str) -> str:
    if not value:
        raise RuntimeError(f"missing:{name}")
    return value


def _resolve(role: str, base: str | None, api_key: str | None,
             model: str | None) -> tuple[str, str, str]:
    """(base, key, model) untuk satu peran. Arg menang; None → env.

    Baca env saat dipanggil, bukan saat import, agar `--env-file`/`source`
    tetap berlaku. Nilai string kosong dianggap hilang (bukan fallback).
    """
    if role not in _ROLES:
        raise ValueError("invalid_role")
    prefix = f"AI_{role.upper()}_"
    vals = []
    for field, override in (("BASE_URL", base), ("API_KEY", api_key),
                            ("MODEL", model)):
        name = prefix + field
        vals.append(_require(
            name, os.environ.get(name, "") if override is None else override))
    b, k, m = vals
    return b.rstrip("/"), k, m


def settings(role: str) -> tuple[str, str, str]:
    """Validasi konfigurasi satu peran; dipakai untuk gagal cepat saat start."""
    return _resolve(role, None, None, None)


def _post(url: str, api_key: str, body: bytes, content_type: str) -> dict:
    req = urllib.request.Request(
        url, data=body,
        headers={"Authorization": f"Bearer {api_key}",
                 "Content-Type": content_type},
        method="POST")
    try:
        with urllib.request.urlopen(req, timeout=_TIMEOUT) as res:
            return json.loads(res.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:200]
        raise RuntimeError(f"ai_http_{e.code}:{detail}") from e


def _multipart(model: str, audio: Path) -> tuple[bytes, str]:
    boundary = "----seougc" + secrets.token_hex(8)
    buf = io.BytesIO()

    def field(name: str, value: str) -> None:
        buf.write(f"--{boundary}\r\nContent-Disposition: form-data; "
                  f'name="{name}"\r\n\r\n{value}\r\n'.encode())

    field("model", model)
    buf.write(f'--{boundary}\r\nContent-Disposition: form-data; '
              f'name="file"; filename="{audio.name}"\r\n'
              f"Content-Type: audio/mpeg\r\n\r\n".encode())
    buf.write(audio.read_bytes())
    buf.write(f"\r\n--{boundary}--\r\n".encode())
    return buf.getvalue(), f"multipart/form-data; boundary={boundary}"


def transcribe_audio(audio_path: str | Path, api_key: str | None = None,
                     model: str | None = None,
                     base: str | None = None) -> dict:
    """audio.mp3 -> {'text', 'language'} via endpoint STT."""
    audio = Path(audio_path)
    base, api_key, model = _resolve("stt", base, api_key, model)
    body, ctype = _multipart(model, audio)
    data = _post(f"{base}/audio/transcriptions", api_key, body, ctype)
    return {"text": data["text"], "language": data.get("language")}


def _wav16k(audio: Path) -> Path:
    """Meta ASR hanya terima WAV: konversi ke 16kHz mono di sebelah file asli."""
    import subprocess
    wav = audio.with_suffix(".wav")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(audio),
                    "-ar", "16000", "-ac", "1", str(wav)],
                   check=True, timeout=60)
    return wav


def _meta_asr_parts(model: str, wav: Path) -> tuple[bytes, str]:
    boundary = "----seougc" + secrets.token_hex(8)
    buf = io.BytesIO()
    buf.write(f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
              f'Content-Type: application/json\r\n\r\n'
              f'{json.dumps({"model": model, "audioEncoding": "WAV"})}\r\n'.encode())
    buf.write(f'--{boundary}\r\nContent-Disposition: form-data; name="audio"; '
              f'filename="{wav.name}"\r\nContent-Type: audio/wav\r\n\r\n'.encode())
    buf.write(wav.read_bytes())
    buf.write(f"\r\n--{boundary}--\r\n".encode())
    return buf.getvalue(), f"multipart/form-data; boundary={boundary}"


def transcribe_meta_asr(audio_path: str | Path, api_key: str | None = None,
                        model: str | None = None,
                        endpoint: str | None = None) -> dict:
    """audio -> {'text', None} via endpoint Meta ASR (bukan OpenAI-compatible).

    AI_STT_BASE_URL diisi URL endpoint penuh (…/v1/asr/transcribe)."""
    audio = Path(audio_path)
    if endpoint is None:
        endpoint = os.environ.get("AI_STT_BASE_URL", "")
    if api_key is None:
        api_key = os.environ.get("AI_STT_API_KEY", "")
    if model is None:
        model = os.environ.get("AI_STT_MODEL", "")
    endpoint = _require("AI_STT_BASE_URL", endpoint).rstrip("/")
    _require("AI_STT_API_KEY", api_key)
    _require("AI_STT_MODEL", model)
    body, ctype = _meta_asr_parts(model, _wav16k(audio))
    data = _post(endpoint, api_key, body, ctype)
    return {"text": data["transcript"], "language": None}


def stt_mode() -> str:
    """openai (default) atau meta-asr. Dibaca saat dipanggil seperti env lain."""
    return os.environ.get("AI_STT_MODE", "").strip() or "openai"


PROMPT = ("Kamu analis review produk. Dari TRANSKRIP + FOTO berikut, "
          "pilih foto produk dan tulis artikel SEO dua bahasa. "
          "KRITERIA FOTO (urutan penting): "
          "1) tajam/fokus, tidak blur atau goyang; "
          "2) produk terlihat utuh dan dominan di frame, bukan jauh/kecil; "
          "3) pencahayaan cukup, warna produk dikenali; "
          "4) tolak foto yang tertutup jari/tangan, teks overlay besar, "
          "atau transisi/efek. "
          "Pilih 2-3 indeks terbaik ke selected_image_indices. "
          "NADA: tulis natural seperti blogger profesional yang memakai "
          "produknya. DILARANG menyebut proses di balik artikel "
          "(transkrip, frame, AI, model, diekstrak, terdeteksi, "
          "dianalisis): pembaca tidak boleh sadar artikel dibuat mesin. "
          "STRUKTUR: body_md wajib memakai subheading ### tiap 100-150 kata, "
          "list - atau 1. untuk poin, dan > untuk catatan penting. "
          "Balas HANYA JSON: "
          '{{"selected_image_indices": [0], '
          '"articles": {{"id": {{"title": ..., "meta": ..., "body_md": ...}}, '
          '"en": {{"title": ..., "meta": ..., "body_md": ...}}}}, '
          '"json_ld": {{...Product Review schema...}}}}. '
          "TRANSKRIP:\n{transcript}")


def generate_article(transcript: str, images_b64: list[str],
                     api_key: str | None = None, model: str | None = None,
                     base: str | None = None) -> dict:
    """Transkrip + foto base64 -> bundle artikel via model multimodal."""
    base, api_key, model = _resolve("llm", base, api_key, model)
    content: list[dict] = [
        {"type": "text", "text": PROMPT.format(transcript=transcript)}]
    for b64 in images_b64[:_MAX_IMAGES]:
        content.append({"type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{b64}"}})
    body = json.dumps({
        "model": model,
        "response_format": {"type": "json_object"},
        "messages": [{"role": "user", "content": content}],
    }).encode()
    data = _post(f"{base}/chat/completions", api_key, body,
                 "application/json")
    return json.loads(data["choices"][0]["message"]["content"])


def enrich(audio_path: str | Path, frame_paths: list[str | Path],
           api_key: str | None = None) -> dict:
    """Satu pintu worker: STT dulu, lalu artikel + seleksi foto."""
    if stt_mode() == "meta-asr":
        stt = transcribe_meta_asr(audio_path, api_key)
    else:
        stt = transcribe_audio(audio_path, api_key)
    images = [base64.b64encode(Path(p).read_bytes()).decode()
              for p in frame_paths]
    bundle = generate_article(stt["text"], images, api_key)
    return {"transcript": stt["text"], "language": stt["language"], **bundle}
