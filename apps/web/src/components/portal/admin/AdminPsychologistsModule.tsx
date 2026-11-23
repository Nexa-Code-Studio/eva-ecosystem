import { AlertCircle, Loader2, RefreshCw, Search } from 'lucide-react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router'
import { PsychologistDetailModal } from './psychologists/PsychologistDetailModal'
import {
  PsychologistKpiCards,
  type PsyFilterTab,
  type PsychologistKpiCounts,
} from './psychologists/PsychologistKpiCards'
import { PsychologistTable } from './psychologists/PsychologistTable'
import {
  MobilePsychologistSimulatorModal,
  MobilePsychologistSimulatorTrigger,
} from '@/components/devtools/PortalDevTools'
import { TablePagination } from '@/components/portal/TablePagination'
import { cn } from '@/lib/cn'
import {
  fetchAdminPsychologists,
  reviewPsychologistVerification,
  type Psychologist,
} from '@/lib/portalStore'

const DEFAULT_PAGE_SIZE = 10
const PAGE_SIZE_OPTIONS = [5, 10, 25, 50]

interface AdminPsychologistsModuleProps {
  psychologists: Psychologist[]
  onFeedback: (msg: string) => void
}

export function AdminPsychologistsModule({
  psychologists,
  onFeedback,
}: AdminPsychologistsModuleProps) {
  const [searchParams, setSearchParams] = useSearchParams()
  const filterParam = searchParams.get('filter') as PsyFilterTab | null
  const validFilters: PsyFilterTab[] = [
    'pending_review',
    'all',
    'verified',
    'rejected',
  ]
  const activeFilter: PsyFilterTab =
    filterParam && validFilters.includes(filterParam) ? filterParam : 'all'

  const rawPage = Number.parseInt(searchParams.get('page') ?? '1', 10)
  const requestedPage = Number.isFinite(rawPage) && rawPage > 0 ? rawPage : 1

  const [search, setSearch] = useState('')
  const [pageSize, setPageSize] = useState(DEFAULT_PAGE_SIZE)
  const [selectedPsyId, setSelectedPsyId] = useState<string | null>(null)
  const [isDetailModalOpen, setIsDetailModalOpen] = useState(false)
  const [isSimModalOpen, setIsSimModalOpen] = useState(false)
  const [isLoadingList, setIsLoadingList] = useState(() => psychologists.length === 0)
  const [loadError, setLoadError] = useState<string | null>(null)
  const tableTopRef = useRef<HTMLDivElement | null>(null)

  const setActiveFilter = (filter: PsyFilterTab) => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      if (filter === 'all') {
        next.delete('filter')
      } else {
        next.set('filter', filter)
      }
      next.delete('page')
      return next
    })
  }

  const updatePageParam = (nextPage: number) => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      if (nextPage <= 1) {
        next.delete('page')
      } else {
        next.set('page', String(nextPage))
      }
      return next
    })
  }

  const handleSearchChange = (value: string) => {
    setSearch(value)
    if (searchParams.has('page')) {
      updatePageParam(1)
    }
  }

  const handlePageSizeChange = (nextSize: number) => {
    setPageSize(nextSize)
    if (searchParams.has('page')) {
      updatePageParam(1)
    }
  }

  const handleResetFilters = () => {
    setSearch('')
    setActiveFilter('all')
  }

  const handleRetryLoad = useCallback(() => {
    setIsLoadingList(true)
    setLoadError(null)
    void fetchAdminPsychologists()
      .catch((err: unknown) => {
        setLoadError(
          err instanceof Error
            ? err.message
            : 'Gagal memuat daftar psikolog dari server.',
        )
      })
      .finally(() => {
        setIsLoadingList(false)
      })
  }, [])

  useEffect(() => {
    let active = true
    fetchAdminPsychologists()
      .then(() => {
        if (active) setLoadError(null)
      })
      .catch((err: unknown) => {
        if (active) {
          setLoadError(
            err instanceof Error
              ? err.message
              : 'Gagal memuat daftar psikolog dari server.',
          )
        }
      })
      .finally(() => {
        if (active) setIsLoadingList(false)
      })
    return () => {
      active = false
    }
  }, [])

  const counts: PsychologistKpiCounts = useMemo(() => {
    const pending = psychologists.filter((p) => p.verificationStatus === 'pending').length
    const verified = psychologists.filter((p) => p.verificationStatus === 'verified').length
    const rejected = psychologists.filter(
      (p) => p.verificationStatus === 'rejected' || p.verificationStatus === 'suspended',
    ).length

    return {
      total: psychologists.length,
      pending,
      verified,
      rejected,
      pendingReview: pending,
    }
  }, [psychologists])

  const filteredPsychologists = useMemo(() => {
    const q = search.trim().toLowerCase()
    return psychologists.filter((p) => {
      if (
        activeFilter === 'pending_review' &&
        p.verificationStatus !== 'pending'
      ) {
        return false
      }
      if (activeFilter === 'verified' && p.verificationStatus !== 'verified') return false
      if (
        activeFilter === 'rejected' &&
        p.verificationStatus !== 'rejected' &&
        p.verificationStatus !== 'suspended'
      ) {
        return false
      }

      if (!q) return true
      return (
        p.fullName.toLowerCase().includes(q) ||
        p.email.toLowerCase().includes(q) ||
        p.strNumber.toLowerCase().includes(q) ||
        (p.sipNumber?.toLowerCase().includes(q) ?? false) ||
        p.association.toLowerCase().includes(q) ||
        p.specializations.some((s) => s.toLowerCase().includes(q))
      )
    })
  }, [psychologists, activeFilter, search])

  const totalPages = Math.max(1, Math.ceil(filteredPsychologists.length / pageSize))
  const safePage = Math.min(requestedPage, totalPages)

  const paginatedPsychologists = useMemo(() => {
    const startIndex = (safePage - 1) * pageSize
    return filteredPsychologists.slice(startIndex, startIndex + pageSize)
  }, [filteredPsychologists, safePage, pageSize])

  const handlePageChange = (nextPage: number) => {
    const clampedPage = Math.min(Math.max(1, nextPage), totalPages)
    updatePageParam(clampedPage)
    const prefersReducedMotion =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches
    tableTopRef.current?.scrollIntoView({
      behavior: prefersReducedMotion ? 'auto' : 'smooth',
      block: 'nearest',
    })
  }

  const selectedPsy = useMemo(() => {
    if (!selectedPsyId) return null
    return psychologists.find((p) => p.id === selectedPsyId) ?? null
  }, [psychologists, selectedPsyId])

  const handleOpenDetail = (psy: Psychologist) => {
    setSelectedPsyId(psy.id)
    setIsDetailModalOpen(true)
  }

  const handleApprove = async (psyId: string, fullName: string, notes?: string) => {
    await reviewPsychologistVerification(psyId, {
      status: 'verified',
      notes: notes || 'Kredensial STR/SIP lengkap dan diverifikasi Admin.',
    })
    onFeedback(
      `Kredensial "${fullName}" berhasil disetujui. Akun otomatis aktif di aplikasi Eva Counselor Mobile.`,
    )
  }

  const filterTabs: Array<{ id: PsyFilterTab; label: string }> = [
    { id: 'pending_review', label: `Antrean (${counts.pendingReview})` },
    { id: 'all', label: `Semua (${counts.total})` },
    { id: 'verified', label: `Terverifikasi (${counts.verified})` },
    { id: 'rejected', label: `Ditolak (${counts.rejected})` },
  ]

  return (
    <div className="flex flex-col gap-4 sm:gap-5">
      <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Verifikasi Psikolog Profesional Mandiri
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Tinjau kredensial STR/SIP psikolog individu yang mendaftar melalui Eva Counselor Mobile.
          </p>
        </div>
        <MobilePsychologistSimulatorTrigger onOpen={() => setIsSimModalOpen(true)} />
      </div>

      <PsychologistKpiCards
        counts={counts}
        activeFilter={activeFilter}
        onSelectFilter={setActiveFilter}
      />

      <div
        ref={tableTopRef}
        className="flex flex-col gap-3 rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 sm:flex-row sm:items-center sm:justify-between"
      >
        <div className="relative flex-1">
          <Search
            className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted"
            aria-hidden="true"
          />
          <label htmlFor="psy-search-input" className="sr-only">
            Cari psikolog
          </label>
          <input
            id="psy-search-input"
            type="search"
            value={search}
            onChange={(e) => handleSearchChange(e.target.value)}
            placeholder="Cari nama, email, nomor STR, SIP/SIPP, organisasi profesi, atau fokus klinis..."
            className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink placeholder:text-ink-muted/70 focus:border-primary focus:bg-white focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
          />
        </div>

        <div className="block sm:hidden">
          <label htmlFor="mobile-psy-filter" className="sr-only">
            Filter Status Verifikasi Psikolog
          </label>
          <select
            id="mobile-psy-filter"
            value={activeFilter}
            onChange={(e) => setActiveFilter(e.target.value as PsyFilterTab)}
            className="min-h-11 w-full cursor-pointer rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] px-3 text-xs font-semibold text-ink focus:border-primary focus:bg-white focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
          >
            {filterTabs.map((tab) => (
              <option key={tab.id} value={tab.id}>
                {tab.label}
              </option>
            ))}
          </select>
        </div>

        <div className="hidden shrink-0 flex-wrap gap-1 rounded-[8px] bg-[#F1F5F9] p-1 sm:flex">
          {filterTabs.map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveFilter(tab.id)}
              className={cn(
                'cursor-pointer rounded-[6px] px-2.5 py-1 text-xs font-semibold whitespace-nowrap transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary',
                activeFilter === tab.id
                  ? 'bg-white text-ink shadow-2xs'
                  : 'text-ink-muted hover:text-ink',
              )}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {loadError && (
        <div
          role="alert"
          className="flex flex-col justify-between gap-2 rounded-[12px] border border-[#FECACA] bg-[#FEF2F2] px-4 py-3 text-xs text-[#991B1B] sm:flex-row sm:items-center"
        >
          <div className="flex items-center gap-2">
            <AlertCircle className="size-4 shrink-0" aria-hidden="true" />
            <span>{loadError}</span>
          </div>
          <button
            type="button"
            onClick={handleRetryLoad}
            className="inline-flex min-h-11 cursor-pointer items-center justify-center gap-1.5 rounded-[8px] border border-[#FECACA] bg-white px-3 text-xs font-semibold text-[#991B1B] transition-colors hover:bg-[#FEE2E2] sm:min-h-8"
          >
            <RefreshCw className="size-3.5" aria-hidden="true" />
            <span>Muat Ulang</span>
          </button>
        </div>
      )}

      {isLoadingList && psychologists.length === 0 ? (
        <div
          role="status"
          aria-live="polite"
          className="flex items-center justify-center gap-2 rounded-[12px] border border-[#E2E8F0] bg-white px-4 py-12 text-xs font-semibold text-ink-soft"
        >
          <Loader2 className="size-4 animate-spin text-primary" aria-hidden="true" />
          <span>Memuat daftar kredensial psikolog...</span>
        </div>
      ) : (
        <>
          <PsychologistTable
            psychologists={paginatedPsychologists}
            onSelectPsychologist={handleOpenDetail}
            hasActiveFilter={activeFilter !== 'all' || search.trim().length > 0}
            onResetFilters={handleResetFilters}
          />

          <TablePagination
            currentPage={safePage}
            totalItems={filteredPsychologists.length}
            pageSize={pageSize}
            pageSizeOptions={PAGE_SIZE_OPTIONS}
            itemLabel="psikolog"
            ariaLabel="Paginasi daftar psikolog"
            onPageChange={handlePageChange}
            onPageSizeChange={handlePageSizeChange}
          />
        </>
      )}

      <PsychologistDetailModal
        key={selectedPsy?.id ?? 'empty'}
        isOpen={isDetailModalOpen}
        psy={selectedPsy}
        onClose={() => {
          setIsDetailModalOpen(false)
          setSelectedPsyId(null)
        }}
        onApprove={handleApprove}
        onFeedback={onFeedback}
      />

      <MobilePsychologistSimulatorModal
        isOpen={isSimModalOpen}
        onClose={() => setIsSimModalOpen(false)}
        onCreated={(created) => {
          setIsSimModalOpen(false)
          onFeedback(
            `Simulasi pendaftaran psikolog "${created.fullName}" berhasil masuk ke antrean verifikasi.`,
          )
        }}
      />
    </div>
  )
}
