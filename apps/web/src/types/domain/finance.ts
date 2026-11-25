export type FinanceDirection = 'in' | 'out'

export type FinanceSource =
  | 'qris_topup'
  | 'counselor_payout'
  | 'payment_refund'
  | 'payout_reversal'

export type FinanceReconciliationStatus =
  | 'pending'
  | 'matched'
  | 'mismatch'
  | 'review_required'
  | 'unknown'

export interface FinanceSummary {
  currency: string
  from: string
  to: string
  moneyInPaidIdr: number
  moneyInPendingIdr: number
  moneyOutCompletedIdr: number
  moneyOutPendingIdr: number
  refundCompletedIdr: number
  providerFeesKnownIdr: number | null
  commissionEarnedIdr: number
  clientCreditLiabilityIdr: number
  counselorPayableIdr: number
  unreconciledCount: number
  providerPayoutAvailableIdr: number | null
  providerBalanceAsOf: string | null
}

export interface FinanceTransaction {
  id: string
  direction: FinanceDirection
  source: FinanceSource
  referenceId: string
  providerReference: string | null
  actorLabel: string
  amountIdr: number | null
  feeIdr: number | null
  netAmountIdr: number | null
  walletDebitIdr: number | null
  currency: string
  status: string
  reconciliationStatus: FinanceReconciliationStatus
  createdAt: string
  completedAt: string | null
  bankAccountMasked: string | null
}

export interface FinanceTransactionEvent {
  status: string
  occurredAt: string
  source: string
  message: string
}

export interface FinanceTransactionDetail extends FinanceTransaction {
  events: FinanceTransactionEvent[]
}

export interface FinanceTransactionsQuery {
  from: string
  to: string
  direction?: FinanceDirection
  status?: string
  source?: FinanceSource
  q?: string
  page: number
  pageSize: number
}

export interface PaginatedFinanceTransactions {
  items: FinanceTransaction[]
  page: number
  pageSize: number
  total: number
}
