"""Proactive Facai Brain — periodic behavioral review and nudge generation.

Fetches behavioral data from the POPO bridge server, analyzes patterns,
and generates contextual nudges via LLM with the Facai (cat) personality.
Nudges are sent to the iOS app via WebSocket notification channel.

Architecture:
- Runs as a background asyncio task inside the Dispatcher
- Checks behavioral data every REVIEW_INTERVAL_HOURS hours
- Only runs when at least one WebSocket client is connected
- Uses gpt-4o-mini for cost-effective nudge generation
- Stores long-term behavioral baselines in a local JSON file
- Gracefully degrades: if bridge server or LLM is unreachable, logs and skips
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import time
import uuid
from datetime import datetime, date
from pathlib import Path
from typing import Any, Callable, Awaitable, Optional
from urllib.error import URLError
from urllib.request import Request, urlopen

log = logging.getLogger("dispatcher")

# -- Configuration defaults --

BRIDGE_SERVER_URL = "http://100.89.67.80:18790"
REVIEW_INTERVAL_HOURS = 3
MAX_NUDGES_PER_DAY = 3  # 2 routine + 1 anomaly buffer
LLM_MODEL = "gpt-4o-mini"
LLM_TIMEOUT = 30  # seconds
BRIDGE_TIMEOUT = 10  # seconds
MEMORY_DIR = Path.home() / ".config" / "dispatcher"
MEMORY_FILE = MEMORY_DIR / "popo_memory.json"

# -- Facai system prompt --

_FACAI_SYSTEM = """\
You are Facai (发财), a warm and caring cat who proactively looks after Zhiyuan's wellbeing. \
You have access to behavioral sensing data from today and historical baselines.

Your job: decide if a nudge is warranted RIGHT NOW based on the data. \
Be warm, concise, and actionable. Short messages — 1-2 sentences max.

Rules:
- Only nudge when genuinely helpful. Most of the time, no nudge is needed.
- Never be preachy, nagging, or repetitive.
- If nothing interesting stands out, respond with exactly: NO_NUDGE
- Respond in the user's preferred language (default: English, but Chinese is also fine).
- Keep the playful cat personality — you care about your human.

Nudge types you can generate (pick the most appropriate one):
- insight: Data-driven observation about patterns ("You walked 8k steps today — nice!")
- reminder: Time/context-based reminder ("You've been at your desk for 3 hours, time to stretch")
- encouragement: Positive reinforcement ("Great job getting outside today!")
- alert: Urgent or unusual pattern detected ("You haven't moved in 4 hours, everything ok?")

Response format (if nudge is warranted):
TYPE: <insight|reminder|encouragement|alert>
TRIGGER: <brief description of what triggered this nudge>
CONTENT: <the nudge message, 1-2 sentences>

