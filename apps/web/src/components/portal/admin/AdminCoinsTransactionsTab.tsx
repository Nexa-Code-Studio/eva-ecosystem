import {
  CheckCircle2,
  Clock,
  Coins,
  Plus,
  RotateCcw,
  Search,
  Sparkles,
  Wallet,
  XCircle,
} from 'lucide-react'
import { useMemo, useRef, useState } from 'react'
import { AdminActionConfirmModal, type ConfirmDialogTone } from './AdminActionConfirmModal'
import { TablePagination } from '@/components/portal/TablePagination'
import { useUrlPagination } from '@/hooks/useUrlPagination'
import { cn } from '@/lib/cn'
import {
  reviewCoinTransaction,
  type CoinTopupTransaction,
  type CoinTransactionStatus,
  type PortalDatabase,
} from '@/lib/portalStore'

interface AdminCoinsTransactionsTabProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
  onOpenGlobalTopup?: () => void
}

type TrxFilter = 'all' | 'pending' | 'completed' | 'refunded_failed'

interface PendingTrxReview {
  trx: CoinTopupTransaction
  nextStatus: CoinTransactionStatus
}

function getReviewModalConfig(trx: CoinTopupTransaction, nextStatus: CoinTransactionStatus): {
  title: string
  confirmLabel: string
  tone: ConfirmDialogTone
  impactSummary: string
  defaultNote: string
} {
  if (nextStatus === 'completed') {
    return {
      title: `Konfirmasi Pelunasan ${trx.invoiceCode}?`,
      confirmLabel: 'Ya, Konfirmasi Lunas',
      tone: 'emerald',
      impactSummary: `Saldo user ${trx.userDisplayName} (${trx.userCode}) akan otomatis bertambah +${trx.coinsGranted} Koin senilai Rp${trx.amountIdr.toLocaleString('id-ID')}.`,
      defaultNote: 'Dikonfirmasi lunas oleh Admin. Saldo koin pengguna otomatis ditambahkan.',
    }
  }
  if (nextStatus === 'refunded') {
    return {
      title: `Tandai Refund Transaksi ${trx.invoiceCode}?`,
      confirmLabel: 'Ya, Proses Refund',
      tone: 'amber',
      impactSummary: `Transaksi senilai Rp${trx.amountIdr.toLocaleString('id-ID')} (${trx.coinsGranted} Koin) milik ${trx.userDisplayName} akan ditandai sebagai Refund dan penyesuaian saldo tercatat.`,
      defaultNote: 'Dana dikembalikan (Refund) oleh Admin dan saldo koin telah disesuaikan.',
    }
  }
  return {
    title: `Batalkan Transaksi ${trx.invoiceCode}?`,
    confirmLabel: 'Ya, Batalkan Transaksi',
    tone: 'danger',
    impactSummary: `Permintaan top-up +${trx.coinsGranted} Koin untuk ${trx.userDisplayName} dibatalkan tanpa penambahan saldo koin.`,
    defaultNote: 'Transaksi dibatalkan oleh Admin.',
  }
}

function TransactionStatusBadge({ status }: { status: CoinTransactionStatus }) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-[6px] px-2 py-0.5 text-[11px] font-semibold',
        status === 'completed'
          ? 'bg-emerald-50 text-emerald-800'
          : status === 'pending'
            ? 'bg-amber-50 text-amber-800'
            : 'bg-slate-100 text-ink-soft',
      )}
    >
      {status === 'completed' && <CheckCircle2 className="size-3" aria-hidden="true" />}
      {status === 'pending' && <Clock className="size-3" aria-hidden="true" />}
      {(status === 'refunded' || status === 'failed') && (
        <XCircle className="size-3" aria-hidden="true" />
      )}
      <span>
        {status === 'completed'
          ? 'Berhasil'
          : status === 'pending'
            ? 'Menunggu Pembayaran'
            : status === 'refunded'
              ? 'Refund'
              : 'Dibatalkan'}
      </span>
    </span>
  )
}

