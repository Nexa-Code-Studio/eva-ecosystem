from datetime import UTC, datetime, timedelta
import hashlib
import hmac
import uuid

from app.services.payment.port import (
    BasePaymentGatewayPort,
    PaymentGatewayError,
    PaymentRefundResult,
    PaymentStatusResult,
    QrisChargeResult,
)

# 1x1 transparent PNG bytes for isolated tests
_MINIMAL_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00"
    b"\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
)


class MockPaymentGatewayAdapter(BasePaymentGatewayPort):
    """Deterministic in-memory adapter exclusively for isolated unit/integration tests."""

    def __init__(self, *, signature_secret: str = "test-sig-secret") -> None:
        self.signature_secret = signature_secret
        self.orders: dict[str, PaymentStatusResult] = {}
        self.charge_calls = 0
        self.status_calls = 0

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
        self.charge_calls += 1
        tx_id = f"mock-tx-{uuid.uuid4().hex[:12]}"
        qr_url = f"https://api.sandbox.midtrans.com/v2/qris/{tx_id}/qr-code"
        expires_at = datetime.now(UTC) + timedelta(minutes=15)
        self.orders[order_id] = PaymentStatusResult(
            order_id=order_id,
            provider_transaction_id=tx_id,
            transaction_status="pending",
            fraud_status="accept",
            payment_type="qris",
            gross_amount_idr=amount_idr,
            currency="IDR",
            status_code="201",
            signature_key=None,
            refund_amount_idr=0,
            settlement_time=None,
            raw_payload={"order_id": order_id, "transaction_id": tx_id},
        )
        return QrisChargeResult(
            provider_transaction_id=tx_id,
            order_id=order_id,
            transaction_status="pending",
            qr_image_url=qr_url,
            qr_image_v2_url=qr_url,
            expires_at=expires_at,
            raw_status_code="201",
        )

    async def get_transaction_status(self, order_id: str) -> PaymentStatusResult:
        self.status_calls += 1
        if order_id not in self.orders:
            raise PaymentGatewayError("TOPUP_NOT_FOUND", f"Mock order {order_id} not found", retryable=False)
        return self.orders[order_id]

    async def refund_transaction(
        self,
        *,
        order_id: str,
        refund_key: str,
        amount_idr: int,
        reason: str,
    ) -> PaymentRefundResult:
        return PaymentRefundResult(
            order_id=order_id,
            refund_key=refund_key,
            refund_chargeback_id=f"rf-{uuid.uuid4().hex[:8]}",
            refund_amount_idr=amount_idr,
            transaction_status="refund",
        )

    def sign(self, order_id: str, status_code: str, gross_amount: str) -> str:
        raw = f"{order_id}{status_code}{gross_amount}{self.signature_secret}".encode("utf-8")
        return hashlib.sha512(raw).hexdigest()

    def verify_notification_signature(
        self,
        *,
        order_id: str,
        status_code: str,
        gross_amount: str,
        signature_key: str,
    ) -> bool:
        expected = self.sign(order_id, status_code, gross_amount)
        return hmac.compare_digest(expected.lower(), (signature_key or "").strip().lower())

    async def fetch_qr_image_bytes(self, qr_url: str) -> bytes:
        return _MINIMAL_PNG
