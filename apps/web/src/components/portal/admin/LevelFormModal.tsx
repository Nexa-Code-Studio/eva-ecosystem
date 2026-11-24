import { Award, CheckCircle2, Loader2, X } from 'lucide-react'
import { useEffect, useState, type FormEvent } from 'react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import type { UpsertPsychologistLevelRequestDto } from '@/types/api/contracts'
import type { PsychologistLevelConfig } from '@/types/domain/portal'

interface LevelFormModalProps {
  isOpen: boolean
  editingLevel: PsychologistLevelConfig | null
  nextSuggestedTier: number
  basePricePerCoinIdr: number
  onClose: () => void
  onSave: (payload: UpsertPsychologistLevelRequestDto, editingId?: string) => Promise<void>
}

const BADGE_ICON_OPTIONS = [
  { value: 'award', label: 'Award (Pemula / Dasar)' },
  { value: 'shield-check', label: 'Shield Check (Terdaftar)' },
  { value: 'star', label: 'Star (Spesialis Senior)' },
  { value: 'crown', label: 'Crown (Master / Eksekutif)' },
  { value: 'sparkles', label: 'Sparkles (Unggulan)' },
] as const

function formatIdr(value: number): string {
  return `Rp${Math.round(value).toLocaleString('id-ID')}`
}

