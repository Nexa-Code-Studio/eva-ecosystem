import { Coins, Loader2, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { cn } from '@/lib/cn'
import {
  fetchAdminPsychologistTransactions,
  type Psychologist,
  type PsychologistCoinTransaction,
} from '@/lib/portalStore'

interface PsychologistCoinHistoryModalProps {
  psychologist: Psychologist | null
  isOpen: boolean
  onClose: () => void
}

function formatTxDate(iso: string): string {
  const parsed = new Date(iso)
  if (Number.isNaN(parsed.getTime())) return iso
  return parsed.toLocaleString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function PsychologistCoinHistoryModal({
  psychologist,
  isOpen,
  onClose,
}: PsychologistCoinHistoryModalProps) {
  const [transactions, setTransactions] = useState<PsychologistCoinTransaction[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  useEffect(() => {
    if (!isOpen || !psychologist) return
    let active = true
    setIsLoading(true)
    setErrorMsg(null)

    void fetchAdminPsychologistTransactions(psychologist.id)
      .then((rows) => {
        if (active) setTransactions(rows)
      })
      .catch((err: unknown) => {
        if (active) {
          setErrorMsg(
            err instanceof Error ? err.message : 'Gagal memuat riwayat mutasi koin psikolog.',
          )
        }
      })
      .finally(() => {
        if (active) setIsLoading(false)
      })

    return () => {
      active = false
    }
  }, [isOpen, psychologist])

  if (!isOpen || !psychologist) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4 backdrop-blur-[2px]"
      role="dialog"
      aria-modal="true"
      aria-labelledby="psy-coin-history-title"
      onClick={onClose}
    >
      <div
        className="flex max-h-[85vh] w-full max-w-2xl flex-col overflow-hidden rounded-[14px] border border-[#E2E8F0] bg-white shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3 border-b border-[#E2E8F0] px-5 py-4">
          <div className="min-w-0">
            <h2 id="psy-coin-history-title" className="truncate text-base font-bold text-ink">
              Riwayat Mutasi Koin Psikolog
            </h2>
            <p className="mt-0.5 truncate text-xs text-ink-muted">
              {psychologist.fullName}, {psychologist.titleDegree} · Saldo saat ini:{' '}
              <span className="font-bold text-primary">
                {psychologist.coinBalance.toLocaleString('id-ID')} Koin
              </span>
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup modal riwayat koin"
            className="inline-flex size-8 shrink-0 cursor-pointer items-center justify-center rounded-[8px] text-ink-muted transition-colors hover:bg-[#F1F5F9] hover:text-ink"
          >
            <X className="size-4" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-5">
          {isLoading ? (
            <div className="flex flex-col items-center justify-center py-10 text-xs text-ink-muted">
              <Loader2 className="size-6 animate-spin text-primary" />
              <p className="mt-2">Memuat riwayat mutasi koin...</p>
            </div>
          ) : errorMsg ? (
            <div className="rounded-[10px] border border-[#FECACA] bg-[#FEF2F2] p-4 text-xs text-[#991B1B]">
              {errorMsg}
            </div>
          ) : transactions.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-10 text-center text-xs text-ink-muted">
              <Coins className="size-8 text-ink-muted/50" />
              <p className="mt-2 font-semibold text-ink">Belum ada riwayat mutasi koin</p>
              <p className="mt-0.5 text-[11px]">
                Honorarium sesi selesai dan pencairan koin akan muncul di sini.
              </p>
            </div>
          ) : (
            <div className="divide-y divide-[#E2E8F0] rounded-[10px] border border-[#E2E8F0]">
              {transactions.map((tx) => {
                const isEarning = tx.transactionType.toUpperCase() === 'EARNING'
                const isCompleted = tx.status.toUpperCase() === 'COMPLETED'
                return (
                  <div
                    key={tx.id}
                    className="flex flex-col justify-between gap-2 px-4 py-3 text-xs sm:flex-row sm:items-center"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="font-semibold text-ink">{tx.description}</p>
                      <div className="mt-0.5 flex flex-wrap items-center gap-2 text-[11px] text-ink-muted">
                        <span>{formatTxDate(tx.date)}</span>
                        {tx.referenceId && (
                          <>
                            <span>·</span>
                            <span className="font-mono">{tx.referenceId}</span>
                          </>
                        )}
                      </div>
                    </div>

                    <div className="flex items-center gap-2 sm:justify-end">
                      <span
                        className={cn(
                          'rounded-[6px] px-2 py-0.5 text-[10px] font-bold uppercase',
                          isCompleted
                            ? 'bg-[#F0FDF4] text-[#166534]'
                            : 'bg-[#FEF3C7] text-[#92400E]',
                        )}
                      >
                        {tx.status}
                      </span>
                      <span
                        className={cn(
                          'font-mono text-xs font-bold whitespace-nowrap',
                          isEarning ? 'text-[#166534]' : 'text-[#991B1B]',
                        )}
                      >
                        {isEarning ? '+' : '-'}
                        {Math.abs(tx.amount).toLocaleString('id-ID')} Koin
                      </span>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
