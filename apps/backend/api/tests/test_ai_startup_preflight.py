"""Tests for fail-fast AI provider startup preflight in FastAPI lifespan."""

from __future__ import annotations

import pytest

from app.main import _validate_ai_providers_startup
from packages.ai.factories import EmotionFactory, LLMFactory, STTFactory, TTSFactory
from packages.shared.config import settings


def _reset_factories() -> None:
    STTFactory.reset()
    LLMFactory.reset()
    TTSFactory.reset()
    EmotionFactory._instances.clear()


def test_startup_preflight_rejects_whisper_and_mock(monkeypatch):
    _reset_factories()
    monkeypatch.delenv("PYTEST_CURRENT_TEST", raising=False)
    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "STT_PROVIDER", "whisper")
    monkeypatch.setattr(settings, "LLM_PROVIDER", "deepseek")
    monkeypatch.setattr(settings, "LLM_API_KEY", "sk-test-llm-key")
    monkeypatch.setattr(settings, "TTS_PROVIDER", "elevenlabs")
    monkeypatch.setattr(settings, "ELEVENLABS_API_KEYS", "sk-test-el-key")
    monkeypatch.setattr(settings, "EMOTION_STREAMING_ENABLED", False)

    with pytest.raises(RuntimeError, match="Unsupported STT_PROVIDER 'whisper'"):
        _validate_ai_providers_startup()

    monkeypatch.setattr(settings, "STT_PROVIDER", "mock")
    with pytest.raises(RuntimeError, match="STT_PROVIDER='mock' is disabled"):
        _validate_ai_providers_startup()
    _reset_factories()


def test_startup_preflight_succeeds_with_elevenlabs_and_real_providers(monkeypatch):
    _reset_factories()
    monkeypatch.delenv("PYTEST_CURRENT_TEST", raising=False)
    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "STT_PROVIDER", "elevenlabs")
    monkeypatch.setattr(settings, "ELEVENLABS_STT_API_KEY", "")
    monkeypatch.setattr(settings, "ELEVENLABS_API_KEYS", "sk-test-el-key")
    monkeypatch.setattr(settings, "LLM_PROVIDER", "deepseek")
    monkeypatch.setattr(settings, "LLM_API_KEY", "sk-test-llm-key")
    monkeypatch.setattr(settings, "TTS_PROVIDER", "elevenlabs")
    monkeypatch.setattr(settings, "EMOTION_STREAMING_ENABLED", True)
    monkeypatch.setattr(settings, "EMOTION_PROVIDER", "remote_http")
    monkeypatch.setattr(settings, "EMOTION_SERVICE_URL", "http://emotion_service:8890")
    monkeypatch.setattr(settings, "EMOTION_SERVICE_AUTH_MODE", "none")

    _validate_ai_providers_startup()
    _reset_factories()
