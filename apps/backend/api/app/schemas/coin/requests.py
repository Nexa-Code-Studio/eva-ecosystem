from typing import Literal
from pydantic import BaseModel, Field, model_validator


class AdminCoinTopupRequest(BaseModel):
    coins_granted: int = Field(..., ge=1, le=100000)
    amount_idr: int = Field(default=0, ge=0)
    payment_method: str = Field(..., min_length=2, max_length=50)
    package_name: str = Field(..., min_length=2, max_length=150)
    admin_notes: str | None = Field(default=None, max_length=500)


class AdminCoinAdjustRequest(BaseModel):
    mode: Literal["deduct", "set"]
    amount: int = Field(..., ge=0, le=100000)
    admin_notes: str = Field(..., min_length=3, max_length=500)

    @model_validator(mode="after")
    def _validate_adjustment(self) -> "AdminCoinAdjustRequest":
        if self.mode == "deduct" and self.amount < 1:
            raise ValueError("Nominal pengurangan koin minimal 1.")
        if len(self.admin_notes.strip()) < 3:
            raise ValueError("Catatan audit admin minimal 3 karakter.")
        return self


class UpsertCoinPackageRequest(BaseModel):
    code: str = Field(..., min_length=2, max_length=40)
    name: str = Field(..., min_length=2, max_length=150)
    coins: int = Field(..., ge=1, le=100000)
    bonus_coins: int = Field(default=0, ge=0, le=100000)
    price_idr: int = Field(..., ge=1000)
    description: str = Field(default="", max_length=500)
    is_popular: bool = False
    is_active: bool = True


class UpdateCoinEconomyConfigRequest(BaseModel):
    base_price_per_coin_idr: int = Field(..., ge=100)
    free_trial_coins_new_user: int = Field(..., ge=0, le=1000)
