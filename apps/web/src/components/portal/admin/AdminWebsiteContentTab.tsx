import { useState, type FormEvent } from 'react'
import { Mail, Plus, Trash2 } from 'lucide-react'
import { cn } from '../../../lib/cn'
import type { PortalDatabase } from '../../../types/portal'
import {
  addFaqEntry,
  deleteFaqEntry,
  toggleFaqPublished,
  updateWaitlistStatus,
} from '../../../services/portal/ecosystemService'

interface AdminWebsiteContentTabProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

export function AdminWebsiteContentTab({
  db,
  onFeedback,
}: AdminWebsiteContentTabProps) {
  const [faqCategory, setFaqCategory] = useState('KEAMANAN & PRIVASI')
  const [faqQuestion, setFaqQuestion] = useState('')
  const [faqAnswer, setFaqAnswer] = useState('')

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
    <div className="mt-5 grid grid-cols-1 gap-6 lg:grid-cols-12">
      {/* Left: Early Access Waitlist from Landing Page */}
      <div className="lg:col-span-6">
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
          <div>
            <h2 className="text-sm font-bold text-ink">
              Pendaftar Early Access & Kemitraan Website ({db.waitlistEntries.length})
            </h2>
            <p className="text-xs text-ink-muted">
              Terhubung langsung dengan form Early Access di halaman utama Website.
            </p>
          </div>

          <div className="mt-4 divide-y divide-[#E2E8F0]">
            {db.waitlistEntries.map((item) => (
              <div
                key={item.id}
                className="flex flex-wrap items-center justify-between gap-3 py-3 text-xs"
              >
                <div>
                  <div className="flex items-center gap-2">
                    <Mail className="size-3.5 text-primary" />
                    <span className="font-semibold text-ink">{item.contact}</span>
                    <span className="rounded-[5px] bg-[#F1F5F9] px-1.5 py-0.5 text-[10px] font-semibold text-ink-soft">
                      {item.channel}
                    </span>
                  </div>
                  <p className="mt-1 text-[11px] text-ink-muted">
                    Topik: {item.topic} · Masuk: {item.submittedAt}
                  </p>
                </div>

                <select
                  aria-label={`Status waitlist ${item.contact}`}
                  value={item.status}
                  onChange={(e) =>
                    updateWaitlistStatus(
                      item.id,
                      e.target.value as 'new' | 'invited' | 'archived',
                    )
                  }
                  className="h-8 rounded-[6px] border border-[#CBD5E1] bg-white px-2 text-xs font-semibold text-ink"
                >
                  <option value="new">Baru Masuk</option>
                  <option value="invited">Sudah Diundang</option>
                  <option value="archived">Diarsipkan</option>
                </select>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Right: FAQ CMS connected to Landing Page */}
      <div className="space-y-5 lg:col-span-6">
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
  )
}

