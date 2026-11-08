import { AlertTriangle, Clock, RefreshCw, X } from 'lucide-react'
import { FORMAL_SECONDARY_BTN_CLASS } from '@/constants/portal'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { cn } from '@/lib/cn'
import type { PartnerAccount } from '@/types/portal'

interface PartnerStatusModalProps {
  partner: PartnerAccount | null
  onClose: () => void
  onRevise: (partnerId: string) => void
}

export function PartnerStatusModal({
  partner,
  onClose,
  onRevise,
}: PartnerStatusModalProps) {
  useBodyScrollLock(Boolean(partner))

  if (!partner) return null

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="partner-status-modal-title"
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
    >
      <div
        aria-hidden="true"
        onClick={onClose}
        className="fixed inset-0 bg-[#0F172A]/45 backdrop-blur-[2px]"
      />

      <div className="relative z-10 w-full max-w-[420px] rounded-[12px] border border-[#E2E8F0] bg-white p-6 shadow-xl">
        <div className="flex items-start justify-between gap-3">
          <span
            className={cn(
              'flex size-10 shrink-0 items-center justify-center rounded-[10px] border',
              partner.status === 'pending' &&
                'border-warning/30 bg-warning/10 text-[#B45309]',
              partner.status === 'rejected' &&
                'border-crisis-border bg-crisis-bg text-crisis-text',
              partner.status === 'suspended' &&
                'border-[#CBD5E1] bg-[#F1F5F9] text-ink-soft',
            )}
          >
            {partner.status === 'pending' ? (
              <Clock className="size-5" />
            ) : (
              <AlertTriangle className="size-5" />
            )}
          </span>

          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup peringatan"
            className="flex size-8 cursor-pointer items-center justify-center rounded-[6px] text-ink-soft transition-colors hover:bg-[#F1F5F9] hover:text-ink"
          >
            <X className="size-4" />
          </button>
        </div>

        <div className="mt-4">
          <h2
            id="partner-status-modal-title"
            className="text-base font-semibold tracking-[-0.01em] text-ink"
          >
            {partner.status === 'pending' && 'Pengajuan Sedang Diverifikasi'}
            {partner.status === 'rejected' && 'Pengajuan Membutuhkan Perbaikan'}
            {partner.status === 'suspended' && 'Akses Akun Dinonaktifkan'}
          </h2>
          <p className="mt-0.5 text-xs font-medium text-ink-soft">{partner.facilityName}</p>

          {partner.status === 'pending' && (
            <p className="mt-3 text-xs leading-relaxed text-ink-soft">
              Permohonan kemitraan fasilitas kesehatan Anda saat ini sedang ditinjau oleh tim Admin
              EVA. Anda dapat masuk ke Dasbor Mitra segera setelah izin operasional faskes selesai
              diverifikasi.
            </p>
          )}

          {partner.status === 'rejected' && (
            <>
              <p className="mt-3 text-xs leading-relaxed text-ink-soft">
                Mohon perbaiki data pengajuan fasilitas kesehatan Anda berdasarkan catatan
                verifikasi Admin berikut:
              </p>
              <div className="mt-2.5 rounded-[8px] border border-crisis-border bg-crisis-bg p-3 text-xs leading-relaxed text-crisis-text">
                {partner.rejectionReason ||
                  'Data izin operasional fasilitas kesehatan belum lengkap.'}
              </div>
            </>
          )}

          {partner.status === 'suspended' && (
            <p className="mt-3 text-xs leading-relaxed text-ink-soft">
              Akses akun mitra untuk fasilitas kesehatan ini sedang dinonaktifkan sementara oleh
              administrator sistem EVA.
            </p>
          )}
        </div>

        <div className="mt-6 flex items-center justify-end gap-2.5 border-t border-[#E2E8F0] pt-4">
          {partner.status === 'rejected' ? (
            <>
              <button type="button" onClick={onClose} className={FORMAL_SECONDARY_BTN_CLASS}>
                Tutup
              </button>
              <button
                type="button"
                onClick={() => onRevise(partner.id)}
                className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-[#464BB8]"
              >
                <RefreshCw className="size-3.5" />
                <span>Perbaiki Pengajuan</span>
              </button>
            </>
          ) : (
            <button
              type="button"
              onClick={onClose}
              className="inline-flex h-9 w-full cursor-pointer items-center justify-center rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-[#464BB8]"
            >
              Mengerti
            </button>
          )}
        </div>
      </div>
    </div>
  )
}

