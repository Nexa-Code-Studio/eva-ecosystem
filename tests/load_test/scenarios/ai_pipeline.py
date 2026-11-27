"""AI Chat, SSE summary streaming, and Voice AI WebSocket stress scenario."""

from __future__ import annotations

import asyncio
import json
import time
import uuid
from functools import lru_cache
from typing import Any

import aiohttp
import websockets

from tests.load_test.audio_utils import (
    build_pcm_for_duration,
    iter_pcm_chunks,
    load_pcm_pool,
)
from tests.load_test.config import StressConfig
from tests.load_test.metrics import RequestSample, WsEventSample
from tests.load_test.scenarios.common import authenticate_or_register, timed_request


@lru_cache(maxsize=4)
def _cached_pcm_for_run(
    audio_dir: str, audio_sample_path: str | None, duration_seconds: float
) -> bytes:
    """Cache converted 16kHz mono PCM stream per worker process to avoid repeated resampling."""
    pool = load_pcm_pool(audio_dir, audio_sample_path)
    return build_pcm_for_duration(pool, duration_seconds)


async def _wait_for_call_ready(ws: Any, timeout_s: float) -> int:
    """Perform call_connected -> start_call handshake and return count of received messages."""
    received = 0
    await asyncio.wait_for(ws.recv(), timeout=timeout_s)
    received += 1
    await ws.send(json.dumps({"type": "start_call"}))
    # Drain immediate call.sync_state / greeting frame without blocking long
    try:
        await asyncio.wait_for(ws.recv(), timeout=min(timeout_s, 3.0))
        received += 1
    except asyncio.TimeoutError:
        pass
    return received


async def _run_voice_ws(
    config: StressConfig,
    token: str,
    session_id: str,
) -> WsEventSample:
    """Open /api/v1/call/ws/{session_id}, stream real 16kHz PCM audio, and measure TTFA."""
    ws_url = f"{config.ws_base_url}/call/ws/{session_id}?token={token}&voice_mode=mode_2"
    start = time.perf_counter()
    sent = 0
    received = 0
    audio_seconds = 0.0
    ttfa_ms = 0.0
    turn_latency_ms = 0.0

    try:
        pcm_stream = b""
        if config.ai_mode == "live":
            pcm_stream = _cached_pcm_for_run(
                config.audio_dir, config.audio_sample_path, config.voice_duration_seconds
            )
            audio_seconds = config.voice_duration_seconds

        async with websockets.connect(
            ws_url,
            open_timeout=config.request_timeout_seconds,
            close_timeout=5,
        ) as ws:
            connect_ms = (time.perf_counter() - start) * 1000.0
            received += await _wait_for_call_ready(ws, config.request_timeout_seconds)
            sent += 1  # start_call

            if config.ai_mode == "live" and pcm_stream:
                chunk_ms = 100
                for chunk in iter_pcm_chunks(pcm_stream, chunk_ms=chunk_ms):
                    await ws.send(chunk)
                    sent += 1
                    if config.audio_pace == "realtime":
                        await asyncio.sleep(chunk_ms / 1000.0)

                turn_start = time.perf_counter()
                if config.stt_fallback:
                    await ws.send(
                        json.dumps(
                            {
                                "type": "stt.final_segment",
                                "call_id": session_id,
                                "user_turn_id": 1,
                                "stt_session_id": 1,
                                "sequence": 1,
                                "text": "Aku merasa cemas dan stres akhir-akhir ini karena tugas menumpuk.",
                            }
                        )
                    )
                    sent += 1

                await ws.send(
                    json.dumps(
                        {
                            "type": "user.force_commit",
                            "call_id": session_id,
                            "user_turn_id": 1,
                        }
                    )
                )
                sent += 1
            else:
                turn_start = time.perf_counter()
                await ws.send(
                    json.dumps(
                        {
                            "type": "stt.final_segment",
                            "call_id": session_id,
                            "user_turn_id": 1,
                            "stt_session_id": 1,
                            "sequence": 1,
                            "text": "Halo EVA, ini adalah uji koneksi mode mock.",
                        }
                    )
                )
                await ws.send(
                    json.dumps(
                        {
                            "type": "user.force_commit",
                            "call_id": session_id,
                            "user_turn_id": 1,
                        }
                    )
                )
                sent += 2

            first_response_time: float | None = None
            wait_budget = max(config.duration_seconds, 20.0) if config.ai_mode == "live" else min(config.duration_seconds, 8.0)
            deadline = time.perf_counter() + wait_budget
            while time.perf_counter() < deadline:
                remaining = max(0.2, deadline - time.perf_counter())
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=min(remaining, 2.0))
                    received += 1
                    if isinstance(raw, bytes):
                        if first_response_time is None:
                            first_response_time = time.perf_counter()
                    else:
                        try:
                            evt = json.loads(raw)
                        except json.JSONDecodeError:
                            continue
                        ev_type = evt.get("type")
                        if (
                            ev_type in ("ai.thinking", "ai.transcript_chunk", "ai.audio_chunk")
                            and first_response_time is None
                        ):
                            first_response_time = time.perf_counter()
                        if ev_type in ("ai.speech_finished", "speech_finished"):
                            break
                except asyncio.TimeoutError:
                    if time.perf_counter() >= deadline:
                        break

            turn_latency_ms = (time.perf_counter() - turn_start) * 1000.0
            ttfa_ms = (
                (first_response_time - turn_start) * 1000.0
                if first_response_time is not None
                else 0.0
            )

            try:
                await ws.send(
                    json.dumps(
                        {
                            "type": "end_call",
                            "duration_seconds": int(round(audio_seconds)),
                        }
                    )
                )
                sent += 1
            except Exception:
                pass

            return WsEventSample(
                endpoint="WS /call/ws/{session_id}",
                connect_ms=connect_ms,
                messages_sent=sent,
                messages_received=received,
                dropped=False,
                ttfa_ms=ttfa_ms,
                turn_latency_ms=turn_latency_ms,
                audio_seconds_sent=audio_seconds,
            )
    except Exception as exc:
        return WsEventSample(
            endpoint="WS /call/ws/{session_id}",
            connect_ms=0.0,
            messages_sent=sent,
            messages_received=received,
            dropped=True,
            error=str(exc),
            audio_seconds_sent=audio_seconds,
        )


