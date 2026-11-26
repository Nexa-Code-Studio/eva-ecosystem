import base64
from datetime import UTC, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
import hashlib
import hmac
import logging
from typing import Any
from urllib.parse import urlparse

import httpx

from app.services.payment.port import (
    BasePaymentGatewayPort,
    PaymentGatewayError,
    PaymentRefundResult,
    PaymentStatusResult,
    QrisChargeResult,
)
from shared.config import settings

logger = logging.getLogger(__name__)

ALLOWED_QR_HOSTS: frozenset[str] = frozenset(
    {
        "api.sandbox.midtrans.com",
        "api.midtrans.com",
        "merchants-app.sbx.midtrans.com",
        "merchants-app.midtrans.com",
    }
)

WIB_TZ = timezone(timedelta(hours=7))


def parse_midtrans_timestamp(raw: str | None) -> datetime | None:
    """Parse Midtrans 'YYYY-MM-DD HH:MM:SS' (WIB +07:00) or ISO-8601 timestamp into UTC datetime."""
    if not raw or not str(raw).strip():
        return None
    text = str(raw).strip()
    try:
        dt = datetime.fromisoformat(text.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=WIB_TZ)
        return dt.astimezone(UTC)
    except ValueError:
        pass
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"):
        try:
            dt = datetime.strptime(text, fmt).replace(tzinfo=WIB_TZ)
            return dt.astimezone(UTC)
        except ValueError:
            continue
    return None


def parse_idr_amount(raw: Any) -> int:
    """Convert Midtrans gross_amount ('45000.00' or 45000) cleanly to integer IDR."""
    if raw is None:
        return 0
    try:
        return int(Decimal(str(raw).strip()))
    except (InvalidOperation, ValueError):
        return 0


def validate_qr_url(qr_url: str) -> str:
    """Validate that a QR URL uses HTTPS and points strictly to an allowlisted Midtrans host."""
    parsed = urlparse((qr_url or "").strip())
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_QR_HOSTS or parsed.port not in (None, 443):
        raise PaymentGatewayError(
            "INVALID_QR_HOST",
            "URL QR pembayaran tidak berasal dari host provider yang diizinkan.",
            retryable=False,
        )
    return parsed.geturl()


