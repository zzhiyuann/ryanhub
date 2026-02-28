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
  POST     /popo/narrations/analyze — Transcribe (via diarization server) + affective analysis (local emotion model)
  POST     /popo/analyze — Behavioral analysis: generate proactive nudges from sensing data (LLM or rule-based)
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
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List
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
# Anthropic SDK for behavioral analysis (LLM-based nudges)
# ---------------------------------------------------------------------------

ANTHROPIC_AVAILABLE = False
_anthropic_client = None

try:
    import anthropic as _anthropic_module
    ANTHROPIC_AVAILABLE = True
    print("Anthropic SDK available for behavioral analysis.")
except ImportError:
    print("Warning: anthropic not installed. LLM-based nudge generation unavailable.",
          file=sys.stderr)
    print("  Install with: pip3 install anthropic", file=sys.stderr)


def _get_anthropic_api_key():
    # type: () -> Optional[str]
    """Resolve the Anthropic API key from environment or config files."""
    # 1. Environment variable (standard)
    key = os.environ.get("ANTHROPIC_API_KEY")
    if key:
        return key

    # 2. Dispatcher config.yaml
    config_path = os.path.expanduser("~/.config/dispatcher/config.yaml")
    if os.path.exists(config_path):
        try:
            import yaml
            with open(config_path, "r") as f:
                cfg = yaml.safe_load(f)
            if isinstance(cfg, dict):
                key = cfg.get("anthropic_api_key") or cfg.get("ANTHROPIC_API_KEY")
                if key:
                    return key
        except Exception:
            pass

    # 3. Common .env files
    for env_path in [
        os.path.expanduser("~/.env"),
        os.path.expanduser("~/projects/ryanhub/.env"),
        os.path.expanduser("~/projects/ryanhub/scripts/.env"),
    ]:
        if os.path.exists(env_path):
            try:
                with open(env_path, "r") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("ANTHROPIC_API_KEY="):
                            return line.split("=", 1)[1].strip().strip('"').strip("'")
            except Exception:
                pass

    return None


