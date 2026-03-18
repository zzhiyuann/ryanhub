#!/usr/bin/env python3
"""
Calendar Sync Server for Ryan Hub iOS app.

Uses Apple Calendar (EventKit) via a compiled Swift helper binary,
reading from the system's native Calendar.app which syncs with
Google, Exchange, iCloud, etc.

Endpoints:
  GET  /health                         — Health check
  GET  /calendars                      — List all calendars with colors
  GET  /events?start=ISO&end=ISO       — Fetch events from all calendars
  POST /events                         — Create event (structured JSON)
  PUT  /events/<id>                    — Update event
  DELETE /events/<id>?calendar_id=X    — Delete event
  POST /agent                          — Natural language command via Claude CLI

Usage:
  python3 scripts/calendar-sync-server.py
"""

import http.server
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlparse, parse_qs

PORT = 18793
HOST = "0.0.0.0"

SCRIPT_DIR = Path(__file__).parent
CALENDAR_HELPER = SCRIPT_DIR / "calendar-helper"
MEMORY_FILE = SCRIPT_DIR / "calendar-agent-memory.json"

# Claude CLI
CLAUDE_PATH = shutil.which("claude") or os.path.expanduser("~/.local/bin/claude")


def run_helper(*args):
    """Run the calendar-helper binary and return parsed JSON."""
    cmd = [str(CALENDAR_HELPER)] + list(args)
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=15
        )
        if result.returncode != 0:
            stderr = result.stderr.strip()
            # Try to parse JSON error from stdout
            try:
                return json.loads(result.stdout)
            except (json.JSONDecodeError, ValueError):
                return {"error": stderr or f"Helper exited with code {result.returncode}"}

        return json.loads(result.stdout)
    except subprocess.TimeoutExpired:
        return {"error": "Calendar helper timed out"}
    except json.JSONDecodeError:
        return {"error": f"Invalid JSON from helper: {result.stdout[:200]}"}
    except Exception as e:
        return {"error": str(e)}


def load_memory():
    """Load agent memory from disk."""
    if MEMORY_FILE.exists():
        return json.loads(MEMORY_FILE.read_text())
    return {"contacts": {}, "preferences": {}}


def save_memory(memory):
    """Save agent memory to disk."""
    MEMORY_FILE.write_text(json.dumps(memory, indent=2, ensure_ascii=False))


def run_agent(command_text):
    """Run a natural language command through Claude CLI."""
    memory = load_memory()

    now = datetime.now()
    context_parts = [
        f"Current date/time: {now.strftime('%A, %B %d, %Y at %I:%M %p')} (Eastern Time)",
        "Timezone: America/New_York",
    ]

    if memory.get("contacts"):
        context_parts.append("\nKnown contacts:")
        for name, info in memory["contacts"].items():
            details = ", ".join(f"{k}: {v}" for k, v in info.items())
            context_parts.append(f"  - {name}: {details}")

    if memory.get("preferences"):
        prefs = memory["preferences"]
        context_parts.append(f"\nDefault calendar: {prefs.get('default_calendar', 'primary')}")
        context_parts.append(f"Default event duration: {prefs.get('default_duration_minutes', 60)} minutes")

    # Get current calendars for context
    calendars = run_helper("list-calendars")
    if isinstance(calendars, list):
        cal_names = [f"- {c['summary']} (id: {c['id']}, source: {c.get('source', '')})" for c in calendars]
        context_parts.append(f"\nAvailable calendars:\n" + "\n".join(cal_names))

    prompt = f"""{chr(10).join(context_parts)}

User request: "{command_text}"

You are a calendar assistant. You have a calendar-helper CLI tool that interacts with Apple Calendar.

Available commands (run via shell):
  {CALENDAR_HELPER} list-calendars
  {CALENDAR_HELPER} list-events <startISO> <endISO>
  {CALENDAR_HELPER} create-event '<json>'   # json: {{"title","startTime","endTime","calendarId?","location?","notes?","isAllDay?"}}
  {CALENDAR_HELPER} update-event <eventId> '<json>'
  {CALENDAR_HELPER} delete-event <eventId>

Process the user's request using these tools.

IMPORTANT RULES:
1. If the user mentions a person and you have their contact info above, use it.
2. If the user provides NEW contact info, include a memory_update in your response.
3. DEFAULT CALENDAR: Use the Exchange "Calendar" (source=Exchange, the Outlook/virginia.edu calendar) unless the user specifies otherwise. The calendarId for Exchange Calendar is "3234BBFF-1189-4413-B5A4-DF7A8412309B".
4. Default duration is 60 minutes unless specified.
5. Always use America/New_York timezone.
6. If the user says "personal calendar" or "Google calendar", use "Zhiyuan Wang 1" (source=Google). If they say "home" or "iCloud", use "Home" (source=iCloud).

After completing the action, respond with ONLY a JSON object:
{{
  "message": "Human-readable summary of what was done",
  "action": "created" | "updated" | "deleted" | "info" | "error",
  "eventId": "the event ID if applicable, or null"
}}
"""

    env = os.environ.copy()
    env.pop("CLAUDE_CODE", None)
    env.pop("CLAUDECODE", None)

    try:
        result = subprocess.run(
            [
                CLAUDE_PATH, "-p", prompt,
                "--output-format", "json",
                "--model", "haiku",
                "--allowedTools", "Bash",
            ],
            capture_output=True,
            text=True,
            timeout=90,
            env=env,
        )

        if result.returncode != 0:
            return {"message": f"Agent error: {result.stderr.strip()}", "action": "error"}

        envelope = json.loads(result.stdout)
        content = envelope.get("result", "") if isinstance(envelope, dict) else str(envelope)

        if isinstance(content, str):
            content = content.strip()
            if content.startswith("```json"):
                content = content[7:]
            elif content.startswith("```"):
                content = content[3:]
            if content.endswith("```"):
                content = content[:-3]
            content = content.strip()
            response = json.loads(content)
        elif isinstance(content, dict):
            response = content
        else:
            return {"message": str(content), "action": "info"}

        # Process memory updates
        if "memory_updates" in response:
            updates = response["memory_updates"]
            if "contacts" in updates and updates["contacts"]:
                memory.setdefault("contacts", {}).update(updates["contacts"])
            if "preferences" in updates and updates["preferences"]:
                memory.setdefault("preferences", {}).update(updates["preferences"])
            save_memory(memory)
            del response["memory_updates"]

        return response

    except subprocess.TimeoutExpired:
        return {"message": "Agent timed out. Please try again.", "action": "error"}
    except json.JSONDecodeError as e:
        return {"message": f"Failed to parse agent response: {e}", "action": "error"}
    except Exception as e:
        return {"message": f"Agent error: {e}", "action": "error"}


class CalendarHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler for calendar sync operations."""

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        if path == "/health":
            self._send_json(200, {"status": "ok"})

        elif path == "/calendars":
            result = run_helper("list-calendars")
            if isinstance(result, dict) and "error" in result:
                self._send_json(500, result)
            else:
                self._send_json(200, result)

        elif path == "/events":
            now = datetime.now(timezone.utc)
            default_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            default_end = default_start + timedelta(days=7)

            time_min = params.get("start", [default_start.isoformat()])[0]
            time_max = params.get("end", [default_end.isoformat()])[0]

            result = run_helper("list-events", time_min, time_max)
            if isinstance(result, dict) and "error" in result:
                self._send_json(500, result)
            else:
                self._send_json(200, result)

        else:
            self._send_json(404, {"error": "Not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid request body: {e}"})
            return

        if path == "/agent":
            text = data.get("text", "").strip()
            if not text:
                self._send_json(400, {"error": "Must provide 'text' field"})
                return
            result = run_agent(text)
            self._send_json(200, result)

        elif path == "/events":
            event_json = json.dumps(data, ensure_ascii=False)
            result = run_helper("create-event", event_json)
            if isinstance(result, dict) and "error" in result:
                self._send_json(500, result)
            else:
                self._send_json(201, result)

        else:
            self._send_json(404, {"error": "Not found"})

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if not path.startswith("/events/"):
            self._send_json(404, {"error": "Not found"})
            return

        event_id = path.split("/events/", 1)[1]
        if not event_id:
            self._send_json(400, {"error": "Missing event ID"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
        except (json.JSONDecodeError, ValueError) as e:
            self._send_json(400, {"error": f"Invalid request body: {e}"})
            return

        event_json = json.dumps(data, ensure_ascii=False)
        result = run_helper("update-event", event_id, event_json)
        if isinstance(result, dict) and "error" in result:
            self._send_json(500, result)
        else:
            self._send_json(200, result)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if not path.startswith("/events/"):
            self._send_json(404, {"error": "Not found"})
            return

        event_id = path.split("/events/", 1)[1]
        if not event_id:
            self._send_json(400, {"error": "Missing event ID"})
            return

        result = run_helper("delete-event", event_id)
        if isinstance(result, dict) and "error" in result:
            self._send_json(500, result)
        else:
            self._send_json(200, result)

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def _send_json(self, status, data):
        response = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, fmt, *args):
        sys.stderr.write(f"[calendar-sync] {self.address_string()} - {fmt % args}\n")


def main():
    if not CALENDAR_HELPER.exists():
        print(f"Error: calendar-helper binary not found at {CALENDAR_HELPER}", file=sys.stderr)
        print("Compile with: swiftc -O -o calendar-helper calendar-helper.swift -framework EventKit -framework CoreGraphics", file=sys.stderr)
        sys.exit(1)

    server = http.server.HTTPServer((HOST, PORT), CalendarHandler)
    print(f"Calendar Sync Server listening on http://{HOST}:{PORT}")
    print(f"Using Apple Calendar via {CALENDAR_HELPER}")
    print(f"Agent memory at: {MEMORY_FILE}")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.shutdown()


if __name__ == "__main__":
    main()
