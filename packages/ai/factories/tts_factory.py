import logging
from typing import ClassVar

from packages.ai.interfaces.tts import BaseTTSProvider
from packages.ai.providers.tts.edge_tts_provider import EdgeTTSProvider
from packages.ai.providers.tts.elevenlabs_tts import ElevenLabsTTSProvider
from packages.ai.providers.tts.mock_tts import MockTTSProvider
from packages.ai.providers.tts.openai_tts import OpenAITTSProvider
from packages.shared.config import settings

logger = logging.getLogger(__name__)


def _is_placeholder(key: str | None) -> bool:
    if not key:
        return True
    return key.strip().startswith("your-") or "placeholder" in key.lower()


class TTSFactory:
    """Factory for instantiating TTS providers with strict fail-fast validation."""

    _instances: ClassVar[dict[str, BaseTTSProvider]] = {}

    @classmethod
    def get_provider(
        cls, provider_type: str | None = None, force_new: bool = False
    ) -> BaseTTSProvider:
        configured = (settings.TTS_PROVIDER or "").strip().lower()
        if provider_type is None and configured == "mock":
            raise RuntimeError(
                "TTS_PROVIDER='mock' is disabled; configure a real TTS provider "
                "(elevenlabs, elevenlabs_rest, openai, edge_tts)."
            )

        target = (provider_type or configured or "elevenlabs").strip().lower()

        if not force_new and target in cls._instances:
            return cls._instances[target]

        is_prod = settings.APP_ENV.lower() == "production"
        logger.info(f"Instantiating TTS Provider: '{target}'")

        if target in ("elevenlabs", "elevenlabs_ttd", "eleven_v3", "eleven_v4", "eleven_v4_turbo"):
            eleven_keys = [k for k in settings.get_elevenlabs_keys() if not _is_placeholder(k)]
            if not eleven_keys:
                raise RuntimeError(
                    "No valid ElevenLabs API key configured for TTS "
                    "(set ELEVENLABS_API_KEYS or TTS_API_KEY)."
                )
            if getattr(settings, "TTS_MODE", "ttd") == "rest" or target == "elevenlabs_rest":
                instance: BaseTTSProvider = ElevenLabsTTSProvider()
            else:
                try:
                    from packages.ai.providers.tts.elevenlabs_ttd_provider import ElevenLabsTTDProvider
                    instance = ElevenLabsTTDProvider()
                except Exception as ex:
                    logger.warning(f"Failed to initialize ElevenLabsTTDProvider ({ex}), falling back to ElevenLabs REST.")
                    instance = ElevenLabsTTSProvider()
        elif target == "elevenlabs_rest":
            eleven_keys = [k for k in settings.get_elevenlabs_keys() if not _is_placeholder(k)]
            if not eleven_keys:
                raise RuntimeError(
                    "No valid ElevenLabs API key configured for TTS "
                    "(set ELEVENLABS_API_KEYS or TTS_API_KEY)."
                )
            instance = ElevenLabsTTSProvider()
        elif target == "openai":
            if _is_placeholder(settings.TTS_API_KEY) and _is_placeholder(settings.LLM_API_KEY):
                raise RuntimeError("TTS_API_KEY or LLM_API_KEY is missing or placeholder for OpenAI TTS provider.")
            instance = OpenAITTSProvider()
        elif target in ("edge_tts", "edgetts", "edge"):
            instance = EdgeTTSProvider()
        elif target == "mock":
            if is_prod:
                raise RuntimeError("TTS_PROVIDER='mock' is prohibited in production.")
            instance = MockTTSProvider()
        else:
            raise RuntimeError(
                f"Unsupported TTS_PROVIDER '{target}'. Supported providers: elevenlabs, elevenlabs_rest, openai, edge_tts."
            )

        cls._instances[target] = instance
        return instance

    @classmethod
    def reset(cls) -> None:
        cls._instances.clear()
