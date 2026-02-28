#!/usr/bin/env python3
"""
Speaker Diarization & Transcription Server

A standalone server that processes audio and returns:
- Transcription (via mlx-whisper, Apple Silicon optimized)
- Speaker diarization (via pyannote.audio, MPS accelerated)
- Speaker identification (via SpeechBrain ECAPA-TDNN embeddings)

HTTP Endpoints (port 18793):
  POST /process       — Full pipeline: transcribe + diarize + identify speakers
  POST /transcribe    — Transcription only (mlx-whisper)
  POST /diarize       — Diarization only (pyannote)
  POST /enroll        — Enroll a speaker voice profile
  POST /enroll-batch  — Batch enroll from directory of audio files
  GET  /profiles      — List enrolled speaker profiles
  DELETE /profiles/<name> — Remove a speaker profile
  GET  /health        — Health check

WebSocket Endpoint (port 18794):
  ws://host:18794/ws/stream — Real-time streaming with VAD + hybrid pipeline
"""

import asyncio
import json
import os
import struct
import sys
import time
import tempfile
import logging
import threading
import wave
from concurrent.futures import ThreadPoolExecutor
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Optional
from urllib.parse import parse_qs, urlparse
import io
import re
import numpy as np

# Lazy-loaded models (initialized on first use)
_whisper_model = None
_diarization_pipeline = None
_speaker_model = None
_vad_model = None
_speaker_profiles: dict[str, np.ndarray] = {}  # name -> centroid embedding

# Paths
DATA_DIR = Path("/Users/zwang/projects/ryanhub/data")
ENROLLMENT_DIR = DATA_DIR / "voice-enrollment"
PROFILES_DIR = DATA_DIR / "voice-profiles"
PROFILES_DIR.mkdir(parents=True, exist_ok=True)

# Config
HOST = "0.0.0.0"
PORT = 18793
WS_PORT = 18794
WHISPER_MODEL = "mlx-community/whisper-large-v3-mlx"
SIMILARITY_THRESHOLD = 0.25  # Cosine similarity threshold for speaker ID
SAMPLE_RATE = 16000

# VAD config
VAD_FRAME_SAMPLES = 512      # Silero VAD expects 512 samples at 16kHz (32ms)
VAD_THRESHOLD = 0.5           # Speech probability threshold
SILENCE_TIMEOUT_MS = 500      # Silence duration to end a segment (ms)
SILENCE_FRAMES = SILENCE_TIMEOUT_MS // 32  # ~16 frames of 32ms each
MIN_SEGMENT_DURATION = 1.0    # Minimum speech segment duration in seconds
MAX_SEGMENT_DURATION = 30.0   # Maximum speech segment duration in seconds

# Thread pool for CPU/GPU-bound model inference
_executor = ThreadPoolExecutor(max_workers=4)

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("diarization")


# ============================================================
# Model Loading (lazy)
# ============================================================

def get_whisper():
    """Load mlx-whisper model (MLX/Metal accelerated)."""
    global _whisper_model
    if _whisper_model is None:
        log.info("Loading mlx-whisper model (first use)...")
        import mlx_whisper
        _whisper_model = mlx_whisper
        # Warm up by loading the model weights
        log.info(f"Whisper model: {WHISPER_MODEL}")
    return _whisper_model


def get_diarization_pipeline():
    """Load pyannote diarization pipeline (MPS accelerated)."""
    global _diarization_pipeline
    if _diarization_pipeline is None:
        log.info("Loading pyannote diarization pipeline (first use)...")
        import torch
        from pyannote.audio import Pipeline

        _diarization_pipeline = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-3.1",
            token=True,
        )
        # Use MPS if available for GPU acceleration
        if torch.backends.mps.is_available():
            import torch
            _diarization_pipeline.to(torch.device("mps"))
            log.info("Diarization pipeline using MPS (Metal) acceleration")
        else:
            log.info("Diarization pipeline using CPU")
    return _diarization_pipeline


def get_speaker_model():
    """Load SpeechBrain ECAPA-TDNN speaker verification model."""
    global _speaker_model
    if _speaker_model is None:
        log.info("Loading SpeechBrain ECAPA-TDNN model (first use)...")
        from speechbrain.inference.speaker import EncoderClassifier
        _speaker_model = EncoderClassifier.from_hparams(
            source="speechbrain/spkrec-ecapa-voxceleb",
            savedir=str(DATA_DIR / "speechbrain-cache"),
        )
        log.info("Speaker verification model loaded")
    return _speaker_model


def get_vad_model():
    """Load Silero VAD model for voice activity detection."""
    global _vad_model
    if _vad_model is None:
        log.info("Loading Silero VAD model (first use)...")
        from silero_vad import load_silero_vad
        _vad_model = load_silero_vad()
        log.info("Silero VAD model loaded")
    return _vad_model


# ============================================================
# Speaker Profile Management
# ============================================================

