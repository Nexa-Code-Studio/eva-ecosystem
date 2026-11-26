from datetime import UTC, datetime, timedelta
import hashlib
from typing import Any
import uuid

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.crypto import BankEncryptionError, decrypt_bank_account
from app.core.payment_errors import raise_contract_error
from app.models.counselor import CounselorTransaction, PsychologistProfile
from app.models.enums import (
    BankVerificationStatus,
    OutboxEventStatus,
    PayoutStatus,
    ReconciliationStatus,
    TransactionStatus,
    TransactionType,
    WebhookProcessStatus,
)
from app.models.payment import (
    CounselorBankAccount,
    CounselorWithdrawal,
    CounselorWithdrawalEvent,
    PaymentOutboxEvent,
    PaymentWebhookInbox,
    PayoutQuote,
)
from app.models.user import User
from app.schemas.common import PaginatedResponse
from app.schemas.finances import (
    BankAccountResponse,
    CreatePayoutQuoteRequest,
    CreatePayoutRequest,
    IrisWebhookAckResponse,
    PayoutPolicyResponse,
    PayoutQuoteResponse,
    PayoutRecordResponse,
)
from app.services.finances.bank_account_service import serialize_bank_account
from app.services.payout import BasePayoutGatewayPort, PayoutGatewayError
from shared.config import settings

MIN_PAYOUT_AMOUNT_IDR = 50_000
MAX_PAYOUT_AMOUNT_IDR = 10_000_000
DAILY_PAYOUT_LIMIT_IDR = 20_000_000
PAYOUT_FEE_IDR = 5_000
PAYOUT_FEE_BEARER = "counselor"
QUOTE_TTL_MINUTES = 5

_ACTIVE_AND_COMPLETED_PAYOUT_STATUSES = (
    PayoutStatus.REQUESTED.value,
    PayoutStatus.WAITING_APPROVAL.value,
    PayoutStatus.PROCESSING.value,
    PayoutStatus.COMPLETED.value,
    PayoutStatus.REVIEW_REQUIRED.value,
)

_TERMINAL_FAILURE_STATUSES = {
    PayoutStatus.FAILED.value,
    PayoutStatus.REJECTED.value,
    PayoutStatus.CANCELLED.value,
    PayoutStatus.REVERSED.value,
}


def map_iris_status_to_payout_status(raw_status: str) -> str:
    """Normalize Midtrans Iris payout status values to internal PayoutStatus enum."""
    normalized = (raw_status or "").strip().lower()
    mapping = {
        "queued": PayoutStatus.WAITING_APPROVAL.value,
        "approved": PayoutStatus.PROCESSING.value,
        "processed": PayoutStatus.PROCESSING.value,
        "completed": PayoutStatus.COMPLETED.value,
        "failed": PayoutStatus.FAILED.value,
        "rejected": PayoutStatus.REJECTED.value,
        "cancelled": PayoutStatus.CANCELLED.value,
        "reversed": PayoutStatus.REVERSED.value,
    }
    return mapping.get(normalized, PayoutStatus.REVIEW_REQUIRED.value)


def _snapshot_to_bank_response(snapshot: dict[str, Any] | None) -> BankAccountResponse | None:
    if not snapshot:
        return None
    verified_at_raw = snapshot.get("verified_at")
    verified_at = None
    if isinstance(verified_at_raw, str) and verified_at_raw:
        try:
            verified_at = datetime.fromisoformat(verified_at_raw)
        except ValueError:
            verified_at = None
    return BankAccountResponse(
        id=str(snapshot.get("id") or ""),
        bank_code=str(snapshot.get("bank_code") or ""),
        bank_name=str(snapshot.get("bank_name") or ""),
        account_number_masked=str(snapshot.get("account_number_masked") or "****"),
        account_holder_name=str(snapshot.get("account_holder_name") or ""),
        verification_status=str(snapshot.get("verification_status") or BankVerificationStatus.VERIFIED.value),
        verified_at=verified_at,
        account_revision=int(snapshot.get("account_revision") or 1),
        is_active=bool(snapshot.get("is_active", True)),
    )


