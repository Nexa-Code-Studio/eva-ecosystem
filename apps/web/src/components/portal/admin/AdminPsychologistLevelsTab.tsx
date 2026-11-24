import {
  AlertCircle,
  Award,
  CheckCircle2,
  Crown,
  Loader2,
  Pencil,
  Plus,
  RefreshCw,
  ShieldCheck,
  Sparkles,
  Star,
  Trash2,
  XCircle,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { LevelFormModal } from './LevelFormModal'
import { cn } from '@/lib/cn'
import {
  createPsychologistLevel,
  deletePsychologistLevel,
  evaluateAllPsychologistLevels,
  fetchPsychologistLevels,
  togglePsychologistLevelActive,
  updatePsychologistLevel,
  type PortalDatabase,
  type PsychologistLevelConfig,
} from '@/lib/portalStore'
import type { UpsertPsychologistLevelRequestDto } from '@/types/api/contracts'

interface AdminPsychologistLevelsTabProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

function renderLevelIcon(iconName: string) {
  switch (iconName) {
    case 'crown':
      return <Crown className="size-4" aria-hidden="true" />
    case 'star':
      return <Star className="size-4" aria-hidden="true" />
    case 'shield-check':
      return <ShieldCheck className="size-4" aria-hidden="true" />
    case 'sparkles':
      return <Sparkles className="size-4" aria-hidden="true" />
    default:
      return <Award className="size-4" aria-hidden="true" />
  }
}

function formatCoins(value: number): string {
  return `${Math.round(value).toLocaleString('id-ID')} Koin`
}

function formatIdr(value: number): string {
  return `Rp${Math.round(value).toLocaleString('id-ID')}`
}

function formatLevelLoadError(err: unknown): string {
  const raw = err instanceof Error ? err.message : ''
  if (raw.trim().toLowerCase() === 'not found' || raw.includes('404')) {
    return 'Endpoint /admin/psychologist-levels belum tersedia (404 Not Found) pada server API yang aktif saat ini. Untuk menguji fitur Issue #120 secara lokal, arahkan VITE_API_BASE_URL ke http://localhost:8888/api/v1 atau deploy backend branch ini ke server target.'
  }
  return raw || 'Gagal memuat master level psikolog.'
}

export function AdminPsychologistLevelsTab({
  db,
  onFeedback,
}: AdminPsychologistLevelsTabProps) {
  const [loading, setLoading] = useState(true)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const [evaluating, setEvaluating] = useState(false)
  const [modalOpen, setModalOpen] = useState(false)
  const [editingLevel, setEditingLevel] = useState<PsychologistLevelConfig | null>(null)
  const [deletingLevel, setDeletingLevel] = useState<PsychologistLevelConfig | null>(null)
  const [deletingSubmitting, setDeletingSubmitting] = useState(false)

  const handleRetryLoad = () => {
    setLoading(true)
    setErrorMsg(null)
    void fetchPsychologistLevels()
      .then(() => {
        setErrorMsg(null)
      })
      .catch((err) => {
        setErrorMsg(formatLevelLoadError(err))
      })
      .finally(() => {
        setLoading(false)
      })
  }

  useEffect(() => {
    let active = true
    fetchPsychologistLevels()
      .then(() => {
        if (active) setErrorMsg(null)
      })
      .catch((err) => {
        if (active) {
          setErrorMsg(formatLevelLoadError(err))
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
    if (!deletingLevel) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setDeletingLevel(null)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [deletingLevel])

  const sortedLevels = [...db.psychologistLevels].sort((a, b) => a.levelTier - b.levelTier)
  const nextSuggestedTier =
    sortedLevels.length > 0 ? Math.max(...sortedLevels.map((l) => l.levelTier)) + 1 : 1
  const coinRateIdr = Math.max(1, Math.round(db.coinEconomyConfig.basePricePerCoinIdr) || 1000)

  const handleSaveLevel = async (
    payload: UpsertPsychologistLevelRequestDto,
    editingId?: string,
  ) => {
    if (editingId) {
      const updated = await updatePsychologistLevel(editingId, payload)
      onFeedback(`Tier #${updated.levelTier} "${updated.name}" berhasil diperbarui.`)
    } else {
      const created = await createPsychologistLevel(payload)
      onFeedback(`Tier baru #${created.levelTier} "${created.name}" berhasil ditambahkan.`)
    }
  }

  const handleEvaluateAll = async () => {
    if (evaluating) return
    setEvaluating(true)
    setErrorMsg(null)
    try {
      const res = await evaluateAllPsychologistLevels()
      onFeedback(res.message)
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal menjalankan evaluasi ulang level.')
    } finally {
      setEvaluating(false)
    }
  }

  const handleConfirmDelete = async () => {
    if (!deletingLevel || deletingSubmitting) return
    setDeletingSubmitting(true)
    setErrorMsg(null)
    try {
      await deletePsychologistLevel(deletingLevel.id)
      onFeedback(`Tier #${deletingLevel.levelTier} "${deletingLevel.name}" berhasil dihapus/dinonaktifkan.`)
      setDeletingLevel(null)
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal menghapus tier level.')
    } finally {
      setDeletingSubmitting(false)
    }
  }

  return (
    <div className="mt-5 space-y-4">
      <div className="flex flex-col justify-between gap-3 rounded-[12px] border border-[#E2E8F0] bg-white p-4 lg:flex-row lg:items-center">
        <div>
          <h2 className="text-sm font-bold text-ink">
            Konfigurasi Dinamis Jenjang Karier &amp; Tarif Psikolog
          </h2>
          <p className="mt-0.5 text-xs text-ink-muted">
            Syarat minimal sesi, rating ulasan, dan jam terbang dievaluasi otomatis dari database; tarif dasar dan potongan platform berlaku untuk pemesanan serta perpanjangan sesi.
          </p>
        </div>

        <div className="flex shrink-0 flex-wrap items-center gap-2">
          <button
            type="button"
            disabled={evaluating}
            onClick={() => void handleEvaluateAll()}
            className="inline-flex min-h-11 cursor-pointer items-center gap-1.5 rounded-[8px] border border-primary/40 bg-[#EEF0FF] px-3.5 text-xs font-semibold text-primary hover:bg-primary hover:text-white disabled:cursor-not-allowed disabled:opacity-60 sm:h-9 sm:min-h-0"
          >
            {evaluating ? (
              <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />
            ) : (
              <Sparkles className="size-3.5" aria-hidden="true" />
            )}
            <span>Evaluasi Ulang Level</span>
          </button>
          <button
            type="button"
            onClick={() => {
              setEditingLevel(null)
              setModalOpen(true)
            }}
            className="inline-flex min-h-11 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-3.5 text-xs font-semibold text-white shadow-btn hover:bg-primary-hover sm:h-9 sm:min-h-0"
          >
            <Plus className="size-3.5" aria-hidden="true" />
            <span>Tambah Tier Level</span>
          </button>
        </div>
      </div>

      {errorMsg && (
        <div
          role="alert"
          className="flex flex-wrap items-center justify-between gap-2 rounded-[10px] border border-[#FECACA] bg-[#FEF2F2] px-4 py-2.5 text-xs font-medium text-[#991B1B]"
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

      <div className="overflow-hidden rounded-[12px] border border-[#E2E8F0] bg-white">
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left">
            <thead>
              <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                <th className="px-4 py-3">Tier &amp; Nama Level</th>
                <th className="px-4 py-3">Syarat Kenaikan Minimal</th>
                <th className="px-4 py-3">Tarif Dasar / Sesi</th>
                <th className="px-4 py-3">Fee Platform</th>
                <th className="px-4 py-3">Tarif Mandiri</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E2E8F0] text-xs">
              {loading && sortedLevels.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-ink-muted">
                    <span className="inline-flex items-center gap-2">
                      <Loader2 className="size-4 animate-spin text-primary" aria-hidden="true" />
                      <span>Memuat daftar konfigurasi level psikolog...</span>
                    </span>
                  </td>
                </tr>
              ) : sortedLevels.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-ink-soft">
                    <p className="font-semibold text-ink">
                      Belum ada tier level psikolog tersimpan.
                    </p>
                    <p className="mt-1 text-xs text-ink-muted">
                      Tambahkan tier level pertama agar skema tarif berjenjang dan evaluasi kenaikan otomatis aktif.
                    </p>
                    <div className="mt-3 flex justify-center">
                      <button
                        type="button"
                        onClick={() => {
                          setEditingLevel(null)
                          setModalOpen(true)
                        }}
                        className="inline-flex min-h-11 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-3.5 text-xs font-semibold text-white hover:bg-primary-hover sm:h-8 sm:min-h-0"
                      >
                        <Plus className="size-3.5" aria-hidden="true" />
                        <span>Tambah Tier Level</span>
                      </button>
                    </div>
                  </td>
                </tr>
              ) : (
                sortedLevels.map((lvl) => (
                  <tr key={lvl.id} className="hover:bg-[#F8FAFC]">
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-2.5">
                        <span
                          aria-hidden="true"
                          className="flex size-8 shrink-0 items-center justify-center rounded-[8px] bg-[#EEF0FF] text-primary"
                        >
                          {renderLevelIcon(lvl.badgeIcon)}
                        </span>
                        <div>
                          <p className="font-bold text-ink">
                            Tier {lvl.levelTier}: {lvl.name}
                          </p>
                          <p className="font-mono text-[10px] text-ink-muted">{lvl.badgeIcon}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3.5 text-[11px] text-ink-soft">
                      <p>
                        <strong className="text-ink">{lvl.minCompletedSessions}</strong> sesi selesai |{' '}
                        <strong className="text-ink">{lvl.minConsultationHours}</strong> jam terbang
                      </p>
                      <p className="mt-0.5">
                        Rating min. <strong className="text-ink">{lvl.minAverageRating}</strong> (min.{' '}
                        {lvl.minReviewCount} ulasan)
                      </p>
                    </td>
                    <td className="px-4 py-3.5">
                      <p className="font-bold text-ink">{formatCoins(lvl.defaultSessionPrice)}</p>
                      <p className="text-[11px] text-ink-muted">
                        Setara {formatIdr(lvl.defaultSessionPrice * coinRateIdr)}
                      </p>
                    </td>
                    <td className="px-4 py-3.5">
                      <span className="inline-flex whitespace-nowrap rounded-[6px] bg-[#EEF0FF] px-2 py-0.5 text-[11px] font-bold text-primary">
                        {lvl.platformFeePercentage}% Platform
                      </span>
                      <p className="mt-0.5 text-[11px] text-ink-muted">
                        Psikolog {Math.round((100 - lvl.platformFeePercentage) * 100) / 100}%
                      </p>
                    </td>
                    <td className="px-4 py-3.5 text-[11px]">
                      {lvl.allowCustomPrice ? (
                        <div>
                          <span className="font-semibold text-[#166534]">Diizinkan</span>
                          <p className="text-ink-muted">
                            {formatCoins(lvl.minCustomPrice ?? lvl.defaultSessionPrice)} -{' '}
                            {formatCoins(lvl.maxCustomPrice ?? lvl.defaultSessionPrice)}
                          </p>
                        </div>
                      ) : (
                        <span className="text-ink-muted">Mengikuti tarif dasar</span>
                      )}
                    </td>
                    <td className="px-4 py-3.5">
                      <button
                        type="button"
                        aria-pressed={lvl.isActive}
                        onClick={() =>
                          void togglePsychologistLevelActive(lvl.id)
                            .then((updated) =>
                              onFeedback(
                                `Tier #${updated.levelTier} "${updated.name}" ${updated.isActive ? 'diaktifkan' : 'dinonaktifkan'}.`,
                              ),
                            )
                            .catch((err) =>
                              setErrorMsg(
                                err instanceof Error
                                  ? err.message
                                  : 'Gagal mengubah status aktif tier level.',
                              ),
                            )
                        }
                        className={cn(
                          'inline-flex min-h-11 cursor-pointer items-center gap-1 rounded-[6px] border px-2.5 py-1 text-[11px] font-semibold sm:min-h-8',
                          lvl.isActive
                            ? 'border-[#166534]/40 bg-[#F0FDF4] text-[#166534]'
                            : 'border-[#768396] bg-[#F8FAFC] text-ink-soft',
                        )}
                      >
                        {lvl.isActive ? (
                          <CheckCircle2 className="size-3" aria-hidden="true" />
                        ) : (
                          <XCircle className="size-3" aria-hidden="true" />
                        )}
                        <span>{lvl.isActive ? 'Aktif' : 'Nonaktif'}</span>
                      </button>
                    </td>
                    <td className="px-4 py-3.5 text-right">
                      <div className="inline-flex items-center justify-end gap-1.5">
                        <button
                          type="button"
                          onClick={() => {
                            setEditingLevel(lvl)
                            setModalOpen(true)
                          }}
                          aria-label={`Edit tier ${lvl.name}`}
                          className="inline-flex min-h-11 min-w-11 cursor-pointer items-center justify-center rounded-[6px] border border-[#768396] bg-white text-ink-soft hover:bg-[#F8FAFC] hover:text-ink sm:size-8 sm:min-h-0 sm:min-w-0"
                        >
                          <Pencil className="size-3.5" aria-hidden="true" />
                        </button>
                        <button
                          type="button"
                          onClick={() => setDeletingLevel(lvl)}
                          aria-label={`Hapus tier ${lvl.name}`}
                          className="inline-flex min-h-11 min-w-11 cursor-pointer items-center justify-center rounded-[6px] border border-[#B91C1C]/40 bg-[#FEF2F2] text-[#B91C1C] hover:bg-[#FEE2E2] sm:size-8 sm:min-h-0 sm:min-w-0"
                        >
                          <Trash2 className="size-3.5" aria-hidden="true" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      <LevelFormModal
        key={modalOpen ? (editingLevel?.id ?? `new-${nextSuggestedTier}`) : 'closed'}
        isOpen={modalOpen}
        editingLevel={editingLevel}
        nextSuggestedTier={nextSuggestedTier}
        basePricePerCoinIdr={coinRateIdr}
        onClose={() => {
          setModalOpen(false)
          setEditingLevel(null)
        }}
        onSave={handleSaveLevel}
      />

      {deletingLevel && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label={`Konfirmasi Hapus Tier ${deletingLevel.name}`}
          onClick={() => setDeletingLevel(null)}
          className="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 p-4"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-md rounded-[14px] border border-[#E2E8F0] bg-white p-5 text-xs shadow-2xl"
          >
            <h3 className="text-sm font-bold text-[#B91C1C]">
              Hapus Tier #{deletingLevel.levelTier}: {deletingLevel.name}?
            </h3>
            <p className="mt-1.5 text-ink-muted">
              Jika tier sedang dipakai psikolog aktif, sistem akan menonaktifkannya secara aman agar riwayat level psikolog tidak rusak.
            </p>
            <div className="mt-4 flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setDeletingLevel(null)}
                className="inline-flex min-h-11 cursor-pointer items-center rounded-[6px] border border-[#768396] px-3 font-semibold text-ink hover:bg-[#F8FAFC] sm:h-8 sm:min-h-0"
              >
                Batal
              </button>
              <button
                type="button"
                disabled={deletingSubmitting}
                onClick={() => void handleConfirmDelete()}
                className="inline-flex min-h-11 cursor-pointer items-center gap-1 rounded-[6px] bg-[#B91C1C] px-3 font-semibold text-white hover:bg-[#991B1B] disabled:cursor-not-allowed disabled:opacity-60 sm:h-8 sm:min-h-0"
              >
                {deletingSubmitting && <Loader2 className="size-3 animate-spin" aria-hidden="true" />}
                <span>Ya, Hapus Tier</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
