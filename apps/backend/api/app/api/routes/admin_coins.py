import uuid

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_coin_service, get_current_admin
from app.models.user import User
from app.schemas.coin import (
    AdminCoinTopupRequest,
    AdminCoinTopupResultResponse,
    AdminUserSummaryResponse,
    CoinTopupTransactionResponse,
)
from app.services.coin import CoinService

router = APIRouter(prefix="/admin", tags=["Admin Coins"])


@router.get("/users", response_model=list[AdminUserSummaryResponse])
async def list_admin_users(
    search: str | None = Query(default=None),
    admin: User = Depends(get_current_admin),
    service: CoinService = Depends(get_coin_service),
) -> list[AdminUserSummaryResponse]:
    """List mobile application users and their current EVA Coin balances (Admin)."""
    return await service.list_admin_users(search=search)


@router.get("/coins/transactions", response_model=list[CoinTopupTransactionResponse])
async def list_admin_coin_transactions(
    include_usage: bool = Query(default=False),
    admin: User = Depends(get_current_admin),
    service: CoinService = Depends(get_coin_service),
) -> list[CoinTopupTransactionResponse]:
    """List EVA Coin top-up and grant ledger transactions (Admin)."""
    return await service.list_transactions(include_usage=include_usage)


@router.post("/users/{user_id}/coins/topup", response_model=AdminCoinTopupResultResponse)
async def topup_user_coins(
    user_id: uuid.UUID,
    payload: AdminCoinTopupRequest,
    admin: User = Depends(get_current_admin),
    service: CoinService = Depends(get_coin_service),
) -> AdminCoinTopupResultResponse:
    """Credit EVA Coins to a user's wallet via conventional admin top-up (Admin)."""
    return await service.topup_user_coins(admin.id, user_id, payload)