def load_profiles():
    """Load all speaker profiles from disk."""
    global _speaker_profiles
    _speaker_profiles = {}
    for f in PROFILES_DIR.glob("*.npy"):
        name = f.stem
        _speaker_profiles[name] = np.load(f)
        log.info(f"Loaded speaker profile: {name}")
    log.info(f"Total profiles loaded: {len(_speaker_profiles)}")


def save_profile(name: str, embedding: np.ndarray):
    """Save a speaker profile embedding to disk."""
    path = PROFILES_DIR / f"{name}.npy"
    np.save(path, embedding)
    _speaker_profiles[name] = embedding
    log.info(f"Saved speaker profile: {name} ({embedding.shape})")


def _convert_to_wav(audio_path: str) -> str:
    """Convert any audio format to 16kHz mono WAV using ffmpeg.
    Returns path to temp WAV file (caller must clean up)."""
    import subprocess
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp.close()
    subprocess.run(
        ["ffmpeg", "-y", "-i", audio_path, "-ar", "16000", "-ac", "1", tmp.name],
        capture_output=True, check=True,
    )
    return tmp.name


def _load_audio(audio_path: str):
    """Load audio, resample to 16kHz mono. Returns (waveform, sample_rate).
    Handles m4a, mp3, ogg, etc. via ffmpeg conversion."""
    import torch
    import torchaudio

    # Try direct load first, fall back to ffmpeg conversion
    tmp_wav = None
    try:
        waveform, sr = torchaudio.load(audio_path)
    except Exception:
        # Convert via ffmpeg (handles m4a, mp3, ogg, aac, etc.)
        tmp_wav = _convert_to_wav(audio_path)
        waveform, sr = torchaudio.load(tmp_wav)

    if sr != SAMPLE_RATE:
        resampler = torchaudio.transforms.Resample(sr, SAMPLE_RATE)
        waveform = resampler(waveform)

    if waveform.shape[0] > 1:
        waveform = waveform.mean(dim=0, keepdim=True)

    if tmp_wav:
        os.unlink(tmp_wav)

    return waveform, SAMPLE_RATE


def compute_embedding(audio_path: str) -> np.ndarray:
    """Compute speaker embedding for an audio file."""
    import torch

    model = get_speaker_model()
    waveform, sr = _load_audio(audio_path)

    with torch.no_grad():
        embedding = model.encode_batch(waveform)

    return embedding.squeeze().cpu().numpy()


# Sliding window config for enrollment
WINDOW_SECS = 10    # Each window is 10 seconds
HOP_SECS = 5        # 5 second overlap (hop = 5s)
MIN_SEGMENT_SECS = 3 # Minimum usable segment length


def compute_embeddings_sliding_window(audio_path: str) -> list[np.ndarray]:
    """Compute multiple embeddings from one audio file using sliding windows.

    For short files (< 15s): returns a single embedding.
    For longer files: slides a 10s window with 5s hop, producing many embeddings.
    This makes enrollment from a single long recording very robust."""
    import torch

    model = get_speaker_model()
    waveform, sr = _load_audio(audio_path)

    duration_secs = waveform.shape[1] / sr
    window_samples = WINDOW_SECS * sr
    hop_samples = HOP_SECS * sr
    min_samples = MIN_SEGMENT_SECS * sr

    # Short file: just one embedding
    if duration_secs < WINDOW_SECS + HOP_SECS:
        if waveform.shape[1] < min_samples:
            return []  # Too short
        with torch.no_grad():
            emb = model.encode_batch(waveform)
        return [emb.squeeze().cpu().numpy()]

    # Sliding window
    embeddings = []
    offset = 0
    while offset + min_samples <= waveform.shape[1]:
        end = min(offset + window_samples, waveform.shape[1])
        chunk = waveform[:, offset:end]

        if chunk.shape[1] < min_samples:
            break

        with torch.no_grad():
            emb = model.encode_batch(chunk)
        embeddings.append(emb.squeeze().cpu().numpy())
        offset += hop_samples

    return embeddings


def identify_speaker(embedding: np.ndarray) -> tuple[str, float]:
    """Match an embedding against enrolled profiles.
    Returns (speaker_name, similarity_score) or ("unknown", best_score)."""
    if not _speaker_profiles:
        return "unknown", 0.0

    best_name = "unknown"
    best_score = -1.0

    for name, profile in _speaker_profiles.items():
        # Cosine similarity
        sim = np.dot(embedding, profile) / (
            np.linalg.norm(embedding) * np.linalg.norm(profile) + 1e-8
        )
        if sim > best_score:
            best_score = float(sim)
            best_name = name

    if best_score >= SIMILARITY_THRESHOLD:
        return best_name, best_score
    return "unknown", best_score


# ============================================================
# Audio Processing
# ============================================================

def transcribe_audio(audio_path: str, language: Optional[str] = None) -> dict:
    """Transcribe audio using mlx-whisper."""
    whisper = get_whisper()

    kwargs = {
        "path_or_hf_repo": WHISPER_MODEL,
        "word_timestamps": True,
    }
    if language:
        kwargs["language"] = language

    result = whisper.transcribe(audio_path, **kwargs)
    return result