export function AdminCoinsTransactionsTab({
  db,
  onFeedback,
  onOpenGlobalTopup,
}: AdminCoinsTransactionsTabProps) {
  const [trxFilter, setTrxFilter] = useState<TrxFilter>('all')
  const [trxSearch, setTrxSearch] = useState('')
  const [pendingReview, setPendingReview] = useState<PendingTrxReview | null>(null)
  const transactionsCardRef = useRef<HTMLDivElement>(null)

  const kpiStats = useMemo(() => {
    const completedTrx = db.coinTransactions.filter(
      (t) => t.status === 'completed' && t.amountIdr > 0,
    )
    const totalRevenueIdr = completedTrx.reduce((sum, t) => sum + t.amountIdr, 0)
    const totalCoinsSold = completedTrx.reduce((sum, t) => sum + t.coinsGranted, 0)
    const pendingCount = db.coinTransactions.filter((t) => t.status === 'pending').length
    const circulatingCoins = db.generalUsers.reduce(
      (sum, u) => sum + (u.coinBalance ?? 0),
      0,
    )
    const totalMinutesUsed = db.generalUsers.reduce(
      (sum, u) => sum + (u.totalVoiceMinutesUsed ?? 0),
      0,
    )

    return {
      totalRevenueIdr,
      totalCoinsSold,
      pendingCount,
      circulatingCoins,
      totalMinutesUsed,
    }
  }, [db.coinTransactions, db.generalUsers])

  const filteredTransactions = useMemo(() => {
    const q = trxSearch.trim().toLowerCase()
    return db.coinTransactions.filter((t) => {
      if (trxFilter === 'pending' && t.status !== 'pending') return false
      if (trxFilter === 'completed' && t.status !== 'completed') return false
      if (
        trxFilter === 'refunded_failed' &&
        t.status !== 'refunded' &&
        t.status !== 'failed'
      ) {
        return false
      }

      if (!q) return true
      return (
        t.invoiceCode.toLowerCase().includes(q) ||
        t.userDisplayName.toLowerCase().includes(q) ||
        t.userCode.toLowerCase().includes(q) ||
        t.packageName.toLowerCase().includes(q) ||
        t.paymentMethod.toLowerCase().includes(q)
      )
    })
  }, [db.coinTransactions, trxFilter, trxSearch])

  const {
    pageSize,
    safePage,
    paginatedItems: paginatedTransactions,
    resetPage,
    handlePageChange,
    handlePageSizeChange,
  } = useUrlPagination(filteredTransactions, {
    defaultPageSize: 10,
    scrollTargetRef: transactionsCardRef,
  })

  const handleFilterChange = (nextFilter: TrxFilter) => {
    setTrxFilter(nextFilter)
    resetPage()
  }

  const handleSearchChange = (value: string) => {
    setTrxSearch(value)
    resetPage()
  }

  const resetAllFilters = () => {
    setTrxFilter('all')
    setTrxSearch('')
    resetPage()
  }

  const isFiltered = trxFilter !== 'all' || Boolean(trxSearch.trim())

  const renderTransactionActions = (trx: CoinTopupTransaction, mobile = false) => {
    const btnHeight = mobile ? 'min-h-11 px-3 text-xs' : 'h-7 px-2.5 text-[11px]'

    if (trx.status === 'pending') {
      return (
        <div className={cn('flex flex-wrap items-center gap-1.5', mobile ? 'w-full' : 'inline-flex justify-end')}>
          <button
            type="button"
            onClick={() => setPendingReview({ trx, nextStatus: 'completed' })}
            className={cn(
              'inline-flex cursor-pointer items-center justify-center gap-1 rounded-[6px] bg-[#047857] font-semibold whitespace-nowrap text-white hover:bg-[#065F46]',
              btnHeight,
              mobile && 'flex-1',
            )}
          >
            <CheckCircle2 className="size-3.5 shrink-0" aria-hidden="true" />
            <span>Konfirmasi Lunas</span>
          </button>
          <button
            type="button"
            onClick={() => setPendingReview({ trx, nextStatus: 'failed' })}
            className={cn(
              'inline-flex cursor-pointer items-center justify-center gap-1 rounded-[6px] border border-[#768396] bg-white font-semibold whitespace-nowrap text-ink-soft hover:bg-slate-50 hover:text-ink',
              btnHeight,
              mobile && 'flex-1',
            )}
          >
            Batalkan
          </button>
        </div>
      )
    }

    if (trx.status === 'completed' && trx.amountIdr > 0) {
      return (
        <button
          type="button"
          onClick={() => setPendingReview({ trx, nextStatus: 'refunded' })}
          className={cn(
            'inline-flex cursor-pointer items-center justify-center gap-1 rounded-[6px] border border-[#768396] bg-white font-semibold whitespace-nowrap text-ink-soft hover:border-[#B45309] hover:text-ink',
            btnHeight,
            mobile && 'w-full',
          )}
        >
          <RotateCcw className="size-3.5 shrink-0" aria-hidden="true" />
          <span>Tandai Refund</span>
        </button>
      )
    }

    return <span className="text-[11px] text-ink-muted">Selesai</span>
  }

  return (
    <div className="mt-5 space-y-5">
      {/* 1. Adaptive KPI Summary Cards (2-col Mobile/Tablet, 4-col Desktop) */}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4 lg:gap-3.5">
        <div className="min-w-0 rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 sm:p-4">
          <div className="flex items-start justify-between gap-2">
            <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase sm:text-[11px]">
              Pendapatan Top-Up
            </span>
            <span
              aria-hidden="true"
              className="flex size-7 shrink-0 items-center justify-center rounded-[8px] bg-emerald-50 text-[#047857] sm:size-8"
            >
              <Wallet className="size-3.5 sm:size-4" aria-hidden="true" />
            </span>
          </div>
          <p className="mt-2 truncate text-base font-bold text-ink sm:text-xl">
            Rp{kpiStats.totalRevenueIdr.toLocaleString('id-ID')}
          </p>
          <p className="mt-0.5 text-[11px] text-ink-muted sm:text-xs">
            {kpiStats.totalCoinsSold.toLocaleString('id-ID')} koin terjual
          </p>
        </div>

        <div className="min-w-0 rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 sm:p-4">
          <div className="flex items-start justify-between gap-2">
            <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase sm:text-[11px]">
              Koin Beredar
            </span>
            <span
              aria-hidden="true"
              className="flex size-7 shrink-0 items-center justify-center rounded-[8px] bg-[#EEF0FF] text-primary sm:size-8"
            >
              <Coins className="size-3.5 sm:size-4" aria-hidden="true" />
            </span>
          </div>
          <p className="mt-2 truncate text-base font-bold text-ink sm:text-xl">
            {kpiStats.circulatingCoins.toLocaleString('id-ID')} Koin
          </p>
          <p className="mt-0.5 text-[11px] text-ink-muted sm:text-xs">
            {kpiStats.totalMinutesUsed.toLocaleString('id-ID')} mnt terpakai
          </p>
        </div>

        <div className="min-w-0 rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 sm:p-4">
          <div className="flex items-start justify-between gap-2">
            <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase sm:text-[11px]">
              Antrean Top-Up
            </span>
            <span
              aria-hidden="true"
              className="flex size-7 shrink-0 items-center justify-center rounded-[8px] bg-amber-50 text-[#B45309] sm:size-8"
            >
              <Clock className="size-3.5 sm:size-4" aria-hidden="true" />
            </span>
          </div>
          <p className="mt-2 truncate text-base font-bold text-ink sm:text-xl">
            {kpiStats.pendingCount} Transaksi
          </p>
          <p className="mt-0.5 text-[11px] text-ink-muted sm:text-xs">
            Menunggu verifikasi admin
          </p>
        </div>

        <div className="min-w-0 rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 sm:p-4">
          <div className="flex items-start justify-between gap-2">
            <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase sm:text-[11px]">
              Kurs EVA Coin
            </span>
            <span
              aria-hidden="true"
              className="flex size-7 shrink-0 items-center justify-center rounded-[8px] bg-[#EEF0FF] text-primary sm:size-8"
            >
              <Sparkles className="size-3.5 sm:size-4" aria-hidden="true" />
            </span>
          </div>
          <p className="mt-2 truncate text-base font-bold text-ink sm:text-xl">
            Rp{db.coinEconomyConfig.basePricePerCoinIdr.toLocaleString('id-ID')}
          </p>
          <p className="mt-0.5 text-[11px] text-ink-muted sm:text-xs">
            Per koin · Trial {db.coinEconomyConfig.freeTrialCoinsNewUser} Koin
          </p>
        </div>
      </div>

      {/* 2. Top-Up Transactions History */}
      <div className="space-y-3">
        <div
          ref={transactionsCardRef}
          className="overflow-hidden rounded-[12px] border border-[#E2E8F0] bg-white"
        >
          <div className="flex flex-col gap-3 border-b border-[#E2E8F0] p-4">
            <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
              <div>
                <h2 className="text-sm font-bold text-ink">
                  Riwayat Transaksi Top-Up Koin Pengguna
                </h2>
                <p className="text-xs text-ink-muted">
                  Verifikasi pembayaran masuk dan pantau distribusi EVA Coin ke akun pengguna.
                </p>
              </div>

              {onOpenGlobalTopup && (
                <button
                  type="button"
                  onClick={onOpenGlobalTopup}
                  className="inline-flex min-h-11 shrink-0 cursor-pointer items-center justify-center gap-1.5 rounded-[8px] bg-primary px-3.5 text-xs font-semibold text-white shadow-2xs transition-colors hover:bg-primary-hover sm:h-9 sm:min-h-0"
                >
                  <Plus className="size-3.5" aria-hidden="true" />
                  <span>Top-Up Manual</span>
                </button>
              )}
            </div>

            <div className="flex flex-col justify-between gap-2.5 lg:flex-row lg:items-center">
              <div className="flex flex-wrap items-center gap-1.5">
                {(
                  [
                    { id: 'all', label: `Semua (${db.coinTransactions.length})` },
                    {
                      id: 'pending',
                      label: `Menunggu (${db.coinTransactions.filter((t) => t.status === 'pending').length})`,
                    },
                    {
                      id: 'completed',
                      label: `Berhasil (${db.coinTransactions.filter((t) => t.status === 'completed').length})`,
                    },
                    {
                      id: 'refunded_failed',
                      label: `Refund/Batal (${db.coinTransactions.filter((t) => t.status === 'refunded' || t.status === 'failed').length})`,
                    },
                  ] as const
                ).map((tab) => (
                  <button
                    key={tab.id}
                    type="button"
                    aria-pressed={trxFilter === tab.id}
                    onClick={() => handleFilterChange(tab.id)}
                    className={cn(
                      'min-h-11 cursor-pointer rounded-[6px] border px-2.5 py-1 text-xs font-semibold transition-colors sm:min-h-8',
                      trxFilter === tab.id
                        ? 'border-primary bg-[#EEF0FF] text-primary'
                        : 'border-[#768396] bg-white text-ink-soft hover:text-ink',
                    )}
                  >
                    {tab.label}
                  </button>
                ))}
              </div>

              <div className="relative w-full lg:w-68">
                <label htmlFor="trx-search-input" className="sr-only">
                  Cari invoice, nama pengguna, atau metode pembayaran
                </label>
                <Search
                  className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted"
                  aria-hidden="true"
                />
                <input
                  id="trx-search-input"
                  type="search"
                  value={trxSearch}
                  onChange={(e) => handleSearchChange(e.target.value)}
                  placeholder="Cari invoice, pengguna, metode..."
                  className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink focus:border-primary focus:bg-white focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                />
              </div>
            </div>
          </div>

          {paginatedTransactions.length === 0 ? (
            <div className="px-4 py-8 text-center text-xs text-ink-soft">
              <p className="font-semibold text-ink">
                {isFiltered
                  ? 'Tidak ada transaksi top-up koin yang sesuai dengan filter pencarian.'
                  : 'Belum ada riwayat transaksi top-up koin.'}
              </p>
              <p className="mt-1 text-ink-muted">
                {isFiltered
                  ? 'Ubah filter status atau kata kunci pencarian untuk melihat transaksi lainnya.'
                  : 'Gunakan tombol Top-Up Manual untuk mencatat penambahan koin ke pengguna.'}
              </p>
              {isFiltered && (
                <button
                  type="button"
                  onClick={resetAllFilters}
                  className="mt-3 inline-flex min-h-11 cursor-pointer items-center rounded-[8px] border border-[#768396] bg-white px-3 text-xs font-semibold text-ink hover:bg-[#F8FAFC] sm:h-8 sm:min-h-0"
                >
                  Reset Filter &amp; Pencarian
                </button>
              )}
            </div>
          ) : (
            <>
              {/* Mobile Card View (< md) */}
              <div className="divide-y divide-[#E2E8F0] md:hidden">
                {paginatedTransactions.map((trx) => (
                  <div key={trx.id} className="space-y-3 p-4 text-xs">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="truncate font-mono font-bold text-ink">{trx.invoiceCode}</p>
                        <p className="text-[11px] text-ink-muted">{trx.createdAt}</p>
                      </div>
                      <TransactionStatusBadge status={trx.status} />
                    </div>

                    <div className="flex flex-wrap items-center justify-between gap-2 rounded-[8px] bg-[#F8FAFC] p-2.5">
                      <div className="min-w-0">
                        <p className="truncate font-semibold text-ink">{trx.userDisplayName}</p>
                        <p className="font-mono text-[11px] text-ink-muted">{trx.userCode}</p>
                      </div>
                      <div className="text-right">
                        <p className="font-bold text-ink">
                          {trx.amountIdr > 0
                            ? `Rp${trx.amountIdr.toLocaleString('id-ID')}`
                            : 'Grant Admin'}
                        </p>
                        <p className="text-[11px] text-ink-muted">Via {trx.paymentMethod}</p>
                      </div>
                    </div>

                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span className="font-semibold text-ink">{trx.packageName}</span>
                      <span className="inline-flex items-center gap-1 rounded-[5px] bg-[#EEF0FF] px-2 py-0.5 text-[11px] font-bold text-primary">
                        <Coins className="size-3" aria-hidden="true" /> +{trx.coinsGranted} Koin
                      </span>
                    </div>

                    {trx.adminNotes && (
                      <p className="text-[11px] leading-relaxed text-ink-muted">{trx.adminNotes}</p>
                    )}

                    <div className="pt-1">{renderTransactionActions(trx, true)}</div>
                  </div>
                ))}
              </div>

              {/* Desktop Table View (>= md) */}
              <div className="hidden overflow-x-auto md:block">
                <table className="w-full border-collapse text-left">
                  <thead>
                    <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                      <th className="px-4 py-3">Invoice &amp; Waktu</th>
                      <th className="px-4 py-3">Pengguna</th>
                      <th className="px-4 py-3">Paket &amp; Kuota Koin</th>
                      <th className="px-4 py-3">Nominal &amp; Metode</th>
                      <th className="px-4 py-3">Status</th>
                      <th className="px-4 py-3 text-right">Tindakan Admin</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-[#E2E8F0] text-xs">
                    {paginatedTransactions.map((trx) => (
                      <tr key={trx.id} className="hover:bg-[#F8FAFC]">
                        <td className="px-4 py-3.5">
                          <p className="font-mono font-bold text-ink">{trx.invoiceCode}</p>
                          <p className="text-[11px] text-ink-muted">{trx.createdAt}</p>
                        </td>
                        <td className="px-4 py-3.5">
                          <p className="font-semibold text-ink">{trx.userDisplayName}</p>
                          <p className="font-mono text-[11px] text-ink-muted">{trx.userCode}</p>
                        </td>
                        <td className="px-4 py-3.5">
                          <p className="font-semibold text-ink">{trx.packageName}</p>
                          <span className="mt-0.5 inline-flex items-center gap-1 rounded-[5px] bg-[#EEF0FF] px-2 py-0.5 text-[11px] font-bold text-primary">
                            <Coins className="size-3" aria-hidden="true" /> +{trx.coinsGranted} Koin ({trx.coinsGranted} mnt)
                          </span>
                        </td>
                        <td className="px-4 py-3.5">
                          <p className="font-bold text-ink">
                            {trx.amountIdr > 0
                              ? `Rp${trx.amountIdr.toLocaleString('id-ID')}`
                              : 'Gratis (Grant Admin)'}
                          </p>
                          <p className="text-[11px] text-ink-muted">Via {trx.paymentMethod}</p>
                        </td>
                        <td className="px-4 py-3.5">
                          <TransactionStatusBadge status={trx.status} />
                          {trx.adminNotes && (
                            <p className="mt-1 max-w-xs text-[11px] text-ink-muted">
                              {trx.adminNotes}
                            </p>
                          )}
                        </td>
                        <td className="px-4 py-3.5 text-right">
                          {renderTransactionActions(trx, false)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </div>

        <TablePagination
          currentPage={safePage}
          totalItems={filteredTransactions.length}
          pageSize={pageSize}
          pageSizeOptions={[5, 10, 25, 50]}
          itemLabel="transaksi"
          ariaLabel="Paginasi riwayat transaksi koin"
          onPageChange={handlePageChange}
          onPageSizeChange={handlePageSizeChange}
        />
      </div>

      {pendingReview && (
        <AdminActionConfirmModal
          key={`${pendingReview.trx.id}-${pendingReview.nextStatus}`}
          isOpen
          title={getReviewModalConfig(pendingReview.trx, pendingReview.nextStatus).title}
          description={`Tinjauan transaksi untuk ${pendingReview.trx.userDisplayName} (${pendingReview.trx.packageName}).`}
          impactSummary={
            getReviewModalConfig(pendingReview.trx, pendingReview.nextStatus).impactSummary
          }
          confirmLabel={
            getReviewModalConfig(pendingReview.trx, pendingReview.nextStatus).confirmLabel
          }
          tone={getReviewModalConfig(pendingReview.trx, pendingReview.nextStatus).tone}
          showNoteInput
          noteLabel="Catatan Audit Admin"
          initialNote={getReviewModalConfig(pendingReview.trx, pendingReview.nextStatus).defaultNote}
          onClose={() => setPendingReview(null)}
          onConfirm={(note) => {
            const fallbackNote = getReviewModalConfig(
              pendingReview.trx,
              pendingReview.nextStatus,
            ).defaultNote
            reviewCoinTransaction(
              pendingReview.trx.id,
              pendingReview.nextStatus,
              note || fallbackNote,
            )
            onFeedback(
              `Status transaksi "${pendingReview.trx.invoiceCode}" diperbarui menjadi ${pendingReview.nextStatus.toUpperCase()}.`,
            )
          }}
        />
      )}
    </div>
  )
}
