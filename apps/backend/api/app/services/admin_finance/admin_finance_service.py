from datetime import UTC, datetime, timedelta
import uuid

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.payment_errors import raise_contract_error
from app.models.coin import CoinEconomyConfig, CoinTransaction
from app.models.counselor import (
    ConsultationSession,
    CounselorTransaction,
    PsychologistProfile,
)
from app.models.enums import (
    CoinTransactionType,
    ConsultationSessionStatus,
    PayoutStatus,
    ReconciliationStatus,
    TopupOrderStatus,
    TransactionStatus,
    TransactionType,
)
from app.models.payment import (
    CoinTopupOrder,
    CounselorWithdrawal,
    PaymentWebhookInbox,
)
from app.models.user import User
from app.schemas.admin_finance import (
    AdminFinanceSummaryResponse,
    AdminFinanceTransactionDetailResponse,
    AdminFinanceTransactionEventResponse,
    AdminFinanceTransactionItemResponse,
)
from app.schemas.common import PaginatedResponse
from app.services.payout import BasePayoutGatewayPort


def _actor_user_label(user: User | None, user_id: uuid.UUID) -> str:
    short = str(user_id).split("-")[0].upper()
    if user and user.display_name:
        return f"{user.display_name} ({short})"
    return f"User {short}"


def _actor_counselor_label(counselor: PsychologistProfile | None, counselor_id: uuid.UUID) -> str:
    short = str(counselor_id).split("-")[0].upper()
    if counselor and counselor.full_name:
        return f"{counselor.full_name} ({short})"
    return f"Counselor {short}"


