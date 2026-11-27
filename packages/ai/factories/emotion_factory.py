"""Factory for instantiating speech emotion inference providers."""

from __future__ import annotations

import logging
from typing import ClassVar

from packages.ai.interfaces.emotion import BaseEmotionProvider
from packages.ai.providers.emotion.mock_emotion import MockEmotionProvider
from packages.ai.providers.emotion.remote_http_emotion import RemoteHTTPEmotionProvider
from packages.shared.config import settings

logger = logging.getLogger(__name__)


class EmotionFactory:
    """Centralized provider factory enforcing strict fail-fast configuration without silent mock fallbacks."""

    _instances: ClassVar[dict[str, BaseEmotionProvider]] = {}

    @classmethod
    def get_provider(
        cls,
        provider_type: str | None = None,
        *,
        force_new: bool = False,
    ) -> BaseEmotionProvider:
        configured = (settings.EMOTION_PROVIDER or "").strip().lower()
        if provider_type is None and configured == "mock":
            raise RuntimeError(
                "EMOTION_PROVIDER='mock' is disabled; configure 'remote_http' with EMOTION_SERVICE_URL."
            )

        target = (provider_type or configured or "remote_http").strip().lower()

        if not force_new and target in cls._instances:
            return cls._instances[target]

        is_prod = settings.APP_ENV.lower() == "production"

        if target == "mock":
            if is_prod:
                raise RuntimeError("EMOTION_PROVIDER='mock' is prohibited in production.")
            instance: BaseEmotionProvider = MockEmotionProvider()
        elif target == "remote_http":
            url = (settings.EMOTION_SERVICE_URL or "").strip()
            auth_mode = (settings.EMOTION_SERVICE_AUTH_MODE or "none").strip().lower()
            if not url:
                raise RuntimeError(
                    "EMOTION_SERVICE_URL must be configured for EMOTION_PROVIDER='remote_http'."
                )
            if is_prod and auth_mode == "none":
                raise RuntimeError(
                    "Unauthenticated emotion inference (EMOTION_SERVICE_AUTH_MODE='none') is prohibited in production."
                )
            instance = RemoteHTTPEmotionProvider(
                base_url=url,
                auth_mode=auth_mode,
                audience=settings.EMOTION_SERVICE_AUDIENCE or url,
                bearer_token=settings.EMOTION_SERVICE_BEARER_TOKEN,
                timeout_ms=settings.EMOTION_SERVICE_TIMEOUT_MS,
                max_retries=settings.EMOTION_SERVICE_MAX_RETRIES,
                circuit_fail_threshold=settings.EMOTION_SERVICE_CIRCUIT_FAIL_THRESHOLD,
                circuit_cooldown_s=settings.EMOTION_SERVICE_CIRCUIT_COOLDOWN_S,
            )
        else:
            raise RuntimeError(
                f"Unsupported EMOTION_PROVIDER '{target}'. Supported: remote_http."
            )

        cls._instances[target] = instance
        return instance

    @classmethod
    async def close_all(cls) -> None:
        for provider in list(cls._instances.values()):
            try:
                await provider.close()
            except Exception as err:
                logger.warning("Error closing emotion provider: %s", err)
        cls._instances.clear()
