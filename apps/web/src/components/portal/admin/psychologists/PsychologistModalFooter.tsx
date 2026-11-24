import { CheckCircle2, FileCheck2, Loader2, XCircle } from 'lucide-react'
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
  onOpenReject: () => void
  onApprove: () => void
  onSuspend: () => void
  onReactivate?: () => void
}

export function PsychologistModalFooter({
  verificationStatus,
  documentsCount,
  verifiedCount,
  approvalNote,
  submitting,
  onApprovalNoteChange,
  onClose,
  onOpenReject,
  onApprove,
  onSuspend,
  onReactivate,
}: PsychologistModalFooterProps) {
  const canApprove = verifiedCount >= 1
  const isVerified = verificationStatus === 'verified'
  const isSuspended = verificationStatus === 'suspended'

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
              canApprove
                ? 'bg-[#DCFCE7] text-[#16A34A]'
                : 'bg-slate-200 text-slate-600',
            )}
          >
            <FileCheck2 className="size-4" />
          </span>
          <div className="text-xs">
            <span className="font-bold text-ink">
              {verifiedCount} dari {documentsCount} Dokumen STR/SIP Terverifikasi (Min. 1)
            </span>
            <span className="block text-[11px] text-ink-muted">
              {canApprove
                ? 'Minimal 1 dokumen legalitas telah valid. Siap disetujui.'
                : 'Tandai valid minimal 1 dokumen STR atau SIP untuk menyetujui.'}
            </span>
          </div>
        </div>

        <div className="flex w-full flex-col gap-2 sm:w-auto sm:flex-row sm:items-center sm:justify-end">
          {!isVerified && (
            <button
              type="button"
              disabled={submitting || !canApprove}
              onClick={isSuspended && onReactivate ? onReactivate : onApprove}
              className="order-1 inline-flex h-10 w-full cursor-pointer items-center justify-center gap-1.5 rounded-[10px] bg-[#16A34A] px-4 text-xs font-semibold text-white shadow-xs transition-colors hover:bg-[#15803D] disabled:cursor-not-allowed disabled:opacity-50 sm:order-4 sm:h-9 sm:w-auto"
            >
              {submitting ? (
                <Loader2 className="size-4 animate-spin" />
              ) : (
                <CheckCircle2 className="size-4" />
              )}
              <span>{isSuspended ? 'Aktifkan Kembali' : 'Approve & Aktifkan'}</span>
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

            {!isVerified && !isSuspended && (
              <button
                type="button"
                disabled={submitting}
                onClick={onOpenReject}
                className="inline-flex h-9 flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-[10px] border border-[#FECACA] bg-[#FEF2F2] px-3 text-xs font-semibold text-[#B91C1C] transition-colors hover:bg-[#FEE2E2] sm:flex-none"
              >
                <XCircle className="size-3.5" />
                <span>Tolak Pendaftaran</span>
              </button>
            )}

            {isVerified && (
              <button
                type="button"
                disabled={submitting}
                onClick={onSuspend}
                className="inline-flex h-9 cursor-pointer items-center justify-center rounded-[10px] border border-[#CBD5E1] bg-white px-3.5 text-xs font-semibold text-ink transition-colors hover:bg-slate-100 disabled:opacity-50"
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
