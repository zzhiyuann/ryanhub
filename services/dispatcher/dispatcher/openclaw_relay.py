"""Thin WebSocket relay: iOS <-> OpenClaw Gateway.

Replaces the heavy Dispatcher by forwarding iOS chat messages to the
OpenClaw gateway via `openclaw agent` CLI and streaming responses back.

Usage:
    python -m dispatcher.openclaw_relay [--port 8765]
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import shutil
import subprocess
import uuid
from pathlib import Path

log = logging.getLogger("openclaw-relay")

OPENCLAW_CLI = shutil.which("openclaw") or "/opt/homebrew/bin/openclaw"
DEFAULT_PORT = 8765
AGENT_ID = "main"  # OpenClaw agent to route to
SESSION_ID = "ryanhub-ios"  # Dedicated session to avoid lock conflicts with Telegram
TIMEOUT_SECONDS = 600


# ---------------------------------------------------------------------------
# WebSocket server
# ---------------------------------------------------------------------------

async def handle_client(reader_ws, path=None):
    """Handle a single iOS WebSocket connection."""
    import websockets
    log.info("iOS client connected")

    try:
        async for raw in reader_ws:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue

            msg_type = msg.get("type", "")
            msg_id = msg.get("id", str(uuid.uuid4()))

            if msg_type == "message":
                # Send ack immediately
                ack = {"type": "ack", "id": msg_id}
                await reader_ws.send(json.dumps(ack))

                # Extract content (strip PersonalContext if iOS still injects it)
                content = msg.get("content", "")
                language = msg.get("language", "en")

                # Run through OpenClaw agent
                asyncio.create_task(
                    _process_and_respond(reader_ws, msg_id, content, language)
                )

            elif msg_type == "ping":
                await reader_ws.send(json.dumps({"type": "pong"}))

    except Exception as e:
        log.warning("Client disconnected: %s", e)
    finally:
        log.info("iOS client disconnected")


async def _process_and_respond(ws, msg_id: str, content: str, language: str):
    """Send message to OpenClaw agent and relay response back to iOS."""
    resp_id = f"resp-{msg_id}"

    try:
        # Build the OpenClaw agent command
        cmd = [
            OPENCLAW_CLI, "agent",
            "--agent", AGENT_ID,
            "--session-id", SESSION_ID,
            "--message", content,
            "--json",
            "--timeout", str(TIMEOUT_SECONDS),
        ]

        # Send "processing" status
        await ws.send(json.dumps({
            "type": "response",
            "id": resp_id,
            "requestId": msg_id,
            "content": "",
            "streaming": True,
            "delta": "",
        }))

        # Run openclaw agent asynchronously
        env = os.environ.copy()
        env.pop("CLAUDE_CODE", None)
        env.pop("CLAUDECODE", None)

        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=env,
        )

        stdout_data, stderr_data = await asyncio.wait_for(
            process.communicate(),
            timeout=TIMEOUT_SECONDS + 30,
        )

        stdout_text = stdout_data.decode("utf-8", errors="replace")

        # Parse response JSON
        # The output may have log lines before the JSON
        json_start = stdout_text.find("{")
        if json_start >= 0:
            try:
                result = json.loads(stdout_text[json_start:])
                payloads = result.get("result", {}).get("payloads", [])
                response_text = "\n\n".join(
                    p.get("text", "") for p in payloads if p.get("text")
                )
            except json.JSONDecodeError:
                response_text = stdout_text[json_start:]
        else:
            response_text = stdout_text.strip() or "No response from agent"

        if not response_text and stderr_data:
            response_text = f"Agent error: {stderr_data.decode()[:200]}"

        # Send final response
        await ws.send(json.dumps({
            "type": "response",
            "id": resp_id,
            "requestId": msg_id,
            "content": response_text,
            "streaming": False,
            "delta": response_text,
        }))

    except asyncio.TimeoutError:
        await ws.send(json.dumps({
            "type": "error",
            "id": msg_id,
            "content": "Agent timed out after %d seconds" % TIMEOUT_SECONDS,
        }))
    except Exception as e:
        log.error("Error processing message: %s", e)
        try:
            await ws.send(json.dumps({
                "type": "error",
                "id": msg_id,
                "content": f"Relay error: {e}",
            }))
        except Exception:
            pass


async def start_relay(port: int = DEFAULT_PORT):
    """Start the WebSocket relay server."""
    import websockets
    log.info("OpenClaw relay starting on port %d", port)
    async with websockets.serve(handle_client, "0.0.0.0", port):
        log.info("OpenClaw relay listening on ws://0.0.0.0:%d", port)
        await asyncio.Future()  # run forever


def main():
    import argparse
    parser = argparse.ArgumentParser(description="OpenClaw WebSocket Relay")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s [%(name)s] %(message)s",
    )

    asyncio.run(start_relay(args.port))


if __name__ == "__main__":
    main()
