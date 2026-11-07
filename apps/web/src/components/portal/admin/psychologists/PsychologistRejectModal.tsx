import { AlertTriangle, X } from 'lucide-react'
import { useState } from 'react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { reviewIndependentPsychologist } from '@/lib/portalStore'

interface PsychologistRejectModalProps {
  isOpen: boolean
  psyId: string
  psyFullName: string
  initialReason?: string
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

  const [reason, setReason] = useState(initialReason)
  const [error, setError] = useState<string | null>(null)

  if (!isOpen) return null

  const handleConfirm = () => {
    if (!reason.trim() || reason.trim().length < 10) {
      setError('Tuliskan catatan evaluasi minimal 10 karakter agar psikolog dapat merevisi berkas.')
      return
    }

    reviewIndependentPsychologist(psyId, 'rejected', reason.trim())
    onFeedback(`Berkas pendaftaran "${psyFullName}" ditolak dengan catatan evaluasi.`)
    onClose()
    onSuccess?.()
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
              Tolak &amp; Minta Revisi Berkas
            </h3>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup dialog penolakan"
            className="inline-flex size-7 cursor-pointer items-center justify-center rounded-[6px] text-ink-muted hover:bg-slate-100"
          >
            <X className="size-4" />
          </button>
        </div>

        <p className="mt-3 text-xs leading-relaxed text-ink-muted">
          Anda akan menolak berkas pendaftaran milik <strong className="break-words text-ink">{psyFullName}</strong>.
          Tuliskan catatan evaluasi yang jelas dan spesifik (misal: SIPP kedaluwarsa, resolusi scan buram, dll).
        </p>

        <div className="mt-3">
          <label htmlFor="eval-notes" className="block text-xs font-semibold text-ink">
            Catatan Evaluasi untuk Psikolog *
          </label>
          <textarea
            id="eval-notes"
            rows={3}
            value={reason}
            onChange={(e) => {
              setReason(e.target.value)
              if (error) setError(null)
            }}
            placeholder="Contoh: Dokumen SIPP yang diunggah telah habis masa berlakunya. Mohon unggah salinan SIPP terbaru..."
            className="mt-1.5 w-full rounded-[8px] border border-[#CBD5E1] p-3 text-xs text-ink placeholder:text-ink-muted/60 focus:border-[#DC2626] focus:outline-none"
          />
          {error && <p className="mt-1 text-[11px] font-semibold text-[#DC2626]">{error}</p>}
        </div>

        <div className="mt-5 flex items-center justify-end gap-2 border-t border-[#E2E8F0] pt-4">
          <button
            type="button"
            onClick={onClose}
            className="inline-flex h-9 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-3.5 text-xs font-semibold text-ink hover:bg-slate-50"
          >
            Batal
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            className="inline-flex h-9 cursor-pointer items-center rounded-[8px] bg-[#DC2626] px-4 text-xs font-semibold text-white shadow-2xs hover:bg-[#B91C1C]"
          >
            Konfirmasi Penolakan
          </button>
        </div>
      </div>
    </div>
  )
}

