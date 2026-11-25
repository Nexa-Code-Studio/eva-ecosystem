import json
import logging
import os
from pathlib import Path
from typing import Annotated, Any

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

logger = logging.getLogger(__name__)
ROOT_DIR = Path(__file__).resolve().parents[2]

DEFAULT_WEBRTC_STUN_URLS: tuple[str, ...] = (
    "stun:stun.l.google.com:19302",
    "stun:stun1.l.google.com:19302",
    "stun:stun.cloudflare.com:3478",
)


def normalize_ws_base_url(value: Any, fallback: str = "ws://localhost:8888") -> str:
    """Normalize WebSocket base URL, converting http(s) schemes to ws(s) without trailing slashes."""
    raw = str(value or "").strip().rstrip("/")
    if not raw:
        return fallback
    if raw.startswith("https://"):
        return f"wss://{raw.removeprefix('https://')}"
    if raw.startswith("http://"):
        return f"ws://{raw.removeprefix('http://')}"
    return raw


def parse_stun_urls(value: Any) -> list[str]:
    """Parse STUN URLs from JSON array strings, comma-separated strings, or string iterables."""
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return list(DEFAULT_WEBRTC_STUN_URLS)
        if stripped.startswith("["):
            try:
                decoded = json.loads(stripped)
            except json.JSONDecodeError:
                decoded = None
            if isinstance(decoded, list):
                return parse_stun_urls(decoded)
        items = [item.strip() for item in stripped.split(",") if item.strip()]
        return items or list(DEFAULT_WEBRTC_STUN_URLS)
    if isinstance(value, (list, tuple, set)):
        items = [str(item).strip() for item in value if str(item).strip()]
        return items or list(DEFAULT_WEBRTC_STUN_URLS)
    return list(DEFAULT_WEBRTC_STUN_URLS)


class BaseConfig(BaseSettings):
    """Base application environment configuration."""

    model_config = SettingsConfigDict(
        env_file=(str(ROOT_DIR / ".env"), ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    APP_ENV: str = "development"
    LOG_LEVEL: str = "INFO"
    PORT: int = 8888
    MCP_PORT: int = 8889
    UPLOAD_DIR: str = "/app/uploads"
    BOOTH_FEEDBACK_MAX_PHOTOS: int = 5
    BOOTH_FEEDBACK_MAX_PHOTO_BYTES: int = 5 * 1024 * 1024

    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5435/luna_ai"
    REDIS_URL: str = "redis://localhost:6380/0"
    WS_BASE_URL: str = "ws://localhost:8888"

    # WebRTC Signaling & Cloudflare Calls Managed TURN
    CLOUDFLARE_TURN_TOKEN_ID: str = ""
    CLOUDFLARE_TURN_API_TOKEN: str = ""
    CLOUDFLARE_TURN_TTL_SECONDS: int = 14400
    WEBRTC_STUN_URLS: Annotated[list[str], NoDecode] = list(DEFAULT_WEBRTC_STUN_URLS)
    WEBRTC_RECONNECT_GRACE_SECONDS: int = 25
    QDRANT_URL: str = "http://localhost:6333"

    @field_validator("WEBRTC_STUN_URLS", mode="before")
    @classmethod
    def _validate_webrtc_stun_urls(cls, value: Any) -> list[str]:
        return parse_stun_urls(value)

    @field_validator("WS_BASE_URL", mode="before")
    @classmethod
    def _validate_ws_base_url(cls, value: Any) -> str:
        return normalize_ws_base_url(value)

    @model_validator(mode="after")
    def _apply_os_environment_overrides(self) -> "BaseConfig":
        """Force explicit OS environment variables (e.g. from Docker Compose) to override .env file."""
        for env_key in (
            "DATABASE_URL",
            "REDIS_URL",
            "QDRANT_URL",
            "CLOUDFLARE_TURN_TOKEN_ID",
            "CLOUDFLARE_TURN_API_TOKEN",
            "UPLOAD_DIR",
        ):
            if env_key in os.environ:
                setattr(self, env_key, os.environ[env_key])

        if "WS_BASE_URL" in os.environ:
            self.WS_BASE_URL = normalize_ws_base_url(os.environ["WS_BASE_URL"])

        if "WEBRTC_RECONNECT_GRACE_SECONDS" in os.environ:
            try:
                self.WEBRTC_RECONNECT_GRACE_SECONDS = int(os.environ["WEBRTC_RECONNECT_GRACE_SECONDS"])
            except ValueError:
                logger.warning("Ignoring invalid OS env WEBRTC_RECONNECT_GRACE_SECONDS value")

        if self.APP_ENV == "production" and (
            "localhost" in self.WS_BASE_URL or "127.0.0.1" in self.WS_BASE_URL
        ):
            logger.warning(
                "WS_BASE_URL=%s points to loopback in production; configure WS_BASE_URL=wss://<domain> in .env",
                self.WS_BASE_URL,
            )
        return self

    # LLM Settings (openai | gemini | ollama | mock)
    LLM_PROVIDER: str = "openai"
    LLM_API_KEY: str = ""
    LLM_MODEL: str = "gpt-4o"
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-1.5-flash"
    DEEPSEEK_MODEL: str = "deepseek-chat"
    OLLAMA_BASE_URL: str = "http://100.82.167.100:11434"

    OLLAMA_MODEL: str = "qwen3:1.7B"

    # STT Settings (whisper | openai | mock)
    STT_PROVIDER: str = "whisper"
    STT_API_KEY: str = ""

    # TTS Settings (elevenlabs | openai | edge_tts | mock)
    TTS_PROVIDER: str = "elevenlabs"
    TTS_API_KEY: str = ""
    ELEVENLABS_API_KEYS: str = ""
    TTS_VOICE_ID: str = "cgSgspJ2msm6clMCkdW9"  # ElevenLabs Jessica voice ID
    TTS_MODEL: str = "eleven_v4_turbo"
    TTS_FALLBACK_MODEL: str = "eleven_multilingual_v2"
    TTS_ENABLE_AUDIO_TAGS: bool = True
    TTS_MODE: str = "ttd"  # ttd | rest
    ELEVENLABS_TTD_URL: str = "wss://api.elevenlabs.io/v1/text-to-dialogue/stream-input"
    ELEVENLABS_OUTPUT_FORMAT: str = "mp3_44100_128"
    EDGE_TTS_VOICE: str = "id-ID-GadisNeural"
    SUPPORTED_TTD_MODEL_PREFIXES: tuple[str, ...] = ("eleven_v3", "eleven_v4")
    DEFAULT_TTD_MODEL: str = "eleven_v4_turbo"

    # Feature Flags & Rollout Versioning
    LUNA_PROMPT_VERSION: str = "v2"  # 'v1' (legacy) | 'v2' (layered spoken Indonesian)
    LUNA_AUDIO_TAG_POLICY_VERSION: str = "v2"  # 'v1' (strict map) | 'v2' (counseling safe hints)
    LUNA_NORMALIZER_MODE: str = "conversational"  # 'conversational' (preserves informal) | 'strict'

    def get_elevenlabs_keys(self) -> list[str]:
        """Return list of valid ElevenLabs API keys from ELEVENLABS_API_KEYS or fallback to TTS_API_KEY."""
        if self.ELEVENLABS_API_KEYS:
            keys = [k.strip() for k in self.ELEVENLABS_API_KEYS.split(",") if k.strip()]
            if keys:
                return keys
        if self.TTS_API_KEY and self.TTS_API_KEY.strip():
            return [self.TTS_API_KEY.strip()]
        return []




settings = BaseConfig()
