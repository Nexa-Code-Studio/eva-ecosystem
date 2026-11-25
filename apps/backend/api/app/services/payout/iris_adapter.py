import base64
from datetime import UTC, datetime
import hashlib
import hmac
import logging
from typing import Any

import httpx

from app.services.payment.midtrans_adapter import parse_idr_amount, parse_midtrans_timestamp
from app.services.payout.port import (
    BankValidationResult,
    BasePayoutGatewayPort,
    BeneficiaryBankItem,
    PayoutCreateResult,
    PayoutGatewayError,
    PayoutStatusResult,
)
from shared.config import settings

logger = logging.getLogger(__name__)


DEFAULT_SUPPORTED_BANKS: tuple[BeneficiaryBankItem, ...] = (
    BeneficiaryBankItem(code="bca", name="Bank Central Asia (BCA)"),
    BeneficiaryBankItem(code="bni", name="Bank Negara Indonesia (BNI)"),
    BeneficiaryBankItem(code="bri", name="Bank Rakyat Indonesia (BRI)"),
    BeneficiaryBankItem(code="mandiri", name="Bank Mandiri"),
    BeneficiaryBankItem(code="cimb", name="CIMB Niaga"),
    BeneficiaryBankItem(code="permata", name="Bank Permata"),
    BeneficiaryBankItem(code="bsi", name="Bank Syariah Indonesia (BSI)"),
    BeneficiaryBankItem(code="danamon", name="Bank Danamon"),
    BeneficiaryBankItem(code="seabank", name="SeaBank Indonesia"),
    BeneficiaryBankItem(code="jago", name="Bank Jago"),
)


def _basic_auth_header(api_key: str) -> str:
    encoded = base64.b64encode(f"{api_key}:".encode("utf-8")).decode("ascii")
    return f"Basic {encoded}"


