import { AlertCircle, CheckCircle2, FileCheck2, Loader2, XCircle } from 'lucide-react'
import { cn } from '@/lib/cn'
import type { VerificationStatus } from '@/types/portal'

interface PsychologistModalFooterProps {
  verificationStatus: VerificationStatus
  documentsCount: number
  verifiedCount: number
  approvalNote: string
  submitting: boolean
  onApprovalNoteChange: (val: string) => void
  onClose: () => void
  onRequestRevision: () => void
  onOpenReject: () => void
  onApprove: () => void
  onSuspend: () => void
}

export function PsychologistModalFooter({
  verificationStatus,
  documentsCount,
  verifiedCount,
  approvalNote,
  submitting,
  onApprovalNoteChange,
  onClose,
  onRequestRevision,
  onOpenReject,
  onApprove,
  onSuspend,
}: PsychologistModalFooterProps) {
  const allVerified = documentsCount > 0 && verifiedCount === documentsCount
  const isVerified = verificationStatus === 'verified'

  return (
    <div className="space-y-3 border-t border-[#E2E8F0] bg-[#F8FAFC] px-4 py-3.5 sm:px-6">
      {!isVerified && (
        <div className="flex flex-col gap-1.5 sm:flex-row sm:items-center sm:gap-3">
          <label
            htmlFor="psy-approval-note"
            className="shrink-0 text-[11px] font-semibold text-ink-soft"
          >
            Catatan Verifikasi (Opsional):
          </label>
          <input
            id="psy-approval-note"
            type="text"
            value={approvalNote}
            onChange={(e) => onApprovalNoteChange(e.target.value)}
            placeholder="Misal: STR-PK & SIPP valid melalui direktori HIMPSI."
            className="h-8 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs text-ink placeholder:text-ink-muted/70 focus:border-primary focus:outline-none"
          />
        </div>
      )}

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-2.5">
          <span
            className={cn(
              'flex size-7 shrink-0 items-center justify-center rounded-full',
              allVerified
                ? 'bg-[#DCFCE7] text-[#16A34A]'
                : verifiedCount > 0
                  ? 'bg-[#FEF3C7] text-[#B45309]'
                  : 'bg-slate-200 text-slate-600',
            )}
          >
            <FileCheck2 className="size-4" />
          </span>
          <div className="text-xs">
            <span className="font-bold text-ink">
              {verifiedCount} dari {documentsCount} Dokumen STR/SIP Terverifikasi
            </span>
            <span className="block text-[11px] text-ink-muted">
              {allVerified
                ? 'Seluruh lampiran kredensial sudah ditandai valid.'
                : 'Periksa keabsahan nomor STR, SIP, dan masa berlaku dokumen.'}
            </span>
          </div>
        </div>

        <div className="flex w-full flex-col gap-2 sm:w-auto sm:flex-row sm:items-center sm:justify-end">
          {!isVerified && (
            <button
              type="button"
              disabled={submitting}
              onClick={onApprove}
              className="order-1 inline-flex h-10 w-full cursor-pointer items-center justify-center gap-1.5 rounded-[10px] bg-[#16A34A] px-4 text-xs font-semibold text-white shadow-xs transition-colors hover:bg-[#15803D] disabled:opacity-60 sm:order-4 sm:h-9 sm:w-auto"
            >
              {submitting ? (
                <Loader2 className="size-4 animate-spin" />
              ) : (
                <CheckCircle2 className="size-4" />
              )}
              <span>Approve &amp; Aktifkan</span>
            </button>
          )}

          <div className="order-2 flex flex-wrap items-center gap-2 sm:order-1">
            <button
              type="button"
              onClick={onClose}
              className="inline-flex h-9 flex-1 cursor-pointer items-center justify-center rounded-[10px] border border-[#CBD5E1] bg-white px-3.5 text-xs font-semibold text-ink transition-colors hover:bg-slate-100 sm:flex-none"
            >
              Tutup
            </button>

            {!isVerified && (
              <>
                <button
                  type="button"
                  disabled={submitting}
                  onClick={onRequestRevision}
                  className="inline-flex h-9 flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-[10px] border border-[#FDBA74] bg-[#FFF7ED] px-3 text-xs font-semibold text-[#C2410C] transition-colors hover:bg-[#FFEDD5] sm:flex-none"
                >
                  <AlertCircle className="size-3.5" />
                  <span>Minta Revisi</span>
                </button>

                <button
                  type="button"
                  disabled={submitting}
                  onClick={onOpenReject}
                  className="inline-flex h-9 flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-[10px] border border-[#FECACA] bg-[#FEF2F2] px-3 text-xs font-semibold text-[#B91C1C] transition-colors hover:bg-[#FEE2E2] sm:flex-none"
                >
                  <XCircle className="size-3.5" />
                  <span>Reject</span>
                </button>
              </>
            )}

            {isVerified && (
              <button
                type="button"
                onClick={onSuspend}
                className="inline-flex h-9 cursor-pointer items-center justify-center rounded-[10px] border border-[#CBD5E1] bg-white px-3.5 text-xs font-semibold text-ink transition-colors hover:bg-slate-100"
              >
                Nonaktifkan Sementara
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
