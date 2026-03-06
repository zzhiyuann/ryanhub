"""Tests for shared conversation context across parallel sessions.

Validates:
1. Two quick messages in parallel share conv_id and conversation history
2. Follow-up after 4 messages sees all prior turns
3. Reply correctness — each parallel session gets the right context
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dispatcher.session import Session, SessionManager
from dispatcher.transcript import Transcript


# ── Helpers ──────────────────────────────────────────────────────────────


def make_sm() -> SessionManager:
    return SessionManager()


def make_transcript(tmp_path: Path) -> Transcript:
    return Transcript(tmp_path)


# ── 1. Two Quick Messages in Parallel ────────────────────────────────────


class TestParallelSessionsShareContext:
    """When two messages arrive while sessions are active, they must share conv_id."""

    def test_second_session_inherits_conv_id(self):
        """A new session in the same cwd inherits conv_id from the last session."""
        sm = make_sm()
        s1 = sm.create(1, "first message", "/projects/foo")
        s1.status = "running"

        # Simulate parallel: second message arrives while first is running
        shared_conv_id = sm.last_conv_id_for_cwd("/projects/foo")
        s2 = sm.create(2, "second message", "/projects/foo", conv_id=shared_conv_id)

        assert s2.conv_id == s1.conv_id
        assert s2.sid != s1.sid  # Tool-state isolation preserved

    def test_different_project_gets_fresh_conv_id(self):
        """A new session in a different cwd does NOT inherit conv_id."""
        sm = make_sm()
        s1 = sm.create(1, "first message", "/projects/foo")
        s1.status = "running"

        shared_conv_id = sm.last_conv_id_for_cwd("/projects/bar")
        s2 = sm.create(2, "second message", "/projects/bar", conv_id=shared_conv_id)

        # shared_conv_id is None → s2 gets its own conv_id
        assert s2.conv_id != s1.conv_id

    def test_parallel_sessions_write_to_same_transcript(self, tmp_path):
        """Both parallel sessions append to the same transcript file."""
        sm = make_sm()
        transcript = make_transcript(tmp_path)

        s1 = sm.create(1, "hello", "/projects/foo")
        transcript.append(s1.conv_id, "user", "hello")
        s1.status = "running"

        # Second session inherits conv_id
        shared_conv_id = sm.last_conv_id_for_cwd("/projects/foo")
        s2 = sm.create(2, "how are you?", "/projects/foo", conv_id=shared_conv_id)
        transcript.append(s2.conv_id, "user", "how are you?")

        # Both messages are in the same transcript
        msgs = transcript.load(s1.conv_id)
        assert len(msgs) == 2
        assert msgs[0]["content"] == "hello"
        assert msgs[1]["content"] == "how are you?"

    def test_parallel_session_sees_prior_history(self, tmp_path):
        """A parallel session's prompt should include history from prior turns."""
        transcript = make_transcript(tmp_path)
        sm = make_sm()

        # First session writes its conversation
        s1 = sm.create(1, "hello", "/projects/foo")
        transcript.append(s1.conv_id, "user", "hello")
        s1.status = "running"

        # Second session inherits conv_id and checks for history
        shared_conv_id = sm.last_conv_id_for_cwd("/projects/foo")
        s2 = sm.create(2, "how are you?", "/projects/foo", conv_id=shared_conv_id)

        assert transcript.has_history(s2.conv_id)
        history = transcript.build_history(s2.conv_id)
        assert "[User]: hello" in history

    def test_force_new_prevents_conv_id_inheritance(self):
        """When force_new is set, new sessions should NOT inherit conv_id."""
        sm = make_sm()
        s1 = sm.create(1, "first message", "/projects/foo")
        s1.status = "done"

        # Simulate /new command
        sm.force_new = True
        # Application code should pass conv_id=None when start_fresh is True
        shared_conv_id = None  # start_fresh = True → skip inheritance
        s2 = sm.create(2, "fresh start", "/projects/foo", conv_id=shared_conv_id)

        assert s2.conv_id != s1.conv_id


# ── 2. Follow-up Referencing Prior 4 Messages ────────────────────────────


