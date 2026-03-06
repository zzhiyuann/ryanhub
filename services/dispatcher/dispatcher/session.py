"""Session tracking for dispatched tasks."""

from __future__ import annotations

import asyncio
import time
import uuid
from pathlib import Path
from typing import Optional


class Session:
    """A single dispatched task or conversation turn."""

    __slots__ = (
        "msg_id", "task_text", "cwd", "sid", "conv_id", "status",
        "proc", "started", "finished", "result", "is_task",
        "bot_msgs", "partial_output", "model_override", "model_sticky",
        # F7: transient question relay fields (NOT serialized)
        "pending_question", "answer_event", "answer_data",
        "stdin_writer", "stdin_drain",
        "used_partial_fallback",
        # WebSocket client reference (for question routing)
        "ws_client", "ws_msg_id",
        # Single-send contract: prevents duplicate final responses
        "final_sent",
        # Observability: pipeline stage timestamps
        "stage_times",
        # Retry tracking
        "retry_count", "max_retries",
        # Cancellation token
        "cancel_event",
    )

    def __init__(
        self, msg_id: int, text: str, cwd: str,
        sid: str | None = None, conv_id: str | None = None,
    ):
        self.msg_id = msg_id
        self.task_text = text
        self.cwd = cwd
        self.sid = sid or str(uuid.uuid4())
        self.conv_id = conv_id or self.sid  # links sessions in same conversation
        self.status = "pending"  # pending | running | done | failed | cancelled
        self.proc = None  # asyncio.subprocess.Process
        self.started: float | None = None
        self.finished: float | None = None
        self.result = ""
        self.is_task = True
        self.bot_msgs: list[int] = []
        self.partial_output = ""  # streaming: accumulated text so far
        self.model_override: str | None = None
        self.model_sticky: bool = False  # True = model persists in follow-ups
        # F7: transient — not persisted
        self.pending_question: dict | None = None  # {tool_use_id, questions, tg_msg_id}
        self.answer_event: asyncio.Event | None = None
        self.answer_data: str | None = None
        self.stdin_writer = None   # proc.stdin.write reference
        self.stdin_drain = None    # proc.stdin.drain reference
        # True when result is partial_output fallback (turns exhausted mid-task)
        self.used_partial_fallback: bool = False
        # WebSocket client reference — set when session originates from WS
        self.ws_client = None   # ServerConnection or None
        self.ws_msg_id: str | None = None  # Original WS message ID
        # Single-send contract: set to True after final response is sent
        self.final_sent: bool = False
        # Observability: record timestamps for each pipeline stage
        self.stage_times: dict[str, float] = {}
        # Retry: track attempts for automatic retry on transient failures
        self.retry_count: int = 0
        self.max_retries: int = 2
        # Cancellation: cooperative cancel via asyncio.Event
        self.cancel_event: asyncio.Event = asyncio.Event()

    def elapsed(self) -> float:
        end = self.finished or time.time()
        return end - self.started if self.started else 0

    @property
    def project_name(self) -> str:
        return Path(self.cwd).name

    def record_stage(self, stage: str) -> None:
        """Record a pipeline stage timestamp for observability."""
        self.stage_times[stage] = time.time()

    @property
    def is_cancelled(self) -> bool:
        """Check if this session has been cooperatively cancelled."""
        return self.cancel_event.is_set()

    def request_cancel(self) -> None:
        """Request cooperative cancellation of this session."""
        self.cancel_event.set()

    def stage_durations(self) -> dict[str, float]:
        """Compute durations between consecutive pipeline stages."""
        stages = sorted(self.stage_times.items(), key=lambda x: x[1])
        durations = {}
        for i in range(1, len(stages)):
            prev_name, prev_ts = stages[i - 1]
            cur_name, cur_ts = stages[i]
            durations[f"{prev_name}->{cur_name}"] = round(cur_ts - prev_ts, 3)
        return durations


class SessionManager:
    """Track active and recent sessions, map bot replies to originals."""

    def __init__(self, recent_window: int = 300):
        self.by_msg: dict[int, Session] = {}
        self.bot_to_orig: dict[int, int] = {}
        self.recent: list[int] = []
        self.recent_window = recent_window
        self.force_new: bool = False

    def create(
        self, msg_id: int, text: str, cwd: str,
        sid: str | None = None, conv_id: str | None = None,
    ) -> Session:
        s = Session(msg_id, text, cwd, sid, conv_id)
        self.by_msg[msg_id] = s
        self.recent.insert(0, msg_id)
        if len(self.recent) > 100:
            self.recent = self.recent[:100]
        return s

    def link_bot(self, bot_msg_id: int, orig_msg_id: int):
        self.bot_to_orig[bot_msg_id] = orig_msg_id

    def find_by_reply(self, reply_to: int) -> Session | None:
        if reply_to in self.by_msg:
            return self.by_msg[reply_to]
        orig = self.bot_to_orig.get(reply_to)
        if orig and orig in self.by_msg:
            return self.by_msg[orig]
        return None

    def last_session(self) -> Session | None:
        """Get the most recently created session (any status)."""
        for mid in self.recent:
            s = self.by_msg.get(mid)
            if s:
                return s
        return None

    def last_conv_id_for_cwd(self, cwd: str) -> str | None:
        """Return the conv_id of the most recent session with the same working directory.

        Used to share conversation context across parallel sessions
        targeting the same project.
        """
        for mid in self.recent:
            s = self.by_msg.get(mid)
            if s and s.cwd == cwd:
                return s.conv_id
        return None

    def active(self) -> list[Session]:
        return [s for s in self.by_msg.values() if s.status == "running"]

    def active_count(self) -> int:
        return len(self.active())
