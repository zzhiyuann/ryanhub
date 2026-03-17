"""Server-side PersonalContext — replicates iOS ToolkitDataProvider summaries.

Generates the same [Personal Context] block that the iOS app injects into
chat messages, but entirely server-side. This means BOTH WebSocket (iOS)
and Telegram channels get identical, fresh context without depending on the
iOS app being open.

Static providers (Bobo, Calendar, BookFactory) emit curl-command documentation.
Dynamic providers (Health, Parking) fetch live data from the bridge server.
"""

from __future__ import annotations

import json
import logging
import urllib.request
import urllib.error
from datetime import datetime

log = logging.getLogger(__name__)

BRIDGE_URL = "http://localhost:18790"

# Simple TTL cache for bridge server fetches (avoids hitting bridge on every message)
_cache: dict[str, tuple[float, object]] = {}
_CACHE_TTL = 30.0  # seconds


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _fetch_json(path: str, timeout: float = 3.0):
    """GET a JSON endpoint from the bridge server. Returns parsed data or None.
    Results are cached for 30 seconds to avoid redundant HTTP calls."""
    import time as _time
    now = _time.time()
    if path in _cache:
        cached_at, cached_data = _cache[path]
        if now - cached_at < _CACHE_TTL:
            return cached_data

    try:
        req = urllib.request.Request(f"{BRIDGE_URL}{path}")
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read())
        _cache[path] = (now, data)
        return data
    except Exception:
        return None


# ---------------------------------------------------------------------------
# BoBo Behavioral Sensing (static API docs)
# ---------------------------------------------------------------------------

def _bobo_context() -> str:
    return """[BoBo Behavioral Sensing]
BoBo is the user's behavioral sensing system that tracks motion, steps, heart rate, HRV, sleep, location, screen usage, workouts, and more. It also stores voice/text diary narrations with emotion analysis.

READ — Query a specific local calendar day (use this for today/yesterday/any explicit date):
curl -s 'http://localhost:18790/bobo/day?date=YYYY-MM-DD'
This endpoint also accepts date=today and date=yesterday.
For any other day, resolve the requested local date explicitly and query that date.
Returns JSON: {date, timezone, isToday, counts, summary, items}.
items are sorted newest-first and include sensing, narrations, nudges, meals, activities, and weight entries with UTC timestamp + localTime.
This is the PRIMARY endpoint for any date-aware timeline/sleep/routine question.

READ — Query multiple local calendar days for trends, mood, routine, or mental-state questions:
curl -s 'http://localhost:18790/bobo/range?days=7'
Or: curl -s 'http://localhost:18790/bobo/range?start=YYYY-MM-DD&end=YYYY-MM-DD'
Use this first when the user asks about patterns over days, the past week, or changes over time.
Returns JSON: {startDate, endDate, timezone, dayCount, totals, days}.

OPTIONAL — Read the current UI snapshot only if the user explicitly asks about the timeline currently open in the Bobo screen:
curl -s http://localhost:18790/bobo/timeline
This endpoint mirrors the currently selected day in the phone UI and may not be 'today'. Always check the returned date field before using it.

WRITE — Add a diary entry to BoBo timeline:
curl -s -X POST http://localhost:18790/bobo/narrations/add -H 'Content-Type: application/json' -d '{"transcript":"what the user said or described"}'
Use this when the user wants to log something to their timeline. Keep transcript concise and factual.
[End BoBo Behavioral Sensing]"""


# ---------------------------------------------------------------------------
# Health Data (dynamic — fetches recent data from bridge)
# ---------------------------------------------------------------------------

