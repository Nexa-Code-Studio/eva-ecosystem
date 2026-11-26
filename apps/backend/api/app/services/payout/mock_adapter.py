from dataclasses import dataclass, field
from datetime import UTC, datetime
import hashlib
import hmac
import uuid

from app.services.payout.iris_adapter import DEFAULT_SUPPORTED_BANKS
from app.services.payout.port import (
    BankValidationResult,
    BasePayoutGatewayPort,
    BeneficiaryBankItem,
    PayoutCreateResult,
    PayoutGatewayError,
    PayoutStatusResult,
)


@dataclass(slots=True)
class _MockPayoutRecord:
    reference_no: str
    status: str
    amount_idr: int
    failure_reason: str | None = None
    updated_at: datetime = field(default_factory=lambda: datetime.now(UTC))


class MockPayoutGatewayAdapter(BasePayoutGatewayPort):
    """Deterministic in-memory payout gateway adapter for isolated unit & integration tests."""

    def __init__(self, *, webhook_secret: str = "test-iris-secret") -> None:
        self.webhook_secret = webhook_secret
        self.banks = list(DEFAULT_SUPPORTED_BANKS)
        self.aggregator_balance_idr: int | None = 50_000_000
        self.records: dict[str, _MockPayoutRecord] = {}
        self.registered_accounts: dict[tuple[str, str], str] = {}
        self.force_validate_unavailable: bool = False
        self.force_create_unavailable: bool = False

    async def list_beneficiary_banks(self) -> list[BeneficiaryBankItem]:
        return list(self.banks)

    async def validate_bank_account(
        self,
        *,
        bank_code: str,
        account_number: str,
    ) -> BankValidationResult:
        if self.force_validate_unavailable:
            raise PayoutGatewayError("PROVIDER_UNAVAILABLE", "Mock bank validator unavailable")

        code = bank_code.strip().lower()
        number = "".join(ch for ch in account_number.strip() if not ch.isspace())
        supported = {b.code: b.name for b in self.banks}
        if code not in supported:
            raise PayoutGatewayError("BANK_NOT_SUPPORTED", f"Bank {code} tidak didukung", retryable=False)

        if number in ("0000000000", "9999999999"):
            return BankValidationResult(
                bank_code=code,
                bank_name=supported[code],
                account_holder_name="",
                status="not_found",
                raw_payload={"mock": True, "status": "not_found"},
            )

        holder_name = self.registered_accounts.get((code, number), "Dr. Budi Santoso, M.Psi")
        return BankValidationResult(
            bank_code=code,
            bank_name=supported[code],
            account_holder_name=holder_name,
            status="valid",
            raw_payload={"mock": True, "account_name": holder_name},
        )

    async def get_aggregator_balance_idr(self) -> int | None:
        return self.aggregator_balance_idr

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
        if self.force_create_unavailable:
            raise PayoutGatewayError("PROVIDER_UNAVAILABLE", "Mock payout gateway unavailable")
        ref_no = f"iris-{uuid.uuid4().hex[:12]}"
        self.records[ref_no] = _MockPayoutRecord(
            reference_no=ref_no,
            status="queued",
            amount_idr=amount_idr,
        )
        return PayoutCreateResult(
            reference_no=ref_no,
            status="queued",
            raw_payload={"reference_no": ref_no, "status": "queued", "notes": notes},
        )

    async def approve_payouts(
        self,
        *,
        reference_nos: list[str],
        otp: str | None = None,
    ) -> list[PayoutCreateResult]:
        results: list[PayoutCreateResult] = []
        for ref in reference_nos:
            if ref in self.records:
                self.records[ref].status = "processed"
                self.records[ref].updated_at = datetime.now(UTC)
            results.append(
                PayoutCreateResult(
                    reference_no=ref,
                    status="processed",
                    raw_payload={"reference_no": ref, "status": "processed"},
                )
            )
        return results

    async def get_payout_status(self, reference_no: str) -> PayoutStatusResult:
        rec = self.records.get(reference_no)
        if not rec:
            raise PayoutGatewayError("PROVIDER_UNAVAILABLE", "Mock payout reference not found")
        return PayoutStatusResult(
            reference_no=rec.reference_no,
            status=rec.status,
            amount_idr=rec.amount_idr,
            failure_reason=rec.failure_reason,
            updated_at=rec.updated_at,
            raw_payload={"reference_no": rec.reference_no, "status": rec.status},
        )

    def verify_webhook_signature(
        self,
        *,
        raw_body: bytes,
        signature_header: str | None,
    ) -> bool:
        if not signature_header:
            return False
        expected = hashlib.sha512(
            raw_body + self.webhook_secret.encode("utf-8")
        ).hexdigest()
        return hmac.compare_digest(expected.lower(), signature_header.strip().lower())
