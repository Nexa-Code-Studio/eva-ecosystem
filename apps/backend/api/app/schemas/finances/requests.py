from pydantic import BaseModel, Field


class PayoutRequest(BaseModel):
    """Legacy withdrawal request model (deprecated in favor of quoted /finances/payouts)."""

    amount: int = Field(..., gt=0, description="Amount to withdraw in IDR")
    bank_name: str = Field(default="BCA", min_length=2, max_length=100, description="Target bank name")
    account_number: str = Field(default="1234567890", min_length=4, max_length=50, description="Bank account number")
    account_holder: str = Field(default="", max_length=200, description="Account holder name")
    account_holder_name: str | None = Field(default=None, max_length=200, description="Account holder name alias")


class ValidateBankAccountRequest(BaseModel):
    """Request to inquire and validate a counselor beneficiary bank account."""

    bank_code: str = Field(..., min_length=2, max_length=50, description="Provider bank code, e.g. 'bca'")
    account_number: str = Field(..., min_length=4, max_length=32, description="Beneficiary bank account digits")


class SaveBankAccountRequest(BaseModel):
    """Request to commit a short-lived single-use verified bank account token."""

    validation_id: str = Field(..., min_length=8, max_length=64, description="Validation ID from /validate")
    current_password: str | None = Field(
        default=None,
        max_length=128,
        description="Optional current password for step-up re-authentication when replacing a verified bank account",
    )


class CreatePayoutQuoteRequest(BaseModel):
    """Request to preview withdrawal fee and net disbursement amount."""

    bank_account_id: str = Field(..., min_length=8, max_length=64, description="Verified counselor bank account ID")
    amount_idr: int = Field(..., gt=0, description="Requested payout amount in IDR")


class CreatePayoutRequest(BaseModel):
    """Request to submit an idempotent payout execution from an active quote."""

    quote_id: str = Field(..., min_length=8, max_length=64, description="Server-issued payout quote ID")