def _health_context() -> str:
    lines = ["[Health Data]"]

    # Weight
    weights = _fetch_json("/health-data/weight")
    if isinstance(weights, list) and weights:
        recent = sorted(weights, key=lambda w: w.get("date", ""), reverse=True)[:5]
        latest = recent[0]
        lines.append(f"Current Weight: {latest.get('weight', '?')} kg (recorded {latest.get('date', '?')[:10]})")
        if len(recent) >= 2:
            trend = " -> ".join(str(w.get("weight", "?")) for w in reversed(recent[:3]))
            lines.append(f"Recent Weight Trend: {trend}")
        lines.append("")

    # Food (today + yesterday)
    food = _fetch_json("/health-data/food")
    if isinstance(food, list) and food:
        today_str = datetime.now().strftime("%Y-%m-%d")
        today_food = [f for f in food if isinstance(f, dict) and f.get("date", "")[:10] == today_str]
        if today_food:
            lines.append("Today's Food:")
            total_cal = 0
            for f in today_food:
                cal = f.get("calories", 0) or 0
                total_cal += cal
                desc = f.get("aiSummary") or f.get("description", "")
                meal = f.get("mealType", "meal")
                lines.append(f"- {meal}: {desc} ({cal} cal)")
            lines.append(f"Today's Totals: {total_cal} cal")
            lines.append("")

    # Activity (today)
    activities = _fetch_json("/health-data/activity")
    if isinstance(activities, list) and activities:
        today_str = datetime.now().strftime("%Y-%m-%d")
        today_act = [a for a in activities if isinstance(a, dict) and a.get("date", "")[:10] == today_str]
        if today_act:
            lines.append("Today's Activity:")
            for a in today_act:
                atype = a.get("type", "Activity")
                dur = a.get("duration", 0)
                cal = a.get("caloriesBurned", 0)
                lines.append(f"- {atype}: {dur} min ({cal} cal)")
            lines.append("")

    # Actions (always present)
    lines.append("""Actions — When the user mentions food/weight/activity, you MUST create a structured entry via curl:
- Record food: curl -s -X POST http://localhost:18790/health-data/food/add -H 'Content-Type: application/json' -d '{"mealType":"lunch","description":"what they ate","calories":500,"protein":30,"carbs":50,"fat":15,"isAIAnalyzed":true,"aiSummary":"brief summary"}'
  mealType must be: breakfast, lunch, dinner, or snack. Estimate macros based on your knowledge.
- Record weight: curl -s -X POST http://localhost:18790/health-data/weight/add -H 'Content-Type: application/json' -d '{"weight":91.5,"note":"optional note"}'
  weight is in kg.
- Record activity: curl -s -X POST http://localhost:18790/health-data/activity/add -H 'Content-Type: application/json' -d '{"type":"Running","duration":30,"caloriesBurned":300,"isAIAnalyzed":true,"rawDescription":"original text","aiSummary":"brief summary","exercises":[]}'
  duration is in minutes. Common types: Walking, Running, Gym, Yoga, Swimming, Cycling, Cardio, Exercise.
  For gym workouts, include exercises array: [{"name":"Bench Press","sets":3,"reps":10,"weight":"135 lb"}]
IMPORTANT: Always call curl to write the entry. The id and date fields are auto-generated. Do NOT skip writing just because you logged to memory.
[End Health Data]""")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Parking Data (dynamic — reads from bridge + filesystem)
# ---------------------------------------------------------------------------

def _parking_context() -> str:
    lines = ["[Parking Data]"]

    # Today's status
    now = datetime.now()
    weekday = now.weekday()  # 0=Mon, 6=Sun
    if weekday >= 5:
        lines.append("Today is a weekend — no parking needed.")
    else:
        status = _fetch_json("/parking/last-status")
        if isinstance(status, dict):
            s = status.get("status", "unknown")
            price = status.get("price", "")
            if s == "purchased":
                lines.append(f"Today's parking: Purchased ({price})")
            elif s == "skipped":
                lines.append("Today's parking: SKIPPED")
            else:
                lines.append(f"Today's parking: {s}")
        else:
            lines.append("Today's parking: status unknown")

    # Skip dates
    skip_data = _fetch_json("/parking/skip-dates")
    if isinstance(skip_data, list) and skip_data:
        today_str = now.strftime("%Y-%m-%d")
        upcoming = sorted([d for d in skip_data if d >= today_str])[:5]
        if upcoming:
            lines.append(f"Upcoming skip dates: {', '.join(upcoming)}")

    lines.append("")
    lines.append("""Actions:
- Skip a date: append YYYY-MM-DD to /Users/zwang/projects/parkmobile-auto/skip-dates.txt (one per line, weekdays only)
- Restore a date: remove the line from /Users/zwang/projects/parkmobile-auto/skip-dates.txt
- View skip list: cat /Users/zwang/projects/parkmobile-auto/skip-dates.txt
[End Parking Data]""")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Calendar Data (static API docs — actual data fetched by agent at runtime)
# ---------------------------------------------------------------------------

