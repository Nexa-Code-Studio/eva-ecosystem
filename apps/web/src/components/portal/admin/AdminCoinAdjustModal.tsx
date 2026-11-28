import { ArrowRight, CheckCircle2, Coins, Loader2, SlidersHorizontal, X } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { cn } from '@/lib/cn'
import {
  adjustPsychologistCoins,
  adjustUserCoins,
  type GeneralAppUser,
  type Psychologist,
} from '@/lib/portalStore'
import {
  computeCoinAdjustmentPreview,
  type CoinAdjustmentMode,
} from '@/services/contracts/coinAdjustmentUtils'
import type {
  AdminPsychologistCoinAdjustMode,
  AdminUserCoinAdjustMode,
} from '@/types/api/contracts'

export type CoinAdjustTarget =
  | { kind: 'user'; user: GeneralAppUser }
  | { kind: 'psychologist'; psychologist: Psychologist }

interface AdminCoinAdjustModalProps {
  isOpen: boolean
  target: CoinAdjustTarget | null
  onClose: () => void
  onSuccess: (message: string) => void
}

const USER_MODES: Array<{ id: AdminUserCoinAdjustMode; label: string; hint: string }> = [
  { id: 'deduct', label: 'Kurangi Koin', hint: 'Potong sejumlah koin dari saldo' },
  { id: 'set', label: 'Set Saldo', hint: 'Tetapkan saldo akhir secara langsung' },
]

const PSYCHOLOGIST_MODES: Array<{
  id: AdminPsychologistCoinAdjustMode
  label: string
  hint: string
}> = [
  { id: 'add', label: 'Tambah Koin', hint: 'Kredit kompensasi / bonus Admin' },
  { id: 'deduct', label: 'Kurangi Koin', hint: 'Potong sejumlah koin dari dompet' },
  { id: 'set', label: 'Set Saldo', hint: 'Tetapkan saldo akhir secara langsung' },
]

