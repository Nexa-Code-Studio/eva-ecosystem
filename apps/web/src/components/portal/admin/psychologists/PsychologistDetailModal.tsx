import { ArrowUpCircle, CheckCircle2, FileText, UserCheck, X, XCircle } from 'lucide-react'
import { useState } from 'react'
import { CertificatePreviewCard } from './CertificatePreviewCard'
import { PsychologistModalFooter } from './PsychologistModalFooter'
import { PsychologistProfileSidebar } from './PsychologistProfileSidebar'
import { PsychologistRejectModal } from './PsychologistRejectModal'
import { PsychologistRejectUpgradeModal } from './PsychologistRejectUpgradeModal'
import {
  PsychologistShieldBadge,
  UpgradeRequestBadge,
  VerificationBadge,
} from '@/components/portal/PortalBadges'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { cn } from '@/lib/cn'
import {
  approvePsychologistUpgrade,
  reviewIndependentPsychologist,
  togglePsychologistDocumentVerified,
  updatePsychologistStatus,
} from '@/lib/portalStore'
import type { PartnerAccount, Psychologist, PsychologistCertificate } from '@/types/portal'

interface PsychologistDetailModalProps {
  isOpen: boolean
  psy: Psychologist | null
  partner: PartnerAccount | null
  onClose: () => void
  onApproveMandiri: (psyId: string, fullName: string) => void
  onFeedback: (msg: string) => void
}

