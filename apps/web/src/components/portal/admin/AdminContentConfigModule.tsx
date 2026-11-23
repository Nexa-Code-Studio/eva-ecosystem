import { useState, type FormEvent } from 'react'
import { Plus, Trash2 } from 'lucide-react'
import { cn } from '@/lib/cn'
import type { PortalDatabase } from '@/types/portal'
import {
  addFaqEntry,
  deleteFaqEntry,
  toggleFaqPublished,
  updateCrisisConfig,
} from '@/services/portal/ecosystemService'

interface AdminContentConfigModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

export function AdminContentConfigModule({ db, onFeedback }: AdminContentConfigModuleProps) {
  // Crisis SafetyNet Protocol state
  const [hotlineNumber, setHotlineNumber] = useState(db.crisisConfig.hotlineNumber)
  const [hotlineLabel, setHotlineLabel] = useState(db.crisisConfig.hotlineLabel)
  const [extremeDep, setExtremeDep] = useState(String(db.crisisConfig.extremeDepressionThreshold))
  const [extremeAnx, setExtremeAnx] = useState(String(db.crisisConfig.extremeAnxietyThreshold))
  const [autoSafetyNet, setAutoSafetyNet] = useState(db.crisisConfig.autoSafetyNetModal)
  const [allowDirectMandiri, setAllowDirectMandiri] = useState(
    db.crisisConfig.allowDirectIndependentReferral,
  )

  // FAQ state
  const [faqCategory, setFaqCategory] = useState('KEAMANAN & PRIVASI')
  const [faqQuestion, setFaqQuestion] = useState('')
  const [faqAnswer, setFaqAnswer] = useState('')

  const handleSaveCrisisConfig = (e: FormEvent) => {
    e.preventDefault()
    updateCrisisConfig({
      hotlineNumber,
      hotlineLabel,
      extremeDepressionThreshold: Number(extremeDep) || 28,
      extremeAnxietyThreshold: Number(extremeAnx) || 20,
      autoSafetyNetModal: autoSafetyNet,
      allowDirectIndependentReferral: allowDirectMandiri,
    })
    onFeedback(
      'Konfigurasi Protokol Krisis SafetyNet & Rujukan Psikolog Mandiri berhasil diperbarui.',
    )
  }

  const handleAddFaq = (e: FormEvent) => {
    e.preventDefault()
    if (!faqQuestion.trim() || !faqAnswer.trim()) return

    addFaqEntry({
      category: faqCategory,
      question: faqQuestion,
      answer: faqAnswer,
    })
    setFaqQuestion('')
    setFaqAnswer('')
    onFeedback('Pertanyaan FAQ baru telah ditambahkan dan langsung tampil di Landing Page.')
  }

  return (
    <div>
      <div>
        <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
          Konfigurasi Konten &amp; Operasional Platform
        </h1>
        <p className="mt-0.5 text-xs text-ink-muted">
          Kelola parameter protokol darurat krisis SafetyNet dan publikasi FAQ halaman utama.
        </p>
      </div>

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
                  value={hotlineNumber}
                  onChange={(e) => setHotlineNumber(e.target.value.toUpperCase())}
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 font-mono uppercase text-ink focus:border-primary focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-ink">Label Layanan Darurat</label>
                <input
                  type="text"
                  value={hotlineLabel}
                  onChange={(e) => setHotlineLabel(e.target.value)}
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-semibold text-ink">Ambang Skor Extreme Depresi</label>
                  <input
                    type="number"
                    value={extremeDep}
                    onChange={(e) => setExtremeDep(e.target.value)}
                    className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block font-semibold text-ink">Ambang Skor Extreme Cemas</label>
                  <input
                    type="number"
                    value={extremeAnx}
                    onChange={(e) => setExtremeAnx(e.target.value)}
                    className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                  />
                </div>
              </div>

              <label className="flex cursor-pointer items-start gap-2.5 rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-3">
                <input
                  type="checkbox"
                  checked={autoSafetyNet}
                  onChange={(e) => setAutoSafetyNet(e.target.checked)}
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
                  onChange={(e) => setAllowDirectMandiri(e.target.checked)}
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
                className="inline-flex h-9 w-full cursor-pointer items-center justify-center rounded-[8px] bg-primary px-4 font-semibold text-white hover:bg-primary-hover"
              >
                Simpan Konfigurasi Protokol
              </button>
            </form>
          </div>
        </div>

        {/* Right: FAQ CMS connected to Landing Page */}
        <div className="space-y-5 lg:col-span-7">
          <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
            <h2 className="text-sm font-bold text-ink">Tambah FAQ Halaman Depan Website</h2>
            <form onSubmit={handleAddFaq} className="mt-3 space-y-3 text-xs">
              <div>
                <label className="block font-semibold text-ink">
                  Kategori FAQ (Huruf Kapital)
                </label>
                <input
                  type="text"
                  value={faqCategory}
                  onChange={(e) => setFaqCategory(e.target.value.toUpperCase())}
                  placeholder="KEAMANAN & PRIVASI"
                  required
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 uppercase text-ink focus:border-primary focus:outline-none"
                />
              </div>
              <div>
                <label className="block font-semibold text-ink">Pertanyaan</label>
                <input
                  type="text"
                  value={faqQuestion}
                  onChange={(e) => setFaqQuestion(e.target.value)}
                  placeholder="Tuliskan pertanyaan yang sering diajukan pengunjung..."
                  required
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
                  className="mt-1 w-full rounded-[8px] border border-[#CBD5E1] bg-white p-2.5 text-ink focus:border-primary focus:outline-none"
                />
              </div>
              <button
                type="submit"
                className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 font-semibold text-white hover:bg-primary-hover"
              >
                <Plus className="size-3.5" /> Terbitkan ke Landing Page
              </button>
            </form>
          </div>

          <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
            <h2 className="text-sm font-bold text-ink">
              Daftar FAQ Website ({db.faqs.length})
            </h2>
            <div className="mt-3 divide-y divide-[#E2E8F0]">
              {db.faqs.map((f) => (
                <div
                  key={f.id}
                  className="flex items-start justify-between gap-3 py-3 text-xs"
                >
                  <div>
                    <span className="text-[10px] font-bold tracking-wider text-primary uppercase">
                      {f.category}
                    </span>
                    <p className="mt-0.5 font-semibold text-ink">{f.question}</p>
                  </div>
                  <div className="flex shrink-0 items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => toggleFaqPublished(f.id)}
                      className={cn(
                        'cursor-pointer rounded-[6px] border px-2 py-1 text-[11px] font-semibold',
                        f.isPublished
                          ? 'border-[#BBF7D0] bg-[#F0FDF4] text-[#166534]'
                          : 'border-[#CBD5E1] bg-[#F8FAFC] text-ink-muted',
                      )}
                    >
                      {f.isPublished ? 'Tayang' : 'Disembunyikan'}
                    </button>
                    <button
                      type="button"
                      onClick={() => deleteFaqEntry(f.id)}
                      aria-label={`Hapus FAQ ${f.question}`}
                      className="inline-flex size-7 cursor-pointer items-center justify-center rounded-[6px] border border-[#FECACA] bg-[#FEF2F2] text-[#B91C1C]"
                    >
                      <Trash2 className="size-3.5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
