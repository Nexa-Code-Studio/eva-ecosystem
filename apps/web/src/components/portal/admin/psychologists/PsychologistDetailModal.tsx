import { CheckCircle2, FileText, UserCheck, X } from 'lucide-react'
import { useState } from 'react'
import { CertificatePreviewCard } from './CertificatePreviewCard'
import { PsychologistModalFooter } from './PsychologistModalFooter'
import { PsychologistProfileSidebar } from './PsychologistProfileSidebar'
import { PsychologistRejectModal } from './PsychologistRejectModal'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { cn } from '@/lib/cn'
import {
  suspendPsychologistAccount,
  togglePsychologistDocumentVerified,
} from '@/lib/portalStore'
import type { Psychologist, PsychologistCertificate } from '@/types/portal'

interface PsychologistDetailModalProps {
  isOpen: boolean
  psy: Psychologist | null
  onClose: () => void
  onApprove: (psyId: string, fullName: string, notes?: string) => Promise<void>
  onFeedback: (msg: string) => void
}

export function PsychologistDetailModal({
  isOpen,
  psy,
  onClose,
  onApprove,
  onFeedback,
}: PsychologistDetailModalProps) {
  useBodyScrollLock(isOpen && Boolean(psy))

  const [activeDocId, setActiveDocId] = useState<string | null>(null)
  const [mobileTab, setMobileTab] = useState<'documents' | 'profile'>('documents')
  const [approvalNote, setApprovalNote] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [rejectModalOpen, setRejectModalOpen] = useState(false)

  if (!isOpen || !psy) return null

  const docs: PsychologistCertificate[] = psy.documents ?? []
  const activeDoc = docs.find((d) => d.id === activeDocId) ?? docs[0] ?? null
  const verifiedCount = docs.filter((d) => d.verified).length

  const handleToggleDoc = (docId: string) => {
    togglePsychologistDocumentVerified(psy.id, docId)
    onFeedback('Status validitas dokumen sertifikat berhasil diperbarui.')
  }

  const handleApproveClick = async () => {
    setSubmitting(true)
    try {
      await onApprove(psy.id, psy.fullName, approvalNote.trim() || undefined)
      setApprovalNote('')
      onClose()
    } finally {
      setSubmitting(false)
    }
  }

  const handleSuspend = () => {
    suspendPsychologistAccount(psy.id)
    onFeedback(`Akun "${psy.fullName}" dinonaktifkan sementara.`)
    onClose()
  }

  return (
    <>
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="psy-detail-title"
        className="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 p-3 sm:p-6"
      >
        <div className="flex max-h-[94dvh] w-full max-w-7xl flex-col overflow-hidden rounded-[20px] border border-[#E2E8F0] bg-white shadow-2xl">
          <div className="flex items-center justify-between gap-3 border-b border-[#E2E8F0] bg-white px-4 py-3.5 sm:px-6 sm:py-4">
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <h2
                  id="psy-detail-title"
                  className="text-base font-bold tracking-tight text-ink sm:text-lg"
                >
                  {psy.verificationStatus === 'verified'
                    ? 'Profil & Kredensial Psikolog Terverifikasi'
                    : 'Verifikasi Kredensial STR/SIP Psikolog Mandiri'}
                </h2>
                <span className="hidden text-xs text-ink-muted sm:inline-block">·</span>
                <span className="hidden font-mono text-xs text-ink-muted sm:inline-block">
                  ID: {psy.id.slice(0, 8)}
                </span>
              </div>
              <p className="mt-0.5 line-clamp-1 text-xs text-ink-muted">
                Tinjau kecocokan nomor STR, SIP/SIPP, dan keabsahan dokumen sebelum mengaktifkan akun di Eva Counselor Mobile.
              </p>
            </div>
            <button
              type="button"
              onClick={onClose}
              aria-label="Tutup modal"
              className="inline-flex size-9 shrink-0 cursor-pointer items-center justify-center rounded-[10px] border border-[#CBD5E1] text-ink-muted transition-colors hover:bg-slate-100 hover:text-ink"
            >
              <X className="size-4" />
            </button>
          </div>

          {docs.length > 0 && (
            <div className="flex border-b border-[#E2E8F0] bg-[#F8FAFC] p-2 lg:hidden">
              <button
                type="button"
                onClick={() => setMobileTab('documents')}
                className={cn(
                  'flex-1 cursor-pointer rounded-[8px] py-2 text-center text-xs font-semibold transition-colors',
                  mobileTab === 'documents'
                    ? 'bg-white text-primary shadow-xs'
                    : 'text-ink-muted hover:text-ink',
                )}
              >
                <span className="inline-flex items-center gap-1.5">
                  <FileText className="size-3.5" /> Dokumen STR/SIP ({docs.length})
                </span>
              </button>
              <button
                type="button"
                onClick={() => setMobileTab('profile')}
                className={cn(
                  'flex-1 cursor-pointer rounded-[8px] py-2 text-center text-xs font-semibold transition-colors',
                  mobileTab === 'profile'
                    ? 'bg-white text-primary shadow-xs'
                    : 'text-ink-muted hover:text-ink',
                )}
              >
                <span className="inline-flex items-center gap-1.5">
                  <UserCheck className="size-3.5" /> Biodata &amp; Profil
                </span>
              </button>
            </div>
          )}

          <div className="grid flex-1 grid-cols-1 overflow-y-auto lg:grid-cols-12">
            <div
              className={cn(
                'border-b border-[#E2E8F0] bg-[#F8FAFC]/60 p-5 lg:col-span-4 lg:block lg:border-r lg:border-b-0',
                mobileTab === 'profile' ? 'block' : 'hidden',
              )}
            >
              <PsychologistProfileSidebar psy={psy} />
            </div>

            <div
              className={cn(
                'flex flex-col space-y-4 p-5 lg:sticky lg:top-0 lg:col-span-8 lg:h-fit lg:self-start lg:p-6',
                mobileTab === 'documents' ? 'block' : 'hidden',
              )}
            >
              {docs.length > 0 ? (
                <>
                  <div>
                    <div className="flex items-center justify-between">
                      <span className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                        Pilih Dokumen Kredensial ({docs.length})
                      </span>
                      <span className="text-xs font-semibold text-primary">
                        {verifiedCount}/{docs.length} Dokumen Valid
                      </span>
                    </div>

                    <div className="mt-2.5 flex flex-wrap gap-2">
                      {docs.map((doc) => {
                        const isSelected = activeDoc?.id === doc.id
                        return (
                          <button
                            key={doc.id}
                            type="button"
                            onClick={() => setActiveDocId(doc.id)}
                            className={cn(
                              'inline-flex cursor-pointer items-center gap-2 rounded-[10px] border px-3 py-1.5 text-xs font-semibold transition-all',
                              isSelected
                                ? 'border-primary bg-primary text-white shadow-2xs'
                                : 'border-[#CBD5E1] bg-white text-ink hover:bg-[#F8FAFC]',
                            )}
                          >
                            <span>{doc.docType}</span>
                            {doc.verified ? (
                              <CheckCircle2
                                className={cn(
                                  'size-3.5',
                                  isSelected ? 'text-white' : 'text-[#16A34A]',
                                )}
                              />
                            ) : (
                              <span
                                className={cn(
                                  'size-2 rounded-full',
                                  isSelected ? 'bg-white' : 'bg-[#F59E0B]',
                                )}
                              />
                            )}
                          </button>
                        )
                      })}
                    </div>
                  </div>

                  {activeDoc && (
                    <CertificatePreviewCard activeDoc={activeDoc} onToggleDoc={handleToggleDoc} />
                  )}
                </>
              ) : (
                <div className="flex h-full flex-col justify-center rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-6 text-center">
                  <FileText className="mx-auto size-12 text-[#94A3B8]" />
                  <h4 className="mt-2 text-sm font-bold text-ink">Belum Ada Lampiran Digital</h4>
                  <p className="mt-1 text-xs text-ink-muted">
                    {psy.certificateDocUrl
                      ? `Tautan dokumen terdaftar: ${psy.certificateDocUrl}`
                      : 'Psikolog belum mengunggah salinan gambar STR/SIP digital.'}
                  </p>
                </div>
              )}
            </div>
          </div>

          <PsychologistModalFooter
            verificationStatus={psy.verificationStatus}
            documentsCount={docs.length}
            verifiedCount={verifiedCount}
            approvalNote={approvalNote}
            submitting={submitting}
            onApprovalNoteChange={setApprovalNote}
            onClose={onClose}
            onOpenReject={() => setRejectModalOpen(true)}
            onApprove={handleApproveClick}
            onSuspend={handleSuspend}
          />
        </div>
      </div>

      <PsychologistRejectModal
        isOpen={rejectModalOpen}
        psyId={psy.id}
        psyFullName={psy.fullName}
        initialReason={psy.verificationNotes}
        onClose={() => setRejectModalOpen(false)}
        onFeedback={onFeedback}
        onSuccess={() => onClose()}
      />
    </>
  )
}
