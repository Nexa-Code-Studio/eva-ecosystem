from pydantic import BaseModel, Field, model_validator


class UpsertPsychologistLevelRequest(BaseModel):
    level_tier: int = Field(..., ge=1, le=99)
    name: str = Field(..., min_length=2, max_length=120)
    badge_icon: str = Field(default="award", min_length=2, max_length=60)
    min_completed_sessions: int = Field(default=0, ge=0, le=100000)
    min_average_rating: float = Field(default=0.0, ge=0.0, le=5.0)
    min_consultation_hours: float = Field(default=0.0, ge=0.0, le=100000.0)
    min_review_count: int = Field(default=0, ge=0, le=100000)
    default_session_price: float = Field(..., ge=0.0, le=1000000.0)
    platform_fee_percentage: float = Field(..., ge=0.0, le=100.0)
    allow_custom_price: bool = False
    min_custom_price: float | None = Field(default=None, ge=0.0, le=1000000.0)
    max_custom_price: float | None = Field(default=None, ge=0.0, le=1000000.0)
    is_active: bool = True

    @model_validator(mode="after")
    def validate_custom_price_bounds(self) -> "UpsertPsychologistLevelRequest":
        if self.allow_custom_price:
            if self.min_custom_price is None or self.max_custom_price is None:
                raise ValueError(
                    "min_custom_price dan max_custom_price wajib diisi jika allow_custom_price aktif."
                )
            if self.min_custom_price > self.max_custom_price:
                raise ValueError("min_custom_price tidak boleh melebihi max_custom_price.")
            if not (self.min_custom_price <= self.default_session_price <= self.max_custom_price):
                raise ValueError(
                    "default_session_price harus berada di antara min_custom_price dan max_custom_price."
                )
        return self


class UpdateCounselorCustomPricingRequest(BaseModel):
    custom_price_per_session: float | None = Field(default=None, ge=0.0, le=1000000.0)


class CreateSessionReviewRequest(BaseModel):
    rating: float = Field(..., ge=1.0, le=5.0)
    review_text: str | None = Field(default=None, max_length=2000)
    highlight_label: str | None = Field(default=None, max_length=120)
    is_anonymous: bool = False