def get_anthropic_client():
    # type: () -> Optional[Any]
    """Get or create a singleton Anthropic client."""
    global _anthropic_client
    if _anthropic_client is not None:
        return _anthropic_client

    if not ANTHROPIC_AVAILABLE:
        return None

    api_key = _get_anthropic_api_key()
    if not api_key:
        print("[Analyze] No Anthropic API key found. LLM nudges disabled.",
              file=sys.stderr)
        return None

    try:
        _anthropic_client = _anthropic_module.Anthropic(api_key=api_key)
        print("[Analyze] Anthropic client initialized.")
        return _anthropic_client
    except Exception as e:
        print("[Analyze] Failed to create Anthropic client: %s" % e,
              file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# Behavioral analysis: data summarization + nudge generation
# ---------------------------------------------------------------------------

BEHAVIORAL_ANALYSIS_SYSTEM_PROMPT = """\
You are Facai (发财), a proactive AI companion cat. You observe your human's behavioral data and generate caring, actionable nudges.

Analyze the behavioral data and generate 1-3 nudges. Each nudge should be:
- Specific (reference actual data: "you walked 8000 steps" not "great activity")
- Caring but not preachy (friendly cat personality)
- Actionable (suggest something concrete when appropriate)
- Contextual (consider time of day, patterns, transitions)

Types:
- insight: Pattern observation ("You're more active in mornings than afternoons this week")
- reminder: Gentle prompt ("You've been at your desk for 3 hours, stretch break?")
- encouragement: Positive reinforcement ("8000 steps today - your best this week!")
- alert: Health concern ("Elevated HR while stationary, try deep breathing")

Return a JSON array of nudges. Each nudge must have exactly these fields:
{ "type", "content", "trigger" (what data triggered this), "priority" ("normal" or "high"), "relatedModalities" (list of sensing modality strings like "motion", "steps", "heartRate", "location", "screen", "sleep", "battery") }

Return ONLY the JSON array, no other text or markdown formatting."""


def summarize_sensing_data(events, narrations, daily_summary=None):
    # type: (List[Dict], List[Dict], Optional[Dict]) -> str
    """Convert raw sensing events and narrations into a readable summary for the LLM.

    Groups events by modality and extracts key metrics for each."""
    lines = []  # type: List[str]
    now = datetime.now()
    lines.append("=== Behavioral Data Summary ===")
    lines.append("Current time: %s" % now.strftime("%Y-%m-%d %H:%M"))
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
        # Latest activity
        latest = max(motion_events, key=lambda e: e.get("timestamp", ""), default=None)
        if latest:
            activity = latest.get("activity", latest.get("data", {}).get("activity", "unknown"))
            confidence = latest.get("confidence", latest.get("data", {}).get("confidence", ""))
            lines.append("  Current activity: %s (confidence: %s)" % (activity, confidence))
        # Count transitions
        activities = [e.get("activity", e.get("data", {}).get("activity", "")) for e in motion_events]
        transitions = sum(1 for i in range(1, len(activities)) if activities[i] != activities[i - 1])
        lines.append("  Activity transitions in period: %d" % transitions)
        # Detect sedentary streaks
        stationary_events = [e for e in motion_events if
                             e.get("activity", e.get("data", {}).get("activity", ""))
                             in ("stationary", "still", "sitting", "unknown")]
        if stationary_events and len(stationary_events) > 0:
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
        lines.append("")

    # --- Steps ---
    step_events = by_modality.get("steps", by_modality.get("pedometer", []))
    if step_events:
        lines.append("[Steps]")
        total_steps = 0
        for ev in step_events:
            count = ev.get("steps", ev.get("data", {}).get("steps", 0))
            if isinstance(count, (int, float)):
                total_steps += int(count)
        if total_steps > 0:
            lines.append("  Total steps: %d" % total_steps)
        else:
            # Try to get the latest cumulative count
            latest = max(step_events, key=lambda e: e.get("timestamp", ""), default=None)
            if latest:
                count = latest.get("steps", latest.get("data", {}).get("steps", 0))
                lines.append("  Latest step count: %s" % count)
        lines.append("")

    # --- Heart Rate ---
    hr_events = by_modality.get("heartRate", by_modality.get("heart_rate", []))
    if hr_events:
        lines.append("[Heart Rate]")
        bpm_values = []
        for ev in hr_events:
            bpm = ev.get("bpm", ev.get("data", {}).get("bpm"))
            if isinstance(bpm, (int, float)):
                bpm_values.append(bpm)
        if bpm_values:
            lines.append("  Latest: %.0f bpm" % bpm_values[-1])
            lines.append("  Range: %.0f - %.0f bpm" % (min(bpm_values), max(bpm_values)))
            lines.append("  Average: %.0f bpm" % (sum(bpm_values) / len(bpm_values)))
        lines.append("")

    # --- Location ---
    loc_events = by_modality.get("location", [])
    if loc_events:
        lines.append("[Location]")
        places = set()
        for ev in loc_events:
            data = ev.get("data", {})
            place = (
                ev.get("placeName") or data.get("placeName")
                or ev.get("semanticLabel") or data.get("semanticLabel")
                or ev.get("place") or data.get("place")
                or ev.get("semanticPlace") or data.get("semanticPlace")
            )
            if place:
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
        total_fg_sec = 0
        session_count = 0
        for ev in screen_events:
            fg = ev.get("foregroundDuration", ev.get("data", {}).get("foregroundDuration", 0))
            if isinstance(fg, (int, float)):
                total_fg_sec += fg
            if ev.get("event", ev.get("data", {}).get("event")) in ("foreground", "unlock"):
                session_count += 1
        lines.append("  Total foreground time: %.0f min" % (total_fg_sec / 60.0))
        if session_count:
            lines.append("  Sessions: %d" % session_count)
        lines.append("")

    # --- Sleep ---
    sleep_events = by_modality.get("sleep", [])
    if sleep_events:
        lines.append("[Sleep]")
        latest = max(sleep_events, key=lambda e: e.get("timestamp", ""), default=None)
        if latest:
            duration = latest.get("duration", latest.get("data", {}).get("duration"))
            quality = latest.get("quality", latest.get("data", {}).get("quality"))
            if duration:
                hours = duration / 3600.0 if isinstance(duration, (int, float)) else 0
                lines.append("  Last night: %.1f hours" % hours)
            if quality:
                lines.append("  Quality: %s" % quality)
        lines.append("")

    # --- Battery ---
    battery_events = by_modality.get("battery", [])
    if battery_events:
        lines.append("[Battery]")
        latest = max(battery_events, key=lambda e: e.get("timestamp", ""), default=None)
        if latest:
            level = latest.get("level", latest.get("data", {}).get("level"))
            charging = latest.get("charging", latest.get("data", {}).get("isCharging"))
            if level is not None:
                lines.append("  Level: %s%%" % level)
            if charging is not None:
                lines.append("  Charging: %s" % ("yes" if charging else "no"))
        lines.append("")

    # --- Any other modalities ---
    known = {"motion", "steps", "pedometer", "heartRate", "heart_rate",
             "location", "screen", "screenTime", "sleep", "battery"}
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
            mood = nar.get("extractedMood", "")
            affect = nar.get("affectAnalysis", {})
            ts = nar.get("timestamp", "")[:16]
            if transcript:
                lines.append('  [%s] "%s"' % (ts, transcript[:120]))
                if mood:
                    lines.append("    Mood: %s" % mood)
                elif affect and isinstance(affect, dict):
                    primary = affect.get("primary_emotion", "")
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


def generate_nudges_llm(summary_text):
    # type: (str) -> Optional[List[Dict]]
    """Generate nudges using Claude API. Returns list of nudge dicts or None on failure."""
    client = get_anthropic_client()
    if client is None:
        return None

    try:
        message = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            system=BEHAVIORAL_ANALYSIS_SYSTEM_PROMPT,
            messages=[
                {"role": "user", "content": summary_text}
            ]
        )

        # Extract the text content
        response_text = ""
        for block in message.content:
            if hasattr(block, "text"):
                response_text += block.text

        # Parse JSON from response
        response_text = response_text.strip()
        # Handle markdown code blocks
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
    """Simple rule-based nudge generation as fallback when LLM is unavailable."""
    nudges = []  # type: List[Dict]
    now = datetime.now()

    # Group events by modality
    by_modality = {}  # type: Dict[str, List[Dict]]
    for ev in events:
        if not isinstance(ev, dict):
            continue
        modality = ev.get("modality", ev.get("type", "unknown"))
        by_modality.setdefault(modality, []).append(ev)

    # Rule 1: Sedentary for too long (>2 hours)
    motion_events = by_modality.get("motion", [])
    if motion_events:
        stationary = [e for e in motion_events if
                      e.get("activity", e.get("data", {}).get("activity", ""))
                      in ("stationary", "still", "sitting", "unknown")]
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
                            "content": "You've been sedentary for about %.0f minutes. How about a quick stretch or a short walk? Your body will thank you! 🐱" % duration_min,
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
        total_steps = 0
        for ev in step_events:
            count = ev.get("steps", ev.get("data", {}).get("steps", 0))
            if isinstance(count, (int, float)):
                total_steps += int(count)
        if total_steps >= 10000:
            nudges.append({
                "type": "encouragement",
                "content": "Amazing! %d steps today - you hit the 10K mark! Keep it up!" % total_steps,
                "trigger": "steps_milestone",
                "priority": "normal",
                "relatedModalities": ["steps"]
            })
        elif total_steps >= 5000:
            nudges.append({
                "type": "encouragement",
                "content": "%d steps so far today. Halfway to 10K - you're doing great!" % total_steps,
                "trigger": "steps_progress",
                "priority": "normal",
                "relatedModalities": ["steps"]
            })
        elif now.hour >= 18 and total_steps < 3000:
            nudges.append({
                "type": "reminder",
                "content": "Only %d steps today and it's already evening. An after-dinner walk could help!" % total_steps,
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
            bpm = latest_hr.get("bpm", latest_hr.get("data", {}).get("bpm", 0))
            activity = latest_motion.get("activity", latest_motion.get("data", {}).get("activity", ""))
            if isinstance(bpm, (int, float)) and bpm > 100 and activity in ("stationary", "still", "sitting"):
                nudges.append({
                    "type": "alert",
                    "content": "Your heart rate is %.0f bpm while you're stationary. Try some deep breathing to relax." % bpm,
                    "trigger": "elevated_hr_stationary",
                    "priority": "high",
                    "relatedModalities": ["heartRate", "motion"]
                })

    # Rule 4: Negative mood from narrations
    if narrations:
        recent_narrations = narrations[-3:]  # Last 3
        negative_count = 0
        for nar in recent_narrations:
            if not isinstance(nar, dict):
                continue
            mood = nar.get("extractedMood", "")
            affect = nar.get("affectAnalysis", {})
            if mood in ("sadness", "anger", "fear", "disgust"):
                negative_count += 1
            elif isinstance(affect, dict) and affect.get("primary_emotion") in ("sadness", "anger", "fear", "disgust"):
                negative_count += 1
        if negative_count >= 2:
            nudges.append({
                "type": "insight",
                "content": "Your recent voice entries suggest you might be feeling down. Want to take a break or do something you enjoy?",
                "trigger": "negative_mood_pattern",
                "priority": "normal",
                "relatedModalities": ["narration"]
            })

    # Rule 5: Low battery warning
    battery_events = by_modality.get("battery", [])
    if battery_events:
        latest = max(battery_events, key=lambda e: e.get("timestamp", ""), default=None)
        if latest:
            level = latest.get("level", latest.get("data", {}).get("level"))
            charging = latest.get("charging", latest.get("data", {}).get("isCharging", False))
            if isinstance(level, (int, float)) and level <= 15 and not charging:
                nudges.append({
                    "type": "alert",
                    "content": "Battery at %d%% - you might want to charge soon so I can keep watching over you!" % int(level),
                    "trigger": "low_battery",
                    "priority": "high",
                    "relatedModalities": ["battery"]
                })

    # If no rules fired and we have data, generate a generic insight
    if not nudges and (events or narrations):
        modalities = list(by_modality.keys())
        nudges.append({
            "type": "insight",
            "content": "I'm observing your %s data. Everything looks normal so far!" % ", ".join(modalities[:3]) if modalities else "I'm here watching over you. Send more sensing data so I can give you better insights!",
            "trigger": "general_observation",
            "priority": "normal",
            "relatedModalities": modalities[:3] if modalities else []
        })

    return nudges[:3]  # Cap at 3 nudges


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

        # POPO behavioral analysis (nudge generation)
        if path == "/popo/analyze":
            self._handle_behavioral_analysis()
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

        sensing_events = data.get("sensing_events", [])
        narrations = data.get("narrations", [])
        daily_summary = data.get("daily_summary")

        if not isinstance(sensing_events, list):
            sensing_events = []
        if not isinstance(narrations, list):
            narrations = []

        print("[Analyze] Received %d sensing events, %d narrations" %
              (len(sensing_events), len(narrations)))

        # Step 1: Summarize the sensing data
        summary_text = summarize_sensing_data(sensing_events, narrations, daily_summary)
        print("[Analyze] Summary:\n%s" % summary_text[:500])

        # Step 2: Generate nudges via LLM (no silent fallback — fail loudly)
        method_used = "none"
        raw_nudges = None

        if not ANTHROPIC_AVAILABLE:
            error_msg = "Anthropic SDK not available or API key not configured"
            print("[Analyze] ERROR: %s" % error_msg, file=sys.stderr)
            self._send_json(503, {
                "ok": False,
                "error": error_msg,
                "nudges": [],
                "method": "none"
            })
            return

        raw_nudges = generate_nudges_llm(summary_text)
        if raw_nudges is None:
            error_msg = "LLM nudge generation failed — check API key, network, or model availability"
            print("[Analyze] ERROR: %s" % error_msg, file=sys.stderr)
            self._send_json(500, {
                "ok": False,
                "error": error_msg,
                "nudges": [],
                "method": "llm_failed"
            })
            return

        method_used = "llm"
        print("[Analyze] Generated %d nudges via LLM" % len(raw_nudges))

        # Step 3: Normalize nudge records (add id, timestamp, validate fields)
        now_iso = datetime.now().isoformat()
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
    if ANTHROPIC_AVAILABLE:
        api_key = _get_anthropic_api_key()
        if api_key:
            print("Anthropic API: available (LLM nudge generation enabled)")
        else:
            print("Anthropic SDK: installed but no API key found (rule-based fallback)")
    else:
        print("Anthropic SDK: not installed (rule-based nudge generation only)")
    print("Press Ctrl+C to stop.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.shutdown()


if __name__ == "__main__":
    main()
