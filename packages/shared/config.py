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

    # Midtrans Payment (Core API QRIS) & BI-SNAP Optional Settings
    MIDTRANS_IS_PRODUCTION: bool = False
    MIDTRANS_MERCHANT_ID: str = ""
    MIDTRANS_SERVER_KEY: str = ""
    MIDTRANS_SIGNATURE_SECRET_KEY: str = ""
    MIDTRANS_CLIENT_KEY: str = ""
    MIDTRANS_QRIS_ACQUIRER: str = "gopay"
    MIDTRANS_PAYMENT_ENABLED: bool = False
    MIDTRANS_SANDBOX_SIMULATION_ENABLED: bool = False

    # Midtrans BI-SNAP Optional Credentials
    MIDTRANS_BISNAP_CLIENT_ID: str = ""
    MIDTRANS_BISNAP_CLIENT_SECRET: str = ""
    MIDTRANS_BISNAP_PRIVATE_KEY_PATH: str = ""
    MIDTRANS_BISNAP_PARTNER_ID: str = ""
    MIDTRANS_BISNAP_CHANNEL_ID: str = ""

    # Midtrans Payout (Iris Primary Adapter)
    MIDTRANS_PAYOUT_ENABLED: bool = False
    MIDTRANS_PAYOUT_PROVIDER_MODE: str = "iris"  # iris | mock (isolated test only)
    MIDTRANS_IRIS_BASE_URL: str = ""
    MIDTRANS_IRIS_CREATOR_KEY: str = ""
    MIDTRANS_IRIS_APPROVER_KEY: str = ""
    MIDTRANS_IRIS_NOTIFICATION_SECRET: str = ""
    MIDTRANS_PAYOUT_AUTO_APPROVE: bool = False

    # At-Rest Bank Account Encryption
    BANK_ACCOUNT_ENCRYPTION_KEY: str = ""

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
            "MIDTRANS_MERCHANT_ID",
            "MIDTRANS_SERVER_KEY",
            "MIDTRANS_SIGNATURE_SECRET_KEY",
            "MIDTRANS_CLIENT_KEY",
            "MIDTRANS_QRIS_ACQUIRER",
            "MIDTRANS_BISNAP_CLIENT_ID",
            "MIDTRANS_BISNAP_CLIENT_SECRET",
            "MIDTRANS_BISNAP_PRIVATE_KEY_PATH",
            "MIDTRANS_BISNAP_PARTNER_ID",
            "MIDTRANS_BISNAP_CHANNEL_ID",
            "MIDTRANS_PAYOUT_PROVIDER_MODE",
            "MIDTRANS_IRIS_BASE_URL",
            "MIDTRANS_IRIS_CREATOR_KEY",
            "MIDTRANS_IRIS_APPROVER_KEY",
            "MIDTRANS_IRIS_NOTIFICATION_SECRET",
            "BANK_ACCOUNT_ENCRYPTION_KEY",
            "STT_PROVIDER",
            "ELEVENLABS_STT_API_KEY",
            "ELEVENLABS_STT_URL",
            "ELEVENLABS_STT_MODEL_ID",
            "ELEVENLABS_STT_LANGUAGE_CODE",
            "ELEVENLABS_STT_COMMIT_STRATEGY",
        ):
            if env_key in os.environ:
                setattr(self, env_key, os.environ[env_key])

        for bool_env_key in (
            "MIDTRANS_IS_PRODUCTION",
            "MIDTRANS_PAYMENT_ENABLED",
            "MIDTRANS_SANDBOX_SIMULATION_ENABLED",
            "MIDTRANS_PAYOUT_ENABLED",
            "MIDTRANS_PAYOUT_AUTO_APPROVE",
            "STT_ALLOW_INCOGNITO_CLOUD_AUDIO",
        ):
            if bool_env_key in os.environ:
                raw_val = os.environ[bool_env_key].strip().lower()
                setattr(self, bool_env_key, raw_val in ("1", "true", "yes", "on"))

        for float_env_key in (
            "ELEVENLABS_STT_VAD_SILENCE_THRESHOLD_SECS",
            "ELEVENLABS_STT_VAD_THRESHOLD",
            "STT_IDLE_CLOSE_TIMEOUT_S",
        ):
            if float_env_key in os.environ:
                try:
                    setattr(self, float_env_key, float(os.environ[float_env_key]))
                except ValueError:
                    logger.warning("Ignoring invalid OS env %s value", float_env_key)

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

    # LLM Settings (openai | gemini | deepseek | ollama)
    LLM_PROVIDER: str = "openai"
    LLM_API_KEY: str = ""
    LLM_MODEL: str = "gpt-4o"
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-1.5-flash"
    DEEPSEEK_MODEL: str = "deepseek-chat"
    OLLAMA_BASE_URL: str = "http://100.82.167.100:11434"

    OLLAMA_MODEL: str = "qwen3:1.7B"

    # STT Settings (elevenlabs)
    STT_PROVIDER: str = "elevenlabs"
    STT_API_KEY: str = ""
    ELEVENLABS_STT_API_KEY: str = ""
    ELEVENLABS_STT_URL: str = "wss://api.elevenlabs.io/v1/speech-to-text/realtime"
    ELEVENLABS_STT_MODEL_ID: str = "scribe_v2_realtime"
    ELEVENLABS_STT_LANGUAGE_CODE: str = "id"
    ELEVENLABS_STT_COMMIT_STRATEGY: str = "vad"
    ELEVENLABS_STT_VAD_SILENCE_THRESHOLD_SECS: float = 0.8
    ELEVENLABS_STT_VAD_THRESHOLD: float = 0.4
    STT_IDLE_CLOSE_TIMEOUT_S: float = 15.0
    STT_ALLOW_INCOGNITO_CLOUD_AUDIO: bool = False  # Fail-closed by default

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

    # Continuous 3-Second Speech Emotion Orchestration (Issue #143 — default OFF until gates pass)
    EMOTION_STREAMING_ENABLED: bool = False
    EMOTION_PROVIDER: str = "remote_http"  # 'remote_http'
    EMOTION_SERVICE_URL: str = ""
    EMOTION_SERVICE_AUTH_MODE: str = "none"  # 'none' | 'gcp_oidc' | 'bearer'
    EMOTION_SERVICE_AUDIENCE: str = ""
    EMOTION_SERVICE_BEARER_TOKEN: str = ""
    EMOTION_SERVICE_TIMEOUT_MS: int = 2000
    EMOTION_SERVICE_MAX_RETRIES: int = 1
    EMOTION_SERVICE_CIRCUIT_FAIL_THRESHOLD: int = 5
    EMOTION_SERVICE_CIRCUIT_COOLDOWN_S: float = 30.0
    EMOTION_SEGMENT_DURATION_MS: int = 3000
    EMOTION_MIN_TAIL_DURATION_MS: int = 750
    EMOTION_WINDOW_TARGET_MS: int = 30000  # 30000..60000 ms valid speech target
    EMOTION_WINDOW_STALENESS_MS: int = 180000
    EMOTION_WINDOW_MIN_COVERAGE: float = 0.60
    EMOTION_DISPATCHER_MAX_INFLIGHT: int = 32
    EMOTION_DISPATCHER_PER_SESSION_MAX_INFLIGHT: int = 4
    EMOTION_DISPATCHER_QUEUE_SIZE: int = 128
    EMOTION_SEGMENT_DEADLINE_MS: int = 4000
    EMOTION_FINALIZE_DRAIN_MS: int = 1500
    EMOTION_ALLOW_INCOGNITO_CLOUD_AUDIO: bool = False  # Fail-closed by default

    @field_validator("EMOTION_WINDOW_TARGET_MS")
    @classmethod
    def _validate_emotion_window_target_ms(cls, value: int) -> int:
        if value < 10000 or value > 60000:
            raise ValueError("EMOTION_WINDOW_TARGET_MS must be between 10000 and 60000 ms")
        return value

    @field_validator("EMOTION_SEGMENT_DURATION_MS")
    @classmethod
    def _validate_emotion_segment_duration_ms(cls, value: int) -> int:
        if value < 1000 or value > 10000:
            raise ValueError("EMOTION_SEGMENT_DURATION_MS must be between 1000 and 10000 ms")
        return value

    @field_validator("EMOTION_MIN_TAIL_DURATION_MS")
    @classmethod
    def _validate_emotion_min_tail_duration_ms(cls, value: int) -> int:
        if value < 250 or value > 2500:
            raise ValueError("EMOTION_MIN_TAIL_DURATION_MS must be between 250 and 2500 ms")
        return value

    @field_validator("EMOTION_WINDOW_MIN_COVERAGE")
    @classmethod
    def _validate_emotion_window_min_coverage(cls, value: float) -> float:
        if value <= 0.0 or value > 1.0:
            raise ValueError("EMOTION_WINDOW_MIN_COVERAGE must be in (0.0, 1.0]")
        return value

    def get_elevenlabs_keys(self) -> list[str]:
        """Return list of valid ElevenLabs API keys from ELEVENLABS_API_KEYS or fallback to TTS_API_KEY."""
        if self.ELEVENLABS_API_KEYS:
            keys = [k.strip() for k in self.ELEVENLABS_API_KEYS.split(",") if k.strip()]
            if keys:
                return keys
        if self.TTS_API_KEY and self.TTS_API_KEY.strip():
            return [self.TTS_API_KEY.strip()]
        return []

    def get_elevenlabs_stt_keys(self) -> list[str]:
        """Return ElevenLabs STT API keys from ELEVENLABS_STT_API_KEY or fallback to ELEVENLABS_API_KEYS."""
        if self.ELEVENLABS_STT_API_KEY and self.ELEVENLABS_STT_API_KEY.strip():
            keys = [k.strip() for k in self.ELEVENLABS_STT_API_KEY.split(",") if k.strip()]
            if keys:
                return keys
        return self.get_elevenlabs_keys()




settings = BaseConfig()
