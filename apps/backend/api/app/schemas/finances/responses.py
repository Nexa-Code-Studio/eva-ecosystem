from datetime import datetime

from pydantic import BaseModel, ConfigDict


class FinancialSummaryResponse(BaseModel):
    """Summary of counselor finances."""

    model_config = ConfigDict(from_attributes=True)

    available_balance: int
    pending_clearing_balance: int
    locked_withdrawal_balance: int = 0
    total_earnings_this_month: int
    total_withdrawn: int
    currency: str = "IDR"


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
    transaction_type: str | None = None
    payout_status: str | None = None
    reference_id: str | None = None


class PayoutResponse(BaseModel):
    """Legacy response model kept for OpenAPI schema compatibility."""

    success: bool
    transaction_id: str
    message: str


class SupportedBankResponse(BaseModel):
    """Supported beneficiary bank item."""

    code: str
    name: str


class SupportedBankListResponse(BaseModel):
    """List envelope of supported beneficiary banks."""

    items: list[SupportedBankResponse]


class BankValidationResponse(BaseModel):
    """Short-lived provider bank inquiry validation result."""

    validation_id: str
    bank_code: str
    bank_name: str
    account_number_masked: str
    account_holder_name: str
    status: str
    name_match: str
    expires_at: datetime


class BankAccountResponse(BaseModel):
    """Serialized masked counselor bank account record."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    bank_code: str
    bank_name: str
    account_number_masked: str
    account_holder_name: str
    verification_status: str
    verified_at: datetime | None = None
    account_revision: int = 1
    is_active: bool = True


class CurrentBankAccountResponse(BaseModel):
    """Envelope holding current active counselor bank account or null."""

    bank_account: BankAccountResponse | None = None


class PayoutPolicyResponse(BaseModel):
    """Server-authoritative payout limits, fee policy, and feature gate."""

    min_amount_idr: int
    max_amount_idr: int
    fee_idr: int
    fee_bearer: str
    daily_limit_idr: int
    currency: str = "IDR"
    payout_enabled: bool
    is_payout_enabled: bool


class PayoutQuoteResponse(BaseModel):
    """Server-computed fee and net disbursement quote."""

    quote_id: str
    bank_account_id: str
    amount_idr: int
    fee_idr: int
    fee_bearer: str
    net_amount_idr: int
    wallet_debit_idr: int
    expires_at: datetime
    currency: str = "IDR"


class PayoutRecordResponse(BaseModel):
    """Complete payout record with masked destination account snapshot."""

    id: str
    reference_id: str
    status: str
    amount_idr: int
    fee_idr: int
    fee_bearer: str
    net_amount_idr: int
    wallet_debit_idr: int
    currency: str = "IDR"
    bank_account: BankAccountResponse | None = None
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None = None
    failure_code: str | None = None
    failure_message: str | None = None


class IrisWebhookAckResponse(BaseModel):
    """Acknowledgement returned to Midtrans Iris payout webhook caller."""

    ok: bool
    status: str
    reference_no: str | None = None
