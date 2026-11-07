import { ExternalLink, X, ZoomIn } from 'lucide-react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import type { PsychologistCertificate } from '@/types/portal'

interface CertificateImageModalProps {
  isOpen: boolean
  certificate: PsychologistCertificate | null
  onClose: () => void
}

export function CertificateImageModal({
  isOpen,
  certificate,
  onClose,
}: CertificateImageModalProps) {
  useBodyScrollLock(isOpen && Boolean(certificate))

  if (!isOpen || !certificate) return null

  const imageUrl = certificate.imageUrl

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={`Pratinjau Berkas ${certificate.title}`}
      className="fixed inset-0 z-60 flex items-center justify-center bg-ink/75 p-3 backdrop-blur-xs sm:p-6"
    >
      <div className="flex max-h-[95dvh] w-full max-w-4xl flex-col overflow-hidden rounded-[16px] border border-white/20 bg-[#0F172A] shadow-2xl">
        {/* Top bar */}
        <div className="flex items-center justify-between border-b border-slate-700/60 bg-[#1E293B] px-5 py-3.5 text-white">
          <div className="min-w-0 pr-4">
            <div className="flex items-center gap-2">
              <span className="rounded-[4px] bg-primary/20 px-2 py-0.5 text-[10px] font-bold text-primary-300 uppercase">
                {certificate.docType}
              </span>
              <span className="text-xs text-slate-400">
                No: {certificate.documentNumber}
              </span>
            </div>
            <h3 className="mt-1 truncate text-sm font-bold text-white">
              {certificate.title}
            </h3>
          </div>

          <div className="flex items-center gap-2">
            {imageUrl && (
              <a
                href={imageUrl}
                download={`${certificate.fileName}.svg`}
                target="_blank"
                rel="noreferrer"
                className="inline-flex h-8 items-center gap-1.5 rounded-[8px] bg-white/10 px-3 text-xs font-medium text-white hover:bg-white/20"
                title="Buka atau unduh berkas asli"
              >
                <ExternalLink className="size-3.5" />
                <span className="hidden sm:inline">Buka Berkas</span>
              </a>
            )}
            <button
              type="button"
              onClick={onClose}
              aria-label="Tutup jendela pratinjau"
              className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[8px] bg-white/10 text-slate-300 hover:bg-white/20 hover:text-white"
            >
              <X className="size-4" />
            </button>
          </div>
        </div>

        {/* Certificate Display Area */}
        <div className="flex flex-1 items-center justify-center overflow-auto bg-[#0B1120] p-4 sm:p-8">
          {imageUrl ? (
            <div className="group relative max-h-[75dvh] max-w-full overflow-hidden rounded-[8px] shadow-[0_15px_35px_rgba(0,0,0,0.6)]">
              <img
                src={imageUrl}
                alt={`Scan resmi ${certificate.title}`}
                className="max-h-[75dvh] w-auto max-w-full object-contain transition-transform duration-200 group-hover:scale-[1.01]"
              />
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center p-12 text-slate-400">
              <ZoomIn className="size-12 text-slate-600 mb-2" />
              <p className="text-sm font-semibold">Gambar dokumen tidak tersedia.</p>
              <p className="text-xs text-slate-500">Hanya metadata file yang tersimpan ({certificate.fileName})</p>
            </div>
          )}
        </div>

        {/* Footer info bar */}
        <div className="flex items-center justify-between border-t border-slate-700/60 bg-[#1E293B] px-5 py-2.5 text-[11px] text-slate-400">
          <span>Penerbit: <strong className="text-slate-200">{certificate.issuedBy}</strong></span>
          <span>Masa Berlaku: <strong className="text-slate-200">{certificate.validUntil}</strong></span>
        </div>
      </div>
    </div>
  )
}

