#!/usr/bin/env python3
"""
RyanHub Bridge Server

A lightweight HTTP server that bridges the iOS app to iMac-hosted services
and data. Listens on 0.0.0.0:18790.

Endpoints:
  POST /analyze — Analyze food from text and/or image (via claude CLI)
  POST /analyze-activity — Analyze physical activity from text (via claude CLI)
  GET  /health — Health check

  Parking data:
  GET  /parking/skip-dates — Read skip dates (text)
  POST /parking/skip-dates — Write skip dates (JSON body: {"dates": [...]})
  GET  /parking/last-status — Read last purchase status (JSON)
  GET  /parking/purchase-history — Read purchase history (JSON)

  Health data (server-side storage):
  GET  /health-data/weight — Read weight entries (JSON array)
  POST /health-data/weight — Write weight entries (JSON array)
  GET  /health-data/food — Read food entries (JSON array)
  POST /health-data/food — Write food entries (JSON array)
  GET  /health-data/activity — Read activity entries (JSON array)
  POST /health-data/activity — Write activity entries (JSON array)

  Chat data (server-side storage):
  GET    /chat/messages — Read chat messages (JSON array)
  POST   /chat/messages — Write chat messages (JSON array)
  DELETE /chat/messages — Clear chat messages

  POPO (Proactive Personal Observer) data:
  GET/POST /popo/sensing — Passive sensing events (motion, steps, HR, etc.)
  GET/POST /popo/narrations — Voice diary entries with transcript + mood
  GET/POST /popo/nudges — Proactive nudge records from Facai
  GET/POST /popo/daily-summary — Daily behavior summaries
  POST     /popo/audio — Upload audio file (binary)
  GET      /popo/audio/<filename> — Retrieve audio file
  POST     /popo/narrations/analyze — Transcribe (Whisper) + affective analysis (local emotion model)
  POST     /popo/location/enrich — Reverse geocode + semantic place enrichment
  POST     /popo/location/learn-place — Teach the system a named place
  All GET endpoints support ?date=YYYY-MM-DD filtering.

Usage:
  python3 scripts/bridge-server.py

The server requires `claude` CLI for analysis endpoints.
"""

import http.server
import json
import subprocess
import sys
import tempfile
import base64
import os
import shutil
import uuid
import threading
from datetime import datetime
from typing import Optional, Dict, Any
from urllib.parse import urlparse, parse_qs

PORT = 18790
HOST = "0.0.0.0"

# Locate the claude CLI binary
CLAUDE_PATH = shutil.which("claude") or os.path.expanduser("~/.local/bin/claude")

# ---------------------------------------------------------------------------
# Parking data (external files managed by parkmobile-auto)
# ---------------------------------------------------------------------------

PARKING_DIR = "/Users/zwang/projects/parkmobile-auto"
PARKING_FILES = {
    "/parking/skip-dates": os.path.join(PARKING_DIR, "skip-dates.txt"),
    "/parking/last-status": os.path.join(PARKING_DIR, "last-status.json"),
    "/parking/purchase-history": os.path.join(PARKING_DIR, "purchase-history.json"),
}

# ---------------------------------------------------------------------------
# Server-side data storage (health + chat)
# ---------------------------------------------------------------------------

BRIDGE_DATA_DIR = os.path.expanduser("~/.ryanhub-data")
os.makedirs(BRIDGE_DATA_DIR, exist_ok=True)

DATA_FILES = {
    "/health-data/weight": os.path.join(BRIDGE_DATA_DIR, "health_weight.json"),
    "/health-data/food": os.path.join(BRIDGE_DATA_DIR, "health_food.json"),
    "/health-data/activity": os.path.join(BRIDGE_DATA_DIR, "health_activity.json"),
    "/chat/messages": os.path.join(BRIDGE_DATA_DIR, "chat_messages.json"),
    "/popo/sensing": os.path.join(BRIDGE_DATA_DIR, "popo_sensing.json"),
    "/popo/narrations": os.path.join(BRIDGE_DATA_DIR, "popo_narrations.json"),
    "/popo/nudges": os.path.join(BRIDGE_DATA_DIR, "popo_nudges.json"),
    "/popo/daily-summary": os.path.join(BRIDGE_DATA_DIR, "popo_summaries.json"),
}

