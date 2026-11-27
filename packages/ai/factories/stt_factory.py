"""Factory for instantiating Speech-to-Text providers with dev fallback and prod fail-fast."""

from __future__ import annotations

import logging
from typing import ClassVar

from packages.ai.interfaces.stt import BaseSTTProvider
from packages.ai.providers.stt.elevenlabs_stt import ElevenLabsRealtimeSTTProvider
from packages.ai.providers.stt.mock_stt import MockSTTProvider
from packages.shared.config import settings

logger = logging.getLogger(__name__)


def _is_placeholder(key: str | None) -> bool:
    if not key:
        return True
    cleaned = key.strip()
    return not cleaned or cleaned.startswith("your-") or "placeholder" in cleaned.lower()


class STTFactory:
    """Centralized provider factory for realtime Speech-to-Text."""

    _instances: ClassVar[dict[str, BaseSTTProvider]] = {}

    @classmethod
    def get_provider(
        cls,
        provider_type: str | None = None,
        *,
        force_new: bool = False,
    ) -> BaseSTTProvider:
        target = (provider_type or settings.STT_PROVIDER or "elevenlabs").strip().lower()

        if not force_new and target in cls._instances:
            return cls._instances[target]

        is_prod = settings.APP_ENV.lower() == "production"

        if target == "mock":
            if is_prod:
                raise RuntimeError("STT_PROVIDER='mock' is prohibited in production.")
            instance: BaseSTTProvider = MockSTTProvider()
        elif target in ("elevenlabs", "elevenlabs_realtime", "scribe_v2_realtime"):
            keys = [k for k in settings.get_elevenlabs_stt_keys() if not _is_placeholder(k)]
            if not keys:
                if is_prod:
                    raise RuntimeError(
                        "No valid ElevenLabs API key configured for STT in production "
                        "(set ELEVENLABS_STT_API_KEY or ELEVENLABS_API_KEYS)."
                    )
                logger.warning(
                    "No valid ElevenLabs STT API key configured in %s; falling back to MockSTTProvider.",
                    settings.APP_ENV,
                )
                instance = MockSTTProvider()
            else:
                instance = ElevenLabsRealtimeSTTProvider(api_key=",".join(keys))
        else:
            if is_prod:
                raise RuntimeError(f"Unsupported STT_PROVIDER '{target}' in production.")
            logger.warning("Unknown STT_PROVIDER '%s'; falling back to MockSTTProvider.", target)
            instance = MockSTTProvider()

        cls._instances[target] = instance
        return instance

    @classmethod
    def reset(cls) -> None:
        cls._instances.clear()
