"""Unit & contract tests for BaseEmotionProvider, MockEmotionProvider, RemoteHTTPEmotionProvider, and EmotionFactory."""

from __future__ import annotations

import json

import httpx
import pytest

from packages.ai.factories.emotion_factory import EmotionFactory
from packages.ai.providers.emotion.mock_emotion import MockEmotionProvider
from packages.ai.providers.emotion.remote_http_emotion import (
    CircuitOpenError,
    EmotionProviderError,
    RemoteHTTPEmotionProvider,
)
from packages.shared.config import settings
from shared.domain_types import EMOTION2VEC_CANONICAL_CLASSES


def _valid_payload(segment_id: str = "seg-1") -> dict:
    scores = {c: 0.02 for c in EMOTION2VEC_CANONICAL_CLASSES}
    scores["sad"] = 0.72
    scores["neutral"] = 0.14
    return {
        "schema_version": 1,
        "segment_id": segment_id,
        "status": "ok",
        "model": "emotion2vec_plus_base",
        "model_revision": "sha256-abc123",
        "runtime": "onnxruntime",
        "precision": "int8",
        "scores": scores,
        "inference_ms": 530.5,
    }


@pytest.mark.asyncio
async def test_mock_emotion_provider_returns_valid_9_classes():
    provider = MockEmotionProvider(simulated_latency_ms=0.0)
    pred = await provider.predict_pcm_segment(
        b"\x01\x00" * 48000,
        segment_id="mock-seg-1",
        valid_speech_ms=3000,
        duration_ms=3000,
    )
    assert pred.segment_id == "mock-seg-1"
    assert set(pred.scores.keys()) == set(EMOTION2VEC_CANONICAL_CLASSES)
    assert abs(sum(pred.scores.values()) - 1.0) < 1e-4
    assert await provider.health_check() is True


@pytest.mark.asyncio
async def test_remote_http_provider_success_oidc_auth_and_zero_pii():
    seen_headers: list[dict[str, str]] = []
    fetch_count = 0

    async def fake_token_fetcher(audience: str) -> str:
        nonlocal fetch_count
        fetch_count += 1
        assert audience == "https://emotion.example.run.app"
        return "oidc-jwt-token-xyz"

    def handler(request: httpx.Request) -> httpx.Response:
        seen_headers.append(dict(request.headers))
        assert request.url.path == "/v1/emotions/predict"
        assert request.headers.get("authorization") == "Bearer oidc-jwt-token-xyz"
        assert request.headers.get("x-segment-id") in ("seg-a", "seg-b")
        # Ensure zero PII headers
        for forbidden in ("x-user-id", "x-user-name", "x-transcript"):
            assert forbidden not in request.headers
        return httpx.Response(200, json=_valid_payload(request.headers["x-segment-id"]))

    provider = RemoteHTTPEmotionProvider(
        base_url="https://emotion.example.run.app",
        auth_mode="gcp_oidc",
        audience="https://emotion.example.run.app",
        transport=httpx.MockTransport(handler),
        token_fetcher=fake_token_fetcher,
    )
    try:
        p1 = await provider.predict_pcm_segment(b"\x02\x00" * 16000, segment_id="seg-a", valid_speech_ms=1000, duration_ms=1000)
        p2 = await provider.predict_pcm_segment(b"\x02\x00" * 16000, segment_id="seg-b", valid_speech_ms=1000, duration_ms=1000)
        assert p1.primary_emotion == "sad"
        assert p2.model_revision == "sha256-abc123"
        # Token was cached across both calls
        assert fetch_count == 1
    finally:
        await provider.close()


@pytest.mark.asyncio
async def test_remote_http_provider_retries_5xx_and_opens_circuit_breaker():
    attempts = 0

    def handler(_request: httpx.Request) -> httpx.Response:
        nonlocal attempts
        attempts += 1
        return httpx.Response(503, json={"detail": "overloaded"})

    provider = RemoteHTTPEmotionProvider(
        base_url="https://emotion.example.run.app",
        max_retries=1,
        circuit_fail_threshold=2,
        circuit_cooldown_s=60.0,
        transport=httpx.MockTransport(handler),
    )
    try:
        with pytest.raises(EmotionProviderError):
            await provider.predict_pcm_segment(b"\x01\x00" * 16000, segment_id="fail-1", deadline_ms=2000)
        assert attempts == 2
        assert provider.circuit_is_open is True

        with pytest.raises(CircuitOpenError):
            await provider.predict_pcm_segment(b"\x01\x00" * 16000, segment_id="fail-2", deadline_ms=2000)
        assert attempts == 2  # Blocked without hitting network
    finally:
        await provider.close()


@pytest.mark.asyncio
async def test_remote_http_provider_rejects_malformed_or_missing_classes():
    bad_payload = _valid_payload("bad-1")
    del bad_payload["scores"]["sad"]

    provider = RemoteHTTPEmotionProvider(
        base_url="https://emotion.example.run.app",
        max_retries=0,
        transport=httpx.MockTransport(lambda _req: httpx.Response(200, content=json.dumps(bad_payload))),
    )
    try:
        with pytest.raises(EmotionProviderError):
            await provider.predict_pcm_segment(b"\x01\x00" * 16000, segment_id="bad-1")
    finally:
        await provider.close()


def test_emotion_factory_fail_fast_no_silent_mock(monkeypatch):
    EmotionFactory._instances.clear()
    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "EMOTION_PROVIDER", "remote_http")
    monkeypatch.setattr(settings, "EMOTION_SERVICE_URL", "")
    with pytest.raises(RuntimeError, match="EMOTION_SERVICE_URL must be configured"):
        EmotionFactory.get_provider(force_new=True)

    monkeypatch.setattr(settings, "EMOTION_PROVIDER", "mock")
    with pytest.raises(RuntimeError, match="EMOTION_PROVIDER='mock' is disabled"):
        EmotionFactory.get_provider(force_new=True)

    monkeypatch.setattr(settings, "EMOTION_PROVIDER", "invalid_backend")
    with pytest.raises(RuntimeError, match="Unsupported EMOTION_PROVIDER"):
        EmotionFactory.get_provider(force_new=True)

    # Production must fail-fast if auth_mode='none'
    monkeypatch.setattr(settings, "APP_ENV", "production")
    monkeypatch.setattr(settings, "EMOTION_STREAMING_ENABLED", True)
    monkeypatch.setattr(settings, "EMOTION_PROVIDER", "remote_http")
    monkeypatch.setattr(settings, "EMOTION_SERVICE_URL", "https://emotion.example.run.app")
    monkeypatch.setattr(settings, "EMOTION_SERVICE_AUTH_MODE", "none")
    with pytest.raises(RuntimeError, match="prohibited in production"):
        EmotionFactory.get_provider(force_new=True)
    EmotionFactory._instances.clear()
