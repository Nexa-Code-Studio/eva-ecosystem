import { AlertTriangle, CheckCircle2, Info, Loader2, X } from 'lucide-react'
import { useEffect, useState, type FormEvent } from 'react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { cn } from '@/lib/cn'

export type ConfirmDialogTone = 'primary' | 'emerald' | 'amber' | 'danger'

interface AdminActionConfirmModalProps {
  isOpen: boolean
  title: string
  description: string
  impactSummary?: string
  confirmLabel: string
  cancelLabel?: string
  tone?: ConfirmDialogTone
  showNoteInput?: boolean
  noteLabel?: string
  notePlaceholder?: string
  initialNote?: string
  onClose: () => void
  onConfirm: (note: string) => void | Promise<void>
}

const TONE_STYLES: Record<
  ConfirmDialogTone,
  { iconBg: string; iconText: string; buttonBg: string; impactBox: string }
> = {
  primary: {
    iconBg: 'bg-[#EEF0FF]',
    iconText: 'text-primary',
    buttonBg: 'bg-primary hover:bg-primary-hover text-white',
    impactBox: 'border-primary/30 bg-[#EEF0FF] text-ink',
  },
  emerald: {
    iconBg: 'bg-[#ECFDF5]',
    iconText: 'text-[#047857]',
    buttonBg: 'bg-[#047857] hover:bg-[#065F46] text-white',
    impactBox: 'border-[#A7F3D0] bg-[#F0FDF4] text-[#166534]',
  },
  amber: {
    iconBg: 'bg-[#FFFBEB]',
    iconText: 'text-[#B45309]',
    buttonBg: 'bg-[#B45309] hover:bg-[#92400E] text-white',
    impactBox: 'border-[#FDE68A] bg-[#FEF3C7] text-[#92400E]',
  },
  danger: {
    iconBg: 'bg-[#FEF2F2]',
    iconText: 'text-[#B91C1C]',
    buttonBg: 'bg-[#B91C1C] hover:bg-[#991B1B] text-white',
    impactBox: 'border-[#FECACA] bg-[#FEF2F2] text-[#991B1B]',
  },
}

/** Shared accessible confirmation dialog for destructive or balance-changing admin actions. */
export function AdminActionConfirmModal({
  isOpen,
  title,
  description,
  impactSummary,
  confirmLabel,
  cancelLabel = 'Batal',
  tone = 'primary',
  showNoteInput = false,
  noteLabel = 'Catatan Admin (Opsional)',
  notePlaceholder = 'Tambahkan catatan alasan atau bukti verifikasi...',
  initialNote = '',
  onClose,
  onConfirm,
}: AdminActionConfirmModalProps) {
  useBodyScrollLock(isOpen)

  const [note, setNote] = useState(initialNote)
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (!isOpen) return
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !submitting) onClose()
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, onClose, submitting])

  if (!isOpen) return null

  const styles = TONE_STYLES[tone]

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    if (submitting) return
    setSubmitting(true)
    try {
      await onConfirm(note.trim())
      onClose()
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onClick={() => {
        if (!submitting) onClose()
      }}
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 p-3 sm:p-4"
    >
      <form
        onClick={(e) => e.stopPropagation()}
        onSubmit={handleSubmit}
        className="w-full max-w-md rounded-[16px] border border-[#E2E8F0] bg-white p-5 text-xs shadow-2xl"
      >
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-start gap-2.5">
            <span
              aria-hidden="true"
              className={cn(
                'flex size-9 shrink-0 items-center justify-center rounded-[10px]',
                styles.iconBg,
                styles.iconText,
              )}
            >
              {tone === 'emerald' ? (
                <CheckCircle2 className="size-4.5" aria-hidden="true" />
              ) : tone === 'primary' ? (
                <Info className="size-4.5" aria-hidden="true" />
              ) : (
                <AlertTriangle className="size-4.5" aria-hidden="true" />
              )}
            </span>
            <div>
              <h3 className="text-sm font-bold text-ink">{title}</h3>
              <p className="mt-1 leading-relaxed text-ink-soft">{description}</p>
            </div>
          </div>

          <button
            type="button"
            disabled={submitting}
            onClick={onClose}
            aria-label="Tutup dialog konfirmasi"
            className="inline-flex min-h-11 min-w-11 shrink-0 cursor-pointer items-center justify-center rounded-[8px] border border-[#768396] text-ink-soft hover:bg-slate-50 hover:text-ink disabled:cursor-not-allowed disabled:opacity-50 sm:size-8 sm:min-h-0 sm:min-w-0"
          >
            <X className="size-4" aria-hidden="true" />
          </button>
        </div>

        {impactSummary && (
          <div
            className={cn(
              'mt-3.5 rounded-[10px] border px-3 py-2.5 text-[11px] font-medium leading-relaxed',
              styles.impactBox,
            )}
          >
            {impactSummary}
          </div>
        )}

        {showNoteInput && (
          <div className="mt-3.5">
            <label htmlFor="admin-confirm-note" className="mb-1 block font-semibold text-ink">
              {noteLabel}
            </label>
            <textarea
              id="admin-confirm-note"
              rows={3}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder={notePlaceholder}
              className="w-full rounded-[8px] border border-[#768396] p-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
            />
          </div>
        )}

        <div className="mt-4 flex flex-col-reverse gap-2 border-t border-[#E2E8F0] pt-3.5 sm:flex-row sm:justify-end">
          <button
            type="button"
            disabled={submitting}
            onClick={onClose}
            className="inline-flex min-h-11 cursor-pointer items-center justify-center rounded-[8px] border border-[#768396] bg-white px-4 font-semibold text-ink hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50 sm:h-9 sm:min-h-0"
          >
            {cancelLabel}
          </button>
          <button
            type="submit"
            disabled={submitting}
            className={cn(
              'inline-flex min-h-11 cursor-pointer items-center justify-center gap-1.5 rounded-[8px] px-4 font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-60 sm:h-9 sm:min-h-0',
              styles.buttonBg,
            )}
          >
            {submitting && <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />}
            <span>{confirmLabel}</span>
          </button>
        </div>
      </form>
    </div>
  )
}
