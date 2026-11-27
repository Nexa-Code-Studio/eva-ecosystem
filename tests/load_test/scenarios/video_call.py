"""Paired Patient + Counselor WebRTC signaling stress scenario."""

from __future__ import annotations

import asyncio
import json
import time

import aiohttp
import websockets

from tests.load_test.config import StressConfig, VideoSessionPair
from tests.load_test.metrics import RequestSample, WsEventSample
from tests.load_test.scenarios.common import authenticate_or_register, timed_request


async def _signaling_peer(
    ws_url: str,
    role: str,
    hold_seconds: float,
    timeout_s: float,
) -> WsEventSample:
    """Connect one WebRTC peer (patient or counselor) and exchange SDP/ICE bursts."""
    start = time.perf_counter()
    sent = 0
    received = 0
    try:
        async with websockets.connect(
            ws_url, open_timeout=timeout_s, close_timeout=5
        ) as ws:
            connect_ms = (time.perf_counter() - start) * 1000.0
            if role == "counselor":
                await ws.send(
                    json.dumps(
                        {
                            "type": "offer",
                            "payload": {"sdp": "v=0\r\no=- 1 2 IN IP4 127.0.0.1\r\n"},
                        }
                    )
                )
                sent += 1
            else:
                await ws.send(
                    json.dumps(
                        {
                            "type": "answer",
                            "payload": {"sdp": "v=0\r\no=- 3 4 IN IP4 127.0.0.1\r\n"},
                        }
                    )
                )
                sent += 1

            for idx in range(3):
                await ws.send(
                    json.dumps(
                        {
                            "type": "ice_candidate",
                            "payload": {
                                "candidate": f"candidate:{idx} 1 udp 2122260223 127.0.0.1 5000{idx} typ host"
                            },
                        }
                    )
                )
                sent += 1
                await asyncio.sleep(0.05)

            deadline = time.perf_counter() + min(hold_seconds, 5.0)
            while time.perf_counter() < deadline:
                try:
                    await asyncio.wait_for(ws.recv(), timeout=0.5)
                    received += 1
                except asyncio.TimeoutError:
                    break

            return WsEventSample(
                endpoint="WS /care/ws/{session_id}",
                connect_ms=connect_ms,
                messages_sent=sent,
                messages_received=received,
                dropped=False,
            )
    except Exception as exc:
        return WsEventSample(
            endpoint="WS /care/ws/{session_id}",
            connect_ms=0.0,
            messages_sent=sent,
            messages_received=received,
            dropped=True,
            error=f"{role}: {exc}",
        )


async def run_video_pair_user(
    session: aiohttp.ClientSession,
    config: StressConfig,
    user_idx: int,
    http_samples: list[RequestSample],
    ws_samples: list[WsEventSample],
    notes: list[str],
) -> None:
    """Exercise paired WebRTC token generation, WS signaling relay, and status updates."""
    if not config.video_pairs:
        notes.append(
            "Video scenario skipped: pass --credentials-file with video_sessions pairs."
        )
        return

    pair: VideoSessionPair = config.video_pairs[user_idx % len(config.video_pairs)]
    patient_token = await authenticate_or_register(
        session,
        config,
        email=pair.patient_email,
        password=pair.patient_password,
        name="Patient Stress",
        samples=http_samples,
    )
    counselor_token = await authenticate_or_register(
        session,
        config,
        email=pair.counselor_email,
        password=pair.counselor_password,
        name="Counselor Stress",
        samples=http_samples,
    )
    if not patient_token or not counselor_token:
        notes.append(f"Pair {user_idx}: patient or counselor auth failed")
        return

    p_tok_sample, p_tok_data = await timed_request(
        session,
        "POST",
        f"{config.api_base_url}/care/sessions/{pair.session_id}/video-token",
        "POST /care/sessions/{id}/video-token",
        headers={"Authorization": f"Bearer {patient_token}"},
    )
    c_tok_sample, c_tok_data = await timed_request(
        session,
        "POST",
        f"{config.api_base_url}/care/sessions/{pair.session_id}/video-token",
        "POST /care/sessions/{id}/video-token",
        headers={"Authorization": f"Bearer {counselor_token}"},
    )
    http_samples.extend([p_tok_sample, c_tok_sample])

    p_room_tok = p_tok_data.get("token") if isinstance(p_tok_data, dict) else None
    c_room_tok = c_tok_data.get("token") if isinstance(c_tok_data, dict) else None
    if not p_room_tok or not c_room_tok:
        notes.append(f"Pair {user_idx}: video-token missing for session {pair.session_id}")
        return

    p_ws_url = f"{config.ws_base_url}/care/ws/{pair.session_id}?token={p_room_tok}"
    c_ws_url = f"{config.ws_base_url}/care/ws/{pair.session_id}?token={c_room_tok}"

    p_ws, c_ws = await asyncio.gather(
        _signaling_peer(
            p_ws_url, "patient", config.duration_seconds, config.request_timeout_seconds
        ),
        _signaling_peer(
            c_ws_url, "counselor", config.duration_seconds, config.request_timeout_seconds
        ),
    )
    ws_samples.extend([p_ws, c_ws])

    status_sample, _ = await timed_request(
        session,
        "POST",
        f"{config.api_base_url}/care/sessions/{pair.session_id}/status",
        "POST /care/sessions/{id}/status",
        headers={"Authorization": f"Bearer {counselor_token}"},
        json_body={"status": "active", "duration_seconds": 5},
    )
    http_samples.append(status_sample)