def serialize_payout_record(withdrawal: CounselorWithdrawal) -> PayoutRecordResponse:
    """Serialize CounselorWithdrawal with its masked bank destination snapshot."""
    bank_resp = _snapshot_to_bank_response(withdrawal.bank_snapshot_json)
    if bank_resp is None and withdrawal.bank_account is not None:
        bank_resp = serialize_bank_account(withdrawal.bank_account)
    return PayoutRecordResponse(
        id=str(withdrawal.id),
        reference_id=withdrawal.reference_id,
        status=withdrawal.status,
        amount_idr=withdrawal.amount_idr,
        fee_idr=withdrawal.fee_idr,
        fee_bearer=withdrawal.fee_bearer,
        net_amount_idr=withdrawal.net_amount_idr,
        wallet_debit_idr=withdrawal.wallet_debit_idr,
        currency=withdrawal.currency,
        bank_account=bank_resp,
        created_at=withdrawal.created_at,
        updated_at=withdrawal.updated_at,
        completed_at=withdrawal.completed_at,
        failure_code=withdrawal.failure_code,
        failure_message=withdrawal.failure_message,
    )


class PayoutService:
    """Handles payout policies, server-computed quotes, locked balance payouts, and Iris webhooks."""

    def __init__(
        self,
        db: AsyncSession,
        gateway: BasePayoutGatewayPort,
        *,
        payout_enabled: bool | None = None,
        auto_approve: bool | None = None,
    ) -> None:
        self.db = db
        self.gateway = gateway
        self._payout_enabled_override = payout_enabled
        self._auto_approve_override = auto_approve

    def is_payout_enabled(self) -> bool:
        """Fail-closed gate checking explicit configuration flag."""
        if self._payout_enabled_override is not None:
            return self._payout_enabled_override
        return bool(settings.MIDTRANS_PAYOUT_ENABLED)

    def _should_auto_approve(self) -> bool:
        if self._auto_approve_override is not None:
            return self._auto_approve_override
        return bool(settings.MIDTRANS_PAYOUT_AUTO_APPROVE and settings.MIDTRANS_IRIS_APPROVER_KEY.strip())

    def get_payout_policy(self) -> PayoutPolicyResponse:
        """Return server-authoritative payout policy and feature gate."""
        enabled = self.is_payout_enabled()
        return PayoutPolicyResponse(
            min_amount_idr=MIN_PAYOUT_AMOUNT_IDR,
            max_amount_idr=MAX_PAYOUT_AMOUNT_IDR,
            fee_idr=PAYOUT_FEE_IDR,
            fee_bearer=PAYOUT_FEE_BEARER,
            daily_limit_idr=DAILY_PAYOUT_LIMIT_IDR,
            currency="IDR",
            payout_enabled=enabled,
            is_payout_enabled=enabled,
        )

    async def create_payout_quote(
        self,
        user_id: uuid.UUID,
        payload: CreatePayoutQuoteRequest,
    ) -> PayoutQuoteResponse:
        """Compute fee & net amount quote without locking counselor wallet balance."""
        if not self.is_payout_enabled():
            raise_contract_error(
                503,
                "PAYOUT_DISABLED",
                "Layanan pencairan honorarium sedang dinonaktifkan sementara.",
            )

        profile = await self._load_counselor_profile(user_id)
        try:
            bank_uuid = uuid.UUID(payload.bank_account_id.strip())
        except ValueError:
            raise_contract_error(400, "BANK_UNVERIFIED", "ID rekening bank tidak valid.")

        bank = await self._load_active_bank_account(profile.id)
        if not bank or bank.verification_status != BankVerificationStatus.VERIFIED.value:
            raise_contract_error(
                400,
                "BANK_UNVERIFIED",
                "Rekening bank aktif harus terverifikasi sebelum mengajukan penarikan.",
            )
        if bank.id != bank_uuid:
            raise_contract_error(
                409,
                "ACCOUNT_CHANGED",
                "Rekening bank aktif telah berubah. Silakan muat ulang profil rekening Anda.",
            )

        if payload.amount_idr < MIN_PAYOUT_AMOUNT_IDR or payload.amount_idr > MAX_PAYOUT_AMOUNT_IDR:
            raise_contract_error(
                400,
                "PAYOUT_LIMIT",
                f"Nominal penarikan harus antara Rp {MIN_PAYOUT_AMOUNT_IDR:,} hingga Rp {MAX_PAYOUT_AMOUNT_IDR:,}.",
            )

        if profile.wallet_balance < payload.amount_idr:
            raise_contract_error(400, "INSUFFICIENT_BALANCE", "Saldo honorarium tersedia tidak mencukupi.")

        today_total = await self._sum_today_withdrawals(profile.id)
        if today_total + payload.amount_idr > DAILY_PAYOUT_LIMIT_IDR:
            raise_contract_error(
                400,
                "PAYOUT_LIMIT",
                f"Melebihi batas penarikan harian maksimal Rp {DAILY_PAYOUT_LIMIT_IDR:,}.",
            )

        now = datetime.now(UTC)
        fee_idr = PAYOUT_FEE_IDR
        net_amount_idr = payload.amount_idr - fee_idr
        wallet_debit_idr = payload.amount_idr
        expires_at = now + timedelta(minutes=QUOTE_TTL_MINUTES)

        quote = PayoutQuote(
            counselor_id=profile.id,
            bank_account_id=bank.id,
            account_revision=bank.account_revision,
            amount_idr=payload.amount_idr,
            fee_idr=fee_idr,
            fee_bearer=PAYOUT_FEE_BEARER,
            net_amount_idr=net_amount_idr,
            wallet_debit_idr=wallet_debit_idr,
            currency="IDR",
            expires_at=expires_at,
        )
        self.db.add(quote)
        await self.db.commit()
        await self.db.refresh(quote)

        return PayoutQuoteResponse(
            quote_id=str(quote.id),
            bank_account_id=str(quote.bank_account_id),
            amount_idr=quote.amount_idr,
            fee_idr=quote.fee_idr,
            fee_bearer=quote.fee_bearer,
            net_amount_idr=quote.net_amount_idr,
            wallet_debit_idr=quote.wallet_debit_idr,
            expires_at=quote.expires_at,
            currency=quote.currency,
        )

    async def create_payout(
        self,
        user_id: uuid.UUID,
        payload: CreatePayoutRequest,
        *,
        idempotency_key: str | None,
    ) -> PayoutRecordResponse:
        """Atomically lock funds, submit payout to Iris/gateway, and ensure idempotency."""
        if not idempotency_key or not idempotency_key.strip():
            raise_contract_error(400, "IDEMPOTENCY_CONFLICT", "Header Idempotency-Key wajib disertakan.")
        idem_key = idempotency_key.strip()[:128]
        req_hash = hashlib.sha256(payload.quote_id.strip().encode("utf-8")).hexdigest()

        profile, user = await self._load_counselor_and_user(user_id)

        existing = await self._find_by_idempotency(profile.id, idem_key)
        if existing is not None:
            if existing.request_hash != req_hash:
                raise_contract_error(
                    409,
                    "IDEMPOTENCY_CONFLICT",
                    "Idempotency-Key sudah digunakan untuk permintaan payout lain.",
                )
            return serialize_payout_record(existing)

        if not self.is_payout_enabled():
            raise_contract_error(
                503,
                "PAYOUT_DISABLED",
                "Layanan pencairan honorarium sedang dinonaktifkan sementara.",
            )

        try:
            quote_uuid = uuid.UUID(payload.quote_id.strip())
        except ValueError:
            raise_contract_error(404, "QUOTE_EXPIRED", "ID quote pencairan tidak valid.")

        # Pre-check provider payout liquidity before acquiring row locks
        quoted_net = (
            await self.db.execute(
                select(PayoutQuote.net_amount_idr).where(
                    PayoutQuote.id == quote_uuid,
                    PayoutQuote.counselor_id == profile.id,
                )
            )
        ).scalar_one_or_none()
        if quoted_net is not None:
            provider_balance = await self.gateway.get_aggregator_balance_idr()
            if provider_balance is not None and provider_balance < int(quoted_net):
                raise_contract_error(
                    503,
                    "PROVIDER_UNAVAILABLE",
                    "Saldo likuiditas pencairan penyedia saat ini sedang tidak mencukupi. Silakan coba lagi nanti.",
                )

        now = datetime.now(UTC)

        # Acquire row locks atomically before mutating balance
        locked_profile = (
            await self.db.execute(
                select(PsychologistProfile)
                .where(PsychologistProfile.id == profile.id)
                .with_for_update()
                .execution_options(populate_existing=True)
            )
        ).scalars().first()
        if not locked_profile:
            raise_contract_error(404, "COUNSELOR_NOT_FOUND", "Profil konselor tidak ditemukan.")

        quote = (
            await self.db.execute(
                select(PayoutQuote)
                .where(PayoutQuote.id == quote_uuid, PayoutQuote.counselor_id == locked_profile.id)
                .with_for_update()
                .execution_options(populate_existing=True)
            )
        ).scalars().first()
        if not quote:
            raise_contract_error(404, "QUOTE_EXPIRED", "Quote pencairan tidak ditemukan.")
        if quote.used_at is not None or quote.expires_at <= now:
            raise_contract_error(410, "QUOTE_EXPIRED", "Quote pencairan sudah kedaluwarsa atau telah digunakan.")

        active_bank = (
            await self.db.execute(
                select(CounselorBankAccount)
                .where(
                    CounselorBankAccount.counselor_id == locked_profile.id,
                    CounselorBankAccount.is_active.is_(True),
                )
                .with_for_update()
                .execution_options(populate_existing=True)
            )
        ).scalars().first()
        if not active_bank or active_bank.verification_status != BankVerificationStatus.VERIFIED.value:
            raise_contract_error(400, "BANK_UNVERIFIED", "Rekening bank aktif harus terverifikasi.")
        if active_bank.id != quote.bank_account_id or active_bank.account_revision != quote.account_revision:
            raise_contract_error(
                409,
                "ACCOUNT_CHANGED",
                "Rekening bank telah berubah sejak quote dibuat. Silakan buat quote baru.",
            )

        if not active_bank.account_number_encrypted:
            raise_contract_error(503, "PROVIDER_UNAVAILABLE", "Data rekening terenkripsi tidak tersedia.")
        try:
            decrypted_account_number = decrypt_bank_account(active_bank.account_number_encrypted)
        except BankEncryptionError as exc:
            raise_contract_error(503, "PROVIDER_UNAVAILABLE", str(exc))

        if locked_profile.wallet_balance < quote.wallet_debit_idr:
            raise_contract_error(400, "INSUFFICIENT_BALANCE", "Saldo honorarium tersedia tidak mencukupi.")

        today_total = await self._sum_today_withdrawals(locked_profile.id)
        if today_total + quote.amount_idr > DAILY_PAYOUT_LIMIT_IDR:
            raise_contract_error(
                400,
                "PAYOUT_LIMIT",
                f"Melebihi batas penarikan harian maksimal Rp {DAILY_PAYOUT_LIMIT_IDR:,}.",
            )

        # Lock wallet balance before submitting outbound gateway instruction
        locked_profile.wallet_balance -= quote.wallet_debit_idr
        locked_profile.locked_withdrawal_balance += quote.wallet_debit_idr
        quote.used_at = now

        reference_id = f"EVA-PO-{now:%Y%m%d}-{uuid.uuid4().hex[:8].upper()}"
        bank_snapshot = {
            "id": str(active_bank.id),
            "bank_code": active_bank.bank_code,
            "bank_name": active_bank.bank_name,
            "account_number_masked": active_bank.account_number_masked,
            "account_holder_name": active_bank.account_holder_name,
            "verification_status": active_bank.verification_status,
            "verified_at": active_bank.verified_at.isoformat() if active_bank.verified_at else None,
            "account_revision": active_bank.account_revision,
            "is_active": active_bank.is_active,
        }

        tx = CounselorTransaction(
            counselor_id=locked_profile.id,
            transaction_type=TransactionType.WITHDRAWAL.value,
            amount=quote.wallet_debit_idr,
            status=TransactionStatus.PENDING.value,
            reference_number=reference_id,
            description=f"Pencairan ke {active_bank.bank_name} ({active_bank.account_number_masked}) [{reference_id}]",
        )
        self.db.add(tx)
        await self.db.flush()

        withdrawal = CounselorWithdrawal(
            reference_id=reference_id,
            counselor_id=locked_profile.id,
            bank_account_id=active_bank.id,
            quote_id=quote.id,
            account_revision=active_bank.account_revision,
            idempotency_key=idem_key,
            request_hash=req_hash,
            amount_idr=quote.amount_idr,
            fee_idr=quote.fee_idr,
            fee_bearer=quote.fee_bearer,
            net_amount_idr=quote.net_amount_idr,
            wallet_debit_idr=quote.wallet_debit_idr,
            currency=quote.currency,
            status=PayoutStatus.REQUESTED.value,
            counselor_transaction_id=tx.id,
            bank_snapshot_json=bank_snapshot,
        )
        self.db.add(withdrawal)
        await self.db.flush()

        self.db.add(
            CounselorWithdrawalEvent(
                withdrawal_id=withdrawal.id,
                status=PayoutStatus.REQUESTED.value,
                source="system",
                message="Permintaan pencairan dibuat dan dana saldo dikunci sementara.",
                occurred_at=now,
            )
        )
        try:
            await self.db.commit()
        except IntegrityError:
            await self.db.rollback()
            existing_retry = await self._find_by_idempotency(profile.id, idem_key)
            if existing_retry and existing_retry.request_hash == req_hash:
                return serialize_payout_record(existing_retry)
            raise_contract_error(409, "IDEMPOTENCY_CONFLICT", "Permintaan payout duplikat.")

        await self.db.refresh(withdrawal)

        # Call external payout provider AFTER releasing DB row locks
        try:
            created = await self.gateway.create_payout(
                reference_id=withdrawal.reference_id,
                beneficiary_name=active_bank.account_holder_name,
                beneficiary_account=decrypted_account_number,
                beneficiary_bank=active_bank.bank_code,
                amount_idr=withdrawal.net_amount_idr,
                notes=f"EVA Honorarium {withdrawal.reference_id}",
                beneficiary_email=user.email,
            )
            mapped_status = map_iris_status_to_payout_status(created.status)
            withdrawal.provider_reference = created.reference_no
            withdrawal.status = mapped_status
            self.db.add(
                CounselorWithdrawalEvent(
                    withdrawal_id=withdrawal.id,
                    status=mapped_status,
                    source="iris",
                    message=f"Instruksi payout diterima penyedia ({created.reference_no}).",
                    occurred_at=datetime.now(UTC),
                )
            )
            if mapped_status == PayoutStatus.WAITING_APPROVAL.value and self._should_auto_approve():
                approved = await self.gateway.approve_payouts(reference_nos=[created.reference_no])
                if approved:
                    withdrawal.status = map_iris_status_to_payout_status(approved[0].status)
                    self.db.add(
                        CounselorWithdrawalEvent(
                            withdrawal_id=withdrawal.id,
                            status=withdrawal.status,
                            source="iris_approver",
                            message="Payout disetujui otomatis oleh sistem approver.",
                            occurred_at=datetime.now(UTC),
                        )
                    )
            await self.db.commit()
            await self.db.refresh(withdrawal)
            return serialize_payout_record(withdrawal)
        except PayoutGatewayError as exc:
            if not exc.retryable:
                await self._reverse_locked_funds(
                    withdrawal.id,
                    target_status=PayoutStatus.FAILED.value,
                    failure_code=exc.code,
                    failure_message=exc.message,
                    source="iris",
                )
                raise_contract_error(503, exc.code, exc.message)

            withdrawal.status = PayoutStatus.REVIEW_REQUIRED.value
            withdrawal.reconciliation_status = ReconciliationStatus.UNKNOWN.value
            withdrawal.failure_code = exc.code
            withdrawal.failure_message = exc.message
            self.db.add(
                CounselorWithdrawalEvent(
                    withdrawal_id=withdrawal.id,
                    status=PayoutStatus.REVIEW_REQUIRED.value,
                    source="system",
                    message="Penyedia payout tidak merespons tepat waktu; dijadwalkan untuk rekonsiliasi.",
                    occurred_at=datetime.now(UTC),
                )
            )
            self.db.add(
                PaymentOutboxEvent(
                    aggregate_type="counselor_withdrawal",
                    aggregate_id=withdrawal.id,
                    event_type="payout.reconcile_status",
                    payload_json={"reference_id": withdrawal.reference_id},
                    status=OutboxEventStatus.PENDING.value,
                    next_retry_at=datetime.now(UTC) + timedelta(minutes=1),
                )
            )
            await self.db.commit()
            raise_contract_error(503, exc.code, exc.message)

    async def list_payouts(
        self,
        user_id: uuid.UUID,
        *,
        page: int = 1,
        page_size: int = 20,
        status_filter: str | None = None,
    ) -> PaginatedResponse[PayoutRecordResponse]:
        """Return paginated list of counselor withdrawals ordered newest first."""
        profile = await self._load_counselor_profile(user_id)
        safe_page = max(1, page)
        safe_size = min(100, max(1, page_size))

        conditions = [CounselorWithdrawal.counselor_id == profile.id]
        if status_filter and status_filter.strip():
            conditions.append(CounselorWithdrawal.status == status_filter.strip().lower())

        total_stmt = select(func.count(CounselorWithdrawal.id)).where(*conditions)
        total = int((await self.db.execute(total_stmt)).scalar() or 0)

        items_stmt = (
            select(CounselorWithdrawal)
            .where(*conditions)
            .order_by(CounselorWithdrawal.created_at.desc(), CounselorWithdrawal.id.desc())
            .offset((safe_page - 1) * safe_size)
            .limit(safe_size)
        )
        rows = list((await self.db.execute(items_stmt)).scalars().all())
        return PaginatedResponse(
            items=[serialize_payout_record(row) for row in rows],
            page=safe_page,
            page_size=safe_size,
            total=total,
        )

    async def get_payout_detail(self, user_id: uuid.UUID, payout_id: str) -> PayoutRecordResponse:
        """Fetch single counselor payout record owned by authenticated counselor."""
        profile = await self._load_counselor_profile(user_id)
        try:
            payout_uuid = uuid.UUID(payout_id.strip())
        except ValueError:
            raise_contract_error(404, "PAYOUT_NOT_FOUND", "Data pencairan tidak ditemukan.")

        stmt = select(CounselorWithdrawal).where(
            CounselorWithdrawal.id == payout_uuid,
            CounselorWithdrawal.counselor_id == profile.id,
        )
        withdrawal = (await self.db.execute(stmt)).scalars().first()
        if not withdrawal:
            raise_contract_error(404, "PAYOUT_NOT_FOUND", "Data pencairan tidak ditemukan.")
        return serialize_payout_record(withdrawal)

    async def handle_iris_webhook(
        self,
        *,
        raw_body: bytes,
        signature_header: str | None,
        payload: dict[str, Any],
    ) -> IrisWebhookAckResponse:
        """Verify Iris signature, poll authoritative payout status, and mutate locked ledger."""
        reference_no = str(payload.get("reference_no") or "").strip()
        event_key = hashlib.sha256(raw_body or reference_no.encode("utf-8")).hexdigest()
        sig_valid = self.gateway.verify_webhook_signature(
            raw_body=raw_body,
            signature_header=signature_header,
        )

        existing_inbox = (
            await self.db.execute(
                select(PaymentWebhookInbox).where(
                    PaymentWebhookInbox.provider == "iris",
                    PaymentWebhookInbox.event_key == event_key,
                )
            )
        ).scalars().first()

        if existing_inbox is not None and existing_inbox.process_status == WebhookProcessStatus.PROCESSED.value:
            return IrisWebhookAckResponse(ok=True, status="duplicate", reference_no=reference_no or None)

        inbox = existing_inbox
        if inbox is None:
            inbox = PaymentWebhookInbox(
                provider="iris",
                event_key=event_key,
                order_or_ref_id=reference_no or "unknown",
                payload_json={"reference_no": reference_no, "status": payload.get("status")},
                signature_valid=sig_valid,
                process_status=(
                    WebhookProcessStatus.PENDING.value
                    if sig_valid
                    else WebhookProcessStatus.QUARANTINED.value
                ),
            )
            self.db.add(inbox)
        else:
            inbox.attempts += 1
            inbox.signature_valid = sig_valid

        if not sig_valid:
            inbox.last_error = "Invalid Iris-Signature header"
            await self.db.commit()
            raise_contract_error(403, "INVALID_SIGNATURE", "Tanda tangan webhook Iris tidak valid.")

        if not reference_no:
            inbox.process_status = WebhookProcessStatus.IGNORED.value
            inbox.processed_at = datetime.now(UTC)
            await self.db.commit()
            return IrisWebhookAckResponse(ok=True, status="ignored")

        await self.db.flush()

        # Verify authoritative status directly against Iris API before state mutation
        try:
            authoritative = await self.gateway.get_payout_status(reference_no)
        except PayoutGatewayError as exc:
            inbox.process_status = WebhookProcessStatus.FAILED.value
            inbox.last_error = exc.message
            await self.db.commit()
            raise_contract_error(503, exc.code, exc.message)

        target_status = map_iris_status_to_payout_status(authoritative.status)
        withdrawal = (
            await self.db.execute(
                select(CounselorWithdrawal)
                .where(CounselorWithdrawal.provider_reference == reference_no)
                .with_for_update()
                .execution_options(populate_existing=True)
            )
        ).scalars().first()

        if not withdrawal:
            inbox.process_status = WebhookProcessStatus.IGNORED.value
            inbox.processed_at = datetime.now(UTC)
            await self.db.commit()
            return IrisWebhookAckResponse(ok=True, status="ignored", reference_no=reference_no)

        await self.apply_authoritative_status(
            withdrawal,
            target_status=target_status,
            failure_reason=authoritative.failure_reason,
            source="iris_webhook",
        )
        inbox.process_status = WebhookProcessStatus.PROCESSED.value
        inbox.processed_at = datetime.now(UTC)
        await self.db.commit()
        return IrisWebhookAckResponse(ok=True, status=withdrawal.status, reference_no=reference_no)

    async def apply_authoritative_status(
        self,
        withdrawal: CounselorWithdrawal,
        *,
        target_status: str,
        failure_reason: str | None = None,
        source: str = "reconcile",
    ) -> CounselorWithdrawal:
        """Apply idempotent state transition and unlock/reverse locked wallet balance."""
        now = datetime.now(UTC)
        already_terminal = (
            withdrawal.status == PayoutStatus.COMPLETED.value
            or withdrawal.status in _TERMINAL_FAILURE_STATUSES
        )
        if already_terminal:
            return withdrawal

        profile = (
            await self.db.execute(
                select(PsychologistProfile)
                .where(PsychologistProfile.id == withdrawal.counselor_id)
                .with_for_update()
                .execution_options(populate_existing=True)
            )
        ).scalars().first()

        if target_status == PayoutStatus.COMPLETED.value:
            if profile:
                release_amount = min(profile.locked_withdrawal_balance, withdrawal.wallet_debit_idr)
                profile.locked_withdrawal_balance -= release_amount
            withdrawal.status = PayoutStatus.COMPLETED.value
            withdrawal.completed_at = now
            withdrawal.reconciliation_status = ReconciliationStatus.MATCHED.value
            if withdrawal.counselor_transaction_id:
                tx = (
                    await self.db.execute(
                        select(CounselorTransaction).where(
                            CounselorTransaction.id == withdrawal.counselor_transaction_id
                        )
                    )
                ).scalars().first()
                if tx:
                    tx.status = TransactionStatus.COMPLETED.value
            self.db.add(
                CounselorWithdrawalEvent(
                    withdrawal_id=withdrawal.id,
                    status=PayoutStatus.COMPLETED.value,
                    source=source,
                    message="Dana pencairan berhasil ditransfer ke rekening tujuan.",
                    occurred_at=now,
                )
            )
        elif target_status in _TERMINAL_FAILURE_STATUSES:
            if profile:
                release_amount = min(profile.locked_withdrawal_balance, withdrawal.wallet_debit_idr)
                profile.locked_withdrawal_balance -= release_amount
                profile.wallet_balance += withdrawal.wallet_debit_idr
            withdrawal.status = target_status
            withdrawal.failure_code = target_status.upper()
            withdrawal.failure_message = failure_reason or "Pencairan gagal diproses oleh bank/penyedia."
            withdrawal.reconciliation_status = ReconciliationStatus.MATCHED.value
            if withdrawal.counselor_transaction_id:
                tx = (
                    await self.db.execute(
                        select(CounselorTransaction).where(
                            CounselorTransaction.id == withdrawal.counselor_transaction_id
                        )
                    )
                ).scalars().first()
                if tx:
                    tx.description = f"[GAGAL/DIKEMBALIKAN] {tx.description}"
            self.db.add(
                CounselorWithdrawalEvent(
                    withdrawal_id=withdrawal.id,
                    status=target_status,
                    source=source,
                    message=f"Pencairan berstatus {target_status}; saldo dikembalikan ke dompet konselor.",
                    occurred_at=now,
                )
            )
        else:
            withdrawal.status = target_status
            self.db.add(
                CounselorWithdrawalEvent(
                    withdrawal_id=withdrawal.id,
                    status=target_status,
                    source=source,
                    message=f"Pembaruan status pencairan: {target_status}.",
                    occurred_at=now,
                )
            )
        return withdrawal

    async def _reverse_locked_funds(
        self,
        withdrawal_id: uuid.UUID,
        *,
        target_status: str,
        failure_code: str,
        failure_message: str,
        source: str,
    ) -> None:
        withdrawal = (
            await self.db.execute(
                select(CounselorWithdrawal)
                .where(CounselorWithdrawal.id == withdrawal_id)
                .with_for_update()
            )
        ).scalars().first()
        if not withdrawal:
            return
        await self.apply_authoritative_status(
            withdrawal,
            target_status=target_status,
            failure_reason=failure_message,
            source=source,
        )
        withdrawal.failure_code = failure_code
        withdrawal.failure_message = failure_message
        await self.db.commit()

    async def _find_by_idempotency(
        self,
        counselor_id: uuid.UUID,
        idempotency_key: str,
    ) -> CounselorWithdrawal | None:
        stmt = select(CounselorWithdrawal).where(
            CounselorWithdrawal.counselor_id == counselor_id,
            CounselorWithdrawal.idempotency_key == idempotency_key,
        )
        return (await self.db.execute(stmt)).scalars().first()

    async def _sum_today_withdrawals(self, counselor_id: uuid.UUID) -> int:
        now = datetime.now(UTC)
        start_of_day = datetime(now.year, now.month, now.day, tzinfo=UTC)
        stmt = select(func.coalesce(func.sum(CounselorWithdrawal.amount_idr), 0)).where(
            CounselorWithdrawal.counselor_id == counselor_id,
            CounselorWithdrawal.created_at >= start_of_day,
            CounselorWithdrawal.status.in_(_ACTIVE_AND_COMPLETED_PAYOUT_STATUSES),
        )
        return int((await self.db.execute(stmt)).scalar() or 0)

    async def _load_counselor_profile(self, user_id: uuid.UUID) -> PsychologistProfile:
        stmt = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        profile = (await self.db.execute(stmt)).scalars().first()
        if not profile:
            raise_contract_error(404, "COUNSELOR_NOT_FOUND", "Profil konselor tidak ditemukan.")
        return profile

    async def _load_counselor_and_user(self, user_id: uuid.UUID) -> tuple[PsychologistProfile, User]:
        profile = await self._load_counselor_profile(user_id)
        user = (await self.db.execute(select(User).where(User.id == user_id))).scalars().first()
        if not user:
            raise_contract_error(404, "USER_NOT_FOUND", "Akun pengguna tidak ditemukan.")
        return profile, user

    async def _load_active_bank_account(self, counselor_id: uuid.UUID) -> CounselorBankAccount | None:
        stmt = (
            select(CounselorBankAccount)
            .where(
                CounselorBankAccount.counselor_id == counselor_id,
                CounselorBankAccount.is_active.is_(True),
            )
            .order_by(CounselorBankAccount.account_revision.desc())
        )
        return (await self.db.execute(stmt)).scalars().first()
