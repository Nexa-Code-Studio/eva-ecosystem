from pydantic import BaseModel, Field


class AdminCoinTopupRequest(BaseModel):
    coins_granted: int = Field(..., ge=1, le=100000)
    amount_idr: int = Field(default=0, ge=0)
    payment_method: str = Field(..., min_length=2, max_length=50)
    package_name: str = Field(..., min_length=2, max_length=150)
    admin_notes: str | None = Field(default=None, max_length=500)
