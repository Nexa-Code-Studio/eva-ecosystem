from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import PayoutStatus, ReconciliationStatus, TopupOrderStatus
from app.models.payment import CoinTopupOrder, CounselorWithdrawal
from app.services.finances.payout_service import PayoutService, map_iris_status_to_payout_status
from app.services.payment.port import BasePaymentGatewayPort, PaymentGatewayError
from app.services.payout.port import BasePayoutGatewayPort, PayoutGatewayError


@dataclass(slots=True)
class ReconciliationReport:
    checked_topups: int
    mismatched_topups: int
    checked_payouts: int
    updated_payouts: int


class ReconciliationService:
    """Compares local QRIS top-up and Iris payout ledgers against provider truth."""

    def __init__(
        self,
        db: AsyncSession,
        *,
        payment_gateway: BasePaymentGatewayPort | None = None,
        payout_gateway: BasePayoutGatewayPort | None = None,
    ) -> None:
        self.db = db
        self.payment_gateway = payment_gateway
        self.payout_gateway = payout_gateway

    async def run_daily_reconciliation(self, *, lookback_hours: int = 48) -> ReconciliationReport:
        cutoff = datetime.now(UTC) - timedelta(hours=lookback_hours)
        checked_topups = 0
        mismatched_topups = 0
        checked_payouts = 0
        updated_payouts = 0

        if self.payment_gateway is not None:
            orders = (
                await self.db.execute(
                    select(CoinTopupOrder).where(
                        CoinTopupOrder.created_at >= cutoff,
                        CoinTopupOrder.status.in_(
                            [TopupOrderStatus.PENDING.value, TopupOrderStatus.PAID.value, TopupOrderStatus.REVIEW_REQUIRED.value]
                        ),
                    )
                )
            ).scalars().all()
            for order in orders:
                checked_topups += 1
                try:
                    remote = await self.payment_gateway.get_transaction_status(order.order_id)
                except PaymentGatewayError:
                    order.reconciliation_status = ReconciliationStatus.UNKNOWN.value
                    continue
                if order.status == TopupOrderStatus.PAID.value and remote.transaction_status in (
                    "settlement",
                    "capture",
                ):
                    order.reconciliation_status = ReconciliationStatus.MATCHED.value
                elif order.status != TopupOrderStatus.PAID.value and remote.transaction_status in (
                    "settlement",
                    "capture",
                ):
                    order.reconciliation_status = ReconciliationStatus.MISMATCH.value
                    mismatched_topups += 1

        if self.payout_gateway is not None:
            payout_service = PayoutService(self.db, self.payout_gateway)
            withdrawals = (
                await self.db.execute(
                    select(CounselorWithdrawal).where(
                        CounselorWithdrawal.created_at >= cutoff,
                        CounselorWithdrawal.provider_reference.is_not(None),
                        CounselorWithdrawal.status.in_(
                            [
                                PayoutStatus.WAITING_APPROVAL.value,
                                PayoutStatus.PROCESSING.value,
                                PayoutStatus.REVIEW_REQUIRED.value,
                            ]
                        ),
                    )
                )
            ).scalars().all()
            for w in withdrawals:
                checked_payouts += 1
                if not w.provider_reference:
                    continue
                try:
                    remote = await self.payout_gateway.get_payout_status(w.provider_reference)
                except PayoutGatewayError:
                    w.reconciliation_status = ReconciliationStatus.UNKNOWN.value
                    continue
                target_status = map_iris_status_to_payout_status(remote.status)
                if target_status != w.status:
                    await payout_service.apply_authoritative_status(
                        w,
                        target_status=target_status,
                        failure_reason=remote.failure_reason,
                        source="reconciliation",
                    )
                    updated_payouts += 1
                else:
                    w.reconciliation_status = ReconciliationStatus.MATCHED.value

        await self.db.commit()
        return ReconciliationReport(
            checked_topups=checked_topups,
            mismatched_topups=mismatched_topups,
            checked_payouts=checked_payouts,
            updated_payouts=updated_payouts,
        )
