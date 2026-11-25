import { useCallback, useEffect, useRef, useState } from 'react'
import { Image as ImageIcon, Loader2, Search, Star, Trash2, X } from 'lucide-react'
import { TablePagination } from '@/components/portal/TablePagination'
import { AdminActionConfirmModal } from '@/components/portal/admin/AdminActionConfirmModal'
import {
  deleteAdminBoothFeedback,
  fetchAdminBoothFeedbackPhotoUrl,
  fetchAdminBoothFeedbacks,
} from '@/lib/portalStore'
import type { BoothFeedbackEntry, BoothFeedbackSummary } from '@/types/portal'

interface BoothFeedbackAdminTabProps {
  onFeedback: (message: string) => void
}

export function BoothFeedbackAdminTab({ onFeedback }: BoothFeedbackAdminTabProps) {
  const [summary, setSummary] = useState<BoothFeedbackSummary>({
    totalCount: 0,
    averageRating: 0,
    ratingCounts: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
  })
  const [items, setItems] = useState<BoothFeedbackEntry[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [ratingFilter, setRatingFilter] = useState<string>('all')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [errorText, setErrorText] = useState<string | null>(null)

  const [photoUrls, setPhotoUrls] = useState<Record<string, string>>({})
  const objectUrlsRef = useRef<string[]>([])
  const [lightboxPhoto, setLightboxPhoto] = useState<{
    url: string
    caption: string
  } | null>(null)
  const [pendingDelete, setPendingDelete] = useState<BoothFeedbackEntry | null>(null)
  const [deleting, setDeleting] = useState(false)
  const [reloadNonce, setReloadNonce] = useState(0)

  const applyBoothResponse = useCallback(
    async (
      res: Awaited<ReturnType<typeof fetchAdminBoothFeedbacks>>,
      isActive: () => boolean,
    ) => {
      if (!isActive()) return
      setSummary(res.summary)
      setItems(res.items)
      setTotal(res.total)

      const pairs: Array<{ feedbackId: string; photoId: string }> = []
      for (const entry of res.items) {
        for (const photo of entry.photos) {
          pairs.push({ feedbackId: entry.id, photoId: photo.id })
        }
      }
      const nextMap: Record<string, string> = {}
      const createdObjectUrls: string[] = []
      await Promise.all(
        pairs.map(async ({ feedbackId, photoId }) => {
          try {
            const url = await fetchAdminBoothFeedbackPhotoUrl(feedbackId, photoId)
            nextMap[photoId] = url
            if (url.startsWith('blob:')) createdObjectUrls.push(url)
          } catch {
            // Skip failed photo thumbnail cleanly
          }
        }),
      )
      if (!isActive()) {
        createdObjectUrls.forEach((u) => URL.revokeObjectURL(u))
        return
      }
      objectUrlsRef.current.forEach((u) => URL.revokeObjectURL(u))
      objectUrlsRef.current = createdObjectUrls
      setPhotoUrls(nextMap)
    },
    [],
  )

  useEffect(() => {
    let active = true
    fetchAdminBoothFeedbacks({
      rating: ratingFilter === 'all' ? undefined : Number(ratingFilter),
      search: search.trim() || undefined,
      page,
      pageSize,
    })
      .then((res) => {
        if (active) setErrorText(null)
        return applyBoothResponse(res, () => active)
      })
      .catch((err) => {
        if (active) {
          setErrorText(
            err instanceof Error ? err.message : 'Gagal memuat feedback pengunjung booth.',
          )
        }
      })
      .finally(() => {
        if (active) setLoading(false)
      })

    return () => {
      active = false
    }
  }, [ratingFilter, search, page, pageSize, reloadNonce, applyBoothResponse])

  useEffect(() => {
    return () => {
      objectUrlsRef.current.forEach((u) => URL.revokeObjectURL(u))
    }
  }, [])

  useEffect(() => {
    if (!lightboxPhoto) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setLightboxPhoto(null)
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [lightboxPhoto])

  const handleConfirmDelete = async () => {
    if (!pendingDelete || deleting) return
    setDeleting(true)
    try {
      await deleteAdminBoothFeedback(pendingDelete.id)
      onFeedback('Feedback booth pengunjung berhasil dihapus.')
      setPendingDelete(null)
      setLoading(true)
      setReloadNonce((n) => n + 1)
    } catch (err) {
      setErrorText(err instanceof Error ? err.message : 'Gagal menghapus feedback booth.')
    } finally {
      setDeleting(false)
    }
  }

  return (
    <div className="space-y-5">
      {/* Summary KPI Cards */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <p className="text-xs font-semibold text-ink-muted">Total Feedback Booth</p>
          <p className="mt-1 text-2xl font-bold text-ink">{summary.totalCount}</p>
        </div>
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <p className="text-xs font-semibold text-ink-muted">Rata-Rata Rating Booth</p>
          <p className="mt-1 inline-flex items-center gap-1.5 text-2xl font-bold text-ink">
            <Star className="size-5 fill-[#D97706] text-[#B45309]" aria-hidden="true" />
            <span>{summary.totalCount > 0 ? summary.averageRating.toFixed(2) : '0.00'}</span>
            <span className="text-xs font-normal text-ink-muted">/ 5</span>
          </p>
        </div>
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <p className="text-xs font-semibold text-ink-muted">Distribusi Skor (5★ / 4★ / ≤3★)</p>
          <p className="mt-1.5 text-sm font-bold text-ink">
            {summary.ratingCounts[5] ?? 0} / {summary.ratingCounts[4] ?? 0} /{' '}
            {(summary.ratingCounts[3] ?? 0) +
              (summary.ratingCounts[2] ?? 0) +
              (summary.ratingCounts[1] ?? 0)}
          </p>
        </div>
      </div>

      {/* Filters & List */}
      <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-xs font-bold text-ink">Daftar Ulasan &amp; Foto Pengunjung Booth</p>

          <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
            <select
              aria-label="Filter berdasarkan rating"
              value={ratingFilter}
              onChange={(e) => {
                setLoading(true)
                setRatingFilter(e.target.value)
                setPage(1)
              }}
              className="h-9 rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs font-medium text-ink focus:border-primary focus:outline-none"
            >
              <option value="all">Semua Rating</option>
              <option value="5">5 Bintang</option>
              <option value="4">4 Bintang</option>
              <option value="3">3 Bintang</option>
              <option value="2">2 Bintang</option>
              <option value="1">1 Bintang</option>
            </select>
            <div className="relative w-full sm:w-64">
              <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
              <input
                type="search"
                value={search}
                onChange={(e) => {
                  setLoading(true)
                  setSearch(e.target.value)
                  setPage(1)
                }}
                placeholder="Cari pesan atau nama..."
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink focus:border-primary focus:bg-white focus:outline-none"
              />
            </div>
          </div>
        </div>

        {errorText && (
          <div className="mt-3 rounded-[10px] border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-xs font-medium text-[#991B1B]">
            {errorText}
          </div>
        )}

        <div className="mt-4 space-y-3">
          {loading ? (
            <div className="flex items-center justify-center gap-2 py-10 text-xs text-ink-muted">
              <Loader2 className="size-4 animate-spin text-primary" />
              <span>Memuat feedback pengunjung booth...</span>
            </div>
          ) : items.length === 0 ? (
            <div className="rounded-[10px] border border-dashed border-[#CBD5E1] py-10 text-center text-xs">
              <p className="font-semibold text-ink">
                {search.trim() || ratingFilter !== 'all'
                  ? 'Tidak ada feedback booth yang sesuai filter.'
                  : 'Belum ada feedback pengunjung booth yang masuk.'}
              </p>
              {(search.trim() || ratingFilter !== 'all') && (
                <button
                  type="button"
                  onClick={() => {
                    setLoading(true)
                    setSearch('')
                    setRatingFilter('all')
                    setPage(1)
                  }}
                  className="mt-2 inline-flex min-h-9 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink hover:bg-[#F8FAFC]"
                >
                  Reset Filter
                </button>
              )}
            </div>
          ) : (
            items.map((item) => (
              <article
                key={item.id}
                className="rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC]/60 p-4"
              >
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="inline-flex items-center gap-1 rounded-[6px] border border-[#FDE68A] bg-[#FFFBEB] px-2 py-0.5 text-xs font-bold text-[#92400E]">
                        <Star className="size-3.5 fill-[#D97706] text-[#B45309]" aria-hidden="true" />
                        {item.rating}/5
                      </span>
                      <span className="text-xs font-semibold text-ink">
                        {item.visitorName || 'Pengunjung Anonim'}
                      </span>
                      {item.visitorContact && (
                        <span className="text-xs text-ink-muted">({item.visitorContact})</span>
                      )}
                    </div>
                    <p className="mt-1 text-[11px] text-ink-muted">
                      {new Date(item.createdAt).toLocaleString('id-ID')} · {item.eventLabel}
                    </p>
                  </div>

                  <button
                    type="button"
                    onClick={() => setPendingDelete(item)}
                    aria-label="Hapus feedback booth"
                    className="inline-flex min-h-9 cursor-pointer items-center gap-1 rounded-[8px] border border-[#FECACA] bg-[#FEF2F2] px-2.5 text-xs font-semibold text-[#991B1B] hover:bg-[#FEE2E2]"
                  >
                    <Trash2 className="size-3.5" aria-hidden="true" />
                    <span>Hapus</span>
                  </button>
                </div>

                <p className="mt-2.5 whitespace-pre-wrap text-xs leading-relaxed text-ink">
                  {item.message}
                </p>

                {item.photos.length > 0 && (
                  <div className="mt-3 flex flex-wrap gap-2">
                    {item.photos.map((photo, idx) => {
                      const src = photoUrls[photo.id]
                      return (
                        <button
                          key={photo.id}
                          type="button"
                          disabled={!src}
                          onClick={() =>
                            src &&
                            setLightboxPhoto({
                              url: src,
                              caption: `${item.visitorName || 'Pengunjung'} · Rating ${item.rating}/5 (Foto #${idx + 1})`,
                            })
                          }
                          aria-label={`Lihat foto booth #${idx + 1}`}
                          className="relative size-20 cursor-pointer overflow-hidden rounded-[10px] border border-[#CBD5E1] bg-white focus-visible:outline-2 focus-visible:outline-primary disabled:cursor-default"
                        >
                          {src ? (
                            <img
                              src={src}
                              alt={`Selfie booth ${idx + 1}`}
                              width={80}
                              height={80}
                              className="size-full object-cover"
                            />
                          ) : (
                            <span className="flex size-full items-center justify-center text-ink-muted">
                              <ImageIcon className="size-4" aria-hidden="true" />
                            </span>
                          )}
                        </button>
                      )
                    })}
                  </div>
                )}
              </article>
            ))
          )}
        </div>

        <TablePagination
          currentPage={page}
          totalItems={total}
          pageSize={pageSize}
          pageSizeOptions={[5, 10, 25]}
          itemLabel="feedback"
          ariaLabel="Paginasi feedback booth"
          onPageChange={(p) => {
            setLoading(true)
            setPage(p)
          }}
          onPageSizeChange={(size) => {
            setLoading(true)
            setPageSize(size)
            setPage(1)
          }}
        />
      </div>

      {/* Photo Lightbox Modal */}
      {lightboxPhoto && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
          role="dialog"
          aria-modal="true"
          aria-label="Pratinjau foto booth"
          onClick={() => setLightboxPhoto(null)}
        >
          <div
            className="relative w-full max-w-xl overflow-hidden rounded-[18px] bg-white shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between border-b border-[#E2E8F0] px-4 py-3">
              <p className="text-xs font-semibold text-ink">{lightboxPhoto.caption}</p>
              <button
                type="button"
                onClick={() => setLightboxPhoto(null)}
                aria-label="Tutup pratinjau foto"
                className="inline-flex size-9 cursor-pointer items-center justify-center rounded-full border border-[#CBD5E1] text-ink hover:bg-canvas"
              >
                <X className="size-4" aria-hidden="true" />
              </button>
            </div>
            <div className="bg-[#0C0A14]">
              <img
                src={lightboxPhoto.url}
                alt={lightboxPhoto.caption}
                className="mx-auto max-h-[75vh] w-auto object-contain"
              />
            </div>
          </div>
        </div>
      )}

      <AdminActionConfirmModal
        isOpen={Boolean(pendingDelete)}
        title="Hapus Feedback Pengunjung Booth?"
        description="Entri feedback beserta seluruh berkas foto selfie yang terlampir akan dihapus permanen dari sistem."
        impactSummary={
          pendingDelete
            ? `Pengunjung: ${pendingDelete.visitorName || 'Anonim'} (${pendingDelete.rating}/5), ${pendingDelete.photos.length} foto akan dihapus dari server.`
            : undefined
        }
        confirmLabel="Hapus Permanen"
        tone="danger"
        onClose={() => !deleting && setPendingDelete(null)}
        onConfirm={() => handleConfirmDelete()}
      />
    </div>
  )
}
