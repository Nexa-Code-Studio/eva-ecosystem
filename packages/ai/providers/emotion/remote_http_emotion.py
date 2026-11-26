"""Remote async HTTP client for the isolated ONNX INT8 Emotion Microservice (Cloud Run target).

Design invariants:
- Pooled `httpx.AsyncClient` connection reuse (no permanent WebSocket to inference service).
- Zero PII transmitted (only canonical PCM16 bytes + opaque segment_id + audio format metadata).
- Service-to-service IAM/OIDC or Bearer auth support with cached token refresh.
- Strict deadline-aware timeout, bounded retry (only on transient errors within deadline), and circuit breaker.
- Validates versioned JSON response with all 9 canonical classes and finite [0..1] scores.
"""

from __future__ import annotations

import asyncio
import logging
import math
import time
from collections.abc import Awaitable, Callable
from typing import Any

import httpx

from packages.ai.interfaces.emotion import BaseEmotionProvider
from shared.domain_types import (
    EMOTION2VEC_CANONICAL_CLASSES,
    EmotionSegmentPrediction,
)

logger = logging.getLogger(__name__)

TokenFetcher = Callable[[str], Awaitable[str | None]]


class EmotionProviderError(RuntimeError):
    """Raised when remote emotion inference fails, times out, or circuit is open."""


class CircuitOpenError(EmotionProviderError):
    """Raised when the circuit breaker is open due to consecutive failures."""


class _CircuitBreaker:
    def __init__(self, failure_threshold: int = 5, cooldown_seconds: float = 30.0) -> None:
        self.failure_threshold = max(1, failure_threshold)
        self.cooldown_seconds = max(1.0, cooldown_seconds)
        self._consecutive_failures = 0
        self._opened_at: float | None = None

    def allow_request(self) -> bool:
        if self._opened_at is None:
            return True
        if (time.monotonic() - self._opened_at) >= self.cooldown_seconds:
            # Half-open probe allowed
            return True
        return False

    def record_success(self) -> None:
        self._consecutive_failures = 0
        self._opened_at = None

    def record_failure(self) -> None:
        self._consecutive_failures += 1
        if self._consecutive_failures >= self.failure_threshold:
            if self._opened_at is None:
                logger.warning(
                    "[EMOTION CIRCUIT] Circuit opened after %d consecutive failures (cooldown=%.1fs)",
                    self._consecutive_failures,
                    self.cooldown_seconds,
                )
            self._opened_at = time.monotonic()

    @property
    def is_open(self) -> bool:
        return not self.allow_request()


class _OIDCTokenCache:
    """Fetches and caches GCP Cloud Run OIDC ID tokens with proactive refresh."""

    def __init__(
        self,
        auth_mode: str,
        audience: str,
        static_bearer_token: str = "",
        custom_fetcher: TokenFetcher | None = None,
    ) -> None:
        self.auth_mode = auth_mode.lower()
        self.audience = audience
        self.static_bearer_token = static_bearer_token
        self.custom_fetcher = custom_fetcher
        self._cached_token: str | None = None
        self._expires_at: float = 0.0
        self._lock = asyncio.Lock()

    async def get_authorization_header(self) -> str | None:
        if self.auth_mode == "none":
            return None
        if self.auth_mode == "bearer":
            if not self.static_bearer_token:
                raise EmotionProviderError("EMOTION_SERVICE_BEARER_TOKEN is required when auth_mode='bearer'")
            return f"Bearer {self.static_bearer_token}"
        if self.auth_mode == "gcp_oidc":
            now = time.monotonic()
            if self._cached_token and now < self._expires_at:
                return f"Bearer {self._cached_token}"
            async with self._lock:
                now = time.monotonic()
                if self._cached_token and now < self._expires_at:
                    return f"Bearer {self._cached_token}"
                token = await self._fetch_oidc_token()
                if not token:
                    raise EmotionProviderError("Failed to obtain GCP OIDC ID token for emotion service")
                self._cached_token = token
                # Standard Google ID tokens live ~3600s; refresh proactively after 45m
                self._expires_at = time.monotonic() + 2700.0
                return f"Bearer {token}"
        raise EmotionProviderError(f"Unsupported EMOTION_SERVICE_AUTH_MODE: '{self.auth_mode}'")

    async def _fetch_oidc_token(self) -> str | None:
        if self.custom_fetcher is not None:
            return await self.custom_fetcher(self.audience)
        if not self.audience:
            raise EmotionProviderError("EMOTION_SERVICE_AUDIENCE is required when auth_mode='gcp_oidc'")

        # Prefer google-auth library when installed; fallback to GCE metadata server
        try:
            import google.auth.transport.requests
            import google.oauth2.id_token

            def _sync_fetch() -> str:
                req = google.auth.transport.requests.Request()
                return str(google.oauth2.id_token.fetch_id_token(req, self.audience))

            return await asyncio.to_thread(_sync_fetch)
        except ImportError:
            metadata_url = (
                "http://metadata.google.internal/computeMetadata/v1/instance/"
                f"service-accounts/default/identity?audience={self.audience}"
            )
            async with httpx.AsyncClient(timeout=2.0) as meta_client:
                resp = await meta_client.get(metadata_url, headers={"Metadata-Flavor": "Google"})
                resp.raise_for_status()
                return resp.text.strip()


