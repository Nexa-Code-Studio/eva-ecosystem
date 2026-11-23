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
