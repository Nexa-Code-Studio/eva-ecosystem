import logging
from typing import ClassVar

from packages.ai.interfaces.llm import BaseLLMProvider
from packages.ai.providers.llm.deepseek_llm import DeepSeekLLMProvider
from packages.ai.providers.llm.gemini_llm import GeminiLLMProvider
from packages.ai.providers.llm.mock_llm import MockLLMProvider
from packages.ai.providers.llm.ollama_llm import OllamaLLMProvider
from packages.ai.providers.llm.openai_llm import OpenAILLMProvider
from packages.shared.config import settings

logger = logging.getLogger(__name__)


def _is_placeholder(key: str | None) -> bool:
    if not key:
        return True
    return key.strip().startswith("your-") or "placeholder" in key.lower()


class LLMFactory:
    """Factory for instantiating LLM providers with strict fail-fast validation."""

    _instances: ClassVar[dict[str, BaseLLMProvider]] = {}

    @classmethod
    def get_provider(
        cls, provider_type: str | None = None, force_new: bool = False
    ) -> BaseLLMProvider:
        configured = (settings.LLM_PROVIDER or "").strip().lower()
        if provider_type is None and configured == "mock":
            raise RuntimeError(
                "LLM_PROVIDER='mock' is disabled; configure a real LLM provider "
                "(deepseek, openai, gemini, ollama)."
            )

        target = (provider_type or configured or "openai").strip().lower()

        if not force_new and target in cls._instances:
            return cls._instances[target]

        is_prod = settings.APP_ENV.lower() == "production"
        logger.info(f"Instantiating LLM Provider: '{target}'")

        if target in ("deepseek", "deepseek-chat"):
            if _is_placeholder(settings.LLM_API_KEY):
                raise RuntimeError("LLM_API_KEY is missing or placeholder for DeepSeek provider.")
            instance: BaseLLMProvider = DeepSeekLLMProvider()
        elif target == "openai":
            if _is_placeholder(settings.LLM_API_KEY):
                raise RuntimeError("LLM_API_KEY is missing or placeholder for OpenAI provider.")
            instance = OpenAILLMProvider()
        elif target == "gemini":
            if _is_placeholder(settings.GEMINI_API_KEY) and _is_placeholder(settings.LLM_API_KEY):
                raise RuntimeError("GEMINI_API_KEY or LLM_API_KEY is missing or placeholder for Gemini provider.")
            instance = GeminiLLMProvider()
        elif target == "ollama":
            instance = OllamaLLMProvider()
        elif target == "mock":
            if is_prod:
                raise RuntimeError("LLM_PROVIDER='mock' is prohibited in production.")
            instance = MockLLMProvider()
        else:
            raise RuntimeError(
                f"Unsupported LLM_PROVIDER '{target}'. Supported providers: deepseek, openai, gemini, ollama."
            )

        cls._instances[target] = instance
        return instance

    @classmethod
    def reset(cls) -> None:
        cls._instances.clear()
