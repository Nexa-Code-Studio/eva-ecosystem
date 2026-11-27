"""Metrics aggregation, percentile calculation, and report generation."""

from __future__ import annotations

import json
import math
from collections import defaultdict
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from tests.load_test.config import StressConfig


@dataclass
class RequestSample:
    """Single HTTP or SSE operation timing sample."""

    endpoint: str
    status_code: int
    latency_ms: float
    ok: bool
    error: str = ""


@dataclass
class WsEventSample:
    """Single WebSocket session lifecycle sample."""

    endpoint: str
    connect_ms: float
    messages_sent: int
    messages_received: int
    dropped: bool
    error: str = ""
    ttfa_ms: float = 0.0
    turn_latency_ms: float = 0.0
    audio_seconds_sent: float = 0.0


@dataclass
class WorkerResult:
    """Aggregated telemetry returned by a single OS worker process."""

    worker_id: int
    user_indices: list[int]
    http_samples: list[RequestSample] = field(default_factory=list)
    ws_samples: list[WsEventSample] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)


def percentile(values: list[float], pct: float) -> float:
    """Compute linear-interpolated percentile (0..100) for a non-empty list."""
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    rank = (pct / 100.0) * (len(ordered) - 1)
    low = math.floor(rank)
    high = math.ceil(rank)
    if low == high:
        return ordered[low]
    weight = rank - low
    return ordered[low] * (1.0 - weight) + ordered[high] * weight


def summarize_results(
    config: StressConfig,
    worker_results: list[WorkerResult],
    wall_duration_s: float,
) -> dict[str, Any]:
    """Combine worker telemetry into a structured summary dictionary."""
    all_http: list[RequestSample] = []
    all_ws: list[WsEventSample] = []
    notes: list[str] = []

    for wr in worker_results:
        all_http.extend(wr.http_samples)
        all_ws.extend(wr.ws_samples)
        notes.extend(wr.notes)

    by_endpoint: dict[str, list[RequestSample]] = defaultdict(list)
    for sample in all_http:
        by_endpoint[sample.endpoint].append(sample)

    endpoint_stats: dict[str, dict[str, Any]] = {}
    for ep, samples in sorted(by_endpoint.items()):
        latencies = [s.latency_ms for s in samples]
        failures = sum(1 for s in samples if not s.ok)
        endpoint_stats[ep] = {
            "count": len(samples),
            "errors": failures,
            "error_rate_pct": round((failures / len(samples)) * 100.0, 2),
            "p50_ms": round(percentile(latencies, 50), 2),
            "p95_ms": round(percentile(latencies, 95), 2),
            "p99_ms": round(percentile(latencies, 99), 2),
            "max_ms": round(max(latencies), 2) if latencies else 0.0,
        }

    ws_by_endpoint: dict[str, list[WsEventSample]] = defaultdict(list)
    for ws in all_ws:
        ws_by_endpoint[ws.endpoint].append(ws)

    ws_stats: dict[str, dict[str, Any]] = {}
    for ep, samples in sorted(ws_by_endpoint.items()):
        connects = [s.connect_ms for s in samples if s.connect_ms > 0]
        ttfas = [s.ttfa_ms for s in samples if s.ttfa_ms > 0]
        turns = [s.turn_latency_ms for s in samples if s.turn_latency_ms > 0]
        drops = sum(1 for s in samples if s.dropped)
        ws_stats[ep] = {
            "sessions": len(samples),
            "drops": drops,
            "drop_rate_pct": round((drops / len(samples)) * 100.0, 2),
            "connect_p50_ms": round(percentile(connects, 50), 2),
            "connect_p95_ms": round(percentile(connects, 95), 2),
            "ttfa_p50_ms": round(percentile(ttfas, 50), 2),
            "ttfa_p95_ms": round(percentile(ttfas, 95), 2),
            "turn_p50_ms": round(percentile(turns, 50), 2),
            "turn_p95_ms": round(percentile(turns, 95), 2),
            "audio_seconds_sent": round(sum(s.audio_seconds_sent for s in samples), 2),
            "messages_sent": sum(s.messages_sent for s in samples),
            "messages_received": sum(s.messages_received for s in samples),
        }

    total_http = len(all_http)
    total_http_errors = sum(1 for s in all_http if not s.ok)
    all_latencies = [s.latency_ms for s in all_http]
    total_ws = len(all_ws)
    total_ws_drops = sum(1 for s in all_ws if s.dropped)

    return {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "config": {
            "target_url": config.target_url,
            "scenario": config.scenario,
            "users": config.users,
            "instances": config.instances,
            "ramp_up_seconds": config.ramp_up_seconds,
            "duration_seconds": config.duration_seconds,
            "ai_mode": config.ai_mode,
        },
        "overall": {
            "wall_duration_s": round(wall_duration_s, 2),
            "http_total": total_http,
            "http_errors": total_http_errors,
            "http_error_rate_pct": round(
                (total_http_errors / total_http) * 100.0, 2
            )
            if total_http
            else 0.0,
            "http_p50_ms": round(percentile(all_latencies, 50), 2),
            "http_p95_ms": round(percentile(all_latencies, 95), 2),
            "http_p99_ms": round(percentile(all_latencies, 99), 2),
            "ws_total": total_ws,
            "ws_drops": total_ws_drops,
            "ws_drop_rate_pct": round((total_ws_drops / total_ws) * 100.0, 2)
            if total_ws
            else 0.0,
        },
        "http_endpoints": endpoint_stats,
        "ws_endpoints": ws_stats,
        "notes": notes[:20],
    }