def _calendar_context() -> str:
    return """[Calendar Data]
READ — Get today's and upcoming events:
curl -s http://localhost:18793/events/today
curl -s http://localhost:18793/events/upcoming
curl -s 'http://localhost:18793/events/date?date=YYYY-MM-DD'

WRITE — Create a new event:
curl -s -X POST http://localhost:18793/events/create -H 'Content-Type: application/json' -d '{"summary":"Event Name","start":"2026-03-20T10:00:00","end":"2026-03-20T11:00:00","location":"optional","description":"optional"}'

Actions: You can create, update, or delete Google Calendar events via the above endpoints.
[End Calendar Data]"""


# ---------------------------------------------------------------------------
# Book Library (static API docs)
# ---------------------------------------------------------------------------

def _bookfactory_context() -> str:
    return """[Book Library Data]
Actions:
- Generate a book NOW via API: curl -sk -X POST https://localhost:3443/api/books/generate -H 'Content-Type: application/json' -d '{"topic":"Your Topic Here"}'
  Returns {"jobId": "...", "status": "running"}. Check status: curl -sk https://localhost:3443/api/books/generate?jobId=JOB_ID
  The Book Factory server handles the entire pipeline (research, write, HTML, audio) — this is the ONLY correct way to generate books.
- CRITICAL: NEVER write book content inline in chat. ALWAYS delegate to Book Factory via the curl command above. You are NOT a book generator — you trigger the real pipeline.
- List all books: curl -sk https://localhost:3443/api/books
- Get book detail: curl -sk https://localhost:3443/api/books/BOOK_ID
[End Book Library Data]"""


# ---------------------------------------------------------------------------
# Dynamic Modules (generic pattern — fetch from bridge if data exists)
# ---------------------------------------------------------------------------

_DYNAMIC_MODULES = [
    ("hydrationTracker", "Hydration Tracker"),
    ("medicationTracker", "Medication Tracker"),
    ("sleepTracker", "Sleep Tracker"),
    ("moodJournal", "Mood Journal"),
    ("spendingTracker", "Spending Tracker"),
    ("readingTracker", "Reading Tracker"),
    ("habitTracker", "Habit Tracker"),
]


def _dynamic_module_context(module_id: str, display_name: str) -> str | None:
    """Build context for a dynamic module by fetching its data from the bridge."""
    data = _fetch_json(f"/modules/{module_id}/data")
    if not isinstance(data, list) or not data:
        return None

    lines = [f"[{display_name}]"]
    lines.append(f"Total entries: {len(data)}")

    # Show last 5 entries
    recent = data[-5:] if len(data) >= 5 else data
    for entry in reversed(recent):
        if isinstance(entry, dict):
            summary = entry.get("summaryLine") or entry.get("description") or str(entry)[:80]
            date = entry.get("date", "")[:16]
            lines.append(f"  - {date}: {summary}")

    lines.append("Actions:")
    lines.append(f"  - Add: POST http://localhost:18790/modules/{module_id}/data/add")
    lines.append(f"  - View: GET http://localhost:18790/modules/{module_id}/data")
    lines.append(f"[End {display_name}]")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def build_full_context() -> str:
    """Build the complete [Personal Context] block for injection into prompts.

    Combines all provider summaries. Returns empty string if nothing to inject.
    """
    sections: list[str] = []

    # Core providers (always included)
    sections.append(_bobo_context())
    sections.append(_health_context())
    sections.append(_parking_context())
    sections.append(_calendar_context())
    sections.append(_bookfactory_context())

    # Dynamic modules (only included if they have data)
    for module_id, display_name in _DYNAMIC_MODULES:
        ctx = _dynamic_module_context(module_id, display_name)
        if ctx:
            sections.append(ctx)

    if not sections:
        return ""

    return "[Personal Context]\n" + "\n".join(sections) + "\n[End Personal Context]"
