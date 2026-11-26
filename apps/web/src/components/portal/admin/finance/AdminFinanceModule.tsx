import {
  ArrowDownLeft,
  ArrowUpRight,
  Info,
  RefreshCw,
  Search,
  ShieldAlert,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router'
import { cn } from '@/lib/cn'
import {
  fetchAdminFinanceSummary,
  fetchAdminFinanceTransactions,
  setPortalSession,
} from '@/lib/portalStore'
import {
  getDefaultWibDateRange,
  isAuthUnauthorizedError,
  wibDateRangeToUtc,
} from '@/services/contracts/financeUtils'
import type {
  FinanceDirection,
  FinanceSource,
  FinanceSummary,
  FinanceTransaction,
} from '@/types/domain/finance'
import { FinanceSummaryCards } from './FinanceSummaryCards'
import { FinanceTransactionDetailModal } from './FinanceTransactionDetailModal'
import { FinanceTransactionsTable } from './FinanceTransactionsTable'

type FinanceTab = 'money_in' | 'money_out'

const MONEY_IN_STATUS_OPTIONS = [
  { value: '', label: 'Semua Status QRIS' },
  { value: 'paid', label: 'Lunas (paid)' },
  { value: 'pending', label: 'Menunggu Bayar (pending)' },
  { value: 'expired', label: 'Kedaluwarsa (expired)' },
  { value: 'failed', label: 'Gagal (failed)' },
] as const

const MONEY_OUT_STATUS_OPTIONS = [
  { value: '', label: 'Semua Status Keluar' },
  { value: 'requested', label: 'Diajukan (requested)' },
  { value: 'waiting_approval', label: 'Menunggu Approval (waiting_approval)' },
  { value: 'processing', label: 'Diproses (processing)' },
  { value: 'completed', label: 'Selesai (completed)' },
  { value: 'failed', label: 'Gagal (failed)' },
  { value: 'rejected', label: 'Ditolak (rejected)' },
  { value: 'cancelled', label: 'Dibatalkan (cancelled)' },
  { value: 'reversed', label: 'Reversal (reversed)' },
  { value: 'review_required', label: 'Perlu Tinjauan (review_required)' },
] as const

const MONEY_OUT_SOURCE_OPTIONS: ReadonlyArray<{ value: '' | FinanceSource; label: string }> = [
  { value: '', label: 'Semua Sumber Keluar' },
  { value: 'counselor_payout', label: 'Pencairan Psikolog' },
  { value: 'payment_refund', label: 'Refund Pembayaran' },
  { value: 'payout_reversal', label: 'Reversal Payout' },
]

export function AdminFinanceModule() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const defaultDates = useMemo(() => getDefaultWibDateRange(), [])

  const activeTab: FinanceTab =
    searchParams.get('tab') === 'money_out' ? 'money_out' : 'money_in'
  const direction: FinanceDirection = activeTab === 'money_out' ? 'out' : 'in'

  const fromDateWib = searchParams.get('from') || defaultDates.fromDate
  const toDateWib = searchParams.get('to') || defaultDates.toDate
  const statusFilter = searchParams.get('status') || ''
  const rawSource = searchParams.get('source') || ''
  const sourceFilter: FinanceSource | undefined =
    activeTab === 'money_out' &&
    (rawSource === 'counselor_payout' ||
      rawSource === 'payment_refund' ||
      rawSource === 'payout_reversal')
      ? rawSource
      : undefined
  const queryText = searchParams.get('q') || ''

  const rawPage = Number.parseInt(searchParams.get('page') || '1', 10)
  const page = Number.isFinite(rawPage) && rawPage > 0 ? rawPage : 1
  const rawPageSize = Number.parseInt(searchParams.get('page_size') || '20', 10)
  const pageSize = Number.isFinite(rawPageSize) && rawPageSize > 0 ? Math.min(100, rawPageSize) : 20

  const [prevQueryText, setPrevQueryText] = useState(queryText)
  const [searchInput, setSearchInput] = useState(queryText)
  if (queryText !== prevQueryText) {
    setPrevQueryText(queryText)
    setSearchInput(queryText)
  }

  const [reloadNonce, setReloadNonce] = useState(0)
  const [selectedTxId, setSelectedTxId] = useState<string | null>(null)

  const utcWindow = useMemo(() => {
    try {
      return wibDateRangeToUtc(fromDateWib, toDateWib)
    } catch {
      return wibDateRangeToUtc(defaultDates.fromDate, defaultDates.toDate)
    }
  }, [fromDateWib, toDateWib, defaultDates.fromDate, defaultDates.toDate])

  const summaryKey = `${utcWindow.from}|${utcWindow.to}|${reloadNonce}`
  const [summaryFetch, setSummaryFetch] = useState<{
    key: string
    data: FinanceSummary | null
    error: string | null
  }>({ key: '', data: null, error: null })

  const txKey = `${utcWindow.from}|${utcWindow.to}|${direction}|${activeTab}|${statusFilter}|${sourceFilter ?? ''}|${queryText}|${page}|${pageSize}|${reloadNonce}`
  const [txFetch, setTxFetch] = useState<{
    key: string
    items: FinanceTransaction[]
    total: number
    error: string | null
  }>({ key: '', items: [], total: 0, error: null })

  const summaryLoading = summaryFetch.key !== summaryKey
  const summary = summaryLoading ? null : summaryFetch.data
  const summaryError = summaryLoading ? null : summaryFetch.error

  const txLoading = txFetch.key !== txKey
  const items = txLoading ? [] : txFetch.items
  const total = txLoading ? 0 : txFetch.total
  const txError = txLoading ? null : txFetch.error

  const updateUrlParams = useCallback(
    (mutator: (next: URLSearchParams) => void) => {
      setSearchParams((prev) => {
        const next = new URLSearchParams(prev)
        mutator(next)
        return next
      })
    },
    [setSearchParams],
  )

  const handleUnauthorized = useCallback(() => {
    setPortalSession(null)
    navigate('/login', { replace: true })
  }, [navigate])

  const handleCloseDetail = useCallback(() => {
    setSelectedTxId(null)
  }, [])

  // Debounce search input into URL `q`
  useEffect(() => {
    const timer = window.setTimeout(() => {
      const normalized = searchInput.trim()
      if (normalized !== queryText) {
        updateUrlParams((next) => {
          if (normalized) next.set('q', normalized)
          else next.delete('q')
          next.delete('page')
        })
      }
    }, 300)
    return () => window.clearTimeout(timer)
  }, [searchInput, queryText, updateUrlParams])

  // Fetch Summary KPI
  useEffect(() => {
    const controller = new AbortController()

    fetchAdminFinanceSummary(
      { from: utcWindow.from, to: utcWindow.to },
      { signal: controller.signal },
    )
      .then((res) => {
        if (!controller.signal.aborted) {
          setSummaryFetch({ key: summaryKey, data: res, error: null })
        }
      })
      .catch((err) => {
        if (controller.signal.aborted) return
        if (isAuthUnauthorizedError(err)) {
          handleUnauthorized()
          return
        }
        setSummaryFetch({
          key: summaryKey,
          data: null,
          error: err instanceof Error ? err.message : 'Gagal memuat ringkasan keuangan.',
        })
      })

    return () => controller.abort()
  }, [summaryKey, utcWindow.from, utcWindow.to, handleUnauthorized])

  // Fetch Transactions List
  useEffect(() => {
    const controller = new AbortController()

    fetchAdminFinanceTransactions(
      {
        from: utcWindow.from,
        to: utcWindow.to,
        direction,
        status: statusFilter || undefined,
        source: activeTab === 'money_in' ? 'qris_topup' : sourceFilter,
        q: queryText || undefined,
        page,
        pageSize,
      },
      { signal: controller.signal },
    )
      .then((res) => {
        if (!controller.signal.aborted) {
          setTxFetch({
            key: txKey,
            items: res.items,
            total: res.total,
            error: null,
          })
        }
      })
      .catch((err) => {
        if (controller.signal.aborted) return
        if (isAuthUnauthorizedError(err)) {
          handleUnauthorized()
          return
        }
        setTxFetch({
          key: txKey,
          items: [],
          total: 0,
          error: err instanceof Error ? err.message : 'Gagal memuat transaksi keuangan.',
        })
      })

    return () => controller.abort()
  }, [
    txKey,
    utcWindow.from,
    utcWindow.to,
    direction,
    activeTab,
    statusFilter,
    sourceFilter,
    queryText,
    page,
    pageSize,
    handleUnauthorized,
  ])

  const statusOptions =
    activeTab === 'money_in' ? MONEY_IN_STATUS_OPTIONS : MONEY_OUT_STATUS_OPTIONS

  return (
    <div className="space-y-6">
      {/* Header & Refresh Action */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-ink">Uang Masuk, Uang Keluar &amp; Rekonsiliasi</h1>
          <p className="mt-1 text-xs text-ink-soft">
            Monitoring read-only arus kas QRIS top-up, pencairan honorarium psikolog, refund, dan status rekonsiliasi.
          </p>
        </div>

        <button
          type="button"
          onClick={() => setReloadNonce((n) => n + 1)}
          className="inline-flex h-10 shrink-0 cursor-pointer items-center gap-2 rounded-[10px] border border-[#CBD5E1] bg-white px-4 text-xs font-semibold text-ink shadow-2xs transition-colors hover:border-primary/40 hover:text-primary"
        >
          <RefreshCw
            className={cn('size-3.5', (summaryLoading || txLoading) && 'animate-spin text-primary')}
            aria-hidden="true"
          />
          <span>Muat Ulang Data</span>
        </button>
      </div>

      {/* Explicit Separation Guardrail Notice */}
      <div className="flex flex-col gap-2 rounded-[14px] border border-[#C7D2FE] bg-[#EEF0FF]/70 px-4 py-3 text-xs text-ink sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-start gap-2.5">
          <Info className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden="true" />
          <p>
            <strong>Arus kas riil terpisah dari Ledger Koin:</strong> Pemberian koin manual admin atau free trial di{' '}
            <button
              type="button"
              onClick={() => navigate('/admin/users-coins')}
              className="cursor-pointer font-bold text-primary underline underline-offset-2"
            >
              Pengguna &amp; Koin
            </button>{' '}
            tidak masuk hitungan uang masuk di halaman ini. Approval payout dilakukan terpisah di{' '}
            <strong>Iris Dashboard</strong>.
          </p>
        </div>
      </div>

      {/* Summary Error Alert (strict mode, never falls back to mock figures) */}
      {summaryError && (
        <div className="flex items-start gap-2.5 rounded-[14px] border border-rose-200 bg-rose-50 px-4 py-3 text-xs text-rose-900">
          <ShieldAlert className="mt-0.5 size-4 shrink-0 text-rose-700" aria-hidden="true" />
          <div>
            <p className="font-bold">Ringkasan keuangan tidak dapat dimuat dari server</p>
            <p className="mt-0.5">{summaryError}</p>
          </div>
        </div>
      )}

      {/* Summary KPI Sections */}
      <FinanceSummaryCards
        summary={summary}
        loading={summaryLoading}
        fromDateWib={fromDateWib}
        toDateWib={toDateWib}
      />

      {/* Direction Tabs + Filter Bar */}
      <div className="space-y-4">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <div role="tablist" aria-label="Arah arus kas" className="inline-flex rounded-[12px] border border-[#E2E8F0] bg-white p-1">
            <button
              id="finance-tab-money-in"
              type="button"
              role="tab"
              aria-selected={activeTab === 'money_in'}
              onClick={() =>
                updateUrlParams((next) => {
                  next.set('tab', 'money_in')
                  next.delete('source')
                  next.delete('status')
                  next.delete('page')
                })
              }
              className={cn(
                'inline-flex cursor-pointer items-center gap-1.5 rounded-[9px] px-4 py-2 text-xs font-bold',
                activeTab === 'money_in'
                  ? 'bg-primary text-white shadow-2xs'
                  : 'text-ink-soft hover:text-ink',
              )}
            >
              <ArrowDownLeft className="size-3.5" aria-hidden="true" />
              <span>Money In (QRIS Top-Up)</span>
            </button>

            <button
              id="finance-tab-money-out"
              type="button"
              role="tab"
              aria-selected={activeTab === 'money_out'}
              onClick={() =>
                updateUrlParams((next) => {
                  next.set('tab', 'money_out')
                  next.delete('status')
                  next.delete('page')
                })
              }
              className={cn(
                'inline-flex cursor-pointer items-center gap-1.5 rounded-[9px] px-4 py-2 text-xs font-bold',
                activeTab === 'money_out'
                  ? 'bg-primary text-white shadow-2xs'
                  : 'text-ink-soft hover:text-ink',
              )}
            >
              <ArrowUpRight className="size-3.5" aria-hidden="true" />
              <span>Money Out (Read-Only)</span>
            </button>
          </div>

          {/* WIB Date Range Inputs */}
          <div className="flex flex-wrap items-center gap-2 text-xs">
            <label className="flex items-center gap-1.5 rounded-[9px] border border-[#CBD5E1] bg-white px-2.5 py-1.5">
              <span className="font-semibold text-ink-muted">Dari (WIB)</span>
              <input
                type="date"
                value={fromDateWib}
                onChange={(e) => {
                  const val = e.target.value
                  if (!val) return
                  updateUrlParams((next) => {
                    next.set('from', val)
                    next.delete('page')
                  })
                }}
                className="bg-transparent font-semibold text-ink focus:outline-none"
              />
            </label>
            <label className="flex items-center gap-1.5 rounded-[9px] border border-[#CBD5E1] bg-white px-2.5 py-1.5">
              <span className="font-semibold text-ink-muted">Sampai (WIB)</span>
              <input
                type="date"
                value={toDateWib}
                onChange={(e) => {
                  const val = e.target.value
                  if (!val) return
                  updateUrlParams((next) => {
                    next.set('to', val)
                    next.delete('page')
                  })
                }}
                className="bg-transparent font-semibold text-ink focus:outline-none"
              />
            </label>
          </div>
        </div>

        {/* Filter Controls */}
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-[1fr_210px_210px]">
          <div className="relative">
            <Search
              className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-ink-muted"
              aria-hidden="true"
            />
            <input
              type="search"
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              placeholder="Cari Order ID, provider ref, atau nama aktor..."
              aria-label="Cari transaksi keuangan"
              className="h-10 w-full rounded-[10px] border border-[#CBD5E1] bg-white pr-3 pl-9 text-xs text-ink placeholder:text-ink-muted focus:border-primary focus:outline-none"
            />
          </div>

          <select
            aria-label="Filter status pembayaran"
            value={statusFilter}
            onChange={(e) =>
              updateUrlParams((next) => {
                if (e.target.value) next.set('status', e.target.value)
                else next.delete('status')
                next.delete('page')
              })
            }
            className="h-10 rounded-[10px] border border-[#CBD5E1] bg-white px-3 text-xs font-medium text-ink focus:border-primary focus:outline-none"
          >
            {statusOptions.map((opt) => (
              <option key={opt.value || 'all'} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>

          {activeTab === 'money_out' ? (
            <select
              aria-label="Filter sumber transaksi keluar"
              value={sourceFilter || ''}
              onChange={(e) =>
                updateUrlParams((next) => {
                  if (e.target.value) next.set('source', e.target.value)
                  else next.delete('source')
                  next.delete('page')
                })
              }
              className="h-10 rounded-[10px] border border-[#CBD5E1] bg-white px-3 text-xs font-medium text-ink focus:border-primary focus:outline-none"
            >
              {MONEY_OUT_SOURCE_OPTIONS.map((opt) => (
                <option key={opt.value || 'all'} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          ) : (
            <div className="flex h-10 items-center rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] px-3 text-xs font-medium text-ink-soft">
              Sumber: QRIS Top-Up Terkonfirmasi
            </div>
          )}
        </div>

        <FinanceTransactionsTable
          direction={direction}
          items={items}
          total={total}
          page={page}
          pageSize={pageSize}
          loading={txLoading}
          errorMessage={txError}
          onRetry={() => setReloadNonce((n) => n + 1)}
          onSelectTransaction={(id) => setSelectedTxId(id)}
          onPageChange={(nextPage) =>
            updateUrlParams((next) => {
              if (nextPage <= 1) next.delete('page')
              else next.set('page', String(nextPage))
            })
          }
          onPageSizeChange={(nextSize) =>
            updateUrlParams((next) => {
              next.set('page_size', String(nextSize))
              next.delete('page')
            })
          }
        />
      </div>

      <FinanceTransactionDetailModal
        transactionId={selectedTxId}
        onClose={handleCloseDetail}
        onUnauthorized={handleUnauthorized}
      />
    </div>
  )
}
