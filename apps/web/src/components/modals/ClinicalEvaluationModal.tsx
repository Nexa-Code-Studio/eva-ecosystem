import { CheckCircle2, ShieldAlert, Stethoscope, X } from 'lucide-react'
import { useEffect, useRef } from 'react'
import { Link } from 'react-router'
import { Button } from '@/components/ui'
import { clinicalEvaluationData } from '@/content/landing'

interface ClinicalEvaluationModalProps {
  isOpen: boolean
  onClose: () => void
}

export function ClinicalEvaluationModal({ isOpen, onClose }: ClinicalEvaluationModalProps) {
  const modalRef = useRef<HTMLDivElement>(null)

  // Handle escape key & backdrop click
  useEffect(() => {
    if (!isOpen) return

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose()
      }
    }

    const originalOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', handleKeyDown)

    return () => {
      document.body.style.overflow = originalOverflow
      window.removeEventListener('keydown', handleKeyDown)
    }
  }, [isOpen, onClose])

  if (!isOpen) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6"
      role="dialog"
      aria-modal="true"
      aria-labelledby="clinical-eval-title"
    >
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-obsidian/60 backdrop-blur-sm transition-opacity"
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Modal Container */}
      <div
        ref={modalRef}
        className="relative z-10 flex max-h-[90vh] w-full max-w-2xl flex-col overflow-hidden rounded-[24px] border border-border-subtle bg-white shadow-nav animate-enter"
      >
        {/* Header */}
        <div className="flex items-start justify-between border-b border-border-subtle/80 p-6 sm:p-8">
          <div className="flex items-center gap-3">
            <span className="flex size-11 items-center justify-center rounded-[14px] bg-primary-container text-primary">
              <Stethoscope className="size-5" />
            </span>
            <div>
              <p className="text-[11px] font-extrabold tracking-wider uppercase text-primary">
                Transparansi Standar Klinis
              </p>
              <h2 id="clinical-eval-title" className="text-title-md sm:text-[20px] font-bold text-ink">
                Ringkasan Evaluasi &amp; Batasan Klinis
              </h2>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup dialog evaluasi klinis"
            className="flex size-9 items-center justify-center rounded-full text-ink-soft transition-colors hover:bg-canvas hover:text-ink focus-visible:outline-2 focus-visible:outline-primary"
          >
            <X className="size-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="flex-1 overflow-y-auto p-6 sm:p-8 space-y-6">
          <div className="rounded-[16px] border border-primary/20 bg-primary-container/30 p-4">
            <p className="text-body-md text-ink leading-relaxed">
              EVA diposisikan secara tegas sebagai <strong>pertolongan pertama psikologis (digital first-aid)</strong> yang non-diagnostik. Seluruh interaksi ditujukan untuk stabilisasi emosi harian dan menjembatani pengguna ke faskes/psikolog manusia ketika diperlukan intervensi mendalam.
            </p>
          </div>

          <div className="space-y-5">
            {clinicalEvaluationData.map((item) => (
              <div
                key={item.id}
                className="rounded-[18px] border border-border-subtle/90 bg-canvas/40 p-5 transition-colors hover:border-primary/30 hover:bg-canvas/70"
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h3 className="text-title-md font-bold text-ink">{item.title}</h3>
                  <span className="rounded-pill bg-white px-2.5 py-1 text-[10px] font-extrabold tracking-wide uppercase text-primary border border-border-subtle">
                    {item.badge}
                  </span>
                </div>
                <p className="mt-2 text-body-md text-ink-soft leading-relaxed">{item.summary}</p>
                <ul className="mt-3.5 space-y-2">
                  {item.details.map((detail, idx) => (
                    <li key={idx} className="flex items-start gap-2 text-caption !tracking-normal text-ink">
                      <CheckCircle2 className="mt-0.5 size-3.5 shrink-0 text-success" />
                      <span>{detail}</span>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>

          <div className="flex items-start gap-3 rounded-[16px] border border-crisis-border bg-crisis-bg p-4 text-crisis-text">
            <ShieldAlert className="mt-0.5 size-5 shrink-0" />
            <div className="text-caption !tracking-normal">
              <strong>Catatan Darurat:</strong> Jika Anda atau orang terdekat mengalami dorongan bahaya diri, harap segera hubungi Hotline Kemenkes 119 Ext 8 atau datangi instalasi gawat darurat faskes terdekat.
            </div>
          </div>
        </div>

        {/* Footer actions */}
        <div className="flex flex-col-reverse gap-3 border-t border-border-subtle/80 bg-canvas/30 p-5 sm:flex-row sm:items-center sm:justify-between sm:px-8">
          <Button variant="secondary" size="md" onClick={onClose}>
            Tutup
          </Button>
          <div className="flex flex-wrap gap-2">
            <Link to="/pengajuan-mitra" onClick={onClose}>
              <Button variant="primary" size="md">
                Ajukan Kemitraan Faskes
              </Button>
            </Link>
          </div>
        </div>
      </div>
    </div>
  )
}