def diarize_audio(audio_path: str) -> list[dict]:
    """Run speaker diarization on audio file.
    Returns list of segments: [{start, end, speaker}]."""
    pipeline = get_diarization_pipeline()

    # Pass pre-loaded waveform dict to avoid torchcodec AudioDecoder dependency
    waveform, sr = _load_audio(audio_path)
    output = pipeline({"waveform": waveform, "sample_rate": sr})

    # pyannote 4.x returns DiarizeOutput; use .speaker_diarization Annotation
    annotation = getattr(output, "speaker_diarization", None)
    if annotation is not None:
        segments = []
        for turn, _, speaker in annotation.itertracks(yield_label=True):
            segments.append({
                "start": round(turn.start, 3),
                "end": round(turn.end, 3),
                "speaker": speaker,
            })
        return segments

    # Fallback: older pyannote returns Annotation directly
    segments = []
    for turn, _, speaker in output.itertracks(yield_label=True):
        segments.append({
            "start": round(turn.start, 3),
            "end": round(turn.end, 3),
            "speaker": speaker,
        })
    return segments


def extract_segment_audio(audio_path: str, start: float, end: float) -> str:
    """Extract a segment from an audio file and save to temp file."""
    import torchaudio

    waveform, sr = torchaudio.load(audio_path)

    # Convert time to samples
    start_sample = int(start * sr)
    end_sample = int(end * sr)

    # Clamp
    start_sample = max(0, start_sample)
    end_sample = min(waveform.shape[1], end_sample)

    segment = waveform[:, start_sample:end_sample]

    # Save to temp file
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    torchaudio.save(tmp.name, segment, sr)
    return tmp.name


def full_pipeline(audio_path: str, language: Optional[str] = None) -> dict:
    """Full pipeline: transcribe + diarize + identify speakers.

    Returns:
    {
        "transcript": "full text",
        "segments": [
            {
                "start": 0.0,
                "end": 2.5,
                "speaker": "zhiyuan",      # or "SPEAKER_00" if unknown
                "speaker_confidence": 0.87,
                "text": "Hello, how are you?"
            },
            ...
        ],
        "speakers": {
            "SPEAKER_00": {"identified_as": "zhiyuan", "confidence": 0.87},
            "SPEAKER_01": {"identified_as": "unknown", "confidence": 0.15}
        }
    }
    """
    t0 = time.time()

    # Step 1: Transcribe
    log.info("Step 1/3: Transcribing...")
    t1 = time.time()
    transcription = transcribe_audio(audio_path, language)
    log.info(f"  Transcription done in {time.time()-t1:.1f}s")

    # Step 2: Diarize
    log.info("Step 2/3: Diarizing...")
    t2 = time.time()
    diar_segments = diarize_audio(audio_path)
    log.info(f"  Diarization done in {time.time()-t2:.1f}s, found {len(diar_segments)} segments")

    # Step 3: Identify speakers (compute embedding per unique speaker)
    log.info("Step 3/3: Identifying speakers...")
    t3 = time.time()
    speaker_map = {}  # SPEAKER_XX -> {identified_as, confidence}
    unique_speakers = set(s["speaker"] for s in diar_segments)

    for spk in unique_speakers:
        # Get all segments for this speaker, take the longest ones for embedding
        spk_segs = [s for s in diar_segments if s["speaker"] == spk]
        spk_segs.sort(key=lambda s: s["end"] - s["start"], reverse=True)

        # Use up to 3 longest segments for robust embedding
        embeddings = []
        for seg in spk_segs[:3]:
            if seg["end"] - seg["start"] < 0.5:
                continue  # Skip very short segments
            try:
                seg_path = extract_segment_audio(audio_path, seg["start"], seg["end"])
                emb = compute_embedding(seg_path)
                embeddings.append(emb)
                os.unlink(seg_path)
            except Exception as e:
                log.warning(f"  Failed to compute embedding for {spk} segment: {e}")

        if embeddings:
            avg_emb = np.mean(embeddings, axis=0)
            name, confidence = identify_speaker(avg_emb)
            speaker_map[spk] = {
                "identified_as": name,
                "confidence": round(confidence, 3),
            }
        else:
            speaker_map[spk] = {
                "identified_as": "unknown",
                "confidence": 0.0,
            }

    log.info(f"  Speaker ID done in {time.time()-t3:.1f}s")

    # Step 4: Merge transcription with diarization
    # Assign each word to a diarization segment based on timestamp overlap
    words = []
    if "segments" in transcription:
        for seg in transcription["segments"]:
            if "words" in seg:
                words.extend(seg["words"])

    output_segments = []
    for dseg in diar_segments:
        # Find words that fall within this diarization segment
        seg_words = []
        for w in words:
            w_start = w.get("start", 0)
            w_end = w.get("end", 0)
            # Word overlaps with diarization segment?
            if w_start < dseg["end"] and w_end > dseg["start"]:
                seg_words.append(w.get("word", "").strip())

        text = " ".join(seg_words).strip()
        spk_info = speaker_map.get(dseg["speaker"], {"identified_as": "unknown", "confidence": 0.0})

        output_segments.append({
            "start": dseg["start"],
            "end": dseg["end"],
            "speaker": spk_info["identified_as"],
            "speaker_label": dseg["speaker"],
            "speaker_confidence": spk_info["confidence"],
            "text": text,
        })

    total_time = time.time() - t0
    log.info(f"Full pipeline completed in {total_time:.1f}s")

    return {
        "transcript": transcription.get("text", ""),
        "segments": output_segments,
        "speakers": speaker_map,
        "processing_time": round(total_time, 2),
    }


