import { AlertTriangle, Loader2, X } from 'lucide-react'
import { useState } from 'react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { reviewPsychologistVerification } from '@/lib/portalStore'

interface PsychologistRejectModalProps {
  isOpen: boolean
  psyId: string
  psyFullName: string
  initialReason?: string | null
  onClose: () => void
  onFeedback: (msg: string) => void
  onSuccess?: () => void
}

export function PsychologistRejectModal({
  isOpen,
  psyId,
  psyFullName,
  initialReason = '',
  onClose,
  onFeedback,
  onSuccess,
}: PsychologistRejectModalProps) {
  useBodyScrollLock(isOpen)

  const [reason, setReason] = useState(initialReason ?? '')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  if (!isOpen) return null

  const handleConfirm = async () => {
    if (!reason.trim() || reason.trim().length < 10) {
      setError('Tuliskan catatan evaluasi minimal 10 karakter agar psikolog mengetahui alasannya.')
      return
    }

    setSubmitting(true)
    try {
      await reviewPsychologistVerification(psyId, {
        status: 'rejected',
        notes: reason.trim(),
      })
      onFeedback(`Pendaftaran psikolog "${psyFullName}" ditolak dengan catatan evaluasi.`)
      onClose()
      onSuccess?.()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal memperbarui status verifikasi.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="reject-dialog-title"
      className="fixed inset-0 z-60 flex items-center justify-center bg-ink/60 p-4 backdrop-blur-xs"
    >
      <div className="w-full max-w-md rounded-[16px] border border-[#FECACA] bg-white p-6 shadow-2xl">
        <div className="flex items-start justify-between border-b border-[#FEE2E2] pb-3">
          <div className="flex items-center gap-2 text-[#991B1B]">
            <span className="flex size-7 items-center justify-center rounded-full bg-[#FEE2E2]">
              <AlertTriangle className="size-4" />
            </span>
            <h3 id="reject-dialog-title" className="text-sm font-bold">
              Tolak Pendaftaran Psikolog
            </h3>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup dialog"
            className="inline-flex size-7 cursor-pointer items-center justify-center rounded-[6px] text-ink-muted hover:bg-slate-100"
          >
            <X className="size-4" />
          </button>
        </div>

        <p className="mt-3 text-xs leading-relaxed text-ink-muted">
          Tuliskan catatan evaluasi untuk <strong className="break-words text-ink">{psyFullName}</strong>{' '}
          (misalnya: foto/scan STR buram, nomor SIPP tidak sesuai, atau masa berlaku dokumen habis). Psikolog dapat mendaftar ulang melalui aplikasi mobile.
        </p>

        <div className="mt-3">
          <label htmlFor="eval-notes" className="block text-xs font-semibold text-ink">
            Catatan Verifikasi Admin *
          </label>
          <textarea
            id="eval-notes"
            rows={3}
            value={reason}
            onChange={(e) => {
              setReason(e.target.value)
              if (error) setError(null)
            }}
            placeholder="Contoh: Dokumen SIPP tidak terbaca jelas atau masa berlaku dokumen habis..."
            className="mt-1.5 w-full rounded-[8px] border border-[#CBD5E1] p-3 text-xs text-ink placeholder:text-ink-muted/60 focus:border-[#DC2626] focus:outline-none"
          />
          {error && <p className="mt-1 text-[11px] font-semibold text-[#DC2626]">{error}</p>}
        </div>

        <div className="mt-5 flex items-center justify-end gap-2 border-t border-[#E2E8F0] pt-4">
          <button
            type="button"
            onClick={onClose}
            disabled={submitting}
            className="inline-flex h-9 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-3.5 text-xs font-semibold text-ink hover:bg-slate-50"
          >
            Batal
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            disabled={submitting}
            className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-[#DC2626] px-4 text-xs font-semibold text-white shadow-2xs hover:bg-[#B91C1C] disabled:opacity-60"
          >
            {submitting && <Loader2 className="size-3.5 animate-spin" />}
            <span>Konfirmasi Penolakan</span>
          </button>
        </div>
      </div>
    </div>
  )
}
