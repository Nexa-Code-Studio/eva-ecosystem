import logging

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_auth_service, get_current_user
from app.models.user import User
from app.schemas.auth import (
    EmailCheckResponse,
    LoginRequest,
    LogoutResponse,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserAuthResponse,
)
from app.services.auth import AuthService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.get("/check-email", response_model=EmailCheckResponse)
async def check_email(
    email: str = Query(..., description="Email address to check"),
    service: AuthService = Depends(get_auth_service),
) -> EmailCheckResponse:
    """Check if an email address is available for registration."""
    return await service.check_email(email)


@router.post("/login", response_model=TokenResponse)
async def login(
    payload: LoginRequest,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    """Authenticate user and issue JWT access & refresh tokens."""
    return await service.login(payload)


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: RegisterRequest,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    """Register a new user account and return initial tokens."""
    return await service.register(payload)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    payload: RefreshRequest,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    """Refresh an expired access token using a valid refresh token."""
    return await service.refresh_token(payload)


@router.get("/me", response_model=UserAuthResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> UserAuthResponse:
    """Get the currently authenticated user's profile."""
    return service.get_user_profile(current_user)


@router.post("/logout", response_model=LogoutResponse)
async def logout(
    service: AuthService = Depends(get_auth_service),
) -> LogoutResponse:
    """Acknowledge user logout."""
    return service.logout()
