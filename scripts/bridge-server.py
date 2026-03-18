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
  POST     /popo/photos/upload — Upload photo from RB Meta glasses/camera (multipart)
  POST     /popo/narrations/analyze — Transcribe (via diarization server) + affective analysis (local emotion model)
  POST     /popo/analyze — Behavioral analysis: generate proactive nudges from sensing data (LLM or rule-based)
  POST     /popo/location/enrich — Reverse geocode + semantic place enrichment
  POST     /popo/location/learn-place — Teach the system a named place
  GET      /popo/day?date=... — Single-day BoBo bundle for date-aware queries
  GET      /popo/range?days=7 or ?start=...&end=... — Multi-day BoBo summaries
  All GET endpoints support ?date=YYYY-MM-DD filtering.

Usage:
  python3 scripts/bridge-server.py

The server requires `claude` CLI for analysis endpoints.
"""

import http.server
import json
import re
import subprocess
import sys
import tempfile
import time
import base64
import os
import shutil
import uuid
import threading
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any, List
from urllib.parse import urlparse, parse_qs

PORT = 18790
HOST = "0.0.0.0"

# User-configured wellness defaults (can be overridden per-process).
STEP_COUNT_GOAL = int(os.environ.get("RYANHUB_STEP_GOAL", "8000"))

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

# Processed timeline snapshot (single JSON object, overwritten by iOS app)
POPO_TIMELINE_FILE = os.path.join(BRIDGE_DATA_DIR, "popo_timeline.json")
# Canonical current-day timeline snapshot for chat queries about "today/latest".
POPO_TODAY_TIMELINE_FILE = os.path.join(BRIDGE_DATA_DIR, "popo_timeline_today.json")

# POPO audio storage directory
POPO_AUDIO_DIR = os.path.join(BRIDGE_DATA_DIR, "popo_audio")
os.makedirs(POPO_AUDIO_DIR, exist_ok=True)
POPO_PHOTOS_DIR = os.path.join(BRIDGE_DATA_DIR, "popo_photos")
os.makedirs(POPO_PHOTOS_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Whisper transcription via diarization server (port 18793)
# ---------------------------------------------------------------------------

DIARIZATION_SERVER_URL = "http://localhost:18793"

# Lock to protect concurrent reads/writes of the narrations JSON file.
# With ThreadingHTTPServer, multiple handlers can run concurrently, and the
# background analysis thread also writes to this file.
_narrations_file_lock = threading.Lock()


def transcribe_via_diarization_server(audio_path):
    """Transcribe audio by forwarding to the diarization server's /transcribe endpoint.

    Posts the audio file as multipart form data to http://localhost:18793/transcribe.
    Returns the transcript text, or None on failure.
    Timeout: 120s (whisper can be slow on long recordings).
    """
    import urllib.request
    import urllib.error
    import mimetypes

    try:
        # Build multipart/form-data request
        boundary = f"----BridgeUpload{uuid.uuid4().hex}"
        filename = os.path.basename(audio_path)
        content_type = mimetypes.guess_type(filename)[0] or "audio/wav"

        with open(audio_path, "rb") as f:
            file_data = f.read()

        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="audio"; filename="{filename}"\r\n'
            f"Content-Type: {content_type}\r\n"
            f"\r\n"
        ).encode("utf-8") + file_data + f"\r\n--{boundary}--\r\n".encode("utf-8")

        req = urllib.request.Request(
            f"{DIARIZATION_SERVER_URL}/transcribe",
            data=body,
            headers={
                "Content-Type": f"multipart/form-data; boundary={boundary}",
                "Content-Length": str(len(body)),
            },
            method="POST",
        )

        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode("utf-8"))

        # Check for error response from diarization server
        if "error" in result:
            print(f"[Whisper] Diarization server error: {result['error']}", file=sys.stderr)
            return None

        text = result.get("text", "").strip()
        if text:
            print(f"[Whisper] Transcribed via diarization server: {os.path.basename(audio_path)}: {text[:80]}...")
        return text if text else None

    except urllib.error.HTTPError as e:
        # 503 = whisper lock timeout (server busy), other codes = unexpected errors
        if e.code == 503:
            print(f"[Whisper] Diarization server busy (503): whisper lock contention", file=sys.stderr)
        else:
            print(f"[Whisper] Diarization server HTTP error {e.code}: {e.reason}", file=sys.stderr)
        return None
    except urllib.error.URLError as e:
        print(f"[Whisper] Diarization server unreachable: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"[Whisper] Remote transcription failed: {e}", file=sys.stderr)
        return None

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
    """Transcribe an audio file via the diarization server (port 18793).
    Returns the transcript text, or None if unavailable."""
    return transcribe_via_diarization_server(audio_path)


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
    Transcription is forwarded to the diarization server (port 18793).
    Returns a dict with 'transcript', 'affect', and 'narration_id'."""
    result = {
        "narration_id": narration_id,
        "transcript": None,
        "affect": None,
        "status": "skipped"
    }  # type: Dict[str, Any]

    # Step 1: Transcribe via diarization server
    transcript = transcribe_audio(audio_path)
    if transcript is None:
        result["status"] = "transcription_failed"
        return result

    result["transcript"] = transcript
    result["status"] = "transcribed"

    # Step 2: Affect analysis (local)
    affect = analyze_affect(transcript)
    if affect:
        result["affect"] = affect
        result["status"] = "analyzed"

    return result


def update_narration_with_analysis(narration_id, analysis_result):
    # type: (str, Dict[str, Any]) -> None
    """Update the stored narration entry with transcript and affect data.
    Thread-safe: acquires _narrations_file_lock to prevent concurrent R/W."""
    narrations_file = DATA_FILES.get("/popo/narrations")
    if not narrations_file or not os.path.exists(narrations_file):
        print("[Narration] Cannot update: narrations file does not exist yet", file=sys.stderr)
        return

    with _narrations_file_lock:
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

        if not updated:
            print("[Narration] Narration %s not found in file — "
                  "may not have been synced yet" % narration_id, file=sys.stderr)

        if updated:
            try:
                with open(narrations_file, "w") as f:
                    json.dump(narrations, f, ensure_ascii=False)
            except IOError as e:
                print(f"[Narration] Failed to update narration file: {e}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Geopy integration for semantic location enrichment
# ---------------------------------------------------------------------------

import urllib.request
import math

# Google Maps API key for reverse geocoding + Places nearby search
GOOGLE_MAPS_API_KEY = "AIzaSyAQV2dwvyVTSKEQvoI-APgzly1guJMzg6I"

# Known places file for home/work detection
KNOWN_PLACES_FILE = os.path.join(BRIDGE_DATA_DIR, "popo", "known_places.json")
os.makedirs(os.path.join(BRIDGE_DATA_DIR, "popo"), exist_ok=True)


def _haversine_meters(lat1, lng1, lat2, lng2):
    """Calculate distance in meters between two lat/lng points."""
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def check_known_places(lat, lng):
    """Check if coordinates match a known place (within 200m).
    Returns the place label string, or None."""
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
        dist = _haversine_meters(lat, lng, plat, plng)
        if dist < 200:
            return place.get("label")
    return None


def _google_reverse_geocode(lat, lng):
    """Reverse geocode via Google Geocoding API. Returns (address, components dict)."""
    url = (
        "https://maps.googleapis.com/maps/api/geocode/json"
        "?latlng=%.6f,%.6f&key=%s&language=en"
    ) % (lat, lng, GOOGLE_MAPS_API_KEY)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ryanhub-popo/1.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
        if data.get("status") != "OK" or not data.get("results"):
            return None, {}
        top = data["results"][0]
        address = top.get("formatted_address", "")
        # Parse address components into a lookup dict
        components = {}
        for comp in top.get("address_components", []):
            for t in comp.get("types", []):
                components[t] = comp.get("long_name", "")
        return address, components
    except Exception as e:
        print(f"[Location] Google geocode failed: {e}")
        return None, {}


def _viewport_area(geometry):
    """Calculate the approximate area of a place's viewport in degrees².
    Larger viewport = larger/more prominent place."""
    vp = geometry.get("viewport", {})
    ne = vp.get("northeast", {})
    sw = vp.get("southwest", {})
    if not all(k in ne for k in ("lat", "lng")) or not all(k in sw for k in ("lat", "lng")):
        return 0
    dlat = abs(ne["lat"] - sw["lat"])
    dlng = abs(ne["lng"] - sw["lng"])
    return dlat * dlng


def _google_nearby_places(lat, lng):
    """Find nearby places via Google Places Nearby Search.
    Uses progressive radius: start small (30m ~ iPhone GPS accuracy),
    expand to 80m if no results. Smaller radius naturally returns
    the building you're in rather than a shop down the hall."""
    # Types that are purely geographic, not actual places
    GEO_ONLY = {"locality", "political", "administrative_area_level_1",
                "administrative_area_level_2", "administrative_area_level_3",
                "country", "postal_code", "route", "street_address",
                "street_number", "sublocality", "sublocality_level_1"}

    for radius in (30, 80):
        url = (
            "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
            "?location=%.6f,%.6f&radius=%d&key=%s"
        ) % (lat, lng, radius, GOOGLE_MAPS_API_KEY)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "ryanhub-popo/1.0"})
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read().decode())
            if data.get("status") not in ("OK", "ZERO_RESULTS"):
                print(f"[Location] Google Places status: {data.get('status')}")
                continue

            results = []
            for place in data.get("results", [])[:10]:
                types_set = set(place.get("types", []))
                # Skip if all types are purely geographic (city, country, etc.)
                if types_set and types_set.issubset(GEO_ONLY):
                    continue
                results.append({
                    "name": place.get("name", ""),
                    "types": place.get("types", []),
                    "vicinity": place.get("vicinity", ""),
                })

            if results:
                return results
        except Exception as e:
            print(f"[Location] Google Places failed (radius={radius}): {e}")

    return []


def enrich_location_data(lat, lng, timestamp_str=None):
    """Enrich a lat/lng with semantic place info via Google APIs.
    Returns a dict with address, place_type, semantic_label, nearby POIs, etc."""
    result = {}

    # 1. Reverse geocode via Google Geocoding API
    address, components = _google_reverse_geocode(lat, lng)
    if address:
        result["address"] = address
        result["neighborhood"] = (
            components.get("neighborhood", "")
            or components.get("sublocality", "")
            or components.get("sublocality_level_1", "")
        )
        result["city"] = (
            components.get("locality", "")
            or components.get("administrative_area_level_2", "")
        )
        result["place_type"] = components.get("point_of_interest", "")

    # 2. Nearby Places (POI) via Google Places API
    # The _google_nearby_places function already filters out pure geographic entries.
    # All results here are actual places (buildings, shops, landmarks, etc.)
    nearby = _google_nearby_places(lat, lng)
    if nearby:
        top_place = nearby[0]
        result["place_name"] = top_place["name"]
        # Extract a readable place type, skipping generic Google categories
        generic_types = {"point_of_interest", "establishment", "political"}
        place_types = [t for t in top_place.get("types", []) if t not in generic_types]
        if place_types:
            result["place_type"] = place_types[0].replace("_", " ")
        # Include up to 3 nearby place names
        poi_names = [p["name"] for p in nearby[:3] if p["name"]]
        if poi_names:
            result["nearby_pois"] = poi_names

    # 3. Check against user-defined known places (home/work clusters)
    known = check_known_places(lat, lng)
    if known:
        result["semantic_label"] = known

    # 4. Time-based heuristic
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


