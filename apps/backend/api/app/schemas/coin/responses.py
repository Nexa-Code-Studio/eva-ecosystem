from datetime import datetime
from pydantic import BaseModel, ConfigDict


class UserCoinBalanceResponse(BaseModel):
    user_id: str
    coin_balance: int


class AdminUserSummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_code: str
    display_name: str
    email: str
    coin_balance: int
    is_active: bool
    created_at: datetime


class CoinTopupTransactionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    invoice_code: str
    user_id: str
    user_code: str
    user_display_name: str
    package_name: str
    transaction_type: str
    coins_delta: int
    balance_after: int
    amount_idr: int
    payment_method: str
    status: str
    admin_notes: str | None = None
    created_at: datetime
    completed_at: datetime | None = None


class AdminCoinTopupResultResponse(BaseModel):
    user: AdminUserSummaryResponse
    transaction: CoinTopupTransactionResponse


class CoinPackageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    code: str
    name: str
    coins: int
    bonus_coins: int
    price_idr: int
    description: str
    is_popular: bool
    is_active: bool
    created_at: datetime
    updated_at: datetime


class CoinEconomyConfigResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    base_price_per_coin_idr: int
    free_trial_coins_new_user: int
    updated_at: datetime


class CoinPackageDeleteResponse(BaseModel):
    message: str
    deleted_id: str
