from io import BytesIO
import uuid

from fastapi import APIRouter, Depends, Header, Query, Response, status
from fastapi.responses import StreamingResponse

from app.api.dependencies import get_coin_service, get_coin_topup_service, get_current_user
from app.models.user import User
from app.schemas.coin import (
    CoinEconomyConfigResponse,
    CoinPackageResponse,
    CoinTopupOrderResponse,
    CreateCoinTopupRequest,
)
from app.schemas.common import PaginatedResponse
from app.services.coin import CoinService, CoinTopupService

router = APIRouter(prefix="/coins", tags=["Coins"])


@router.get("/packages", response_model=list[CoinPackageResponse])
async def list_public_coin_packages(
    service: CoinService = Depends(get_coin_service),
) -> list[CoinPackageResponse]:
    """List active EVA Coin top-up packages available for users."""
    return await service.list_packages(include_inactive=False)


@router.get("/economy", response_model=CoinEconomyConfigResponse)
async def get_public_coin_economy(
    service: CoinService = Depends(get_coin_service),
) -> CoinEconomyConfigResponse:
    """Get active EVA Coin base rate and new-user free trial coin allowance."""
    return await service.get_economy_config()


@router.post("/topups", response_model=CoinTopupOrderResponse, status_code=status.HTTP_201_CREATED)
async def create_coin_topup(
    payload: CreateCoinTopupRequest,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    user: User = Depends(get_current_user),
    service: CoinTopupService = Depends(get_coin_topup_service),
) -> CoinTopupOrderResponse:
    """Create or replay a QRIS EVA Coin top-up order."""
    order, status_code = await service.create_topup_order(user, payload, idempotency_key)
    response.status_code = status_code
    return order


@router.get("/topups", response_model=PaginatedResponse[CoinTopupOrderResponse])
async def list_coin_topups(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    status_filter: str | None = Query(default=None, alias="status"),
    user: User = Depends(get_current_user),
    service: CoinTopupService = Depends(get_coin_topup_service),
) -> PaginatedResponse[CoinTopupOrderResponse]:
    """List paginated QRIS top-up orders for the authenticated user."""
    return await service.list_topup_orders(user.id, page=page, page_size=page_size, status_filter=status_filter)


@router.get("/topups/{topup_id}", response_model=CoinTopupOrderResponse)
async def get_coin_topup(
    topup_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: CoinTopupService = Depends(get_coin_topup_service),
) -> CoinTopupOrderResponse:
    """Retrieve details of a user's QRIS top-up order."""
    return await service.get_topup_order(user.id, topup_id)


@router.get("/topups/{topup_id}/qr")
async def get_coin_topup_qr(
    topup_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: CoinTopupService = Depends(get_coin_topup_service),
) -> StreamingResponse:
    """Stream QRIS PNG image safely from allowlisted provider host."""
    png_bytes = await service.fetch_qr_png(user.id, topup_id)
    headers = {"Cache-Control": "private, no-store"}
    return StreamingResponse(BytesIO(png_bytes), media_type="image/png", headers=headers)


@router.post("/topups/{topup_id}/refresh", response_model=CoinTopupOrderResponse)
async def refresh_coin_topup(
    topup_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: CoinTopupService = Depends(get_coin_topup_service),
) -> CoinTopupOrderResponse:
    """Synchronize QRIS top-up status on demand with rate-limit protection."""
    return await service.refresh_topup_order(user.id, topup_id)


@router.post("/topups/{topup_id}/simulate-paid", response_model=CoinTopupOrderResponse)
async def simulate_coin_topup_paid(
    topup_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: CoinTopupService = Depends(get_coin_topup_service),
) -> CoinTopupOrderResponse:
    """Sandbox-only endpoint to simulate QRIS settlement for QA testing."""
    return await service.simulate_sandbox_payment(user.id, topup_id)
