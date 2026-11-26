from datetime import UTC, datetime, timedelta
import hashlib
import logging
import math
from typing import Any
import uuid

from fastapi import status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.payment_errors import raise_contract_error
from app.models.coin import CoinPackage, CoinTransaction
from app.models.enums import (
    CoinTransactionType,
    OutboxEventStatus,
    ReconciliationStatus,
    TopupOrderStatus,
    TransactionStatus,
    WebhookProcessStatus,
)
from app.models.payment import CoinTopupOrder, PaymentOutboxEvent, PaymentWebhookInbox
from app.models.user import User
from app.schemas.coin import (
    CoinTopupOrderResponse,
    CoinTopupPackageSnapshotResponse,
    CreateCoinTopupRequest,
    MidtransNotificationAckResponse,
)
from app.schemas.common import PaginatedResponse
from app.services.payment import (
    BasePaymentGatewayPort,
    MidtransCoreApiAdapter,
    PaymentGatewayError,
    PaymentStatusResult,
)
from shared.config import settings

logger = logging.getLogger(__name__)

_TERMINAL_TOPUP_STATUSES = {
    TopupOrderStatus.PAID.value,
    TopupOrderStatus.EXPIRED.value,
    TopupOrderStatus.CANCELLED.value,
    TopupOrderStatus.REFUNDED.value,
    TopupOrderStatus.REVIEW_REQUIRED.value,
}

_PROTECTED_PAID_OR_POST_PAID = {
    TopupOrderStatus.PAID.value,
    TopupOrderStatus.REFUND_PENDING.value,
    TopupOrderStatus.PARTIALLY_REFUNDED.value,
    TopupOrderStatus.REFUNDED.value,
    TopupOrderStatus.REVIEW_REQUIRED.value,
}

_REFRESH_COOLDOWN_SECONDS = 3


