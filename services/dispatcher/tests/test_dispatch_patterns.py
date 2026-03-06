"""Tests for OpenClaw-inspired dispatch patterns.

Validates:
1. Single-send contract — no duplicate final responses
2. Quote/reply-to enforcement — responses link back to originating message
3. Retry with backoff — transient failures auto-retry
4. Cooperative cancellation — cancel_event stops retry loops
5. Observability — pipeline stage tracking
"""

from __future__ import annotations

import asyncio
import json
import sys
import time
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dispatcher.session import Session, SessionManager
from dispatcher.ws_server import WebSocketServer


# ── Helpers ──────────────────────────────────────────────────────────────


def make_session(msg_id: int = 1, text: str = "test", cwd: str = "/tmp") -> Session:
    return Session(msg_id, text, cwd)


class FakeWebSocket:
    """Minimal ServerConnection mock for testing."""

    def __init__(self):
        self.sent: list[dict] = []
        self.closed = False
        self.remote_address = ("127.0.0.1", 9999)

    async def send(self, data: str):
        if self.closed:
            raise Exception("ConnectionClosed")
        self.sent.append(json.loads(data))


# ── 1. Single-Send Contract ─────────────────────────────────────────────


class TestSingleSendContract:
    """Verify that final (non-streaming) responses are sent exactly once."""

    @pytest.mark.asyncio
    async def test_final_response_sent_once(self):
        """Calling send_response with streaming=False twice should suppress the second."""
        ws = WebSocketServer(port=0)
        client = FakeWebSocket()
        ws._clients.add(client)

        # First final send should succeed
        ok1 = await ws.send_response(client, "msg-1", "Hello", streaming=False)
        assert ok1 is True
        assert len(client.sent) == 1
        assert client.sent[0]["content"] == "Hello"

        # Second final send for same ID should be suppressed
        ok2 = await ws.send_response(client, "msg-1", "Hello again", streaming=False)
        assert ok2 is False
        assert len(client.sent) == 1  # Still 1 — no duplicate

    @pytest.mark.asyncio
    async def test_streaming_responses_not_blocked(self):
        """Streaming responses should always be sent (not guarded by single-send)."""
        ws = WebSocketServer(port=0)
        client = FakeWebSocket()
        ws._clients.add(client)

        # Multiple streaming sends are fine
        await ws.send_response(client, "msg-1", "chunk 1", streaming=True)
        await ws.send_response(client, "msg-1", "chunk 2", streaming=True)
        assert len(client.sent) == 2

        # Final send after streaming should work
        ok = await ws.send_response(client, "msg-1", "final", streaming=False)
        assert ok is True
        assert len(client.sent) == 3

        # But second final should be blocked
        ok = await ws.send_response(client, "msg-1", "dupe", streaming=False)
        assert ok is False
        assert len(client.sent) == 3

    @pytest.mark.asyncio
    async def test_different_ids_independent(self):
        """Single-send guard is per message ID, not global."""
        ws = WebSocketServer(port=0)
        client = FakeWebSocket()
        ws._clients.add(client)

        ok1 = await ws.send_response(client, "msg-1", "r1", streaming=False)
        ok2 = await ws.send_response(client, "msg-2", "r2", streaming=False)
        assert ok1 is True
        assert ok2 is True
        assert len(client.sent) == 2

    @pytest.mark.asyncio
    async def test_session_final_sent_flag(self):
        """Session.final_sent starts False and can be set to True."""
        s = make_session()
        assert s.final_sent is False
        s.final_sent = True
        assert s.final_sent is True

    @pytest.mark.asyncio
    async def test_final_sent_eviction(self):
        """The _final_sent set should not grow unboundedly."""
        ws = WebSocketServer(port=0)
        client = FakeWebSocket()
        ws._clients.add(client)

        # Send 600 unique final responses
        for i in range(600):
            await ws.send_response(client, f"msg-{i}", f"r{i}", streaming=False)

        # Set should have been trimmed
        assert len(ws._final_sent) <= 500


# ── 2. Quote/Reply-To Enforcement ───────────────────────────────────────