class TestFollowUpSeesFullHistory:
    """A follow-up message should see all prior turns in the conversation."""

    def test_four_turn_history_visible(self, tmp_path):
        """After 4 messages (2 user + 2 assistant), follow-up sees all 4."""
        transcript = make_transcript(tmp_path)

        conv_id = "test-conv-123"
        transcript.append(conv_id, "user", "What is Python?")
        transcript.append(conv_id, "assistant", "Python is a programming language.")
        transcript.append(conv_id, "user", "What about JavaScript?")
        transcript.append(conv_id, "assistant", "JavaScript is used for web development.")

        history = transcript.build_history(conv_id)
        assert "[User]: What is Python?" in history
        assert "[Assistant]: Python is a programming language." in history
        assert "[User]: What about JavaScript?" in history
        assert "[Assistant]: JavaScript is used for web development." in history

    def test_parallel_then_followup_sees_all(self, tmp_path):
        """After two parallel sessions complete, a follow-up sees all turns."""
        transcript = make_transcript(tmp_path)
        sm = make_sm()

        # First session
        s1 = sm.create(1, "analyze code", "/projects/foo")
        transcript.append(s1.conv_id, "user", "analyze code")
        s1.status = "running"

        # Second session (parallel) inherits conv_id
        shared = sm.last_conv_id_for_cwd("/projects/foo")
        s2 = sm.create(2, "check tests", "/projects/foo", conv_id=shared)
        transcript.append(s2.conv_id, "user", "check tests")

        # Both complete
        transcript.append(s1.conv_id, "assistant", "Code analysis: all good.")
        s1.status = "done"
        transcript.append(s2.conv_id, "assistant", "Tests: 42 passed, 0 failed.")
        s2.status = "done"

        # Follow-up message
        history = transcript.build_history(s1.conv_id)
        assert "[User]: analyze code" in history
        assert "[User]: check tests" in history
        assert "[Assistant]: Code analysis: all good." in history
        assert "[Assistant]: Tests: 42 passed, 0 failed." in history

    def test_history_order_preserved(self, tmp_path):
        """Messages appear in chronological order in history."""
        transcript = make_transcript(tmp_path)

        conv_id = "order-test"
        transcript.append(conv_id, "user", "msg-1")
        transcript.append(conv_id, "user", "msg-2")
        transcript.append(conv_id, "assistant", "reply-1")
        transcript.append(conv_id, "assistant", "reply-2")

        history = transcript.build_history(conv_id)
        pos_1 = history.index("msg-1")
        pos_2 = history.index("msg-2")
        pos_r1 = history.index("reply-1")
        pos_r2 = history.index("reply-2")
        assert pos_1 < pos_2 < pos_r1 < pos_r2


# ── 3. Reply Correctness ─────────────────────────────────────────────────


class TestReplyCorrectness:
    """Each parallel session should receive the correct conversation context."""

    def test_session_ids_are_unique(self):
        """Parallel sessions must have distinct session IDs for tool isolation."""
        sm = make_sm()
        s1 = sm.create(1, "task A", "/projects/foo")
        shared = sm.last_conv_id_for_cwd("/projects/foo")
        s2 = sm.create(2, "task B", "/projects/foo", conv_id=shared)

        assert s1.sid != s2.sid
        assert s1.conv_id == s2.conv_id

    def test_conv_id_chains_across_three_parallel(self):
        """Three rapid parallel messages all share the same conv_id."""
        sm = make_sm()
        s1 = sm.create(1, "msg A", "/projects/foo")
        s1.status = "running"

        shared = sm.last_conv_id_for_cwd("/projects/foo")
        s2 = sm.create(2, "msg B", "/projects/foo", conv_id=shared)
        s2.status = "running"

        shared = sm.last_conv_id_for_cwd("/projects/foo")
        s3 = sm.create(3, "msg C", "/projects/foo", conv_id=shared)

        assert s1.conv_id == s2.conv_id == s3.conv_id
        assert len({s1.sid, s2.sid, s3.sid}) == 3  # All different sids

    def test_has_history_false_for_new_conv(self, tmp_path):
        """A brand new conversation has no history."""
        transcript = make_transcript(tmp_path)
        assert not transcript.has_history("nonexistent-conv")

    def test_has_history_true_after_append(self, tmp_path):
        """After appending a message, has_history returns True."""
        transcript = make_transcript(tmp_path)
        transcript.append("test-conv", "user", "hello")
        assert transcript.has_history("test-conv")

    def test_last_conv_id_for_cwd_returns_most_recent(self):
        """last_conv_id_for_cwd returns the most recently created session's conv_id."""
        sm = make_sm()
        s1 = sm.create(1, "old", "/projects/foo")
        s1.status = "done"

        s2 = sm.create(2, "new", "/projects/foo")
        s2.status = "running"

        result = sm.last_conv_id_for_cwd("/projects/foo")
        assert result == s2.conv_id

    def test_last_conv_id_for_cwd_skips_other_projects(self):
        """last_conv_id_for_cwd only matches the requested cwd."""
        sm = make_sm()
        s1 = sm.create(1, "foo task", "/projects/foo")
        s2 = sm.create(2, "bar task", "/projects/bar")

        result = sm.last_conv_id_for_cwd("/projects/foo")
        assert result == s1.conv_id
        assert result != s2.conv_id

    def test_last_conv_id_for_cwd_returns_none_when_empty(self):
        """Returns None when no sessions exist for the given cwd."""
        sm = make_sm()
        assert sm.last_conv_id_for_cwd("/projects/foo") is None


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
