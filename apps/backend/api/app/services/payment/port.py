from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from typing import Any


class PaymentGatewayError(Exception):
    """Domain error raised when payment gateway request fails or is unavailable."""

    def __init__(self, code: str, message: str, *, retryable: bool = True) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable


@dataclass(slots=True)
class QrisChargeResult:
    provider_transaction_id: str
    order_id: str
    transaction_status: str
    qr_image_url: str
    qr_image_v2_url: str | None
    expires_at: datetime | None
    raw_status_code: str


@dataclass(slots=True)
class PaymentStatusResult:
    order_id: str
    provider_transaction_id: str | None
    transaction_status: str
    fraud_status: str | None
    payment_type: str | None
    gross_amount_idr: int
    currency: str
    status_code: str
    signature_key: str | None
    refund_amount_idr: int
    settlement_time: datetime | None
    raw_payload: dict[str, Any]


@dataclass(slots=True)
class PaymentRefundResult:
    order_id: str
    refund_key: str
    refund_chargeback_id: str | None
    refund_amount_idr: int
    transaction_status: str


class BasePaymentGatewayPort(ABC):
    """Provider-agnostic interface for QRIS charge, status inquiry, refund, and signature check."""

    @abstractmethod
    async def create_qris_charge(
        self,
        *,
        order_id: str,
        amount_idr: int,
        item_id: str,
        item_name: str,
        customer_name: str,
        customer_email: str,
    ) -> QrisChargeResult:
        """Create a dynamic QRIS charge at the payment gateway."""

    @abstractmethod
    async def get_transaction_status(self, order_id: str) -> PaymentStatusResult:
        """Fetch authoritative transaction status from the payment gateway."""

    @abstractmethod
    async def refund_transaction(
        self,
        *,
        order_id: str,
        refund_key: str,
        amount_idr: int,
        reason: str,
    ) -> PaymentRefundResult:
        """Request a full or partial refund for a settled transaction."""

    @abstractmethod
    def verify_notification_signature(
        self,
        *,
        order_id: str,
        status_code: str,
        gross_amount: str,
        signature_key: str,
    ) -> bool:
        """Verify provider webhook notification signature in constant time."""

    @abstractmethod
    async def fetch_qr_image_bytes(self, qr_url: str) -> bytes:
        """Fetch PNG bytes from an allowlisted provider QR URL."""
