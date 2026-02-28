#!/usr/bin/env python3
"""
Speaker Diarization & Transcription Server

A standalone HTTP server that processes audio and returns:
- Transcription (via mlx-whisper, Apple Silicon optimized)
- Speaker diarization (via pyannote.audio, MPS accelerated)
- Speaker identification (via SpeechBrain ECAPA-TDNN embeddings)

Endpoints:
  POST /process       — Full pipeline: transcribe + diarize + identify speakers
  POST /transcribe    — Transcription only (mlx-whisper)
  POST /diarize       — Diarization only (pyannote)
  POST /enroll        — Enroll a speaker voice profile
  POST /enroll-batch  — Batch enroll from directory of audio files
  GET  /profiles      — List enrolled speaker profiles
  DELETE /profiles/<name> — Remove a speaker profile
  GET  /health        — Health check

Listens on 0.0.0.0:18793
"""

import json
import os
import sys
import time
import tempfile
import logging
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
_speaker_profiles: dict[str, np.ndarray] = {}  # name -> centroid embedding

# Paths
DATA_DIR = Path("/Users/zwang/projects/ryanhub/data")
ENROLLMENT_DIR = DATA_DIR / "voice-enrollment"
PROFILES_DIR = DATA_DIR / "voice-profiles"
PROFILES_DIR.mkdir(parents=True, exist_ok=True)

# Config
HOST = "0.0.0.0"
PORT = 18793
WHISPER_MODEL = "mlx-community/whisper-large-v3-mlx"
SIMILARITY_THRESHOLD = 0.25  # Cosine similarity threshold for speaker ID
SAMPLE_RATE = 16000

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
            use_auth_token=True,
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


def _load_audio(audio_path: str):
    """Load audio, resample to 16kHz mono. Returns (waveform, sample_rate)."""
    import torch
    import torchaudio

    waveform, sr = torchaudio.load(audio_path)

    if sr != SAMPLE_RATE:
        resampler = torchaudio.transforms.Resample(sr, SAMPLE_RATE)
        waveform = resampler(waveform)

    if waveform.shape[0] > 1:
        waveform = waveform.mean(dim=0, keepdim=True)

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

    diarization = pipeline(audio_path)

    segments = []
    for turn, _, speaker in diarization.itertracks(yield_label=True):
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
# Main
# ============================================================

def main():
    log.info("=" * 60)
    log.info("Speaker Diarization & Transcription Server")
    log.info(f"Listening on {HOST}:{PORT}")
    log.info(f"Whisper model: {WHISPER_MODEL} (MLX/Metal)")
    log.info(f"Diarization: pyannote/speaker-diarization-3.1 (MPS)")
    log.info(f"Speaker ID: speechbrain/spkrec-ecapa-voxceleb")
    log.info(f"Enrollment dir: {ENROLLMENT_DIR}")
    log.info(f"Profiles dir: {PROFILES_DIR}")
    log.info("=" * 60)

    # Load existing speaker profiles
    load_profiles()

    # Pre-check HuggingFace auth
    try:
        from huggingface_hub import HfApi
        api = HfApi()
        user = api.whoami()
        log.info(f"HuggingFace authenticated as: {user.get('name', 'unknown')}")
    except Exception:
        log.warning("HuggingFace not authenticated! Run: huggingface-cli login")
        log.warning("Required for pyannote model download.")

    server = HTTPServer((HOST, PORT), DiarizationHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Shutting down...")
        server.server_close()


if __name__ == "__main__":
    main()
