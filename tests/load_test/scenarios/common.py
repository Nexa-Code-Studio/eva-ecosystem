"""Shared async HTTP and authentication helpers for load test scenarios."""

from __future__ import annotations

import time
from typing import Any

import aiohttp

from tests.load_test.config import StressConfig
from tests.load_test.metrics import RequestSample


async def timed_request(
    session: aiohttp.ClientSession,
    method: str,
    url: str,
    endpoint_label: str,
    *,
    headers: dict[str, str] | None = None,
    json_body: dict[str, Any] | None = None,
    read_sse: bool = False,
) -> tuple[RequestSample, Any]:
    """Execute an HTTP/SSE request and return a RequestSample plus parsed payload."""
    start = time.perf_counter()
    try:
        async with session.request(
            method, url, headers=headers, json=json_body
        ) as resp:
            if read_sse:
                chunks = 0
                async for line in resp.content:
                    if line:
                        chunks += 1
                data: Any = {"sse_lines": chunks}
            else:
                try:
                    data = await resp.json(content_type=None)
                except Exception:
                    data = await resp.text()
            elapsed_ms = (time.perf_counter() - start) * 1000.0
            ok = 200 <= resp.status < 300
            return (
                RequestSample(
                    endpoint=endpoint_label,
                    status_code=resp.status,
                    latency_ms=elapsed_ms,
                    ok=ok,
                    error="" if ok else f"HTTP {resp.status}",
                ),
                data,
            )
    except Exception as exc:
        elapsed_ms = (time.perf_counter() - start) * 1000.0
        return (
            RequestSample(
                endpoint=endpoint_label,
                status_code=0,
                latency_ms=elapsed_ms,
                ok=False,
                error=str(exc),
            ),
            None,
        )


async def authenticate_or_register(
    session: aiohttp.ClientSession,
    config: StressConfig,
    email: str,
    password: str,
    name: str,
    samples: list[RequestSample],
) -> str | None:
    """Authenticate an account, falling back to /auth/register when missing."""
    login_sample, login_data = await timed_request(
        session,
        "POST",
        f"{config.api_base_url}/auth/login",
        "POST /auth/login",
        json_body={"email": email, "password": password},
    )
    samples.append(login_sample)
    if login_sample.ok and isinstance(login_data, dict):
        token = login_data.get("access_token")
        if token:
            return str(token)

    reg_sample, reg_data = await timed_request(
        session,
        "POST",
        f"{config.api_base_url}/auth/register",
        "POST /auth/register",
        json_body={"name": name, "email": email, "password": password},
    )
    samples.append(reg_sample)
    if reg_sample.ok and isinstance(reg_data, dict):
        token = reg_data.get("access_token")
        if token:
            return str(token)
    return None
