#!/usr/bin/env python3
"""Staging comparative & load benchmark runner for the isolated Emotion Microservice.

Supports:
1. Segment-length sweep (`--durations 3,5,10`) against `POST /v1/emotions/predict`
2. Concurrent user load test (`--users 1,10,30,50,100`, `--duty-cycle 0.5`, `--duration-s 60`)
Outputs machine-readable JSON + percentile summary (p50/p95/p99, throughput, error/drop rate).
"""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import statistics
import sys
import time
import uuid
from array import array

import httpx


def _pcm_fixture(duration_s: float) -> bytes:
    n = int(round(duration_s * 16000))
    arr = array("h", (int(8000 * math.sin(2.0 * math.pi * 220.0 * (i / 16000.0))) for i in range(n)))
    if sys.byteorder != "little":
        arr.byteswap()
    return arr.tobytes()


def _percentile(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    idx = min(len(ordered) - 1, max(0, int(math.ceil((pct / 100.0) * len(ordered))) - 1))
    return round(ordered[idx], 2)


async def run_load_scenario(
    *,
    base_url: str,
    token: str,
    concurrent_users: int,
    segment_s: float,
    duty_cycle: float,
    duration_s: float,
    timeout_s: float,
) -> dict:
    payload = _pcm_fixture(segment_s)
    interval_s = segment_s / max(0.05, min(1.0, duty_cycle))
    latencies_ms: list[float] = []
    status_counts: dict[str, int] = {}

    headers_base = {
        "Content-Type": "application/octet-stream",
        "X-Schema-Version": "1",
        "X-Sample-Rate": "16000",
        "X-Channels": "1",
        "X-Sample-Format": "pcm_s16le",
    }
    if token:
        headers_base["Authorization"] = f"Bearer {token}"

    end_time = time.monotonic() + duration_s

    async with httpx.AsyncClient(
        base_url=base_url.rstrip("/"),
        timeout=httpx.Timeout(timeout_s),
        limits=httpx.Limits(max_connections=max(64, concurrent_users * 2)),
    ) as client:

        async def _user_loop(user_idx: int) -> None:
            # Stagger initial arrivals across one interval to simulate realistic calls
            await asyncio.sleep((user_idx / max(1, concurrent_users)) * min(interval_s, 3.0))
            while time.monotonic() < end_time:
                t0 = time.perf_counter()
                seg_id = f"bench-u{user_idx}-{uuid.uuid4().hex[:8]}"
                try:
                    resp = await client.post(
                        "/v1/emotions/predict",
                        content=payload,
                        headers={**headers_base, "X-Segment-Id": seg_id},
                    )
                    code = str(resp.status_code)
                    status_counts[code] = status_counts.get(code, 0) + 1
                    if resp.status_code == 200:
                        latencies_ms.append((time.perf_counter() - t0) * 1000.0)
                except Exception as exc:
                    key = f"err:{type(exc).__name__}"
                    status_counts[key] = status_counts.get(key, 0) + 1

                elapsed = time.perf_counter() - t0
                sleep_for = max(0.0, interval_s - elapsed)
                if time.monotonic() + sleep_for >= end_time:
                    break
                await asyncio.sleep(sleep_for)

        t_wall_start = time.perf_counter()
        await asyncio.gather(*(_user_loop(i) for i in range(concurrent_users)))
        wall_s = max(0.001, time.perf_counter() - t_wall_start)

    total_reqs = sum(status_counts.values())
    ok_reqs = status_counts.get("200", 0)
    return {
        "concurrent_users": concurrent_users,
        "segment_s": segment_s,
        "duty_cycle": duty_cycle,
        "wall_seconds": round(wall_s, 2),
        "total_requests": total_reqs,
        "ok_requests": ok_reqs,
        "error_rate": round((total_reqs - ok_reqs) / max(1, total_reqs), 4),
        "throughput_rps": round(ok_reqs / wall_s, 3),
        "latency_ms": {
            "p50": _percentile(latencies_ms, 50),
            "p95": _percentile(latencies_ms, 95),
            "p99": _percentile(latencies_ms, 99),
            "mean": round(statistics.mean(latencies_ms), 2) if latencies_ms else 0.0,
        },
        "status_counts": status_counts,
    }


async def _amain() -> None:
    parser = argparse.ArgumentParser(description="Staging load benchmark for Eva Emotion Microservice")
    parser.add_argument("--url", required=True, help="Base URL of emotion service (e.g. http://localhost:8890)")
    parser.add_argument("--token", default="", help="Optional Bearer / GCP OIDC token")
    parser.add_argument("--users", default="1,10", help="Comma-separated concurrent user levels (e.g. 1,10,30,50,100)")
    parser.add_argument("--segment-s", type=float, default=3.0, help="Segment duration in seconds (3, 5, 10)")
    parser.add_argument("--duty-cycle", type=float, default=0.5, help="Speech duty cycle (0.3, 0.5, 1.0)")
    parser.add_argument("--duration-s", type=float, default=30.0, help="Scenario duration in seconds")
    parser.add_argument("--timeout-s", type=float, default=5.0, help="Per-request HTTP timeout")
    args = parser.parse_args()

    results = []
    for raw_u in args.users.split(","):
        u = int(raw_u.strip())
        res = await run_load_scenario(
            base_url=args.url,
            token=args.token,
            concurrent_users=u,
            segment_s=args.segment_s,
            duty_cycle=args.duty_cycle,
            duration_s=args.duration_s,
            timeout_s=args.timeout_s,
        )
        results.append(res)

    print(json.dumps({"target_url": args.url, "scenarios": results}, indent=2))


if __name__ == "__main__":
    asyncio.run(_amain())
