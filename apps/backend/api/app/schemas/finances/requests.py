from pydantic import BaseModel, Field


class PayoutRequest(BaseModel):
    """Payload for submitting counselor payout / withdrawal request."""

    amount: int = Field(..., gt=0, description="Amount to withdraw in IDR")
    bank_name: str = Field(default="BCA", min_length=2, max_length=100, description="Target bank name")
    account_number: str = Field(default="1234567890", min_length=4, max_length=50, description="Bank account number")
    account_holder: str = Field(default="", max_length=200, description="Account holder name")
    account_holder_name: str | None = Field(default=None, max_length=200, description="Account holder name alias")
