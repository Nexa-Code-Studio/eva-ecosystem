import type {
  BackendFinanceEventDto,
  BackendFinanceSummaryDto,
  BackendFinanceTransactionDetailDto,
  BackendFinanceTransactionDto,
  BackendFinanceTransactionsPageDto,
} from '../../types/api/contracts.ts'
import type {
  FinanceDirection,
  FinanceReconciliationStatus,
  FinanceSource,
  FinanceSummary,
  FinanceTransaction,
  FinanceTransactionDetail,
  FinanceTransactionEvent,
  PaginatedFinanceTransactions,
} from '../../types/domain/finance.ts'

export function normalizeFinanceDirection(value: string): FinanceDirection {
  return value === 'out' ? 'out' : 'in'
}

export function normalizeFinanceSource(value: string): FinanceSource {
  switch (value) {
    case 'counselor_payout':
    case 'payment_refund':
    case 'payout_reversal':
      return value
    default:
      return 'qris_topup'
  }
}

export function normalizeFinanceReconciliationStatus(
  value: string,
): FinanceReconciliationStatus {
  switch (value) {
    case 'pending':
    case 'matched':
    case 'mismatch':
    case 'review_required':
      return value
    default:
      return 'unknown'
  }
}

function toNullableFiniteNumber(value: unknown): number | null {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return null
  }
  return value
}

export function mapBackendFinanceSummaryToDomain(
  dto: BackendFinanceSummaryDto,
): FinanceSummary {
  return {
    currency: dto.currency || 'IDR',
    from: dto.from,
    to: dto.to,
    moneyInPaidIdr: dto.money_in_paid_idr ?? 0,
    moneyInPendingIdr: dto.money_in_pending_idr ?? 0,
    moneyOutCompletedIdr: dto.money_out_completed_idr ?? 0,
    moneyOutPendingIdr: dto.money_out_pending_idr ?? 0,
    refundCompletedIdr: dto.refund_completed_idr ?? 0,
    providerFeesKnownIdr: toNullableFiniteNumber(dto.provider_fees_known_idr),
    commissionEarnedIdr: dto.commission_earned_idr ?? 0,
    clientCreditLiabilityIdr: dto.client_credit_liability_idr ?? 0,
    counselorPayableIdr: dto.counselor_payable_idr ?? 0,
    unreconciledCount: dto.unreconciled_count ?? 0,
    providerPayoutAvailableIdr: toNullableFiniteNumber(dto.provider_payout_available_idr),
    providerBalanceAsOf: dto.provider_balance_as_of ?? null,
  }
}

export function mapBackendFinanceTransactionToDomain(
  dto: BackendFinanceTransactionDto,
): FinanceTransaction {
  return {
    id: dto.id,
    direction: normalizeFinanceDirection(dto.direction),
    source: normalizeFinanceSource(dto.source),
    referenceId: dto.reference_id,
    providerReference: dto.provider_reference ?? null,
    actorLabel: dto.actor_label,
    amountIdr: toNullableFiniteNumber(dto.amount_idr),
    feeIdr: toNullableFiniteNumber(dto.fee_idr),
    netAmountIdr: toNullableFiniteNumber(dto.net_amount_idr),
    walletDebitIdr: toNullableFiniteNumber(dto.wallet_debit_idr),
    currency: dto.currency || 'IDR',
    status: dto.status,
    reconciliationStatus: normalizeFinanceReconciliationStatus(dto.reconciliation_status),
    createdAt: dto.created_at,
    completedAt: dto.completed_at ?? null,
    bankAccountMasked: dto.bank_account_masked ?? null,
  }
}

export function mapBackendFinanceTransactionsPageToDomain(
  dto: BackendFinanceTransactionsPageDto,
): PaginatedFinanceTransactions {
  return {
    items: (dto.items ?? []).map(mapBackendFinanceTransactionToDomain),
    page: dto.page ?? 1,
    pageSize: dto.page_size ?? 20,
    total: dto.total ?? 0,
  }
}

export function mapBackendFinanceEventToDomain(
  dto: BackendFinanceEventDto,
): FinanceTransactionEvent {
  return {
    status: dto.status,
    occurredAt: dto.occurred_at,
    source: dto.source,
    message: dto.message,
  }
}

export function mapBackendFinanceTransactionDetailToDomain(
  dto: BackendFinanceTransactionDetailDto,
): FinanceTransactionDetail {
  return {
    ...mapBackendFinanceTransactionToDomain(dto),
    events: (dto.events ?? []).map(mapBackendFinanceEventToDomain),
  }
}