export function AdminCoinAdjustModal({
  isOpen,
  target,
  onClose,
  onSuccess,
}: AdminCoinAdjustModalProps) {
  useBodyScrollLock(isOpen)

  const [mode, setMode] = useState<CoinAdjustmentMode>('deduct')
  const [amountInput, setAmountInput] = useState('10')
  const [adminNotes, setAdminNotes] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  if (!isOpen || !target) return null

  const isPsychologist = target.kind === 'psychologist'
  const currentBalance =
    target.kind === 'user' ? (target.user.coinBalance ?? 0) : (target.psychologist.coinBalance ?? 0)
  const displayName =
    target.kind === 'user'
      ? target.user.displayName
      : `${target.psychologist.fullName}, ${target.psychologist.titleDegree}`
  const subLabel =
    target.kind === 'user'
      ? `${target.user.userCode} · ${target.user.email}`
      : target.psychologist.email

  const modeOptions = isPsychologist ? PSYCHOLOGIST_MODES : USER_MODES
  const activeMode: CoinAdjustmentMode =
    !isPsychologist && mode === 'add' ? 'deduct' : mode

  const parsedAmount = amountInput.trim() === '' ? NaN : Number(amountInput)
  const preview = computeCoinAdjustmentPreview(activeMode, parsedAmount, currentBalance)

  const handleModeChange = (nextMode: CoinAdjustmentMode) => {
    setMode(nextMode)
    setErrorMsg(null)
    if (nextMode === 'set') {
      setAmountInput(String(currentBalance))
    } else if (amountInput.trim() === '' || Number(amountInput) <= 0) {
      setAmountInput('10')
    }
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    if (!preview.valid) {
      setErrorMsg(preview.error || 'Nominal penyesuaian koin tidak valid.')
      return
    }
    const trimmedNotes = adminNotes.trim()
    if (trimmedNotes.length < 3) {
      setErrorMsg('Catatan audit admin wajib diisi (minimal 3 karakter).')
      return
    }

    setSubmitting(true)
    setErrorMsg(null)
    try {
      if (target.kind === 'user') {
        const res = await adjustUserCoins({
          userId: target.user.id,
          mode: activeMode as AdminUserCoinAdjustMode,
          amount: Math.trunc(parsedAmount),
          adminNotes: trimmedNotes,
        })
        const deltaLabel =
          res.transaction.coinsGranted > 0
            ? `+${res.transaction.coinsGranted}`
            : `${res.transaction.coinsGranted}`
        onSuccess(
          `Saldo koin ${res.user.displayName} disesuaikan (${deltaLabel} Koin). Saldo baru: ${res.user.coinBalance} Koin.`,
        )
      } else {
        const res = await adjustPsychologistCoins({
          psychologistId: target.psychologist.id,
          mode: activeMode as AdminPsychologistCoinAdjustMode,
          amount: Math.trunc(parsedAmount),
          adminNotes: trimmedNotes,
        })
        const deltaLabel =
          res.transaction.amount > 0 ? `+${res.transaction.amount}` : `${res.transaction.amount}`
        onSuccess(
          `Saldo koin ${res.psychologist.fullName} disesuaikan (${deltaLabel} Koin). Saldo baru: ${res.psychologist.coinBalance} Koin.`,
        )
      }
      onClose()
    } catch (err) {
      setErrorMsg(
        err instanceof Error ? err.message : 'Gagal menyimpan penyesuaian koin ke server.',
      )
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4 backdrop-blur-[2px]"
      role="dialog"
      aria-modal="true"
      aria-labelledby="coin-adjust-modal-title"
      onClick={onClose}
    >
      <div
        className="flex max-h-[90vh] w-full max-w-lg flex-col overflow-hidden rounded-[14px] border border-[#E2E8F0] bg-white shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3 border-b border-[#E2E8F0] px-5 py-4">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <span className="flex size-7 shrink-0 items-center justify-center rounded-[8px] bg-[#EEF0FF] text-primary">
                <SlidersHorizontal className="size-4" aria-hidden="true" />
              </span>
              <h2 id="coin-adjust-modal-title" className="truncate text-base font-bold text-ink">
                Sesuaikan Saldo Koin {isPsychologist ? 'Psikolog' : 'Pengguna'}
              </h2>
            </div>
            <p className="mt-1 truncate text-xs font-semibold text-ink">{displayName}</p>
            <p className="truncate text-[11px] text-ink-muted">{subLabel}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup modal penyesuaian koin"
            className="inline-flex size-8 shrink-0 cursor-pointer items-center justify-center rounded-[8px] text-ink-muted transition-colors hover:bg-[#F1F5F9] hover:text-ink"
          >
            <X className="size-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 overflow-y-auto p-5 text-xs">
          <div>
            <p className="mb-1.5 font-bold text-ink">Mode Penyesuaian</p>
            <div
              className={cn(
                'grid gap-2',
                modeOptions.length === 3 ? 'grid-cols-1 sm:grid-cols-3' : 'grid-cols-2',
              )}
            >
              {modeOptions.map((opt) => {
                const selected = activeMode === opt.id
                return (
                  <button
                    key={opt.id}
                    type="button"
                    onClick={() => handleModeChange(opt.id)}
                    className={cn(
                      'cursor-pointer rounded-[10px] border p-2.5 text-left transition-colors',
                      selected
                        ? 'border-primary bg-[#EEF0FF] text-primary'
                        : 'border-[#CBD5E1] bg-white text-ink hover:bg-[#F8FAFC]',
                    )}
                  >
                    <p className="font-bold">{opt.label}</p>
                    <p className="mt-0.5 text-[10px] leading-snug text-ink-muted">{opt.hint}</p>
                  </button>
                )
              })}
            </div>
          </div>

          <div>
            <label htmlFor="coin-adjust-amount" className="mb-1.5 block font-bold text-ink">
              {activeMode === 'set'
                ? 'Target Saldo Koin Baru'
                : activeMode === 'add'
                  ? 'Jumlah Penambahan Koin'
                  : 'Jumlah Pengurangan Koin'}
            </label>
            <div className="relative">
              <Coins
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-ink-muted"
                aria-hidden="true"
              />
              <input
                id="coin-adjust-amount"
                type="number"
                min={activeMode === 'set' ? 0 : 1}
                max={100000}
                step={1}
                value={amountInput}
                onChange={(e) => {
                  setAmountInput(e.target.value)
                  setErrorMsg(null)
                }}
                className="h-10 w-full rounded-[8px] border border-[#768396] bg-white pr-14 pl-9 text-sm font-bold text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
                required
              />
              <span className="pointer-events-none absolute top-1/2 right-3 -translate-y-1/2 text-xs font-semibold text-ink-muted">
                Koin
              </span>
            </div>
          </div>

          <div className="rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3">
            <p className="text-[11px] font-bold tracking-wide text-ink-muted uppercase">
              Pratinjau Mutasi Ledger
            </p>
            <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
              <div className="flex items-center gap-2 font-mono text-sm font-bold text-ink">
                <span>{currentBalance.toLocaleString('id-ID')}</span>
                <ArrowRight className="size-3.5 text-ink-muted" aria-hidden="true" />
                <span className={preview.nextBalance < 0 ? 'text-[#B91C1C]' : 'text-primary'}>
                  {preview.nextBalance.toLocaleString('id-ID')} Koin
                </span>
              </div>
              {preview.delta !== 0 && (
                <span
                  className={cn(
                    'rounded-[6px] px-2 py-0.5 font-mono text-[11px] font-bold',
                    preview.delta > 0
                      ? 'bg-[#F0FDF4] text-[#166534]'
                      : 'bg-[#FEF2F2] text-[#B91C1C]',
                  )}
                >
                  {preview.delta > 0 ? `+${preview.delta}` : preview.delta} Koin
                </span>
              )}
            </div>
            {!preview.valid && preview.error && (
              <p className="mt-1.5 text-[11px] font-semibold text-[#B91C1C]">{preview.error}</p>
            )}
          </div>

          <div>
            <label htmlFor="coin-adjust-notes" className="mb-1.5 block font-bold text-ink">
              Catatan Audit Admin <span className="text-[#B91C1C]">*</span>
            </label>
            <textarea
              id="coin-adjust-notes"
              rows={3}
              minLength={3}
              maxLength={500}
              value={adminNotes}
              onChange={(e) => {
                setAdminNotes(e.target.value)
                setErrorMsg(null)
              }}
              placeholder="Contoh: Koreksi duplikasi top-up, penyesuaian saldo migrasi, atau kompensasi kendala sesi."
              className="w-full rounded-[8px] border border-[#768396] bg-white p-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
              required
            />
            <p className="mt-1 text-[11px] text-ink-muted">
              Akan dicatat ke riwayat transaksi sebagai mutasi{' '}
              <span className="font-mono">admin_adjustment</span>.
            </p>
          </div>

          {errorMsg && (
            <div className="rounded-[8px] border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-xs font-medium text-[#991B1B]">
              {errorMsg}
            </div>
          )}

          <div className="flex flex-col-reverse gap-2 border-t border-[#E2E8F0] pt-3 sm:flex-row sm:justify-end">
            <button
              type="button"
              onClick={onClose}
              disabled={submitting}
              className="inline-flex h-10 cursor-pointer items-center justify-center rounded-[8px] border border-[#CBD5E1] bg-white px-4 font-semibold text-ink hover:bg-[#F8FAFC] disabled:opacity-60"
            >
              Batal
            </button>
            <button
              type="submit"
              disabled={submitting || !preview.valid || adminNotes.trim().length < 3}
              className="inline-flex h-10 cursor-pointer items-center justify-center gap-1.5 rounded-[8px] bg-primary px-4 font-semibold text-white transition-colors hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {submitting ? (
                <Loader2 className="size-4 animate-spin" aria-hidden="true" />
              ) : (
                <CheckCircle2 className="size-4" aria-hidden="true" />
              )}
              <span>Simpan Penyesuaian</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
