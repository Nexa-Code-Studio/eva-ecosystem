"""Contract & security tests for the isolated ONNX INT8 Emotion Microservice."""

from __future__ import annotations

import sys
from pathlib import Path

from fastapi.testclient import TestClient

SERVICE_ROOT = Path(__file__).resolve().parent.parent
if str(SERVICE_ROOT) not in sys.path:
    sys.path.insert(0, str(SERVICE_ROOT))

from app.engine import ONNXEmotionEngine
from app.main import create_app
from app.schemas import EMOTION_CLASSES


def test_health_and_readiness_lifecycle(monkeypatch):
    monkeypatch.setenv("APP_ENV", "development")
    monkeypatch.setenv("EMOTION_SERVICE_AUTH_MODE", "none")
    monkeypatch.setenv("EMOTION_SKIP_STARTUP_LOAD", "true")

    eng = ONNXEmotionEngine(backend="mock")
    application = create_app(custom_engine=eng)

    with TestClient(application) as client:
        assert client.get("/health").status_code == 200
        # Not loaded yet -> 503
        assert client.get("/ready").status_code == 503

        eng.load()
        ready_resp = client.get("/ready")
        assert ready_resp.status_code == 200
        body = ready_resp.json()
        assert body["ready"] is True
        assert body["model"] == "emotion2vec_plus_base"


def test_predict_endpoint_contract_validation_and_bearer_auth(monkeypatch):
    monkeypatch.setenv("APP_ENV", "development")
    monkeypatch.setenv("EMOTION_SERVICE_AUTH_MODE", "bearer")
    monkeypatch.setenv("EMOTION_SERVICE_BEARER_TOKEN", "secret-test-token")
    monkeypatch.setenv("EMOTION_SKIP_STARTUP_LOAD", "false")

    eng = ONNXEmotionEngine(backend="mock")
    application = create_app(custom_engine=eng)

    valid_3s_pcm = b"\x10\x05" * 48_000
    headers = {
        "Content-Type": "application/octet-stream",
        "X-Schema-Version": "1",
        "X-Segment-Id": "opaque-seg-001",
        "X-Sample-Rate": "16000",
        "X-Channels": "1",
        "X-Sample-Format": "pcm_s16le",
    }

    with TestClient(application) as client:
        # Missing auth -> 401
        r_no_auth = client.post("/v1/emotions/predict", content=valid_3s_pcm, headers=headers)
        assert r_no_auth.status_code == 401

        # Wrong token -> 403
        r_bad_auth = client.post(
            "/v1/emotions/predict",
            content=valid_3s_pcm,
            headers={**headers, "Authorization": "Bearer wrong-token"},
        )
        assert r_bad_auth.status_code == 403

        auth_headers = {**headers, "Authorization": "Bearer secret-test-token"}

        # Valid 3s PCM16 -> 200 with full 9 canonical classes
        r_ok = client.post("/v1/emotions/predict", content=valid_3s_pcm, headers=auth_headers)
        assert r_ok.status_code == 200
        data = r_ok.json()
        assert data["schema_version"] == 1
        assert data["segment_id"] == "opaque-seg-001"
        assert data["status"] == "ok"
        assert set(data["scores"].keys()) == set(EMOTION_CLASSES)
        assert all(0.0 <= v <= 1.0 for v in data["scores"].values())

        # Too short -> 400
        assert client.post("/v1/emotions/predict", content=b"\x00\x00" * 100, headers=auth_headers).status_code == 400
        # Odd byte length -> 400
        assert client.post("/v1/emotions/predict", content=b"\x01" * 9001, headers=auth_headers).status_code == 400
        # Too large (> 10s) -> 413
        assert client.post("/v1/emotions/predict", content=b"\x00\x00" * 200_000, headers=auth_headers).status_code == 413
        # Wrong sample rate -> 400
        assert (
            client.post(
                "/v1/emotions/predict",
                content=valid_3s_pcm,
                headers={**auth_headers, "X-Sample-Rate": "44100"},
            ).status_code
            == 400
        )


def test_production_blocks_unauthenticated_mode(monkeypatch):
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("EMOTION_SERVICE_AUTH_MODE", "none")
    monkeypatch.setenv("EMOTION_SKIP_STARTUP_LOAD", "true")

    eng = ONNXEmotionEngine(backend="mock")
    eng._ready = True
    application = create_app(custom_engine=eng)

    with TestClient(application) as client:
        resp = client.post(
            "/v1/emotions/predict",
            content=b"\x01\x02" * 16_000,
            headers={"X-Segment-Id": "prod-unauth"},
        )
        assert resp.status_code == 503
