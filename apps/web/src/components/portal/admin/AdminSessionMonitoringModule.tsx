import {
  AlertCircle,
  Calendar,
  Clock,
  Eye,
  Loader2,
  RefreshCw,
  Search,
  Sparkles,
  Video,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { SessionDurationBadge } from '@/components/portal/PortalBadges'
import { TablePagination } from '@/components/portal/TablePagination'
import { useUrlPagination } from '@/hooks/useUrlPagination'
import { cn } from '@/lib/cn'
import { fetchConsultationSessions } from '@/lib/portalStore'
import type {
  ConsultationSessionMonitoring,
  ConsultationSessionStatus,
} from '@/types/portal'

interface AdminSessionMonitoringModuleProps {
  sessions: ConsultationSessionMonitoring[]
}

type StatusFilter = 'all' | ConsultationSessionStatus
type DurationFilter = 'all' | '30' | '60'

function formatSessionDateTime(iso: string): string {
  try {
    const dt = new Date(iso)
    return dt.toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return iso
  }
}

function formatCoins(value: number): string {
  return `${Math.round(value).toLocaleString('id-ID')} Koin`
}

function getSessionStatusBadge(status: ConsultationSessionStatus): {
  label: string
  className: string
} {
  switch (status) {
    case 'scheduled':
      return { label: 'Terjadwal', className: 'border-[#C7D2FE] bg-[#EEF0FF] text-primary' }
    case 'waiting':
      return { label: 'Menunggu Room', className: 'border-[#FDE68A] bg-[#FEF3C7] text-[#92400E]' }
    case 'in_progress':
      return { label: 'Berlangsung', className: 'border-[#BBF7D0] bg-[#F0FDF4] text-[#166534]' }
    case 'extended':
      return { label: 'Berlangsung (+30m)', className: 'border-indigo-300 bg-indigo-50 text-indigo-800' }
    case 'completed':
      return { label: 'Selesai', className: 'border-[#CBD5E1] bg-[#F1F5F9] text-ink-soft' }
    case 'cancelled':
      return { label: 'Dibatalkan', className: 'border-[#FECACA] bg-[#FEF2F2] text-[#991B1B]' }
    case 'expired':
      return { label: 'Kedaluwarsa', className: 'border-[#E2E8F0] bg-[#F8FAFC] text-ink-muted' }
  }
}

export function AdminSessionMonitoringModule({
  sessions,
}: AdminSessionMonitoringModuleProps) {
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all')
  const [durationFilter, setDurationFilter] = useState<DurationFilter>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [isLoading, setIsLoading] = useState(() => sessions.length === 0)
  const [loadError, setLoadError] = useState<string | null>(null)
  const listTopRef = useRef<HTMLDivElement>(null)

  const handleRetryLoad = useCallback(() => {
    setIsLoading(true)
    setLoadError(null)
    void fetchConsultationSessions()
      .catch((err: unknown) => {
        setLoadError(
          err instanceof Error ? err.message : 'Gagal memuat daftar sesi konsultasi.',
        )
      })
      .finally(() => {
        setIsLoading(false)
      })
  }, [])

  useEffect(() => {
    let active = true
    fetchConsultationSessions()
      .then(() => {
        if (active) setLoadError(null)
      })
      .catch((err: unknown) => {
        if (active) {
          setLoadError(
            err instanceof Error ? err.message : 'Gagal memuat daftar sesi konsultasi.',
          )
        }
      })
      .finally(() => {
        if (active) setIsLoading(false)
      })
    return () => {
      active = false
    }
  }, [])

  const counts = useMemo(() => {
    const extendedCount = sessions.filter((s) => s.isExtended || s.durationMinutes === 60).length
    const activeCount = sessions.filter(
      (s) => s.status === 'in_progress' || s.status === 'extended' || s.status === 'waiting',
    ).length
    const scheduledCount = sessions.filter((s) => s.status === 'scheduled').length
    const completedCount = sessions.filter((s) => s.status === 'completed').length

    return {
      all: sessions.length,
      extendedCount,
      activeCount,
      scheduledCount,
      completedCount,
    }
  }, [sessions])

  const filteredSessions = useMemo(() => {
    const q = searchQuery.trim().toLowerCase()
    return sessions.filter((sess) => {
      if (statusFilter !== 'all' && sess.status !== statusFilter) return false
      if (durationFilter === '30' && (sess.isExtended || sess.durationMinutes !== 30)) {
        return false
      }
      if (durationFilter === '60' && !sess.isExtended && sess.durationMinutes !== 60) {
        return false
      }
      if (!q) return true

      return (
        sess.sessionCode.toLowerCase().includes(q) ||
        sess.patientCode.toLowerCase().includes(q) ||
        sess.patientDisplayName.toLowerCase().includes(q) ||
        sess.counselorName.toLowerCase().includes(q)
      )
    })
  }, [sessions, statusFilter, durationFilter, searchQuery])

  const {
    pageSize,
    safePage,
    paginatedItems: paginatedSessions,
    resetPage,
    handlePageChange,
    handlePageSizeChange,
  } = useUrlPagination(filteredSessions, {
    defaultPageSize: 10,
    scrollTargetRef: listTopRef,
  })

  const hasActiveFilter =
    statusFilter !== 'all' || durationFilter !== 'all' || searchQuery.trim().length > 0

  const handleSearchChange = (value: string) => {
    setSearchQuery(value)
    resetPage()
  }

  const handleDurationChange = (next: DurationFilter) => {
    setDurationFilter(next)
    resetPage()
  }

  const handleStatusChange = (next: StatusFilter) => {
    setStatusFilter(next)
    resetPage()
  }

  const handleResetFilters = () => {
    setSearchQuery('')
    setDurationFilter('all')
    setStatusFilter('all')
    resetPage()
  }

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Monitoring Jadwal &amp; Sesi Online
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Pemantauan read-only seluruh sesi telekonsultasi 30 menit dan perpanjangan in-call 60 menit dari aplikasi mobile.
          </p>
        </div>
        <span className="inline-flex shrink-0 items-center gap-1.5 rounded-[8px] border border-[#E2E8F0] bg-white px-3 py-1.5 text-xs font-semibold text-ink-soft">
          <Eye className="size-3.5 text-primary" />
          <span>Mode Read-Only · 100% Telekonsultasi Video</span>
        </span>
      </div>

      {/* Ringkasan KPI Monitoring */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <span className="text-[11px] font-semibold text-ink-muted">Total Sesi Terpantau</span>
          <p className="mt-1.5 text-2xl font-bold text-ink">{counts.all}</p>
        </div>
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <span className="text-[11px] font-semibold text-ink-muted">Sedang Berlangsung</span>
          <p className="mt-1.5 text-2xl font-bold text-emerald-700">{counts.activeCount}</p>
        </div>
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <span className="text-[11px] font-semibold text-ink-muted">Terjadwal</span>
          <p className="mt-1.5 text-2xl font-bold text-primary">{counts.scheduledCount}</p>
        </div>
        <div className="rounded-[12px] border border-[#C7D2FE] bg-[#EEF0FF]/40 p-4">
          <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-primary">
            <Sparkles className="size-3" /> Diperpanjang (60 Menit)
          </span>
          <p className="mt-1.5 text-2xl font-bold text-primary">{counts.extendedCount}</p>
        </div>
      </div>

      {/* Filter Controls */}
      <div
        ref={listTopRef}
        className="flex flex-col gap-3 rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 lg:flex-row lg:items-center lg:justify-between"
      >
        <div className="relative flex-1">
          <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
          <input
            type="search"
            value={searchQuery}
            onChange={(e) => handleSearchChange(e.target.value)}
            placeholder="Cari kode sesi, kode pasien, atau nama psikolog mandiri..."
            className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink placeholder:text-ink-muted/70 focus:border-primary focus:bg-white focus:outline-none"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <select
            aria-label="Filter Durasi Sesi"
            value={durationFilter}
            onChange={(e) => handleDurationChange(e.target.value as DurationFilter)}
            className="h-9 rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] px-3 text-xs font-semibold text-ink focus:border-primary focus:bg-white focus:outline-none"
          >
            <option value="all">Semua Durasi</option>
            <option value="30">Standar: 30 Menit</option>
            <option value="60">Diperpanjang: 60 Menit</option>
          </select>

          <select
            aria-label="Filter Status Sesi"
            value={statusFilter}
            onChange={(e) => handleStatusChange(e.target.value as StatusFilter)}
            className="h-9 rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] px-3 text-xs font-semibold text-ink focus:border-primary focus:bg-white focus:outline-none"
          >
            <option value="all">Semua Status ({sessions.length})</option>
            <option value="in_progress">Berlangsung</option>
            <option value="extended">Diperpanjang (+30m)</option>
            <option value="scheduled">Terjadwal</option>
            <option value="completed">Selesai</option>
            <option value="cancelled">Dibatalkan</option>
            <option value="expired">Kedaluwarsa</option>
          </select>
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
            className="inline-flex min-h-10 cursor-pointer items-center justify-center gap-1.5 rounded-[8px] border border-[#FECACA] bg-white px-3 text-xs font-semibold text-[#991B1B] hover:bg-[#FEE2E2] sm:min-h-8"
          >
            <RefreshCw className="size-3.5" aria-hidden="true" />
            <span>Muat Ulang</span>
          </button>
        </div>
      )}

      {isLoading && sessions.length === 0 ? (
        <div
          role="status"
          aria-live="polite"
          className="flex items-center justify-center gap-2 rounded-[12px] border border-[#E2E8F0] bg-white px-4 py-12 text-xs font-semibold text-ink-soft"
        >
          <Loader2 className="size-4 animate-spin text-primary" aria-hidden="true" />
          <span>Memuat jadwal dan sesi konsultasi...</span>
        </div>
      ) : (
        <>
          {/* Mobile Cards (< md) */}
          <div className="space-y-3 md:hidden">
            {paginatedSessions.length === 0 ? (
              <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-8 text-center text-xs text-ink-muted">
                <p className="font-semibold text-ink">
                  {hasActiveFilter
                    ? 'Tidak ada sesi telekonsultasi yang cocok dengan filter saat ini.'
                    : 'Belum ada sesi telekonsultasi terdaftar.'}
                </p>
                {hasActiveFilter && (
                  <button
                    type="button"
                    onClick={handleResetFilters}
                    className="mt-3 inline-flex min-h-11 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-4 text-xs font-semibold text-ink hover:bg-[#F8FAFC]"
                  >
                    Reset Filter
                  </button>
                )}
              </div>
            ) : (
              paginatedSessions.map((sess) => {
            const statusBadge = getSessionStatusBadge(sess.status)
            return (
              <div
                key={sess.id}
                className="rounded-[12px] border border-[#E2E8F0] bg-white p-4 shadow-2xs"
              >
                <div className="flex items-start justify-between gap-2 border-b border-[#E2E8F0] pb-2.5">
                  <div>
                    <p className="font-mono text-xs font-bold text-ink">{sess.sessionCode}</p>
                    <p className="mt-0.5 text-xs font-semibold text-ink">
                      {sess.patientDisplayName}{' '}
                      <span className="font-mono text-[11px] font-normal text-ink-muted">
                        ({sess.patientCode})
                      </span>
                    </p>
                  </div>
                  <span
                    className={cn(
                      'inline-flex shrink-0 rounded-[6px] border px-2 py-0.5 text-[10.5px] font-semibold',
                      statusBadge.className,
                    )}
                  >
                    {statusBadge.label}
                  </span>
                </div>

                <div className="mt-3 space-y-2 text-xs">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-ink-muted">Psikolog:</span>
                    <span className="font-semibold text-ink">
                      {sess.counselorName}, {sess.counselorTitle}
                    </span>
                  </div>

                  <div className="flex items-center justify-between gap-2">
                    <span className="text-ink-muted">Jadwal:</span>
                    <span className="text-ink-soft">
                      {formatSessionDateTime(sess.scheduledStartTime)}
                    </span>
                  </div>

                  <div className="flex items-center justify-between gap-2">
                    <span className="text-ink-muted">Durasi:</span>
                    <SessionDurationBadge
                      durationMinutes={sess.durationMinutes}
                      isExtended={sess.isExtended}
                    />
                  </div>

                  <div className="flex items-center justify-between gap-2 border-t border-[#F1F5F9] pt-2">
                    <span className="text-ink-muted">Nilai Transaksi:</span>
                    <span className="font-bold text-ink">{formatCoins(sess.totalPriceCoins)}</span>
                  </div>
                </div>
              </div>
            )
          })
        )}
      </div>

      {/* Desktop Table (>= md) */}
      <div className="hidden overflow-hidden rounded-[12px] border border-[#E2E8F0] bg-white md:block">
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left">
            <thead>
              <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                <th className="px-5 py-3.5">Sesi &amp; Pasien</th>
                <th className="px-5 py-3.5">Psikolog Mandiri</th>
                <th className="px-5 py-3.5">Jadwal Telekonsultasi</th>
                <th className="px-5 py-3.5">Durasi Sesi</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5 text-right">Nominal &amp; Split (Koin)</th>
              </tr>
            </thead>
              <tbody className="divide-y divide-[#E2E8F0] text-xs">
                {paginatedSessions.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="p-8 text-center text-ink-muted">
                      <div className="flex flex-col items-center justify-center">
                        <Clock className="size-8 text-ink-muted/50" />
                        <p className="mt-2 text-xs font-semibold text-ink">
                          {hasActiveFilter
                            ? 'Tidak ada sesi yang sesuai filter'
                            : 'Belum ada sesi telekonsultasi terdaftar'}
                        </p>
                        {hasActiveFilter && (
                          <button
                            type="button"
                            onClick={handleResetFilters}
                            className="mt-3 inline-flex min-h-9 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink hover:bg-[#F8FAFC]"
                          >
                            Reset Filter
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedSessions.map((sess) => {
                  const statusBadge = getSessionStatusBadge(sess.status)
                  return (
                    <tr key={sess.id} className="hover:bg-[#F8FAFC]">
                      <td className="px-5 py-4">
                        <p className="font-mono text-xs font-bold text-ink">{sess.sessionCode}</p>
                        <p className="mt-0.5 text-xs text-ink-soft">
                          {sess.patientDisplayName} ·{' '}
                          <span className="font-mono text-[11px] text-ink-muted">
                            {sess.patientCode}
                          </span>
                        </p>
                      </td>

                      <td className="px-5 py-4">
                        <p className="font-semibold text-ink">
                          {sess.counselorName}, {sess.counselorTitle}
                        </p>
                        <p className="mt-0.5 inline-flex items-center gap-1 text-[11px] text-ink-muted">
                          <Video className="size-3 text-primary" />
                          <span>Video Telekonsultasi Online</span>
                        </p>
                      </td>

                      <td className="px-5 py-4">
                        <div className="inline-flex items-center gap-1.5 text-ink">
                          <Calendar className="size-3.5 text-ink-muted" />
                          <span>{formatSessionDateTime(sess.scheduledStartTime)}</span>
                        </div>
                      </td>

                      <td className="px-5 py-4">
                        <SessionDurationBadge
                          durationMinutes={sess.durationMinutes}
                          isExtended={sess.isExtended}
                        />
                      </td>

                      <td className="px-5 py-4">
                        <span
                          className={cn(
                            'inline-flex rounded-[6px] border px-2 py-0.5 text-[11px] font-semibold',
                            statusBadge.className,
                          )}
                        >
                          {statusBadge.label}
                        </span>
                      </td>

                      <td className="px-5 py-4 text-right">
                        <p className="font-bold text-ink">{formatCoins(sess.totalPriceCoins)}</p>
                        <p className="mt-0.5 text-[11px] text-ink-muted">
                          Psikolog {formatCoins(sess.counselorEarningCoins)} · Fee{' '}
                          {formatCoins(sess.platformFeeCoins)}
                        </p>
                      </td>
                    </tr>
                  )
                })
                )}
              </tbody>
            </table>
          </div>
        </div>

          <TablePagination
            currentPage={safePage}
            totalItems={filteredSessions.length}
            pageSize={pageSize}
            pageSizeOptions={[5, 10, 25, 50]}
            itemLabel="sesi"
            ariaLabel="Paginasi monitoring sesi konsultasi"
            onPageChange={handlePageChange}
            onPageSizeChange={handlePageSizeChange}
          />
        </>
      )}
    </div>
  )
}