export function PsychologistDetailModal({
  isOpen,
  psy,
  partner,
  onClose,
  onApproveMandiri,
  onFeedback,
}: PsychologistDetailModalProps) {
  useBodyScrollLock(isOpen && Boolean(psy))

  const [activeDocId, setActiveDocId] = useState<string | null>(null)
  const [mobileTab, setMobileTab] = useState<'documents' | 'profile'>('documents')
  const [isRejectOpen, setIsRejectOpen] = useState(false)
  const [isRejectUpgradeOpen, setIsRejectUpgradeOpen] = useState(false)

  if (!isOpen || !psy) return null

  const isMitra = psy.role === 'professional_mitra' || (!psy.role && psy.partnerId)
  const isMandiri = !isMitra
  const hasUpgrade = Boolean(psy.upgradeRequest)
  const targetUpgradeLabel =
    psy.upgradeRequest?.targetRole === 'relawan_utama' ||
    (psy.upgradeRequest?.targetRole as string) === 'relawan_pro'
      ? 'Relawan Utama'
      : 'Relawan Profesional'

  // Combine regular documents and upgrade request documents
  const standardDocs: PsychologistCertificate[] = psy.documents ?? []
  const upgradeDocs: PsychologistCertificate[] = psy.upgradeRequest?.documents ?? []
  const allDocs: PsychologistCertificate[] = [...upgradeDocs, ...standardDocs]

  const activeDoc =
    allDocs.find((d) => d.id === activeDocId) ?? upgradeDocs[0] ?? standardDocs[0] ?? null
  const verifiedCount = standardDocs.filter((d) => d.verified).length

  const handleToggleDoc = (docId: string) => {
    togglePsychologistDocumentVerified(psy.id, docId)
    onFeedback('Status validitas dokumen sertifikat berhasil diperbarui.')
  }

  const handleSuspend = () => {
    reviewIndependentPsychologist(psy.id, 'suspended')
    onFeedback(`Akun "${psy.fullName}" dinonaktifkan sementara.`)
  }

  const handleApproveUpgrade = () => {
    approvePsychologistUpgrade(psy.id)
    onFeedback(
      `Permohonan upgrade "${psy.fullName}" ke ${targetUpgradeLabel} telah disetujui! Status peran diperbarui.`,
    )
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
        <div className="flex max-h-[94dvh] w-full max-w-5xl flex-col overflow-hidden rounded-[20px] border border-[#E2E8F0] bg-white shadow-2xl">
          {/* 1. Modal Top Header */}
          <div className="flex items-center justify-between gap-3 border-b border-[#E2E8F0] px-4 py-3.5 sm:px-6 sm:py-4">
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <h2
                  id="psy-detail-title"
                  className="line-clamp-1 text-base font-bold text-ink sm:line-clamp-2 sm:text-lg"
                  title={psy.fullName}
                >
                  {psy.fullName}
                </h2>
                <PsychologistShieldBadge
                  role={psy.role}
                  isPriorityMobile={psy.isPriorityMobile}
                  partnerName={partner?.facilityName}
                  upgradeRequest={psy.upgradeRequest}
                />
                {hasUpgrade ? (
                  <UpgradeRequestBadge request={psy.upgradeRequest} />
                ) : isMandiri ? (
                  <span className="shrink-0">
                    <VerificationBadge status={psy.verificationStatus ?? 'pending'} />
                  </span>
                ) : null}
              </div>
              <p className="mt-0.5 line-clamp-1 text-xs text-ink-muted">
                {hasUpgrade
                  ? `Verifikasi dokumen dan riwayat pendampingan untuk pengajuan upgrade ke ${targetUpgradeLabel}.`
                  : 'Verifikasi kelengkapan berkas izin praktik dan dokumen sertifikasi.'}
              </p>
            </div>
            <button
              type="button"
              onClick={onClose}
              aria-label="Tutup modal"
              className="inline-flex size-9 shrink-0 cursor-pointer items-center justify-center rounded-[10px] border border-[#CBD5E1] text-ink-muted transition-colors hover:bg-slate-100"
            >
              <X className="size-4" />
            </button>
          </div>

          {/* 2. Segmented Tab Switch (Mobile Only, < lg) */}
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
                <FileText className="size-3.5" /> Berkas Sertifikat ({allDocs.length})
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

          {/* 3. Modal Body: 2-Column Studio Grid */}
          <div className="grid flex-1 grid-cols-1 overflow-y-auto lg:grid-cols-12">
            {/* Left Column: Sidebar Profil Psikolog (Col-span 4) */}
            <div
              className={cn(
                'border-b border-[#E2E8F0] bg-[#F8FAFC]/50 p-5 lg:col-span-4 lg:border-r lg:border-b-0 lg:block',
                mobileTab === 'profile' ? 'block' : 'hidden',
              )}
            >
              <PsychologistProfileSidebar psy={psy} partner={partner} />
            </div>

            {/* Right Column: Focus Document Canvas (Col-span 8) */}
            <div
              className={cn(
                'flex flex-col space-y-4 p-5 lg:col-span-8 lg:p-6 lg:block',
                mobileTab === 'documents' ? 'block' : 'hidden',
              )}
            >
              {/* Highlight Review Panel ONLY if upgradeRequest exists */}
              {hasUpgrade && (
                <div className="rounded-[12px] border border-amber-300 bg-amber-50/70 p-4 shadow-xs">
                  <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between border-b border-amber-200 pb-3">
                    <div className="flex items-center gap-2 text-amber-900">
                      <span className="flex size-7 items-center justify-center rounded-full bg-amber-200 text-amber-800">
                        <ArrowUpCircle className="size-4" />
                      </span>
                      <div>
                        <h3 className="text-xs font-bold sm:text-sm">
                          Permohonan Upgrade ke {targetUpgradeLabel}
                        </h3>
                        <p className="text-[11px] text-amber-800/90">
                          Diajukan pada {psy.upgradeRequest?.requestedAt}
                        </p>
                      </div>
                    </div>

                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => setIsRejectUpgradeOpen(true)}
                        className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#FECACA] bg-white px-3 text-xs font-semibold text-[#B91C1C] hover:bg-[#FEF2F2]"
                      >
                        <XCircle className="size-3.5" />
                        <span>Tolak Upgrade</span>
                      </button>
                      <button
                        type="button"
                        onClick={handleApproveUpgrade}
                        className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[8px] bg-[#16A34A] px-3.5 text-xs font-semibold text-white shadow-xs hover:bg-[#15803D]"
                      >
                        <CheckCircle2 className="size-3.5" />
                        <span>Setujui Upgrade ke {targetUpgradeLabel}</span>
                      </button>
                    </div>
                  </div>

                  <div className="mt-2.5">
                    <span className="text-[10px] font-bold tracking-wider text-amber-800 uppercase">
                      Portofolio dan Catatan Pengaju:
                    </span>
                    <p className="mt-1 rounded-[8px] border border-amber-200 bg-white p-3 text-xs text-ink leading-relaxed">
                      {psy.upgradeRequest?.notes || 'Tidak ada catatan tambahan.'}
                    </p>
                  </div>
                </div>
              )}

              {/* Document Selection & Preview Canvas */}
              {allDocs.length > 0 ? (
                <>
                  <div>
                    <div className="flex items-center justify-between">
                      <span className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                        Pilih Dokumen Sertifikat ({allDocs.length})
                      </span>
                      <span className="text-xs font-semibold text-primary">
                        {hasUpgrade
                          ? `${allDocs.filter((d) => d.verified).length}/${allDocs.length} Dokumen Terverifikasi`
                          : `${verifiedCount}/${standardDocs.length} Dokumen Valid`}
                      </span>
                    </div>

                    <div className="mt-2.5 flex flex-wrap gap-2">
                      {allDocs.map((doc) => {
                        const isSelected = activeDoc?.id === doc.id
                        const isUpgradeDoc = upgradeDocs.some((d) => d.id === doc.id)
                        return (
                          <button
                            key={doc.id}
                            type="button"
                            onClick={() => setActiveDocId(doc.id)}
                            className={cn(
                              'inline-flex cursor-pointer items-center gap-2 rounded-[10px] border px-3 py-1.5 text-xs font-semibold transition-all',
                              isSelected
                                ? isUpgradeDoc
                                  ? 'border-amber-600 bg-amber-600 text-white shadow-2xs'
                                  : 'border-primary bg-primary text-white shadow-2xs'
                                : isUpgradeDoc
                                  ? 'border-amber-300 bg-amber-50 text-amber-900 hover:bg-amber-100'
                                  : 'border-[#CBD5E1] bg-white text-ink hover:bg-[#F8FAFC]',
                            )}
                          >
                            <span>{doc.docType}</span>
                            {isUpgradeDoc && (
                              <span
                                className={cn(
                                  'rounded px-1 py-0.2 text-[9px] font-bold',
                                  isSelected ? 'bg-amber-800 text-white' : 'bg-amber-200 text-amber-900',
                                )}
                              >
                                Berkas Upgrade
                              </span>
                            )}
                            {doc.verified ? (
                              <CheckCircle2
                                className={cn('size-3.5', isSelected ? 'text-white' : 'text-[#16A34A]')}
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

                  {/* Focus Document Preview Card */}
                  {activeDoc && (
                    <CertificatePreviewCard activeDoc={activeDoc} onToggleDoc={handleToggleDoc} />
                  )}
                </>
              ) : isMitra ? (
                /* Faskes status configuration or empty documents */
                <div className="flex h-full flex-col justify-center rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-6 text-center">
                  <FileText className="mx-auto size-12 text-[#94A3B8]" />
                  <h4 className="mt-2 text-sm font-bold text-ink">
                    Psikolog Faskes Mitra Terafiliasi
                  </h4>
                  <p className="mt-1 text-xs text-ink-muted">
                    Psikolog ini didaftarkan oleh faskes mitra ({partner?.facilityName ?? 'Mitra'}).
                    Verifikasi berkas dijamin melalui penjaminan mutu instansi terkait.
                  </p>
                  <div className="mx-auto mt-4 w-full max-w-xs">
                    <label className="block text-left text-xs font-semibold text-ink">
                      Status Praktik
                    </label>
                    <select
                      value={psy.status}
                      onChange={(e) => {
                        updatePsychologistStatus(
                          psy.id,
                          e.target.value as 'active' | 'on_leave' | 'inactive',
                        )
                        onFeedback(`Status praktik "${psy.fullName}" berhasil diperbarui.`)
                      }}
                      className="mt-1.5 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink"
                    >
                      <option value="active">Aktif Menerima Rujukan</option>
                      <option value="on_leave">Sedang Cuti</option>
                      <option value="inactive">Nonaktif</option>
                    </select>
                  </div>
                </div>
              ) : (
                <div className="flex h-full flex-col justify-center rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-6 text-center">
                  <FileText className="mx-auto size-12 text-[#94A3B8]" />
                  <h4 className="mt-2 text-sm font-bold text-ink">Belum Ada Berkas</h4>
                  <p className="mt-1 text-xs text-ink-muted">
                    Relawan ini belum melampirkan berkas dokumen digital.
                  </p>
                </div>
              )}
            </div>
          </div>

          {/* 4. Sticky Footer Action Bar */}
          <PsychologistModalFooter
            isMandiri={isMandiri}
            verificationStatus={psy.verificationStatus}
            documentsCount={standardDocs.length}
            verifiedCount={verifiedCount}
            upgradeRequest={psy.upgradeRequest}
            onClose={onClose}
            onOpenReject={() => setIsRejectOpen(true)}
            onApprove={() => {
              onApproveMandiri(psy.id, psy.fullName)
              onClose()
            }}
            onSuspend={handleSuspend}
            onApproveUpgrade={handleApproveUpgrade}
            onOpenRejectUpgrade={() => setIsRejectUpgradeOpen(true)}
          />
        </div>
      </div>

      {/* Pop-up Dialog Penolakan Berkas Pendaftaran Awal */}
      <PsychologistRejectModal
        isOpen={isRejectOpen}
        psyId={psy.id}
        psyFullName={psy.fullName}
        initialReason={psy.rejectionReason}
        onClose={() => setIsRejectOpen(false)}
        onFeedback={onFeedback}
        onSuccess={() => onClose()}
      />

      {/* Pop-up Dialog Penolakan Permohonan Upgrade */}
      <PsychologistRejectUpgradeModal
        isOpen={isRejectUpgradeOpen}
        psyId={psy.id}
        psyFullName={psy.fullName}
        upgradeRequest={psy.upgradeRequest}
        onClose={() => setIsRejectUpgradeOpen(false)}
        onFeedback={onFeedback}
        onSuccess={() => onClose()}
      />
    </>
  )
}