def run_claude_text(prompt: str, timeout: int = 60) -> str:
    """Run claude CLI with a text-only prompt."""
    env = os.environ.copy()
    env.pop("CLAUDE_CODE", None)
    env.pop("CLAUDECODE", None)

    result = subprocess.run(
        [CLAUDE_PATH, "-p", prompt, "--output-format", "json", "--model", "haiku"],
        capture_output=True,
        text=True,
        timeout=timeout,
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
# Claude CLI is used for behavioral analysis (nudge generation).
# No API key needed — uses the local claude CLI with Max Plan auth.


# ---------------------------------------------------------------------------
# Behavioral analysis: data summarization + nudge generation
# ---------------------------------------------------------------------------

BEHAVIORAL_ANALYSIS_SYSTEM_PROMPT = """\
You are Bo, a behavioral health AI companion. You analyze the user's real sensor data and generate evidence-based, actionable insights grounded in behavioral science.

Your user is: Zhiyuan Wang, PhD student at UVA, starting at Meta Reality Labs in May. He tracks health for fat loss (baseline 92+ kg, goal ~75 kg). He wears an Apple Watch and has full HealthKit integration.

IMPORTANT: All timestamps are in the user's LOCAL timezone. Current local time is in the summary header.

## Analysis Framework

Apply these behavioral science principles when analyzing data:

1. **Circadian alignment** — Is sleep/wake timing consistent? Late-night screen use disrupts melatonin. Morning sunlight exposure improves sleep quality.
2. **Energy balance** — Compare active calories burned vs food intake (if available). Sedentary hours reduce NEAT (non-exercise activity thermogenesis).
3. **Heart rate variability (HRV)** — Low HRV indicates stress/poor recovery. Trend matters more than single readings. Post-sleep HRV is most reliable.
4. **Activity patterns** — Prolonged sedentary bouts (>90 min) increase cardiometabolic risk regardless of exercise. Movement breaks restore executive function (Cognitive Restoration Theory).
5. **Sleep architecture** — Deep sleep is critical for physical recovery, REM for cognitive consolidation. <6h total sleep impairs glucose metabolism and increases cortisol.
6. **Behavioral momentum** — Reinforce small wins to build habit chains (BJ Fogg's Tiny Habits). Don't lecture; nudge toward the next small step.
7. **Recovery signals** — Resting HR trend, blood oxygen during sleep, respiratory rate changes indicate overtraining or illness onset.

## Output Rules

Generate 1-3 insights. Each MUST:
- Reference SPECIFIC data points with numbers and times ("Your HR was 92 BPM at 2:30 PM while stationary — that's elevated")
- Explain WHY it matters using behavioral science ("Prolonged sitting reduces NEAT by ~300 cal/day")
- Suggest ONE concrete action ("Try a 5-min walk now — even brief movement resets the sedentary counter")
- Be concise (2-3 sentences max per insight)

Do NOT generate generic "everything looks good" messages. If data is genuinely unremarkable, find ONE specific improvement opportunity.

Types:
- insight: Pattern observation grounded in data
- reminder: Time-sensitive behavioral prompt
- encouragement: Data-backed positive reinforcement (with numbers)
- alert: Health concern with specific threshold crossed

Return ONLY a JSON array. Each object: { "type", "content", "trigger", "priority" ("normal"|"high"), "relatedModalities" (list) }
No markdown, no explanation outside the JSON."""


def _utc_to_local_str(ts_str):
    # type: (str) -> str
    """Convert an ISO 8601 UTC timestamp string to local time display string."""
    if not ts_str:
        return ts_str
    try:
        dt = _parse_iso_datetime(ts_str, assume_local_if_naive=False)
        if dt is None:
            return ts_str[:16]
        local_dt = dt.astimezone(_get_local_timezone())
        return local_dt.strftime("%Y-%m-%d %H:%M")
    except (ValueError, TypeError):
        return ts_str[:16]


def _get_local_timezone():
    # type: () -> timezone
    """Return the server's local timezone."""
    return datetime.now().astimezone().tzinfo or timezone.utc


def _parse_iso_datetime(ts_str, assume_local_if_naive=True):
    # type: (str, bool) -> Optional[datetime]
    """Parse an ISO 8601 timestamp into an aware datetime.

    Legacy bridge data sometimes stored naive local timestamps without an
    explicit timezone. When `assume_local_if_naive` is true, interpret those
    values in the server's local timezone so comparisons and display stay
    stable across old/new records.
    """
    if not ts_str or not isinstance(ts_str, str):
        return None

    try:
        dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
    except ValueError:
        return None

    if dt.tzinfo is None:
        if assume_local_if_naive:
            return dt.replace(tzinfo=_get_local_timezone())
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _now_utc_iso():
    # type: () -> str
    """Return the current time as an ISO 8601 UTC timestamp."""
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _record_timestamp_at_or_after(record, cutoff):
    # type: (Dict[str, Any], datetime) -> bool
    """Return whether a record's timestamp is on/after the cutoff."""
    if not isinstance(record, dict):
        return False

    dt = _parse_iso_datetime(record.get("timestamp", ""), assume_local_if_naive=True)
    if dt is None:
        return False
    return dt >= cutoff


def _local_date_string(dt):
    # type: (datetime) -> str
    """Format a datetime as YYYY-MM-DD in the server's local timezone."""
    return dt.astimezone(_get_local_timezone()).strftime("%Y-%m-%d")


def _record_matches_local_date(record, date_filter, field="timestamp"):
    # type: (Dict[str, Any], str, str) -> bool
    """Return whether a record belongs to the given local calendar day."""
    if not isinstance(record, dict):
        return False

    value = record.get(field, "")
    dt = _parse_iso_datetime(value, assume_local_if_naive=True)
    if dt is None:
        return False
    return _local_date_string(dt) == date_filter


def _sleep_record_matches_local_date(record, date_filter):
    # type: (Dict[str, Any], str) -> bool
    """Assign sleep samples to the local day of their end time (wake-up day)."""
    if not isinstance(record, dict):
        return False

    payload = record.get("payload", {}) if isinstance(record.get("payload"), dict) else {}
    end_dt = _parse_iso_datetime(payload.get("endDate", ""), assume_local_if_naive=False)
    if end_dt is None:
        return _record_matches_local_date(record, date_filter)
    return _local_date_string(end_dt) == date_filter


def _load_json_array(filepath):
    # type: (str) -> List[Dict[str, Any]]
    """Load a JSON array file, returning [] on errors or non-array content."""
    if not filepath or not os.path.exists(filepath):
        return []
    try:
        with open(filepath, "r") as f:
            content = f.read()
        data = json.loads(content) if content.strip() else []
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, IOError):
        return []


def _get_local_timezone_name():
    # type: () -> str
    """Get the local timezone name (e.g. 'EST', 'America/New_York')."""
    try:
        import subprocess
        result = subprocess.run(
            ["readlink", "/etc/localtime"],
            capture_output=True, text=True, timeout=5
        )
        # e.g. /var/db/timezone/zoneinfo/America/New_York
        path = result.stdout.strip()
        if "zoneinfo/" in path:
            return path.split("zoneinfo/")[-1]
    except Exception:
        pass
    # Fallback: use UTC offset
    now = datetime.now().astimezone()
    return now.strftime("%Z (UTC%z)")


def _evf(event, *fields, default=None):
    # type: (dict, *str, Any) -> Any
    """Extract a field from a sensing event, handling flat, nested (payload),
    and legacy (data) formats. Tries each field name in order, checking
    top-level, then payload, then data. Returns the first non-None match."""
    for field in fields:
        # Top-level (flat format from iOS generateNudges)
        val = event.get(field)
        if val is not None:
            return val
        # Nested payload (format from popo_sensing.json)
        payload = event.get("payload")
        if isinstance(payload, dict):
            val = payload.get(field)
            if val is not None:
                return val
        # Legacy nested data
        data = event.get("data")
        if isinstance(data, dict):
            val = data.get(field)
            if val is not None:
                return val
    return default


def _evf_num(event, *fields, default=0):
    # type: (dict, *str, float) -> float
    """Like _evf but coerces the result to a number (int or float).
    Handles string values from iOS payloads like '72' or '1234'."""
    val = _evf(event, *fields, default=default)
    if isinstance(val, (int, float)):
        return val
    if isinstance(val, str):
        try:
            return float(val)
        except (ValueError, TypeError):
            return default
    return default