class RemoteHTTPEmotionProvider(BaseEmotionProvider):
    """Async pooled HTTP client targeting `POST /v1/emotions/predict` on the isolated emotion microservice."""

    def __init__(
        self,
        base_url: str,
        *,
        auth_mode: str = "none",
        audience: str = "",
        bearer_token: str = "",
        timeout_ms: int = 2000,
        max_retries: int = 1,
        circuit_fail_threshold: int = 5,
        circuit_cooldown_s: float = 30.0,
        transport: httpx.AsyncBaseTransport | None = None,
        token_fetcher: TokenFetcher | None = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout_s = max(0.2, timeout_ms / 1000.0)
        self.max_retries = max(0, max_retries)
        self._circuit = _CircuitBreaker(
            failure_threshold=circuit_fail_threshold,
            cooldown_seconds=circuit_cooldown_s,
        )
        self._token_cache = _OIDCTokenCache(
            auth_mode=auth_mode,
            audience=audience or self.base_url,
            static_bearer_token=bearer_token,
            custom_fetcher=token_fetcher,
        )
        self._client = httpx.AsyncClient(
            base_url=self.base_url,
            timeout=httpx.Timeout(self.timeout_s, connect=min(1.0, self.timeout_s)),
            limits=httpx.Limits(max_connections=64, max_keepalive_connections=32),
            transport=transport,
        )

    @property
    def circuit_is_open(self) -> bool:
        return self._circuit.is_open

    async def predict_pcm_segment(
        self,
        pcm_bytes: bytes,
        *,
        segment_id: str,
        sample_rate: int = 16000,
        channels: int = 1,
        sample_width_bytes: int = 2,
        valid_speech_ms: int = 0,
        duration_ms: int = 0,
        deadline_ms: int | None = None,
        sequence: int = 0,
        user_turn_id: int = 0,
        capture_epoch: int = 0,
        start_offset_ms: int = 0,
        end_offset_ms: int = 0,
    ) -> EmotionSegmentPrediction:
        if not pcm_bytes:
            raise EmotionProviderError("Cannot predict emotion on empty PCM payload")

        if not self._circuit.allow_request():
            raise CircuitOpenError("Emotion inference circuit breaker is open")

        started_mono = time.monotonic()
        hard_deadline = (started_mono + (deadline_ms / 1000.0)) if deadline_ms else (started_mono + self.timeout_s * 2)

        headers: dict[str, str] = {
            "Content-Type": "application/octet-stream",
            "X-Schema-Version": "1",
            "X-Segment-Id": segment_id,
            "X-Sample-Rate": str(sample_rate),
            "X-Channels": str(channels),
            "X-Sample-Format": "pcm_s16le",
        }
        auth_header = await self._token_cache.get_authorization_header()
        if auth_header:
            headers["Authorization"] = auth_header

        last_exc: Exception | None = None
        attempts = 1 + self.max_retries

        for attempt in range(attempts):
            remaining_s = hard_deadline - time.monotonic()
            if remaining_s <= 0.1:
                raise EmotionProviderError(f"Segment {segment_id} deadline expired prior to attempt {attempt + 1}")

            req_timeout = min(self.timeout_s, remaining_s)
            try:
                response = await self._client.post(
                    "/v1/emotions/predict",
                    content=pcm_bytes,
                    headers=headers,
                    timeout=req_timeout,
                )

                if response.status_code == 200:
                    payload = response.json()
                    prediction = self._parse_and_validate_response(
                        payload=payload,
                        expected_segment_id=segment_id,
                        valid_speech_ms=valid_speech_ms,
                        duration_ms=duration_ms,
                        sequence=sequence,
                        user_turn_id=user_turn_id,
                        capture_epoch=capture_epoch,
                        start_offset_ms=start_offset_ms,
                        end_offset_ms=end_offset_ms,
                    )
                    self._circuit.record_success()
                    return prediction

                # Never retry 4xx client/auth/validation errors (except 429 if deadline allows)
                if response.status_code in (400, 401, 403, 413, 415, 422):
                    self._circuit.record_failure()
                    raise EmotionProviderError(
                        f"Emotion service rejected segment {segment_id} with HTTP {response.status_code}"
                    )

                last_exc = EmotionProviderError(
                    f"Emotion service transient HTTP {response.status_code} for segment {segment_id}"
                )
                self._circuit.record_failure()
            except (httpx.TimeoutException, httpx.TransportError) as net_err:
                last_exc = EmotionProviderError(f"Emotion service network/timeout error: {net_err}")
                self._circuit.record_failure()
            except EmotionProviderError:
                raise
            except Exception as parse_err:
                self._circuit.record_failure()
                raise EmotionProviderError(f"Emotion service invalid response: {parse_err}") from parse_err

            # Retry only if attempts remain, circuit allows, and sufficient deadline budget exists
            if attempt + 1 < attempts and self._circuit.allow_request():
                remaining_after = hard_deadline - time.monotonic()
                if remaining_after > 0.35:
                    await asyncio.sleep(min(0.15 * (attempt + 1), remaining_after / 3.0))
                    continue
            break

        raise last_exc or EmotionProviderError(f"Emotion inference failed for segment {segment_id}")

    def _parse_and_validate_response(
        self,
        *,
        payload: dict[str, Any],
        expected_segment_id: str,
        valid_speech_ms: int,
        duration_ms: int,
        sequence: int,
        user_turn_id: int,
        capture_epoch: int,
        start_offset_ms: int,
        end_offset_ms: int,
    ) -> EmotionSegmentPrediction:
        if not isinstance(payload, dict):
            raise ValueError("Response payload must be a JSON object")
        if payload.get("schema_version") != 1:
            raise ValueError(f"Unsupported schema_version: {payload.get('schema_version')}")
        if payload.get("status") != "ok":
            raise ValueError(f"Non-ok prediction status: {payload.get('status')}")

        raw_scores = payload.get("scores")
        if not isinstance(raw_scores, dict):
            raise ValueError("Missing or malformed 'scores' map in emotion prediction response")

        missing = [c for c in EMOTION2VEC_CANONICAL_CLASSES if c not in raw_scores]
        if missing:
            raise ValueError(f"Emotion prediction response missing canonical classes: {missing}")

        validated_scores: dict[str, float] = {}
        for cls in EMOTION2VEC_CANONICAL_CLASSES:
            val = raw_scores[cls]
            if not isinstance(val, int | float) or not math.isfinite(val):
                raise ValueError(f"Non-finite score for class '{cls}': {val}")
            if val < 0.0 or val > 1.0:
                raise ValueError(f"Out-of-range score for class '{cls}': {val}")
            validated_scores[cls] = float(val)

        ordered = sorted(validated_scores.items(), key=lambda item: item[1], reverse=True)
        primary_emotion, confidence = ordered[0]
        secondary_emotion = ordered[1][0] if len(ordered) > 1 else None

        return EmotionSegmentPrediction(
            schema_version=1,
            segment_id=str(payload.get("segment_id") or expected_segment_id),
            status="ok",
            model=str(payload.get("model") or "emotion2vec_plus_base"),
            model_revision=str(payload.get("model_revision") or "unknown"),
            runtime=str(payload.get("runtime") or "onnxruntime"),
            precision=str(payload.get("precision") or "int8"),
            scores=validated_scores,
            primary_emotion=primary_emotion,
            secondary_emotion=secondary_emotion,
            confidence=confidence,
            inference_ms=float(payload.get("inference_ms", 0.0)),
            valid_speech_ms=valid_speech_ms,
            duration_ms=duration_ms,
            sequence=sequence,
            user_turn_id=user_turn_id,
            capture_epoch=capture_epoch,
            start_offset_ms=start_offset_ms,
            end_offset_ms=end_offset_ms,
        )

    async def health_check(self) -> bool:
        try:
            headers: dict[str, str] = {}
            auth_header = await self._token_cache.get_authorization_header()
            if auth_header:
                headers["Authorization"] = auth_header
            resp = await self._client.get("/ready", headers=headers, timeout=min(1.5, self.timeout_s))
            return resp.status_code == 200
        except Exception:
            return False

    async def close(self) -> None:
        await self._client.aclose()
