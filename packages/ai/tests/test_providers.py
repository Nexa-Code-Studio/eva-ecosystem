import pytest
from packages.ai.factories.llm_factory import LLMFactory
from packages.ai.factories.tts_factory import TTSFactory
from packages.ai.interfaces.llm import LLMMessage
from packages.ai.providers.llm.ollama_llm import OllamaLLMProvider
from packages.ai.providers.tts.edge_tts_provider import EdgeTTSProvider
from packages.shared.config import settings


def test_llm_factory_fail_fast(monkeypatch):
    LLMFactory.reset()
    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "LLM_PROVIDER", "deepseek")
    monkeypatch.setattr(settings, "LLM_API_KEY", "")
    with pytest.raises(RuntimeError, match="LLM_API_KEY is missing or placeholder"):
        LLMFactory.get_provider(force_new=True)

    monkeypatch.setattr(settings, "LLM_PROVIDER", "mock")
    with pytest.raises(RuntimeError, match="LLM_PROVIDER='mock' is disabled"):
        LLMFactory.get_provider(force_new=True)

    monkeypatch.setattr(settings, "LLM_PROVIDER", "unknown_llm")
    with pytest.raises(RuntimeError, match="Unsupported LLM_PROVIDER"):
        LLMFactory.get_provider(force_new=True)
    LLMFactory.reset()


def test_tts_factory_fail_fast(monkeypatch):
    TTSFactory.reset()
    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "TTS_PROVIDER", "elevenlabs")
    monkeypatch.setattr(settings, "ELEVENLABS_API_KEYS", "")
    monkeypatch.setattr(settings, "TTS_API_KEY", "")
    with pytest.raises(RuntimeError, match="No valid ElevenLabs API key"):
        TTSFactory.get_provider(force_new=True)

    monkeypatch.setattr(settings, "TTS_PROVIDER", "mock")
    with pytest.raises(RuntimeError, match="TTS_PROVIDER='mock' is disabled"):
        TTSFactory.get_provider(force_new=True)

    monkeypatch.setattr(settings, "TTS_PROVIDER", "unknown_tts")
    with pytest.raises(RuntimeError, match="Unsupported TTS_PROVIDER"):
        TTSFactory.get_provider(force_new=True)
    TTSFactory.reset()


def test_llm_factory_ollama():
    provider = LLMFactory.get_provider("ollama")
    assert isinstance(provider, OllamaLLMProvider)
    assert provider.model == "qwen3:1.7B"
    assert "100.82.167.100" in provider.base_url


def test_tts_factory_edge():
    provider = TTSFactory.get_provider("edge_tts")
    assert isinstance(provider, EdgeTTSProvider)
    assert provider.default_voice == "id-ID-GadisNeural"



@pytest.mark.asyncio
async def test_ollama_provider_format():
    provider = OllamaLLMProvider(base_url="http://100.82.167.100:11434", model="qwen3:1.7B")
    formatted = provider._format_messages([
        LLMMessage(role="user", content="Halo Luna")
    ])
    assert formatted == [{"role": "user", "content": "Halo Luna"}]
