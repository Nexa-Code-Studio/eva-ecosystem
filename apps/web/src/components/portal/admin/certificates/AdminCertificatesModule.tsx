import {
  AlertCircle,
  Award,
  Ban,
  CheckCircle2,
  Download,
  Eye,
  Loader2,
  Pencil,
  Plus,
  RefreshCw,
  Search,
  Sparkles,
  X,
} from 'lucide-react'
import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react'
import { useSearchParams } from 'react-router'
import { IssueCertificateModal } from './IssueCertificateModal'
import { OfficialCertificatePreviewModal } from './OfficialCertificatePreviewModal'
import { TablePagination } from '@/components/portal/TablePagination'
import { useUrlPagination } from '@/hooks/useUrlPagination'
import { cn } from '@/lib/cn'
import {
  downloadCertificatePdf,
  evaluateAutoCertificates,
  fetchCertificateTemplates,
  fetchEligibleCounselorsForCertificates,
  fetchIssuedCertificates,
  revokeCertificate,
  toggleCertificateTemplateActive,
  upsertCertificateTemplate,
  type CertificateTemplate,
  type CertificateTriggerType,
  type IssuedPsychologistCertificate,
  type PortalDatabase,
} from '@/lib/portalStore'

interface AdminCertificatesModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

type CertStatusFilter = 'all' | 'active' | 'revoked'

const PLACEHOLDER_CHIPS = [
  '{psychologist_name}',
  '{str_number}',
  '{certificate_number}',
  '{issue_date}',
] as const

const TRIGGER_LABELS: Record<CertificateTriggerType, string> = {
  sessions_milestone: 'Milestone Sesi Selesai',
  rating_milestone: 'Rating Kepuasan Pasien',
  manual: 'Penerbitan Manual Admin',
}

