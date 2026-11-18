from datetime import datetime
from pydantic import BaseModel, ConfigDict


class PricingConfigResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    session_duration_minutes: int
    price_per_session: float
    counselor_share_percentage: float
    platform_fee_percentage: float
    extension_price_per_session: float
    status: str
    notes: str | None = None
    effective_from: datetime
    effective_until: datetime | None = None
    created_at: datetime


class PricingCalculationResponse(BaseModel):
    session_duration_minutes: int
    total_price: float
    counselor_earning: float
    platform_fee: float
    extension_price: float
