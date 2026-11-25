from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from typing import Any


class PayoutGatewayError(Exception):
    """Domain error raised when payout gateway request fails or is unavailable."""

    def __init__(self, code: str, message: str, *, retryable: bool = True) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable


@dataclass(slots=True)
class BeneficiaryBankItem:
    code: str
    name: str


@dataclass(slots=True)
class BankValidationResult:
    bank_code: str
    bank_name: str
    account_holder_name: str
    status: str  # valid | not_found | unavailable
    raw_payload: dict[str, Any]


@dataclass(slots=True)
class PayoutCreateResult:
    reference_no: str
    status: str
    raw_payload: dict[str, Any]


@dataclass(slots=True)
class PayoutStatusResult:
    reference_no: str
    status: str
    amount_idr: int
    failure_reason: str | None
    updated_at: datetime | None
    raw_payload: dict[str, Any]


class BasePayoutGatewayPort(ABC):
    """Provider-agnostic interface for beneficiary bank validation and disbursement."""

    @abstractmethod
    async def list_beneficiary_banks(self) -> list[BeneficiaryBankItem]:
        """Return list of supported Indonesian beneficiary banks."""

    @abstractmethod
    async def validate_bank_account(
        self,
        *,
        bank_code: str,
        account_number: str,
    ) -> BankValidationResult:
        """Validate beneficiary bank account number and retrieve registered holder name."""

    @abstractmethod
    async def get_aggregator_balance_idr(self) -> int | None:
        """Fetch aggregator/payout balance in IDR, or None if unavailable."""

    @abstractmethod
    async def create_payout(
        self,
        *,
        reference_id: str,
        beneficiary_name: str,
        beneficiary_account: str,
        beneficiary_bank: str,
        amount_idr: int,
        notes: str,
        beneficiary_email: str = "",
    ) -> PayoutCreateResult:
        """Create a payout instruction in the disbursement gateway."""

    @abstractmethod
    async def approve_payouts(
        self,
        *,
        reference_nos: list[str],
        otp: str | None = None,
    ) -> list[PayoutCreateResult]:
        """Approve queued payouts using separate approver credentials."""

    @abstractmethod
    async def get_payout_status(self, reference_no: str) -> PayoutStatusResult:
        """Fetch authoritative payout status from the disbursement gateway."""

    @abstractmethod
    def verify_webhook_signature(
        self,
        *,
        raw_body: bytes,
        signature_header: str | None,
    ) -> bool:
        """Verify incoming Iris/disbursement webhook signature in constant time."""
