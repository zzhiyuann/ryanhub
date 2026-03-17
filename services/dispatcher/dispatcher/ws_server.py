"""WebSocket server for native app connectivity.

Runs alongside the Telegram bot, accepting WebSocket connections
on a configurable port. Uses the same routing/session logic.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
import uuid
from typing import Any, Callable, Awaitable

import websockets
from websockets.asyncio.server import Server, ServerConnection

log = logging.getLogger("dispatcher")

# Type for the message handler callback provided by core.py
# Args: content, project, msg_id, websocket, image_base64, audio_base64, audio_duration, language, target_agent
MessageHandler = Callable[
    [str, str | None, str, "ServerConnection", str | None, str | None, float | None, str | None, str | None],
    Awaitable[str],
]

# Type for the command handler callback provided by core.py
# Args: command, data (full message dict)
# Returns: dict with structured response data
CommandHandler = Callable[
    [str, dict[str, Any]],
    Awaitable[dict[str, Any]],
]

# Type for the answer handler callback provided by core.py
# Args: session_id_prefix, answer_text, msg_id
AnswerHandler = Callable[
    [str, str, str],
    Awaitable[None],
]

# Type for the edit handler callback provided by core.py
# Args: original_msg_id, new_content, websocket
# Returns: dict with {"ok": bool, "error"?: str}
EditHandler = Callable[
    [str, str, "ServerConnection"],
    Awaitable[dict[str, Any]],
]


class WebSocketServer:
    """WebSocket server that bridges native app clients to the Dispatcher.

    Accepts connections, authenticates them (optional token), and routes
    messages through the same pipeline as Telegram.
    """

    def __init__(
        self,
        host: str = "0.0.0.0",
        port: int = 8765,
        auth_token: str = "",
        on_message: MessageHandler | None = None,
        on_command: CommandHandler | None = None,
        on_answer: AnswerHandler | None = None,
        on_edit: EditHandler | None = None,
    ):
        self.host = host
        self.port = port
        self.auth_token = auth_token
        self.on_message = on_message
        self.on_command = on_command
        self.on_answer = on_answer
        self.on_edit = on_edit
        self._server: Server | None = None
        self._clients: set[ServerConnection] = set()
        self._status_task: asyncio.Task | None = None
        self._active_sessions_count: int = 0
        # Cache of final responses that failed to deliver (client disconnected).
        # List of dicts: {"type": "response", "id": msg_id, "content": ..., "streaming": False, "ts": ...}
        # Replayed to the next client that connects. Single-user app so no keying needed.
        self._pending_deliveries: list[dict] = []

    async def start(self) -> None:
        """Start the WebSocket server."""
        self._server = await websockets.serve(
            self._handle_connection,
            self.host,
            self.port,
        )
        log.info("WebSocket server listening on ws://%s:%d", self.host, self.port)
        # Start periodic status broadcast
        self._status_task = asyncio.create_task(self._status_loop())

    async def stop(self) -> None:
        """Stop the WebSocket server and disconnect all clients."""
        if self._status_task:
            self._status_task.cancel()
            try:
                await self._status_task
            except asyncio.CancelledError:
                pass

        if self._server:
            self._server.close()
            await self._server.wait_closed()
            log.info("WebSocket server stopped")

        self._clients.clear()

    def update_session_count(self, count: int) -> None:
        """Update the active session count (called by core.py)."""
        self._active_sessions_count = count

    @property
    def client_count(self) -> int:
        """Number of currently connected clients."""
        return len(self._clients)

    # -- Connection handling --

    async def _handle_connection(self, websocket: ServerConnection) -> None:
        """Handle a new WebSocket client connection."""
        # Authenticate if token is configured
        if self.auth_token:
            try:
                raw = await asyncio.wait_for(websocket.recv(), timeout=10)
                data = json.loads(raw)
                if data.get("type") != "auth" or data.get("token") != self.auth_token:
                    await self._send(websocket, {
                        "type": "error",
                        "id": data.get("id", ""),
                        "message": "Authentication failed",
                    })
                    await websocket.close(4001, "Authentication failed")
                    return
            except (asyncio.TimeoutError, json.JSONDecodeError, Exception) as exc:
                log.warning("ws auth failed: %s", exc)
                await websocket.close(4001, "Authentication timeout or invalid")
                return

        self._clients.add(websocket)
        remote = websocket.remote_address
        log.info("ws client connected: %s (total: %d)", remote, len(self._clients))

        # Send initial status
        await self.send_status(websocket)

        # Replay any responses that failed to deliver while the client was away
        if self._pending_deliveries:
            log.info("ws replaying %d pending deliveries to reconnected client", len(self._pending_deliveries))
            for msg in self._pending_deliveries:
                await self._send(websocket, msg)
            self._pending_deliveries.clear()

        try:
            async for raw_message in websocket:
                try:
                    data = json.loads(raw_message)
                    await self._handle_message(websocket, data)
                except json.JSONDecodeError:
                    await self._send(websocket, {
                        "type": "error",
                        "id": "",
                        "message": "Invalid JSON",
                    })
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            self._clients.discard(websocket)
            log.info("ws client disconnected: %s (remaining: %d)", remote, len(self._clients))

    async def _handle_message(self, websocket: ServerConnection, data: dict) -> None:
        """Process an incoming WebSocket message.

        Messages are dispatched concurrently so multiple user messages
        can be in-flight at the same time (first-response-first-arrive).
        """
        msg_type = data.get("type", "")
        msg_id = data.get("id", str(uuid.uuid4()))

        if msg_type == "ping":
            await self._send(websocket, {"type": "pong", "id": msg_id})
            return

        if msg_type == "command":
            cmd = data.get("command", "").strip()
            if not cmd:
                await self._send(websocket, {
                    "type": "error",
                    "id": msg_id,
                    "message": "Empty command",
                })
                return
            asyncio.create_task(self._process_command(websocket, msg_id, cmd, data))
            return

        if msg_type == "answer":
            session_id = data.get("session_id", "").strip()
            answer = data.get("answer", "").strip()
            if not session_id or not answer:
                await self._send(websocket, {
                    "type": "error",
                    "id": msg_id,
                    "message": "Answer requires session_id and answer fields",
                })
                return
            if self.on_answer:
                try:
                    await self.on_answer(session_id, answer, msg_id)
                except Exception as exc:
                    log.exception("ws answer handler error for session %s", session_id)
                    await self._send(websocket, {
                        "type": "error",
                        "id": msg_id,
                        "message": f"Answer error: {str(exc)[:200]}",
                    })
            return

        if msg_type == "edit":
            content = data.get("content", "").strip()
            if not content:
                await self._send(websocket, {
                    "type": "error",
                    "id": msg_id,
                    "message": "Edit requires non-empty content",
                })
                return
            asyncio.create_task(self._process_edit(websocket, msg_id, content))
            return

        if msg_type == "notification":
            # External services can push notifications to all connected clients
            # without going through the agent pipeline.
            content = data.get("content", "").strip()
            source = data.get("source", "system")
            if content:
                await self.broadcast({
                    "type": "notification",
                    "id": msg_id,
                    "content": content,
                    "source": source,
                })
                log.info("ws notification broadcast from %s: %s", source, content[:80])
            return

        if msg_type == "message":
            content = data.get("content", "").strip()
            image_base64 = data.get("image_base64")
            audio_base64 = data.get("audio_base64")
            audio_duration = data.get("duration")
            language = data.get("language")
            target_agent = data.get("target_agent")

            # Allow empty content if there's an image or audio
            if not content and not image_base64 and not audio_base64:
                await self._send(websocket, {
                    "type": "error",
                    "id": msg_id,
                    "message": "Empty message content",
                })
                return

            project = data.get("project")

            # Acknowledge receipt immediately so the client can show 👀
            await self._send(websocket, {
                "type": "ack",
                "id": msg_id,
            })

            # Dispatch handling concurrently (fire-and-forget) so we don't
            # block the receive loop — the next message can start processing
            # right away.
            asyncio.create_task(
                self._process_message(
                    websocket, msg_id, content, project,
                    image_base64, audio_base64, audio_duration, language, target_agent,
                )
            )
            return

        # Unknown message type
        await self._send(websocket, {
            "type": "error",
            "id": msg_id,
            "message": f"Unknown message type: {msg_type}",
        })

    async def _process_message(
        self,
        websocket: ServerConnection,
        msg_id: str,
        content: str,
        project: str | None,
        image_base64: str | None,
        audio_base64: str | None,
        audio_duration: float | None,
        language: str | None,
        target_agent: str | None,
    ) -> None:
        """Process a single message through the dispatcher pipeline.

        Runs as a concurrent task so multiple messages can be handled in parallel.
        """
        if self.on_message:
            try:
                result = await self.on_message(
                    content, project, msg_id, websocket,
                    image_base64, audio_base64, audio_duration, language, target_agent,
                )
                # Pick best target: original ws if still connected, else any active client
                response_data = {
                    "type": "response",
                    "id": msg_id,
                    "content": result or "",
                    "streaming": False,
                }
                target = self.get_active_client(websocket)
                if target:
                    await self._send(target, response_data)
                else:
                    # No client connected — cache for later replay
                    self._cache_if_important(response_data)
            except Exception as exc:
                log.exception("ws message handler error for msg %s", msg_id[:8])
                error_data = {
                    "type": "error",
                    "id": msg_id,
                    "message": f"Handler error: {str(exc)[:200]}",
                }
                target = self.get_active_client(websocket)
                if target:
                    await self._send(target, error_data)
                else:
                    self._cache_if_important(error_data)
        else:
            await self._send(websocket, {
                "type": "error",
                "id": msg_id,
                "message": "No message handler configured",
            })

    async def _process_command(
        self,
        websocket: ServerConnection,
        msg_id: str,
        command: str,
        data: dict,
    ) -> None:
        """Process a slash command and return a structured response.

        Runs as a concurrent task so it doesn't block the receive loop.
        """
        if self.on_command:
            try:
                result = await self.on_command(command, data)
                target = self.get_active_client(websocket)
                if target:
                    await self._send(target, {
                        "type": "command_result",
                        "id": msg_id,
                        "command": command,
                        "data": result,
                    })
                else:
                    self._cache_if_important({
                        "type": "command_result",
                        "id": msg_id,
                        "command": command,
                        "data": result,
                    })
            except Exception as exc:
                log.exception("ws command handler error for %s", command)
                error_data = {
                    "type": "error",
                    "id": msg_id,
                    "message": f"Command error: {str(exc)[:200]}",
                }
                target = self.get_active_client(websocket)
                if target:
                    await self._send(target, error_data)
                else:
                    self._cache_if_important(error_data)
        else:
            await self._send(websocket, {
                "type": "error",
                "id": msg_id,
                "message": "No command handler configured",
            })

    async def _process_edit(
        self,
        websocket: ServerConnection,
        msg_id: str,
        content: str,
    ) -> None:
        """Process an edit request for a previously sent message.

        Delegates to the on_edit callback which handles session lookup,
        process killing, and re-dispatch.
        """
        if self.on_edit:
            try:
                result = await self.on_edit(msg_id, content, websocket)
                target = self.get_active_client(websocket)
                if result.get("ok"):
                    if target:
                        await self._send(target, {
                            "type": "edit_ack",
                            "id": msg_id,
                        })
                else:
                    error_data = {
                        "type": "error",
                        "id": msg_id,
                        "message": result.get("error", "Edit failed"),
                    }
                    if target:
                        await self._send(target, error_data)
                    else:
                        self._cache_if_important(error_data)
            except Exception as exc:
                log.exception("ws edit handler error for msg %s", msg_id[:8])
                error_data = {
                    "type": "error",
                    "id": msg_id,
                    "message": f"Edit error: {str(exc)[:200]}",
                }
                target = self.get_active_client(websocket)
                if target:
                    await self._send(target, error_data)
                else:
                    self._cache_if_important(error_data)
        else:
            await self._send(websocket, {
                "type": "error",
                "id": msg_id,
                "message": "No edit handler configured",
            })

    # -- Sending helpers --

    async def _send(self, websocket: ServerConnection, data: dict) -> None:
        """Send a JSON message to a single client. Silently handles errors.

        If the send fails for a final (non-streaming) response, the message
        is cached in ``_pending_deliveries`` and replayed when the next client
        connects.
        """
        try:
            await websocket.send(json.dumps(data, ensure_ascii=False))
        except websockets.exceptions.ConnectionClosed:
            self._clients.discard(websocket)
            self._cache_if_important(data)
        except Exception:
            log.debug("ws send failed", exc_info=True)
            self._cache_if_important(data)

    def _cache_if_important(self, data: dict) -> None:
        """Cache a message for later delivery if it's a final response or error.

        If there are active clients when caching, immediately flush the
        pending queue so reconnected clients don't miss responses that
        completed while they were away (race condition fix).
        Also triggers Telegram fallback notification when no clients are connected.
        """
        msg_type = data.get("type")
        is_final_response = msg_type == "response" and not data.get("streaming", False)
        is_error = msg_type == "error"
        is_question = msg_type == "question"
        if is_final_response or is_error or is_question:
            data["_cached_at"] = time.time()
            self._pending_deliveries.append(data)
            log.info("ws cached undelivered %s (id=%s) for replay", msg_type, data.get("id", "?")[:8])
            # Immediately try to flush to any connected clients — this closes
            # the race window where a client reconnects before the task finishes
            # and the replay queue is still empty at replay time.
            if self._clients:
                asyncio.create_task(self._flush_pending())
            elif is_final_response and not self._clients:
                # No WS clients connected — send via Telegram as fallback
                asyncio.create_task(self._telegram_fallback(data))

    async def _telegram_fallback(self, data: dict) -> None:
        """Send a condensed notification to Telegram when iOS is disconnected.

        Uses the Boo bot (@bofacaibot) to deliver a summary so the user
        always gets notified even when the app is backgrounded/closed.
        """
        import urllib.request
        content = data.get("content", "")
        if not content or len(content) < 5:
            return
        # Truncate for Telegram (max 4096 chars)
        if len(content) > 3000:
            content = content[:3000] + "\n\n[truncated — open RyanHub for full response]"
        bot_token = "7740709485:AAF35LkeavJ5-F4C6hcG5PC_7RdC9AeI8lI"
        chat_id = 7542082932
        try:
            payload = json.dumps({
                "chat_id": chat_id,
                "text": f"📱 [RyanHub] Facai says:\n\n{content}",
            }).encode()
            req = urllib.request.Request(
                f"https://api.telegram.org/bot{bot_token}/sendMessage",
                data=payload,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            await asyncio.to_thread(lambda: urllib.request.urlopen(req, timeout=5))
            log.info("ws telegram fallback sent (%d chars)", len(content))
        except Exception as e:
            log.debug("ws telegram fallback failed: %s", e)

    async def _flush_pending(self) -> None:
        """Send all pending deliveries to currently connected clients."""
        if not self._pending_deliveries or not self._clients:
            return
        pending = list(self._pending_deliveries)
        self._pending_deliveries.clear()
        log.info("ws flushing %d pending deliveries to %d active clients", len(pending), len(self._clients))
        for msg in pending:
            await self.broadcast(msg)

    def get_active_client(self, preferred: ServerConnection | None = None) -> ServerConnection | None:
        """Return preferred client if still active, else any connected client."""
        if preferred and preferred in self._clients:
            return preferred
        return next(iter(self._clients), None)

    async def send_response(
        self,
        websocket: ServerConnection,
        msg_id: str,
        content: str,
        streaming: bool = True,
        delta: str | None = None,
    ) -> None:
        """Send a response message to a specific client.

        If the original websocket is dead, retarget to any active client.
        ``delta`` contains only the new text since the last update, allowing
        the client to append efficiently instead of replacing the full content.
        """
        target = self.get_active_client(websocket)
        if target:
            data: dict = {
                "type": "response",
                "id": msg_id,
                "content": content,
                "streaming": streaming,
            }
            if delta is not None:
                data["delta"] = delta
            await self._send(target, data)
        elif not streaming:
            # Only cache non-streaming (final) responses
            self._cache_if_important({
                "type": "response",
                "id": msg_id,
                "content": content,
                "streaming": streaming,
            })

    async def send_status(self, websocket: ServerConnection) -> None:
        """Send current status to a specific client."""
        await self._send(websocket, {
            "type": "status",
            "connected": True,
            "active_sessions": self._active_sessions_count,
        })

    async def send_question(
        self,
        websocket: ServerConnection,
        msg_id: str,
        session_id: str,
        question: str,
        options: list[str],
        allow_free_text: bool = True,
    ) -> None:
        """Send an AskUserQuestion to a specific WebSocket client."""
        target = self.get_active_client(websocket)
        if not target:
            # Cache for replay — question is important
            self._cache_if_important({
                "type": "question",
                "id": msg_id,
                "session_id": session_id,
                "question": question,
                "options": options,
                "allow_free_text": allow_free_text,
            })
            return
        await self._send(target, {
            "type": "question",
            "id": msg_id,
            "session_id": session_id,
            "question": question,
            "options": options,
            "allow_free_text": allow_free_text,
        })

    async def broadcast(self, data: dict) -> None:
        """Send a message to all connected clients."""
        if not self._clients:
            return
        message = json.dumps(data, ensure_ascii=False)
        # Send to all clients concurrently, remove dead ones
        dead: list[ServerConnection] = []
        tasks = []
        for ws in self._clients:
            tasks.append(self._try_send(ws, message, dead))
        if tasks:
            await asyncio.gather(*tasks)
        for ws in dead:
            self._clients.discard(ws)

    async def _try_send(
        self, ws: ServerConnection, message: str, dead: list[ServerConnection]
    ) -> None:
        """Attempt to send to a client, marking it dead on failure."""
        try:
            await ws.send(message)
        except Exception:
            dead.append(ws)

    async def broadcast_response(
        self, msg_id: str, content: str, streaming: bool = True
    ) -> None:
        """Broadcast a response to all connected clients."""
        await self.broadcast({
            "type": "response",
            "id": msg_id,
            "content": content,
            "streaming": streaming,
        })

    async def broadcast_status(self) -> None:
        """Broadcast current status to all connected clients."""
        await self.broadcast({
            "type": "status",
            "connected": True,
            "active_sessions": self._active_sessions_count,
        })

    # -- Background tasks --

    async def _status_loop(self) -> None:
        """Periodically send status updates to all connected clients."""
        try:
            while True:
                await asyncio.sleep(30)
                if self._clients:
                    await self.broadcast_status()
        except asyncio.CancelledError:
            pass
