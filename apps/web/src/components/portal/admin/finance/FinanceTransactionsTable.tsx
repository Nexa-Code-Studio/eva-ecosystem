import { Eye, FileSearch, Loader2 } from 'lucide-react'
import { TablePagination } from '@/components/portal/TablePagination'
import {
  formatIdrOrUnavailable,
  formatTimestampWib,
} from '@/services/contracts/financeUtils'
import type { FinanceDirection, FinanceTransaction } from '@/types/domain/finance'
import {
  FinancePaymentStatusBadge,
  FinanceReconciliationBadge,
  FinanceSourceBadge,
} from './FinanceStatusBadges'

interface FinanceTransactionsTableProps {
  direction: FinanceDirection
  items: FinanceTransaction[]
  total: number
  page: number
  pageSize: number
  loading: boolean
  errorMessage: string | null
  onRetry: () => void
  onSelectTransaction: (transactionId: string) => void
  onPageChange: (nextPage: number) => void
  onPageSizeChange: (nextSize: number) => void
}

export function FinanceTransactionsTable({
  direction,
  items,
  total,
  page,
  pageSize,
  loading,
  errorMessage,
  onRetry,
  onSelectTransaction,
  onPageChange,
  onPageSizeChange,
}: FinanceTransactionsTableProps) {
  if (errorMessage) {
    return (
      <div className="rounded-[14px] border border-rose-200 bg-rose-50 px-5 py-8 text-center">
        <p className="text-sm font-bold text-rose-800">Gagal memuat daftar transaksi</p>
        <p className="mt-1 text-xs text-rose-700">{errorMessage}</p>
        <button
          type="button"
          onClick={onRetry}
          className="mt-4 inline-flex h-9 cursor-pointer items-center rounded-[8px] border border-rose-300 bg-white px-4 text-xs font-semibold text-rose-800 transition-colors hover:bg-rose-100"
        >
          Muat Ulang
        </button>
      </div>
    )
  }

  if (loading && items.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center gap-2.5 rounded-[14px] border border-[#E2E8F0] bg-white px-5 py-12 text-xs font-medium text-ink-soft">
        <Loader2 className="size-5 animate-spin text-primary" aria-hidden="true" />
        <span>Memuat transaksi keuangan...</span>
      </div>
    )
  }

  if (!loading && items.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center gap-2 rounded-[14px] border border-[#E2E8F0] bg-white px-5 py-12 text-center">
        <FileSearch className="size-6 text-ink-muted" aria-hidden="true" />
        <p className="text-sm font-semibold text-ink">
          Belum ada transaksi {direction === 'in' ? 'uang masuk (QRIS)' : 'uang keluar'} yang cocok
        </p>
        <p className="max-w-md text-xs text-ink-muted">
          Sesuaikan rentang tanggal WIB, kata kunci referensi, atau filter status di atas.
        </p>
      </div>
    )
  }

  return (
    <div className="overflow-hidden rounded-[14px] border border-[#E2E8F0] bg-white shadow-2xs">
      {loading && (
        <div className="flex items-center gap-2 border-b border-[#E2E8F0] bg-[#EEF0FF]/60 px-4 py-2 text-xs font-medium text-primary">
          <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />
          <span>Memperbarui data transaksi...</span>
        </div>
      )}

      {/* Desktop Table */}
      <div className="hidden overflow-x-auto md:block">
        <table className="w-full border-collapse text-left text-xs">
          <thead>
            <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wide text-ink-muted uppercase">
              <th className="py-3 pr-3 pl-4">Referensi &amp; Provider</th>
              <th className="px-3 py-3">{direction === 'in' ? 'Pengguna' : 'Penerima & Rekening'}</th>
              <th className="px-3 py-3">Waktu (WIB)</th>
              <th className="px-3 py-3 text-right">
                {direction === 'out' ? 'Nominal & Biaya' : 'Nominal IDR'}
              </th>
              {direction === 'out' && (
                <th className="px-3 py-3 text-right">Net / Debit</th>
              )}
              <th className="px-3 py-3">
                {direction === 'out' ? 'Status & Rekonsiliasi' : 'Status'}
              </th>
              {direction === 'in' && <th className="px-3 py-3">Rekonsiliasi</th>}
              <th className="py-3 pr-4 pl-3 text-right">Aksi</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[#E2E8F0]">
            {items.map((tx) => (
              <tr key={tx.id} className="transition-colors hover:bg-[#F8FAFC]">
                <td className="py-3 pr-3 pl-4 align-top">
                  <p className="font-mono font-semibold whitespace-nowrap text-ink">{tx.referenceId}</p>
                  <div className="mt-1 flex flex-wrap items-center gap-1.5">
                    <FinanceSourceBadge source={tx.source} />
                    {tx.providerReference && (
                      <span className="font-mono text-[11px] text-ink-muted">
                        {tx.providerReference}
                      </span>
                    )}
                  </div>
                </td>
                <td className="px-3 py-3 align-top">
                  <p className="font-semibold text-ink">{tx.actorLabel}</p>
                  {direction === 'out' && (
                    <p className="mt-0.5 text-[11px] text-ink-soft">
                      Rekening: {tx.bankAccountMasked || 'Tidak tersedia'}
                    </p>
                  )}
                </td>
                <td className="px-3 py-3 align-top whitespace-nowrap text-ink-soft">
                  {formatTimestampWib(tx.createdAt)}
                </td>
                <td className="px-3 py-3 align-top text-right tabular-nums">
                  <p className="font-bold whitespace-nowrap text-ink">
                    {formatIdrOrUnavailable(tx.amountIdr)}
                  </p>
                  {direction === 'out' && (
                    <p className="mt-0.5 text-[11px] whitespace-nowrap text-ink-muted">
                      Biaya: {formatIdrOrUnavailable(tx.feeIdr)}
                    </p>
                  )}
                </td>
                {direction === 'out' && (
                  <td className="px-3 py-3 align-top text-right tabular-nums">
                    <p className="font-semibold whitespace-nowrap text-ink">
                      Net: {formatIdrOrUnavailable(tx.netAmountIdr)}
                    </p>
                    <p className="mt-0.5 text-[11px] whitespace-nowrap text-ink-muted">
                      Debit: {formatIdrOrUnavailable(tx.walletDebitIdr)}
                    </p>
                  </td>
                )}
                <td className="px-3 py-3 align-top">
                  <div className="flex flex-col items-start gap-1">
                    <FinancePaymentStatusBadge status={tx.status} />
                    {direction === 'out' && (
                      <FinanceReconciliationBadge status={tx.reconciliationStatus} />
                    )}
                  </div>
                </td>
                {direction === 'in' && (
                  <td className="px-3 py-3 align-top">
                    <FinanceReconciliationBadge status={tx.reconciliationStatus} />
                  </td>
                )}
                <td className="py-3 pr-4 pl-3 align-top text-right whitespace-nowrap">
                  <button
                    type="button"
                    onClick={() => onSelectTransaction(tx.id)}
                    className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[7px] border border-[#CBD5E1] bg-white px-2.5 text-[11px] font-semibold text-ink transition-colors hover:border-primary/40 hover:text-primary"
                  >
                    <Eye className="size-3.5" aria-hidden="true" />
                    <span>Detail</span>
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile Cards */}
      <ul className="divide-y divide-[#E2E8F0] md:hidden">
        {items.map((tx) => (
          <li key={tx.id} className="space-y-2.5 p-4 text-xs">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <p className="truncate font-mono font-bold text-ink">{tx.referenceId}</p>
                <p className="mt-0.5 text-[11px] text-ink-soft">{formatTimestampWib(tx.createdAt)}</p>
              </div>
              <p className="shrink-0 text-sm font-bold tabular-nums text-ink">
                {formatIdrOrUnavailable(tx.amountIdr)}
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-1.5">
              <FinanceSourceBadge source={tx.source} />
              <FinancePaymentStatusBadge status={tx.status} />
              <FinanceReconciliationBadge status={tx.reconciliationStatus} />
            </div>

            <div className="space-y-1 text-[11px] text-ink-soft">
              <p>
                Aktor: <span className="font-semibold text-ink">{tx.actorLabel}</span>
              </p>
              {direction === 'out' && (
                <p>
                  Rekening: {tx.bankAccountMasked || 'Tidak tersedia'} · Biaya:{' '}
                  {formatIdrOrUnavailable(tx.feeIdr)} · Net: {formatIdrOrUnavailable(tx.netAmountIdr)}
                </p>
              )}
            </div>

            <button
              type="button"
              onClick={() => onSelectTransaction(tx.id)}
              className="inline-flex h-9 w-full cursor-pointer items-center justify-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] text-xs font-semibold text-ink transition-colors hover:border-primary/40 hover:text-primary"
            >
              <Eye className="size-3.5" aria-hidden="true" />
              <span>Lihat Detail &amp; Timeline</span>
            </button>
          </li>
        ))}
      </ul>

      <div className="border-t border-[#E2E8F0] px-4 py-3">
        <TablePagination
          currentPage={page}
          totalItems={total}
          pageSize={pageSize}
          pageSizeOptions={[10, 20, 50, 100]}
          itemLabel="transaksi"
          ariaLabel="Paginasi transaksi keuangan"
          onPageChange={onPageChange}
          onPageSizeChange={onPageSizeChange}
        />
      </div>
    </div>
  )
}
