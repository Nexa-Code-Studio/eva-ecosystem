import { AlertTriangle, CheckCircle2, Clock, RefreshCw, Smartphone, X } from 'lucide-react'
import { FORMAL_SECONDARY_BTN_CLASS } from '@/constants/portal'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { cn } from '@/lib/cn'
import type { Psychologist } from '@/types/portal'

interface PsychologistVerificationStatusModalProps {
  psychologist: Psychologist | null
  onClose: () => void
  onRevise: (psychologistId: string) => void
}

export function PsychologistVerificationStatusModal({
  psychologist,
  onClose,
  onRevise,
}: PsychologistVerificationStatusModalProps) {
  useBodyScrollLock(Boolean(psychologist))

  if (!psychologist) return null

  const status = psychologist.verificationStatus
  const canRevise = status === 'need_revision' || status === 'rejected'

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="psy-status-modal-title"
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
    >
      <div
        aria-hidden="true"
        onClick={onClose}
        className="fixed inset-0 bg-[#0F172A]/45 backdrop-blur-[2px]"
      />

      <div className="relative z-10 w-full max-w-[440px] rounded-[12px] border border-[#E2E8F0] bg-white p-6 shadow-xl">
        <div className="flex items-start justify-between gap-3">
          <span
            className={cn(
              'flex size-10 shrink-0 items-center justify-center rounded-[10px] border',
              status === 'verified' && 'border-emerald-200 bg-emerald-50 text-emerald-700',
              status === 'pending' && 'border-warning/30 bg-warning/10 text-[#B45309]',
              canRevise && 'border-crisis-border bg-crisis-bg text-crisis-text',
              status === 'suspended' && 'border-[#CBD5E1] bg-[#F1F5F9] text-ink-soft',
            )}
          >
            {status === 'verified' ? (
              <CheckCircle2 className="size-5" />
            ) : status === 'pending' ? (
              <Clock className="size-5" />
            ) : (
              <AlertTriangle className="size-5" />
            )}
          </span>

          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup status verifikasi"
            className="flex size-8 cursor-pointer items-center justify-center rounded-[6px] text-ink-soft transition-colors hover:bg-[#F1F5F9] hover:text-ink"
          >
            <X className="size-4" />
          </button>
        </div>

        <div className="mt-4">
          <h2
            id="psy-status-modal-title"
            className="text-base font-semibold tracking-[-0.01em] text-ink"
          >
            {status === 'verified' && 'Akun Psikolog Sudah Terverifikasi'}
            {status === 'pending' && 'Kredensial Sedang Diverifikasi'}
            {status === 'need_revision' && 'Berkas Membutuhkan Revisi'}
            {status === 'rejected' && 'Pendaftaran Ditolak / Perlu Perbaikan'}
            {status === 'suspended' && 'Akses Akun Dinonaktifkan'}
          </h2>
          <p className="mt-0.5 text-xs font-medium text-ink-soft">
            {psychologist.fullName}, {psychologist.titleDegree} · STR{' '}
            <span className="font-mono">{psychologist.strNumber}</span>
          </p>

          {status === 'verified' && (
            <div className="mt-3 flex items-start gap-2.5 rounded-[8px] border border-emerald-200 bg-emerald-50/70 p-3 text-xs leading-relaxed text-emerald-950">
              <Smartphone className="mt-0.5 size-4 shrink-0 text-emerald-700" />
              <p>
                Kredensial STR/SIP Anda telah disetujui oleh Admin EVA. Silakan masuk menggunakan email{' '}
                <strong>{psychologist.email}</strong> pada aplikasi{' '}
                <strong>Eva Counselor Mobile</strong> untuk mengatur jadwal dan menerima sesi telekonsultasi.
              </p>
            </div>
          )}

          {status === 'pending' && (
            <p className="mt-3 text-xs leading-relaxed text-ink-soft">
              Pendaftaran psikolog mandiri Anda sedang ditinjau oleh tim Admin EVA. Setelah STR/SIP
              diverifikasi, akun Anda otomatis aktif di aplikasi <strong>Eva Counselor Mobile</strong>.
            </p>
          )}

          {canRevise && (
            <>
              <p className="mt-3 text-xs leading-relaxed text-ink-soft">
                Mohon perbarui data atau dokumen STR/SIP Anda berdasarkan catatan verifikasi Admin berikut:
              </p>
              <div className="mt-2.5 rounded-[8px] border border-crisis-border bg-crisis-bg p-3 text-xs leading-relaxed text-crisis-text">
                {psychologist.verificationNotes ||
                  'Dokumen STR/SIP perlu dilengkapi atau diperbarui dengan salinan yang lebih jelas.'}
              </div>
            </>
          )}

          {status === 'suspended' && (
            <p className="mt-3 text-xs leading-relaxed text-ink-soft">
              Akun praktik psikolog Anda sedang dinonaktifkan sementara oleh administrator sistem EVA.
            </p>
          )}
        </div>

        <div className="mt-6 flex items-center justify-end gap-2.5 border-t border-[#E2E8F0] pt-4">
          {canRevise ? (
            <>
              <button type="button" onClick={onClose} className={FORMAL_SECONDARY_BTN_CLASS}>
                Tutup
              </button>
              <button
                type="button"
                onClick={() => onRevise(psychologist.id)}
                className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-[#464BB8]"
              >
                <RefreshCw className="size-3.5" />
                <span>Perbaiki Pendaftaran</span>
              </button>
            </>
          ) : (
            <button type="button" onClick={onClose} className={FORMAL_SECONDARY_BTN_CLASS}>
              Tutup
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
