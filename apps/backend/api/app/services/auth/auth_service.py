import logging
import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_access_token,
    decode_refresh_token,
    hash_password,
    verify_password,
)
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

logger = logging.getLogger(__name__)


class AuthService:
    """Service handling user authentication, registration, and token lifecycles."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def check_email(self, email: str) -> EmailCheckResponse:
        """Check if an email is valid and available for registration."""
        clean_email = email.strip().lower()
        if not clean_email or "@" not in clean_email or "." not in clean_email:
            return EmailCheckResponse(
                available=False,
                email=clean_email,
                message="Format email tidak valid",
            )

        query = select(User).where(User.email == clean_email)
        res = await self.db.execute(query)
        existing = res.scalar_one_or_none()

        if existing:
            return EmailCheckResponse(
                available=False,
                email=clean_email,
                message="Email sudah terdaftar",
            )

        return EmailCheckResponse(
            available=True,
            email=clean_email,
            message="Email tersedia",
        )

    async def login(self, payload: LoginRequest) -> TokenResponse:
        """Authenticate user by email and password, returning JWT access & refresh tokens."""
        clean_email = payload.email.strip().lower()
        query = select(User).where(User.email == clean_email)
        res = await self.db.execute(query)
        user = res.scalar_one_or_none()

        if not user or not verify_password(payload.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Email atau kata sandi tidak valid",
            )

        display_name = user.display_name or user.username or "User Eva"
        access_token = create_access_token(user_id=str(user.id), email=user.email, name=display_name)
        refresh_token = create_refresh_token(user_id=str(user.id), email=user.email)

        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            user=UserAuthResponse(
                id=str(user.id),
                name=display_name,
                email=user.email,
            ),
        )

    async def register(self, payload: RegisterRequest) -> TokenResponse:
        """Register a new user, commit to database, and return initial JWT tokens."""
        clean_email = payload.email.strip().lower()
        query = select(User).where(User.email == clean_email)
        res = await self.db.execute(query)
        existing = res.scalar_one_or_none()

        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email sudah terdaftar",
            )

        clean_name = payload.name.strip()
        user = User(
            email=clean_email,
            username=clean_name,
            display_name=clean_name,
            password_hash=hash_password(payload.password),
            is_active=True,
            is_verified=True,
        )
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)

        display_name = user.display_name or clean_name
        access_token = create_access_token(user_id=str(user.id), email=user.email, name=display_name)
        refresh_token = create_refresh_token(user_id=str(user.id), email=user.email)

        logger.info(f"✅ [AUTH] User registered successfully: {clean_email} ({user.id})")

        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            user=UserAuthResponse(
                id=str(user.id),
                name=display_name,
                email=user.email,
            ),
        )

    async def refresh_token(self, payload: RefreshRequest) -> TokenResponse:
        """Issue a new access and refresh token pair using a valid refresh token."""
        decoded = decode_refresh_token(payload.refresh_token)
        if not decoded or "sub" not in decoded:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Refresh token tidak valid atau telah kedaluwarsa",
            )

        try:
            u_uuid = uuid.UUID(decoded["sub"])
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Format user ID token tidak valid",
            )

        query = select(User).where(User.id == u_uuid)
        res = await self.db.execute(query)
        user = res.scalar_one_or_none()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User tidak ditemukan atau tidak aktif",
            )

        display_name = user.display_name or user.username or "User Eva"
        new_access_token = create_access_token(user_id=str(user.id), email=user.email, name=display_name)
        new_refresh_token = create_refresh_token(user_id=str(user.id), email=user.email)

        return TokenResponse(
            access_token=new_access_token,
            refresh_token=new_refresh_token,
            token_type="bearer",
            user=UserAuthResponse(
                id=str(user.id),
                name=display_name,
                email=user.email,
            ),
        )

    async def get_user_from_token(self, token: str) -> User:
        """Decode access token, parse user UUID, and retrieve User model from database."""
        decoded = decode_access_token(token)
        if not decoded or "sub" not in decoded:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token akses tidak valid atau telah kedaluwarsa",
            )

        try:
            user_uuid = uuid.UUID(decoded["sub"])
        except (ValueError, TypeError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Format user ID dalam token tidak valid",
            )

        query = select(User).where(User.id == user_uuid)
        res = await self.db.execute(query)
        user = res.scalar_one_or_none()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Pengguna tidak ditemukan atau telah dinonaktifkan",
            )

        return user

    @staticmethod
    def get_user_profile(user: User) -> UserAuthResponse:
        """Format an authenticated User instance into a UserAuthResponse DTO."""
        return UserAuthResponse(
            id=str(user.id),
            name=user.display_name or user.username or "User Eva",
            email=user.email,
        )

    @staticmethod
    def logout() -> LogoutResponse:
        """Return successful logout acknowledgment."""
        return LogoutResponse()
