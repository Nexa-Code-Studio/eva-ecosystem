import { useState, type FormEvent } from 'react'
import { Plus, Trash2 } from 'lucide-react'
import { cn } from '@/lib/cn'
import type { CopingQuest, PortalDatabase } from '@/types/portal'
import {
  addCopingQuest,
  deleteCopingQuest,
  toggleCopingQuest,
  updateCrisisConfig,
} from '@/services/portal/ecosystemService'

interface AdminMobileContentTabProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

export function AdminMobileContentTab({
  db,
  onFeedback,
}: AdminMobileContentTabProps) {
  const [questCode, setQuestCode] = useState('')
  const [questTitle, setQuestTitle] = useState('')
  const [questCategory, setQuestCategory] = useState<CopingQuest['category']>('Pernapasan')
  const [questDuration, setQuestDuration] = useState('3')
  const [questTargetEmotion, setQuestTargetEmotion] = useState('')

  const [hotlineNumber, setHotlineNumber] = useState(db.crisisConfig.hotlineNumber)
  const [hotlineLabel, setHotlineLabel] = useState(db.crisisConfig.hotlineLabel)
  const [extremeDep, setExtremeDep] = useState(String(db.crisisConfig.extremeDepressionThreshold))
  const [extremeAnx, setExtremeAnx] = useState(String(db.crisisConfig.extremeAnxietyThreshold))
  const [autoSafetyNet, setAutoSafetyNet] = useState(db.crisisConfig.autoSafetyNetModal)
  const [allowDirectMandiri, setAllowDirectMandiri] = useState(
    db.crisisConfig.allowDirectIndependentReferral,
  )

  const handleAddQuest = (e: FormEvent) => {
    e.preventDefault()
    if (!questCode.trim() || !questTitle.trim() || !questTargetEmotion.trim()) return

    addCopingQuest({
      code: questCode,
      title: questTitle,
      category: questCategory,
      durationMinutes: Number(questDuration) || 3,
      targetEmotion: questTargetEmotion,
    })
    setQuestCode('')
    setQuestTitle('')
    setQuestTargetEmotion('')
    onFeedback(`Misi koping "${questTitle}" berhasil ditambahkan ke Aplikasi Mobile User.`)
  }

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

  return (
    <div className="mt-5 grid grid-cols-1 gap-6 lg:grid-cols-12">
      {/* Coping Quests Management */}
      <div className="space-y-5 lg:col-span-7">
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
          <h2 className="text-sm font-bold text-ink">
            Tambah Misi Koping Harian (Aplikasi Mobile User)
          </h2>
          <form onSubmit={handleAddQuest} className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-xs font-semibold text-ink">
                Kode Misi (Otomatis Huruf Kapital)
              </label>
              <input
                type="text"
                value={questCode}
                onChange={(e) => setQuestCode(e.target.value.toUpperCase())}
                placeholder="QUEST-JOURNAL-3M"
                required
                className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 font-mono text-xs uppercase text-ink focus:border-primary focus:outline-none"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-ink">Kategori Latihan</label>
              <select
                value={questCategory}
                onChange={(e) => setQuestCategory(e.target.value as CopingQuest['category'])}
                className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs text-ink focus:border-primary focus:outline-none"
              >
                <option value="Pernapasan">Pernapasan</option>
                <option value="Grounding">Grounding</option>
                <option value="Refleksi Kognitif">Refleksi Kognitif</option>
                <option value="Regulasi Tidur">Regulasi Tidur</option>
              </select>
            </div>
            <div className="sm:col-span-2">
              <label className="block text-xs font-semibold text-ink">
                Judul Misi Koping di Aplikasi
              </label>
              <input
                type="text"
                value={questTitle}
                onChange={(e) => setQuestTitle(e.target.value)}
                placeholder="Contoh: Jeda Napas Terpandu Sebelum Presentasi"
                required
                className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs text-ink focus:border-primary focus:outline-none"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-ink">Target Kondisi Emosi</label>
              <input
                type="text"
                value={questTargetEmotion}
                onChange={(e) => setQuestTargetEmotion(e.target.value)}
                placeholder="Contoh: Cemas Sosial & Gugup"
                required
                className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs text-ink focus:border-primary focus:outline-none"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-ink">Durasi (Menit)</label>
              <input
                type="number"
                min={1}
                max={15}
                value={questDuration}
                onChange={(e) => setQuestDuration(e.target.value)}
                className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs text-ink focus:border-primary focus:outline-none"
              />
            </div>
            <div className="sm:col-span-2">
              <button
                type="submit"
                className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white hover:bg-primary-hover"
              >
                <Plus className="size-3.5" /> Tambahkan ke Katalog Mobile
              </button>
            </div>
          </form>
        </div>

        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
          <h2 className="text-sm font-bold text-ink">
            Katalog Misi Koping Terdaftar ({db.copingQuests.length})
          </h2>
          <div className="mt-3 divide-y divide-[#E2E8F0]">
            {db.copingQuests.map((q) => (
              <div
                key={q.id}
                className="flex flex-wrap items-center justify-between gap-3 py-3 text-xs"
              >
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-[11px] font-bold text-primary">{q.code}</span>
                    <span className="rounded-[5px] bg-[#F1F5F9] px-2 py-0.5 text-[10px] font-semibold text-ink-soft">
                      {q.category} · {q.durationMinutes} mnt
                    </span>
                  </div>
                  <p className="mt-1 font-semibold text-ink">{q.title}</p>
                  <p className="text-[11px] text-ink-muted">
                    Target: {q.targetEmotion} · Diselesaikan {q.completionCount} kali
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => toggleCopingQuest(q.id)}
                    className={cn(
                      'cursor-pointer rounded-[6px] border px-2.5 py-1 text-[11px] font-semibold',
                      q.isActive
                        ? 'border-[#BBF7D0] bg-[#F0FDF4] text-[#166534]'
                        : 'border-[#CBD5E1] bg-[#F8FAFC] text-ink-muted',
                    )}
                  >
                    {q.isActive ? 'Aktif di App' : 'Nonaktif'}
                  </button>
                  <button
                    type="button"
                    onClick={() => deleteCopingQuest(q.id)}
                    aria-label={`Hapus ${q.title}`}
                    className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[6px] border border-[#FECACA] bg-[#FEF2F2] text-[#B91C1C]"
                  >
                    <Trash2 className="size-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Crisis Protocol Configuration */}
      <div className="lg:col-span-5">
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
          <h2 className="text-sm font-bold text-ink">
            Konfigurasi Protokol Darurat SafetyNet & DASS-21
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
                  Menghentikan sesi curhat AI biasa & menampilkan tombol panggilan 119 saat kata kunci krisis terdeteksi.
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
    </div>
  )
}
