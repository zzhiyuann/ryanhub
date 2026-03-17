#!/usr/bin/env python3
"""
Calendar Sync Server for Ryan Hub iOS app.

A lightweight HTTP server that bridges Google Calendar operations from
the iOS app. Uses Google Calendar API directly for fast sync (no AI needed),
and shells out to `claude` CLI for natural language event management.

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

Requires Google Calendar API credentials at:
  /Users/zwang/Documents/gcal-mcp-server/credentials.json
  /Users/zwang/Documents/gcal-mcp-server/token.json
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

PORT = 18793  # Moved from 18791 (now used by OpenClaw browser-control)
HOST = "0.0.0.0"

# Google Calendar API credentials (reuse from MCP server)
GCAL_DIR = Path("/Users/zwang/Documents/gcal-mcp-server")
CREDENTIALS_FILE = GCAL_DIR / "credentials.json"
TOKEN_FILE = GCAL_DIR / "token.json"
SCOPES = ["https://www.googleapis.com/auth/calendar"]

# Agent memory file
SCRIPT_DIR = Path(__file__).parent
MEMORY_FILE = SCRIPT_DIR / "calendar-agent-memory.json"

# Claude CLI
CLAUDE_PATH = shutil.which("claude") or os.path.expanduser("~/.local/bin/claude")

# Add gcal venv to path for google API libraries
GCAL_VENV_SITE = GCAL_DIR / ".venv" / "lib"
# Find the python version directory dynamically
for p in GCAL_VENV_SITE.glob("python*/site-packages"):
    sys.path.insert(0, str(p))
    break

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build


def get_calendar_service():
    """Authenticate and return Google Calendar service."""
    creds = None
    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not CREDENTIALS_FILE.exists():
                raise FileNotFoundError(
                    f"credentials.json not found at {CREDENTIALS_FILE}"
                )
            flow = InstalledAppFlow.from_client_secrets_file(
                str(CREDENTIALS_FILE), SCOPES
            )
            creds = flow.run_local_server(port=0)
        TOKEN_FILE.write_text(creds.to_json())
    return build("calendar", "v3", credentials=creds)


def load_memory():
    """Load agent memory from disk."""
    if MEMORY_FILE.exists():
        return json.loads(MEMORY_FILE.read_text())
    return {"contacts": {}, "preferences": {}}


def save_memory(memory):
    """Save agent memory to disk."""
    MEMORY_FILE.write_text(json.dumps(memory, indent=2, ensure_ascii=False))


def normalize_event(event, calendar_id, calendar_name, calendar_color):
    """Normalize a Google Calendar event into a flat structure for iOS."""
    start = event.get("start", {})
    end = event.get("end", {})

    is_all_day = "date" in start and "dateTime" not in start
    start_time = start.get("dateTime") or start.get("date", "")
    end_time = end.get("dateTime") or end.get("date", "")

    return {
        "id": event.get("id", ""),
        "title": event.get("summary", "(No title)"),
        "startTime": start_time,
        "endTime": end_time,
        "location": event.get("location"),
        "notes": event.get("description"),
        "calendarId": calendar_id,
        "calendarName": calendar_name,
        "calendarColor": calendar_color,
        "isAllDay": is_all_day,
        "htmlLink": event.get("htmlLink"),
        "status": event.get("status"),
        "attendees": [
            {
                "email": a.get("email", ""),
                "displayName": a.get("displayName"),
                "responseStatus": a.get("responseStatus", "needsAction"),
            }
            for a in event.get("attendees", [])
        ],
    }


def fetch_all_calendars(service):
    """Fetch all calendars with their metadata."""
    result = service.calendarList().list().execute()
    calendars = []
    for cal in result.get("items", []):
        calendars.append({
            "id": cal["id"],
            "summary": cal.get("summary", ""),
            "backgroundColor": cal.get("backgroundColor", "#4285f4"),
            "primary": cal.get("primary", False),
            "accessRole": cal.get("accessRole", ""),
        })
    return calendars


def fetch_all_events(service, calendars, time_min, time_max):
    """Fetch events from all calendars, merged and sorted."""
    all_events = []
    for cal in calendars:
        try:
            result = service.events().list(
                calendarId=cal["id"],
                timeMin=time_min,
                timeMax=time_max,
                singleEvents=True,
                orderBy="startTime",
                maxResults=100,
            ).execute()
            for event in result.get("items", []):
                if event.get("status") == "cancelled":
                    continue
                all_events.append(
                    normalize_event(
                        event,
                        cal["id"],
                        cal["summary"],
                        cal["backgroundColor"],
                    )
                )
        except Exception as e:
            print(f"[calendar-sync] Error fetching from {cal['summary']}: {e}", file=sys.stderr)

    # Sort by startTime
    all_events.sort(key=lambda e: e.get("startTime", ""))
    return all_events


def run_agent(command_text):
    """Run a natural language command through Claude CLI with gcal MCP tools."""
    memory = load_memory()

    # Build context with memory and current date
    now = datetime.now()
    context_parts = [
        f"Current date/time: {now.strftime('%A, %B %d, %Y at %I:%M %p')} (Eastern Time)",
        f"Timezone: America/New_York",
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

    prompt = f"""{chr(10).join(context_parts)}

User request: "{command_text}"

You are a calendar assistant. Process the user's request using the Google Calendar MCP tools available to you.

