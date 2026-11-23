from fastapi import APIRouter, Depends

from app.api.dependencies import get_coin_service
from app.schemas.coin import CoinEconomyConfigResponse, CoinPackageResponse
from app.services.coin import CoinService

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
