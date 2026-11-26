"""Service-to-service authentication guard for the isolated emotion microservice.

Production requires `gcp_oidc` or `bearer` auth (`none` is rejected when APP_ENV=production).
"""

from __future__ import annotations

import hmac
import logging
import os

from fastapi import Header, HTTPException, status

logger = logging.getLogger(__name__)


def _verify_gcp_oidc_token(token: str, audience: str) -> None:
    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GCP OIDC verifier dependency (google-auth) is not installed",
        ) from exc

    try:
        claims = id_token.verify_oauth2_token(token, google_requests.Request(), audience=audience)
        issuer = claims.get("iss", "")
        if issuer not in ("https://accounts.google.com", "accounts.google.com"):
            raise ValueError(f"Unexpected OIDC issuer: {issuer}")
    except Exception as exc:
        logger.warning("[EMOTION AUTH] Rejected OIDC token: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid OIDC authorization token",
        ) from exc


async def verify_service_auth(
    authorization: str | None = Header(default=None),
) -> None:
    """Validate inbound service-to-service credentials."""
    app_env = os.getenv("APP_ENV", "development").strip().lower()
    auth_mode = os.getenv("EMOTION_SERVICE_AUTH_MODE", "none").strip().lower()

    if auth_mode == "none":
        if app_env == "production":
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Unauthenticated mode is prohibited in production",
            )
        return

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Bearer authorization header",
        )

    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Empty Bearer authorization token",
        )

    if auth_mode == "bearer":
        expected = os.getenv("EMOTION_SERVICE_BEARER_TOKEN", "").strip()
        if not expected or not hmac.compare_digest(token, expected):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid service bearer token",
            )
        return

    if auth_mode == "gcp_oidc":
        audience = os.getenv("EMOTION_SERVICE_AUDIENCE", "").strip()
        if not audience:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="EMOTION_SERVICE_AUDIENCE is not configured",
            )
        _verify_gcp_oidc_token(token, audience)
        return

    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail=f"Unsupported auth mode: {auth_mode}",
    )