IMPORTANT RULES:
1. If the user mentions a person and you have their contact info above, use it (e.g., add them as attendee).
2. If the user provides NEW contact info (like "Luyuan's email is X"), include a memory_update in your response.
3. For creating events, use the primary calendar unless specified otherwise.
4. Default duration is 60 minutes unless specified.
5. Always use America/New_York timezone.

After completing the action, respond with ONLY a JSON object (no markdown, no other text):
{{
  "message": "Human-readable summary of what was done",
  "action": "created" | "updated" | "deleted" | "info" | "error",
  "eventId": "the event ID if applicable, or null",
  "memory_updates": {{
    "contacts": {{"Name": {{"email": "x@y.com", "note": "optional"}}}},
    "preferences": {{}}
  }}
}}

The memory_updates field should ONLY be present if the user provided new contact info or preferences to remember. Otherwise omit it entirely.
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
                "--mcp-config", str(Path.home() / ".mcp.json"),
            ],
            capture_output=True,
            text=True,
            timeout=90,
            env=env,
        )

        if result.returncode != 0:
            return {"message": f"Agent error: {result.stderr.strip()}", "action": "error"}

        # Parse Claude CLI JSON envelope
        envelope = json.loads(result.stdout)
        content = envelope.get("result", "") if isinstance(envelope, dict) else str(envelope)

        # Extract the JSON response from content
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
            try:
                service = get_calendar_service()
                calendars = fetch_all_calendars(service)
                self._send_json(200, calendars)
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        elif path == "/events":
            try:
                service = get_calendar_service()
                calendars = fetch_all_calendars(service)

                # Default: today to 7 days from now
                now = datetime.now(timezone.utc)
                default_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
                default_end = default_start + timedelta(days=7)

                time_min = params.get("start", [default_start.isoformat()])[0]
                time_max = params.get("end", [default_end.isoformat()])[0]

                # Ensure timezone info
                if not time_min.endswith("Z") and "+" not in time_min and "-" not in time_min[10:]:
                    time_min += "-05:00"
                if not time_max.endswith("Z") and "+" not in time_max and "-" not in time_max[10:]:
                    time_max += "-05:00"

                events = fetch_all_events(service, calendars, time_min, time_max)
                self._send_json(200, events)
            except Exception as e:
                self._send_json(500, {"error": str(e)})

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
            try:
                service = get_calendar_service()
                calendar_id = data.get("calendarId", "primary")
                tz = data.get("timezone", "America/New_York")

                event_body = {
                    "summary": data["title"],
                    "start": {
                        "dateTime": data["startTime"],
                        "timeZone": tz,
                    },
                    "end": {
                        "dateTime": data["endTime"],
                        "timeZone": tz,
                    },
                }
                if data.get("location"):
                    event_body["location"] = data["location"]
                if data.get("notes"):
                    event_body["description"] = data["notes"]
                if data.get("attendees"):
                    event_body["attendees"] = [
                        {"email": a} for a in data["attendees"]
                    ]

                created = service.events().insert(
                    calendarId=calendar_id, body=event_body
                ).execute()
                self._send_json(201, {
                    "id": created["id"],
                    "htmlLink": created.get("htmlLink"),
                    "status": "created",
                })
            except KeyError as e:
                self._send_json(400, {"error": f"Missing required field: {e}"})
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        else:
            self._send_json(404, {"error": "Not found"})

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        # PUT /events/<id>
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

        try:
            service = get_calendar_service()
            calendar_id = data.get("calendarId", "primary")
            tz = data.get("timezone", "America/New_York")

            # Fetch existing event
            event = service.events().get(
                calendarId=calendar_id, eventId=event_id
            ).execute()

            # Update provided fields
            if "title" in data:
                event["summary"] = data["title"]
            if "startTime" in data:
                event["start"] = {"dateTime": data["startTime"], "timeZone": tz}
            if "endTime" in data:
                event["end"] = {"dateTime": data["endTime"], "timeZone": tz}
            if "location" in data:
                event["location"] = data["location"]
            if "notes" in data:
                event["description"] = data["notes"]

            updated = service.events().update(
                calendarId=calendar_id, eventId=event_id, body=event
            ).execute()
            self._send_json(200, {
                "id": updated["id"],
                "htmlLink": updated.get("htmlLink"),
                "status": "updated",
            })
        except Exception as e:
            self._send_json(500, {"error": str(e)})

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        if not path.startswith("/events/"):
            self._send_json(404, {"error": "Not found"})
            return

        event_id = path.split("/events/", 1)[1]
        if not event_id:
            self._send_json(400, {"error": "Missing event ID"})
            return

        try:
            service = get_calendar_service()
            calendar_id = params.get("calendar_id", ["primary"])[0]
            service.events().delete(
                calendarId=calendar_id, eventId=event_id
            ).execute()
            self._send_json(200, {"status": "deleted", "eventId": event_id})
        except Exception as e:
            self._send_json(500, {"error": str(e)})

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
    if not CREDENTIALS_FILE.exists():
        print(f"Error: Google credentials not found at {CREDENTIALS_FILE}", file=sys.stderr)
        sys.exit(1)

    # Verify google API libraries are importable (already imported above)
    server = http.server.HTTPServer((HOST, PORT), CalendarHandler)
    print(f"Calendar Sync Server listening on http://{HOST}:{PORT}")
    print(f"Using credentials from: {GCAL_DIR}")
    print(f"Agent memory at: {MEMORY_FILE}")
    print("Press Ctrl+C to stop.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.shutdown()


if __name__ == "__main__":
    main()