class MidtransCoreApiAdapter(BasePaymentGatewayPort):
    """Midtrans Core API v2 adapter for dynamic QRIS charge, status inquiry, refund, and QR proxy."""

    def __init__(
        self,
        *,
        config: Any = None,
        http_client: httpx.AsyncClient | None = None,
        timeout_seconds: float = 12.0,
    ) -> None:
        self._settings = config or settings
        self._http_client = http_client
        self._timeout_seconds = timeout_seconds

    @property
    def base_url(self) -> str:
        is_prod = bool(getattr(self._settings, "MIDTRANS_IS_PRODUCTION", False))
        return "https://api.midtrans.com" if is_prod else "https://api.sandbox.midtrans.com"

    def _require_enabled_server_key(self) -> str:
        if not bool(getattr(self._settings, "MIDTRANS_PAYMENT_ENABLED", False)):
            raise PaymentGatewayError(
                "PAYMENT_DISABLED",
                "Pembayaran QRIS saat ini sedang dinonaktifkan.",
                retryable=False,
            )
        server_key = str(getattr(self._settings, "MIDTRANS_SERVER_KEY", "") or "").strip()
        if not server_key:
            raise PaymentGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Konfigurasi gateway pembayaran belum lengkap.",
                retryable=False,
            )
        return server_key

    def _auth_headers(self) -> dict[str, str]:
        server_key = self._require_enabled_server_key()
        encoded = base64.b64encode(f"{server_key}:".encode()).decode()
        return {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": f"Basic {encoded}",
        }

    async def _request(
        self,
        method: str,
        path: str,
        *,
        json_body: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        url = f"{self.base_url}{path}"
        headers = self._auth_headers()
        try:
            if self._http_client is not None:
                resp = await self._http_client.request(
                    method, url, headers=headers, json=json_body, timeout=self._timeout_seconds
                )
            else:
                async with httpx.AsyncClient(timeout=self._timeout_seconds, follow_redirects=False) as client:
                    resp = await client.request(method, url, headers=headers, json=json_body)
        except httpx.TimeoutException as exc:
            raise PaymentGatewayError(
                "PROVIDER_TIMEOUT",
                "Koneksi ke gateway pembayaran timeout.",
                retryable=True,
            ) from exc
        except httpx.HTTPError as exc:
            raise PaymentGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Gateway pembayaran sedang tidak dapat dijangkau.",
                retryable=True,
            ) from exc

        if resp.status_code >= 500:
            raise PaymentGatewayError(
                "PROVIDER_UNAVAILABLE",
                f"Gateway pembayaran mengembalikan HTTP {resp.status_code}.",
                retryable=True,
            )

        try:
            data = resp.json()
        except ValueError as exc:
            raise PaymentGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Respons gateway pembayaran tidak valid.",
                retryable=True,
            ) from exc

        if resp.status_code >= 400:
            msg = str(data.get("status_message") or "Permintaan pembayaran ditolak provider.")
            raise PaymentGatewayError("PROVIDER_UNAVAILABLE", msg, retryable=False)
        return data

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
        acquirer = str(getattr(self._settings, "MIDTRANS_QRIS_ACQUIRER", "gopay") or "gopay").strip()
        payload = {
            "payment_type": "qris",
            "transaction_details": {
                "order_id": order_id,
                "gross_amount": amount_idr,
            },
            "qris": {"acquirer": acquirer},
            "item_details": [
                {
                    "id": item_id[:50],
                    "price": amount_idr,
                    "quantity": 1,
                    "name": item_name[:50],
                }
            ],
            "customer_details": {
                "first_name": (customer_name or "User Eva")[:50],
                "email": customer_email,
            },
        }
        try:
            data = await self._request("POST", "/v2/charge", json_body=payload)
        except PaymentGatewayError as exc:
            if exc.retryable:
                # Recover ambiguous charge timeout via authoritative status inquiry without double-charging
                status_res = await self._recover_after_charge_timeout(order_id)
                if status_res is not None:
                    return status_res
            raise

        return self._parse_charge_payload(order_id, data)

    async def _recover_after_charge_timeout(self, order_id: str) -> QrisChargeResult | None:
        try:
            status_res = await self.get_transaction_status(order_id)
            raw = status_res.raw_payload
            if raw.get("transaction_id"):
                return self._parse_charge_payload(order_id, raw)
        except PaymentGatewayError:
            return None
        return None

    def _parse_charge_payload(self, order_id: str, data: dict[str, Any]) -> QrisChargeResult:
        status_code = str(data.get("status_code") or "")
        tx_id = str(data.get("transaction_id") or "")
        if not tx_id or status_code not in {"200", "201"}:
            msg = str(data.get("status_message") or "Gagal membuat tagihan QRIS.")
            raise PaymentGatewayError("PROVIDER_UNAVAILABLE", msg, retryable=False)

        qr_v1: str | None = None
        qr_v2: str | None = None
        for action in data.get("actions") or []:
            if not isinstance(action, dict):
                continue
            name = action.get("name")
            url = str(action.get("url") or "").strip()
            if not url:
                continue
            validated = validate_qr_url(url)
            if name == "generate-qr-code-v2":
                qr_v2 = validated
            elif name == "generate-qr-code":
                qr_v1 = validated

        primary_qr = qr_v2 or qr_v1 or validate_qr_url(f"{self.base_url}/v2/qris/{tx_id}/qr-code")
        expires_at = parse_midtrans_timestamp(data.get("expiry_time"))
        if expires_at is None:
            tx_time = parse_midtrans_timestamp(data.get("transaction_time")) or datetime.now(UTC)
            expires_at = tx_time + timedelta(minutes=15)

        return QrisChargeResult(
            provider_transaction_id=tx_id,
            order_id=str(data.get("order_id") or order_id),
            transaction_status=str(data.get("transaction_status") or "pending").lower(),
            qr_image_url=primary_qr,
            qr_image_v2_url=qr_v2,
            expires_at=expires_at,
            raw_status_code=status_code,
        )

    async def get_transaction_status(self, order_id: str) -> PaymentStatusResult:
        data = await self._request("GET", f"/v2/{order_id}/status")
        status_code = str(data.get("status_code") or "")
        if status_code == "404":
            raise PaymentGatewayError("TOPUP_NOT_FOUND", "Transaksi tidak ditemukan di provider.", retryable=False)
        refund_total = 0
        for ref in data.get("refunds") or []:
            if isinstance(ref, dict):
                refund_total += parse_idr_amount(ref.get("refund_amount"))
        if refund_total == 0 and data.get("refund_amount") is not None:
            refund_total = parse_idr_amount(data.get("refund_amount"))

        return PaymentStatusResult(
            order_id=str(data.get("order_id") or order_id),
            provider_transaction_id=data.get("transaction_id"),
            transaction_status=str(data.get("transaction_status") or "pending").lower(),
            fraud_status=str(data.get("fraud_status")).lower() if data.get("fraud_status") else None,
            payment_type=str(data.get("payment_type")).lower() if data.get("payment_type") else None,
            gross_amount_idr=parse_idr_amount(data.get("gross_amount")),
            currency=str(data.get("currency") or "IDR").upper(),
            status_code=status_code,
            signature_key=data.get("signature_key"),
            refund_amount_idr=refund_total,
            settlement_time=parse_midtrans_timestamp(data.get("settlement_time")),
            raw_payload=data,
        )

    async def refund_transaction(
        self,
        *,
        order_id: str,
        refund_key: str,
        amount_idr: int,
        reason: str,
    ) -> PaymentRefundResult:
        payload = {
            "refund_key": refund_key,
            "amount": amount_idr,
            "reason": reason[:200],
        }
        data = await self._request("POST", f"/v2/{order_id}/refund", json_body=payload)
        return PaymentRefundResult(
            order_id=str(data.get("order_id") or order_id),
            refund_key=str(data.get("refund_key") or refund_key),
            refund_chargeback_id=data.get("refund_chargeback_id"),
            refund_amount_idr=parse_idr_amount(data.get("refund_amount") or amount_idr),
            transaction_status=str(data.get("transaction_status") or "refund").lower(),
        )

    def verify_notification_signature(
        self,
        *,
        order_id: str,
        status_code: str,
        gross_amount: str,
        signature_key: str,
    ) -> bool:
        if not signature_key:
            return False
        secret = str(getattr(self._settings, "MIDTRANS_SIGNATURE_SECRET_KEY", "") or "").strip()
        if not secret:
            secret = str(getattr(self._settings, "MIDTRANS_SERVER_KEY", "") or "").strip()
        if not secret:
            return False
        raw = f"{order_id}{status_code}{gross_amount}{secret}".encode("utf-8")
        expected = hashlib.sha512(raw).hexdigest()
        return hmac.compare_digest(expected.lower(), signature_key.strip().lower())

    async def fetch_qr_image_bytes(self, qr_url: str) -> bytes:
        validated_url = validate_qr_url(qr_url)
        try:
            if self._http_client is not None:
                resp = await self._http_client.get(validated_url, timeout=self._timeout_seconds)
            else:
                async with httpx.AsyncClient(timeout=self._timeout_seconds, follow_redirects=False) as client:
                    resp = await client.get(validated_url)
        except httpx.HTTPError as exc:
            raise PaymentGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Gagal mengambil gambar QRIS dari provider.",
                retryable=True,
            ) from exc

        if resp.status_code != 200 or not resp.content:
            raise PaymentGatewayError(
                "PROVIDER_UNAVAILABLE",
                f"Gambar QRIS gagal dimuat (HTTP {resp.status_code}).",
                retryable=True,
            )
        return resp.content
