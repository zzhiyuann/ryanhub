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
from urllib.parse import urlparse

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
}

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
        path = urlparse(self.path).path
        if path == "/health":
            self._send_json(200, {"status": "ok"})
        elif path in PARKING_FILES:
            self._serve_parking_file(path)
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

        # Server-side data write (health + chat)
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
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
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
    print("Press Ctrl+C to stop.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.shutdown()


if __name__ == "__main__":
    main()