class IrisPayoutAdapter(BasePayoutGatewayPort):
    """Midtrans Iris disbursement and bank-account inquiry adapter."""

    def __init__(
        self,
        *,
        creator_key: str | None = None,
        approver_key: str | None = None,
        notification_secret: str | None = None,
        base_url: str | None = None,
        is_production: bool | None = None,
        timeout_seconds: float = 15.0,
    ) -> None:
        self._creator_key = (
            creator_key if creator_key is not None else settings.MIDTRANS_IRIS_CREATOR_KEY
        ).strip()
        self._approver_key = (
            approver_key if approver_key is not None else settings.MIDTRANS_IRIS_APPROVER_KEY
        ).strip()
        self._notification_secret = (
            notification_secret
            if notification_secret is not None
            else settings.MIDTRANS_IRIS_NOTIFICATION_SECRET
        ).strip()
        prod = settings.MIDTRANS_IS_PRODUCTION if is_production is None else is_production
        configured_base = (base_url if base_url is not None else settings.MIDTRANS_IRIS_BASE_URL).strip()
        if configured_base:
            self._base_url = configured_base.rstrip("/")
        elif prod:
            self._base_url = "https://app.midtrans.com/iris/api/v1"
        else:
            self._base_url = "https://app.sandbox.midtrans.com/iris/api/v1"
        self._timeout = timeout_seconds

    def _creator_headers(self) -> dict[str, str]:
        if not self._creator_key:
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Kredensial Creator Midtrans Iris belum dikonfigurasi.",
                retryable=False,
            )
        return {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": _basic_auth_header(self._creator_key),
        }

    def _approver_headers(self) -> dict[str, str]:
        if not self._approver_key:
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Kredensial Approver Midtrans Iris belum dikonfigurasi.",
                retryable=False,
            )
        return {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": _basic_auth_header(self._approver_key),
        }

    async def list_beneficiary_banks(self) -> list[BeneficiaryBankItem]:
        if not self._creator_key:
            return list(DEFAULT_SUPPORTED_BANKS)
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                resp = await client.get(
                    f"{self._base_url}/beneficiary_banks",
                    headers=self._creator_headers(),
                )
            if resp.status_code != 200:
                logger.warning("Iris list_beneficiary_banks returned %s", resp.status_code)
                return list(DEFAULT_SUPPORTED_BANKS)
            data = resp.json()
            banks = data.get("beneficiary_banks") or []
            parsed = [
                BeneficiaryBankItem(
                    code=str(item.get("code", "")).strip().lower(),
                    name=str(item.get("name", "")).strip(),
                )
                for item in banks
                if item.get("code") and item.get("name")
            ]
            return parsed or list(DEFAULT_SUPPORTED_BANKS)
        except Exception:
            logger.warning("Failed fetching Iris beneficiary_banks, using catalog fallback", exc_info=True)
            return list(DEFAULT_SUPPORTED_BANKS)

    async def validate_bank_account(
        self,
        *,
        bank_code: str,
        account_number: str,
    ) -> BankValidationResult:
        headers = self._creator_headers()
        normalized_bank = bank_code.strip().lower()
        normalized_account = "".join(ch for ch in account_number.strip() if not ch.isspace())
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                resp = await client.get(
                    f"{self._base_url}/account_validation",
                    params={"bank": normalized_bank, "account": normalized_account},
                    headers=headers,
                )
        except httpx.TimeoutException as exc:
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Validasi rekening ke layanan bank sedang timeout. Silakan coba lagi.",
                retryable=True,
            ) from exc
        except httpx.HTTPError as exc:
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Tidak dapat menghubungi layanan validasi rekening bank.",
                retryable=True,
            ) from exc

        payload: dict[str, Any] = {}
        try:
            payload = resp.json()
        except Exception:
            payload = {}

        if resp.status_code in (400, 404):
            err_msg = str(payload.get("error_message") or payload.get("errors") or "")
            if "not found" in err_msg.lower() or resp.status_code == 404:
                return BankValidationResult(
                    bank_code=normalized_bank,
                    bank_name=str(payload.get("bank_name") or normalized_bank.upper()),
                    account_holder_name="",
                    status="not_found",
                    raw_payload={"status_code": resp.status_code},
                )
            raise PayoutGatewayError(
                "BANK_NOT_SUPPORTED",
                "Bank atau format nomor rekening tidak didukung oleh layanan pencairan.",
                retryable=False,
            )

        if resp.status_code >= 500 or resp.status_code in (401, 403, 429):
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Layanan validasi bank sedang tidak tersedia. Silakan coba beberapa saat lagi.",
                retryable=True,
            )

        holder_name = str(payload.get("account_name") or "").strip()
        if not holder_name:
            return BankValidationResult(
                bank_code=normalized_bank,
                bank_name=str(payload.get("bank_name") or normalized_bank.upper()),
                account_holder_name="",
                status="not_found",
                raw_payload={"status_code": resp.status_code},
            )

        return BankValidationResult(
            bank_code=normalized_bank,
            bank_name=str(payload.get("bank_name") or normalized_bank.upper()),
            account_holder_name=holder_name,
            status="valid",
            raw_payload={"account_name": holder_name, "bank_name": payload.get("bank_name")},
        )

    async def get_aggregator_balance_idr(self) -> int | None:
        if not self._creator_key:
            return None
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                resp = await client.get(
                    f"{self._base_url}/balance",
                    headers=self._creator_headers(),
                )
            if resp.status_code != 200:
                return None
            return parse_idr_amount(resp.json().get("balance"))
        except Exception:
            logger.warning("Failed fetching Iris aggregator balance", exc_info=True)
            return None

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
        headers = self._creator_headers()
        body = {
            "payouts": [
                {
                    "beneficiary_name": beneficiary_name,
                    "beneficiary_account": beneficiary_account,
                    "beneficiary_bank": beneficiary_bank.lower(),
                    "beneficiary_email": beneficiary_email or "counselor@eva.id",
                    "amount": str(amount_idr),
                    "notes": notes[:255],
                }
            ]
        }
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                resp = await client.post(
                    f"{self._base_url}/payouts",
                    json=body,
                    headers=headers,
                )
        except httpx.TimeoutException as exc:
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Permintaan pencairan ke Iris timeout. Status akan direkonsiliasi.",
                retryable=True,
            ) from exc
        except httpx.HTTPError as exc:
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Layanan pencairan Iris tidak dapat dijangkau.",
                retryable=True,
            ) from exc

        payload = resp.json() if resp.content else {}
        if resp.status_code not in (200, 201):
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                f"Permintaan payout gagal diproses penyedia ({resp.status_code}).",
                retryable=resp.status_code >= 500 or resp.status_code == 429,
            )

        payouts = payload.get("payouts") or []
        if not payouts:
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Respon Iris tidak memuat detail payout.",
                retryable=True,
            )
        item = payouts[0]
        return PayoutCreateResult(
            reference_no=str(item.get("reference_no") or reference_id),
            status=str(item.get("status") or "queued").lower(),
            raw_payload=item,
        )

    async def approve_payouts(
        self,
        *,
        reference_nos: list[str],
        otp: str | None = None,
    ) -> list[PayoutCreateResult]:
        headers = self._approver_headers()
        body: dict[str, Any] = {"reference_nos": reference_nos}
        if otp:
            body["otp"] = otp
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                resp = await client.post(
                    f"{self._base_url}/payouts/approve",
                    json=body,
                    headers=headers,
                )
        except httpx.HTTPError as exc:
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Gagal menyetujui payout pada Iris.",
                retryable=True,
            ) from exc

        if resp.status_code not in (200, 201):
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                f"Persetujuan payout Iris gagal ({resp.status_code}).",
                retryable=resp.status_code >= 500,
            )
        data = resp.json() if resp.content else {}
        status_str = str(data.get("status") or "approved").lower()
        return [
            PayoutCreateResult(reference_no=ref, status=status_str, raw_payload=data)
            for ref in reference_nos
        ]

    async def get_payout_status(self, reference_no: str) -> PayoutStatusResult:
        headers = self._creator_headers()
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                resp = await client.get(
                    f"{self._base_url}/payouts/{reference_no}",
                    headers=headers,
                )
        except httpx.HTTPError as exc:
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                "Gagal memeriksa status payout dari Iris.",
                retryable=True,
            ) from exc

        if resp.status_code != 200:
            raise PayoutGatewayError(
                "PROVIDER_UNAVAILABLE",
                f"Status payout Iris gagal diambil ({resp.status_code}).",
                retryable=resp.status_code >= 500,
            )
        data = resp.json()
        return PayoutStatusResult(
            reference_no=str(data.get("reference_no") or reference_no),
            status=str(data.get("status") or "queued").lower(),
            amount_idr=parse_idr_amount(data.get("amount")),
            failure_reason=data.get("error_message") or data.get("errors"),
            updated_at=parse_midtrans_timestamp(data.get("updated_at")) or datetime.now(UTC),
            raw_payload=data,
        )

    def verify_webhook_signature(
        self,
        *,
        raw_body: bytes,
        signature_header: str | None,
    ) -> bool:
        if not self._notification_secret or not signature_header:
            return False
        expected = hashlib.sha512(
            raw_body + self._notification_secret.encode("utf-8")
        ).hexdigest()
        return hmac.compare_digest(expected.lower(), signature_header.strip().lower())