class AdminFinanceService:
    """Provides audited real-money KPIs and sanitized finance ledgers for Web Admin C5."""

    def __init__(self, db: AsyncSession, payout_gateway: BasePayoutGatewayPort) -> None:
        self.db = db
        self.payout_gateway = payout_gateway

    async def get_summary(
        self,
        *,
        from_at: datetime | None = None,
        to_at: datetime | None = None,
    ) -> AdminFinanceSummaryResponse:
        now = datetime.now(UTC)
        end_dt = to_at or now
        start_dt = from_at or (end_dt - timedelta(days=30))

        money_in_paid = int(
            (
                await self.db.execute(
                    select(func.coalesce(func.sum(CoinTopupOrder.amount_idr), 0)).where(
                        CoinTopupOrder.created_at >= start_dt,
                        CoinTopupOrder.created_at <= end_dt,
                        CoinTopupOrder.status.in_(
                            [TopupOrderStatus.PAID.value, TopupOrderStatus.PARTIALLY_REFUNDED.value]
                        ),
                    )
                )
            ).scalar()
            or 0
        )

        money_in_pending = int(
            (
                await self.db.execute(
                    select(func.coalesce(func.sum(CoinTopupOrder.amount_idr), 0)).where(
                        CoinTopupOrder.created_at >= start_dt,
                        CoinTopupOrder.created_at <= end_dt,
                        CoinTopupOrder.status.in_(
                            [TopupOrderStatus.CREATING.value, TopupOrderStatus.PENDING.value]
                        ),
                    )
                )
            ).scalar()
            or 0
        )

        money_out_completed = int(
            (
                await self.db.execute(
                    select(func.coalesce(func.sum(CounselorWithdrawal.net_amount_idr), 0)).where(
                        CounselorWithdrawal.created_at >= start_dt,
                        CounselorWithdrawal.created_at <= end_dt,
                        CounselorWithdrawal.status == PayoutStatus.COMPLETED.value,
                    )
                )
            ).scalar()
            or 0
        )

        money_out_pending = int(
            (
                await self.db.execute(
                    select(func.coalesce(func.sum(CounselorWithdrawal.amount_idr), 0)).where(
                        CounselorWithdrawal.created_at >= start_dt,
                        CounselorWithdrawal.created_at <= end_dt,
                        CounselorWithdrawal.status.in_(
                            [
                                PayoutStatus.REQUESTED.value,
                                PayoutStatus.WAITING_APPROVAL.value,
                                PayoutStatus.PROCESSING.value,
                                PayoutStatus.REVIEW_REQUIRED.value,
                            ]
                        ),
                    )
                )
            ).scalar()
            or 0
        )

        refund_completed = int(
            (
                await self.db.execute(
                    select(func.coalesce(func.sum(CoinTopupOrder.refunded_amount_idr), 0)).where(
                        CoinTopupOrder.created_at >= start_dt,
                        CoinTopupOrder.created_at <= end_dt,
                        CoinTopupOrder.status.in_(
                            [TopupOrderStatus.REFUNDED.value, TopupOrderStatus.PARTIALLY_REFUNDED.value]
                        ),
                    )
                )
            ).scalar()
            or 0
        )

        known_fees_row = (
            await self.db.execute(
                select(
                    func.count(CounselorWithdrawal.id),
                    func.coalesce(func.sum(CounselorWithdrawal.fee_idr), 0),
                ).where(
                    CounselorWithdrawal.created_at >= start_dt,
                    CounselorWithdrawal.created_at <= end_dt,
                    CounselorWithdrawal.status == PayoutStatus.COMPLETED.value,
                )
            )
        ).first()
        completed_payout_count = int(known_fees_row[0] or 0) if known_fees_row else 0
        provider_fees_known = (
            int(known_fees_row[1] or 0) if completed_payout_count > 0 and known_fees_row else None
        )

        commission_earned = int(
            (
                await self.db.execute(
                    select(func.coalesce(func.sum(ConsultationSession.platform_fee), 0)).where(
                        ConsultationSession.created_at >= start_dt,
                        ConsultationSession.created_at <= end_dt,
                        ConsultationSession.status == ConsultationSessionStatus.COMPLETED.value,
                    )
                )
            ).scalar()
            or 0
        )

        economy_cfg = (
            await self.db.execute(
                select(CoinEconomyConfig).order_by(CoinEconomyConfig.created_at.desc())
            )
        ).scalars().first()
        coin_price_idr = int(economy_cfg.base_price_per_coin_idr) if economy_cfg else 1000
        total_user_coins = int(
            (await self.db.execute(select(func.coalesce(func.sum(User.coin_balance), 0)))).scalar() or 0
        )
        client_credit_liability = total_user_coins * coin_price_idr

        counselor_wallets = int(
            (
                await self.db.execute(
                    select(
                        func.coalesce(
                            func.sum(
                                PsychologistProfile.wallet_balance
                                + PsychologistProfile.locked_withdrawal_balance
                            ),
                            0,
                        )
                    )
                )
            ).scalar()
            or 0
        )
        counselor_pending_clearing = int(
            (
                await self.db.execute(
                    select(func.coalesce(func.sum(CounselorTransaction.amount), 0)).where(
                        CounselorTransaction.transaction_type == TransactionType.EARNING.value,
                        CounselorTransaction.status == TransactionStatus.PENDING.value,
                    )
                )
            ).scalar()
            or 0
        )
        counselor_payable = counselor_wallets + counselor_pending_clearing

        unreconciled_topups = int(
            (
                await self.db.execute(
                    select(func.count(CoinTopupOrder.id)).where(
                        or_(
                            CoinTopupOrder.reconciliation_status.in_(
                                [
                                    ReconciliationStatus.MISMATCH.value,
                                    ReconciliationStatus.REVIEW_REQUIRED.value,
                                    ReconciliationStatus.UNKNOWN.value,
                                ]
                            ),
                            (
                                (CoinTopupOrder.reconciliation_status == ReconciliationStatus.PENDING.value)
                                & CoinTopupOrder.status.in_(
                                    [TopupOrderStatus.CREATING.value, TopupOrderStatus.PENDING.value]
                                )
                            ),
                        )
                    )
                )
            ).scalar()
            or 0
        )
        unreconciled_payouts = int(
            (
                await self.db.execute(
                    select(func.count(CounselorWithdrawal.id)).where(
                        CounselorWithdrawal.reconciliation_status != ReconciliationStatus.MATCHED.value,
                        CounselorWithdrawal.status.not_in(
                            [
                                PayoutStatus.FAILED.value,
                                PayoutStatus.REJECTED.value,
                                PayoutStatus.CANCELLED.value,
                                PayoutStatus.REVERSED.value,
                            ]
                        ),
                    )
                )
            ).scalar()
            or 0
        )

        provider_balance = await self.payout_gateway.get_aggregator_balance_idr()
        provider_balance_as_of = datetime.now(UTC) if provider_balance is not None else None

        return AdminFinanceSummaryResponse(
            currency="IDR",
            from_at=start_dt,
            to_at=end_dt,
            money_in_paid_idr=money_in_paid,
            money_in_pending_idr=money_in_pending,
            money_out_completed_idr=money_out_completed,
            money_out_pending_idr=money_out_pending,
            refund_completed_idr=refund_completed,
            provider_fees_known_idr=provider_fees_known,
            commission_earned_idr=commission_earned,
            client_credit_liability_idr=client_credit_liability,
            counselor_payable_idr=counselor_payable,
            unreconciled_count=unreconciled_topups + unreconciled_payouts,
            provider_payout_available_idr=provider_balance,
            provider_balance_as_of=provider_balance_as_of,
        )

    async def list_transactions(
        self,
        *,
        from_at: datetime | None = None,
        to_at: datetime | None = None,
        direction: str | None = None,
        status_filter: str | None = None,
        source: str | None = None,
        q: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedResponse[AdminFinanceTransactionItemResponse]:
        safe_page = max(1, page)
        safe_size = min(100, max(1, page_size))
        dir_filter = direction.strip().lower() if direction else None
        src_filter = source.strip().lower() if source else None
        st_filter = status_filter.strip().lower() if status_filter else None
        search_q = q.strip().lower() if q and q.strip() else None

        items: list[AdminFinanceTransactionItemResponse] = []

        include_topups = src_filter in (None, "qris_topup", "qris_refund") and dir_filter in (None, "in", "refund")
        if include_topups:
            stmt = select(CoinTopupOrder).options(selectinload(CoinTopupOrder.user))
            if from_at:
                stmt = stmt.where(CoinTopupOrder.created_at >= from_at)
            if to_at:
                stmt = stmt.where(CoinTopupOrder.created_at <= to_at)
            if st_filter:
                stmt = stmt.where(CoinTopupOrder.status == st_filter)
            orders = list((await self.db.execute(stmt)).scalars().all())
            for order in orders:
                is_refunded = order.status in (
                    TopupOrderStatus.REFUNDED.value,
                    TopupOrderStatus.PARTIALLY_REFUNDED.value,
                )
                row_dir = "refund" if is_refunded and dir_filter == "refund" else "in"
                row_src = "qris_refund" if is_refunded and src_filter == "qris_refund" else "qris_topup"
                if dir_filter and row_dir != dir_filter:
                    continue
                if src_filter and row_src != src_filter:
                    continue
                item = AdminFinanceTransactionItemResponse(
                    id=str(order.id),
                    direction=row_dir,
                    source=row_src,
                    reference_id=order.order_id,
                    provider_reference=order.provider_transaction_id,
                    actor_label=_actor_user_label(order.user, order.user_id),
                    amount_idr=order.amount_idr,
                    fee_idr=None,
                    net_amount_idr=None,
                    currency=order.currency,
                    status=order.status,
                    reconciliation_status=order.reconciliation_status,
                    created_at=order.created_at,
                    completed_at=order.paid_at,
                    bank_account_masked=None,
                )
                if self._matches_search(item, search_q):
                    items.append(item)

        include_payouts = src_filter in (None, "counselor_payout") and dir_filter in (None, "out")
        if include_payouts:
            stmt = select(CounselorWithdrawal).options(selectinload(CounselorWithdrawal.counselor))
            if from_at:
                stmt = stmt.where(CounselorWithdrawal.created_at >= from_at)
            if to_at:
                stmt = stmt.where(CounselorWithdrawal.created_at <= to_at)
            if st_filter:
                stmt = stmt.where(CounselorWithdrawal.status == st_filter)
            payouts = list((await self.db.execute(stmt)).scalars().all())
            for w in payouts:
                snap = w.bank_snapshot_json or {}
                item = AdminFinanceTransactionItemResponse(
                    id=str(w.id),
                    direction="out",
                    source="counselor_payout",
                    reference_id=w.reference_id,
                    provider_reference=w.provider_reference,
                    actor_label=_actor_counselor_label(w.counselor, w.counselor_id),
                    amount_idr=w.amount_idr,
                    fee_idr=w.fee_idr,
                    net_amount_idr=w.net_amount_idr,
                    currency=w.currency,
                    status=w.status,
                    reconciliation_status=w.reconciliation_status,
                    created_at=w.created_at,
                    completed_at=w.completed_at,
                    bank_account_masked=snap.get("account_number_masked"),
                )
                if self._matches_search(item, search_q):
                    items.append(item)

        include_grants = src_filter in (None, "admin_grant") and dir_filter in (None, "grant")
        if include_grants:
            stmt = (
                select(CoinTransaction)
                .where(
                    CoinTransaction.transaction_type.in_(
                        [CoinTransactionType.GRANT_ADMIN.value, CoinTransactionType.TOPUP_ADMIN.value]
                    )
                )
                .options(selectinload(CoinTransaction.user))
            )
            if from_at:
                stmt = stmt.where(CoinTransaction.created_at >= from_at)
            if to_at:
                stmt = stmt.where(CoinTransaction.created_at <= to_at)
            grants = list((await self.db.execute(stmt)).scalars().all())
            for g in grants:
                status_val = "granted"
                if st_filter and status_val != st_filter:
                    continue
                item = AdminFinanceTransactionItemResponse(
                    id=str(g.id),
                    direction="grant",
                    source="admin_grant",
                    reference_id=g.invoice_code or str(g.id),
                    provider_reference=None,
                    actor_label=_actor_user_label(g.user, g.user_id),
                    amount_idr=0,
                    fee_idr=None,
                    net_amount_idr=None,
                    currency="IDR",
                    status=status_val,
                    reconciliation_status=ReconciliationStatus.MATCHED.value,
                    created_at=g.created_at,
                    completed_at=g.created_at,
                    bank_account_masked=None,
                )
                if self._matches_search(item, search_q):
                    items.append(item)

        items.sort(key=lambda row: (row.created_at, row.id), reverse=True)
        total = len(items)
        start = (safe_page - 1) * safe_size
        return PaginatedResponse(
            items=items[start : start + safe_size],
            page=safe_page,
            page_size=safe_size,
            total=total,
        )

    async def get_transaction_detail(self, record_id: str) -> AdminFinanceTransactionDetailResponse:
        try:
            rec_uuid = uuid.UUID(record_id.strip())
        except ValueError:
            raise_contract_error(404, "TRANSACTION_NOT_FOUND", "Data transaksi keuangan tidak ditemukan.")

        order = (
            await self.db.execute(
                select(CoinTopupOrder)
                .where(CoinTopupOrder.id == rec_uuid)
                .options(selectinload(CoinTopupOrder.user))
            )
        ).scalars().first()
        if order:
            webhooks = (
                await self.db.execute(
                    select(PaymentWebhookInbox)
                    .where(
                        PaymentWebhookInbox.provider == "midtrans_qris",
                        PaymentWebhookInbox.order_or_ref_id == order.order_id,
                    )
                    .order_by(PaymentWebhookInbox.created_at.asc())
                )
            ).scalars().all()
            events = [
                AdminFinanceTransactionEventResponse(
                    status=TopupOrderStatus.PENDING.value,
                    occurred_at=order.created_at,
                    source="backend",
                    message=f"Order QRIS {order.order_id} dibuat ({order.amount_idr} IDR).",
                )
            ]
            for wh in webhooks:
                events.append(
                    AdminFinanceTransactionEventResponse(
                        status=wh.process_status,
                        occurred_at=wh.processed_at or wh.created_at,
                        source="midtrans_webhook",
                        message=f"Webhook QRIS diterima ({wh.process_status}).",
                    )
                )
            if order.paid_at:
                events.append(
                    AdminFinanceTransactionEventResponse(
                        status=order.status,
                        occurred_at=order.paid_at,
                        source="ledger",
                        message="Pembayaran terverifikasi dan saldo koin pengguna dikreditkan.",
                    )
                )
            is_refunded = order.status in (
                TopupOrderStatus.REFUNDED.value,
                TopupOrderStatus.PARTIALLY_REFUNDED.value,
            )
            return AdminFinanceTransactionDetailResponse(
                id=str(order.id),
                direction="refund" if is_refunded else "in",
                source="qris_refund" if is_refunded else "qris_topup",
                reference_id=order.order_id,
                provider_reference=order.provider_transaction_id,
                actor_label=_actor_user_label(order.user, order.user_id),
                amount_idr=order.amount_idr,
                fee_idr=None,
                net_amount_idr=None,
                currency=order.currency,
                status=order.status,
                reconciliation_status=order.reconciliation_status,
                created_at=order.created_at,
                completed_at=order.paid_at,
                bank_account_masked=None,
                events=events,
            )

        withdrawal = (
            await self.db.execute(
                select(CounselorWithdrawal)
                .where(CounselorWithdrawal.id == rec_uuid)
                .options(
                    selectinload(CounselorWithdrawal.counselor),
                    selectinload(CounselorWithdrawal.events),
                )
            )
        ).scalars().first()
        if withdrawal:
            snap = withdrawal.bank_snapshot_json or {}
            return AdminFinanceTransactionDetailResponse(
                id=str(withdrawal.id),
                direction="out",
                source="counselor_payout",
                reference_id=withdrawal.reference_id,
                provider_reference=withdrawal.provider_reference,
                actor_label=_actor_counselor_label(withdrawal.counselor, withdrawal.counselor_id),
                amount_idr=withdrawal.amount_idr,
                fee_idr=withdrawal.fee_idr,
                net_amount_idr=withdrawal.net_amount_idr,
                currency=withdrawal.currency,
                status=withdrawal.status,
                reconciliation_status=withdrawal.reconciliation_status,
                created_at=withdrawal.created_at,
                completed_at=withdrawal.completed_at,
                bank_account_masked=snap.get("account_number_masked"),
                events=[
                    AdminFinanceTransactionEventResponse(
                        status=ev.status,
                        occurred_at=ev.occurred_at,
                        source=ev.source,
                        message=ev.message,
                    )
                    for ev in withdrawal.events
                ],
            )

        grant_tx = (
            await self.db.execute(
                select(CoinTransaction)
                .where(
                    CoinTransaction.id == rec_uuid,
                    CoinTransaction.transaction_type.in_(
                        [CoinTransactionType.GRANT_ADMIN.value, CoinTransactionType.TOPUP_ADMIN.value]
                    ),
                )
                .options(selectinload(CoinTransaction.user))
            )
        ).scalars().first()
        if grant_tx:
            return AdminFinanceTransactionDetailResponse(
                id=str(grant_tx.id),
                direction="grant",
                source="admin_grant",
                reference_id=grant_tx.invoice_code or str(grant_tx.id),
                provider_reference=None,
                actor_label=_actor_user_label(grant_tx.user, grant_tx.user_id),
                amount_idr=0,
                fee_idr=None,
                net_amount_idr=None,
                currency="IDR",
                status="granted",
                reconciliation_status=ReconciliationStatus.MATCHED.value,
                created_at=grant_tx.created_at,
                completed_at=grant_tx.created_at,
                bank_account_masked=None,
                events=[
                    AdminFinanceTransactionEventResponse(
                        status="granted",
                        occurred_at=grant_tx.created_at,
                        source="admin",
                        message=grant_tx.admin_notes or f"Pemberian {grant_tx.coins_delta} koin oleh admin.",
                    )
                ],
            )

        raise_contract_error(404, "TRANSACTION_NOT_FOUND", "Data transaksi keuangan tidak ditemukan.")

    @staticmethod
    def _matches_search(item: AdminFinanceTransactionItemResponse, search_q: str | None) -> bool:
        if not search_q:
            return True
        haystack = " ".join(
            [
                item.reference_id.lower(),
                (item.provider_reference or "").lower(),
                item.actor_label.lower(),
                item.source.lower(),
            ]
        )
        return search_q in haystack