def summarize_sensing_data(events, narrations, daily_summary=None):
    # type: (List[Dict], List[Dict], Optional[Dict]) -> str
    """Convert raw sensing events and narrations into a readable summary for the LLM.

    Groups events by modality and extracts key metrics for each.
    Handles both flat dicts (from iOS generateNudges) and nested dicts
    (from popo_sensing.json with payload sub-dict).
    All timestamps are converted from UTC to the server's local timezone."""
    lines = []  # type: List[str]
    now = datetime.now(_get_local_timezone())
    tz_name = _get_local_timezone_name()
    lines.append("=== Behavioral Data Summary ===")
    lines.append("Current time: %s (%s)" % (now.strftime("%Y-%m-%d %H:%M"), tz_name))
    lines.append("All times below are in %s." % tz_name)
    lines.append("")

    if not events and not narrations and not daily_summary:
        lines.append("No sensing data available for this period.")
        return "\n".join(lines)

    # Group events by modality
    by_modality = {}  # type: Dict[str, List[Dict]]
    for ev in events:
        if not isinstance(ev, dict):
            continue
        modality = ev.get("modality", ev.get("type", "unknown"))
        by_modality.setdefault(modality, []).append(ev)

    # --- Motion ---
    motion_events = by_modality.get("motion", [])
    if motion_events:
        lines.append("[Motion]")
        latest = max(motion_events, key=lambda e: e.get("timestamp", ""), default=None)
        if latest:
            activity = _evf(latest, "activityType", "activity", default="unknown")
            confidence = _evf(latest, "confidence", default="")
            lines.append("  Current activity: %s (confidence: %s)" % (activity, confidence))
        activities = [_evf(e, "activityType", "activity", default="") for e in motion_events]
        transitions = sum(1 for i in range(1, len(activities)) if activities[i] != activities[i - 1])
        lines.append("  Activity transitions in period: %d" % transitions)
        stationary_events = [e for e in motion_events if
                             _evf(e, "activityType", "activity", default="")
                             in ("stationary", "still", "sitting", "unknown")]
        if stationary_events:
            first_ts = stationary_events[0].get("timestamp", "")
            last_ts = stationary_events[-1].get("timestamp", "")
            if first_ts and last_ts:
                try:
                    t0 = datetime.fromisoformat(first_ts.replace("Z", "+00:00"))
                    t1 = datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
                    duration_min = (t1 - t0).total_seconds() / 60
                    if duration_min > 30:
                        lines.append("  Sedentary streak: ~%.0f minutes" % duration_min)
                except (ValueError, TypeError):
                    pass
        # Episode durations
        for ev in motion_events:
            dur = _evf_num(ev, "duration")
            if dur > 0:
                activity = _evf(ev, "activityType", "activity", default="?")
                next_act = _evf(ev, "nextActivity", default="")
                ts = _utc_to_local_str(ev.get("timestamp", ""))
                dur_min = dur / 60
                line = "  [%s] %s for %.0f min" % (ts, activity, dur_min)
                if next_act:
                    line += " → %s" % next_act
                lines.append(line)
        lines.append("")

    # --- Steps ---
    step_events = by_modality.get("steps", by_modality.get("pedometer", []))
    if step_events:
        lines.append("[Steps]")
        max_steps = 0
        for ev in step_events:
            count = _evf_num(ev, "steps", "count")
            max_steps = max(max_steps, int(count))
        if max_steps > 0:
            lines.append("  Total steps: %d" % max_steps)
        else:
            lines.append("  Step events: %d (no counts extracted)" % len(step_events))
        lines.append("")

    # --- Heart Rate ---
    hr_events = by_modality.get("heartRate", by_modality.get("heart_rate", []))
    if hr_events:
        lines.append("[Heart Rate]")
        bpm_values = []
        for ev in hr_events:
            bpm = _evf_num(ev, "bpm")
            if bpm > 0:
                bpm_values.append(bpm)
        if bpm_values:
            lines.append("  Latest: %.0f bpm" % bpm_values[-1])
            lines.append("  Range: %.0f - %.0f bpm" % (min(bpm_values), max(bpm_values)))
            lines.append("  Average: %.0f bpm" % (sum(bpm_values) / len(bpm_values)))
            # Flag anomalies
            anomalies = [ev for ev in hr_events if _evf(ev, "anomaly") == "true"]
            if anomalies:
                lines.append("  ⚠ %d anomaly readings detected" % len(anomalies))
        lines.append("")

    # --- HRV ---
    hrv_events = by_modality.get("hrv", [])
    if hrv_events:
        lines.append("[Heart Rate Variability]")
        sdnn_values = [_evf_num(ev, "sdnn") for ev in hrv_events]
        sdnn_values = [v for v in sdnn_values if v > 0]
        if sdnn_values:
            lines.append("  Latest: %.1f ms SDNN" % sdnn_values[-1])
            lines.append("  Range: %.1f - %.1f ms" % (min(sdnn_values), max(sdnn_values)))
        lines.append("")

    # --- Location ---
    loc_events = by_modality.get("location", [])
    if loc_events:
        lines.append("[Location]")
        places = set()
        for ev in loc_events:
            place = (_evf(ev, "placeName") or _evf(ev, "semanticLabel")
                     or _evf(ev, "description") or _evf(ev, "address"))
            if place and place != "unknown":
                places.add(place)
        if places:
            lines.append("  Places visited: %s" % ", ".join(sorted(places)))
        else:
            lines.append("  Location events: %d (no semantic places resolved)" % len(loc_events))
        lines.append("")

    # --- Screen ---
    screen_events = by_modality.get("screen", by_modality.get("screenTime", []))
    if screen_events:
        lines.append("[Screen]")
        on_events = [ev for ev in screen_events if _evf(ev, "state") == "on"
                     or _evf(ev, "state") == "hourly_aggregate"]
        total_on_sec = 0
        session_count = 0
        for ev in on_events:
            on_dur = _evf_num(ev, "onDuration", "totalDuration")
            if on_dur > 0:
                total_on_sec += on_dur
            count = _evf_num(ev, "count", default=1)
            session_count += int(count)
        if total_on_sec > 0:
            lines.append("  Total screen time: %.0f min" % (total_on_sec / 60.0))
        if session_count > 0:
            lines.append("  Screen opens: %d" % session_count)
        lines.append("")

    # --- Sleep ---
    sleep_events = by_modality.get("sleep", [])
    if sleep_events:
        lines.append("[Sleep]")
        total_sleep_sec = 0
        stages = {}  # type: Dict[str, float]
        for ev in sleep_events:
            stage = _evf(ev, "stage", "state", "value", default="unknown")
            start_dt = _parse_iso_datetime(_evf(ev, "startDate", default=""), assume_local_if_naive=False)
            end_dt = _parse_iso_datetime(_evf(ev, "endDate", default=""), assume_local_if_naive=False)
            if start_dt and end_dt:
                seconds = max(0.0, (end_dt - start_dt).total_seconds())
            else:
                seconds = _evf_num(ev, "duration")
            total_sleep_sec += seconds
            stages[stage] = stages.get(stage, 0) + seconds
        hours = total_sleep_sec / 3600.0
        lines.append("  Total sleep: %.1f hours" % hours)
        for stage, secs in sorted(stages.items(), key=lambda x: -x[1]):
            if secs > 0:
                lines.append("    %s: %.0f min" % (stage, secs / 60.0))
        lines.append("")

    # --- Energy ---
    for modality_key, label in [("activeEnergy", "Active Energy"), ("basalEnergy", "Resting Energy")]:
        energy_events = by_modality.get(modality_key, [])
        if energy_events:
            lines.append("[%s]" % label)
            total_kcal = sum(_evf_num(ev, "kcal") for ev in energy_events)
            if total_kcal > 0:
                lines.append("  Total: %.0f kcal" % total_kcal)
            lines.append("")

    # --- Blood Oxygen ---
    spo2_events = by_modality.get("bloodOxygen", [])
    if spo2_events:
        lines.append("[Blood Oxygen]")
        values = [_evf_num(ev, "spo2") for ev in spo2_events]
        values = [v for v in values if v > 0]
        if values:
            lines.append("  Latest: %.0f%%" % values[-1])
            lines.append("  Range: %.0f - %.0f%%" % (min(values), max(values)))
            low = [v for v in values if v < 95]
            if low:
                lines.append("  ⚠ %d readings below 95%%" % len(low))
        lines.append("")

    # --- Respiratory Rate ---
    resp_events = by_modality.get("respiratoryRate", [])
    if resp_events:
        lines.append("[Respiratory Rate]")
        values = [_evf_num(ev, "breathsPerMin") for ev in resp_events]
        values = [v for v in values if v > 0]
        if values:
            lines.append("  Latest: %.1f breaths/min" % values[-1])
        lines.append("")

    # --- Noise ---
    noise_events = by_modality.get("noiseExposure", [])
    if noise_events:
        lines.append("[Noise Exposure]")
        values = [_evf_num(ev, "decibels") for ev in noise_events]
        values = [v for v in values if v > 0]
        if values:
            lines.append("  Latest: %.0f dB" % values[-1])
            lines.append("  Range: %.0f - %.0f dB" % (min(values), max(values)))
            loud = [v for v in values if v >= 80]
            if loud:
                lines.append("  ⚠ %d readings above 80 dB" % len(loud))
        lines.append("")

    # --- Battery ---
    battery_events = by_modality.get("battery", [])
    if battery_events:
        lines.append("[Battery]")
        latest = max(battery_events, key=lambda e: e.get("timestamp", ""), default=None)
        if latest:
            level = _evf_num(latest, "level")
            charging = _evf(latest, "charging", "isCharging")
            if level > 0:
                lines.append("  Level: %.0f%%" % level)
            if charging is not None:
                is_charging = str(charging).lower() in ("true", "1", "yes")
                lines.append("  Charging: %s" % ("yes" if is_charging else "no"))
        lines.append("")

    # --- Workout ---
    workout_events = by_modality.get("workout", [])
    if workout_events:
        lines.append("[Workouts]")
        for ev in workout_events:
            wtype = _evf(ev, "type", default="unknown")
            dur = _evf_num(ev, "duration")
            cal = _evf_num(ev, "calories")
            ts = _utc_to_local_str(ev.get("timestamp", ""))
            parts = [wtype]
            if dur > 0:
                parts.append("%.0f min" % (dur / 60))
            if cal > 0:
                parts.append("%.0f kcal" % cal)
            lines.append("  [%s] %s" % (ts, " — ".join(parts)))
        lines.append("")

    # --- Any other modalities ---
    known = {"motion", "steps", "pedometer", "heartRate", "heart_rate",
             "location", "screen", "screenTime", "sleep", "battery",
             "hrv", "activeEnergy", "basalEnergy", "bloodOxygen",
             "respiratoryRate", "noiseExposure", "workout"}
    for modality, evts in by_modality.items():
        if modality not in known and evts:
            lines.append("[%s]" % modality.capitalize())
            lines.append("  Events: %d" % len(evts))
            lines.append("")

    # --- Narrations ---
    if narrations:
        lines.append("[Voice Narrations]")
        for nar in narrations[-5:]:  # Last 5 narrations
            if not isinstance(nar, dict):
                continue
            transcript = nar.get("transcript", "")
            mood = nar.get("extractedMood", nar.get("mood", ""))
            affect = nar.get("affectAnalysis", {})
            ts = _utc_to_local_str(nar.get("timestamp", ""))
            if transcript:
                lines.append('  [%s] "%s"' % (ts, transcript[:120]))
                if mood:
                    lines.append("    Mood: %s" % mood)
                elif affect and isinstance(affect, dict):
                    primary = affect.get("primary_emotion", affect.get("primaryEmotion", ""))
                    if primary:
                        lines.append("    Emotion: %s" % primary)
        lines.append("")

    # --- Daily summary (if provided) ---
    if daily_summary and isinstance(daily_summary, dict):
        lines.append("[Daily Summary]")
        for key, val in daily_summary.items():
            if key not in ("id", "date"):
                lines.append("  %s: %s" % (key, val))
        lines.append("")

    return "\n".join(lines)


def generate_nudges_llm(summary_text, timeout=20):
    # type: (str) -> Optional[List[Dict]]
    """Generate nudges using Claude CLI (Max Plan). Returns list of nudge dicts or None on failure."""
    full_prompt = BEHAVIORAL_ANALYSIS_SYSTEM_PROMPT + "\n\n" + summary_text

    try:
        raw_output = run_claude_text(full_prompt, timeout=timeout)

        # Parse the claude CLI JSON output to get the result text
        try:
            cli_result = json.loads(raw_output)
            response_text = cli_result.get("result", raw_output)
        except (json.JSONDecodeError, TypeError):
            response_text = raw_output

        # Strip markdown code blocks if present
        response_text = response_text.strip()
        if response_text.startswith("```json"):
            response_text = response_text[7:]
        elif response_text.startswith("```"):
            response_text = response_text[3:]
        if response_text.endswith("```"):
            response_text = response_text[:-3]
        response_text = response_text.strip()

        nudges = json.loads(response_text)
        if isinstance(nudges, list):
            return nudges
        elif isinstance(nudges, dict) and "nudges" in nudges:
            return nudges["nudges"]
        else:
            print("[Analyze] Unexpected LLM response format: %s" % type(nudges),
                  file=sys.stderr)
            return None

    except Exception as e:
        print("[Analyze] LLM nudge generation failed: %s" % e, file=sys.stderr)
        return None