async def run_ai_user(
    session: aiohttp.ClientSession,
    config: StressConfig,
    user_idx: int,
    http_samples: list[RequestSample],
    ws_samples: list[WsEventSample],
    notes: list[str],
) -> None:
    """Execute one simulated user's AI HTTP, SSE, and Voice WebSocket flow."""
    email = (
        f"{config.user_email_prefix}@{config.user_email_domain}"
        if config.shared_auth
        else f"{config.user_email_prefix}_{user_idx}@{config.user_email_domain}"
    )
    token = await authenticate_or_register(
        session,
        config,
        email=email,
        password=config.user_password,
        name=f"Stress User {user_idx}",
        samples=http_samples,
    )
    if not token:
        notes.append(f"User {user_idx}: auth failed for {email}")
        return

    headers = {"Authorization": f"Bearer {token}"}
    conv_sample, conv_data = await timed_request(
        session,
        "GET",
        f"{config.api_base_url}/conversations?page=1&limit=10",
        "GET /conversations",
        headers=headers,
    )
    http_samples.append(conv_sample)

    today_sample, _ = await timed_request(
        session,
        "GET",
        f"{config.api_base_url}/conversations/today?page=1&limit=10",
        "GET /conversations/today",
        headers=headers,
    )
    http_samples.append(today_sample)

    conv_id: str | None = None
    if isinstance(conv_data, dict):
        items = conv_data.get("conversations") or conv_data.get("items") or []
        if isinstance(items, list) and items:
            first: Any = items[0]
            if isinstance(first, dict) and first.get("id"):
                conv_id = str(first["id"])

    if conv_id:
        msg_sample, _ = await timed_request(
            session,
            "POST",
            f"{config.api_base_url}/conversations/{conv_id}/messages",
            "POST /conversations/{id}/messages",
            headers=headers,
            json_body={
                "content": "Pesan stress test untuk mengukur throughput chat.",
                "modality": "text",
            },
        )
        http_samples.append(msg_sample)

        sse_sample, _ = await timed_request(
            session,
            "GET",
            f"{config.api_base_url}/conversations/{conv_id}/summary/stream",
            "GET /conversations/{id}/summary/stream",
            headers=headers,
            read_sse=True,
        )
        http_samples.append(sse_sample)

    call_session_id = str(uuid.uuid4())
    ws_sample = await _run_voice_ws(config, token, call_session_id)
    ws_samples.append(ws_sample)
    if ws_sample.dropped and ws_sample.error:
        notes.append(f"User {user_idx} WS drop: {ws_sample.error}")

    synth_sample, _ = await timed_request(
        session,
        "POST",
        f"{config.api_base_url}/call/synthesize",
        "POST /call/synthesize",
        headers=headers,
        json_body={
            "session_id": call_session_id,
            "turns": [
                {"role": "user", "text": "Hari ini terasa cukup melelahkan."},
                {"role": "assistant", "text": "Terima kasih sudah berbagi."},
            ],
            "include_dass": False,
            "include_memory_candidates": False,
        },
    )
    http_samples.append(synth_sample)
