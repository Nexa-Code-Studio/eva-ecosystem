from pydantic import BaseModel, ConfigDict


class FinancialSummaryResponse(BaseModel):
    """Summary of counselor finances."""

    model_config = ConfigDict(from_attributes=True)

    available_balance: int
    pending_clearing_balance: int
    total_earnings_this_month: int
    total_withdrawn: int


class TransactionResponse(BaseModel):
    """Detailed transaction record for counselor ledger."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    patient_name: str
    session_type: str
    date: str
    amount: int
    admin_fee: int
    net_earnings: int
    status: str
    bank_account_info: str | None = None


class PayoutResponse(BaseModel):
    """Response returned upon payout request submission."""

    success: bool
    transaction_id: str
    message: str