def generate_nudges_rule_based(events, narrations, daily_summary=None):
    # type: (List[Dict], List[Dict], Optional[Dict]) -> List[Dict]
    """Rule-based nudge generation as fallback when LLM is unavailable.
    Uses _evf/_evf_num helpers to handle both flat and nested event formats."""
    nudges = []  # type: List[Dict]
    now = datetime.now(_get_local_timezone())

    # Group events by modality
    by_modality = {}  # type: Dict[str, List[Dict]]
    for ev in events:
        if not isinstance(ev, dict):
            continue
        modality = ev.get("modality", ev.get("type", "unknown"))
        by_modality.setdefault(modality, []).append(ev)

    # Rule 1: Sedentary for too long
    motion_events = by_modality.get("motion", [])
    if motion_events:
        stationary = [e for e in motion_events if
                      _evf(e, "activityType", "activity", default="")
                      in ("stationary", "still", "sitting")]
        if len(stationary) >= 2:
            first_ts = stationary[0].get("timestamp", "")
            last_ts = stationary[-1].get("timestamp", "")
            if first_ts and last_ts:
                try:
                    t0 = datetime.fromisoformat(first_ts.replace("Z", "+00:00"))
                    t1 = datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
                    duration_min = (t1 - t0).total_seconds() / 60
                    if duration_min >= 120:
                        nudges.append({
                            "type": "reminder",
                            "content": "You've been sedentary for about %.0f minutes. How about a quick stretch or a short walk?" % duration_min,
                            "trigger": "sedentary_duration",
                            "priority": "normal",
                            "relatedModalities": ["motion"]
                        })
                    elif duration_min >= 60:
                        nudges.append({
                            "type": "reminder",
                            "content": "About an hour of sitting so far. Maybe stand up and stretch for a minute?",
                            "trigger": "sedentary_duration",
                            "priority": "normal",
                            "relatedModalities": ["motion"]
                        })
                except (ValueError, TypeError):
                    pass

    # Rule 2: Step count milestones
    step_events = by_modality.get("steps", by_modality.get("pedometer", []))
    if step_events:
        max_steps = 0
        for ev in step_events:
            count = int(_evf_num(ev, "steps", "count"))
            max_steps = max(max_steps, count)
        if max_steps >= 8000:
            nudges.append({
                "type": "encouragement",
                "content": "Amazing! %d steps today — you hit the 8K mark!" % max_steps,
                "trigger": "steps_milestone",
                "priority": "normal",
                "relatedModalities": ["steps"]
            })
        elif max_steps >= 4000:
            nudges.append({
                "type": "encouragement",
                "content": "%d steps so far today. Halfway to 8K — you're doing great!" % max_steps,
                "trigger": "steps_progress",
                "priority": "normal",
                "relatedModalities": ["steps"]
            })
        elif now.hour >= 18 and 0 < max_steps < 3000:
            nudges.append({
                "type": "reminder",
                "content": "Only %d steps today and it's already evening. An after-dinner walk could help!" % max_steps,
                "trigger": "low_steps_evening",
                "priority": "normal",
                "relatedModalities": ["steps"]
            })

    # Rule 3: Elevated heart rate while stationary
    hr_events = by_modality.get("heartRate", by_modality.get("heart_rate", []))
    if hr_events and motion_events:
        latest_hr = max(hr_events, key=lambda e: e.get("timestamp", ""), default=None)
        latest_motion = max(motion_events, key=lambda e: e.get("timestamp", ""), default=None)
        if latest_hr and latest_motion:
            bpm = _evf_num(latest_hr, "bpm")
            activity = _evf(latest_motion, "activityType", "activity", default="")
            if bpm > 100 and activity in ("stationary", "still", "sitting"):
                nudges.append({
                    "type": "alert",
                    "content": "Your heart rate is %.0f bpm while you're stationary. Try some deep breathing to relax." % bpm,
                    "trigger": "elevated_hr_stationary",
                    "priority": "high",
                    "relatedModalities": ["heartRate", "motion"]
                })

    # Rule 4: Low blood oxygen
    spo2_events = by_modality.get("bloodOxygen", [])
    if spo2_events:
        latest = max(spo2_events, key=lambda e: e.get("timestamp", ""), default=None)
        if latest:
            spo2 = _evf_num(latest, "spo2")
            if 0 < spo2 < 95:
                nudges.append({
                    "type": "alert",
                    "content": "Blood oxygen at %.0f%% — that's a bit low. Consider taking some deep breaths and monitoring." % spo2,
                    "trigger": "low_spo2",
                    "priority": "high",
                    "relatedModalities": ["bloodOxygen"]
                })

    # Rule 5: Sleep quality insight
    sleep_events = by_modality.get("sleep", [])
    if sleep_events:
        total_sleep_sec = 0
        for ev in sleep_events:
            start_dt = _parse_iso_datetime(_evf(ev, "startDate", default=""), assume_local_if_naive=False)
            end_dt = _parse_iso_datetime(_evf(ev, "endDate", default=""), assume_local_if_naive=False)
            if start_dt and end_dt:
                total_sleep_sec += max(0, (end_dt - start_dt).total_seconds())
            else:
                total_sleep_sec += _evf_num(ev, "duration")
        hours = total_sleep_sec / 3600.0
        if 0 < hours < 6:
            nudges.append({
                "type": "insight",
                "content": "Only %.1f hours of sleep last night. Try to get to bed earlier tonight — your body needs recovery time." % hours,
                "trigger": "low_sleep",
                "priority": "normal",
                "relatedModalities": ["sleep"]
            })
        elif hours >= 8:
            nudges.append({
                "type": "encouragement",
                "content": "Great sleep — %.1f hours! You should feel well-rested today." % hours,
                "trigger": "good_sleep",
                "priority": "normal",
                "relatedModalities": ["sleep"]
            })

    # Rule 6: Negative mood from narrations
    if narrations:
        recent_narrations = narrations[-3:]
        negative_count = 0
        for nar in recent_narrations:
            if not isinstance(nar, dict):
                continue
            mood = nar.get("extractedMood", nar.get("mood", ""))
            affect = nar.get("affectAnalysis", {})
            if mood in ("sadness", "anger", "fear", "disgust"):
                negative_count += 1
            elif isinstance(affect, dict):
                primary = affect.get("primary_emotion", affect.get("primaryEmotion", ""))
                if primary in ("sadness", "anger", "fear", "disgust"):
                    negative_count += 1
        if negative_count >= 2:
            nudges.append({
                "type": "insight",
                "content": "Your recent voice entries suggest you might be feeling down. Want to take a break or do something you enjoy?",
                "trigger": "negative_mood_pattern",
                "priority": "normal",
                "relatedModalities": ["narration"]
            })

    # Rule 7: Low battery warning
    battery_events = by_modality.get("battery", [])
    if battery_events:
        latest = max(battery_events, key=lambda e: e.get("timestamp", ""), default=None)
        if latest:
            level = _evf_num(latest, "level")
            charging = _evf(latest, "charging", "isCharging")
            is_charging = str(charging).lower() in ("true", "1", "yes") if charging else False
            if 0 < level <= 15 and not is_charging:
                nudges.append({
                    "type": "alert",
                    "content": "Battery at %d%% — you might want to charge soon!" % int(level),
                    "trigger": "low_battery",
                    "priority": "high",
                    "relatedModalities": ["battery"]
                })

    # Rule 8: High noise exposure
    noise_events = by_modality.get("noiseExposure", [])
    if noise_events:
        high_noise = [ev for ev in noise_events if _evf_num(ev, "decibels") >= 80]
        if len(high_noise) >= 3:
            nudges.append({
                "type": "alert",
                "content": "You've been exposed to noise above 80 dB for a while. Consider ear protection or moving somewhere quieter.",
                "trigger": "high_noise_exposure",
                "priority": "normal",
                "relatedModalities": ["noiseExposure"]
            })

    # If no specific rules fired, generate a contextual summary nudge
    if not nudges and (events or narrations):
        # No specific rule fired — generate a data-grounded observation
        now = datetime.now(_get_local_timezone())
        parts = []
        if step_events:
            max_s = max(int(_evf_num(ev, "steps", "count")) for ev in step_events)
            if max_s > 0:
                if max_s < 3000 and now.hour >= 14:
                    parts.append("Only %d steps by %s — try a 10-min walk to boost your NEAT" % (max_s, now.strftime("%I %p")))
                elif max_s >= 8000:
                    parts.append("%d steps — strong movement day" % max_s)
                else:
                    parts.append("%d steps so far" % max_s)
        if sleep_events:
            total_sec = 0
            for ev in sleep_events:
                s = _parse_iso_datetime(_evf(ev, "startDate", default=""), assume_local_if_naive=False)
                e = _parse_iso_datetime(_evf(ev, "endDate", default=""), assume_local_if_naive=False)
                if s and e:
                    total_sec += max(0, (e - s).total_seconds())
            hours = total_sec / 3600
            if hours > 0:
                if hours < 6:
                    parts.append("%.1fh sleep — below the 7h threshold for metabolic health" % hours)
                else:
                    parts.append("%.1fh sleep" % hours)
        if motion_events:
            # Check for prolonged sedentary
            stationary = [e for e in motion_events if _evf(e, "activityType", "activity", default="") in ("stationary", "still")]
            if len(stationary) > len(motion_events) * 0.7:
                parts.append("mostly sedentary today — prolonged sitting (>90 min) reduces executive function and NEAT")

        content = ". ".join(parts) if parts else "Data is flowing but no notable patterns yet"
        nudges.append({
            "type": "insight",
            "content": content,
            "trigger": "behavioral_observation",
            "priority": "normal",
            "relatedModalities": list(by_modality.keys())[:3]
        })

    return nudges[:3]


def store_generated_nudges(nudge_records):
    # type: (List[Dict]) -> None
    """Store generated nudges into popo_nudges.json following existing storage pattern."""
    nudges_file = DATA_FILES.get("/popo/nudges")
    if not nudges_file:
        return

    # Load existing nudges
    existing = []
    if os.path.exists(nudges_file):
        try:
            with open(nudges_file, "r") as f:
                content = f.read()
            existing = json.loads(content) if content.strip() else []
        except (json.JSONDecodeError, IOError):
            existing = []

    # Merge by id (same pattern as _write_data_file)
    merged = {}  # type: Dict[str, Dict]
    for item in existing:
        if isinstance(item, dict) and "id" in item:
            merged[item["id"]] = item
    for item in nudge_records:
        if isinstance(item, dict) and "id" in item:
            merged[item["id"]] = item

    try:
        with open(nudges_file, "w") as f:
            json.dump(list(merged.values()), f, ensure_ascii=False)
    except IOError as e:
        print("[Analyze] Failed to store nudges: %s" % e, file=sys.stderr)


def _parse_requested_local_date(date_str):
    # type: (Optional[str]) -> datetime
    """Parse a local calendar day. Supports YYYY-MM-DD, today, and yesterday."""
    if not date_str:
        return datetime.now(_get_local_timezone()).replace(
            hour=0, minute=0, second=0, microsecond=0
        )

    normalized = str(date_str).strip().lower()
    local_tz = _get_local_timezone()
    base_day = datetime.now(local_tz).replace(hour=0, minute=0, second=0, microsecond=0)
    if normalized == "today":
        return base_day
    if normalized == "yesterday":
        return base_day - timedelta(days=1)

    parsed = datetime.strptime(normalized, "%Y-%m-%d")
    return parsed.replace(tzinfo=local_tz)


