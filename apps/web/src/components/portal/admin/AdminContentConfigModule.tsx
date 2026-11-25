import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react'
import { Loader2, Pencil, Plus, Search, Trash2, X } from 'lucide-react'
import { TablePagination } from '@/components/portal/TablePagination'
import { BoothFeedbackAdminTab } from '@/components/portal/admin/BoothFeedbackAdminTab'
import { useUrlPagination } from '@/hooks/useUrlPagination'
import { cn } from '@/lib/cn'
import {
  addFaqEntry,
  deleteFaqEntry,
  fetchAdminFaqs,
  fetchCrisisConfig,
  toggleFaqPublished,
  updateCrisisConfig,
  updateFaqEntry,
  type FaqEntry,
  type PortalDatabase,
} from '@/lib/portalStore'

interface AdminContentConfigModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

type CrisisDraft = {
  hotlineNumber?: string
  hotlineLabel?: string
  extremeDep?: string
  extremeAnx?: string
  autoSafetyNet?: boolean
  allowDirectMandiri?: boolean
}

export function AdminContentConfigModule({ db, onFeedback }: AdminContentConfigModuleProps) {
  const [activeSubTab, setActiveSubTab] = useState<'faq-crisis' | 'booth-feedback'>('faq-crisis')

  // Crisis SafetyNet Protocol draft overrides (falls back cleanly to live db.crisisConfig)
  const [crisisDraft, setCrisisDraft] = useState<CrisisDraft | null>(null)
  const [savingCrisis, setSavingCrisis] = useState(false)

  const hotlineNumber = crisisDraft?.hotlineNumber ?? db.crisisConfig.hotlineNumber
  const hotlineLabel = crisisDraft?.hotlineLabel ?? db.crisisConfig.hotlineLabel
  const extremeDep =
    crisisDraft?.extremeDep ?? String(db.crisisConfig.extremeDepressionThreshold)
  const extremeAnx =
    crisisDraft?.extremeAnx ?? String(db.crisisConfig.extremeAnxietyThreshold)
  const autoSafetyNet = crisisDraft?.autoSafetyNet ?? db.crisisConfig.autoSafetyNetModal
  const allowDirectMandiri =
    crisisDraft?.allowDirectMandiri ?? db.crisisConfig.allowDirectIndependentReferral

  const patchCrisisDraft = (patch: Partial<CrisisDraft>) => {
    setCrisisDraft((prev) => ({ ...(prev ?? {}), ...patch }))
  }

  // FAQ CMS state
  const [editingFaqId, setEditingFaqId] = useState<string | null>(null)
  const [faqCategory, setFaqCategory] = useState('KEAMANAN & PRIVASI')
  const [faqQuestion, setFaqQuestion] = useState('')
  const [faqAnswer, setFaqAnswer] = useState('')
  const [faqSortOrder, setFaqSortOrder] = useState('')
  const [faqSearch, setFaqSearch] = useState('')
  const [savingFaq, setSavingFaq] = useState(false)
  const [pendingFaqId, setPendingFaqId] = useState<string | null>(null)
  const [loadingData, setLoadingData] = useState(true)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const faqFormRef = useRef<HTMLDivElement>(null)
  const faqListCardRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    let active = true
    Promise.all([fetchCrisisConfig(), fetchAdminFaqs()])
      .then(() => {
        if (active) setErrorMessage(null)
      })
      .catch((err) => {
        if (active) {
          setErrorMessage(
            err instanceof Error ? err.message : 'Gagal memuat konfigurasi konten dari server.',
          )
        }
      })
      .finally(() => {
        if (active) setLoadingData(false)
      })

    return () => {
      active = false
    }
  }, [])

  const sortedFaqs = useMemo(
    () =>
      [...db.faqs].sort(
        (a, b) => (a.sortOrder ?? Number.MAX_SAFE_INTEGER) - (b.sortOrder ?? Number.MAX_SAFE_INTEGER),
      ),
    [db.faqs],
  )

  const filteredFaqs = useMemo(() => {
    const q = faqSearch.trim().toLowerCase()
    if (!q) return sortedFaqs
    return sortedFaqs.filter(
      (f) =>
        f.category.toLowerCase().includes(q) ||
        f.question.toLowerCase().includes(q) ||
        f.answer.toLowerCase().includes(q),
    )
  }, [sortedFaqs, faqSearch])

  const {
    pageSize: faqPageSize,
    safePage: faqSafePage,
    paginatedItems: paginatedFaqs,
    resetPage: resetFaqPage,
    handlePageChange: handleFaqPageChange,
    handlePageSizeChange: handleFaqPageSizeChange,
  } = useUrlPagination(filteredFaqs, {
    defaultPageSize: 5,
    scrollTargetRef: faqListCardRef,
  })

  const handleFaqSearchChange = (value: string) => {
    setFaqSearch(value)
    resetFaqPage()
  }

  const resetFaqForm = () => {
    setEditingFaqId(null)
    setFaqCategory('KEAMANAN & PRIVASI')
    setFaqQuestion('')
    setFaqAnswer('')
    setFaqSortOrder('')
  }

  const handleStartEditFaq = (faq: FaqEntry) => {
    setEditingFaqId(faq.id)
    setFaqCategory(faq.category)
    setFaqQuestion(faq.question)
    setFaqAnswer(faq.answer)
    setFaqSortOrder(faq.sortOrder !== undefined ? String(faq.sortOrder) : '')
    setErrorMessage(null)
    faqFormRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }

  const handleSaveCrisisConfig = async (e: FormEvent) => {
    e.preventDefault()
    if (savingCrisis) return

    const depThreshold = Math.min(42, Math.max(1, Math.trunc(Number(extremeDep) || 28)))
    const anxThreshold = Math.min(42, Math.max(1, Math.trunc(Number(extremeAnx) || 20)))

    setSavingCrisis(true)
    setErrorMessage(null)
    try {
      await updateCrisisConfig({
        hotlineNumber: hotlineNumber.trim().toUpperCase(),
        hotlineLabel: hotlineLabel.trim(),
        extremeDepressionThreshold: depThreshold,
        extremeAnxietyThreshold: anxThreshold,
        autoSafetyNetModal: autoSafetyNet,
        allowDirectIndependentReferral: allowDirectMandiri,
      })
      setCrisisDraft(null)
      onFeedback(
        'Konfigurasi Protokol Krisis SafetyNet & Rujukan Psikolog Mandiri berhasil disimpan ke server.',
      )
    } catch (err) {
      setErrorMessage(
        err instanceof Error ? err.message : 'Gagal menyimpan konfigurasi protokol krisis.',
      )
    } finally {
      setSavingCrisis(false)
    }
  }

  const handleSubmitFaq = async (e: FormEvent) => {
    e.preventDefault()
    if (savingFaq || !faqQuestion.trim() || !faqAnswer.trim() || !faqCategory.trim()) return

    const parsedOrder = faqSortOrder.trim() === '' ? undefined : Math.max(0, Math.trunc(Number(faqSortOrder)))
    if (faqSortOrder.trim() !== '' && Number.isNaN(parsedOrder)) {
      setErrorMessage('Urutan tampilan FAQ harus berupa angka bulat non-negatif.')
      return
    }

    setSavingFaq(true)
    setErrorMessage(null)
    try {
      if (editingFaqId) {
        await updateFaqEntry(editingFaqId, {
          category: faqCategory,
          question: faqQuestion,
          answer: faqAnswer,
          sortOrder: parsedOrder,
        })
        resetFaqForm()
        onFeedback('Perubahan entri FAQ berhasil disimpan ke server.')
      } else {
        await addFaqEntry({
          category: faqCategory,
          question: faqQuestion,
          answer: faqAnswer,
          sortOrder: parsedOrder,
        })
        resetFaqForm()
        onFeedback('Pertanyaan FAQ baru berhasil diterbitkan ke server dan tampil di Landing Page.')
      }
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Gagal menyimpan entri FAQ.')
    } finally {
      setSavingFaq(false)
    }
  }

  const handleToggleFaq = async (faq: FaqEntry) => {
    if (pendingFaqId) return
    setPendingFaqId(faq.id)
    setErrorMessage(null)
    try {
      const updated = await toggleFaqPublished(faq.id)
      onFeedback(
        updated.isPublished
          ? `FAQ "${updated.question}" sekarang tayang di Landing Page.`
          : `FAQ "${updated.question}" disembunyikan dari Landing Page.`,
      )
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Gagal mengubah status publikasi FAQ.')
    } finally {
      setPendingFaqId(null)
    }
  }

  const handleDeleteFaq = async (faq: FaqEntry) => {
    if (pendingFaqId) return
    setPendingFaqId(faq.id)
    setErrorMessage(null)
    try {
      await deleteFaqEntry(faq.id)
      if (editingFaqId === faq.id) {
        resetFaqForm()
      }
      onFeedback(`FAQ "${faq.question}" berhasil dihapus permanen.`)
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Gagal menghapus FAQ.')
    } finally {
      setPendingFaqId(null)
    }
  }

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Konfigurasi Konten &amp; Operasional Platform
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Kelola parameter protokol darurat krisis SafetyNet dan publikasi FAQ halaman utama.
          </p>
        </div>
        {loadingData && activeSubTab === 'faq-crisis' && (
          <span className="inline-flex items-center gap-1.5 rounded-[8px] border border-[#E2E8F0] bg-white px-3 py-1.5 text-xs font-medium text-ink-muted">
            <Loader2 className="size-3.5 animate-spin text-primary" /> Memuat sinkronisasi server...
          </span>
        )}
      </div>

      {/* Sub-navigation Tabs */}
      <div
        role="tablist"
        aria-label="Submenu Konfigurasi Konten"
        className="mt-4 inline-flex w-full flex-wrap gap-2 rounded-[12px] border border-[#E2E8F0] bg-white p-1.5 sm:w-auto"
      >
        <button
          type="button"
          role="tab"
          aria-selected={activeSubTab === 'faq-crisis'}
          onClick={() => setActiveSubTab('faq-crisis')}
          className={cn(
            'min-h-10 cursor-pointer rounded-[8px] px-4 text-xs font-semibold',
            activeSubTab === 'faq-crisis'
              ? 'bg-primary text-white'
              : 'bg-white text-ink-soft hover:bg-[#F8FAFC] hover:text-ink',
          )}
        >
          Protokol Darurat &amp; FAQ Website
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeSubTab === 'booth-feedback'}
          onClick={() => setActiveSubTab('booth-feedback')}
          className={cn(
            'min-h-10 cursor-pointer rounded-[8px] px-4 text-xs font-semibold',
            activeSubTab === 'booth-feedback'
              ? 'bg-primary text-white'
              : 'bg-white text-ink-soft hover:bg-[#F8FAFC] hover:text-ink',
          )}
        >
          Feedback &amp; Selfie Booth Event
        </button>
      </div>

      {activeSubTab === 'booth-feedback' ? (
        <div className="mt-5">
          <BoothFeedbackAdminTab onFeedback={onFeedback} />
        </div>
      ) : (
        <>
          {errorMessage && (
            <div className="mt-4 rounded-[10px] border border-[#FECACA] bg-[#FEF2F2] px-4 py-2.5 text-xs font-medium text-[#991B1B]">
              {errorMessage}
            </div>
          )}

          <div className="mt-5 grid grid-cols-1 gap-6 lg:grid-cols-12">
        {/* Left: Crisis SafetyNet Protocol Configuration */}
        <div className="lg:col-span-5">
          <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
            <h2 className="text-sm font-bold text-ink">
              Konfigurasi Protokol Darurat SafetyNet &amp; DASS-21
            </h2>
            <p className="mt-1 text-xs text-ink-muted">
              Parameter ini mengatur pemicu bantuan darurat otomatis di Aplikasi Mobile Pengguna Umum dan Aplikasi Psikolog.
            </p>

            <form onSubmit={handleSaveCrisisConfig} className="mt-4 space-y-3.5 text-xs">
              <div>
                <label className="block font-semibold text-ink">Nomor Hotline Darurat Nasional</label>
                <input
                  type="text"
                  required
                  value={hotlineNumber}
                  onChange={(e) =>
                    patchCrisisDraft({ hotlineNumber: e.target.value.toUpperCase() })
                  }
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 font-mono uppercase text-ink focus:border-primary focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-ink">Label Layanan Darurat</label>
                <input
                  type="text"
                  required
                  value={hotlineLabel}
                  onChange={(e) => patchCrisisDraft({ hotlineLabel: e.target.value })}
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-semibold text-ink">Ambang Skor Extreme Depresi</label>
                  <input
                    type="number"
                    min={1}
                    max={42}
                    required
                    value={extremeDep}
                    onChange={(e) => patchCrisisDraft({ extremeDep: e.target.value })}
                    className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block font-semibold text-ink">Ambang Skor Extreme Cemas</label>
                  <input
                    type="number"
                    min={1}
                    max={42}
                    required
                    value={extremeAnx}
                    onChange={(e) => patchCrisisDraft({ extremeAnx: e.target.value })}
                    className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                  />
                </div>
              </div>

              <label className="flex cursor-pointer items-start gap-2.5 rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-3">
                <input
                  type="checkbox"
                  checked={autoSafetyNet}
                  onChange={(e) => patchCrisisDraft({ autoSafetyNet: e.target.checked })}
                  className="mt-0.5 size-4 accent-primary"
                />
                <span>
                  <strong className="block text-ink">Aktifkan Modal Intervensi SafetyNet Otomatis</strong>
                  <span className="text-[11px] text-ink-muted">
                    Menghentikan sesi curhat AI biasa &amp; menampilkan tombol panggilan 119 saat kata kunci krisis terdeteksi.
                  </span>
                </span>
              </label>

              <label className="flex cursor-pointer items-start gap-2.5 rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-3">
                <input
                  type="checkbox"
                  checked={allowDirectMandiri}
                  onChange={(e) =>
                    patchCrisisDraft({ allowDirectMandiri: e.target.checked })
                  }
                  className="mt-0.5 size-4 accent-primary"
                />
                <span>
                  <strong className="block text-ink">Izinkan Rujukan Langsung ke Psikolog Mandiri</strong>
                  <span className="text-[11px] text-ink-muted">
                    Pengguna umum dapat memilih jadwal telekonsultasi dengan Psikolog Mandiri yang telah diverifikasi Admin.
                  </span>
                </span>
              </label>

              <button
                type="submit"
                disabled={savingCrisis}
                className="inline-flex h-9 w-full cursor-pointer items-center justify-center gap-1.5 rounded-[8px] bg-primary px-4 font-semibold text-white hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-60"
              >
                {savingCrisis && <Loader2 className="size-3.5 animate-spin" />}
                <span>Simpan Konfigurasi Protokol</span>
              </button>
            </form>
          </div>
        </div>

        {/* Right: FAQ CMS connected to Landing Page */}
        <div className="space-y-5 lg:col-span-7">
          <div ref={faqFormRef} className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
            <div className="flex items-center justify-between gap-2">
              <h2 className="text-sm font-bold text-ink">
                {editingFaqId ? 'Edit Entri FAQ Website' : 'Tambah FAQ Halaman Depan Website'}
              </h2>
              {editingFaqId && (
                <button
                  type="button"
                  onClick={resetFaqForm}
                  className="inline-flex cursor-pointer items-center gap-1 rounded-[6px] border border-[#CBD5E1] px-2.5 py-1 text-[11px] font-semibold text-ink-muted hover:bg-[#F8FAFC] hover:text-ink"
                >
                  <X className="size-3" /> Batal Edit
                </button>
              )}
            </div>

            <form onSubmit={handleSubmitFaq} className="mt-3 space-y-3 text-xs">
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-4">
                <div className="sm:col-span-3">
                  <label className="block font-semibold text-ink">
                    Kategori FAQ (Huruf Kapital)
                  </label>
                  <input
                    type="text"
                    value={faqCategory}
                    onChange={(e) => setFaqCategory(e.target.value.toUpperCase())}
                    placeholder="KEAMANAN & PRIVASI"
                    required
                    minLength={2}
                    className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 uppercase text-ink focus:border-primary focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block font-semibold text-ink">Urutan (Opsional)</label>
                  <input
                    type="number"
                    min={0}
                    max={9999}
                    value={faqSortOrder}
                    onChange={(e) => setFaqSortOrder(e.target.value)}
                    placeholder="Auto"
                    className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                  />
                </div>
              </div>
              <div>
                <label className="block font-semibold text-ink">Pertanyaan</label>
                <input
                  type="text"
                  value={faqQuestion}
                  onChange={(e) => setFaqQuestion(e.target.value)}
                  placeholder="Tuliskan pertanyaan yang sering diajukan pengunjung..."
                  required
                  minLength={5}
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                />
              </div>
              <div>
                <label className="block font-semibold text-ink">Jawaban Resmi</label>
                <textarea
                  rows={3}
                  value={faqAnswer}
                  onChange={(e) => setFaqAnswer(e.target.value)}
                  placeholder="Tuliskan penjelasan transparan yang tampil di Landing Page..."
                  required
                  minLength={5}
                  className="mt-1 w-full rounded-[8px] border border-[#CBD5E1] bg-white p-2.5 text-ink focus:border-primary focus:outline-none"
                />
              </div>
              <button
                type="submit"
                disabled={savingFaq}
                className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 font-semibold text-white hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-60"
              >
                {savingFaq ? (
                  <Loader2 className="size-3.5 animate-spin" />
                ) : (
                  <Plus className="size-3.5" />
                )}
                <span>{editingFaqId ? 'Simpan Perubahan FAQ' : 'Terbitkan ke Landing Page'}</span>
              </button>
            </form>
          </div>

          <div
            ref={faqListCardRef}
            className="rounded-[12px] border border-[#E2E8F0] bg-white p-5"
          >
            <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
              <h2 className="text-sm font-bold text-ink">
                Daftar FAQ Website ({db.faqs.length})
              </h2>
              <div className="relative w-full sm:w-64">
                <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
                <input
                  type="search"
                  value={faqSearch}
                  onChange={(e) => handleFaqSearchChange(e.target.value)}
                  placeholder="Cari kategori atau pertanyaan..."
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink focus:border-primary focus:bg-white focus:outline-none"
                />
              </div>
            </div>

            <div className="mt-3 divide-y divide-[#E2E8F0]">
              {paginatedFaqs.length === 0 ? (
                <div className="py-8 text-center text-xs text-ink-muted">
                  <p className="font-semibold text-ink">
                    {faqSearch.trim()
                      ? 'Tidak ada entri FAQ yang cocok dengan kata kunci pencarian.'
                      : 'Belum ada entri FAQ terdaftar.'}
                  </p>
                  {faqSearch.trim() && (
                    <button
                      type="button"
                      onClick={() => handleFaqSearchChange('')}
                      className="mt-2 inline-flex min-h-8 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink hover:bg-[#F8FAFC]"
                    >
                      Reset Pencarian
                    </button>
                  )}
                </div>
              ) : (
                paginatedFaqs.map((f) => {
                  const isBusy = pendingFaqId === f.id
                  const isBeingEdited = editingFaqId === f.id
                  return (
                    <div
                      key={f.id}
                      className={cn(
                        'flex flex-col justify-between gap-3 py-3 text-xs sm:flex-row sm:items-start',
                        isBeingEdited && 'rounded-[8px] bg-[#EEF0FF]/40 px-2.5',
                      )}
                    >
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-1.5">
                          {f.sortOrder !== undefined && (
                            <span className="rounded-[4px] bg-[#F1F5F9] px-1.5 py-0.5 font-mono text-[10px] font-bold text-ink-muted">
                              #{f.sortOrder}
                            </span>
                          )}
                          <span className="text-[10px] font-bold tracking-wider text-primary uppercase">
                            {f.category}
                          </span>
                        </div>
                        <p className="mt-0.5 font-semibold text-ink">{f.question}</p>
                        <p className="mt-1 line-clamp-2 text-[11px] text-ink-muted">{f.answer}</p>
                      </div>
                      <div className="flex shrink-0 items-center gap-1.5">
                        <button
                          type="button"
                          disabled={isBusy}
                          onClick={() => handleStartEditFaq(f)}
                          aria-label={`Edit FAQ ${f.question}`}
                          className="inline-flex size-7 cursor-pointer items-center justify-center rounded-[6px] border border-[#CBD5E1] bg-white text-ink-soft hover:bg-[#F8FAFC] hover:text-ink disabled:cursor-not-allowed disabled:opacity-50"
                        >
                          <Pencil className="size-3.5" />
                        </button>
                        <button
                          type="button"
                          disabled={isBusy}
                          onClick={() => void handleToggleFaq(f)}
                          className={cn(
                            'cursor-pointer rounded-[6px] border px-2 py-1 text-[11px] font-semibold disabled:cursor-not-allowed disabled:opacity-50',
                            f.isPublished
                              ? 'border-[#BBF7D0] bg-[#F0FDF4] text-[#166534]'
                              : 'border-[#CBD5E1] bg-[#F8FAFC] text-ink-muted',
                          )}
                        >
                          {f.isPublished ? 'Tayang' : 'Disembunyikan'}
                        </button>
                        <button
                          type="button"
                          disabled={isBusy}
                          onClick={() => void handleDeleteFaq(f)}
                          aria-label={`Hapus FAQ ${f.question}`}
                          className="inline-flex size-7 cursor-pointer items-center justify-center rounded-[6px] border border-[#FECACA] bg-[#FEF2F2] text-[#B91C1C] disabled:cursor-not-allowed disabled:opacity-50"
                        >
                          <Trash2 className="size-3.5" />
                        </button>
                      </div>
                    </div>
                  )
                })
              )}
            </div>
          </div>

          <TablePagination
            currentPage={faqSafePage}
            totalItems={filteredFaqs.length}
            pageSize={faqPageSize}
            pageSizeOptions={[5, 10, 25]}
            itemLabel="FAQ"
            ariaLabel="Paginasi daftar FAQ"
            onPageChange={handleFaqPageChange}
            onPageSizeChange={handleFaqPageSizeChange}
          />
        </div>
      </div>
        </>
      )}
    </div>
  )
}
