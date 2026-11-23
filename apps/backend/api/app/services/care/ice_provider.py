from dataclasses import dataclass
import logging
from typing import Any

import httpx

from app.schemas.care.responses import IceServerConfig
from shared.config import settings

logger = logging.getLogger(__name__)

DEFAULT_STUN_URLS: list[str] = [
    "stun:stun.l.google.com:19302",
    "stun:stun1.l.google.com:19302",
    "stun:stun.cloudflare.com:3478",
]

CLOUDFLARE_TURN_ENDPOINT_TEMPLATE = (
    "https://rtc.live.cloudflare.com/v1/turn/keys/{token_id}/credentials/generate-ice-servers"
)


@dataclass(slots=True)
class ResolvedIceServers:
    ice_servers: list[str]
    ice_server_configs: list[IceServerConfig]


class IceServerProvider:
    """Resolves STUN and dynamic Cloudflare Calls TURN credentials with safe STUN fallback."""

    def __init__(
        self,
        *,
        config: Any = None,
        http_client: httpx.AsyncClient | None = None,
        timeout_seconds: float = 5.0,
    ) -> None:
        self._settings = config or settings
        self._http_client = http_client
        self._timeout_seconds = timeout_seconds

    def _get_stun_urls(self) -> list[str]:
        configured = getattr(self._settings, "WEBRTC_STUN_URLS", None)
        if isinstance(configured, list) and configured:
            cleaned = [str(url).strip() for url in configured if str(url).strip()]
            if cleaned:
                return list(dict.fromkeys(cleaned))
        if isinstance(configured, str) and configured.strip():
            cleaned = [part.strip() for part in configured.split(",") if part.strip()]
            if cleaned:
                return list(dict.fromkeys(cleaned))
        return list(DEFAULT_STUN_URLS)

    async def resolve_ice_servers(self) -> ResolvedIceServers:
        stun_urls = self._get_stun_urls()
        configs: list[IceServerConfig] = [IceServerConfig(urls=list(stun_urls))]
        flat_urls: list[str] = list(stun_urls)

        token_id = str(getattr(self._settings, "CLOUDFLARE_TURN_TOKEN_ID", "") or "").strip()
        api_token = str(getattr(self._settings, "CLOUDFLARE_TURN_API_TOKEN", "") or "").strip()
        if not token_id or not api_token:
            return ResolvedIceServers(ice_servers=flat_urls, ice_server_configs=configs)

        ttl_raw = getattr(self._settings, "CLOUDFLARE_TURN_TTL_SECONDS", 14400)
        try:
            ttl = max(60, int(ttl_raw))
        except (TypeError, ValueError):
            ttl = 14400

        turn_configs = await self._fetch_cloudflare_turn_configs(
            token_id=token_id,
            api_token=api_token,
            ttl=ttl,
        )
        for turn_cfg in turn_configs:
            configs.append(turn_cfg)
            urls = [turn_cfg.urls] if isinstance(turn_cfg.urls, str) else list(turn_cfg.urls)
            for url in urls:
                if url and url not in flat_urls:
                    flat_urls.append(url)

        return ResolvedIceServers(ice_servers=flat_urls, ice_server_configs=configs)

    async def _fetch_cloudflare_turn_configs(
        self,
        *,
        token_id: str,
        api_token: str,
        ttl: int,
    ) -> list[IceServerConfig]:
        url = CLOUDFLARE_TURN_ENDPOINT_TEMPLATE.format(token_id=token_id)
        headers = {
            "Authorization": f"Bearer {api_token}",
            "Content-Type": "application/json",
        }
        payload = {"ttl": ttl}

        try:
            if self._http_client is not None:
                response = await self._http_client.post(
                    url,
                    headers=headers,
                    json=payload,
                    timeout=self._timeout_seconds,
                )
            else:
                async with httpx.AsyncClient(timeout=self._timeout_seconds) as client:
                    response = await client.post(url, headers=headers, json=payload)

            if response.status_code >= 400:
                logger.warning(
                    "Cloudflare TURN API returned HTTP %s; falling back to STUN",
                    response.status_code,
                )
                return []

            data = response.json()
        except Exception as exc:
            logger.warning(
                "Cloudflare TURN credential request failed (%s); falling back to STUN",
                exc.__class__.__name__,
            )
            return []

        return self._parse_cloudflare_payload(data)

    @staticmethod
    def _parse_cloudflare_payload(data: Any) -> list[IceServerConfig]:
        if not isinstance(data, dict):
            return []

        raw_servers = data.get("iceServers")
        entries: list[Any]
        if isinstance(raw_servers, dict):
            entries = [raw_servers]
        elif isinstance(raw_servers, list):
            entries = raw_servers
        else:
            return []

        parsed: list[IceServerConfig] = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            raw_urls = entry.get("urls")
            if isinstance(raw_urls, str) and raw_urls.strip():
                urls: list[str] = [raw_urls.strip()]
            elif isinstance(raw_urls, list):
                urls = [str(u).strip() for u in raw_urls if str(u).strip()]
            else:
                continue

            if not urls:
                continue

            username = entry.get("username")
            credential = entry.get("credential")
            parsed.append(
                IceServerConfig(
                    urls=urls,
                    username=str(username) if username is not None else None,
                    credential=str(credential) if credential is not None else None,
                )
            )

        return parsed