def _build_day_bundle(date_str):
    # type: (str) -> Dict[str, Any]
    """Build a date-scoped timeline bundle from server data files."""
    target_day = _parse_requested_local_date(date_str)
    target_key = target_day.strftime("%Y-%m-%d")

    raw_sensing = _load_json_array(DATA_FILES["/popo/sensing"])
    sensing = []
    seen_sleep_keys = set()  # type: set
    for item in raw_sensing:
        if not isinstance(item, dict):
            continue
        modality = item.get("modality")
        if modality == "sleep":
            if not _sleep_record_matches_local_date(item, target_key):
                continue
            payload = item.get("payload", {}) if isinstance(item.get("payload"), dict) else {}
            sleep_key = (
                payload.get("stage", ""),
                payload.get("startDate", ""),
                payload.get("endDate", ""),
            )
            if sleep_key in seen_sleep_keys:
                continue
            seen_sleep_keys.add(sleep_key)
            sensing.append(item)
            continue

        if _record_matches_local_date(item, target_key):
            sensing.append(item)
    narrations = [
        item for item in _load_json_array(DATA_FILES["/popo/narrations"])
        if _record_matches_local_date(item, target_key)
    ]
    nudges = [
        item for item in _load_json_array(DATA_FILES["/popo/nudges"])
        if _record_matches_local_date(item, target_key)
    ]
    food = [
        item for item in _load_json_array(DATA_FILES["/health-data/food"])
        if _record_matches_local_date(item, target_key, field="date")
    ]
    activities = [
        item for item in _load_json_array(DATA_FILES["/health-data/activity"])
        if _record_matches_local_date(item, target_key, field="date")
    ]
    weights = [
        item for item in _load_json_array(DATA_FILES["/health-data/weight"])
        if _record_matches_local_date(item, target_key, field="date")
    ]

    items = []  # type: List[Dict[str, Any]]
    total_steps = 0
    sleep_segments = 0
    total_sleep_hours = 0.0
    total_food_calories = 0
    total_activity_minutes = 0
    total_activity_calories = 0

    for event in sensing:
        dt = _parse_iso_datetime(event.get("timestamp", ""), assume_local_if_naive=True)
        if dt is None:
            continue
        local_dt = dt.astimezone(_get_local_timezone())
        modality = event.get("modality", "sensing")
        payload = event.get("payload", {}) if isinstance(event.get("payload"), dict) else {}

        detail = ""
        if modality == "steps":
            steps = payload.get("steps")
            if isinstance(steps, str) and steps.isdigit():
                total_steps = max(total_steps, int(steps))
            detail = str(steps or payload.get("count") or "")
        elif modality == "sleep":
            sleep_segments += 1
            start_dt = _parse_iso_datetime(payload.get("startDate", ""), assume_local_if_naive=False)
            end_dt = _parse_iso_datetime(payload.get("endDate", ""), assume_local_if_naive=False)
            if start_dt and end_dt:
                seconds = max(0.0, (end_dt - start_dt).total_seconds())
            else:
                duration = payload.get("duration")
                try:
                    seconds = float(duration) if duration is not None else 0.0
                except (TypeError, ValueError):
                    seconds = 0.0
            total_sleep_hours += seconds / 3600.0
            stage = payload.get("stage") or payload.get("state") or payload.get("value") or ""
            if seconds > 0:
                minutes = int(round(seconds / 60.0))
                detail = "%s (%d min)" % (stage, minutes)
            else:
                detail = stage
        elif modality == "heartRate":
            detail = "%s BPM" % payload.get("bpm", "?")
        elif modality == "motion":
            detail = payload.get("activityType") or payload.get("activity") or ""
        elif modality == "location":
            detail = (
                payload.get("description")
                or payload.get("semanticLabel")
                or payload.get("placeName")
                or ""
            )
        elif modality == "screen":
            detail = payload.get("state") or payload.get("event") or ""
        elif modality == "bloodOxygen":
            detail = "%s%% SpO2" % payload.get("spo2", "?")
        elif modality == "hrv":
            detail = "%s ms SDNN" % payload.get("sdnn", "?")
        elif modality == "respiratoryRate":
            detail = "%s breaths/min" % payload.get("breathsPerMin", "?")
        elif modality == "noiseExposure":
            detail = "%s dB" % payload.get("decibels", "?")
        elif modality == "activeEnergy":
            kcal = payload.get("kcal", "?")
            label = payload.get("hourLabel", "")
            detail = "%s kcal%s" % (kcal, (" (%s)" % label) if label else "")
        elif modality == "basalEnergy":
            kcal = payload.get("kcal", "?")
            label = payload.get("hourLabel", "")
            detail = "%s kcal resting%s" % (kcal, (" (%s)" % label) if label else "")
        elif modality == "workout":
            wtype = payload.get("type", "workout")
            dur = payload.get("duration", "?")
            cal = payload.get("calories", "?")
            detail = "%s — %ss, %s kcal" % (wtype, dur, cal)
        elif modality == "battery":
            detail = "%s%%" % payload.get("level", "?")
            if payload.get("charging") == "true" or payload.get("isCharging") == "true":
                detail += " (charging)"
        elif modality == "wifi":
            detail = payload.get("ssid", "?")
        elif modality == "bluetooth":
            detail = "%s devices" % payload.get("deviceCount", "?")
        elif modality == "visit":
            detail = payload.get("description") or payload.get("placeName") or "?"
        elif modality == "audio":
            detail = payload.get("text", payload.get("status", ""))[:80]
        elif modality == "photo":
            detail = "Photo" if payload.get("mediaType") != "video" else "Video"
        else:
            # Generic fallback — try common keys
            for key in ("summary", "value", "status", "description", "detail"):
                if payload.get(key):
                    detail = str(payload[key])
                    break

        items.append({
            "timestamp": dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            "localTime": local_dt.strftime("%I:%M %p").lstrip("0"),
            "kind": "sensing",
            "type": modality,
            "detail": detail,
            "source": "popo_sensing",
        })

    for narration in narrations:
        dt = _parse_iso_datetime(narration.get("timestamp", ""), assume_local_if_naive=True)
        if dt is None:
            continue
        local_dt = dt.astimezone(_get_local_timezone())
        transcript = narration.get("transcript", "")
        items.append({
            "timestamp": dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            "localTime": local_dt.strftime("%I:%M %p").lstrip("0"),
            "kind": "narration",
            "type": "voice" if narration.get("duration", 0) else "text",
            "detail": transcript,
            "source": "popo_narrations",
        })

    for nudge in nudges:
        dt = _parse_iso_datetime(nudge.get("timestamp", ""), assume_local_if_naive=True)
        if dt is None:
            continue
        local_dt = dt.astimezone(_get_local_timezone())
        items.append({
            "timestamp": dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            "localTime": local_dt.strftime("%I:%M %p").lstrip("0"),
            "kind": "nudge",
            "type": nudge.get("type", "insight"),
            "detail": nudge.get("content", ""),
            "trigger": nudge.get("trigger", ""),
            "source": "popo_nudges",
        })

    for meal in food:
        dt = _parse_iso_datetime(meal.get("date", ""), assume_local_if_naive=True)
        if dt is None:
            continue
        local_dt = dt.astimezone(_get_local_timezone())
        calories = meal.get("calories")
        if isinstance(calories, int):
            total_food_calories += calories
        items.append({
            "timestamp": dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            "localTime": local_dt.strftime("%I:%M %p").lstrip("0"),
            "kind": "meal",
            "type": meal.get("mealType", "meal"),
            "detail": meal.get("description", ""),
            "calories": calories,
            "source": "health_food",
        })

    for activity in activities:
        dt = _parse_iso_datetime(activity.get("date", ""), assume_local_if_naive=True)
        if dt is None:
            continue
        local_dt = dt.astimezone(_get_local_timezone())
        duration = activity.get("duration")
        calories = activity.get("caloriesBurned")
        if isinstance(duration, int):
            total_activity_minutes += duration
        if isinstance(calories, int):
            total_activity_calories += calories
        items.append({
            "timestamp": dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            "localTime": local_dt.strftime("%I:%M %p").lstrip("0"),
            "kind": "activity",
            "type": activity.get("type", "activity"),
            "detail": activity.get("aiSummary") or activity.get("note") or "",
            "duration": duration,
            "caloriesBurned": calories,
            "source": "health_activity",
        })

    for weight in weights:
        dt = _parse_iso_datetime(weight.get("date", ""), assume_local_if_naive=True)
        if dt is None:
            continue
        local_dt = dt.astimezone(_get_local_timezone())
        items.append({
            "timestamp": dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            "localTime": local_dt.strftime("%I:%M %p").lstrip("0"),
            "kind": "weight",
            "type": "weight",
            "detail": "%s kg" % weight.get("weight", ""),
            "source": "health_weight",
        })

    # Time-window dedup: match the iOS BoboViewModel.filteredSensingEvents logic.
    # Keep at most 1 event per interval for high-frequency modalities.
    # Steps are excluded from items (already in summary.totalSteps).
    _TIME_WINDOW = {
        "heartRate": 60,        # 1 per minute
        "hrv": 60,              # 1 per minute
        "activeEnergy": 300,    # 1 per 5 minutes
        "basalEnergy": 300,     # 1 per 5 minutes
        "respiratoryRate": 600, # 1 per 10 minutes
        "bloodOxygen": 60,      # 1 per minute
        "noiseExposure": 600,   # 1 per 10 minutes
        "bluetooth": 3600,      # 1 per hour
    }

    filtered_items = []
    last_kept_by_type = {}  # type: Dict[str, str]  # modality -> last kept timestamp

    # Sort items oldest-first for dedup, then reverse back
    items.sort(key=lambda item: item.get("timestamp", ""))

    for item in items:
        kind = item.get("kind", "")
        mtype = item.get("type", "")

        # Skip raw step events (shown in summary only)
        if kind == "sensing" and mtype == "steps":
            continue

        # Apply time-window dedup for high-frequency sensing types
        if kind == "sensing" and mtype in _TIME_WINDOW:
            window = _TIME_WINDOW[mtype]
            ts_str = item.get("timestamp", "")
            last_ts_str = last_kept_by_type.get(mtype)

            if last_ts_str and ts_str:
                try:
                    ts = _parse_iso_datetime(ts_str, assume_local_if_naive=True)
                    last_ts = _parse_iso_datetime(last_ts_str, assume_local_if_naive=True)
                    if ts and last_ts and (ts - last_ts).total_seconds() < window:
                        continue  # Within window — skip
                except (ValueError, TypeError):
                    pass

            last_kept_by_type[mtype] = ts_str

        filtered_items.append(item)

    filtered_items.sort(key=lambda item: item.get("timestamp", ""), reverse=True)

    return {
        "date": target_key,
        "timezone": _get_local_timezone_name(),
        "isToday": target_key == _local_date_string(datetime.now(_get_local_timezone())),
        "counts": {
            "sensing": len(sensing),
            "narrations": len(narrations),
            "nudges": len(nudges),
            "meals": len(food),
            "activities": len(activities),
            "weights": len(weights),
        },
        "summary": {
            "totalSteps": total_steps,
            "sleepSegments": sleep_segments,
            "sleepHours": round(total_sleep_hours, 2),
            "mealCalories": total_food_calories,
            "activityMinutes": total_activity_minutes,
            "activityCaloriesBurned": total_activity_calories,
            "stepGoal": STEP_COUNT_GOAL,
        },
        "items": filtered_items,
    }


def _build_range_bundle(start_date_str, end_date_str, days_str):
    # type: (Optional[str], Optional[str], Optional[str]) -> Dict[str, Any]
    """Build a compact multi-day BOBO range bundle for trend analysis."""
    local_tz = _get_local_timezone()
    today = datetime.now(local_tz).replace(hour=0, minute=0, second=0, microsecond=0)

    if days_str:
        days = int(str(days_str).strip())
        if days < 1 or days > 31:
            raise ValueError("days must be between 1 and 31")
        end_day = _parse_requested_local_date(end_date_str) if end_date_str else today
        start_day = end_day - timedelta(days=days - 1)
    else:
        start_day = _parse_requested_local_date(start_date_str) if start_date_str else today - timedelta(days=6)
        end_day = _parse_requested_local_date(end_date_str) if end_date_str else today

    if start_day > end_day:
        start_day, end_day = end_day, start_day

    span_days = (end_day - start_day).days + 1
    if span_days > 31:
        raise ValueError("range too large")

    days = []
    totals = {
        "sensing": 0,
        "narrations": 0,
        "nudges": 0,
        "meals": 0,
        "activities": 0,
        "weights": 0,
        "totalSteps": 0,
        "sleepHours": 0.0,
        "mealCalories": 0,
        "activityMinutes": 0,
        "activityCaloriesBurned": 0,
        "stepGoal": STEP_COUNT_GOAL,
    }

    cursor = start_day
    while cursor <= end_day:
        date_key = cursor.strftime("%Y-%m-%d")
        bundle = _build_day_bundle(date_key)
        days.append({
            "date": bundle["date"],
            "isToday": bundle["isToday"],
            "counts": bundle["counts"],
            "summary": bundle["summary"],
        })
        totals["sensing"] += bundle["counts"]["sensing"]
        totals["narrations"] += bundle["counts"]["narrations"]
        totals["nudges"] += bundle["counts"]["nudges"]
        totals["meals"] += bundle["counts"]["meals"]
        totals["activities"] += bundle["counts"]["activities"]
        totals["weights"] += bundle["counts"]["weights"]
        totals["totalSteps"] += bundle["summary"]["totalSteps"]
        totals["sleepHours"] += bundle["summary"]["sleepHours"]
        totals["mealCalories"] += bundle["summary"]["mealCalories"]
        totals["activityMinutes"] += bundle["summary"]["activityMinutes"]
        totals["activityCaloriesBurned"] += bundle["summary"]["activityCaloriesBurned"]
        cursor += timedelta(days=1)

    return {
        "startDate": start_day.strftime("%Y-%m-%d"),
        "endDate": end_day.strftime("%Y-%m-%d"),
        "timezone": _get_local_timezone_name(),
        "dayCount": span_days,
        "totals": {
            **totals,
            "sleepHours": round(totals["sleepHours"], 2),
            "averageSleepHours": round(totals["sleepHours"] / span_days, 2),
            "averageSteps": round(totals["totalSteps"] / span_days, 1),
        },
        "days": days,
    }