class TestReplyToEnforcement:
    """Verify that responses include reply_to linking back to the request."""

    @pytest.mark.asyncio
    async def test_response_includes_reply_to(self):
        """send_response with reply_to should include it in the wire message."""
        ws = WebSocketServer(port=0)
        client = FakeWebSocket()
        ws._clients.add(client)

        await ws.send_response(
            client, "msg-1", "Hello",
            streaming=False, reply_to="msg-1",
        )
        msg = client.sent[0]
        assert msg["reply_to"] == "msg-1"
        assert msg["id"] == "msg-1"
        assert msg["type"] == "response"

    @pytest.mark.asyncio
    async def test_streaming_response_no_reply_to(self):
        """Streaming responses without reply_to should not include the field."""
        ws = WebSocketServer(port=0)
        client = FakeWebSocket()
        ws._clients.add(client)

        await ws.send_response(client, "msg-1", "chunk", streaming=True)
        msg = client.sent[0]
        assert "reply_to" not in msg

    @pytest.mark.asyncio
    async def test_broadcast_response_reply_to(self):
        """broadcast_response with reply_to should include it."""
        ws = WebSocketServer(port=0)
        client = FakeWebSocket()
        ws._clients.add(client)

        await ws.broadcast_response("msg-1", "Hello", streaming=False, reply_to="msg-1")
        msg = client.sent[0]
        assert msg["reply_to"] == "msg-1"

    @pytest.mark.asyncio
    async def test_question_includes_reply_to(self):
        """send_question with reply_to should include it in the wire message."""
        ws = WebSocketServer(port=0)
        client = FakeWebSocket()
        ws._clients.add(client)

        await ws.send_question(
            client, "msg-1", "sid-123", "What?", ["Yes", "No"],
            reply_to="msg-1",
        )
        msg = client.sent[0]
        assert msg["reply_to"] == "msg-1"
        assert msg["type"] == "question"


# ── 3. Retry with Backoff ───────────────────────────────────────────────


class TestRetryTracking:
    """Verify session retry tracking fields."""

    def test_retry_count_starts_at_zero(self):
        s = make_session()
        assert s.retry_count == 0

    def test_max_retries_default(self):
        s = make_session()
        assert s.max_retries == 2

    def test_retry_count_incrementable(self):
        s = make_session()
        s.retry_count = 1
        assert s.retry_count == 1


# ── 4. Cooperative Cancellation ─────────────────────────────────────────


class TestCooperativeCancellation:
    """Verify cancel_event-based cooperative cancellation."""

    def test_not_cancelled_by_default(self):
        s = make_session()
        assert s.is_cancelled is False

    def test_request_cancel_sets_event(self):
        s = make_session()
        s.request_cancel()
        assert s.is_cancelled is True

    def test_cancel_event_is_asyncio_event(self):
        s = make_session()
        assert isinstance(s.cancel_event, asyncio.Event)
        assert not s.cancel_event.is_set()
        s.request_cancel()
        assert s.cancel_event.is_set()


# ── 5. Observability / Pipeline Stage Tracking ──────────────────────────


class TestObservability:
    """Verify pipeline stage recording and duration computation."""

    def test_record_stage(self):
        s = make_session()
        before = time.time()
        s.record_stage("received")
        after = time.time()

        assert "received" in s.stage_times
        assert before <= s.stage_times["received"] <= after

    def test_multiple_stages(self):
        s = make_session()
        s.record_stage("received")
        s.record_stage("classified")
        s.record_stage("dispatched")

        assert len(s.stage_times) == 3
        assert s.stage_times["received"] <= s.stage_times["classified"]

    def test_stage_durations(self):
        s = make_session()
        now = time.time()
        s.stage_times = {
            "received": now,
            "classified": now + 0.5,
            "dispatched": now + 1.2,
        }

        durations = s.stage_durations()
        assert "received->classified" in durations
        assert "classified->dispatched" in durations
        assert abs(durations["received->classified"] - 0.5) < 0.01
        assert abs(durations["classified->dispatched"] - 0.7) < 0.01

    def test_stage_durations_empty(self):
        s = make_session()
        assert s.stage_durations() == {}

    def test_stage_durations_single(self):
        s = make_session()
        s.record_stage("received")
        assert s.stage_durations() == {}


# ── Integration: Session + SessionManager ────────────────────────────────


class TestSessionManagerIntegration:
    """Verify that new fields survive SessionManager.create() flow."""

    def test_create_session_has_new_fields(self):
        sm = SessionManager()
        s = sm.create(1, "test", "/tmp")
        assert s.final_sent is False
        assert s.retry_count == 0
        assert s.max_retries == 2
        assert s.is_cancelled is False
        assert isinstance(s.stage_times, dict)
        assert len(s.stage_times) == 0

    def test_cancel_via_session_manager(self):
        sm = SessionManager()
        s = sm.create(1, "test", "/tmp")
        s.status = "running"
        s.request_cancel()
        assert s.is_cancelled is True
        # Session is still "running" until handler checks is_cancelled
        assert s.status == "running"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
