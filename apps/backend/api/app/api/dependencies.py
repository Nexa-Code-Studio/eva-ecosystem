from collections.abc import AsyncGenerator
import logging

from fastapi import Depends, Header, HTTPException, Query, status
from redis.asyncio import Redis, from_url
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.models.user import User
from shared.config import settings

logger = logging.getLogger(__name__)


async def get_redis_client() -> AsyncGenerator[Redis, None]:
    """Dependency for providing Async Redis client."""
    client: Redis = from_url(settings.REDIS_URL, decode_responses=True)
    try:
        yield client
    finally:
        await client.close()


def extract_auth_token(
    authorization: str | None = Header(None),
    token_query: str | None = Query(None, alias="token"),
) -> str:
    """Extract raw bearer token from Authorization header or 'token' query parameter."""
    token = None
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split("Bearer ")[1].strip()
    elif token_query:
        token = token_query.strip()

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Header Authorization Bearer atau token query diperlukan",
        )
    return token


async def get_auth_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for AuthService."""
    from app.services.auth import AuthService

    return AuthService(db)


async def get_current_user(
    token: str = Depends(extract_auth_token),
    service=Depends(get_auth_service),
) -> User:
    """Strictly authenticate current user from Bearer JWT access token or query parameter."""
    return await service.get_user_from_token(token)


async def get_current_admin(
    current_user: User = Depends(get_current_user),
) -> User:
    """Ensure the authenticated user has administrator privileges."""
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akses ditolak: hanya Administrator EVA yang dapat mengakses fitur ini.",
        )
    return current_user



async def get_user_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for UserService."""
    from app.services.user import UserService

    return UserService(db)


async def get_diary_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for DiaryService."""
    from app.services.diary import DiaryService

    return DiaryService(db)


async def get_recommendation_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for RecommendationService."""
    from app.services.recommendation import RecommendationService

    return RecommendationService(db)


async def get_dass_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for DASSService."""
    from app.services.dass import DASSService

    return DASSService(db)


async def get_analytics_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for AnalyticsService."""
    from app.services.analytics import AnalyticsService

    return AnalyticsService(db)


async def get_conversation_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for ConversationService."""
    from app.services.conversation import ConversationService

    return ConversationService(db)


async def get_summary_stream_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for SummaryStreamService."""
    from app.services.conversation import SummaryStreamService

    return SummaryStreamService(db)


async def get_counselor_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for CounselorService."""
    from app.services.counselor import CounselorService

    return CounselorService(db)


async def get_pricing_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for PricingService."""
    from app.services.pricing import PricingService

    return PricingService(db)


async def get_scheduling_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for SchedulingService."""
    from app.services.session import SchedulingService

    return SchedulingService(db)


_webrtc_signaling_manager = None


def get_ice_provider():
    """Dependency factory for IceServerProvider."""
    from app.services.care import IceServerProvider

    return IceServerProvider()


def get_webrtc_signaling_manager():
    """Worker-scoped dependency factory for WebRtcSignalingManager."""
    global _webrtc_signaling_manager
    from app.services.care import WebRtcSignalingManager

    if _webrtc_signaling_manager is None:
        redis_client: Redis = from_url(settings.REDIS_URL, decode_responses=True)
        _webrtc_signaling_manager = WebRtcSignalingManager(redis_client)
    return _webrtc_signaling_manager


async def shutdown_webrtc_signaling_manager() -> None:
    """Cleanly close worker-scoped WebRtcSignalingManager resources."""
    global _webrtc_signaling_manager
    if _webrtc_signaling_manager is not None:
        await _webrtc_signaling_manager.close()
        _webrtc_signaling_manager = None


async def get_care_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for CareService."""
    from app.services.care import CareService, IceServerProvider

    return CareService(db, ice_provider=IceServerProvider())


async def get_finance_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for FinanceService."""
    from app.services.finances import FinanceService

    return FinanceService(db)


async def get_coin_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for CoinService."""
    from app.services.coin import CoinService

    return CoinService(db)


async def get_content_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for ContentService."""
    from app.services.content import ContentService

    return ContentService(db)


async def get_certificate_service(db: AsyncSession = Depends(get_db_session)):
    """Dependency factory for CertificateService."""
    from app.services.certificate import CertificateService

    return CertificateService(db)







