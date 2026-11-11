# Расшифровка голосовых для Telegram-бота (faster-whisper, локально, без интернета
# после первой загрузки модели). Работает как фоновый процесс:
#   вход  (stdin):  {"id": "...", "path": "C:\\...\\voice.oga"}      — по строке JSON
#   выход (stdout): {"id": "...", "text": "...", "duration": 12.3}   или {"id": "...", "error": "..."}
# Первая строка вывода — {"ready": true}, когда модель загружена.
# Настройки через переменные окружения: WHISPER_MODEL (medium), WHISPER_LANG (ru).
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.stdin.reconfigure(encoding="utf-8")
os.environ.setdefault("HF_HUB_DISABLE_TELEMETRY", "1")
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")

from faster_whisper import WhisperModel  # noqa: E402

MODEL = os.environ.get("WHISPER_MODEL", "medium")
LANG = os.environ.get("WHISPER_LANG", "ru") or None
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
THREADS = max(2, (os.cpu_count() or 4) // 2)


def decode_audio(path):
    """Any audio/video file → 16 kHz mono float32 (own decoder: newer PyAV
    versions dropped an argument faster-whisper's built-in decoder passes)."""
    import av
    import numpy as np

    chunks = []
    resampler = av.AudioResampler(format="s16", layout="mono", rate=16000)
    with av.open(path) as container:
        for frame in container.decode(audio=0):
            for f in resampler.resample(frame):
                chunks.append(f.to_ndarray().reshape(-1))
        for f in resampler.resample(None):
            chunks.append(f.to_ndarray().reshape(-1))
    if not chunks:
        return np.zeros(0, dtype=np.float32)
    return np.concatenate(chunks).astype(np.float32) / 32768.0


def send(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def load(local_only):
    return WhisperModel(MODEL, device="cpu", compute_type="int8", download_root=ROOT,
                        cpu_threads=THREADS, local_files_only=local_only)


try:
    try:
        model = load(True)   # already downloaded → no internet needed
    except Exception:  # noqa: BLE001
        model = load(False)  # first run: download the model
except Exception as e:  # noqa: BLE001
    send({"ready": False, "error": f"model load failed: {e}"})
    sys.exit(1)

send({"ready": True, "model": MODEL})

for line in sys.stdin:
    line = line.strip().lstrip("﻿")
    if not line:
        continue
    req_id = None
    try:
        req = json.loads(line)
        req_id = req.get("id")
        segments, info = model.transcribe(
            decode_audio(req["path"]),
            language=req.get("lang") or LANG,
            beam_size=int(req.get("beam", 3)),
            vad_filter=True,
            condition_on_previous_text=False,
        )
        text = " ".join(s.text.strip() for s in segments).strip()
        send({"id": req_id, "text": text, "duration": round(info.duration, 1), "language": info.language})
    except Exception as e:  # noqa: BLE001
        send({"id": req_id, "error": str(e)[:300]})