# POPO audio storage directory
POPO_AUDIO_DIR = os.path.join(BRIDGE_DATA_DIR, "popo_audio")
os.makedirs(POPO_AUDIO_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Local Whisper integration for narration transcription
# ---------------------------------------------------------------------------

WHISPER_AVAILABLE = False
_whisper_model = None

try:
    import whisper
    WHISPER_AVAILABLE = True
    print("Local Whisper available for narration transcription.")
except ImportError:
    print("Warning: openai-whisper not installed. Narration transcription will be skipped.",
          file=sys.stderr)
    print("  Install with: pip install openai-whisper", file=sys.stderr)


def get_whisper_model():
    """Lazily load the Whisper model (large-v3-turbo for best quality)."""
    global _whisper_model
    if _whisper_model is None:
        print("[Whisper] Loading model large-v3-turbo (first call, may take a moment)...")
        _whisper_model = whisper.load_model("large-v3-turbo")
        print("[Whisper] Model loaded successfully.")
    return _whisper_model

# ---------------------------------------------------------------------------
# Local HuggingFace emotion model for affect analysis
# ---------------------------------------------------------------------------

SENTIMENT_AVAILABLE = False
_sentiment_pipeline = None

try:
    from transformers import pipeline as hf_pipeline
    SENTIMENT_AVAILABLE = True
    print("HuggingFace transformers available for local affect analysis.")
except ImportError:
    print("Warning: transformers not installed. Affect analysis will be skipped.",
          file=sys.stderr)
    print("  Install with: pip install transformers torch", file=sys.stderr)


def get_sentiment_pipeline():
    """Lazily load the emotion classification model."""
    global _sentiment_pipeline
    if _sentiment_pipeline is None:
        print("[Affect] Loading emotion model (first call, may take a moment)...")
        _sentiment_pipeline = hf_pipeline(
            "text-classification",
            model="j-hartmann/emotion-english-distilroberta-base",
            top_k=None,  # return all emotion scores
            device="mps" if __import__('torch').backends.mps.is_available() else "cpu"
        )
        print("[Affect] Model loaded successfully.")
    return _sentiment_pipeline


def _emotion_to_valence(emotion):
    """Map emotion label to valence (-1.0 to 1.0)."""
    mapping = {
        'joy': 0.8, 'surprise': 0.3, 'neutral': 0.0,
        'sadness': -0.6, 'anger': -0.7, 'disgust': -0.8, 'fear': -0.5
    }
    return mapping.get(emotion, 0.0)


def _emotion_to_arousal(emotion):
    """Map emotion label to arousal (0.0 to 1.0)."""
    mapping = {
        'joy': 0.6, 'surprise': 0.8, 'neutral': 0.2,
        'sadness': 0.3, 'anger': 0.9, 'disgust': 0.5, 'fear': 0.8
    }
    return mapping.get(emotion, 0.5)


def _emotion_to_mood(emotion):
    """Map emotion label to mood score (1-10 scale)."""
    mapping = {
        'joy': 8, 'surprise': 6, 'neutral': 5,
        'sadness': 3, 'anger': 2, 'disgust': 2, 'fear': 3
    }
    return mapping.get(emotion, 5)


def _emotion_to_energy(emotion):
    """Map emotion label to energy score (1-10 scale)."""
    mapping = {
        'joy': 7, 'surprise': 8, 'neutral': 5,
        'sadness': 3, 'anger': 8, 'disgust': 4, 'fear': 7
    }
    return mapping.get(emotion, 5)


def _emotion_to_stress(emotion):
    """Map emotion label to stress score (1-10 scale)."""
    mapping = {
        'joy': 2, 'surprise': 5, 'neutral': 3,
        'sadness': 6, 'anger': 8, 'disgust': 6, 'fear': 8
    }
    return mapping.get(emotion, 5)


def transcribe_audio(audio_path):
    # type: (str) -> Optional[str]
    """Transcribe an audio file using local Whisper model.
    Returns the transcript text, or None if unavailable."""
    if not WHISPER_AVAILABLE:
        return None
    try:
        model = get_whisper_model()
        result = model.transcribe(str(audio_path))
        text = result["text"].strip()
        if text:
            print(f"[Whisper] Transcribed {os.path.basename(audio_path)}: {text[:80]}...")
        return text if text else None
    except Exception as e:
        print(f"[Whisper] Local transcription failed: {e}", file=sys.stderr)
        return None


def analyze_affect(text):
    # type: (str) -> Optional[Dict[str, Any]]
    """Analyze emotional affect of text using local emotion model.
    Returns a dict matching the iOS AffectAnalysis schema, or None."""
    if not SENTIMENT_AVAILABLE or not text or len(text.strip()) < 10:
        return None
    try:
        pipe = get_sentiment_pipeline()
        # Model returns list of dicts: [{"label": "joy", "score": 0.95}, ...]
        results = pipe(text[:512])[0]  # truncate to model max, get first result

        # Sort by score descending
        results.sort(key=lambda x: x['score'], reverse=True)

        primary = results[0]
        secondary = results[1] if len(results) > 1 else None

        # Build response matching iOS AffectAnalysis CodingKeys (snake_case)
        analysis = {
            "primary_emotion": primary['label'],
            "confidence": round(primary['score'], 3),
            "valence": _emotion_to_valence(primary['label']),
            "arousal": _emotion_to_arousal(primary['label']),
            "mood": _emotion_to_mood(primary['label']),
            "energy": _emotion_to_energy(primary['label']),
            "stress": _emotion_to_stress(primary['label']),
            "emotions": {r['label']: round(r['score'], 3) for r in results},
            "brief_summary": f"Detected {primary['label']} ({primary['score']:.0%} confidence)"
        }

        if secondary and secondary['score'] > 0.1:
            analysis["secondary_emotion"] = secondary['label']

        print(f"[Affect] {primary['label']} ({primary['score']:.2f}) for: {text[:60]}...")
        return analysis

    except Exception as e:
        print(f"[Affect] Analysis failed: {e}", file=sys.stderr)
        return None


def run_narration_analysis(audio_path, narration_id=None):
    # type: (str, Optional[str]) -> Dict[str, Any]
    """Run the full transcription + affect analysis pipeline.
    Returns a dict with 'transcript', 'affect', and 'narration_id'."""
    result = {
        "narration_id": narration_id,
        "transcript": None,
        "affect": None,
        "status": "skipped"
    }  # type: Dict[str, Any]

    if not WHISPER_AVAILABLE:
        result["status"] = "whisper_unavailable"
        return result

    # Step 1: Transcribe
    transcript = transcribe_audio(audio_path)
    if transcript:
        result["transcript"] = transcript
        result["status"] = "transcribed"

        # Step 2: Affect analysis
        affect = analyze_affect(transcript)
        if affect:
            result["affect"] = affect
            result["status"] = "analyzed"

    return result


def update_narration_with_analysis(narration_id, analysis_result):
    # type: (str, Dict[str, Any]) -> None
    """Update the stored narration entry with transcript and affect data."""
    narrations_file = DATA_FILES.get("/popo/narrations")
    if not narrations_file or not os.path.exists(narrations_file):
        return

    try:
        with open(narrations_file, "r") as f:
            content = f.read()
        narrations = json.loads(content) if content.strip() else []
    except (json.JSONDecodeError, IOError):
        return

    updated = False
    for narration in narrations:
        if isinstance(narration, dict) and narration.get("id") == narration_id:
            if analysis_result.get("transcript"):
                narration["transcript"] = analysis_result["transcript"]
            if analysis_result.get("affect"):
                narration["affectAnalysis"] = analysis_result["affect"]
                # Also set legacy extractedMood field
                primary = analysis_result["affect"].get("primary_emotion")
                if primary:
                    narration["extractedMood"] = primary
            updated = True
            break

    if updated:
        try:
            with open(narrations_file, "w") as f:
                json.dump(narrations, f, ensure_ascii=False)
        except IOError as e:
            print(f"[Narration] Failed to update narration file: {e}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Geopy integration for semantic location enrichment
# ---------------------------------------------------------------------------

GEOPY_AVAILABLE = False
_geocoder = None

try:
    from geopy.geocoders import Nominatim
    from geopy.distance import geodesic
    _geocoder = Nominatim(user_agent="ryanhub-popo/1.0")
    GEOPY_AVAILABLE = True
    print("Geopy available for location enrichment.")
except ImportError:
    print("Warning: geopy not installed. Location enrichment will be unavailable.",
          file=sys.stderr)
    print("  Install with: pip install geopy", file=sys.stderr)

# Known places file for home/work detection
KNOWN_PLACES_FILE = os.path.join(BRIDGE_DATA_DIR, "popo", "known_places.json")
os.makedirs(os.path.join(BRIDGE_DATA_DIR, "popo"), exist_ok=True)


def check_known_places(lat, lng):
    """Check if coordinates match a known place (within 200m).
    Returns the place label string, or None."""
    if not GEOPY_AVAILABLE:
        return None
    if not os.path.exists(KNOWN_PLACES_FILE):
        return None
    try:
        with open(KNOWN_PLACES_FILE, "r") as f:
            content = f.read()
        places = json.loads(content) if content.strip() else []
    except (json.JSONDecodeError, IOError):
        return None

    for place in places:
        if not isinstance(place, dict):
            continue
        plat = place.get("lat")
        plng = place.get("lng")
        if plat is None or plng is None:
            continue
        dist = geodesic((lat, lng), (plat, plng)).meters
        if dist < 200:
            return place.get("label")
    return None


def enrich_location_data(lat, lng, timestamp_str=None):
    """Enrich a lat/lng with semantic place info.
    Returns a dict with address, place_type, semantic_label, etc."""
    result = {}

    # 1. Reverse geocode via Nominatim
    if GEOPY_AVAILABLE and _geocoder:
        try:
            location = _geocoder.reverse(
                f"{lat}, {lng}", exactly_one=True, language="en"
            )
            if location:
                addr = location.raw.get("address", {})
                result["address"] = location.address
                result["place_type"] = (
                    addr.get("amenity")
                    or addr.get("shop")
                    or addr.get("building")
                    or addr.get("leisure")
                    or ""
                )
                result["neighborhood"] = (
                    addr.get("neighbourhood") or addr.get("suburb") or ""
                )
                result["city"] = addr.get("city") or addr.get("town") or ""
        except Exception as e:
            print(f"[Location] Geocode failed: {e}")

    # 2. Check against known places (home/work clusters)
    known = check_known_places(lat, lng)
    if known:
        result["semantic_label"] = known

    # 3. Time-based heuristic
    if timestamp_str:
        try:
            hour = datetime.fromisoformat(
                timestamp_str.replace("Z", "+00:00")
            ).hour
            if not known:
                if 0 <= hour <= 6:
                    result["semantic_hint"] = "likely_home"
                elif 8 <= hour <= 17:
                    result["semantic_hint"] = "likely_work"
        except (ValueError, AttributeError):
            pass

    return result


# ---------------------------------------------------------------------------
# Claude CLI analysis prompts
# ---------------------------------------------------------------------------

ACTIVITY_ANALYSIS_PROMPT_TEMPLATE = """\
You are a fitness expert. Analyze this physical activity description and return a JSON object with estimates.
The user might describe activities in any language (Chinese, English, etc). Always return English output.
Be practical and estimate realistic calorie burn based on typical body weight (~85 kg) and intensity.

Activity description: "{description}"

Return ONLY a valid JSON object in this exact format, no other text or markdown:
{{
  "type": "Strength Training",
  "caloriesBurned": 250,
  "duration": 45,
  "summary": "Upper body strength session with lat pulldowns and bench press",
  "exercises": [
    {{"name": "Lat Pulldown", "sets": 4, "reps": 12, "weight": "70 lb", "caloriesBurned": 75}},
    {{"name": "Bench Press", "sets": 3, "reps": 8, "weight": "135 lb", "caloriesBurned": 85}}
  ]
}}

Rules:
- type: concise activity category in English (e.g., "Strength Training", "Running", "HIIT", "Yoga", "Swimming", "Cycling", "Walking").
- caloriesBurned: total estimated kcal burned across all exercises.
- duration: estimated total duration in minutes, or null if unclear.
- summary: brief one-line English description of the entire session.
- exercises: array of individual exercises. For strength exercises include sets, reps, weight. For cardio exercises include duration instead. Each exercise gets an estimated caloriesBurned. If the description is a single simple activity (e.g., "ran 30 minutes"), use a single-item exercises array with duration.
- weight should include units as given (lb, kg, etc). If not specified, omit weight.
- Omit fields that don't apply (e.g., no "sets" for cardio, no "duration" for strength).
"""

FOOD_ANALYSIS_PROMPT_TEMPLATE = """\
You are a nutritionist. Analyze this meal/food and return a JSON object with nutritional estimates.
The user might describe food in any language (Chinese, English, etc).
Be practical and estimate realistic calorie counts based on typical portion sizes.

{description}

Return ONLY a valid JSON object in this exact format, no other text or markdown:
{{
  "items": [
    {{
      "name": "food item name in English",
      "calories": 350,
      "protein": 25,
      "carbs": 30,
      "fat": 12,
      "portion": "1 bowl"
    }}
  ],
  "totalCalories": 350,
  "totalProtein": 25,
  "totalCarbs": 30,
  "totalFat": 12,
  "mealType": "lunch",
  "summary": "A brief one-line summary of the meal"
}}

mealType must be one of: breakfast, lunch, dinner, snack.
All nutritional values are in grams except calories (kcal).
"""


# ---------------------------------------------------------------------------
# Claude CLI helpers
# ---------------------------------------------------------------------------

def build_prompt(text, has_image):
    """Build the analysis prompt from text and/or image context."""
    if text and has_image:
        description = (
            f'The user provided this description: "{text}"\n'
            "They also attached a photo of the food. "
            "Use both the image and description to analyze the meal."
        )
    elif has_image:
        description = (
            "The user provided a photo of a meal. "
            "Identify all visible food items and estimate their nutritional content."
        )
    elif text:
        description = f'Food description: "{text}"'
    else:
        return ""

    return FOOD_ANALYSIS_PROMPT_TEMPLATE.format(description=description)


def run_claude_text(prompt: str) -> str:
    """Run claude CLI with a text-only prompt."""
    env = os.environ.copy()
    env.pop("CLAUDE_CODE", None)
    env.pop("CLAUDECODE", None)

    result = subprocess.run(
        [CLAUDE_PATH, "-p", prompt, "--output-format", "json", "--model", "haiku"],
        capture_output=True,
        text=True,
        timeout=60,
        env=env,
    )

    if result.returncode != 0:
        raise RuntimeError(f"claude CLI error: {result.stderr.strip()}")

    return result.stdout


def run_claude_with_image(prompt: str, image_path: str) -> str:
    """Run claude CLI with a prompt that references an image file."""
    env = os.environ.copy()
    env.pop("CLAUDE_CODE", None)
    env.pop("CLAUDECODE", None)

    full_prompt = (
        f"Read the image file at '{image_path}' and analyze it.\n\n{prompt}"
    )

    result = subprocess.run(
        [
            CLAUDE_PATH,
            "-p",
            full_prompt,
            "--output-format",
            "json",
            "--model",
            "haiku",
            "--allowedTools",
            "Read",
        ],
        capture_output=True,
        text=True,
        timeout=90,
        env=env,
    )

    if result.returncode != 0:
        raise RuntimeError(f"claude CLI error: {result.stderr.strip()}")

    return result.stdout


def extract_result(claude_output: str) -> dict:
    """Extract the analysis JSON from claude CLI output."""
    try:
        envelope = json.loads(claude_output)
    except json.JSONDecodeError:
        return parse_food_json(claude_output)

    if isinstance(envelope, dict):
        content = envelope.get("result", "")
        if isinstance(content, str):
            return parse_food_json(content)
        elif isinstance(content, dict):
            return content

    raise ValueError("Unexpected claude output format")


def parse_food_json(text: str) -> dict:
    """Parse food analysis JSON from text, handling markdown code blocks."""
    text = text.strip()
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    text = text.strip()
    return json.loads(text)


# ---------------------------------------------------------------------------
# HTTP Handler
# ---------------------------------------------------------------------------

class BridgeHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler for all RyanHub bridge endpoints."""

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        if path == "/health":
            self._send_json(200, {"status": "ok"})
        elif path in PARKING_FILES:
            self._serve_parking_file(path)
        elif path.startswith("/popo/audio/"):
            self._serve_audio_file(path)
        elif path in DATA_FILES and path.startswith("/popo/"):
            query = parse_qs(parsed.query)
            date_filter = query.get("date", [None])[0]
            self._serve_popo_data(path, date_filter)
        elif path in DATA_FILES:
            self._serve_data_file(path)
        else:
            self._send_json(404, {"error": "Not found"})

    def do_POST(self):
        path = urlparse(self.path).path

        # Parking skip-dates write
        if path == "/parking/skip-dates":
            self._write_parking_skip_dates()
            return

        # POPO audio upload
        if path == "/popo/audio":
            self._handle_audio_upload()
            return

        # POPO narration analysis (transcription + affect)
        if path == "/popo/narrations/analyze":
            self._handle_narration_analysis()
            return

        # POPO location enrichment
        if path == "/popo/location/enrich":
            self._handle_location_enrich()
            return

        # POPO learn a named place
        if path == "/popo/location/learn-place":
            self._handle_learn_place()
            return

        # Server-side data write (health + chat + popo)
        if path in DATA_FILES:
            self._write_data_file(path)
            return

        # Analysis endpoints
        if path not in ("/analyze", "/analyze-activity"):
            self._send_json(404, {"error": "Not found"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid request body: {e}"})
            return

        if path == "/analyze-activity":
            self._handle_activity_analysis(data)
        else:
            self._handle_food_analysis(data)

    def do_DELETE(self):
        path = urlparse(self.path).path
        if path in DATA_FILES:
            filepath = DATA_FILES[path]
            if os.path.exists(filepath):
                os.remove(filepath)
            self._send_json(200, {"ok": True})
        else:
            self._send_json(404, {"error": "Not found"})

    # -----------------------------------------------------------------------
    # Data file endpoints (health + chat)
    # -----------------------------------------------------------------------

    def _serve_data_file(self, path):
        """Serve a JSON data file. Returns [] if file doesn't exist."""
        filepath = DATA_FILES[path]
        if not os.path.exists(filepath):
            self._send_json(200, [])
            return
        try:
            with open(filepath, "r") as f:
                content = f.read()
            data = json.loads(content) if content.strip() else []
            self._send_json(200, data)
        except (json.JSONDecodeError, IOError):
            self._send_json(200, [])

    def _write_data_file(self, path):
        """Write JSON data to a file. Merges by 'id' field so multi-device
        sync works correctly (no data loss from concurrent writes)."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            incoming = json.loads(body) if body else []
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid body: {e}"})
            return

        filepath = DATA_FILES[path]

        # Load existing data for merge
        existing = []
        if os.path.exists(filepath):
            try:
                with open(filepath, "r") as f:
                    content = f.read()
                existing = json.loads(content) if content.strip() else []
            except (json.JSONDecodeError, IOError):
                existing = []

        # Merge by 'id' — incoming entries override existing ones with same id,
        # and existing entries not in incoming are preserved.
        if isinstance(incoming, list) and isinstance(existing, list):
            merged = {}
            for item in existing:
                if isinstance(item, dict) and "id" in item:
                    merged[item["id"]] = item
            for item in incoming:
                if isinstance(item, dict) and "id" in item:
                    merged[item["id"]] = item
            data = list(merged.values())
        else:
            data = incoming

        try:
            with open(filepath, "w") as f:
                json.dump(data, f, ensure_ascii=False)
            self._send_json(200, {"ok": True, "count": len(data) if isinstance(data, list) else 1})
        except IOError as e:
            self._send_json(500, {"error": f"Failed to write: {e}"})

    # -----------------------------------------------------------------------
    # POPO data endpoints
    # -----------------------------------------------------------------------

    def _serve_popo_data(self, path, date_filter=None):
        """Serve a POPO JSON data file, optionally filtered by date.
        date_filter should be 'YYYY-MM-DD' or None for all data."""
        filepath = DATA_FILES[path]
        if not os.path.exists(filepath):
            self._send_json(200, [])
            return
        try:
            with open(filepath, "r") as f:
                content = f.read()
            data = json.loads(content) if content.strip() else []
        except (json.JSONDecodeError, IOError):
            self._send_json(200, [])
            return

        if date_filter and isinstance(data, list):
            # For daily-summary, match on the 'date' field directly
            if path == "/popo/daily-summary":
                data = [
                    item for item in data
                    if isinstance(item, dict) and item.get("date", "") == date_filter
                ]
            else:
                # For other POPO data, match date portion of 'timestamp'
                data = [
                    item for item in data
                    if isinstance(item, dict)
                    and item.get("timestamp", "")[:10] == date_filter
                ]

        self._send_json(200, data)

    def _handle_audio_upload(self):
        """Accept a binary audio file upload and save to POPO audio directory.
        Expects Content-Type with audio/* or application/octet-stream.
        The filename can be provided via X-Filename header, or a UUID is generated."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length == 0:
                self._send_json(400, {"error": "Empty body"})
                return

            body = self.rfile.read(content_length)

            # Determine filename
            filename = self.headers.get("X-Filename")
            if not filename:
                # Guess extension from content type
                content_type = self.headers.get("Content-Type", "")
                ext = ".m4a"  # default
                if "wav" in content_type:
                    ext = ".wav"
                elif "mp3" in content_type or "mpeg" in content_type:
                    ext = ".mp3"
                elif "caf" in content_type:
                    ext = ".caf"
                filename = f"{uuid.uuid4()}{ext}"

            # Sanitize filename (prevent directory traversal)
            filename = os.path.basename(filename)
            filepath = os.path.join(POPO_AUDIO_DIR, filename)

            with open(filepath, "wb") as f:
                f.write(body)

            response_data = {
                "ok": True,
                "filename": filename,
                "size": len(body),
            }

            # If a narration ID was provided, trigger background analysis
            # (needs local Whisper for transcription; Claude for affect analysis is optional)
            narration_id = self.headers.get("X-Narration-Id")
            if narration_id and WHISPER_AVAILABLE:
                response_data["analysis_queued"] = True

                def _bg_analyze():
                    try:
                        result = run_narration_analysis(filepath, narration_id)
                        if result.get("status") in ("transcribed", "analyzed"):
                            update_narration_with_analysis(narration_id, result)
                            print("[Narration] Background analysis complete for %s" % filename)
                    except Exception as e:
                        print("[Narration] Background analysis failed: %s" % e,
                              file=sys.stderr)

                bg_thread = threading.Thread(target=_bg_analyze, daemon=True)
                bg_thread.start()

            self._send_json(200, response_data)
        except IOError as e:
            self._send_json(500, {"error": "Failed to save audio: %s" % e})

    def _serve_audio_file(self, path):
        """Serve a stored audio file from POPO audio directory.
        Path format: /popo/audio/<filename>"""
        filename = path.split("/popo/audio/", 1)[-1]
        if not filename:
            self._send_json(400, {"error": "No filename specified"})
            return

        # Sanitize to prevent directory traversal
        filename = os.path.basename(filename)
        filepath = os.path.join(POPO_AUDIO_DIR, filename)

        if not os.path.exists(filepath):
            self._send_json(404, {"error": "Audio file not found"})
            return

        # Determine content type from extension
        ext = os.path.splitext(filename)[1].lower()
        content_types = {
            ".m4a": "audio/mp4",
            ".mp3": "audio/mpeg",
            ".wav": "audio/wav",
            ".caf": "audio/x-caf",
            ".aac": "audio/aac",
        }
        content_type = content_types.get(ext, "application/octet-stream")

        try:
            with open(filepath, "rb") as f:
                data = f.read()
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(data)
        except IOError as e:
            self._send_json(500, {"error": f"Failed to read audio: {e}"})

    # -----------------------------------------------------------------------
    # Narration analysis endpoint
    # -----------------------------------------------------------------------

    def _handle_narration_analysis(self):
        """Transcribe and analyze emotional affect from a narration audio file.
        Expects JSON body with 'filename' and optionally 'narration_id'."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": "Invalid request body: %s" % e})
            return

        filename = data.get("filename")
        narration_id = data.get("narration_id")

        if not filename:
            self._send_json(400, {"error": "Missing 'filename' in request body"})
            return

        # Sanitize and locate the audio file
        filename = os.path.basename(filename)
        audio_path = os.path.join(POPO_AUDIO_DIR, filename)

        if not os.path.exists(audio_path):
            self._send_json(404, {"error": "Audio file not found: %s" % filename})
            return

        if not WHISPER_AVAILABLE:
            self._send_json(503, {
                "error": "Local Whisper not available (openai-whisper package not installed)",
                "transcript": None,
                "affect": None,
                "status": "whisper_unavailable"
            })
            return

        # Run the analysis pipeline
        try:
            result = run_narration_analysis(audio_path, narration_id)

            # If we have a narration_id, update the stored narration entry
            if narration_id and result.get("status") in ("transcribed", "analyzed"):
                update_narration_with_analysis(narration_id, result)

            self._send_json(200, result)
        except Exception as e:
            self._send_json(500, {"error": "Analysis failed: %s" % e})

    # -----------------------------------------------------------------------
    # Location enrichment endpoints
    # -----------------------------------------------------------------------

    def _handle_location_enrich(self):
        """Enrich a lat/lng with semantic place info (reverse geocode + known places)."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": "Invalid request body: %s" % e})
            return

        lat = data.get("latitude")
        lng = data.get("longitude")
        timestamp = data.get("timestamp")

        if lat is None or lng is None:
            self._send_json(400, {"error": "latitude and longitude required"})
            return

        try:
            lat = float(lat)
            lng = float(lng)
        except (TypeError, ValueError):
            self._send_json(400, {"error": "latitude and longitude must be numeric"})
            return

        enrichment = enrich_location_data(lat, lng, timestamp)
        self._send_json(200, {"ok": True, "enrichment": enrichment})

    def _handle_learn_place(self):
        """Teach the system a named place (e.g., Home, Work, Gym)."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": "Invalid request body: %s" % e})
            return

        lat = data.get("latitude")
        lng = data.get("longitude")
        label = data.get("label")

        if lat is None or lng is None or not label:
            self._send_json(400, {"error": "latitude, longitude, and label required"})
            return

        try:
            lat = float(lat)
            lng = float(lng)
        except (TypeError, ValueError):
            self._send_json(400, {"error": "latitude and longitude must be numeric"})
            return

        # Load existing places
        places = []
        if os.path.exists(KNOWN_PLACES_FILE):
            try:
                with open(KNOWN_PLACES_FILE, "r") as f:
                    content = f.read()
                places = json.loads(content) if content.strip() else []
            except (json.JSONDecodeError, IOError):
                places = []

        # Check for existing place with same label — update its coordinates
        updated = False
        for place in places:
            if isinstance(place, dict) and place.get("label") == label:
                place["lat"] = lat
                place["lng"] = lng
                updated = True
                break

        if not updated:
            places.append({"lat": lat, "lng": lng, "label": label})

        try:
            with open(KNOWN_PLACES_FILE, "w") as f:
                json.dump(places, f, ensure_ascii=False, indent=2)
            self._send_json(200, {
                "ok": True,
                "label": label,
                "updated": updated,
                "total_places": len(places)
            })
        except IOError as e:
            self._send_json(500, {"error": "Failed to save place: %s" % e})

    # -----------------------------------------------------------------------
    # Parking endpoints
    # -----------------------------------------------------------------------

    def _serve_parking_file(self, path):
        filepath = PARKING_FILES[path]
        if not os.path.exists(filepath):
            if filepath.endswith(".json"):
                self._send_json(200, {} if "last-status" in path else [])
            else:
                self._send_raw(200, "", "text/plain")
            return
        with open(filepath, "r") as f:
            content = f.read()
        if filepath.endswith(".json"):
            try:
                data = json.loads(content) if content.strip() else (
                    {} if "last-status" in path else []
                )
                self._send_json(200, data)
            except json.JSONDecodeError:
                self._send_json(200, {} if "last-status" in path else [])
        else:
            self._send_raw(200, content, "text/plain")

    def _write_parking_skip_dates(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid body: {e}"})
            return
        dates = data.get("dates", [])
        filepath = PARKING_FILES["/parking/skip-dates"]
        with open(filepath, "w") as f:
            f.write("\n".join(dates) + "\n" if dates else "")
        self._send_json(200, {"ok": True, "count": len(dates)})

    # -----------------------------------------------------------------------
    # Analysis endpoints
    # -----------------------------------------------------------------------

    def _handle_activity_analysis(self, data):
        text = data.get("text")
        if not text:
            self._send_json(400, {"error": "Must provide text"})
            return

        prompt = ACTIVITY_ANALYSIS_PROMPT_TEMPLATE.format(description=text)

        try:
            raw_output = run_claude_text(prompt)
            result = extract_result(raw_output)
            self._send_json(200, result)
        except subprocess.TimeoutExpired:
            self._send_json(504, {"error": "Analysis timed out"})
        except RuntimeError as e:
            self._send_json(502, {"error": str(e)})
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(
                500,
                {"error": f"Failed to parse analysis result: {e}"},
            )
        except Exception as e:
            self._send_json(500, {"error": f"Internal error: {e}"})

    def _handle_food_analysis(self, data):
        text = data.get("text")
        image_base64 = data.get("image_base64")
        has_image = bool(image_base64)

        prompt = build_prompt(text, has_image)
        if not prompt:
            self._send_json(400, {"error": "Must provide text or image_base64"})
            return

        temp_image_path = None
        try:
            if has_image:
                with tempfile.NamedTemporaryFile(
                    suffix=".jpg", delete=False
                ) as tmp:
                    tmp.write(base64.b64decode(image_base64))
                    temp_image_path = tmp.name

                raw_output = run_claude_with_image(prompt, temp_image_path)
            else:
                raw_output = run_claude_text(prompt)

            result = extract_result(raw_output)
            self._send_json(200, result)

        except subprocess.TimeoutExpired:
            self._send_json(504, {"error": "Analysis timed out"})
        except RuntimeError as e:
            self._send_json(502, {"error": str(e)})
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(
                500,
                {"error": f"Failed to parse analysis result: {e}"},
            )
        except Exception as e:
            self._send_json(500, {"error": f"Internal error: {e}"})
        finally:
            if temp_image_path and os.path.exists(temp_image_path):
                os.unlink(temp_image_path)

    # -----------------------------------------------------------------------
    # Response helpers
    # -----------------------------------------------------------------------

    def _send_raw(self, status: int, text: str, content_type: str):
        encoded = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(encoded)

    def _send_json(self, status: int, data):
        response = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(response)

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Filename, X-Narration-Id")
        self.end_headers()

    def log_message(self, format, *args):
        """Override to use a cleaner log format."""
        sys.stderr.write(
            f"[bridge] {self.address_string()} - {format % args}\n"
        )


def main():
    if not os.path.isfile(CLAUDE_PATH):
        print(f"Warning: claude CLI not found at {CLAUDE_PATH}", file=sys.stderr)
        print("Analysis endpoints will fail, but data endpoints will work.", file=sys.stderr)

    server = http.server.HTTPServer((HOST, PORT), BridgeHandler)
    print(f"RyanHub Bridge Server listening on http://{HOST}:{PORT}")
    print(f"Data directory: {BRIDGE_DATA_DIR}")
    if os.path.isfile(CLAUDE_PATH):
        print(f"Claude CLI: {CLAUDE_PATH}")
    if WHISPER_AVAILABLE:
        print("Local Whisper: available (narration transcription enabled)")
    else:
        print("Local Whisper: not available (narration transcription disabled)")
    if SENTIMENT_AVAILABLE:
        print("Local emotion model: available (affect analysis enabled)")
    else:
        print("Local emotion model: not available (affect analysis disabled)")
    if GEOPY_AVAILABLE:
        print("Geopy: available (location enrichment enabled)")
    else:
        print("Geopy: not available (location enrichment disabled)")
    print("Press Ctrl+C to stop.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.shutdown()


if __name__ == "__main__":
    main()
