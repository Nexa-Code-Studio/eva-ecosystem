"""Configuration and CLI argument parsing for multi-instance stress tests."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class VideoSessionPair:
    """Credential and room pairing for a patient + counselor WebRTC signaling test."""

    session_id: str
    patient_email: str
    patient_password: str
    counselor_email: str
    counselor_password: str


@dataclass(frozen=True)
class StressConfig:
    """Immutable configuration passed to every worker process."""

    target_url: str
    scenario: str = "ai"  # ai | video | mixed
    users: int = 10
    instances: int = 2
    ramp_up_seconds: float = 5.0
    duration_seconds: float = 15.0
    ai_mode: str = "mock"  # mock | live
    request_timeout_seconds: float = 30.0
    credentials_file: str | None = None
    output_dir: str = "tests/load_test/reports"
    audio_sample_path: str | None = None
    audio_dir: str = "tests/test_emotion"
    voice_duration_seconds: float = 10.0
    audio_pace: str = "realtime"  # realtime | fast
    stt_fallback: bool = False
    user_email_prefix: str = "stress_test"
    user_email_domain: str = "gmail.com"
    user_password: str = "StressTest123!"
    shared_auth: bool = False
    video_pairs: tuple[VideoSessionPair, ...] = field(default_factory=tuple)

    @property
    def api_base_url(self) -> str:
        base = self.target_url.rstrip("/")
        if base.endswith("/api/v1"):
            return base
        return f"{base}/api/v1"

    @property
    def ws_base_url(self) -> str:
        api = self.api_base_url
        if api.startswith("https://"):
            return "wss://" + api[len("https://") :]
        if api.startswith("http://"):
            return "ws://" + api[len("http://") :]
        return api


def load_video_pairs(credentials_file: str | None) -> tuple[VideoSessionPair, ...]:
    """Load optional patient+counselor video session pairs from a JSON file."""
    if not credentials_file:
        return ()
    path = Path(credentials_file)
    raw: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    pairs: list[VideoSessionPair] = []
    for item in raw.get("video_sessions", []):
        pairs.append(
            VideoSessionPair(
                session_id=str(item["session_id"]),
                patient_email=str(item["patient_email"]),
                patient_password=str(item["patient_password"]),
                counselor_email=str(item["counselor_email"]),
                counselor_password=str(item["counselor_password"]),
            )
        )
    return tuple(pairs)


def distribute_users(total_users: int, instances: int) -> list[list[int]]:
    """Distribute user indices [0..total_users-1] evenly across worker instances."""
    effective_instances = max(1, min(instances, max(1, total_users)))
    buckets: list[list[int]] = [[] for _ in range(effective_instances)]
    for idx in range(total_users):
        buckets[idx % effective_instances].append(idx)
    return buckets


def parse_args(argv: list[str] | None = None) -> StressConfig:
    """Parse CLI arguments into a validated StressConfig."""
    parser = argparse.ArgumentParser(
        description="EVA Ecosystem Multi-Instance Stress Test Runner (AI & WebRTC Signaling)"
    )
    parser.add_argument(
        "--target-url",
        required=True,
        help="Base URL of target backend (e.g. https://api.example.com or http://127.0.0.1:8888)",
    )
    parser.add_argument(
        "--scenario",
        choices=["ai", "video", "mixed"],
        default="ai",
        help="Stress scenario to execute (default: ai)",
    )
    parser.add_argument(
        "--users",
        type=int,
        default=10,
        help="Total concurrent virtual users (default: 10)",
    )
    parser.add_argument(
        "--instances",
        type=int,
        default=2,
        help="Number of independent OS worker processes (default: 2)",
    )
    parser.add_argument(
        "--ramp-up",
        type=float,
        default=5.0,
        help="Ramp-up window in seconds across all users (default: 5.0)",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=15.0,
        help="Hold/burst duration in seconds per user session (default: 15.0)",
    )
    parser.add_argument(
        "--ai-mode",
        choices=["mock", "live"],
        default="mock",
        help="Client AI burst mode: 'mock' (lightweight/quota-safe) or 'live' (full audio WAV streaming)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=30.0,
        help="HTTP/WS request timeout in seconds (default: 30.0)",
    )
    parser.add_argument(
        "--credentials-file",
        default=None,
        help="Optional JSON file containing video_sessions pairs for WebRTC signaling tests",
    )
    parser.add_argument(
        "--audio-sample",
        default=None,
        help="Optional specific WAV file path for live Voice AI WebSocket streaming",
    )
    parser.add_argument(
        "--audio-dir",
        default="tests/test_emotion",
        help="Directory containing WAV voice samples (default: tests/test_emotion)",
    )
    parser.add_argument(
        "--voice-duration",
        type=float,
        default=10.0,
        help="Target voice input duration in seconds streamed per AI call turn (default: 10.0)",
    )
    parser.add_argument(
        "--audio-pace",
        choices=["realtime", "fast"],
        default="realtime",
        help="Chunk pacing for voice audio: 'realtime' (100ms intervals) or 'fast' (burst)",
    )
    parser.add_argument(
        "--stt-fallback",
        action="store_true",
        help="Also send stt.final_segment after streaming audio (use if upstream STT is disabled)",
    )
    parser.add_argument(
        "--output-dir",
        default="tests/load_test/reports",
        help="Directory for generated JSON and Markdown reports",
    )
    parser.add_argument(
        "--email-prefix",
        default="stress_test",
        help="Email prefix for auto-registered virtual users (default: stress_test)",
    )
    parser.add_argument(
        "--email-domain",
        default="gmail.com",
        help="MX-valid email domain for virtual users (default: gmail.com)",
    )
    parser.add_argument(
        "--shared-auth",
        action="store_true",
        help="Reuse a single test email (<prefix>@<domain>) across all virtual users instead of registering per user index",
    )
    parser.add_argument(
        "--password",
        default="StressTest123!",
        help="Password for virtual test users",
    )

    args = parser.parse_args(argv)
    if args.users < 1:
        parser.error("--users must be >= 1")
    if args.instances < 1:
        parser.error("--instances must be >= 1")
    if args.ramp_up < 0:
        parser.error("--ramp-up must be >= 0")
    if args.voice_duration <= 0:
        parser.error("--voice-duration must be > 0")

    video_pairs = load_video_pairs(args.credentials_file)
    return StressConfig(
        target_url=args.target_url,
        scenario=args.scenario,
        users=args.users,
        instances=args.instances,
        ramp_up_seconds=args.ramp_up,
        duration_seconds=args.duration,
        ai_mode=args.ai_mode,
        request_timeout_seconds=args.timeout,
        credentials_file=args.credentials_file,
        output_dir=args.output_dir,
        audio_sample_path=args.audio_sample,
        audio_dir=args.audio_dir,
        voice_duration_seconds=args.voice_duration,
        audio_pace=args.audio_pace,
        stt_fallback=args.stt_fallback,
        user_email_prefix=args.email_prefix,
        user_email_domain=args.email_domain,
        user_password=args.password,
        shared_auth=args.shared_auth,
        video_pairs=video_pairs,
    )