def render_markdown_report(summary: dict[str, Any]) -> str:
    """Format summary dictionary into a clean Markdown report."""
    cfg = summary["config"]
    ov = summary["overall"]
    lines = [
        "# EVA Ecosystem Stress Test Report",
        "",
        f"- **Timestamp (UTC)**: `{summary['generated_at_utc']}`",
        f"- **Target URL**: `{cfg['target_url']}`",
        f"- **Scenario**: `{cfg['scenario']}` | **AI Mode**: `{cfg['ai_mode']}`",
        f"- **Concurrency**: `{cfg['users']}` users across `{cfg['instances']}` worker processes (ramp-up `{cfg['ramp_up_seconds']}s`)",
        f"- **Wall Duration**: `{ov['wall_duration_s']}s`",
        "",
        "## Overall Summary",
        "",
        f"- **HTTP Requests**: `{ov['http_total']}` (Errors: `{ov['http_errors']}` / `{ov['http_error_rate_pct']}%`)",
        f"- **HTTP Latency**: `p50={ov['http_p50_ms']}ms`, `p95={ov['http_p95_ms']}ms`, `p99={ov['http_p99_ms']}ms`",
        f"- **WebSocket Sessions**: `{ov['ws_total']}` (Drops: `{ov['ws_drops']}` / `{ov['ws_drop_rate_pct']}%`)",
        "",
        "## HTTP Endpoints",
        "",
        "| Endpoint | Count | Errors | Error % | p50 (ms) | p95 (ms) | p99 (ms) | Max (ms) |",
        "| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for ep, st in summary["http_endpoints"].items():
        lines.append(
            f"| `{ep}` | {st['count']} | {st['errors']} | {st['error_rate_pct']}% | "
            f"{st['p50_ms']} | {st['p95_ms']} | {st['p99_ms']} | {st['max_ms']} |"
        )

    if summary["ws_endpoints"]:
        lines.extend(
            [
                "",
                "## WebSocket Endpoints",
                "",
                "| Endpoint | Sessions | Drops | Drop % | Connect p50/p95 (ms) | TTFA p50/p95 (ms) | Turn p50/p95 (ms) | Audio (s) | Sent | Recv |",
                "| :--- | ---: | ---: | ---: | :---: | :---: | :---: | ---: | ---: | ---: |",
            ]
        )
        for ep, st in summary["ws_endpoints"].items():
            lines.append(
                f"| `{ep}` | {st['sessions']} | {st['drops']} | {st['drop_rate_pct']}% | "
                f"{st['connect_p50_ms']} / {st['connect_p95_ms']} | "
                f"{st['ttfa_p50_ms']} / {st['ttfa_p95_ms']} | "
                f"{st['turn_p50_ms']} / {st['turn_p95_ms']} | "
                f"{st['audio_seconds_sent']} | {st['messages_sent']} | {st['messages_received']} |"
            )

    if summary["notes"]:
        lines.extend(["", "## Sample Notes / Warnings", ""])
        for note in summary["notes"]:
            lines.append(f"- {note}")

    return "\n".join(lines) + "\n"


def write_reports(summary: dict[str, Any], output_dir: str) -> tuple[Path, Path]:
    """Persist JSON and Markdown reports to output_dir and return their paths."""
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    scenario = summary["config"]["scenario"]
    users = summary["config"]["users"]
    json_path = out / f"stress_{scenario}_{users}u_{stamp}.json"
    md_path = out / f"stress_{scenario}_{users}u_{stamp}.md"
    json_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    md_path.write_text(render_markdown_report(summary), encoding="utf-8")
    return json_path, md_path
