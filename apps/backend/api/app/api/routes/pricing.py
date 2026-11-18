import uuid

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_current_user, get_pricing_service
from app.models.user import User
from app.schemas.pricing import (
    CreatePricingConfigRequest,
    PricingCalculationResponse,
    PricingConfigResponse,
    UpdatePricingConfigRequest,
)
from app.services.pricing import PricingService

router = APIRouter(prefix="/pricing", tags=["Pricing"])


@router.get("/active", response_model=PricingConfigResponse)
async def get_active_pricing_config(
    service: PricingService = Depends(get_pricing_service),
) -> PricingConfigResponse:
    """Get currently active platform pricing and revenue share policy."""
    config = await service.get_active_pricing()
    return service._to_response(config)


@router.get("/calculate", response_model=PricingCalculationResponse)
async def calculate_session_pricing(
    config_id: uuid.UUID | None = Query(default=None),
    service: PricingService = Depends(get_pricing_service),
) -> PricingCalculationResponse:
    """Calculate financial breakdown (patient price, counselor share, platform fee) for 30 minutes."""
    return await service.calculate_pricing(config_id=config_id)


@router.post("", response_model=PricingConfigResponse, status_code=status.HTTP_201_CREATED)
async def create_platform_pricing(
    payload: CreatePricingConfigRequest,
    admin: User = Depends(get_current_user),
    service: PricingService = Depends(get_pricing_service),
) -> PricingConfigResponse:
    """Publish a new platform pricing policy and archive previous active policy (Admin)."""
    return await service.create_pricing_config(payload)


@router.put("/{config_id}", response_model=PricingConfigResponse)
async def update_platform_pricing(
    config_id: uuid.UUID,
    payload: UpdatePricingConfigRequest,
    admin: User = Depends(get_current_user),
    service: PricingService = Depends(get_pricing_service),
) -> PricingConfigResponse:
    """Update existing platform pricing configuration (Admin)."""
    return await service.update_pricing_config(config_id, payload)


@router.get("", response_model=list[PricingConfigResponse])
async def list_pricing_configs(
    admin: User = Depends(get_current_user),
    service: PricingService = Depends(get_pricing_service),
) -> list[PricingConfigResponse]:
    """List historical and active platform pricing configurations (Admin audit)."""
    return await service.list_pricing_configs()
