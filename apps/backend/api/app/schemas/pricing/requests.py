from pydantic import BaseModel, Field


class CreatePricingConfigRequest(BaseModel):
    session_duration_minutes: int = Field(default=30, ge=15, le=120)
    price_per_session: float = Field(..., ge=0)
    counselor_share_percentage: float = Field(..., ge=0, le=100)
    platform_fee_percentage: float = Field(..., ge=0, le=100)
    extension_price_per_session: float = Field(..., ge=0)
    notes: str | None = None


class UpdatePricingConfigRequest(BaseModel):
    price_per_session: float | None = Field(default=None, ge=0)
    counselor_share_percentage: float | None = Field(default=None, ge=0, le=100)
    platform_fee_percentage: float | None = Field(default=None, ge=0, le=100)
    extension_price_per_session: float | None = Field(default=None, ge=0)
    status: str | None = Field(default=None, pattern="^(active|draft|archived)$")
    notes: str | None = None