# ---------------------------------------------------------------------------
# HTTP Handler
# ---------------------------------------------------------------------------

_BRIDGE_AUTH_TOKEN = os.environ.get("BRIDGE_AUTH_TOKEN", "")


class BridgeHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler for all RyanHub bridge endpoints."""

    def _check_auth(self) -> bool:
        """Validate Authorization header if BRIDGE_AUTH_TOKEN is set.
        Returns True if authorized (or no token configured)."""
        if not _BRIDGE_AUTH_TOKEN:
            return True  # No auth configured — open access
        auth = self.headers.get("Authorization", "")
        if auth == f"Bearer {_BRIDGE_AUTH_TOKEN}" or auth == _BRIDGE_AUTH_TOKEN:
            return True
        # Allow localhost without auth (bridge server queries itself)
        client_ip = self.client_address[0]
        if client_ip in ("127.0.0.1", "::1", "localhost"):
            return True
        self._send_json(401, {"error": "Unauthorized"})
        return False

    def do_GET(self):
        if not self._check_auth():
            return
        parsed = urlparse(self.path)
        path = parsed.path
        # Alias /bobo/ → /popo/ after iOS module rename
        if path.startswith("/bobo/"):
            path = "/popo/" + path[len("/bobo/"):]
        if path == "/health":
            self._send_json(200, {"status": "ok"})
        elif path in PARKING_FILES:
            self._serve_parking_file(path)
        elif path == "/popo/timeline":
            self._serve_timeline()
        elif path == "/popo/timeline/today":
            self._serve_timeline(today_only=True)
        elif path == "/popo/latest":
            query = parse_qs(parsed.query)
            self._serve_latest(query.get("types", [None])[0])
        elif path == "/popo/day":
            query = parse_qs(parsed.query)
            self._serve_day_bundle(query.get("date", [None])[0])
        elif path == "/popo/range":
            query = parse_qs(parsed.query)
            self._serve_range_bundle(
                query.get("start", [None])[0],
                query.get("end", [None])[0],
                query.get("days", [None])[0],
            )
        elif path.startswith("/popo/audio/"):
            self._serve_audio_file(path)
        elif path in DATA_FILES and path.startswith("/popo/"):
            query = parse_qs(parsed.query)
            date_filter = query.get("date", [None])[0]
            self._serve_popo_data(path, date_filter)
        elif path in DATA_FILES:
            self._serve_data_file(path)
        else:
            # Dynamic module data: GET /modules/<id>/data
            module_match = re.match(r'^/modules/([a-zA-Z0-9_-]+)/data$', path)
            if module_match:
                module_id = module_match.group(1)
                filepath = os.path.join(BRIDGE_DATA_DIR, f"module_{module_id}.json")
                self._serve_module_data_file(filepath)
            else:
                self._send_json(404, {"error": "Not found"})

    def do_POST(self):
        if not self._check_auth():
            return
        path = urlparse(self.path).path
        # Alias /bobo/ → /popo/ after iOS module rename
        if path.startswith("/bobo/"):
            path = "/popo/" + path[len("/bobo/"):]

        # Parking skip-dates write
        if path == "/parking/skip-dates":
            self._write_parking_skip_dates()
            return

        # POPO audio upload
        if path == "/popo/audio":
            self._handle_audio_upload()
            return

        # POPO photo upload (from RB Meta glasses / iPhone camera)
        if path == "/popo/photos/upload":
            self._handle_photo_upload()
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

        # POPO behavioral analysis (nudge generation)
        if path == "/popo/analyze":
            self._handle_behavioral_analysis()
            return

        # POPO background nudge check (server-side generation)
        if path == "/popo/nudge-check":
            self._handle_nudge_check()
            return

        # Health data single-entry append (for chat agent)
        _ADD_ENDPOINTS = {
            "/health-data/weight/add": "/health-data/weight",
            "/health-data/food/add": "/health-data/food",
            "/health-data/activity/add": "/health-data/activity",
        }
        if path in _ADD_ENDPOINTS:
            self._append_health_entry(_ADD_ENDPOINTS[path])
            return

        # BoBo processed timeline snapshot (overwrite)
        if path == "/popo/timeline":
            self._write_timeline()
            return
        if path == "/popo/timeline/today":
            self._write_timeline(today_only=True)
            return

        # Chat message single-entry append (for cross-channel sync)
        if path == "/chat/messages/add":
            self._append_chat_message()
            return

        # BoBo narration single-entry append (for chat agent)
        if path == "/popo/narrations/add":
            self._append_narration_entry()
            return

        # Dynamic module data: POST /modules/<id>/data or /modules/<id>/data/add
        module_match = re.match(r'^/modules/([a-zA-Z0-9_-]+)/data(/add)?$', path)
        if module_match:
            module_id = module_match.group(1)
            is_add = module_match.group(2) == "/add"
            filepath = os.path.join(BRIDGE_DATA_DIR, f"module_{module_id}.json")
            if is_add:
                self._append_module_entry(filepath)
            else:
                self._write_module_data_file(filepath)
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
        parsed = urlparse(self.path)
        path = parsed.path
        if path in DATA_FILES:
            filepath = DATA_FILES[path]
            query = parse_qs(parsed.query)
            entry_id = query.get("id", [None])[0]
            if entry_id:
                self._delete_data_entry(filepath, entry_id, path)
            else:
                if os.path.exists(filepath):
                    os.remove(filepath)
                self._send_json(200, {"ok": True})
        else:
            # Dynamic module data: DELETE /modules/<id>/data?id=<entry_id>
            module_match = re.match(r'^/modules/([a-zA-Z0-9_-]+)/data$', path)
            if module_match:
                module_id = module_match.group(1)
                filepath = os.path.join(BRIDGE_DATA_DIR, f"module_{module_id}.json")
                query = parse_qs(parsed.query)
                entry_id = query.get("id", [None])[0]
                self._delete_module_entry(filepath, entry_id)
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
        sync works correctly (no data loss from concurrent writes).
        For /popo/narrations, acquires _narrations_file_lock to prevent
        conflicts with background analysis updates."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            incoming = json.loads(body) if body else []
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid body: {e}"})
            return

        filepath = DATA_FILES[path]

        # Use narrations file lock for /popo/narrations to prevent conflicts
        # with update_narration_with_analysis running in background threads.
        lock = _narrations_file_lock if path == "/popo/narrations" else None
        if lock:
            lock.acquire()

        try:
            self._merge_and_write(filepath, incoming, path)
        finally:
            if lock:
                lock.release()

    def _merge_and_write(self, filepath, incoming, path):
        """Internal helper: merge incoming data with existing file and write."""
        # Chat history is a full-snapshot sync from the app.
        # Use overwrite semantics so deletions propagate to server storage.
        if path == "/chat/messages":
            data = incoming
            try:
                with open(filepath, "w") as f:
                    json.dump(data, f, ensure_ascii=False)
                self._send_json(200, {"ok": True, "count": len(data) if isinstance(data, list) else 1})
            except IOError as e:
                self._send_json(500, {"error": f"Failed to write: {e}"})
            return

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
        # IMPORTANT: for narrations, preserve server-side fields (transcript,
        # affectAnalysis) that the iOS client may not have yet. Only override
        # if the incoming entry has a non-empty transcript.
        if isinstance(incoming, list) and isinstance(existing, list):
            merged = {}
            for item in existing:
                if isinstance(item, dict) and "id" in item:
                    merged[item["id"]] = item
            for item in incoming:
                if isinstance(item, dict) and "id" in item:
                    item_id = item["id"]
                    if path == "/popo/narrations" and item_id in merged:
                        # Preserve server-side transcript and affect if the
                        # incoming entry has empty/missing transcript
                        existing_item = merged[item_id]
                        if (not item.get("transcript")
                                and existing_item.get("transcript")):
                            item["transcript"] = existing_item["transcript"]
                        if (not item.get("affectAnalysis")
                                and existing_item.get("affectAnalysis")):
                            item["affectAnalysis"] = existing_item["affectAnalysis"]
                        if (not item.get("extractedMood")
                                and existing_item.get("extractedMood")):
                            item["extractedMood"] = existing_item["extractedMood"]
                    merged[item_id] = item
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
    # Health data single-entry append (for chat agent use)
    # -----------------------------------------------------------------------

    def _append_health_entry(self, data_path):
        """Append a single health entry to the data file.

        Accepts a single JSON object (not an array). Generates an 'id' if
        missing and adds 'date' defaulting to now if missing. Merges into
        the existing array by id (so re-posting the same id is an upsert).
        """
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            entry = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid body: {e}"})
            return

        if not isinstance(entry, dict):
            self._send_json(400, {"error": "Expected a JSON object, not an array"})
            return

        # Auto-generate id if missing
        if "id" not in entry:
            import uuid
            entry["id"] = str(uuid.uuid4()).upper()

        # Auto-add date if missing (ISO 8601)
        if "date" not in entry:
            from datetime import datetime, timezone
            entry["date"] = datetime.now(timezone.utc).isoformat()

        filepath = DATA_FILES[data_path]

        # Load existing data
        existing = []
        if os.path.exists(filepath):
            try:
                with open(filepath, "r") as f:
                    content = f.read()
                existing = json.loads(content) if content.strip() else []
            except (json.JSONDecodeError, IOError):
                existing = []

        # Merge by id (upsert)
        merged = {}
        for item in existing:
            if isinstance(item, dict) and "id" in item:
                merged[item["id"]] = item
        merged[entry["id"]] = entry
        data = list(merged.values())

        try:
            with open(filepath, "w") as f:
                json.dump(data, f, ensure_ascii=False)
            self._send_json(200, {"ok": True, "id": entry["id"], "count": len(data)})
        except IOError as e:
            self._send_json(500, {"error": f"Failed to write: {e}"})

    # -----------------------------------------------------------------------
    # Dynamic module data endpoints
    # -----------------------------------------------------------------------

    def _serve_module_data_file(self, filepath):
        """Serve a dynamic module JSON data file. Returns [] if file doesn't exist."""
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

    def _write_module_data_file(self, filepath):
        """Overwrite a dynamic module JSON data file with the request body."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else []
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid body: {e}"})
            return

        try:
            with open(filepath, "w") as f:
                json.dump(data, f, ensure_ascii=False)
            count = len(data) if isinstance(data, list) else 1
            self._send_json(200, {"ok": True, "count": count})
        except IOError as e:
            self._send_json(500, {"error": f"Failed to write: {e}"})

    def _append_module_entry(self, filepath):
        """Append a single JSON object to a dynamic module data file.

        Accepts a single JSON object (not an array). Generates an 'id' if
        missing and adds 'date' defaulting to now if missing. Merges into
        the existing array by id (upsert).
        """
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            entry = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid body: {e}"})
            return

        if not isinstance(entry, dict):
            self._send_json(400, {"error": "Expected a JSON object, not an array"})
            return

        # Auto-generate id if missing
        if "id" not in entry:
            entry["id"] = str(uuid.uuid4()).upper()

        # Auto-add date if missing (ISO 8601)
        if "date" not in entry:
            entry["date"] = datetime.now(timezone.utc).isoformat()

        # Load existing data
        existing = []
        if os.path.exists(filepath):
            try:
                with open(filepath, "r") as f:
                    content = f.read()
                existing = json.loads(content) if content.strip() else []
            except (json.JSONDecodeError, IOError):
                existing = []

        # Merge by id (upsert)
        merged = {}
        for item in existing:
            if isinstance(item, dict) and "id" in item:
                merged[item["id"]] = item
        merged[entry["id"]] = entry
        data = list(merged.values())

        try:
            with open(filepath, "w") as f:
                json.dump(data, f, ensure_ascii=False)
            self._send_json(200, {"ok": True, "id": entry["id"], "count": len(data)})
        except IOError as e:
            self._send_json(500, {"error": f"Failed to write: {e}"})

    def _delete_module_entry(self, filepath, entry_id):
        """Delete a specific entry by id from a dynamic module data file."""
        if not entry_id:
            self._send_json(400, {"error": "Missing 'id' query parameter"})
            return

        if not os.path.exists(filepath):
            self._send_json(404, {"error": "Entry not found"})
            return

        try:
            with open(filepath, "r") as f:
                content = f.read()
            data = json.loads(content) if content.strip() else []
        except (json.JSONDecodeError, IOError):
            data = []

        original_count = len(data)
        data = [item for item in data if not (isinstance(item, dict) and item.get("id") == entry_id)]

        if len(data) == original_count:
            self._send_json(404, {"error": "Entry not found"})
            return

        try:
            with open(filepath, "w") as f:
                json.dump(data, f, ensure_ascii=False)
            self._send_json(200, {"ok": True, "count": len(data)})
        except IOError as e:
            self._send_json(500, {"error": f"Failed to write: {e}"})

    def _delete_data_entry(self, filepath, entry_id, path):
        """Delete a specific entry by id from a built-in data file."""
        if not entry_id:
            self._send_json(400, {"error": "Missing 'id' query parameter"})
            return

        lock = _narrations_file_lock if path == "/popo/narrations" else None
        if lock:
            lock.acquire()

        try:
            self._delete_module_entry(filepath, entry_id)
        finally:
            if lock:
                lock.release()

    def _serve_timeline(self, today_only=False):
        # type: (bool) -> None
        """Serve a processed timeline snapshot from the iOS app."""
        timeline_file = POPO_TODAY_TIMELINE_FILE if today_only else POPO_TIMELINE_FILE
        if not os.path.exists(timeline_file):
            self._send_json(200, {"date": "", "totalEvents": 0, "summary": {}, "items": []})
            return
        try:
            with open(timeline_file, "r") as f:
                data = json.load(f)
            self._send_json(200, data)
        except (IOError, json.JSONDecodeError) as e:
            self._send_json(500, {"error": f"Failed to read timeline: {e}"})

    def _write_timeline(self, today_only=False):
        # type: (bool) -> None
        """Store a processed timeline snapshot from the iOS app."""
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length) if length else b""
            data = json.loads(body) if body else {}
            timeline_file = POPO_TODAY_TIMELINE_FILE if today_only else POPO_TIMELINE_FILE
            with open(timeline_file, "w") as f:
                json.dump(data, f, ensure_ascii=False)
            count = len(data.get("items", []))
            self._send_json(200, {"ok": True, "items": count})
        except (json.JSONDecodeError, IOError) as e:
            self._send_json(500, {"error": f"Failed to write timeline: {e}"})

    def _serve_latest(self, types_filter=None):
        # type: (Optional[str]) -> None
        """Return the most recent event per modality from today's sensing data.

        Optional ?types=heartRate,steps,bloodOxygen to filter specific modalities.
        Much lighter than /bobo/day for quick "what's my current heart rate?" queries.
        """
        raw = _load_json_array(DATA_FILES["/popo/sensing"])
        today_key = _local_date_string(datetime.now(_get_local_timezone()))

        # Filter to today
        today_events = [e for e in raw if isinstance(e, dict) and _record_matches_local_date(e, today_key)]

        # Optional type filter
        requested_types = None
        if types_filter:
            requested_types = set(t.strip() for t in types_filter.split(","))

        # Find latest per modality
        latest_by_type = {}  # type: Dict[str, Dict]
        for event in today_events:
            modality = event.get("modality", "")
            if requested_types and modality not in requested_types:
                continue
            ts = event.get("timestamp", "")
            if modality not in latest_by_type or ts > latest_by_type[modality].get("timestamp", ""):
                latest_by_type[modality] = event

        # Format output
        items = []
        for modality, event in sorted(latest_by_type.items()):
            dt = _parse_iso_datetime(event.get("timestamp", ""), assume_local_if_naive=True)
            local_time = dt.astimezone(_get_local_timezone()).strftime("%I:%M %p").lstrip("0") if dt else "?"
            payload = event.get("payload", {}) if isinstance(event.get("payload"), dict) else {}

            detail = ""
            if modality == "heartRate":
                detail = "%s BPM" % payload.get("bpm", "?")
            elif modality == "steps":
                detail = "%s steps" % payload.get("steps", "?")
            elif modality == "bloodOxygen":
                detail = "%s%% SpO2" % payload.get("spo2", "?")
            elif modality == "hrv":
                detail = "%s ms SDNN" % payload.get("sdnn", "?")
            elif modality == "motion":
                detail = payload.get("activityType", "?")
            elif modality == "battery":
                detail = "%s%%" % payload.get("level", "?")
            elif modality == "location":
                detail = payload.get("description") or payload.get("placeName") or payload.get("address") or "?"
            else:
                detail = str(list(payload.values())[:2]) if payload else "?"

            items.append({
                "type": modality,
                "localTime": local_time,
                "detail": detail,
                "timestamp": event.get("timestamp", ""),
            })

        self._send_json(200, {
            "date": today_key,
            "count": len(items),
            "items": items,
        })

    def _serve_day_bundle(self, date_filter):
        # type: (Optional[str]) -> None
        """Serve a date-scoped BOBO day bundle for chat and external agents."""
        try:
            bundle = _build_day_bundle(date_filter)
            self._send_json(200, bundle)
        except ValueError:
            self._send_json(400, {"error": "Invalid date. Use YYYY-MM-DD, today, or yesterday."})

    def _serve_range_bundle(self, start_date, end_date, days):
        # type: (Optional[str], Optional[str], Optional[str]) -> None
        """Serve a compact multi-day BOBO range bundle."""
        try:
            bundle = _build_range_bundle(start_date, end_date, days)
            self._send_json(200, bundle)
        except ValueError:
            self._send_json(400, {"error": "Invalid range. Use days=1..31 or start/end with YYYY-MM-DD, today, or yesterday."})

    def _append_chat_message(self):
        """Append a single chat message for cross-channel sync.

        Accepts a JSON object with: role, content, and optionally source, id, timestamp.
        Merges into chat_messages.json by id (upsert).
        Used by the Dispatcher to sync messages from both iOS and Telegram channels."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            entry = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid body: {e}"})
            return

        if not isinstance(entry, dict):
            self._send_json(400, {"error": "Expected a JSON object"})
            return

        if not entry.get("content") and not entry.get("text"):
            self._send_json(400, {"error": "Missing required field: content"})
            return

        if "id" not in entry:
            entry["id"] = str(uuid.uuid4()).upper()
        if "timestamp" not in entry:
            entry["timestamp"] = datetime.now(timezone.utc).isoformat()
        entry.setdefault("role", "user")
        entry.setdefault("source", "unknown")

        filepath = DATA_FILES.get("/chat/messages")
        if not filepath:
            self._send_json(500, {"error": "Chat data path not configured"})
            return

        existing = []
        if os.path.exists(filepath):
            try:
                with open(filepath, "r") as f:
                    content = f.read()
                existing = json.loads(content) if content.strip() else []
            except (json.JSONDecodeError, IOError):
                existing = []

        # Merge by id (upsert)
        merged = {}
        for item in existing:
            if isinstance(item, dict) and "id" in item:
                merged[item["id"]] = item
        merged[entry["id"]] = entry

        try:
            with open(filepath, "w") as f:
                json.dump(list(merged.values()), f, ensure_ascii=False)
            self._send_json(200, {"ok": True, "id": entry["id"]})
        except IOError as e:
            self._send_json(500, {"error": f"Failed to write: {e}"})

    def _append_narration_entry(self):
        """Append a single narration entry (for chat agent adding text diary).

        Accepts a JSON object with at least 'transcript'. Generates 'id' and
        'timestamp' if missing. Sets duration=0 (text entry, no audio).
        Merges into the narrations file by id."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            entry = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid body: {e}"})
            return

        if not isinstance(entry, dict):
            self._send_json(400, {"error": "Expected a JSON object"})
            return

        if not entry.get("transcript"):
            self._send_json(400, {"error": "Missing required field: transcript"})
            return

        import uuid
        from datetime import datetime, timezone

        if "id" not in entry:
            entry["id"] = str(uuid.uuid4()).upper()
        if "timestamp" not in entry:
            entry["timestamp"] = datetime.now(timezone.utc).isoformat()
        entry.setdefault("duration", 0)
        entry.setdefault("transcript", "")

        filepath = DATA_FILES.get("/popo/narrations")
        if not filepath:
            self._send_json(500, {"error": "Narrations data path not configured"})
            return

        with _narrations_file_lock:
            existing = []
            if os.path.exists(filepath):
                try:
                    with open(filepath, "r") as f:
                        content = f.read()
                    existing = json.loads(content) if content.strip() else []
                except (json.JSONDecodeError, IOError):
                    existing = []

            merged = {}
            for item in existing:
                if isinstance(item, dict) and "id" in item:
                    merged[item["id"]] = item
            merged[entry["id"]] = entry

            try:
                with open(filepath, "w") as f:
                    json.dump(list(merged.values()), f, ensure_ascii=False)
                self._send_json(200, {"ok": True, "id": entry["id"]})
            except IOError as e:
                self._send_json(500, {"error": f"Failed to write: {e}"})

    # -----------------------------------------------------------------------
    # POPO data endpoints
    # -----------------------------------------------------------------------

    def _serve_popo_data(self, path, date_filter=None):
        """Serve a POPO JSON data file, optionally filtered by date.
        date_filter should be 'YYYY-MM-DD' or None for all data."""
        filepath = DATA_FILES[path]
        data = _load_json_array(filepath)

        if date_filter and isinstance(data, list):
            # For daily-summary, match on the 'date' field directly
            if path == "/popo/daily-summary":
                data = [
                    item for item in data
                    if isinstance(item, dict) and item.get("date", "") == date_filter
                ]
            else:
                # For other POPO data, match the record's local calendar day.
                data = [
                    item for item in data
                    if isinstance(item, dict)
                    and _record_matches_local_date(item, date_filter)
                ]

        self._send_json(200, data)

    def _handle_photo_upload(self):
        """Accept a multipart/form-data photo upload from RB Meta and save to iMac.
        Fields: event_id, source, photo (JPEG file)."""
        import re
        try:
            content_type = self.headers.get("Content-Type", "")
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length == 0:
                self._send_json(400, {"error": "Empty request body"})
                return

            body = self.rfile.read(content_length)

            # Parse multipart boundary
            boundary_match = re.search(r"boundary=(.+)", content_type)
            if not boundary_match:
                self._send_json(400, {"error": "Missing multipart boundary"})
                return
            boundary = boundary_match.group(1).encode()

            # Simple multipart parser
            parts = body.split(b"--" + boundary)
            event_id = None
            source = None
            photo_data = None

            for part in parts:
                if b"Content-Disposition" not in part:
                    continue
                header_end = part.find(b"\r\n\r\n")
                if header_end < 0:
                    continue
                header = part[:header_end].decode("utf-8", errors="replace")
                data = part[header_end + 4:]
                # Strip trailing \r\n
                if data.endswith(b"\r\n"):
                    data = data[:-2]

                if 'name="event_id"' in header:
                    event_id = data.decode().strip()
                elif 'name="source"' in header:
                    source = data.decode().strip()
                elif 'name="photo"' in header:
                    photo_data = data

            if not event_id or photo_data is None:
                self._send_json(400, {"error": "Missing event_id or photo data"})
                return

            # Save organized by date
            from datetime import datetime
            date_dir = datetime.now().strftime("%Y-%m-%d")
            save_dir = os.path.join(POPO_PHOTOS_DIR, date_dir)
            os.makedirs(save_dir, exist_ok=True)

            filename = "%s.jpg" % event_id
            filepath = os.path.join(save_dir, filename)
            with open(filepath, "wb") as f:
                f.write(photo_data)

            print("[Photos] Saved %s from %s (%d bytes) → %s" % (
                event_id, source or "unknown", len(photo_data), filepath))

            self._send_json(200, {
                "ok": True,
                "event_id": event_id,
                "source": source,
                "size": len(photo_data),
                "path": filepath,
            })
        except Exception as e:
            print("[Photos] Upload error: %s" % e)
            self._send_json(500, {"error": "Photo upload failed: %s" % e})

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

            # Background analysis removed from audio upload. The iOS client
            # sends an explicit POST /popo/narrations/analyze after upload,
            # which is the primary transcription path. Running Whisper here
            # caused race conditions (concurrent model inference, file writes)
            # and double-transcription waste.
            narration_id = self.headers.get("X-Narration-Id")
            if narration_id:
                response_data["narration_id"] = narration_id

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
        """Transcribe and analyze emotional affect from a narration.

        Supports two modes:
        1. Audio mode: JSON body with 'filename' (and optionally 'narration_id').
           Runs Whisper transcription then affect analysis.
        2. Text-only mode: JSON body with 'transcript' and 'text_only'='true'.
           Skips Whisper, runs affect analysis directly on the provided text.
        """
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": "Invalid request body: %s" % e})
            return

        narration_id = data.get("narration_id")

        # --- Text-only mode: skip Whisper, run affect on provided transcript ---
        if data.get("text_only") == "true":
            transcript = data.get("transcript", "").strip()
            if not transcript:
                self._send_json(400, {"error": "Missing 'transcript' for text_only analysis"})
                return

            result = {
                "narration_id": narration_id,
                "transcript": transcript,
                "affect": None,
                "status": "text_only"
            }

            affect = analyze_affect(transcript)
            if affect:
                result["affect"] = affect
                result["status"] = "analyzed"

            if narration_id and result.get("status") == "analyzed":
                update_narration_with_analysis(narration_id, result)

            self._send_json(200, result)
            return

        # --- Audio mode: require filename, run Whisper + affect ---
        filename = data.get("filename")

        if not filename:
            self._send_json(400, {"error": "Missing 'filename' in request body"})
            return

        # Sanitize and locate the audio file
        filename = os.path.basename(filename)
        audio_path = os.path.join(POPO_AUDIO_DIR, filename)

        if not os.path.exists(audio_path):
            self._send_json(404, {"error": "Audio file not found: %s" % filename})
            return

        # Run the analysis pipeline (transcription forwarded to diarization server)
        try:
            result = run_narration_analysis(audio_path, narration_id)

            # If we have a narration_id, update the stored narration entry
            if narration_id and result.get("status") in ("transcribed", "analyzed"):
                update_narration_with_analysis(narration_id, result)

            self._send_json(200, result)
        except Exception as e:
            self._send_json(500, {"error": "Analysis failed: %s" % e})

    # -----------------------------------------------------------------------
    # Behavioral analysis endpoint (nudge generation)
    # -----------------------------------------------------------------------

    def _handle_behavioral_analysis(self):
        """Analyze behavioral sensing data and generate proactive nudges.
        Uses Claude API (haiku) when available, falls back to rule-based system.

        Expects JSON body:
        {
            "sensing_events": [...],  // Recent sensing events (last 6 hours)
            "narrations": [...],      // Recent narrations with transcripts and affect
            "daily_summary": {...}    // Optional aggregated stats
        }
        """
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": "Invalid request body: %s" % e})
            return

        # Accept both key formats for backwards compatibility (iOS sends "events"/"day_summary")
        sensing_events = data.get("sensing_events", data.get("events", []))
        narrations = data.get("narrations", [])
        daily_summary = data.get("daily_summary", data.get("day_summary"))

        if not isinstance(sensing_events, list):
            sensing_events = []
        if not isinstance(narrations, list):
            narrations = []

        print("[Analyze] Received %d sensing events, %d narrations" %
              (len(sensing_events), len(narrations)))

        # Step 1: Summarize the sensing data
        summary_text = summarize_sensing_data(sensing_events, narrations, daily_summary)
        print("[Analyze] Summary:\n%s" % summary_text[:500])

        # Step 2: Generate nudges via Claude CLI
        method_used = "none"
        raw_nudges = None

        raw_nudges = generate_nudges_llm(summary_text, timeout=20)
        if raw_nudges:
            method_used = "llm"
            print("[Analyze] Generated %d nudges via LLM" % len(raw_nudges))
        else:
            raw_nudges = generate_nudges_rule_based(sensing_events, narrations, daily_summary)
            method_used = "rule_based_fallback"
            print("[Analyze] Falling back to rule-based nudges (%d)" % len(raw_nudges))

        # Step 3: Normalize nudge records (add id, timestamp, validate fields)
        now_iso = _now_utc_iso()
        nudge_records = []
        for raw in raw_nudges:
            if not isinstance(raw, dict):
                continue
            nudge = {
                "id": str(uuid.uuid4()),
                "timestamp": now_iso,
                "type": raw.get("type", "insight"),
                "content": raw.get("content", ""),
                "trigger": raw.get("trigger", "unknown"),
                "priority": raw.get("priority", "normal"),
                "relatedModalities": raw.get("relatedModalities", []),
            }
            # Validate type
            if nudge["type"] not in ("insight", "reminder", "encouragement", "alert"):
                nudge["type"] = "insight"
            # Validate priority
            if nudge["priority"] not in ("normal", "high"):
                nudge["priority"] = "normal"
            # Ensure relatedModalities is a list
            if not isinstance(nudge["relatedModalities"], list):
                nudge["relatedModalities"] = []
            nudge_records.append(nudge)

        # Step 4: Store the nudges
        if nudge_records:
            store_generated_nudges(nudge_records)

        self._send_json(200, {
            "ok": True,
            "nudges": nudge_records,
            "method": method_used,
            "summary_length": len(summary_text),
        })

    # -----------------------------------------------------------------------
    # Background nudge check (server-side generation)
    # -----------------------------------------------------------------------

    def _handle_nudge_check(self):
        """Generate nudges server-side if >2 hours since last generation.
        Uses the full /bobo/day bundle for today to give the LLM complete context.
        Used by iOS background sync task and proactive heartbeat."""
        timestamp_file = os.path.join(BRIDGE_DATA_DIR, "popo_last_nudge_gen.txt")

        # Check if enough time has passed since last generation
        last_gen = 0
        if os.path.exists(timestamp_file):
            try:
                with open(timestamp_file, "r") as f:
                    last_gen = float(f.read().strip())
            except (ValueError, IOError):
                last_gen = 0

        elapsed = time.time() - last_gen
        if elapsed < 7200:  # 2 hours
            self._send_json(200, {"ok": True, "nudges": [], "skipped": True,
                                  "seconds_until_next": int(7200 - elapsed)})
            return

        # Use the full day bundle — same data the user sees in the timeline.
        # This gives the LLM complete context: sensing + food + activity + sleep + narrations.
        try:
            day_bundle = _build_day_bundle("today")
        except Exception:
            day_bundle = None

        if not day_bundle or day_bundle.get("counts", {}).get("sensing", 0) == 0:
            self._send_json(200, {"ok": True, "nudges": [], "skipped": True,
                                  "reason": "no_data"})
            return

        # Build a rich summary from the day bundle
        summary_parts = []
        summary_parts.append("=== Today's Full Day Bundle ===")
        summary_parts.append("Date: %s | Timezone: %s" % (day_bundle.get("date"), day_bundle.get("timezone")))
        summary_parts.append("Counts: %s" % json.dumps(day_bundle.get("counts", {})))
        summary_parts.append("Summary: %s" % json.dumps(day_bundle.get("summary", {})))
        summary_parts.append("")

        # Include timeline items (already filtered/deduped by _build_day_bundle)
        items = day_bundle.get("items", [])
        summary_parts.append("Timeline (%d items, newest first):" % len(items))
        for item in items[:150]:  # Cap at 150 most recent for token efficiency
            ts = item.get("localTime", "?")
            kind = item.get("kind", "?")
            itype = item.get("type", "?")
            detail = item.get("detail", "")
            if kind == "sensing":
                summary_parts.append("  [%s] %s: %s" % (ts, itype, detail))
            elif kind == "meal":
                cal = item.get("calories", "?")
                summary_parts.append("  [%s] MEAL (%s): %s (%s cal)" % (ts, itype, detail, cal))
            elif kind == "activity":
                dur = item.get("duration", "?")
                cal = item.get("caloriesBurned", "?")
                summary_parts.append("  [%s] ACTIVITY (%s): %s (%s min, %s cal)" % (ts, itype, detail, dur, cal))
            elif kind == "narration":
                summary_parts.append("  [%s] DIARY: %s" % (ts, detail[:100]))
            elif kind == "weight":
                summary_parts.append("  [%s] WEIGHT: %s" % (ts, detail))

        summary_text = "\n".join(summary_parts)
        print("[NudgeCheck] Processing day bundle: %d items, summary %d chars" % (len(items), len(summary_text)))

        raw_nudges = generate_nudges_llm(summary_text, timeout=30)
        if not raw_nudges:
            raw_nudges = generate_nudges_rule_based(events, narrations)

        if raw_nudges is None:
            self._send_json(500, {"ok": False, "error": "LLM generation failed", "nudges": []})
            return

        # Normalize nudge records
        now_iso = _now_utc_iso()
        nudge_records = []
        for raw in raw_nudges:
            if not isinstance(raw, dict):
                continue
            nudge = {
                "id": str(uuid.uuid4()),
                "timestamp": now_iso,
                "type": raw.get("type", "insight"),
                "content": raw.get("content", ""),
                "trigger": raw.get("trigger", "background_check"),
                "priority": raw.get("priority", "normal"),
                "relatedModalities": raw.get("relatedModalities", []),
            }
            if nudge["type"] not in ("insight", "reminder", "encouragement", "alert"):
                nudge["type"] = "insight"
            if nudge["priority"] not in ("normal", "high"):
                nudge["priority"] = "normal"
            if not isinstance(nudge["relatedModalities"], list):
                nudge["relatedModalities"] = []
            nudge_records.append(nudge)

        # Store nudges and update timestamp
        if nudge_records:
            store_generated_nudges(nudge_records)
        with open(timestamp_file, "w") as f:
            f.write(str(time.time()))

        print("[NudgeCheck] Generated %d nudges in background" % len(nudge_records))
        self._send_json(200, {"ok": True, "nudges": nudge_records})

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

    # Use ThreadingHTTPServer so the server can accept new requests while
    # a long-running handler (e.g. remote transcription, Claude analysis) is processing.
    # Without threading, a long call blocks ALL other requests.
    server = http.server.ThreadingHTTPServer((HOST, PORT), BridgeHandler)
    print(f"RyanHub Bridge Server listening on http://{HOST}:{PORT}")
    print(f"Data directory: {BRIDGE_DATA_DIR}")
    if os.path.isfile(CLAUDE_PATH):
        print(f"Claude CLI: {CLAUDE_PATH}")
    print(f"Whisper: via diarization server ({DIARIZATION_SERVER_URL})")
    if SENTIMENT_AVAILABLE:
        print("Local emotion model: available (affect analysis enabled)")
    else:
        print("Local emotion model: not available (affect analysis disabled)")
    if GOOGLE_MAPS_API_KEY:
        print("Google Maps API: configured (location enrichment enabled)")
    print("Claude CLI: nudge generation via Max Plan (%s)" % CLAUDE_PATH)
    print("Press Ctrl+C to stop.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.shutdown()


if __name__ == "__main__":
    main()
