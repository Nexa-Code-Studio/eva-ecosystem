import uuid

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_coin_service, get_current_admin
from app.models.user import User
from app.schemas.coin import (
    AdminCoinAdjustRequest,
    AdminCoinTopupRequest,
    AdminCoinTopupResultResponse,
    AdminUserSummaryResponse,
    CoinEconomyConfigResponse,
    CoinPackageDeleteResponse,
    CoinPackageResponse,
    CoinTopupTransactionResponse,
    UpdateCoinEconomyConfigRequest,
    UpsertCoinPackageRequest,
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


@router.post("/users/{user_id}/coins/adjust", response_model=AdminCoinTopupResultResponse)
async def adjust_user_coins(
    user_id: uuid.UUID,
    payload: AdminCoinAdjustRequest,
    admin: User = Depends(get_current_admin),
    service: CoinService = Depends(get_coin_service),
) -> AdminCoinTopupResultResponse:
    """Deduct or set a user's EVA Coin balance and record an audit transaction (Admin)."""
    return await service.adjust_user_coins(admin.id, user_id, payload)


@router.get("/coins/packages", response_model=list[CoinPackageResponse])
async def list_admin_coin_packages(
    admin: User = Depends(get_current_admin),
    service: CoinService = Depends(get_coin_service),
) -> list[CoinPackageResponse]:
    """List all EVA Coin top-up packages including inactive entries (Admin)."""
    return await service.list_packages(include_inactive=True)


@router.post("/coins/packages", response_model=CoinPackageResponse, status_code=status.HTTP_201_CREATED)
async def create_coin_package(
    payload: UpsertCoinPackageRequest,
    admin: User = Depends(get_current_admin),
    service: CoinService = Depends(get_coin_service),
) -> CoinPackageResponse:
    """Create a new EVA Coin top-up bundling package (Admin)."""
    return await service.create_package(payload)


@router.put("/coins/packages/{package_id}", response_model=CoinPackageResponse)
async def update_coin_package(
    package_id: uuid.UUID,
    payload: UpsertCoinPackageRequest,
    admin: User = Depends(get_current_admin),
    service: CoinService = Depends(get_coin_service),
) -> CoinPackageResponse:
    """Update an existing EVA Coin top-up bundling package (Admin)."""
    return await service.update_package(package_id, payload)


@router.patch("/coins/packages/{package_id}/toggle", response_model=CoinPackageResponse)
async def toggle_coin_package_active(
    package_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: CoinService = Depends(get_coin_service),
) -> CoinPackageResponse:
    """Toggle active visibility status of an EVA Coin package (Admin)."""
    return await service.toggle_package_active(package_id)


@router.delete("/coins/packages/{package_id}", response_model=CoinPackageDeleteResponse)
async def delete_coin_package(
    package_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: CoinService = Depends(get_coin_service),
) -> CoinPackageDeleteResponse:
    """Delete an EVA Coin package from catalog (Admin)."""
    return await service.delete_package(package_id)


@router.put("/coins/economy", response_model=CoinEconomyConfigResponse)
async def update_coin_economy_config(
    payload: UpdateCoinEconomyConfigRequest,
    admin: User = Depends(get_current_admin),
    service: CoinService = Depends(get_coin_service),
) -> CoinEconomyConfigResponse:
    """Update global EVA Coin base rate and free-trial allocation (Admin)."""
    return await service.update_economy_config(payload)
