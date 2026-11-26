import { AlertTriangle, Clock, Loader2, ShieldCheck, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { fetchAdminFinanceTransactionDetail } from '@/lib/portalStore'
import {
  formatIdrOrUnavailable,
  formatTimestampWib,
} from '@/services/contracts/financeUtils'
import type { FinanceTransactionDetail } from '@/types/domain/finance'
import {
  FinancePaymentStatusBadge,
  FinanceReconciliationBadge,
  FinanceSourceBadge,
} from './FinanceStatusBadges'

interface FinanceTransactionDetailModalProps {
  transactionId: string | null
  onClose: () => void
  onUnauthorized?: () => void
}

export function FinanceTransactionDetailModal({
  transactionId,
  onClose,
  onUnauthorized,
}: FinanceTransactionDetailModalProps) {
  const [fetchState, setFetchState] = useState<{
    txId: string | null
    detail: FinanceTransactionDetail | null
    errorMessage: string | null
  }>({ txId: null, detail: null, errorMessage: null })

  useBodyScrollLock(Boolean(transactionId))

  useEffect(() => {
    if (!transactionId) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [transactionId, onClose])

  useEffect(() => {
    if (!transactionId) return

    const controller = new AbortController()
    fetchAdminFinanceTransactionDetail(transactionId, { signal: controller.signal })
      .then((res) => {
        if (!controller.signal.aborted) {
          setFetchState({ txId: transactionId, detail: res, errorMessage: null })
        }
      })
      .catch((err) => {
        if (controller.signal.aborted) return
        if (err && typeof err === 'object' && 'status' in err && (err as { status: number }).status === 401) {
          onUnauthorized?.()
        }
        setFetchState({
          txId: transactionId,
          detail: null,
          errorMessage: err instanceof Error ? err.message : 'Gagal memuat detail transaksi.',
        })
      })

    return () => controller.abort()
  }, [transactionId, onUnauthorized])

  if (!transactionId) return null

  const loading = fetchState.txId !== transactionId
  const detail = loading ? null : fetchState.detail
  const errorMessage = loading ? null : fetchState.errorMessage

  return (
    <div
      data-lenis-prevent
      className="fixed inset-0 z-[70] flex items-center justify-center overscroll-contain bg-ink/50 p-3 backdrop-blur-xs sm:p-5"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="finance-detail-title"
        data-lenis-prevent
        className="relative max-h-[88dvh] w-full max-w-2xl overflow-y-auto overscroll-contain rounded-[18px] border border-[#E2E8F0] bg-white p-5 shadow-2xl sm:p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-4 border-b border-[#E2E8F0] pb-4">
          <div>
            <p className="text-[11px] font-bold tracking-wider text-primary uppercase">
              Detail Audit Keuangan (Read-Only)
            </p>
            <h2 id="finance-detail-title" className="mt-1 font-mono text-base font-bold text-ink">
              {detail?.referenceId ?? transactionId}
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup modal detail transaksi"
            className="flex size-9 shrink-0 cursor-pointer items-center justify-center rounded-full border border-[#E2E8F0] text-ink-soft transition-colors hover:bg-[#F8FAFC] hover:text-ink"
          >
            <X className="size-4" />
          </button>
        </div>

        {loading ? (
          <div className="flex items-center justify-center gap-2 py-12 text-xs font-medium text-ink-soft">
            <Loader2 className="size-4 animate-spin text-primary" aria-hidden="true" />
            <span>Mengambil jejak rekonsiliasi transaksi...</span>
          </div>
        ) : errorMessage ? (
          <div className="mt-4 rounded-[12px] border border-rose-200 bg-rose-50 p-4 text-xs text-rose-800">
            <p className="font-bold">Gagal memuat detail</p>
            <p className="mt-1">{errorMessage}</p>
          </div>
        ) : detail ? (
          <div className="mt-4 space-y-5 text-xs">
            {/* Status Row */}
            <div className="flex flex-wrap items-center gap-2">
              <FinanceSourceBadge source={detail.source} />
              <FinancePaymentStatusBadge status={detail.status} />
              <FinanceReconciliationBadge status={detail.reconciliationStatus} />
            </div>

            {(detail.reconciliationStatus === 'mismatch' ||
              detail.reconciliationStatus === 'review_required') && (
              <div className="flex items-start gap-2.5 rounded-[12px] border border-rose-200 bg-rose-50 p-3.5 text-rose-900">
                <AlertTriangle className="mt-0.5 size-4 shrink-0 text-rose-700" aria-hidden="true" />
                <div>
                  <p className="font-bold">Catatan Investigasi Rekonsiliasi (Read-Only)</p>
                  <p className="mt-0.5 leading-relaxed">
                    Transaksi ini ditandai untuk pengecekan manual antara catatan backend dan dashboard
                    provider. Portal web tidak menyediakan mutasi saldo atau penyesuaian langsung.
                  </p>
                </div>
              </div>
            )}

            {/* Financial & Provider Metadata Grid */}
            <div className="grid gap-3 rounded-[14px] border border-[#E2E8F0] bg-[#F8FAFC] p-4 sm:grid-cols-2">
              <div>
                <p className="text-[11px] font-semibold text-ink-muted">Aktor</p>
                <p className="mt-0.5 font-semibold text-ink">{detail.actorLabel}</p>
              </div>
              <div>
                <p className="text-[11px] font-semibold text-ink-muted">Referensi Provider Aman</p>
                <p className="mt-0.5 font-mono text-ink">
                  {detail.providerReference || 'Tidak tersedia'}
                </p>
              </div>
              <div>
                <p className="text-[11px] font-semibold text-ink-muted">Nominal Bruto (IDR)</p>
                <p className="mt-0.5 font-bold tabular-nums text-ink">
                  {formatIdrOrUnavailable(detail.amountIdr)}
                </p>
              </div>
              <div>
                <p className="text-[11px] font-semibold text-ink-muted">Biaya Provider (Fee)</p>
                <p className="mt-0.5 font-semibold tabular-nums text-ink">
                  {formatIdrOrUnavailable(detail.feeIdr)}
                </p>
              </div>
              <div>
                <p className="text-[11px] font-semibold text-ink-muted">Nominal Bersih (Net)</p>
                <p className="mt-0.5 font-semibold tabular-nums text-ink">
                  {formatIdrOrUnavailable(detail.netAmountIdr)}
                </p>
              </div>
              <div>
                <p className="text-[11px] font-semibold text-ink-muted">Debit Wallet / Rekening Masked</p>
                <p className="mt-0.5 font-semibold text-ink">
                  {formatIdrOrUnavailable(detail.walletDebitIdr)} ·{' '}
                  {detail.bankAccountMasked || 'Tidak tersedia'}
                </p>
              </div>
              <div>
                <p className="text-[11px] font-semibold text-ink-muted">Dibuat (WIB)</p>
                <p className="mt-0.5 text-ink">{formatTimestampWib(detail.createdAt)}</p>
              </div>
              <div>
                <p className="text-[11px] font-semibold text-ink-muted">Selesai (WIB)</p>
                <p className="mt-0.5 text-ink">{formatTimestampWib(detail.completedAt)}</p>
              </div>
            </div>

            {/* Sanitized Timeline Events */}
            <div>
              <h3 className="flex items-center gap-1.5 text-xs font-bold text-ink uppercase">
                <Clock className="size-3.5 text-primary" aria-hidden="true" />
                <span>Timeline Peristiwa Tersanitasi ({detail.events.length})</span>
              </h3>

              {detail.events.length === 0 ? (
                <p className="mt-2 rounded-[10px] border border-[#E2E8F0] p-3 text-ink-muted">
                  Belum ada catatan peristiwa untuk transaksi ini.
                </p>
              ) : (
                <ol className="mt-3 space-y-2.5 border-l-2 border-[#E2E8F0] pl-4">
                  {detail.events.map((ev, index) => (
                    <li key={`${ev.occurredAt}-${ev.status}-${index}`} className="relative">
                      <span
                        aria-hidden="true"
                        className="absolute top-1.5 -left-[21px] size-2.5 rounded-full border-2 border-white bg-primary"
                      />
                      <div className="rounded-[10px] border border-[#E2E8F0] bg-white p-3">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <div className="flex items-center gap-2">
                            <FinancePaymentStatusBadge status={ev.status} />
                            <span className="rounded-[5px] bg-[#EEF0FF] px-1.5 py-0.5 text-[10px] font-bold text-primary uppercase">
                              {ev.source}
                            </span>
                          </div>
                          <span className="text-[11px] text-ink-muted">
                            {formatTimestampWib(ev.occurredAt)}
                          </span>
                        </div>
                        <p className="mt-1.5 leading-relaxed text-ink">{ev.message}</p>
                      </div>
                    </li>
                  ))}
                </ol>
              )}
            </div>

            <div className="flex items-center gap-2 rounded-[10px] bg-[#F8FAFC] px-3 py-2 text-[11px] text-ink-soft">
              <ShieldCheck className="size-4 shrink-0 text-primary" aria-hidden="true" />
              <span>
                Tampilan ini disanitasi oleh server tanpa nomor rekening penuh, raw webhook payload,
                atau data klinis pasien.
              </span>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  )
}
