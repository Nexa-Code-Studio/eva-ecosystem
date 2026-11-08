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






