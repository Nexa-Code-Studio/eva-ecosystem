import { getActivePortalDataSource } from './storage'
import type {
  FinanceSummary,
  FinanceTransactionDetail,
  FinanceTransactionsQuery,
  PaginatedFinanceTransactions,
} from '@/types/domain/finance'

export async function fetchAdminFinanceSummary(
  params: { from: string; to: string },
  options?: { signal?: AbortSignal },
): Promise<FinanceSummary> {
  return getActivePortalDataSource().fetchAdminFinanceSummary(params, options)
}

export async function fetchAdminFinanceTransactions(
  query: FinanceTransactionsQuery,
  options?: { signal?: AbortSignal },
): Promise<PaginatedFinanceTransactions> {
  return getActivePortalDataSource().fetchAdminFinanceTransactions(query, options)
}

export async function fetchAdminFinanceTransactionDetail(
  transactionId: string,
  options?: { signal?: AbortSignal },
): Promise<FinanceTransactionDetail> {
  return getActivePortalDataSource().fetchAdminFinanceTransactionDetail(transactionId, options)
}