class CoinTopupService:
    """Domain service managing QRIS EVA Coin top-ups, idempotency, webhooks, and refunds."""

    def __init__(
        self,
        db: AsyncSession,
        *,
        gateway: BasePaymentGatewayPort | None = None,
        config: Any = None,
    ) -> None:
        self.db = db
        self._settings = config or settings
        self.gateway = gateway or MidtransCoreApiAdapter(config=self._settings)

    def _ensure_payment_enabled(self) -> None:
        if not bool(getattr(self._settings, "MIDTRANS_PAYMENT_ENABLED", False)):
            raise_contract_error(
                status.HTTP_503_SERVICE_UNAVAILABLE,
                "PAYMENT_DISABLED",
                "Pembelian koin via QRIS saat ini sedang dinonaktifkan.",
            )

    @staticmethod
    def _compute_request_hash(package_id: uuid.UUID) -> str:
        return hashlib.sha256(f"qris:{package_id}".encode("utf-8")).hexdigest()

    async def create_topup_order(
        self,
        user: User,
        payload: CreateCoinTopupRequest,
        idempotency_key: str | None,
    ) -> tuple[CoinTopupOrderResponse, int]:
        """Create or replay a QRIS top-up order with strict server-side pricing & idempotency."""
        self._ensure_payment_enabled()

        clean_key = (idempotency_key or "").strip()
        if not clean_key or len(clean_key) > 128:
            raise_contract_error(
                status.HTTP_400_BAD_REQUEST,
                "IDEMPOTENCY_KEY_REQUIRED",
                "Header Idempotency-Key wajib disertakan untuk membuat pesanan top-up.",
            )

        request_hash = self._compute_request_hash(payload.package_id)

        existing = await self._find_by_idempotency(user.id, clean_key)
        if existing is not None:
            if existing.request_hash != request_hash:
                raise_contract_error(
                    status.HTTP_409_CONFLICT,
                    "IDEMPOTENCY_CONFLICT",
                    "Idempotency-Key sudah digunakan untuk paket top-up yang berbeda.",
                )
            replay_code = (
                status.HTTP_202_ACCEPTED
                if existing.status == TopupOrderStatus.CREATING.value
                else status.HTTP_200_OK
            )
            return self._to_order_response(existing), replay_code

        pkg_res = await self.db.execute(
            select(CoinPackage).where(CoinPackage.id == payload.package_id)
        )
        pkg = pkg_res.scalar_one_or_none()
        if not pkg or not pkg.is_active:
            raise_contract_error(
                status.HTTP_400_BAD_REQUEST,
                "PACKAGE_INACTIVE",
                "Paket EVA Coin tidak ditemukan atau sedang tidak aktif.",
            )

        now = datetime.now(UTC)
        order_code = f"EVA-TOPUP-{now.strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"
        total_coins = int(pkg.coins) + int(pkg.bonus_coins)

        order = CoinTopupOrder(
            order_id=order_code,
            user_id=user.id,
            package_id=pkg.id,
            package_code=pkg.code,
            package_name=pkg.name,
            coins_snapshot=int(pkg.coins),
            bonus_coins_snapshot=int(pkg.bonus_coins),
            total_coins_snapshot=total_coins,
            amount_idr=int(pkg.price_idr),
            currency="IDR",
            payment_method="qris",
            idempotency_key=clean_key,
            request_hash=request_hash,
            status=TopupOrderStatus.CREATING.value,
            reconciliation_status=ReconciliationStatus.PENDING.value,
        )
        self.db.add(order)
        try:
            await self.db.commit()
            await self.db.refresh(order)
        except IntegrityError:
            await self.db.rollback()
            existing = await self._find_by_idempotency(user.id, clean_key)
            if existing is None:
                raise
            if existing.request_hash != request_hash:
                raise_contract_error(
                    status.HTTP_409_CONFLICT,
                    "IDEMPOTENCY_CONFLICT",
                    "Idempotency-Key sudah digunakan untuk paket top-up yang berbeda.",
                )
            replay_code = (
                status.HTTP_202_ACCEPTED
                if existing.status == TopupOrderStatus.CREATING.value
                else status.HTTP_200_OK
            )
            return self._to_order_response(existing), replay_code

        customer_name = user.display_name or user.username or user.email.split("@")[0]
        try:
            charge_res = await self.gateway.create_qris_charge(
                order_id=order.order_id,
                amount_idr=order.amount_idr,
                item_id=order.package_code,
                item_name=order.package_name,
                customer_name=customer_name,
                customer_email=user.email,
            )
        except PaymentGatewayError as exc:
            order.failure_code = exc.code
            order.failure_message = exc.message
            if exc.retryable:
                self.db.add(
                    PaymentOutboxEvent(
                        aggregate_type="topup_order",
                        aggregate_id=order.id,
                        event_type="reconcile_charge_timeout",
                        payload_json={"order_id": order.order_id},
                        status=OutboxEventStatus.PENDING.value,
                        next_retry_at=datetime.now(UTC) + timedelta(seconds=15),
                    )
                )
            else:
                order.status = TopupOrderStatus.FAILED.value
            await self.db.commit()
            http_code = (
                status.HTTP_503_SERVICE_UNAVAILABLE
                if exc.code in {"PAYMENT_DISABLED", "PROVIDER_UNAVAILABLE", "PROVIDER_TIMEOUT"}
                else status.HTTP_502_BAD_GATEWAY
            )
            raise_contract_error(http_code, exc.code, exc.message)

        order.provider_transaction_id = charge_res.provider_transaction_id
        order.qr_image_url = charge_res.qr_image_url
        order.qr_image_v2_url = charge_res.qr_image_v2_url
        order.expires_at = charge_res.expires_at
        order.status = (
            TopupOrderStatus.PENDING.value
            if charge_res.transaction_status in {"pending", "creating", ""}
            else charge_res.transaction_status
        )
        await self.db.commit()
        await self.db.refresh(order)

        return self._to_order_response(order), status.HTTP_201_CREATED

    async def list_topup_orders(
        self,
        user_id: uuid.UUID,
        *,
        page: int = 1,
        page_size: int = 20,
        status_filter: str | None = None,
    ) -> PaginatedResponse[CoinTopupOrderResponse]:
        """List paginated top-up orders belonging strictly to the authenticated user."""
        safe_page = max(1, page)
        safe_size = max(1, min(100, page_size))

        base_filter = [CoinTopupOrder.user_id == user_id]
        if status_filter and status_filter.strip():
            base_filter.append(CoinTopupOrder.status == status_filter.strip().lower())

        count_res = await self.db.execute(
            select(func.count(CoinTopupOrder.id)).where(*base_filter)
        )
        total = int(count_res.scalar() or 0)

        rows_res = await self.db.execute(
            select(CoinTopupOrder)
            .where(*base_filter)
            .order_by(CoinTopupOrder.created_at.desc(), CoinTopupOrder.id.desc())
            .offset((safe_page - 1) * safe_size)
            .limit(safe_size)
        )
        orders = rows_res.scalars().all()
        return PaginatedResponse[CoinTopupOrderResponse](
            items=[self._to_order_response(o) for o in orders],
            page=safe_page,
            page_size=safe_size,
            total=total,
        )

    async def get_topup_order(self, user_id: uuid.UUID, topup_id: uuid.UUID) -> CoinTopupOrderResponse:
        """Fetch a single top-up order owned by the authenticated user."""
        order = await self._get_owned_order(user_id, topup_id)
        return self._to_order_response(order)

    async def fetch_qr_png(self, user_id: uuid.UUID, topup_id: uuid.UUID) -> bytes:
        """Proxy QR PNG bytes safely from an allowlisted Midtrans URL for the order owner."""
        order = await self._get_owned_order(user_id, topup_id)
        target_url = order.qr_image_v2_url or order.qr_image_url
        if not target_url:
            raise_contract_error(
                status.HTTP_404_NOT_FOUND,
                "QR_NOT_AVAILABLE",
                "Gambar QRIS belum tersedia untuk pesanan ini.",
            )
        try:
            return await self.gateway.fetch_qr_image_bytes(target_url)
        except PaymentGatewayError as exc:
            raise_contract_error(status.HTTP_503_SERVICE_UNAVAILABLE, exc.code, exc.message)

    async def refresh_topup_order(self, user_id: uuid.UUID, topup_id: uuid.UUID) -> CoinTopupOrderResponse:
        """Sync order state on-demand against Midtrans Get Status with cooldown rate limit."""
        order = await self._get_owned_order(user_id, topup_id)
        if order.status in _TERMINAL_TOPUP_STATUSES:
            return self._to_order_response(order)

        now = datetime.now(UTC)
        if order.updated_at is not None:
            updated_utc = order.updated_at if order.updated_at.tzinfo else order.updated_at.replace(tzinfo=UTC)
            if (now - updated_utc).total_seconds() < _REFRESH_COOLDOWN_SECONDS and order.status == TopupOrderStatus.PENDING.value:
                raise_contract_error(
                    status.HTTP_429_TOO_MANY_REQUESTS,
                    "RATE_LIMITED",
                    "Tunggu beberapa detik sebelum memeriksa ulang status pembayaran.",
                )

        self._ensure_payment_enabled()
        try:
            status_res = await self.gateway.get_transaction_status(order.order_id)
        except PaymentGatewayError as exc:
            if exc.code == "TOPUP_NOT_FOUND" and order.expires_at and now > order.expires_at:
                order.status = TopupOrderStatus.EXPIRED.value
                await self.db.commit()
                await self.db.refresh(order)
                return self._to_order_response(order)
            raise_contract_error(status.HTTP_503_SERVICE_UNAVAILABLE, exc.code, exc.message)

        await self._reconcile_order_with_status(order.order_id, status_res)
        await self.db.refresh(order)
        return self._to_order_response(order)

    async def handle_midtrans_webhook(self, payload: dict[str, Any]) -> MidtransNotificationAckResponse:
        """Verify Midtrans webhook signature, persist inbox, cross-check Get Status, and credit atomically."""
        order_id = str(payload.get("order_id") or "").strip()
        status_code = str(payload.get("status_code") or "").strip()
        gross_amount = str(payload.get("gross_amount") or "").strip()
        signature_key = str(payload.get("signature_key") or "").strip()
        tx_id = str(payload.get("transaction_id") or "").strip()
        tx_status = str(payload.get("transaction_status") or "").strip().lower()

        if not order_id or not status_code or not gross_amount:
            raise_contract_error(
                status.HTTP_400_BAD_REQUEST,
                "INVALID_WEBHOOK_PAYLOAD",
                "Payload notifikasi Midtrans tidak lengkap.",
            )

        sig_valid = self.gateway.verify_notification_signature(
            order_id=order_id,
            status_code=status_code,
            gross_amount=gross_amount,
            signature_key=signature_key,
        )

        event_key_raw = f"midtrans_payment|{order_id}|{tx_id}|{tx_status}|{status_code}|{gross_amount}|{signature_key}"
        event_key = hashlib.sha256(event_key_raw.encode("utf-8")).hexdigest()

        inbox = await self._record_webhook_inbox(
            provider="midtrans_payment",
            event_key=event_key,
            order_or_ref_id=order_id,
            payload=payload,
            signature_valid=sig_valid,
        )

        if not sig_valid:
            inbox.process_status = WebhookProcessStatus.QUARANTINED.value
            inbox.last_error = "Invalid SHA512 signature_key"
            await self.db.commit()
            raise_contract_error(
                status.HTTP_403_FORBIDDEN,
                "INVALID_SIGNATURE",
                "Tanda tangan webhook Midtrans tidak valid.",
            )

        if inbox.process_status == WebhookProcessStatus.PROCESSED.value:
            return MidtransNotificationAckResponse(received=True, order_id=order_id, status=tx_status or "processed")

        try:
            auth_status = await self.gateway.get_transaction_status(order_id)
        except PaymentGatewayError as exc:
            inbox.attempts += 1
            inbox.process_status = WebhookProcessStatus.FAILED.value
            inbox.last_error = exc.message
            await self.db.commit()
            raise_contract_error(status.HTTP_503_SERVICE_UNAVAILABLE, exc.code, exc.message)

        final_status = await self._reconcile_order_with_status(order_id, auth_status, inbox=inbox)
        return MidtransNotificationAckResponse(received=True, order_id=order_id, status=final_status)

    async def reconcile_order_by_code(self, order_id: str) -> str:
        """Worker helper to sync an order directly with Midtrans Get Status."""
        auth_status = await self.gateway.get_transaction_status(order_id)
        return await self._reconcile_order_with_status(order_id, auth_status)

    async def _reconcile_order_with_status(
        self,
        order_id: str,
        status_res: PaymentStatusResult,
        *,
        inbox: PaymentWebhookInbox | None = None,
    ) -> str:
        res = await self.db.execute(
            select(CoinTopupOrder).where(CoinTopupOrder.order_id == order_id).with_for_update()
        )
        order = res.scalar_one_or_none()
        if order is None:
            if inbox is not None:
                inbox.process_status = WebhookProcessStatus.QUARANTINED.value
                inbox.last_error = "Unknown order_id"
                await self.db.commit()
            return "unknown_order"

        mismatch_reasons: list[str] = []
        if status_res.gross_amount_idr != order.amount_idr:
            mismatch_reasons.append(f"amount {status_res.gross_amount_idr} != {order.amount_idr}")
        if status_res.currency != order.currency:
            mismatch_reasons.append(f"currency {status_res.currency} != {order.currency}")
        if status_res.payment_type and status_res.payment_type != "qris":
            mismatch_reasons.append(f"payment_type {status_res.payment_type} != qris")
        if (
            order.provider_transaction_id
            and status_res.provider_transaction_id
            and status_res.provider_transaction_id != order.provider_transaction_id
        ):
            mismatch_reasons.append("provider_transaction_id mismatch")

        if mismatch_reasons:
            order.status = TopupOrderStatus.REVIEW_REQUIRED.value
            order.reconciliation_status = ReconciliationStatus.MISMATCH.value
            order.failure_code = "RECONCILIATION_MISMATCH"
            order.failure_message = "; ".join(mismatch_reasons)
            if inbox is not None:
                inbox.process_status = WebhookProcessStatus.QUARANTINED.value
                inbox.last_error = order.failure_message
            await self.db.commit()
            return order.status

        if not order.provider_transaction_id and status_res.provider_transaction_id:
            order.provider_transaction_id = status_res.provider_transaction_id

        tx_status = status_res.transaction_status
        fraud_ok = status_res.fraud_status in (None, "", "accept")
        now = datetime.now(UTC)

        if tx_status == "settlement" or (tx_status == "capture" and fraud_ok):
            await self._apply_settlement(order, status_res, now)
        elif tx_status == "pending":
            if order.status == TopupOrderStatus.CREATING.value:
                order.status = TopupOrderStatus.PENDING.value
        elif tx_status == "expire":
            if order.status in {TopupOrderStatus.CREATING.value, TopupOrderStatus.PENDING.value}:
                order.status = TopupOrderStatus.EXPIRED.value
                order.reconciliation_status = ReconciliationStatus.MATCHED.value
        elif tx_status == "cancel":
            if order.status in {TopupOrderStatus.CREATING.value, TopupOrderStatus.PENDING.value}:
                order.status = TopupOrderStatus.CANCELLED.value
                order.reconciliation_status = ReconciliationStatus.MATCHED.value
        elif tx_status in {"deny", "failure"} or (tx_status == "capture" and not fraud_ok):
            if order.status in {TopupOrderStatus.CREATING.value, TopupOrderStatus.PENDING.value}:
                order.status = TopupOrderStatus.FAILED.value
                order.failure_code = "PROVIDER_REJECTED"
                order.reconciliation_status = ReconciliationStatus.MATCHED.value
        elif tx_status in {"refund", "partial_refund"}:
            await self._apply_refund(order, status_res, now)
        else:
            if order.status not in _PROTECTED_PAID_OR_POST_PAID:
                order.status = TopupOrderStatus.REVIEW_REQUIRED.value
                order.reconciliation_status = ReconciliationStatus.UNKNOWN.value

        if inbox is not None:
            inbox.process_status = WebhookProcessStatus.PROCESSED.value
            inbox.processed_at = now
            inbox.last_error = None

        await self.db.commit()
        return order.status

    async def _apply_settlement(
        self,
        order: CoinTopupOrder,
        status_res: PaymentStatusResult,
        now: datetime,
    ) -> None:
        """Atomically credit user coin balance exactly once on settlement."""
        if order.coin_transaction_id is not None or order.status in _PROTECTED_PAID_OR_POST_PAID:
            return

        user_res = await self.db.execute(
            select(User).where(User.id == order.user_id).with_for_update()
        )
        user = user_res.scalar_one_or_none()
        if user is None:
            order.status = TopupOrderStatus.REVIEW_REQUIRED.value
            order.reconciliation_status = ReconciliationStatus.MISMATCH.value
            order.failure_code = "USER_NOT_FOUND"
            return

        paid_at = status_res.settlement_time or now
        user.coin_balance += order.total_coins_snapshot
        invoice_code = f"EVA-QRIS-{paid_at.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"
        tx = CoinTransaction(
            invoice_code=invoice_code,
            user_id=user.id,
            transaction_type=CoinTransactionType.TOPUP_QRIS.value,
            coins_delta=order.total_coins_snapshot,
            balance_after=user.coin_balance,
            amount_idr=order.amount_idr,
            payment_method="QRIS Midtrans",
            package_name=order.package_name,
            status=TransactionStatus.COMPLETED.value,
            completed_at=paid_at,
        )
        self.db.add(tx)
        await self.db.flush()

        order.coin_transaction_id = tx.id
        order.status = TopupOrderStatus.PAID.value
        order.paid_at = paid_at
        order.reconciliation_status = ReconciliationStatus.MATCHED.value
        order.failure_code = None
        order.failure_message = None

    async def _apply_refund(
        self,
        order: CoinTopupOrder,
        status_res: PaymentStatusResult,
        now: datetime,
    ) -> None:
        """Handle Midtrans refund safely without ever letting coin balance go negative."""
        target_refund_idr = status_res.refund_amount_idr or order.amount_idr
        target_refund_idr = min(order.amount_idr, max(0, target_refund_idr))
        if target_refund_idr <= order.refunded_amount_idr and order.status in {
            TopupOrderStatus.REFUNDED.value,
            TopupOrderStatus.PARTIALLY_REFUNDED.value,
        }:
            return

        if order.coin_transaction_id is None:
            order.refunded_amount_idr = target_refund_idr
            order.status = (
                TopupOrderStatus.REFUNDED.value
                if target_refund_idr >= order.amount_idr
                else TopupOrderStatus.PARTIALLY_REFUNDED.value
            )
            order.reconciliation_status = ReconciliationStatus.MATCHED.value
            return

        already_clawed_coins = (
            math.floor((order.refunded_amount_idr / order.amount_idr) * order.total_coins_snapshot)
            if order.amount_idr > 0
            else 0
        )
        target_claw_coins = (
            order.total_coins_snapshot
            if target_refund_idr >= order.amount_idr
            else math.ceil((target_refund_idr / order.amount_idr) * order.total_coins_snapshot)
        )
        coins_to_clawback = max(0, target_claw_coins - already_clawed_coins)

        user_res = await self.db.execute(
            select(User).where(User.id == order.user_id).with_for_update()
        )
        user = user_res.scalar_one_or_none()
        if user is None or user.coin_balance < coins_to_clawback:
            order.status = TopupOrderStatus.REVIEW_REQUIRED.value
            order.reconciliation_status = ReconciliationStatus.MISMATCH.value
            order.failure_code = "REFUND_COINS_ALREADY_SPENT"
            order.failure_message = "Sebagian atau seluruh koin dari top-up ini telah terpakai."
            return

        if coins_to_clawback > 0:
            user.coin_balance -= coins_to_clawback
            self.db.add(
                CoinTransaction(
                    invoice_code=f"EVA-RFND-{now.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}",
                    user_id=user.id,
                    transaction_type=CoinTransactionType.REFUND.value,
                    coins_delta=-coins_to_clawback,
                    balance_after=user.coin_balance,
                    amount_idr=max(0, target_refund_idr - order.refunded_amount_idr),
                    payment_method="QRIS Midtrans Refund",
                    package_name=order.package_name,
                    status=TransactionStatus.REFUNDED.value,
                    completed_at=now,
                )
            )

        order.refunded_amount_idr = target_refund_idr
        order.status = (
            TopupOrderStatus.REFUNDED.value
            if target_refund_idr >= order.amount_idr
            else TopupOrderStatus.PARTIALLY_REFUNDED.value
        )
        order.reconciliation_status = ReconciliationStatus.MATCHED.value

    async def _find_by_idempotency(
        self,
        user_id: uuid.UUID,
        idempotency_key: str,
    ) -> CoinTopupOrder | None:
        res = await self.db.execute(
            select(CoinTopupOrder).where(
                CoinTopupOrder.user_id == user_id,
                CoinTopupOrder.idempotency_key == idempotency_key,
            )
        )
        return res.scalar_one_or_none()

    async def _get_owned_order(self, user_id: uuid.UUID, topup_id: uuid.UUID) -> CoinTopupOrder:
        res = await self.db.execute(
            select(CoinTopupOrder).where(
                CoinTopupOrder.id == topup_id,
                CoinTopupOrder.user_id == user_id,
            )
        )
        order = res.scalar_one_or_none()
        if order is None:
            raise_contract_error(
                status.HTTP_404_NOT_FOUND,
                "TOPUP_NOT_FOUND",
                "Pesanan top-up koin tidak ditemukan.",
            )
        return order

    async def _record_webhook_inbox(
        self,
        *,
        provider: str,
        event_key: str,
        order_or_ref_id: str,
        payload: dict[str, Any],
        signature_valid: bool,
    ) -> PaymentWebhookInbox:
        res = await self.db.execute(
            select(PaymentWebhookInbox).where(
                PaymentWebhookInbox.provider == provider,
                PaymentWebhookInbox.event_key == event_key,
            )
        )
        existing = res.scalar_one_or_none()
        if existing is not None:
            return existing

        inbox = PaymentWebhookInbox(
            provider=provider,
            event_key=event_key,
            order_or_ref_id=order_or_ref_id,
            payload_json=payload,
            signature_valid=signature_valid,
            process_status=WebhookProcessStatus.PENDING.value,
        )
        self.db.add(inbox)
        try:
            await self.db.flush()
            return inbox
        except IntegrityError:
            await self.db.rollback()
            res = await self.db.execute(
                select(PaymentWebhookInbox).where(
                    PaymentWebhookInbox.provider == provider,
                    PaymentWebhookInbox.event_key == event_key,
                )
            )
            return res.scalar_one()

    @staticmethod
    def _to_order_response(order: CoinTopupOrder) -> CoinTopupOrderResponse:
        return CoinTopupOrderResponse(
            id=str(order.id),
            order_id=order.order_id,
            package=CoinTopupPackageSnapshotResponse(
                id=str(order.package_id or order.package_code),
                name=order.package_name,
                coins=order.coins_snapshot,
                bonus_coins=order.bonus_coins_snapshot,
            ),
            amount_idr=order.amount_idr,
            currency=order.currency,
            total_coins=order.total_coins_snapshot,
            payment_method=order.payment_method,
            status=order.status,
            qr_image_url=order.qr_image_v2_url or order.qr_image_url,
            expires_at=order.expires_at,
            paid_at=order.paid_at,
            created_at=order.created_at,
            updated_at=order.updated_at,
        )