export function AdminCertificatesModule({ db, onFeedback }: AdminCertificatesModuleProps) {
  const [searchParams, setSearchParams] = useSearchParams()
  const activeTab: 'issued' | 'templates' =
    searchParams.get('tab') === 'templates' ? 'templates' : 'issued'

  const [loading, setLoading] = useState(true)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const [evaluatingAuto, setEvaluatingAuto] = useState(false)
  const [isIssueModalOpen, setIsIssueModalOpen] = useState(false)
  const [previewCert, setPreviewCert] = useState<IssuedPsychologistCertificate | null>(null)
  const [downloadingCertId, setDownloadingCertId] = useState<string | null>(null)

  // Issued certificates filter/search state
  const [searchQuery, setSearchQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState<CertStatusFilter>('all')
  const [revokingCert, setRevokingCert] = useState<IssuedPsychologistCertificate | null>(null)
  const [revokeReason, setRevokeReason] = useState('')
  const [revokingSubmitting, setRevokingSubmitting] = useState(false)

  // Template editor form state
  const [editingTemplateId, setEditingTemplateId] = useState<string | null>(null)
  const [tplCode, setTplCode] = useState('')
  const [tplTitle, setTplTitle] = useState('')
  const [tplSubtitle, setTplSubtitle] = useState('Clinical Tele-Psychology Excellence')
  const [tplCategoryCode, setTplCategoryCode] = useState('PRO')
  const [tplCategoryLabel, setTplCategoryLabel] = useState('Psikolog Mandiri')
  const [tplMilestone, setTplMilestone] = useState('')
  const [tplDescription, setTplDescription] = useState(
    'Diberikan kepada {psychologist_name} (STR: {str_number}) atas dedikasi klinis resmi EVA. Nomor: {certificate_number} ({issue_date}).',
  )
  const [tplBadgeColor, setTplBadgeColor] = useState('#2563EB')
  const [tplTriggerType, setTplTriggerType] = useState<CertificateTriggerType>('sessions_milestone')
  const [tplMinSessions, setTplMinSessions] = useState('25')
  const [tplMinRating, setTplMinRating] = useState('4.8')
  const [tplAutoEnabled, setTplAutoEnabled] = useState(true)
  const [savingTemplate, setSavingTemplate] = useState(false)

  const tableCardRef = useRef<HTMLDivElement>(null)
  const templateFormRef = useRef<HTMLDivElement>(null)

  const handleRetryLoad = () => {
    setLoading(true)
    setErrorMsg(null)
    void Promise.all([
      fetchIssuedCertificates(),
      fetchCertificateTemplates(),
      fetchEligibleCounselorsForCertificates(),
    ])
      .then(() => {
        setErrorMsg(null)
      })
      .catch((err) => {
        setErrorMsg(
          err instanceof Error ? err.message : 'Gagal memuat data sertifikat psikolog dari server.',
        )
      })
      .finally(() => {
        setLoading(false)
      })
  }

  useEffect(() => {
    let active = true
    Promise.all([
      fetchIssuedCertificates(),
      fetchCertificateTemplates(),
      fetchEligibleCounselorsForCertificates(),
    ])
      .then(() => {
        if (active) setErrorMsg(null)
      })
      .catch((err) => {
        if (active) {
          setErrorMsg(
            err instanceof Error
              ? err.message
              : 'Gagal memuat data sertifikat psikolog dari server.',
          )
        }
      })
      .finally(() => {
        if (active) setLoading(false)
      })

    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    if (!revokingCert) return
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setRevokingCert(null)
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [revokingCert])

  const handleTabChange = (nextTab: 'issued' | 'templates') => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      if (nextTab === 'templates') next.set('tab', 'templates')
      else next.delete('tab')
      next.delete('page')
      return next
    })
  }

  const filteredCertificates = useMemo(() => {
    const q = searchQuery.trim().toLowerCase()
    return db.issuedCertificates.filter((cert) => {
      if (statusFilter !== 'all' && cert.status !== statusFilter) return false
      if (!q) return true
      return (
        cert.recipientName.toLowerCase().includes(q) ||
        cert.certificateNumber.toLowerCase().includes(q) ||
        cert.strNumber.toLowerCase().includes(q) ||
        cert.title.toLowerCase().includes(q)
      )
    })
  }, [db.issuedCertificates, searchQuery, statusFilter])

  const {
    pageSize,
    safePage,
    paginatedItems: paginatedCerts,
    resetPage,
    handlePageChange,
    handlePageSizeChange,
  } = useUrlPagination(filteredCertificates, {
    defaultPageSize: 5,
    scrollTargetRef: tableCardRef,
  })

  const activeCertCount = useMemo(
    () => db.issuedCertificates.filter((c) => c.status === 'active').length,
    [db.issuedCertificates],
  )
  const activeTemplateCount = useMemo(
    () => db.certificateTemplates.filter((t) => t.isActive).length,
    [db.certificateTemplates],
  )

  const handleEvaluateAuto = async () => {
    if (evaluatingAuto) return
    setEvaluatingAuto(true)
    setErrorMsg(null)
    try {
      const summary = await evaluateAutoCertificates()
      if (summary.newlyIssuedCount > 0) {
        onFeedback(
          `Evaluasi selesai: ${summary.newlyIssuedCount} sertifikat baru diterbitkan otomatis untuk ${summary.evaluatedCounselors} psikolog terverifikasi.`,
        )
      } else {
        onFeedback(
          `Evaluasi selesai (${summary.evaluatedCounselors} psikolog terverifikasi diperiksa): seluruh milestone aktif sudah up-to-date.`,
        )
      }
      void fetchEligibleCounselorsForCertificates()
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal menjalankan evaluasi otomatis.')
    } finally {
      setEvaluatingAuto(false)
    }
  }

  const handleDownloadPdf = async (cert: IssuedPsychologistCertificate) => {
    if (downloadingCertId) return
    setDownloadingCertId(cert.id)
    setErrorMsg(null)
    try {
      const { blob, filename } = await downloadCertificatePdf(cert.id)
      const url = URL.createObjectURL(blob)
      const anchor = document.createElement('a')
      anchor.href = url
      anchor.download = filename
      document.body.appendChild(anchor)
      anchor.click()
      anchor.remove()
      URL.revokeObjectURL(url)
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal mengunduh sertifikat PDF.')
    } finally {
      setDownloadingCertId(null)
    }
  }

  const handleConfirmRevoke = async (e: FormEvent) => {
    e.preventDefault()
    if (!revokingCert || revokingSubmitting || revokeReason.trim().length < 3) return
    setRevokingSubmitting(true)
    setErrorMsg(null)
    try {
      const updated = await revokeCertificate(revokingCert.id, revokeReason)
      onFeedback(`Sertifikat ${updated.certificateNumber} telah dicabut.`)
      setRevokingCert(null)
      setRevokeReason('')
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal mencabut sertifikat.')
    } finally {
      setRevokingSubmitting(false)
    }
  }

  const resetTemplateForm = () => {
    setEditingTemplateId(null)
    setTplCode('')
    setTplTitle('')
    setTplSubtitle('Clinical Tele-Psychology Excellence')
    setTplCategoryCode('PRO')
    setTplCategoryLabel('Psikolog Mandiri')
    setTplMilestone('')
    setTplDescription(
      'Diberikan kepada {psychologist_name} (STR: {str_number}) atas dedikasi klinis resmi EVA. Nomor: {certificate_number} ({issue_date}).',
    )
    setTplBadgeColor('#2563EB')
    setTplTriggerType('sessions_milestone')
    setTplMinSessions('25')
    setTplMinRating('4.8')
    setTplAutoEnabled(true)
  }

  const handleEditTemplate = (tpl: CertificateTemplate) => {
    setEditingTemplateId(tpl.id)
    setTplCode(tpl.code)
    setTplTitle(tpl.title)
    setTplSubtitle(tpl.subtitle)
    setTplCategoryCode(tpl.categoryCode)
    setTplCategoryLabel(tpl.categoryLabel)
    setTplMilestone(tpl.milestoneCriteria)
    setTplDescription(tpl.description)
    setTplBadgeColor(tpl.badgeColor)
    setTplTriggerType(tpl.triggerType)
    setTplMinSessions(String(tpl.minCompletedSessions))
    setTplMinRating(tpl.minAverageRating !== null && tpl.minAverageRating !== undefined ? String(tpl.minAverageRating) : '4.8')
    setTplAutoEnabled(tpl.autoIssueEnabled)
    setErrorMsg(null)
    templateFormRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }

  const handleSaveTemplate = async (e: FormEvent) => {
    e.preventDefault()
    if (savingTemplate) return
    setSavingTemplate(true)
    setErrorMsg(null)
    try {
      const saved = await upsertCertificateTemplate({
        id: editingTemplateId ?? undefined,
        code: tplCode,
        title: tplTitle,
        subtitle: tplSubtitle,
        categoryCode: tplCategoryCode,
        categoryLabel: tplCategoryLabel,
        milestoneCriteria: tplMilestone,
        description: tplDescription,
        badgeColor: tplBadgeColor,
        triggerType: tplTriggerType,
        minCompletedSessions: Math.max(0, Math.trunc(Number(tplMinSessions) || 0)),
        minAverageRating:
          tplTriggerType === 'rating_milestone' ? Number(tplMinRating) || 4.8 : null,
        autoIssueEnabled: tplTriggerType === 'manual' ? false : tplAutoEnabled,
        isActive: true,
      })
      resetTemplateForm()
      onFeedback(`Template sertifikat "${saved.code}" berhasil disimpan.`)
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal menyimpan template sertifikat.')
    } finally {
      setSavingTemplate(false)
    }
  }

  return (
    <div>
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Manajemen Sertifikat Psikolog &amp; Penomoran Resmi
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Kelola template sertifikat dinamis, aturan penerbitan milestone/rating otomatis, penomoran EVA/CERT/&#123;TAHUN&#125;/&#123;KATEGORI&#125;/&#123;URUT&#125;, serta dokumen PDF bertanda tangan EVA.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            disabled={evaluatingAuto}
            onClick={() => void handleEvaluateAuto()}
            className="inline-flex min-h-11 cursor-pointer items-center gap-1.5 rounded-[8px] border border-primary/40 bg-[#EEF0FF] px-3.5 text-xs font-semibold text-primary hover:bg-primary hover:text-white disabled:cursor-not-allowed disabled:opacity-60 sm:h-9 sm:min-h-0"
          >
            {evaluatingAuto ? (
              <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />
            ) : (
              <Sparkles className="size-3.5" aria-hidden="true" />
            )}
            <span>Evaluasi Milestone Otomatis</span>
          </button>
          <button
            type="button"
            onClick={() => setIsIssueModalOpen(true)}
            className="inline-flex min-h-11 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-3.5 text-xs font-semibold text-white shadow-btn hover:bg-primary-hover sm:h-9 sm:min-h-0"
          >
            <Plus className="size-3.5" aria-hidden="true" />
            <span>Terbitkan Sertifikat</span>
          </button>
        </div>
      </div>

      {/* KPI Strip */}
      <div className="mt-5 grid grid-cols-1 gap-3.5 sm:grid-cols-3">
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <p className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
            Sertifikat Aktif Terbit
          </p>
          <p className="mt-1.5 text-2xl font-bold text-ink">{activeCertCount}</p>
          <p className="mt-0.5 text-xs text-ink-muted">Tervalidasi STR Kemenkes/KTKI</p>
        </div>
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <p className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
            Template Aturan Aktif
          </p>
          <p className="mt-1.5 text-2xl font-bold text-ink">{activeTemplateCount}</p>
          <p className="mt-0.5 text-xs text-ink-muted">Sesi klinis, rating &amp; manual award</p>
        </div>
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <p className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
            Psikolog Terverifikasi
          </p>
          <p className="mt-1.5 text-2xl font-bold text-ink">
            {db.eligibleCounselorSummaries.length}
          </p>
          <p className="mt-0.5 text-xs text-ink-muted">Siap menerima kredensial resmi EVA</p>
        </div>
      </div>

      {/* Tabs */}
      <div
        role="tablist"
        aria-label="Navigasi manajemen sertifikat psikolog"
        className="mt-5 inline-flex flex-wrap gap-1 rounded-[8px] border border-[#CBD5E1] bg-white p-1"
      >
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === 'issued'}
          onClick={() => handleTabChange('issued')}
          className={cn(
            'min-h-11 cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors sm:min-h-0',
            activeTab === 'issued' ? 'bg-primary text-white' : 'text-ink-soft hover:text-ink',
          )}
        >
          Daftar Sertifikat Terbit ({db.issuedCertificates.length})
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === 'templates'}
          onClick={() => handleTabChange('templates')}
          className={cn(
            'min-h-11 cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors sm:min-h-0',
            activeTab === 'templates' ? 'bg-primary text-white' : 'text-ink-soft hover:text-ink',
          )}
        >
          Template &amp; Aturan Pemicu ({db.certificateTemplates.length})
        </button>
      </div>

      {errorMsg && (
        <div
          role="alert"
          className="mt-4 flex flex-wrap items-center justify-between gap-2 rounded-[10px] border border-[#FECACA] bg-[#FEF2F2] px-4 py-2.5 text-xs font-medium text-[#991B1B]"
        >
          <div className="flex items-center gap-2">
            <AlertCircle className="size-4 shrink-0" aria-hidden="true" />
            <span>{errorMsg}</span>
          </div>
          <button
            type="button"
            disabled={loading}
            onClick={handleRetryLoad}
            className="inline-flex min-h-11 cursor-pointer items-center gap-1 rounded-[6px] border border-[#B91C1C] bg-white px-2.5 text-xs font-semibold text-[#991B1B] hover:bg-[#FEE2E2] disabled:cursor-not-allowed disabled:opacity-60 sm:h-8 sm:min-h-0"
          >
            <RefreshCw className="size-3.5" aria-hidden="true" />
            <span>Muat Ulang</span>
          </button>
        </div>
      )}

      {activeTab === 'issued' ? (
        <div className="mt-4 space-y-3">
          <div
            ref={tableCardRef}
            className="rounded-[12px] border border-[#E2E8F0] bg-white"
          >
            <div className="flex flex-col justify-between gap-3 border-b border-[#E2E8F0] p-4 sm:flex-row sm:items-center">
              <div className="flex flex-wrap items-center gap-1.5">
                {(['all', 'active', 'revoked'] as const).map((st) => (
                  <button
                    key={st}
                    type="button"
                    aria-pressed={statusFilter === st}
                    onClick={() => {
                      setStatusFilter(st)
                      resetPage()
                    }}
                    className={cn(
                      'min-h-11 cursor-pointer rounded-[6px] border px-2.5 py-1 text-xs font-semibold sm:min-h-8',
                      statusFilter === st
                        ? 'border-primary bg-[#EEF0FF] text-primary'
                        : 'border-[#768396] bg-white text-ink-soft hover:text-ink',
                    )}
                  >
                    {st === 'all' ? 'Semua Status' : st === 'active' ? 'Aktif' : 'Dicabut'}
                  </button>
                ))}
              </div>

              <div className="relative w-full sm:w-72">
                <label htmlFor="cert-search-input" className="sr-only">
                  Cari nama psikolog, nomor EVA/CERT, atau STR
                </label>
                <Search
                  className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted"
                  aria-hidden="true"
                />
                <input
                  id="cert-search-input"
                  type="search"
                  value={searchQuery}
                  onChange={(e) => {
                    setSearchQuery(e.target.value)
                    resetPage()
                  }}
                  placeholder="Cari nama, nomor EVA/CERT, atau STR..."
                  className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink focus:border-primary focus:bg-white focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                />
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left">
                <thead>
                  <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                    <th className="px-4 py-3">Nomor Sertifikat</th>
                    <th className="px-4 py-3">Penerima &amp; STR</th>
                    <th className="px-4 py-3">Judul &amp; Kriteria</th>
                    <th className="px-4 py-3">Sumber / Tanggal</th>
                    <th className="px-4 py-3">Status</th>
                    <th className="px-4 py-3 text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#E2E8F0] text-xs">
                  {loading && db.issuedCertificates.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="px-4 py-8 text-center text-ink-muted">
                        <span className="inline-flex items-center gap-2">
                          <Loader2 className="size-4 animate-spin text-primary" aria-hidden="true" />
                          <span>Memuat daftar sertifikat psikolog...</span>
                        </span>
                      </td>
                    </tr>
                  ) : paginatedCerts.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="px-4 py-8 text-center text-ink-soft">
                        <p className="font-semibold text-ink">
                          {searchQuery.trim() || statusFilter !== 'all'
                            ? 'Tidak ada sertifikat yang cocok dengan filter pencarian.'
                            : 'Belum ada sertifikat psikolog yang diterbitkan.'}
                        </p>
                        <p className="mt-1 text-xs text-ink-muted">
                          {searchQuery.trim() || statusFilter !== 'all'
                            ? 'Ubah kata kunci atau atur ulang filter status untuk melihat seluruh sertifikat.'
                            : 'Jalankan evaluasi milestone otomatis atau terbitkan sertifikat secara manual.'}
                        </p>
                        <div className="mt-3 flex flex-wrap justify-center gap-2">
                          {(searchQuery.trim() || statusFilter !== 'all') && (
                            <button
                              type="button"
                              onClick={() => {
                                setSearchQuery('')
                                setStatusFilter('all')
                                resetPage()
                              }}
                              className="inline-flex min-h-11 cursor-pointer items-center rounded-[8px] border border-[#768396] bg-white px-3 text-xs font-semibold text-ink hover:bg-[#F8FAFC] sm:h-8 sm:min-h-0"
                            >
                              Reset Filter &amp; Pencarian
                            </button>
                          )}
                          {db.issuedCertificates.length === 0 && (
                            <button
                              type="button"
                              onClick={() => setIsIssueModalOpen(true)}
                              className="inline-flex min-h-11 cursor-pointer items-center gap-1 rounded-[8px] bg-primary px-3 text-xs font-semibold text-white hover:bg-primary-hover sm:h-8 sm:min-h-0"
                            >
                              <Plus className="size-3.5" aria-hidden="true" />
                              <span>Terbitkan Sertifikat</span>
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ) : (
                    paginatedCerts.map((cert) => (
                      <tr key={cert.id} className="hover:bg-[#F8FAFC]">
                        <td className="px-4 py-3.5 font-mono text-[11px] font-bold text-primary">
                          {cert.certificateNumber}
                        </td>
                        <td className="px-4 py-3.5">
                          <p className="font-semibold text-ink">{cert.recipientName}</p>
                          <p className="font-mono text-[11px] text-ink-muted">{cert.strNumber}</p>
                        </td>
                        <td className="px-4 py-3.5">
                          <p className="font-semibold text-ink">{cert.title}</p>
                          <p className="text-[11px] text-ink-muted">{cert.milestoneCriteria}</p>
                        </td>
                        <td className="px-4 py-3.5">
                          <span className="inline-flex rounded-[5px] bg-[#F1F5F9] px-1.5 py-0.5 text-[10px] font-semibold text-ink-soft">
                            {cert.triggerSource === 'auto_sessions'
                              ? 'Auto: Sesi'
                              : cert.triggerSource === 'auto_rating'
                                ? 'Auto: Rating'
                                : 'Manual Admin'}
                          </span>
                          <p className="mt-1 text-[11px] text-ink-muted">{cert.issueDateLabel}</p>
                        </td>
                        <td className="px-4 py-3.5">
                          <span
                            className={cn(
                              'inline-flex items-center gap-1 rounded-[6px] px-2 py-0.5 text-[11px] font-semibold',
                              cert.status === 'active'
                                ? 'bg-[#F0FDF4] text-[#166534]'
                                : 'bg-[#FEF2F2] text-[#B91C1C]',
                            )}
                          >
                            {cert.status === 'active' ? (
                              <CheckCircle2 className="size-3" aria-hidden="true" />
                            ) : (
                              <Ban className="size-3" aria-hidden="true" />
                            )}
                            <span>{cert.status === 'active' ? 'Aktif' : 'Dicabut'}</span>
                          </span>
                        </td>
                        <td className="px-4 py-3.5 text-right">
                          <div className="inline-flex items-center justify-end gap-1.5">
                            <button
                              type="button"
                              onClick={() => setPreviewCert(cert)}
                              className="inline-flex min-h-11 cursor-pointer items-center gap-1 rounded-[6px] border border-[#768396] bg-white px-2.5 text-[11px] font-semibold text-ink hover:bg-[#F8FAFC] sm:h-8 sm:min-h-0"
                            >
                              <Eye className="size-3.5" aria-hidden="true" />
                              <span>Pratinjau</span>
                            </button>
                            <button
                              type="button"
                              disabled={downloadingCertId === cert.id}
                              onClick={() => void handleDownloadPdf(cert)}
                              className="inline-flex min-h-11 cursor-pointer items-center gap-1 rounded-[6px] border border-primary/40 bg-[#EEF0FF] px-2.5 text-[11px] font-semibold text-primary hover:bg-primary hover:text-white disabled:cursor-not-allowed disabled:opacity-50 sm:h-8 sm:min-h-0"
                            >
                              {downloadingCertId === cert.id ? (
                                <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />
                              ) : (
                                <Download className="size-3.5" aria-hidden="true" />
                              )}
                              <span>PDF</span>
                            </button>
                            {cert.status === 'active' && (
                              <button
                                type="button"
                                aria-label={`Cabut sertifikat ${cert.certificateNumber}`}
                                onClick={() => {
                                  setRevokingCert(cert)
                                  setRevokeReason('')
                                }}
                                className="inline-flex min-h-11 min-w-11 cursor-pointer items-center justify-center rounded-[6px] border border-[#B91C1C]/40 bg-[#FEF2F2] text-[#B91C1C] hover:bg-[#FEE2E2] sm:size-8 sm:min-h-0 sm:min-w-0"
                              >
                                <Ban className="size-3.5" aria-hidden="true" />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <TablePagination
            currentPage={safePage}
            totalItems={filteredCertificates.length}
            pageSize={pageSize}
            pageSizeOptions={[5, 10, 25]}
            itemLabel="sertifikat"
            ariaLabel="Paginasi sertifikat psikolog"
            onPageChange={handlePageChange}
            onPageSizeChange={handlePageSizeChange}
          />
        </div>
      ) : (
        <div className="mt-4 grid grid-cols-1 gap-6 lg:grid-cols-12">
          <div ref={templateFormRef} className="lg:col-span-5">
            <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
              <div className="flex items-center justify-between gap-2">
                <h2 className="text-sm font-bold text-ink">
                  {editingTemplateId ? 'Edit Template Sertifikat' : 'Buat Template & Aturan Baru'}
                </h2>
                {editingTemplateId && (
                  <button
                    type="button"
                    onClick={resetTemplateForm}
                    className="inline-flex min-h-11 cursor-pointer items-center gap-1 rounded-[6px] border border-[#768396] px-2.5 py-1 text-[11px] font-semibold text-ink-soft hover:text-ink sm:min-h-8"
                  >
                    <X className="size-3" aria-hidden="true" /> Batal Edit
                  </button>
                )}
              </div>

              <form onSubmit={handleSaveTemplate} className="mt-4 space-y-3 text-xs">
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label htmlFor="tpl-code" className="block font-semibold text-ink">
                      Kode Template *
                    </label>
                    <input
                      id="tpl-code"
                      type="text"
                      required
                      minLength={3}
                      value={tplCode}
                      onChange={(e) => setTplCode(e.target.value.toUpperCase())}
                      placeholder="CERT-PRO-04"
                      className="mt-1 min-h-11 w-full rounded-[8px] border border-[#768396] px-3 font-mono uppercase text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                    />
                  </div>
                  <div>
                    <label htmlFor="tpl-category-code" className="block font-semibold text-ink">
                      Kode Kategori Nomor *
                    </label>
                    <input
                      id="tpl-category-code"
                      type="text"
                      required
                      minLength={2}
                      maxLength={16}
                      value={tplCategoryCode}
                      onChange={(e) => setTplCategoryCode(e.target.value.toUpperCase())}
                      placeholder="PRO"
                      className="mt-1 min-h-11 w-full rounded-[8px] border border-[#768396] px-3 font-mono uppercase text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                    />
                  </div>
                </div>

                <div>
                  <label htmlFor="tpl-title" className="block font-semibold text-ink">
                    Judul Sertifikat *
                  </label>
                  <input
                    id="tpl-title"
                    type="text"
                    required
                    minLength={4}
                    value={tplTitle}
                    onChange={(e) => setTplTitle(e.target.value)}
                    placeholder="SERTIFIKAT PRAKTIK TELEKONSELING KLINIS"
                    className="mt-1 min-h-11 w-full rounded-[8px] border border-[#768396] px-3 text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                  />
                </div>

                <div className="grid grid-cols-3 gap-3">
                  <div className="col-span-2">
                    <label htmlFor="tpl-subtitle" className="block font-semibold text-ink">
                      Subjudul *
                    </label>
                    <input
                      id="tpl-subtitle"
                      type="text"
                      required
                      value={tplSubtitle}
                      onChange={(e) => setTplSubtitle(e.target.value)}
                      className="mt-1 min-h-11 w-full rounded-[8px] border border-[#768396] px-3 text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                    />
                  </div>
                  <div>
                    <label htmlFor="tpl-badge-color" className="block font-semibold text-ink">
                      Warna Aksen
                    </label>
                    <input
                      id="tpl-badge-color"
                      type="color"
                      value={tplBadgeColor}
                      onChange={(e) => setTplBadgeColor(e.target.value)}
                      className="mt-1 min-h-11 w-full cursor-pointer rounded-[8px] border border-[#768396] bg-white p-1 sm:h-9 sm:min-h-0"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <div>
                    <label htmlFor="tpl-category-label" className="block font-semibold text-ink">
                      Label Kategori *
                    </label>
                    <input
                      id="tpl-category-label"
                      type="text"
                      required
                      value={tplCategoryLabel}
                      onChange={(e) => setTplCategoryLabel(e.target.value)}
                      placeholder="Psikolog Mandiri"
                      className="mt-1 min-h-11 w-full rounded-[8px] border border-[#768396] px-3 text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                    />
                  </div>
                  <div>
                    <label htmlFor="tpl-milestone" className="block font-semibold text-ink">
                      Kriteria Milestone *
                    </label>
                    <input
                      id="tpl-milestone"
                      type="text"
                      required
                      value={tplMilestone}
                      onChange={(e) => setTplMilestone(e.target.value)}
                      placeholder="25 Sesi Terverifikasi"
                      className="mt-1 min-h-11 w-full rounded-[8px] border border-[#768396] px-3 text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                    />
                  </div>
                </div>

                <div>
                  <label htmlFor="tpl-trigger-type" className="block font-semibold text-ink">
                    Aturan Pemicu Penerbitan
                  </label>
                  <select
                    id="tpl-trigger-type"
                    value={tplTriggerType}
                    onChange={(e) => setTplTriggerType(e.target.value as CertificateTriggerType)}
                    className="mt-1 min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                  >
                    <option value="sessions_milestone">Otomatis: Milestone Jumlah Sesi</option>
                    <option value="rating_milestone">Otomatis: Sesi + Rating Kepuasan Pasien</option>
                    <option value="manual">Manual: Diterbitkan oleh Admin</option>
                  </select>
                </div>

                {tplTriggerType !== 'manual' && (
                  <div className="grid grid-cols-2 gap-3 rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-3">
                    <div>
                      <label htmlFor="tpl-min-sessions" className="block font-semibold text-ink">
                        Min. Sesi Selesai
                      </label>
                      <input
                        id="tpl-min-sessions"
                        type="number"
                        min={1}
                        value={tplMinSessions}
                        onChange={(e) => setTplMinSessions(e.target.value)}
                        className="mt-1 min-h-11 w-full rounded-[6px] border border-[#768396] bg-white px-2.5 text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-8 sm:min-h-0"
                      />
                    </div>
                    {tplTriggerType === 'rating_milestone' ? (
                      <div>
                        <label htmlFor="tpl-min-rating" className="block font-semibold text-ink">
                          Min. Rating (1-5)
                        </label>
                        <input
                          id="tpl-min-rating"
                          type="number"
                          step="0.1"
                          min={1}
                          max={5}
                          value={tplMinRating}
                          onChange={(e) => setTplMinRating(e.target.value)}
                          className="mt-1 min-h-11 w-full rounded-[6px] border border-[#768396] bg-white px-2.5 text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-8 sm:min-h-0"
                        />
                      </div>
                    ) : (
                      <label
                        htmlFor="tpl-auto-enabled"
                        className="flex cursor-pointer items-center gap-2 pt-5"
                      >
                        <input
                          id="tpl-auto-enabled"
                          type="checkbox"
                          checked={tplAutoEnabled}
                          onChange={(e) => setTplAutoEnabled(e.target.checked)}
                          className="size-4 accent-primary"
                        />
                        <span className="font-semibold text-ink">Auto-terbit aktif</span>
                      </label>
                    )}
                  </div>
                )}

                <div>
                  <div className="flex flex-wrap items-center justify-between gap-1">
                    <label htmlFor="tpl-description" className="font-semibold text-ink">
                      Teks / Variabel Dinamis *
                    </label>
                    <div className="flex flex-wrap gap-1">
                      {PLACEHOLDER_CHIPS.map((chip) => (
                        <button
                          key={chip}
                          type="button"
                          onClick={() => setTplDescription((prev) => `${prev} ${chip}`.trim())}
                          className="min-h-8 cursor-pointer rounded-[4px] bg-[#EEF0FF] px-1.5 py-0.5 font-mono text-[10px] font-semibold text-primary hover:bg-primary hover:text-white sm:min-h-0"
                        >
                          {chip}
                        </button>
                      ))}
                    </div>
                  </div>
                  <textarea
                    id="tpl-description"
                    rows={3}
                    required
                    minLength={10}
                    value={tplDescription}
                    onChange={(e) => setTplDescription(e.target.value)}
                    className="mt-1.5 w-full rounded-[8px] border border-[#768396] p-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
                  />
                </div>

                <button
                  type="submit"
                  disabled={savingTemplate}
                  className="inline-flex min-h-11 w-full cursor-pointer items-center justify-center gap-1.5 rounded-[8px] bg-primary px-4 font-semibold text-white hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-60 sm:h-9 sm:min-h-0"
                >
                  {savingTemplate ? (
                    <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />
                  ) : (
                    <CheckCircle2 className="size-3.5" aria-hidden="true" />
                  )}
                  <span>{editingTemplateId ? 'Simpan Perubahan Template' : 'Simpan Template Baru'}</span>
                </button>
              </form>
            </div>
          </div>

          <div className="lg:col-span-7">
            <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
              <h2 className="text-sm font-bold text-ink">
                Daftar Template Sertifikat &amp; Trigger ({db.certificateTemplates.length})
              </h2>
              {loading && db.certificateTemplates.length === 0 ? (
                <div className="mt-4 flex items-center gap-2 py-6 text-xs text-ink-muted">
                  <Loader2 className="size-4 animate-spin text-primary" aria-hidden="true" />
                  <span>Memuat template sertifikat...</span>
                </div>
              ) : db.certificateTemplates.length === 0 ? (
                <div className="mt-4 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-4 text-xs text-ink-soft">
                  <p className="font-semibold text-ink">Belum ada template sertifikat tersimpan.</p>
                  <p className="mt-1">
                    Buat template pertama melalui formulir di samping untuk mengaktifkan penerbitan otomatis atau manual.
                  </p>
                </div>
              ) : (
                <div className="mt-3 divide-y divide-[#E2E8F0]">
                  {db.certificateTemplates.map((tpl) => (
                    <div
                      key={tpl.id}
                      className="flex flex-col justify-between gap-3 py-3.5 text-xs sm:flex-row sm:items-start"
                    >
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-1.5">
                          <span
                            aria-hidden="true"
                            className="size-2.5 rounded-full"
                            style={{ backgroundColor: tpl.badgeColor }}
                          />
                          <span className="font-mono text-[11px] font-bold text-primary">
                            {tpl.code}
                          </span>
                          <span className="rounded-[4px] bg-[#F1F5F9] px-1.5 py-0.5 text-[10px] font-semibold text-ink-soft">
                            Kategori: {tpl.categoryCode}
                          </span>
                          <span className="rounded-[4px] bg-[#EEF0FF] px-1.5 py-0.5 text-[10px] font-semibold text-primary">
                            {TRIGGER_LABELS[tpl.triggerType]}
                            {tpl.triggerType !== 'manual' && ` (${tpl.minCompletedSessions} sesi`}
                            {tpl.triggerType === 'rating_milestone' &&
                              `, Rating ${tpl.minAverageRating ?? 4.8}`}
                            {tpl.triggerType !== 'manual' && ')'}
                          </span>
                        </div>
                        <p className="mt-1 font-bold text-ink">{tpl.title}</p>
                        <p className="mt-0.5 text-[11px] text-ink-muted">{tpl.milestoneCriteria}</p>
                      </div>

                      <div className="flex shrink-0 items-center gap-1.5">
                        <button
                          type="button"
                          onClick={() => handleEditTemplate(tpl)}
                          aria-label={`Edit template ${tpl.code}`}
                          className="inline-flex min-h-11 min-w-11 cursor-pointer items-center justify-center rounded-[6px] border border-[#768396] bg-white text-ink-soft hover:bg-[#F8FAFC] hover:text-ink sm:size-8 sm:min-h-0 sm:min-w-0"
                        >
                          <Pencil className="size-3.5" aria-hidden="true" />
                        </button>
                        <button
                          type="button"
                          aria-pressed={tpl.isActive}
                          onClick={() =>
                            void toggleCertificateTemplateActive(tpl.id)
                              .then((updated) =>
                                onFeedback(
                                  `Template ${updated.code} ${updated.isActive ? 'diaktifkan' : 'dinonaktifkan'}.`,
                                ),
                              )
                              .catch((err) =>
                                setErrorMsg(
                                  err instanceof Error
                                    ? err.message
                                    : 'Gagal mengubah status aktif template.',
                                ),
                              )
                          }
                          className={cn(
                            'min-h-11 cursor-pointer rounded-[6px] border px-2.5 py-1 text-[11px] font-semibold sm:min-h-8',
                            tpl.isActive
                              ? 'border-[#166534]/40 bg-[#F0FDF4] text-[#166534]'
                              : 'border-[#768396] bg-[#F8FAFC] text-ink-soft',
                          )}
                        >
                          {tpl.isActive ? 'Aktif' : 'Nonaktif'}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Revoke Certificate Dialog */}
      {revokingCert && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Cabut Sertifikat Psikolog"
          onClick={() => setRevokingCert(null)}
          className="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 p-4"
        >
          <form
            onClick={(e) => e.stopPropagation()}
            onSubmit={handleConfirmRevoke}
            className="w-full max-w-md rounded-[14px] border border-[#E2E8F0] bg-white p-5 text-xs shadow-2xl"
          >
            <div className="flex items-center gap-2 text-[#B91C1C]">
              <Award className="size-4" aria-hidden="true" />
              <h3 className="text-sm font-bold">Cabut Sertifikat {revokingCert.certificateNumber}</h3>
            </div>
            <p className="mt-1.5 text-ink-muted">
              Sertifikat milik <strong>{revokingCert.recipientName}</strong> akan ditandai dicabut dan tidak tampil di daftar aktif konselor.
            </p>
            <label htmlFor="revoke-reason-input" className="mt-3 block font-semibold text-ink">
              Alasan Pencabutan Resmi *
            </label>
            <textarea
              id="revoke-reason-input"
              rows={3}
              required
              minLength={3}
              value={revokeReason}
              onChange={(e) => setRevokeReason(e.target.value)}
              placeholder="Tuliskan alasan pencabutan resmi..."
              className="mt-1.5 w-full rounded-[8px] border border-[#768396] p-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
            />
            <div className="mt-4 flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setRevokingCert(null)}
                className="inline-flex min-h-11 cursor-pointer items-center rounded-[6px] border border-[#768396] px-3 font-semibold text-ink hover:bg-[#F8FAFC] sm:h-8 sm:min-h-0"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={revokingSubmitting || revokeReason.trim().length < 3}
                className="inline-flex min-h-11 cursor-pointer items-center gap-1 rounded-[6px] bg-[#B91C1C] px-3 font-semibold text-white hover:bg-[#991B1B] disabled:cursor-not-allowed disabled:opacity-50 sm:h-8 sm:min-h-0"
              >
                {revokingSubmitting && <Loader2 className="size-3 animate-spin" aria-hidden="true" />}
                <span>Konfirmasi Cabut</span>
              </button>
            </div>
          </form>
        </div>
      )}

      <IssueCertificateModal
        key={isIssueModalOpen ? 'issue-open' : 'issue-closed'}
        isOpen={isIssueModalOpen}
        counselors={db.eligibleCounselorSummaries}
        templates={db.certificateTemplates}
        onClose={() => setIsIssueModalOpen(false)}
        onIssued={(cert) => {
          onFeedback(
            `Sertifikat resmi ${cert.certificateNumber} berhasil diterbitkan untuk ${cert.recipientName}.`,
          )
          void fetchEligibleCounselorsForCertificates()
        }}
      />

      <OfficialCertificatePreviewModal
        certificate={previewCert}
        isOpen={Boolean(previewCert)}
        onClose={() => setPreviewCert(null)}
        onError={(msg) => setErrorMsg(msg)}
      />
    </div>
  )
}
