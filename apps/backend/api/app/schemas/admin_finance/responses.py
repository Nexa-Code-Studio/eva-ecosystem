from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AdminFinanceSummaryResponse(BaseModel):
    """Real-money financial KPIs strictly separated from admin coin grants."""

    model_config = ConfigDict(populate_by_name=True)

    currency: str = "IDR"
    from_at: datetime = Field(..., serialization_alias="from")
    to_at: datetime = Field(..., serialization_alias="to")
    money_in_paid_idr: int
    money_in_pending_idr: int
    money_out_completed_idr: int
    money_out_pending_idr: int
    refund_completed_idr: int
    provider_fees_known_idr: int | None = None
    commission_earned_idr: int
    client_credit_liability_idr: int
    counselor_payable_idr: int
    unreconciled_count: int
    provider_payout_available_idr: int | None = None
    provider_balance_as_of: datetime | None = None


class AdminFinanceTransactionEventResponse(BaseModel):
    """Sanitized status transition event for admin audit trail."""

    status: str
    occurred_at: datetime
    source: str
    message: str


class AdminFinanceTransactionItemResponse(BaseModel):
    """Unified admin ledger entry without sensitive provider or bank secrets."""

    id: str
    direction: str
    source: str
    reference_id: str
    provider_reference: str | None = None
    actor_label: str
    amount_idr: int
    fee_idr: int | None = None
    net_amount_idr: int | None = None
    currency: str = "IDR"
    status: str
    reconciliation_status: str
    created_at: datetime
    completed_at: datetime | None = None
    bank_account_masked: str | None = None


class AdminFinanceTransactionDetailResponse(AdminFinanceTransactionItemResponse):
    """Detailed admin ledger record including sanitized timeline events."""

    events: list[AdminFinanceTransactionEventResponse] = Field(default_factory=list)
