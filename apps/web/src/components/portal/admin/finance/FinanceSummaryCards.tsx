import { AlertTriangle, Calendar, Clock } from 'lucide-react'
import { cn } from '@/lib/cn'
import {
  formatIdrOrUnavailable,
  formatTimestampWib,
} from '@/services/contracts/financeUtils'
import type { FinanceSummary } from '@/types/domain/finance'

interface FinanceSummaryCardsProps {
  summary: FinanceSummary | null
  loading: boolean
  fromDateWib: string
  toDateWib: string
}

interface MetricCell {
  id: string
  label: string
  valueText: string
  isUnavailable?: boolean
  hint?: string
  tone?: 'default' | 'positive' | 'warning'
}

export function FinanceSummaryCards({
  summary,
  loading,
  fromDateWib,
  toDateWib,
}: FinanceSummaryCardsProps) {
  const periodMetrics: MetricCell[] = [
    {
      id: 'money_in_paid_idr',
      label: 'Uang Masuk Lunas (QRIS)',
      valueText: summary ? formatIdrOrUnavailable(summary.moneyInPaidIdr) : '-',
      tone: 'positive',
    },
    {
      id: 'money_in_pending_idr',
      label: 'Uang Masuk Tertunda',
      valueText: summary ? formatIdrOrUnavailable(summary.moneyInPendingIdr) : '-',
    },
    {
      id: 'money_out_completed_idr',
      label: 'Payout Selesai',
      valueText: summary ? formatIdrOrUnavailable(summary.moneyOutCompletedIdr) : '-',
    },
    {
      id: 'money_out_pending_idr',
      label: 'Payout Tertunda',
      valueText: summary ? formatIdrOrUnavailable(summary.moneyOutPendingIdr) : '-',
    },
    {
      id: 'refund_completed_idr',
      label: 'Refund Selesai',
      valueText: summary ? formatIdrOrUnavailable(summary.refundCompletedIdr) : '-',
    },
    {
      id: 'commission_earned_idr',
      label: 'Komisi Platform',
      valueText: summary ? formatIdrOrUnavailable(summary.commissionEarnedIdr) : '-',
    },
    {
      id: 'provider_fees_known_idr',
      label: 'Biaya Provider Tercatat',
      valueText: summary ? formatIdrOrUnavailable(summary.providerFeesKnownIdr) : '-',
      isUnavailable: summary ? summary.providerFeesKnownIdr === null : false,
    },
  ]

  const snapshotMetrics: MetricCell[] = [
    {
      id: 'client_credit_liability_idr',
      label: 'Kewajiban Koin Pengguna',
      valueText: summary ? formatIdrOrUnavailable(summary.clientCreditLiabilityIdr) : '-',
      hint: 'Nilai koin aktif pengguna belum terpakai',
    },
    {
      id: 'counselor_payable_idr',
      label: 'Honorarium Psikolog Terutang',
      valueText: summary ? formatIdrOrUnavailable(summary.counselorPayableIdr) : '-',
      hint: 'Saldo konselor siap atau menunggu cair',
    },
    {
      id: 'unreconciled_count',
      label: 'Butuh Rekonsiliasi',
      valueText: summary ? `${summary.unreconciledCount} transaksi` : '-',
      tone: summary && summary.unreconciledCount > 0 ? 'warning' : 'default',
      hint: 'Status selisih atau perlu tinjauan',
    },
    {
      id: 'provider_payout_available_idr',
      label: 'Saldo Payout Provider',
      valueText: summary ? formatIdrOrUnavailable(summary.providerPayoutAvailableIdr) : '-',
      isUnavailable: summary ? summary.providerPayoutAvailableIdr === null : false,
      hint: summary?.providerBalanceAsOf
        ? `Per ${formatTimestampWib(summary.providerBalanceAsOf)}`
        : 'Timestamp saldo belum tersedia',
    },
  ]

  return (
    <div className="space-y-4">
      {/* Group 1: Period Cash Flow [from, to) */}
      <section
        aria-label="Ringkasan arus kas periode"
        className="overflow-hidden rounded-[16px] border border-[#E2E8F0] bg-white shadow-2xs"
      >
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[#E2E8F0] bg-[#F8FAFC] px-4 py-3 sm:px-5">
          <div className="flex items-center gap-2">
            <Calendar className="size-4 text-primary" aria-hidden="true" />
            <h2 className="text-xs font-bold tracking-wide text-ink uppercase">
              Arus Kas Periode [from, to)
            </h2>
          </div>
          <span className="text-xs font-medium text-ink-soft">
            {fromDateWib} s.d. {toDateWib} WIB
          </span>
        </div>

        <div className="grid grid-cols-2 divide-x divide-y divide-[#E2E8F0] sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7 xl:divide-y-0">
          {periodMetrics.map((m) => (
            <div key={m.id} data-metric-id={m.id} className="p-4">
              <p className="text-[11px] font-semibold text-ink-soft">{m.label}</p>
              <p
                className={cn(
                  'mt-1.5 text-base font-bold tabular-nums',
                  loading && !summary && 'animate-pulse text-ink-muted',
                  m.isUnavailable
                    ? 'text-xs font-medium italic text-ink-muted'
                    : m.tone === 'positive'
                      ? 'text-emerald-700'
                      : 'text-ink',
                )}
              >
                {m.valueText}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* Group 2: Snapshot Position (as_of) */}
      <section
        aria-label="Posisi saldo dan rekonsiliasi saat ini"
        className="overflow-hidden rounded-[16px] border border-[#E2E8F0] bg-white shadow-2xs"
      >
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[#E2E8F0] bg-[#F8FAFC] px-4 py-3 sm:px-5">
          <div className="flex items-center gap-2">
            <Clock className="size-4 text-primary" aria-hidden="true" />
            <h2 className="text-xs font-bold tracking-wide text-ink uppercase">
              Posisi Saldo &amp; Rekonsiliasi (Snapshot)
            </h2>
          </div>
          <span className="text-xs text-ink-soft">
            Otoritas angka langsung dari summary backend, bukan total halaman tabel
          </span>
        </div>

        <div className="grid grid-cols-1 divide-y divide-[#E2E8F0] sm:grid-cols-2 sm:divide-x lg:grid-cols-4 lg:divide-y-0">
          {snapshotMetrics.map((m) => (
            <div key={m.id} data-metric-id={m.id} className="p-4 sm:px-5">
              <p className="text-[11px] font-semibold text-ink-soft">{m.label}</p>
              <div className="mt-1.5 flex items-center gap-2">
                {m.tone === 'warning' && (
                  <AlertTriangle className="size-4 shrink-0 text-rose-600" aria-hidden="true" />
                )}
                <p
                  className={cn(
                    'text-base font-bold tabular-nums',
                    m.isUnavailable
                      ? 'text-xs font-medium italic text-ink-muted'
                      : m.tone === 'warning'
                        ? 'text-rose-700'
                        : 'text-ink',
                  )}
                >
                  {m.valueText}
                </p>
              </div>
              {m.hint && <p className="mt-1 text-[11px] text-ink-muted">{m.hint}</p>}
            </div>
          ))}
        </div>
      </section>
    </div>
  )
}
