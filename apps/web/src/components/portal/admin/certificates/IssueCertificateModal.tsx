import { Award, CheckCircle2, Loader2, X } from 'lucide-react'
import { useEffect, useState, type FormEvent } from 'react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import {
  issueCertificateManual,
  type CertificateTemplate,
  type CounselorCertificateEligibility,
  type IssuedPsychologistCertificate,
} from '@/lib/portalStore'

interface IssueCertificateModalProps {
  isOpen: boolean
  counselors: CounselorCertificateEligibility[]
  templates: CertificateTemplate[]
  onClose: () => void
  onIssued: (cert: IssuedPsychologistCertificate) => void
}

export function IssueCertificateModal({
  isOpen,
  counselors,
  templates,
  onClose,
  onIssued,
}: IssueCertificateModalProps) {
  useBodyScrollLock(isOpen)

  const activeTemplates = templates.filter((t) => t.isActive)
  const [counselorId, setCounselorId] = useState(() => counselors[0]?.counselorId ?? '')
  const [mode, setMode] = useState<'template' | 'custom'>(() =>
    activeTemplates.length > 0 ? 'template' : 'custom',
  )
  const [templateId, setTemplateId] = useState(() => activeTemplates[0]?.id ?? '')
  const [customTitle, setCustomTitle] = useState('')
  const [customSubtitle, setCustomSubtitle] = useState('Penghargaan Kredensial Klinis Resmi EVA')
  const [customCategoryCode, setCustomCategoryCode] = useState('PRO')
  const [customMilestone, setCustomMilestone] = useState('Penghargaan Kontribusi Klinis Khusus')
  const [customDescription, setCustomDescription] = useState(
    'Diberikan kepada {psychologist_name} (STR: {str_number}) atas dedikasi telekonseling klinis resmi EVA. Nomor Sertifikat: {certificate_number} ({issue_date}).',
  )
  const [submitting, setSubmitting] = useState(false)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  useEffect(() => {
    if (!isOpen) return
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, onClose])

  if (!isOpen) return null

  const selectedCounselor =
    counselors.find((c) => c.counselorId === counselorId) ?? counselors[0] ?? null
  const selectedTemplate =
    activeTemplates.find((t) => t.id === templateId) ?? activeTemplates[0] ?? null
  const previewCategory =
    mode === 'template' && selectedTemplate
      ? selectedTemplate.categoryCode
      : customCategoryCode.trim().toUpperCase() || 'PRO'

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    if (submitting || !selectedCounselor) return

    setSubmitting(true)
    setErrorMsg(null)
    try {
      const issued = await issueCertificateManual(
        mode === 'template' && selectedTemplate
          ? {
              counselorId: selectedCounselor.counselorId,
              templateId: selectedTemplate.id,
            }
          : {
              counselorId: selectedCounselor.counselorId,
              customTitle,
              customSubtitle,
              customCategoryCode: previewCategory,
              customMilestoneCriteria: customMilestone,
              customDescription,
            },
      )
      onIssued(issued)
      onClose()
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal menerbitkan sertifikat.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Terbitkan Sertifikat Resmi Psikolog"
      onClick={onClose}
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 p-3 sm:p-4"
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="flex max-h-[92dvh] w-full max-w-xl flex-col overflow-hidden rounded-[16px] border border-[#E2E8F0] bg-white shadow-2xl"
      >
        <div className="flex items-start justify-between gap-3 border-b border-[#E2E8F0] px-5 py-4">
          <div className="flex items-center gap-2.5">
            <span
              aria-hidden="true"
              className="flex size-9 shrink-0 items-center justify-center rounded-[10px] bg-[#EEF0FF] text-primary"
            >
              <Award className="size-4.5" aria-hidden="true" />
            </span>
            <div>
              <h2 className="text-sm font-bold text-ink sm:text-base">
                Terbitkan Sertifikat Psikolog (Manual Award)
              </h2>
              <p className="text-xs text-ink-muted">
                Nomor otomatis berformat EVA/CERT/{new Date().getFullYear()}/{previewCategory}/XXXXX dengan STR terverifikasi.
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup modal penerbitan sertifikat"
            className="inline-flex min-h-11 min-w-11 cursor-pointer items-center justify-center rounded-[8px] border border-[#768396] text-ink-soft hover:bg-slate-50 hover:text-ink sm:size-8 sm:min-h-0 sm:min-w-0"
          >
            <X className="size-4" aria-hidden="true" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 overflow-y-auto p-5 text-xs">
          {errorMsg && (
            <div
              role="alert"
              className="rounded-[8px] border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 font-medium text-[#991B1B]"
            >
              {errorMsg}
            </div>
          )}

          <div>
            <label htmlFor="issue-counselor-select" className="mb-1 block font-semibold text-ink">
              Pilih Psikolog Terverifikasi *
            </label>
            {counselors.length === 0 ? (
              <p className="rounded-[8px] border border-[#FDE68A] bg-[#FEF3C7] px-3 py-2 text-[#92400E]">
                Belum ada psikolog terverifikasi yang siap menerima sertifikat.
              </p>
            ) : (
              <select
                id="issue-counselor-select"
                value={selectedCounselor?.counselorId ?? ''}
                onChange={(e) => setCounselorId(e.target.value)}
                className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-xs font-medium text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
              >
                {counselors.map((c) => (
                  <option key={c.counselorId} value={c.counselorId}>
                    {c.fullName} - STR: {c.strNumber} ({c.completedSessionsCount} sesi
                    {c.averageRating !== null && c.averageRating !== undefined
                      ? `, Rating ${c.averageRating}`
                      : ''}
                    )
                  </option>
                ))}
              </select>
            )}
          </div>

          <div className="grid grid-cols-2 gap-2 rounded-[8px] bg-[#F1F5F9] p-1">
            <button
              type="button"
              aria-pressed={mode === 'template'}
              disabled={activeTemplates.length === 0}
              onClick={() => setMode('template')}
              className={`min-h-11 cursor-pointer rounded-[6px] text-xs font-semibold disabled:cursor-not-allowed disabled:opacity-50 sm:h-8 sm:min-h-0 ${
                mode === 'template' ? 'bg-white text-ink shadow-2xs' : 'text-ink-muted hover:text-ink'
              }`}
            >
              Gunakan Template ({activeTemplates.length})
            </button>
            <button
              type="button"
              aria-pressed={mode === 'custom'}
              onClick={() => setMode('custom')}
              className={`min-h-11 cursor-pointer rounded-[6px] text-xs font-semibold sm:h-8 sm:min-h-0 ${
                mode === 'custom' ? 'bg-white text-ink shadow-2xs' : 'text-ink-muted hover:text-ink'
              }`}
            >
              Penghargaan Kustom
            </button>
          </div>

          {mode === 'template' && selectedTemplate ? (
            <div className="space-y-2">
              <label htmlFor="issue-template-select" className="block font-semibold text-ink">
                Template Sertifikat *
              </label>
              <select
                id="issue-template-select"
                value={selectedTemplate.id}
                onChange={(e) => setTemplateId(e.target.value)}
                className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-xs font-medium text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
              >
                {activeTemplates.map((tpl) => (
                  <option key={tpl.id} value={tpl.id}>
                    [{tpl.code}] {tpl.title} ({tpl.categoryCode})
                  </option>
                ))}
              </select>
              <div className="rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3 text-[11px] text-ink-soft">
                <p className="font-bold text-ink">{selectedTemplate.milestoneCriteria}</p>
                <p className="mt-1">{selectedTemplate.description}</p>
              </div>
            </div>
          ) : (
            <div className="space-y-3">
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                <div className="sm:col-span-2">
                  <label htmlFor="issue-custom-title" className="mb-1 block font-semibold text-ink">
                    Judul Sertifikat *
                  </label>
                  <input
                    id="issue-custom-title"
                    type="text"
                    required
                    minLength={4}
                    value={customTitle}
                    onChange={(e) => setCustomTitle(e.target.value)}
                    placeholder="SERTIFIKAT PENYULUHAN KLINIS EVA"
                    className="min-h-11 w-full rounded-[8px] border border-[#768396] px-3 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                  />
                </div>
                <div>
                  <label
                    htmlFor="issue-custom-category"
                    className="mb-1 block font-semibold text-ink"
                  >
                    Kode Kategori *
                  </label>
                  <input
                    id="issue-custom-category"
                    type="text"
                    required
                    minLength={2}
                    maxLength={16}
                    value={customCategoryCode}
                    onChange={(e) => setCustomCategoryCode(e.target.value.toUpperCase())}
                    placeholder="PRO"
                    className="min-h-11 w-full rounded-[8px] border border-[#768396] px-3 font-mono text-xs uppercase text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                  />
                </div>
              </div>
              <div>
                <label htmlFor="issue-custom-subtitle" className="mb-1 block font-semibold text-ink">
                  Subjudul
                </label>
                <input
                  id="issue-custom-subtitle"
                  type="text"
                  required
                  value={customSubtitle}
                  onChange={(e) => setCustomSubtitle(e.target.value)}
                  className="min-h-11 w-full rounded-[8px] border border-[#768396] px-3 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                />
              </div>
              <div>
                <label htmlFor="issue-custom-milestone" className="mb-1 block font-semibold text-ink">
                  Kriteria Penghargaan *
                </label>
                <input
                  id="issue-custom-milestone"
                  type="text"
                  required
                  value={customMilestone}
                  onChange={(e) => setCustomMilestone(e.target.value)}
                  className="min-h-11 w-full rounded-[8px] border border-[#768396] px-3 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                />
              </div>
              <div>
                <label
                  htmlFor="issue-custom-description"
                  className="mb-1 block font-semibold text-ink"
                >
                  Deskripsi Sertifikat *
                </label>
                <textarea
                  id="issue-custom-description"
                  rows={3}
                  required
                  minLength={10}
                  value={customDescription}
                  onChange={(e) => setCustomDescription(e.target.value)}
                  className="w-full rounded-[8px] border border-[#768396] p-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
                />
              </div>
            </div>
          )}

          <div className="flex items-center justify-end gap-2 border-t border-[#E2E8F0] pt-3.5">
            <button
              type="button"
              onClick={onClose}
              className="inline-flex min-h-11 cursor-pointer items-center rounded-[8px] border border-[#768396] bg-white px-4 font-semibold text-ink hover:bg-slate-50 sm:h-9 sm:min-h-0"
            >
              Batal
            </button>
            <button
              type="submit"
              disabled={submitting || !selectedCounselor}
              className="inline-flex min-h-11 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 font-semibold text-white hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-50 sm:h-9 sm:min-h-0"
            >
              {submitting ? (
                <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />
              ) : (
                <CheckCircle2 className="size-3.5" aria-hidden="true" />
              )}
              <span>Terbitkan Sertifikat</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
