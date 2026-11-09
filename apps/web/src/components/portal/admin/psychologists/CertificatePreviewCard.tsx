import { CheckCircle2, FileText, Maximize2, ShieldCheck, XCircle } from 'lucide-react'
import { useState } from 'react'
import { CertificateImageModal } from './CertificateImageModal'
import { cn } from '@/lib/cn'
import type { PsychologistCertificate } from '@/types/portal'

interface CertificatePreviewCardProps {
  activeDoc: PsychologistCertificate
  onToggleDoc: (docId: string) => void
}

export function CertificatePreviewCard({
  activeDoc,
  onToggleDoc,
}: CertificatePreviewCardProps) {
  const [isZoomOpen, setIsZoomOpen] = useState(false)
  const [isBtnHovered, setIsBtnHovered] = useState(false)

  return (
    <>
      <div className="flex flex-col rounded-[16px] border border-[#CBD5E1] bg-white p-4 shadow-xs sm:p-5">
        {/* Document Top Header & Action Toolbar */}
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[#E2E8F0] pb-3.5">
          <div className="flex items-center gap-2">
            <span className="rounded-[6px] bg-primary/10 px-2.5 py-1 text-[11px] font-bold text-primary uppercase">
              {activeDoc.docType}
            </span>
            <span className="text-xs font-bold text-ink sm:text-sm">
              {activeDoc.title}
            </span>
            {activeDoc.verified && (
              <span className="inline-flex items-center gap-1 rounded-full bg-[#F0FDF4] px-2 py-0.5 text-[10px] font-bold text-[#16A34A]">
                <ShieldCheck className="size-3" /> Valid
              </span>
            )}
          </div>
          <button
            type="button"
            onClick={() => setIsZoomOpen(true)}
            className="inline-flex cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] px-3 py-1.5 text-xs font-semibold text-ink-muted transition-colors hover:border-primary/50 hover:bg-white hover:text-primary"
          >
            <Maximize2 className="size-3.5" />
            <span>Perbesar Dokumen</span>
          </button>
        </div>

        {/* Focus Canvas Image Frame (Lega & Flexible Height) */}
        <div className="relative mt-4 overflow-hidden rounded-[12px] border border-slate-200 bg-slate-100/80">
          {activeDoc.imageUrl ? (
            <div
              onClick={() => setIsZoomOpen(true)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') setIsZoomOpen(true)
              }}
              title="Klik untuk memperbesar tampilan berkas sertifikat"
              className="group relative flex h-72 min-h-[300px] w-full cursor-zoom-in items-center justify-center p-3 sm:h-96 transition-colors hover:bg-slate-200/50"
            >
              <img
                src={activeDoc.imageUrl}
                alt={`Pratinjau ${activeDoc.title}`}
                className="max-h-full max-w-full rounded-[6px] object-contain shadow-md transition-transform duration-200 group-hover:scale-[1.015]"
              />
              <div className="absolute inset-0 flex items-center justify-center bg-ink/25 opacity-0 backdrop-blur-[1px] transition-opacity duration-200 group-hover:opacity-100">
                <span className="inline-flex items-center gap-2 rounded-full bg-white/95 px-4 py-2 text-xs font-bold text-ink shadow-lg">
                  <Maximize2 className="size-4 text-primary" /> Klik untuk Memperbesar Dokumen
                </span>
              </div>
            </div>
          ) : (
            <div className="flex h-72 w-full flex-col items-center justify-center gap-2 text-ink-muted sm:h-80">
              <FileText className="size-10 text-slate-400" />
              <p className="text-xs font-semibold">Pratinjau dokumen tidak tersedia</p>
              <p className="font-mono text-[11px] text-slate-500">{activeDoc.fileName}</p>
            </div>
          )}
        </div>

        {/* Integrated Metadata & Document Verification Control */}
        <div className="mt-4 rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5">
          <div className="grid grid-cols-1 gap-3 text-[11px] sm:grid-cols-3">
            <div>
              <span className="block text-[10px] font-bold uppercase tracking-wider text-ink-muted">
                No. Registrasi Dokumen
              </span>
              <span className="mt-0.5 block font-mono font-bold text-ink">
                {activeDoc.documentNumber}
              </span>
            </div>

            <div>
              <span className="block text-[10px] font-bold uppercase tracking-wider text-ink-muted">
                Instansi Penerbit
              </span>
              <span className="mt-0.5 block truncate font-medium text-ink" title={activeDoc.issuedBy}>
                {activeDoc.issuedBy}
              </span>
            </div>

            <div>
              <span className="block text-[10px] font-bold uppercase tracking-wider text-ink-muted">
                Masa Berlaku
              </span>
              <span className="mt-0.5 block font-semibold text-ink">
                {activeDoc.validUntil}
              </span>
            </div>
          </div>

          <div className="mt-3.5 flex flex-col gap-2.5 border-t border-[#E2E8F0] pt-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex min-w-0 items-center gap-2 overflow-hidden text-xs">
              <span
                className="truncate font-mono text-[11px] text-ink-muted"
                title={`${activeDoc.fileName} (${activeDoc.fileSize})`}
              >
                {activeDoc.fileName}
              </span>
              <span className="shrink-0 text-[10px] text-ink-muted/80">
                ({activeDoc.fileSize})
              </span>
            </div>

            <button
              type="button"
              onClick={() => onToggleDoc(activeDoc.id)}
              onMouseEnter={() => setIsBtnHovered(true)}
              onMouseLeave={() => setIsBtnHovered(false)}
              className={cn(
                'inline-flex h-9 cursor-pointer items-center justify-center gap-1.5 rounded-[8px] border px-4 text-xs font-semibold whitespace-nowrap transition-all sm:w-auto sm:shrink-0',
                activeDoc.verified
                  ? isBtnHovered
                    ? 'border-[#FECACA] bg-[#FEF2F2] text-[#B91C1C]'
                    : 'border-[#BBF7D0] bg-[#F0FDF4] text-[#166534]'
                  : 'border-primary bg-primary text-white shadow-2xs hover:bg-primary-hover',
              )}
            >
              {activeDoc.verified ? (
                isBtnHovered ? (
                  <>
                    <XCircle className="size-3.5" />
                    <span>Batalkan Validasi Dokumen</span>
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="size-3.5" />
                    <span>Dokumen Terverifikasi Valid</span>
                  </>
                )
              ) : (
                <>
                  <CheckCircle2 className="size-3.5" />
                  <span>Tandai Dokumen Ini Valid</span>
                </>
              )}
            </button>
          </div>
        </div>
      </div>

      {/* High-Resolution Zoom Modal */}
      <CertificateImageModal
        isOpen={isZoomOpen}
        certificate={activeDoc}
        onClose={() => setIsZoomOpen(false)}
      />
    </>
  )
}