# ============================================================
# HTTP Server
# ============================================================

def parse_multipart(headers, body: bytes) -> dict[str, list]:
    """Parse multipart/form-data without the deprecated cgi module.
    Returns dict mapping field names to lists of (filename, data) tuples.
    Text fields have filename=None and data is a string."""
    content_type = headers.get("Content-Type", "")
    # Extract boundary
    match = re.search(r'boundary=([^\s;]+)', content_type)
    if not match:
        return {}
    boundary = match.group(1).encode()

    result: dict[str, list] = {}
    parts = body.split(b"--" + boundary)

    for part in parts:
        if part in (b"", b"--", b"--\r\n", b"\r\n"):
            continue
        part = part.strip(b"\r\n")
        if part == b"--":
            continue

        # Split headers from body
        header_end = part.find(b"\r\n\r\n")
        if header_end == -1:
            continue
        part_headers = part[:header_end].decode("utf-8", errors="replace")
        part_body = part[header_end + 4:]
        # Strip trailing \r\n
        if part_body.endswith(b"\r\n"):
            part_body = part_body[:-2]

        # Parse Content-Disposition
        name_match = re.search(r'name="([^"]*)"', part_headers)
        if not name_match:
            continue
        field_name = name_match.group(1)

        filename_match = re.search(r'filename="([^"]*)"', part_headers)
        filename = filename_match.group(1) if filename_match else None

        if field_name not in result:
            result[field_name] = []

        if filename is not None:
            result[field_name].append((filename, part_body))
        else:
            result[field_name].append((None, part_body.decode("utf-8", errors="replace")))

    return result


class DiarizationHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        log.info(f"{self.client_address[0]} - {format % args}")

    def _read_body(self) -> bytes:
        length = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(length) if length > 0 else b""

    def _send_json(self, data: dict, status: int = 200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_error(self, msg: str, status: int = 400):
        self._send_json({"error": msg}, status)

    def _save_upload(self, field_name: str = "audio") -> Optional[str]:
        """Parse uploaded audio and save to temp file.
        For multipart: extracts the named field.
        For raw binary: saves the entire body."""
        content_type = self.headers.get("Content-Type", "")
        body = self._read_body()

        if "multipart/form-data" in content_type:
            parts = parse_multipart(self.headers, body)
            files = parts.get(field_name, [])
            if not files:
                return None

            paths = []
            for filename, data in files:
                if filename is not None and data:
                    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
                    tmp.write(data)
                    tmp.close()
                    paths.append(tmp.name)

            if len(paths) == 1:
                return paths[0]
            elif paths:
                return paths
            return None
        else:
            if not body:
                return None
            tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
            tmp.write(body)
            tmp.close()
            return tmp.name

    def do_GET(self):
        if self.path == "/health":
            self._send_json({
                "status": "ok",
                "profiles": list(_speaker_profiles.keys()),
                "models": {
                    "whisper": _whisper_model is not None,
                    "diarization": _diarization_pipeline is not None,
                    "speaker": _speaker_model is not None,
                },
                "websocket_port": WS_PORT,
            })
        elif self.path == "/profiles":
            profiles = {}
            for name, emb in _speaker_profiles.items():
                profiles[name] = {
                    "embedding_dim": emb.shape[0] if emb.ndim == 1 else emb.shape,
                }
            self._send_json({"profiles": profiles})
        else:
            self._send_error("Not found", 404)

    def do_DELETE(self):
        if self.path.startswith("/profiles/"):
            name = self.path.split("/profiles/")[1]
            profile_path = PROFILES_DIR / f"{name}.npy"
            if profile_path.exists():
                profile_path.unlink()
                _speaker_profiles.pop(name, None)
                self._send_json({"message": f"Profile '{name}' deleted"})
            else:
                self._send_error(f"Profile '{name}' not found", 404)
        else:
            self._send_error("Not found", 404)

    def do_POST(self):
        try:
            if self.path == "/process":
                self._handle_process()
            elif self.path == "/transcribe":
                self._handle_transcribe()
            elif self.path == "/diarize":
                self._handle_diarize()
            elif self.path == "/enroll":
                self._handle_enroll()
            elif self.path == "/enroll-batch":
                self._handle_enroll_batch()
            else:
                self._send_error("Not found", 404)
        except Exception as e:
            log.exception(f"Error handling {self.path}")
            self._send_error(str(e), 500)

    def _handle_process(self):
        """Full pipeline: transcribe + diarize + identify."""
        audio_path = self._save_upload()
        if not audio_path or isinstance(audio_path, list):
            self._send_error("Audio file required (single file)")
            return

        try:
            # Parse optional language parameter from query string
            language = None
            if "?" in self.path:
                params = parse_qs(urlparse(self.path).query)
                language = params.get("language", [None])[0]

            result = full_pipeline(audio_path, language)
            self._send_json(result)
        finally:
            os.unlink(audio_path)

    def _handle_transcribe(self):
        """Transcription only."""
        audio_path = self._save_upload()
        if not audio_path or isinstance(audio_path, list):
            self._send_error("Audio file required (single file)")
            return

        try:
            result = transcribe_audio(audio_path)
            self._send_json({
                "text": result.get("text", ""),
                "segments": result.get("segments", []),
                "language": result.get("language", ""),
            })
        finally:
            os.unlink(audio_path)

    def _handle_diarize(self):
        """Diarization only."""
        audio_path = self._save_upload()
        if not audio_path or isinstance(audio_path, list):
            self._send_error("Audio file required (single file)")
            return

        try:
            segments = diarize_audio(audio_path)
            self._send_json({"segments": segments})
        finally:
            os.unlink(audio_path)

    def _handle_enroll(self):
        """Enroll a speaker from uploaded audio file(s)."""
        content_type = self.headers.get("Content-Type", "")

        if "multipart/form-data" not in content_type:
            self._send_error("Multipart form data required")
            return

        body = self._read_body()
        parts = parse_multipart(self.headers, body)

        # Get speaker name
        name_parts = parts.get("speaker_name", [])
        speaker_name = name_parts[0][1].strip() if name_parts else ""
        if not speaker_name:
            self._send_error("speaker_name is required")
            return

        # Get audio files
        audio_parts = parts.get("audio", [])
        if not audio_parts:
            self._send_error("No audio files provided")
            return

        embeddings = []
        tmp_files = []

        for filename, data in audio_parts:
            if filename is None or not data:
                continue
            tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
            tmp.write(data)
            tmp.close()
            tmp_files.append(tmp.name)

            try:
                embs = compute_embeddings_sliding_window(tmp.name)
                embeddings.extend(embs)
                log.info(f"  {filename}: {len(embs)} embedding segments")
            except Exception as e:
                log.warning(f"  Failed to process enrollment sample {filename}: {e}")

        # Clean up temp files
        for f in tmp_files:
            os.unlink(f)

        if not embeddings:
            self._send_error("No valid audio samples processed")
            return

        # If profile exists, merge with existing embeddings
        if speaker_name in _speaker_profiles:
            existing = _speaker_profiles[speaker_name]
            n_existing = 1
            n_new = len(embeddings)
            new_centroid = np.mean(embeddings, axis=0)
            merged = (existing * n_existing + new_centroid * n_new) / (n_existing + n_new)
            save_profile(speaker_name, merged)
            log.info(f"Updated profile '{speaker_name}' with {n_new} new samples")
        else:
            centroid = np.mean(embeddings, axis=0)
            save_profile(speaker_name, centroid)
            log.info(f"Created profile '{speaker_name}' from {len(embeddings)} samples")

        self._send_json({
            "message": f"Enrolled speaker '{speaker_name}' with {len(embeddings)} samples",
            "speaker_name": speaker_name,
            "samples_processed": len(embeddings),
        })

    def _handle_enroll_batch(self):
        """Batch enroll from a directory of audio files.
        Uses sliding window (10s window, 5s hop) to automatically slice
        long recordings into many embedding samples for robust profiles."""
        body = self._read_body()
        body_json = json.loads(body) if body else {}

        speaker_name = body_json.get("speaker_name", "").strip()
        directory = body_json.get("directory", "").strip()

        if not speaker_name:
            self._send_error("speaker_name is required")
            return
        if not directory or not Path(directory).exists():
            self._send_error(f"Directory not found: {directory}")
            return

        audio_extensions = {".wav", ".m4a", ".mp3", ".flac", ".ogg", ".aac", ".mp4"}
        audio_files = sorted([
            f for f in Path(directory).iterdir()
            if f.suffix.lower() in audio_extensions
        ])

        if not audio_files:
            self._send_error(f"No audio files found in {directory}")
            return

        log.info(f"Batch enrolling '{speaker_name}' from {len(audio_files)} files in {directory}")
        log.info(f"Using sliding window: {WINDOW_SECS}s window, {HOP_SECS}s hop")

        all_embeddings = []
        failed = []
        file_stats = []

        for audio_file in audio_files:
            try:
                embs = compute_embeddings_sliding_window(str(audio_file))
                all_embeddings.extend(embs)
                file_stats.append({"file": audio_file.name, "segments": len(embs)})
                log.info(f"  {audio_file.name}: {len(embs)} embedding segments")
            except Exception as e:
                log.warning(f"  Failed: {audio_file.name}: {e}")
                failed.append(str(audio_file.name))

        if not all_embeddings:
            self._send_error("No valid audio samples processed")
            return

        centroid = np.mean(all_embeddings, axis=0)
        save_profile(speaker_name, centroid)

        log.info(f"Enrolled '{speaker_name}': {len(all_embeddings)} total embeddings from {len(audio_files)} files")

        self._send_json({
            "message": f"Enrolled speaker '{speaker_name}' from {len(all_embeddings)} segments across {len(audio_files)} files",
            "speaker_name": speaker_name,
            "total_embedding_segments": len(all_embeddings),
            "files_processed": len(audio_files) - len(failed),
            "files_failed": failed,
            "file_details": file_stats,
        })


# ============================================================
# WebSocket Streaming Server
# ============================================================

def _save_pcm_to_wav(pcm_samples: np.ndarray, sample_rate: int = SAMPLE_RATE) -> str:
    """Save raw PCM samples (float32 or int16) to a temporary WAV file.
    Returns the path to the temp file (caller must clean up)."""
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp.close()

    # Convert to int16 if needed
    if pcm_samples.dtype == np.float32 or pcm_samples.dtype == np.float64:
        # Clip to [-1, 1] and scale to int16 range
        pcm_int16 = np.clip(pcm_samples, -1.0, 1.0)
        pcm_int16 = (pcm_int16 * 32767).astype(np.int16)
    elif pcm_samples.dtype == np.int16:
        pcm_int16 = pcm_samples
    else:
        pcm_int16 = pcm_samples.astype(np.int16)

    with wave.open(tmp.name, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(sample_rate)
        wf.writeframes(pcm_int16.tobytes())

    return tmp.name


def _transcribe_segment_sync(wav_path: str) -> dict:
    """Synchronous transcription of a WAV file. Runs in thread pool."""
    result = transcribe_audio(wav_path)
    return result


def _diarize_and_identify_sync(wav_path: str) -> list[dict]:
    """Synchronous diarization + speaker identification. Runs in thread pool.
    Returns list of diarization results with speaker identity."""
    diar_segments = diarize_audio(wav_path)

    if not diar_segments:
        return []

    results = []
    unique_speakers = set(s["speaker"] for s in diar_segments)

    for spk in unique_speakers:
        spk_segs = [s for s in diar_segments if s["speaker"] == spk]
        spk_segs.sort(key=lambda s: s["end"] - s["start"], reverse=True)

        embeddings = []
        for seg in spk_segs[:3]:
            if seg["end"] - seg["start"] < 0.5:
                continue
            try:
                seg_path = extract_segment_audio(wav_path, seg["start"], seg["end"])
                emb = compute_embedding(seg_path)
                embeddings.append(emb)
                os.unlink(seg_path)
            except Exception as e:
                log.warning(f"  WS slow path: failed embedding for {spk}: {e}")

        if embeddings:
            avg_emb = np.mean(embeddings, axis=0)
            name, confidence = identify_speaker(avg_emb)
        else:
            name, confidence = "unknown", 0.0

        results.append({
            "speaker_label": spk,
            "speaker": name,
            "confidence": round(confidence, 3),
        })

    return results


class StreamingSession:
    """Manages VAD state and audio buffering for one WebSocket connection."""

    def __init__(self):
        self.segment_counter = 0
        self.speech_buffer: list[np.ndarray] = []  # Accumulated speech frames
        self.silence_count = 0  # Consecutive non-speech frames
        self.is_speaking = False  # Current VAD state
        self.session_start_time = time.time()
        self.segment_start_sample = 0  # Sample offset of current segment start
        self.total_samples_received = 0  # Total samples received so far

    def next_segment_id(self) -> str:
        """Generate the next segment ID."""
        self.segment_counter += 1
        return f"seg_{self.segment_counter:03d}"

    def get_buffered_duration(self) -> float:
        """Get duration of buffered speech in seconds."""
        total_samples = sum(len(chunk) for chunk in self.speech_buffer)
        return total_samples / SAMPLE_RATE

    def get_buffered_pcm(self) -> np.ndarray:
        """Get all buffered speech as a single float32 array."""
        if not self.speech_buffer:
            return np.array([], dtype=np.float32)
        return np.concatenate(self.speech_buffer)

    def clear_buffer(self):
        """Clear the speech buffer and reset silence counter."""
        self.speech_buffer = []
        self.silence_count = 0


async def ws_handler(websocket):
    """Handle a single WebSocket connection for real-time streaming."""
    import torch

    client_addr = websocket.remote_address
    log.info(f"WS: New connection from {client_addr}")

    session = None
    vad_model = None
    loop = asyncio.get_event_loop()

    try:
        async for message in websocket:
            # --- Text frame: control messages ---
            if isinstance(message, str):
                try:
                    msg = json.loads(message)
                except json.JSONDecodeError:
                    await websocket.send(json.dumps({
                        "type": "error",
                        "message": "Invalid JSON in text frame",
                    }))
                    continue

                msg_type = msg.get("type", "")

                if msg_type == "start":
                    # Initialize a new streaming session
                    session = StreamingSession()
                    vad_model = get_vad_model()
                    vad_model.reset_states()
                    log.info(f"WS: Session started for {client_addr}")

                    await websocket.send(json.dumps({
                        "type": "status",
                        "message": "connected",
                        "profiles": list(_speaker_profiles.keys()),
                    }))

                elif msg_type == "stop":
                    if session is not None:
                        # Process any remaining buffered speech
                        if session.speech_buffer and session.get_buffered_duration() >= MIN_SEGMENT_DURATION:
                            await _process_speech_segment(
                                websocket, session, loop
                            )
                        log.info(f"WS: Session stopped for {client_addr} "
                                 f"({session.segment_counter} segments processed)")
                        session = None
                        vad_model = None
                    await websocket.send(json.dumps({
                        "type": "status",
                        "message": "stopped",
                    }))

                else:
                    await websocket.send(json.dumps({
                        "type": "error",
                        "message": f"Unknown control message type: {msg_type}",
                    }))
                continue

            # --- Binary frame: raw PCM audio data ---
            if not isinstance(message, (bytes, bytearray)):
                continue

            if session is None:
                # Ignore audio before session start
                continue

            # Decode raw Int16 little-endian PCM to float32
            pcm_int16 = np.frombuffer(message, dtype=np.int16)
            pcm_float = pcm_int16.astype(np.float32) / 32768.0
            session.total_samples_received += len(pcm_float)

            # Split incoming chunk into VAD_FRAME_SAMPLES-sized sub-frames
            offset = 0
            while offset + VAD_FRAME_SAMPLES <= len(pcm_float):
                frame = pcm_float[offset:offset + VAD_FRAME_SAMPLES]
                offset += VAD_FRAME_SAMPLES

                # Run VAD on this frame (lightweight, runs in async loop)
                frame_tensor = torch.FloatTensor(frame)
                speech_prob = vad_model(frame_tensor, SAMPLE_RATE).item()
                is_speech = speech_prob > VAD_THRESHOLD

                if is_speech:
                    if not session.is_speaking:
                        # Transition: silence -> speech
                        session.is_speaking = True
                        session.segment_start_sample = (
                            session.total_samples_received - len(pcm_float) + offset - VAD_FRAME_SAMPLES
                        )
                        await websocket.send(json.dumps({
                            "type": "vad",
                            "speech": True,
                        }))

                    session.speech_buffer.append(frame)
                    session.silence_count = 0

                    # Check max segment duration
                    if session.get_buffered_duration() >= MAX_SEGMENT_DURATION:
                        log.info(f"WS: Max segment duration reached, forcing segment end")
                        await _process_speech_segment(websocket, session, loop)
                        vad_model.reset_states()

                else:
                    if session.is_speaking:
                        # Still accumulate during brief silence gaps within speech
                        session.speech_buffer.append(frame)
                        session.silence_count += 1

                        if session.silence_count >= SILENCE_FRAMES:
                            # Transition: speech -> silence (end of utterance)
                            session.is_speaking = False
                            await websocket.send(json.dumps({
                                "type": "vad",
                                "speech": False,
                            }))

                            # Process the segment if long enough
                            if session.get_buffered_duration() >= MIN_SEGMENT_DURATION:
                                await _process_speech_segment(
                                    websocket, session, loop
                                )
                            else:
                                log.info(f"WS: Discarding short segment "
                                         f"({session.get_buffered_duration():.2f}s < {MIN_SEGMENT_DURATION}s)")
                                session.clear_buffer()

                            vad_model.reset_states()

            # Handle leftover samples that don't fill a complete VAD frame
            # (they'll be picked up when the next chunk arrives, since the
            #  client sends continuous 0.5s chunks)

    except Exception as e:
        # websockets library raises ConnectionClosed variants on disconnect
        error_name = type(e).__name__
        if "Closed" in error_name or "closed" in str(e).lower():
            log.info(f"WS: Connection closed for {client_addr}")
        else:
            log.exception(f"WS: Error in session for {client_addr}")
            try:
                await websocket.send(json.dumps({
                    "type": "error",
                    "message": str(e),
                }))
            except Exception:
                pass

    log.info(f"WS: Connection ended for {client_addr}")


async def _process_speech_segment(websocket, session: StreamingSession, loop):
    """Process a completed speech segment through the hybrid pipeline.

    Fast path: transcribe with whisper (send transcript immediately)
    Slow path: diarize + speaker ID (send speaker labels after)
    """
    pcm_data = session.get_buffered_pcm()
    segment_id = session.next_segment_id()
    segment_duration = len(pcm_data) / SAMPLE_RATE
    segment_start = session.segment_start_sample / SAMPLE_RATE

    log.info(f"WS: Processing segment {segment_id} "
             f"({segment_duration:.1f}s, start={segment_start:.1f}s)")

    # Save PCM to temp WAV for model processing
    wav_path = _save_pcm_to_wav(pcm_data)
    session.clear_buffer()

    # --- Fast path: transcription (run in thread pool) ---
    try:
        transcription = await loop.run_in_executor(
            _executor, _transcribe_segment_sync, wav_path
        )
        text = transcription.get("text", "").strip()

        if text:
            await websocket.send(json.dumps({
                "type": "transcript",
                "text": text,
                "segment_id": segment_id,
                "start": round(segment_start, 3),
                "end": round(segment_start + segment_duration, 3),
                "is_partial": False,
            }))
            log.info(f"WS: Fast path done for {segment_id}: \"{text[:80]}...\"" if len(text) > 80
                     else f"WS: Fast path done for {segment_id}: \"{text}\"")
        else:
            log.info(f"WS: Fast path returned empty text for {segment_id}")

    except Exception as e:
        log.exception(f"WS: Fast path error for {segment_id}")
        try:
            await websocket.send(json.dumps({
                "type": "error",
                "message": f"Transcription failed for {segment_id}: {e}",
            }))
        except Exception:
            pass

    # --- Slow path: diarization + speaker ID (background task) ---
    # Keep a reference to the wav_path so the background task can use it.
    # The background task is responsible for cleaning up the WAV file.
    asyncio.ensure_future(
        _slow_path_task(websocket, segment_id, wav_path, loop)
    )


async def _slow_path_task(websocket, segment_id: str, wav_path: str, loop):
    """Background task for diarization + speaker identification (slow path)."""
    try:
        results = await loop.run_in_executor(
            _executor, _diarize_and_identify_sync, wav_path
        )

        for result in results:
            try:
                await websocket.send(json.dumps({
                    "type": "speaker",
                    "segment_id": segment_id,
                    "speaker": result["speaker"],
                    "speaker_label": result["speaker_label"],
                    "confidence": result["confidence"],
                }))
            except Exception:
                break  # Connection likely closed

        if results:
            speakers = ", ".join(f"{r['speaker']}({r['confidence']:.2f})" for r in results)
            log.info(f"WS: Slow path done for {segment_id}: {speakers}")
        else:
            log.info(f"WS: Slow path returned no speakers for {segment_id}")

    except Exception as e:
        log.exception(f"WS: Slow path error for {segment_id}")
        try:
            await websocket.send(json.dumps({
                "type": "error",
                "message": f"Diarization failed for {segment_id}: {e}",
            }))
        except Exception:
            pass

    finally:
        # Clean up temp WAV file
        try:
            os.unlink(wav_path)
        except OSError:
            pass


# ============================================================
# Main
# ============================================================

def run_http_server():
    """Run the HTTP server in a separate thread (blocking)."""
    server = HTTPServer((HOST, PORT), DiarizationHandler)
    log.info(f"HTTP server listening on {HOST}:{PORT}")
    server.serve_forever()


async def run_ws_server():
    """Run the WebSocket server using asyncio (async main loop)."""
    import websockets

    server = await websockets.serve(
        ws_handler,
        HOST,
        WS_PORT,
        max_size=2 ** 20,  # 1 MB max frame size (plenty for 0.5s audio chunks)
        ping_interval=30,
        ping_timeout=10,
    )
    log.info(f"WebSocket server listening on {HOST}:{WS_PORT}")
    await server.wait_closed()


async def async_main():
    """Main async entry point: starts HTTP thread + WebSocket server."""
    # Start HTTP server in a daemon thread
    http_thread = threading.Thread(target=run_http_server, daemon=True)
    http_thread.start()

    # Run WebSocket server in the async event loop
    await run_ws_server()


def main():
    log.info("=" * 60)
    log.info("Speaker Diarization & Transcription Server")
    log.info(f"HTTP  server: {HOST}:{PORT}")
    log.info(f"WebSocket server: {HOST}:{WS_PORT}")
    log.info(f"Whisper model: {WHISPER_MODEL} (MLX/Metal)")
    log.info(f"Diarization: pyannote/speaker-diarization-3.1 (MPS)")
    log.info(f"Speaker ID: speechbrain/spkrec-ecapa-voxceleb")
    log.info(f"VAD: Silero VAD (streaming mode)")
    log.info(f"Enrollment dir: {ENROLLMENT_DIR}")
    log.info(f"Profiles dir: {PROFILES_DIR}")
    log.info("=" * 60)

    # Load existing speaker profiles
    load_profiles()

    # Non-blocking HuggingFace auth check
    def _check_hf():
        try:
            from huggingface_hub import HfApi
            user = HfApi().whoami()
            log.info(f"HuggingFace authenticated as: {user.get('name', 'unknown')}")
        except Exception:
            log.warning("HuggingFace not authenticated! Run: huggingface-cli login")
    threading.Thread(target=_check_hf, daemon=True).start()

    try:
        asyncio.run(async_main())
    except KeyboardInterrupt:
        log.info("Shutting down...")


if __name__ == "__main__":
    main()
