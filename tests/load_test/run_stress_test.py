#!/usr/bin/env python3
"""Multi-instance (multiprocessing + asyncio) stress test runner for EVA Ecosystem."""

from __future__ import annotations

import asyncio
import importlib.util
import multiprocessing as mp
import sys
import time
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tests.load_test.config import StressConfig, distribute_users, parse_args
from tests.load_test.metrics import (
    RequestSample,
    WorkerResult,
    WsEventSample,
    summarize_results,
    write_reports,
)


async def _run_user_task(
    session: Any,
    config: StressConfig,
    user_idx: int,
    http_samples: list[RequestSample],
    ws_samples: list[WsEventSample],
    notes: list[str],
) -> None:
    """Execute the configured scenario for a single virtual user with ramp-up delay."""
    from tests.load_test.scenarios.ai_pipeline import run_ai_user
    from tests.load_test.scenarios.video_call import run_video_pair_user

    if config.users > 1 and config.ramp_up_seconds > 0:
        delay = (user_idx / (config.users - 1)) * config.ramp_up_seconds
        await asyncio.sleep(delay)

    if config.scenario == "ai":
        await run_ai_user(session, config, user_idx, http_samples, ws_samples, notes)
    elif config.scenario == "video":
        await run_video_pair_user(
            session, config, user_idx, http_samples, ws_samples, notes
        )
    else:
        if user_idx % 2 == 0:
            await run_ai_user(
                session, config, user_idx, http_samples, ws_samples, notes
            )
        else:
            await run_video_pair_user(
                session, config, user_idx, http_samples, ws_samples, notes
            )


async def _worker_async(
    worker_id: int, config: StressConfig, user_indices: list[int]
) -> WorkerResult:
    """Async entrypoint inside a single OS worker process."""
    import aiohttp

    http_samples: list[RequestSample] = []
    ws_samples: list[WsEventSample] = []
    notes: list[str] = []

    timeout = aiohttp.ClientTimeout(total=config.request_timeout_seconds)
    connector = aiohttp.TCPConnector(limit=0)
    async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
        tasks = [
            _run_user_task(session, config, idx, http_samples, ws_samples, notes)
            for idx in user_indices
        ]
        await asyncio.gather(*tasks, return_exceptions=False)

    return WorkerResult(
        worker_id=worker_id,
        user_indices=user_indices,
        http_samples=http_samples,
        ws_samples=ws_samples,
        notes=notes,
    )


def _worker_process(
    worker_id: int,
    config: StressConfig,
    user_indices: list[int],
    queue: mp.Queue[Any],
) -> None:
    """Spawned OS process running its own asyncio event loop."""
    try:
        result = asyncio.run(_worker_async(worker_id, config, user_indices))
        queue.put(result)
    except Exception as exc:
        queue.put(
            WorkerResult(
                worker_id=worker_id,
                user_indices=user_indices,
                notes=[f"Worker {worker_id} crashed: {exc}"],
            )
        )


def _check_runtime_dependencies() -> list[str]:
    """Return missing runtime packages required to execute load test workers."""
    required = ("aiohttp", "websockets")
    return [pkg for pkg in required if importlib.util.find_spec(pkg) is None]


def run_multi_instance(config: StressConfig) -> dict[str, Any]:
    """Launch worker processes, collect telemetry, and persist JSON/Markdown reports."""
    missing = _check_runtime_dependencies()
    if missing:
        pkg_list = " ".join(missing)
        raise SystemExit(
            f"Missing required Python packages: {pkg_list}.\n"
            f"Install in a virtualenv (`pip install aiohttp websockets`) or run via:\n"
            f"  uv run --with aiohttp --with websockets python3 tests/load_test/run_stress_test.py ..."
        )

    buckets = distribute_users(config.users, config.instances)
    ctx = mp.get_context("spawn")
    queue: mp.Queue[Any] = ctx.Queue()
    processes: list[mp.Process] = []

    print(
        f"Starting EVA stress test: scenario={config.scenario} users={config.users} "
        f"instances={len(buckets)} ai_mode={config.ai_mode} target={config.target_url}"
    )
    t0 = time.perf_counter()

    for worker_id, user_indices in enumerate(buckets):
        proc = ctx.Process(
            target=_worker_process,
            args=(worker_id, config, user_indices, queue),
        )
        proc.start()
        processes.append(proc)

    worker_results: list[WorkerResult] = []
    for _ in processes:
        worker_results.append(queue.get())

    for proc in processes:
        proc.join()

    wall_s = time.perf_counter() - t0
    summary = summarize_results(config, worker_results, wall_s)
    json_path, md_path = write_reports(summary, config.output_dir)

    ov = summary["overall"]
    print(
        f"Done in {ov['wall_duration_s']}s | HTTP: {ov['http_total']} "
        f"(err {ov['http_error_rate_pct']}%, p50={ov['http_p50_ms']}ms, "
        f"p95={ov['http_p95_ms']}ms, p99={ov['http_p99_ms']}ms) | "
        f"WS: {ov['ws_total']} (drop {ov['ws_drop_rate_pct']}%)"
    )
    print(f"Reports saved: {md_path} and {json_path}")
    return summary


def main(argv: list[str] | None = None) -> int:
    config = parse_args(argv)
    run_multi_instance(config)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