If no nudge is warranted, respond with exactly: NO_NUDGE
"""


def _load_api_key() -> str:
    """Load OpenAI API key from env or common .env files."""
    val = os.environ.get("OPENAI_API_KEY", "")
    if val:
        return val
    for p in (Path.home() / ".openclaw" / ".env", Path.home() / ".env"):
        if p.exists():
            try:
                for line in p.read_text().splitlines():
                    line = line.strip()
                    if line.startswith("OPENAI_API_KEY="):
                        return line.split("=", 1)[1].strip().strip("\"'")
            except Exception:
                pass
    return ""


class PopoBrain:
    """Proactive behavioral nudge engine powered by LLM analysis.

    Periodically fetches POPO sensing data from the bridge server,
    analyzes behavioral patterns, and generates contextual nudges
    via the Facai personality.
    """

    def __init__(
        self,
        bridge_url: str = BRIDGE_SERVER_URL,
        review_interval_hours: float = REVIEW_INTERVAL_HOURS,
        max_nudges_per_day: int = MAX_NUDGES_PER_DAY,
        ws_client_count_fn: Optional[Callable[[], int]] = None,
        ws_broadcast_fn: Optional[Callable[[dict], Awaitable[None]]] = None,
    ):
        self.bridge_url = bridge_url.rstrip("/")
        self.review_interval = review_interval_hours * 3600  # convert to seconds
        self.max_nudges_per_day = max_nudges_per_day
        self._ws_client_count = ws_client_count_fn
        self._ws_broadcast = ws_broadcast_fn

        self._api_key = _load_api_key()
        self._enabled = bool(self._api_key)
        self._task: Optional[asyncio.Task] = None
        self._nudges_today: list[dict] = []
        self._today_str: str = ""
        self._memory: dict = {}
        self._last_review_time: float = 0

        if not self._enabled:
            log.warning("PopoBrain disabled: no OPENAI_API_KEY found")
        else:
            log.info("PopoBrain initialized (interval=%dh, max_nudges=%d/day)",
                     review_interval_hours, max_nudges_per_day)

    # -- Lifecycle --

    def start(self) -> None:
        """Start the background review loop as an asyncio task."""
        if not self._enabled:
            return
        self._load_memory()
        self._task = asyncio.create_task(self._review_loop())
        log.info("PopoBrain background loop started")

    async def stop(self) -> None:
        """Cancel the background task gracefully."""
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None
            log.info("PopoBrain background loop stopped")

    # -- Background review loop --

    async def _review_loop(self) -> None:
        """Main loop: periodically review behavioral data and generate nudges."""
        # Wait a bit on startup to let everything initialize
        await asyncio.sleep(60)

        while True:
            try:
                await self._maybe_review()
            except asyncio.CancelledError:
                raise
            except Exception:
                log.exception("PopoBrain review cycle failed")

            await asyncio.sleep(self.review_interval)

    async def _maybe_review(self) -> None:
        """Check conditions and run a review if appropriate."""
        # Reset daily nudge counter on date change
        today = date.today().isoformat()
        if today != self._today_str:
            self._today_str = today
            self._nudges_today = []
            log.info("PopoBrain: new day %s, nudge counter reset", today)

        # Skip if no WebSocket clients connected (nobody to send nudges to)
        if self._ws_client_count and self._ws_client_count() == 0:
            log.debug("PopoBrain: no WS clients connected, skipping review")
            return

        # Skip if we've hit the daily nudge limit
        if len(self._nudges_today) >= self.max_nudges_per_day:
            log.debug("PopoBrain: daily nudge limit reached (%d/%d)",
                      len(self._nudges_today), self.max_nudges_per_day)
            return

        log.info("PopoBrain: starting behavioral review for %s", today)
        await self.review_behavior()

    # -- Core behavior review --

    async def review_behavior(self) -> None:
        """Fetch today's behavioral data and generate insights."""
        today = date.today().isoformat()

        # Fetch data from bridge server
        daily_data = await self._fetch_daily_data(today)
        if daily_data is None:
            log.warning("PopoBrain: could not fetch daily data, skipping")
            return

        # Build behavioral summary for the LLM
        summary = self._build_behavioral_summary(daily_data)
        if not summary:
            log.info("PopoBrain: no meaningful data to analyze")
            return

        # Generate nudge via LLM
        nudge = await self.generate_nudge(summary)
        if nudge:
            await self.send_nudge(nudge)
            self._nudges_today.append(nudge)
            log.info("PopoBrain: nudge sent — type=%s", nudge.get("type", "unknown"))
        else:
            log.info("PopoBrain: LLM decided no nudge needed")

        # Update long-term memory with today's data
        await self.update_memory(daily_data)
        self._last_review_time = time.time()

    # -- Data fetching --

    async def _fetch_daily_data(self, date_str: str) -> Optional[dict]:
        """Fetch all POPO data for a date from the bridge server.

        Returns a dict with keys: sensing, narrations, nudges, summary
        or None on failure.
        """
        result = {}
        endpoints = {
            "sensing": f"/popo/sensing?date={date_str}",
            "narrations": f"/popo/narrations?date={date_str}",
            "nudges": f"/popo/nudges?date={date_str}",
            "summary": f"/popo/daily-summary?date={date_str}",
        }

        for key, path in endpoints.items():
            try:
                data = await asyncio.to_thread(
                    self._http_get, f"{self.bridge_url}{path}"
                )
                result[key] = data
            except Exception as exc:
                log.debug("PopoBrain: failed to fetch %s: %s", key, exc)
                result[key] = []

        return result

    def _http_get(self, url: str) -> Any:
        """Synchronous HTTP GET returning parsed JSON."""
        req = Request(url, headers={"Accept": "application/json"})
        resp = urlopen(req, timeout=BRIDGE_TIMEOUT)
        return json.loads(resp.read())

    def _http_post(self, url: str, payload: dict) -> Any:
        """Synchronous HTTP POST with JSON body, returning parsed JSON."""
        data = json.dumps(payload).encode()
        req = Request(
            url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        resp = urlopen(req, timeout=BRIDGE_TIMEOUT)
        return json.loads(resp.read())

    # -- Behavioral analysis --

    def _build_behavioral_summary(self, daily_data: dict) -> str:
        """Transform raw POPO data into a concise summary for the LLM.

        Returns empty string if there's not enough data to analyze.
        """
        parts: list[str] = []
        now = datetime.now()
        parts.append(f"Current time: {now.strftime('%Y-%m-%d %H:%M')} (local)")
        parts.append(f"Day of week: {now.strftime('%A')}")

        # -- Sensing events --
        sensing = daily_data.get("sensing", [])
        if sensing and isinstance(sensing, list):
            parts.append(f"\n=== Sensing Data ({len(sensing)} events) ===")

            # Categorize events
            motion_events = []
            step_events = []
            heart_rate_events = []
            location_events = []
            screen_events = []
            other_events = []

            for event in sensing:
                if not isinstance(event, dict):
                    continue
                etype = event.get("type", "").lower()
                if "motion" in etype or "accelero" in etype or "activity" in etype:
                    motion_events.append(event)
                elif "step" in etype or "pedometer" in etype:
                    step_events.append(event)
                elif "heart" in etype or "hr" in etype:
                    heart_rate_events.append(event)
                elif "location" in etype or "gps" in etype:
                    location_events.append(event)
                elif "screen" in etype:
                    screen_events.append(event)
                else:
                    other_events.append(event)

            if step_events:
                # Extract step counts
                steps = [e.get("value", e.get("steps", 0)) for e in step_events]
                total_steps = sum(s for s in steps if isinstance(s, (int, float)))
                parts.append(f"Steps today: {int(total_steps)}")

            if motion_events:
                parts.append(f"Motion events: {len(motion_events)}")
                # Check for prolonged sedentary periods
                if len(motion_events) > 0:
                    latest = motion_events[-1]
                    ts = latest.get("timestamp", "")
                    parts.append(f"Last motion detected: {ts}")

            if heart_rate_events:
                hrs = [e.get("value", e.get("bpm", 0)) for e in heart_rate_events]
                valid_hrs = [h for h in hrs if isinstance(h, (int, float)) and h > 0]
                if valid_hrs:
                    parts.append(f"Heart rate: avg={sum(valid_hrs)/len(valid_hrs):.0f}, "
                                 f"min={min(valid_hrs):.0f}, max={max(valid_hrs):.0f}")

            if location_events:
                parts.append(f"Location changes: {len(location_events)}")

            if screen_events:
                parts.append(f"Screen events: {len(screen_events)}")

            if other_events:
                # Summarize other event types
                other_types = set(e.get("type", "unknown") for e in other_events)
                parts.append(f"Other sensors: {', '.join(other_types)}")

        # -- Narrations (voice diary) --
        narrations = daily_data.get("narrations", [])
        if narrations and isinstance(narrations, list):
            parts.append(f"\n=== Narrations ({len(narrations)} entries) ===")
            for narr in narrations[-5:]:  # Last 5 narrations max
                if not isinstance(narr, dict):
                    continue
                ts = narr.get("timestamp", "")
                transcript = narr.get("transcript", "")
                mood = narr.get("mood", narr.get("affect", ""))
                entry = f"[{ts}]"
                if transcript:
                    entry += f" \"{transcript[:200]}\""
                if mood:
                    entry += f" (mood: {mood})"
                parts.append(entry)

        # -- Existing nudges today (to avoid repeats) --
        existing_nudges = daily_data.get("nudges", [])
        if existing_nudges and isinstance(existing_nudges, list):
            parts.append(f"\n=== Already sent {len(existing_nudges)} nudge(s) today ===")
            for nudge in existing_nudges:
                if isinstance(nudge, dict):
                    parts.append(f"- [{nudge.get('type', '?')}] {nudge.get('content', '')[:100]}")

        # -- Historical baselines from memory --
        if self._memory.get("baselines"):
            baselines = self._memory["baselines"]
            parts.append("\n=== Historical Baselines ===")
            if "avg_daily_steps" in baselines:
                parts.append(f"Average daily steps: {baselines['avg_daily_steps']:.0f}")
            if "typical_active_hours" in baselines:
                parts.append(f"Typical active hours: {baselines['typical_active_hours']}")
            if "mood_trend" in baselines:
                parts.append(f"Recent mood trend: {baselines['mood_trend']}")

        # Only return if we have meaningful data beyond just the timestamp
        if len(parts) <= 2:
            return ""

        return "\n".join(parts)

    # -- Nudge generation --

    async def generate_nudge(self, behavioral_summary: str) -> Optional[dict]:
        """Use LLM to decide if a nudge is warranted and generate it.

        Returns a nudge dict compatible with the iOS Nudge model, or None.
        """
        if not self._api_key:
            return None

        user_prompt = (
            f"Here is today's behavioral data for Zhiyuan:\n\n"
            f"{behavioral_summary}\n\n"
            f"Based on this data, should I send a nudge right now? "
            f"Remember: only nudge if genuinely helpful. "
            f"Nudges already sent today: {len(self._nudges_today)}. "
            f"Max allowed: {self.max_nudges_per_day}."
        )

        try:
            response = await asyncio.to_thread(
                self._call_llm, user_prompt
            )
        except Exception:
            log.exception("PopoBrain: LLM call failed")
            return None

        if not response or "NO_NUDGE" in response.upper():
            return None

        return self._parse_nudge_response(response)

    def _call_llm(self, user_content: str) -> str:
        """Synchronous OpenAI API call. Runs in a thread."""
        payload = json.dumps({
            "model": LLM_MODEL,
            "max_tokens": 200,
            "temperature": 0.7,
            "messages": [
                {"role": "system", "content": _FACAI_SYSTEM},
                {"role": "user", "content": user_content},
            ],
        }).encode()
        req = Request(
            "https://api.openai.com/v1/chat/completions",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self._api_key}",
            },
        )
        resp = urlopen(req, timeout=LLM_TIMEOUT)
        data = json.loads(resp.read())
        choices = data.get("choices", [])
        if choices:
            return choices[0].get("message", {}).get("content", "")
        return ""

    def _parse_nudge_response(self, response: str) -> Optional[dict]:
        """Parse the LLM response into a structured nudge dict.

        Expected format:
            TYPE: <insight|reminder|encouragement|alert>
            TRIGGER: <description>
            CONTENT: <message>
        """
        nudge_type = "insight"
        trigger = ""
        content = ""

        for line in response.strip().splitlines():
            line = line.strip()
            upper = line.upper()
            if upper.startswith("TYPE:"):
                raw_type = line.split(":", 1)[1].strip().lower()
                if raw_type in ("insight", "reminder", "encouragement", "alert"):
                    nudge_type = raw_type
            elif upper.startswith("TRIGGER:"):
                trigger = line.split(":", 1)[1].strip()
            elif upper.startswith("CONTENT:"):
                content = line.split(":", 1)[1].strip()

        if not content:
            # Fallback: use the entire response as content if no structured format
            content = response.strip()
            # But skip if it looks like garbage or NO_NUDGE slipped through
            if len(content) < 5 or "NO_NUDGE" in content.upper():
                return None
            trigger = "behavioral pattern"

        return {
            "id": str(uuid.uuid4()),
            "timestamp": datetime.now().isoformat(),
            "type": nudge_type,
            "trigger": trigger,
            "content": content,
            "acknowledged": False,
        }

    # -- Nudge delivery --

    async def send_nudge(self, nudge: dict) -> None:
        """Save nudge to bridge server AND push to iOS via WebSocket."""
        # 1. Save to bridge server
        try:
            await asyncio.to_thread(
                self._http_post,
                f"{self.bridge_url}/popo/nudges",
                nudge,
            )
            log.info("PopoBrain: nudge saved to bridge server")
        except Exception:
            log.warning("PopoBrain: failed to save nudge to bridge server", exc_info=True)
            # Continue anyway — still push via WebSocket

        # 2. Push to iOS via WebSocket notification
        if self._ws_broadcast:
            try:
                await self._ws_broadcast({
                    "type": "notification",
                    "id": str(uuid.uuid4()),
                    "content": nudge["content"],
                    "source": "popo_brain",
                    "nudge": nudge,  # Full nudge data for iOS to store
                })
                log.info("PopoBrain: nudge pushed via WebSocket")
            except Exception:
                log.warning("PopoBrain: failed to push nudge via WebSocket", exc_info=True)

    # -- Long-term memory --

    def _load_memory(self) -> None:
        """Load behavioral memory from disk."""
        try:
            MEMORY_DIR.mkdir(parents=True, exist_ok=True)
            if MEMORY_FILE.exists():
                self._memory = json.loads(MEMORY_FILE.read_text())
                log.info("PopoBrain: loaded memory (%d days of history)",
                         len(self._memory.get("daily_logs", {})))
            else:
                self._memory = {
                    "baselines": {},
                    "daily_logs": {},
                    "last_updated": "",
                }
        except Exception:
            log.warning("PopoBrain: failed to load memory, starting fresh", exc_info=True)
            self._memory = {"baselines": {}, "daily_logs": {}, "last_updated": ""}

    def _save_memory(self) -> None:
        """Persist behavioral memory to disk."""
        try:
            MEMORY_DIR.mkdir(parents=True, exist_ok=True)
            self._memory["last_updated"] = datetime.now().isoformat()
            MEMORY_FILE.write_text(json.dumps(self._memory, indent=2, ensure_ascii=False))
        except Exception:
            log.warning("PopoBrain: failed to save memory", exc_info=True)

    async def update_memory(self, daily_data: dict) -> None:
        """Accumulate behavioral patterns from today's data into long-term memory."""
        today = date.today().isoformat()
        daily_logs = self._memory.setdefault("daily_logs", {})

        # Build today's summary entry
        entry: dict[str, Any] = {"date": today}

        # Extract key metrics from sensing data
        sensing = daily_data.get("sensing", [])
        if isinstance(sensing, list):
            step_events = [
                e for e in sensing
                if isinstance(e, dict)
                and ("step" in e.get("type", "").lower()
                     or "pedometer" in e.get("type", "").lower())
            ]
            if step_events:
                steps = [
                    e.get("value", e.get("steps", 0))
                    for e in step_events
                ]
                entry["total_steps"] = sum(
                    s for s in steps if isinstance(s, (int, float))
                )

            motion_count = sum(
                1 for e in sensing
                if isinstance(e, dict)
                and ("motion" in e.get("type", "").lower()
                     or "activity" in e.get("type", "").lower())
            )
            entry["motion_events"] = motion_count

        # Extract mood from narrations
        narrations = daily_data.get("narrations", [])
        if isinstance(narrations, list) and narrations:
            moods = [
                n.get("mood", n.get("affect", ""))
                for n in narrations
                if isinstance(n, dict) and (n.get("mood") or n.get("affect"))
            ]
            if moods:
                entry["moods"] = moods

        entry["nudges_sent"] = len(self._nudges_today)

        # Store today's entry
        daily_logs[today] = entry

        # Keep only last 30 days of logs
        if len(daily_logs) > 30:
            sorted_dates = sorted(daily_logs.keys())
            for old_date in sorted_dates[:-30]:
                del daily_logs[old_date]

        # Recompute baselines from recent history
        self._recompute_baselines()

        # Persist to disk
        await asyncio.to_thread(self._save_memory)

    def _recompute_baselines(self) -> None:
        """Recompute average behavioral baselines from stored daily logs."""
        daily_logs = self._memory.get("daily_logs", {})
        if not daily_logs:
            return

        baselines: dict[str, Any] = {}

        # Average daily steps
        step_values = [
            log_entry.get("total_steps", 0)
            for log_entry in daily_logs.values()
            if isinstance(log_entry, dict) and log_entry.get("total_steps", 0) > 0
        ]
        if step_values:
            baselines["avg_daily_steps"] = sum(step_values) / len(step_values)

        # Average motion events
        motion_values = [
            log_entry.get("motion_events", 0)
            for log_entry in daily_logs.values()
            if isinstance(log_entry, dict) and log_entry.get("motion_events", 0) > 0
        ]
        if motion_values:
            baselines["avg_motion_events"] = sum(motion_values) / len(motion_values)

        # Mood trend (from last 7 days)
        recent_dates = sorted(daily_logs.keys())[-7:]
        all_moods: list[str] = []
        for d in recent_dates:
            entry = daily_logs.get(d, {})
            if isinstance(entry, dict):
                all_moods.extend(entry.get("moods", []))
        if all_moods:
            baselines["mood_trend"] = ", ".join(all_moods[-5:])

        baselines["days_of_data"] = len(daily_logs)
        self._memory["baselines"] = baselines