export function LevelFormModal({
  isOpen,
  editingLevel,
  nextSuggestedTier,
  basePricePerCoinIdr,
  onClose,
  onSave,
}: LevelFormModalProps) {
  useBodyScrollLock(isOpen)

  const [levelTier, setLevelTier] = useState(() =>
    String(editingLevel?.levelTier ?? nextSuggestedTier),
  )
  const [name, setName] = useState(() => editingLevel?.name ?? '')
  const [badgeIcon, setBadgeIcon] = useState(() => editingLevel?.badgeIcon ?? 'award')
  const [minSessions, setMinSessions] = useState(() =>
    String(editingLevel?.minCompletedSessions ?? 0),
  )
  const [minRating, setMinRating] = useState(() =>
    String(editingLevel?.minAverageRating ?? 0),
  )
  const [minHours, setMinHours] = useState(() =>
    String(editingLevel?.minConsultationHours ?? 0),
  )
  const [minReviews, setMinReviews] = useState(() =>
    String(editingLevel?.minReviewCount ?? 0),
  )
  const [defaultPrice, setDefaultPrice] = useState(() =>
    String(editingLevel?.defaultSessionPrice ?? 150),
  )
  const [platformFee, setPlatformFee] = useState(() =>
    String(editingLevel?.platformFeePercentage ?? 20),
  )
  const [allowCustomPrice, setAllowCustomPrice] = useState(
    () => editingLevel?.allowCustomPrice ?? false,
  )
  const [minCustomPrice, setMinCustomPrice] = useState(() =>
    editingLevel?.minCustomPrice !== null && editingLevel?.minCustomPrice !== undefined
      ? String(editingLevel.minCustomPrice)
      : '150',
  )
  const [maxCustomPrice, setMaxCustomPrice] = useState(() =>
    editingLevel?.maxCustomPrice !== null && editingLevel?.maxCustomPrice !== undefined
      ? String(editingLevel.maxCustomPrice)
      : '250',
  )
  const [isActive, setIsActive] = useState(() => editingLevel?.isActive ?? true)
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

  const coinRate = Math.max(1, Math.round(basePricePerCoinIdr) || 1000)
  const parsedPrice = Math.max(0, Number(defaultPrice) || 0)
  const parsedFee = Math.min(100, Math.max(0, Number(platformFee) || 0))
  const counselorSharePct = Math.round((100 - parsedFee) * 100) / 100

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    if (submitting) return

    const tierNum = Math.trunc(Number(levelTier) || 0)
    const minCustom = allowCustomPrice ? Number(minCustomPrice) : null
    const maxCustom = allowCustomPrice ? Number(maxCustomPrice) : null

    if (tierNum < 1) {
      setErrorMsg('Urutan tier level minimal adalah 1.')
      return
    }
    if (allowCustomPrice) {
      if (minCustom === null || maxCustom === null || Number.isNaN(minCustom) || Number.isNaN(maxCustom)) {
        setErrorMsg('Batas tarif minimal dan maksimal wajib diisi.')
        return
      }
      if (minCustom > maxCustom) {
        setErrorMsg('Batas tarif minimal tidak boleh lebih besar dari batas maksimal.')
        return
      }
      if (parsedPrice < minCustom || parsedPrice > maxCustom) {
        setErrorMsg('Tarif dasar sesi harus berada di antara batas tarif minimal dan maksimal.')
        return
      }
    }

    setSubmitting(true)
    setErrorMsg(null)
    try {
      await onSave(
        {
          levelTier: tierNum,
          name: name.trim(),
          badgeIcon: badgeIcon.trim() || 'award',
          minCompletedSessions: Math.max(0, Math.trunc(Number(minSessions) || 0)),
          minAverageRating: Math.min(5, Math.max(0, Number(minRating) || 0)),
          minConsultationHours: Math.max(0, Number(minHours) || 0),
          minReviewCount: Math.max(0, Math.trunc(Number(minReviews) || 0)),
          defaultSessionPrice: parsedPrice,
          platformFeePercentage: parsedFee,
          allowCustomPrice,
          minCustomPrice: minCustom,
          maxCustomPrice: maxCustom,
          isActive,
        },
        editingLevel?.id,
      )
      onClose()
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal menyimpan konfigurasi level.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={editingLevel ? `Edit Level ${editingLevel.name}` : 'Tambah Tier Level Psikolog'}
      onClick={onClose}
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 p-3 sm:p-4"
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="flex max-h-[92dvh] w-full max-w-2xl flex-col overflow-hidden rounded-[16px] border border-[#E2E8F0] bg-white shadow-2xl"
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
                {editingLevel ? `Edit Tier #${editingLevel.levelTier}: ${editingLevel.name}` : 'Tambah Tier Level Psikolog'}
              </h2>
              <p className="text-xs text-ink-muted">
                Konfigurasi syarat kenaikan karier kuantitatif, tarif dasar Koin EVA, potongan fee platform, serta izin tarif mandiri.
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup modal konfigurasi level"
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

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-6">
            <div className="sm:col-span-1">
              <label htmlFor="level-tier-input" className="mb-1 block font-semibold text-ink">
                Tier *
              </label>
              <input
                id="level-tier-input"
                type="number"
                min={1}
                max={99}
                required
                value={levelTier}
                onChange={(e) => setLevelTier(e.target.value)}
                className="min-h-11 w-full rounded-[8px] border border-[#768396] px-2.5 font-mono text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
              />
            </div>
            <div className="sm:col-span-3">
              <label htmlFor="level-name-input" className="mb-1 block font-semibold text-ink">
                Nama Tier Level *
              </label>
              <input
                id="level-name-input"
                type="text"
                required
                minLength={2}
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Contoh: Senior Specialist"
                className="min-h-11 w-full rounded-[8px] border border-[#768396] px-3 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
              />
            </div>
            <div className="sm:col-span-2">
              <label htmlFor="level-icon-select" className="mb-1 block font-semibold text-ink">
                Ikon Badge
              </label>
              <select
                id="level-icon-select"
                value={badgeIcon}
                onChange={(e) => setBadgeIcon(e.target.value)}
                className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
              >
                {BADGE_ICON_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <fieldset className="rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5">
            <legend className="px-1 text-[11px] font-bold tracking-wider text-ink-soft uppercase">
              Syarat Kenaikan Kuantitatif Minimal
            </legend>
            <div className="mt-1 grid grid-cols-2 gap-3 sm:grid-cols-4">
              <div>
                <label htmlFor="level-min-sessions" className="mb-1 block font-semibold text-ink">
                  Min. Sesi Selesai
                </label>
                <input
                  id="level-min-sessions"
                  type="number"
                  min={0}
                  required
                  value={minSessions}
                  onChange={(e) => setMinSessions(e.target.value)}
                  className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                />
              </div>
              <div>
                <label htmlFor="level-min-rating" className="mb-1 block font-semibold text-ink">
                  Min. Rating (0-5)
                </label>
                <input
                  id="level-min-rating"
                  type="number"
                  step="0.1"
                  min={0}
                  max={5}
                  required
                  value={minRating}
                  onChange={(e) => setMinRating(e.target.value)}
                  className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                />
              </div>
              <div>
                <label htmlFor="level-min-hours" className="mb-1 block font-semibold text-ink">
                  Min. Jam Terbang
                </label>
                <input
                  id="level-min-hours"
                  type="number"
                  step="0.5"
                  min={0}
                  required
                  value={minHours}
                  onChange={(e) => setMinHours(e.target.value)}
                  className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                />
              </div>
              <div>
                <label htmlFor="level-min-reviews" className="mb-1 block font-semibold text-ink">
                  Min. Jumlah Ulasan
                </label>
                <input
                  id="level-min-reviews"
                  type="number"
                  min={0}
                  required
                  value={minReviews}
                  onChange={(e) => setMinReviews(e.target.value)}
                  className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                />
              </div>
            </div>
          </fieldset>

          <fieldset className="rounded-[10px] border border-[#E2E8F0] bg-white p-3.5">
            <legend className="px-1 text-[11px] font-bold tracking-wider text-ink-soft uppercase">
              Skema Tarif Dasar &amp; Bagi Hasil (Satuan EVA Coin)
            </legend>
            <div className="mt-1 grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label htmlFor="level-default-price" className="mb-1 block font-semibold text-ink">
                  Tarif Dasar per Sesi (Koin) *
                </label>
                <input
                  id="level-default-price"
                  type="number"
                  min={0}
                  step="1"
                  required
                  value={defaultPrice}
                  onChange={(e) => setDefaultPrice(e.target.value)}
                  className="min-h-11 w-full rounded-[8px] border border-[#768396] px-3 text-xs font-semibold text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                />
                <p className="mt-1 text-[11px] text-ink-muted">
                  Setara {formatIdr(parsedPrice * coinRate)} (kurs {formatIdr(coinRate)}/Koin)
                </p>
              </div>
              <div>
                <label htmlFor="level-platform-fee" className="mb-1 block font-semibold text-ink">
                  Potongan Fee Platform (%) *
                </label>
                <input
                  id="level-platform-fee"
                  type="number"
                  min={0}
                  max={100}
                  step="0.5"
                  required
                  value={platformFee}
                  onChange={(e) => setPlatformFee(e.target.value)}
                  className="min-h-11 w-full rounded-[8px] border border-[#768396] px-3 text-xs font-semibold text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                />
                <p className="mt-1 text-[11px] text-ink-muted">
                  Hak Psikolog: {counselorSharePct}% ({Math.round((parsedPrice * counselorSharePct) / 100)} Koin/sesi)
                </p>
              </div>
            </div>

            <div className="mt-3 border-t border-[#E2E8F0] pt-3">
              <label htmlFor="level-allow-custom" className="flex cursor-pointer items-center gap-2.5">
                <input
                  id="level-allow-custom"
                  type="checkbox"
                  checked={allowCustomPrice}
                  onChange={(e) => setAllowCustomPrice(e.target.checked)}
                  className="size-4 accent-primary"
                />
                <span className="font-semibold text-ink">
                  Izinkan Psikolog Tentukan Tarif Sendiri pada tier ini
                </span>
              </label>

              {allowCustomPrice && (
                <div className="mt-3 grid grid-cols-1 gap-3 rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-3 sm:grid-cols-2">
                  <div>
                    <label htmlFor="level-min-custom-price" className="mb-1 block font-semibold text-ink">
                      Batas Bawah Tarif Mandiri (Koin) *
                    </label>
                    <input
                      id="level-min-custom-price"
                      type="number"
                      min={0}
                      required={allowCustomPrice}
                      value={minCustomPrice}
                      onChange={(e) => setMinCustomPrice(e.target.value)}
                      className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                    />
                    <p className="mt-0.5 text-[10px] text-ink-muted">
                      Setara {formatIdr((Number(minCustomPrice) || 0) * coinRate)}
                    </p>
                  </div>
                  <div>
                    <label htmlFor="level-max-custom-price" className="mb-1 block font-semibold text-ink">
                      Batas Atas Tarif Mandiri (Koin) *
                    </label>
                    <input
                      id="level-max-custom-price"
                      type="number"
                      min={0}
                      required={allowCustomPrice}
                      value={maxCustomPrice}
                      onChange={(e) => setMaxCustomPrice(e.target.value)}
                      className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-xs text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                    />
                    <p className="mt-0.5 text-[10px] text-ink-muted">
                      Setara {formatIdr((Number(maxCustomPrice) || 0) * coinRate)}
                    </p>
                  </div>
                </div>
              )}
            </div>
          </fieldset>

          <label htmlFor="level-is-active" className="flex cursor-pointer items-center gap-2">
            <input
              id="level-is-active"
              type="checkbox"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
              className="size-4 accent-primary"
            />
            <span className="font-semibold text-ink">Tier level aktif dalam evaluasi otomatis</span>
          </label>

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
              disabled={submitting}
              className="inline-flex min-h-11 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 font-semibold text-white hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-60 sm:h-9 sm:min-h-0"
            >
              {submitting ? (
                <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />
              ) : (
                <CheckCircle2 className="size-3.5" aria-hidden="true" />
              )}
              <span>{editingLevel ? 'Simpan Perubahan Level' : 'Simpan Tier Baru'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
