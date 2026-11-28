import { Coins, History, Search, SlidersHorizontal, Stethoscope } from 'lucide-react'
import { useMemo, useRef, useState } from 'react'
import { VerificationBadge } from '@/components/portal/PortalBadges'
import { TablePagination } from '@/components/portal/TablePagination'
import { useUrlPagination } from '@/hooks/useUrlPagination'
import { cn } from '@/lib/cn'
import type { Psychologist, VerificationStatus } from '@/types/portal'
import { AdminCoinAdjustModal } from './AdminCoinAdjustModal'
import { PsychologistCoinHistoryModal } from './PsychologistCoinHistoryModal'

interface AdminPsychologistCoinsTabProps {
  psychologists: Psychologist[]
  onFeedback?: (message: string) => void
}

type PsyCoinStatusFilter = 'all' | VerificationStatus

export function AdminPsychologistCoinsTab({
  psychologists,
  onFeedback,
}: AdminPsychologistCoinsTabProps) {
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<PsyCoinStatusFilter>('all')
  const [selectedPsy, setSelectedPsy] = useState<Psychologist | null>(null)
  const [adjustTargetPsy, setAdjustTargetPsy] = useState<Psychologist | null>(null)
  const tableRef = useRef<HTMLDivElement>(null)

  const totalCoins = useMemo(
    () => psychologists.reduce((sum, p) => sum + (p.coinBalance ?? 0), 0),
    [psychologists],
  )

  const filteredPsychologists = useMemo(() => {
    const q = search.trim().toLowerCase()
    return psychologists.filter((psy) => {
      if (statusFilter !== 'all' && psy.verificationStatus !== statusFilter) return false
      if (!q) return true
      return (
        psy.fullName.toLowerCase().includes(q) ||
        psy.email.toLowerCase().includes(q) ||
        psy.strNumber.toLowerCase().includes(q) ||
        (psy.sipNumber ?? '').toLowerCase().includes(q)
      )
    })
  }, [psychologists, search, statusFilter])

  const {
    pageSize,
    safePage,
    paginatedItems,
    resetPage,
    handlePageChange,
    handlePageSizeChange,
  } = useUrlPagination(filteredPsychologists, {
    defaultPageSize: 10,
    scrollTargetRef: tableRef,
  })

  return (
    <div className="mt-5 space-y-3">
      <div
        ref={tableRef}
        className="overflow-hidden rounded-[12px] border border-[#E2E8F0] bg-white"
      >
        <div className="flex flex-col gap-3 border-b border-[#E2E8F0] p-4">
          <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
            <div>
              <h2 className="text-sm font-bold text-ink">
                Monitoring Saldo Koin Psikolog
              </h2>
              <p className="text-xs text-ink-muted">
                Pantau total koin honorarium psikolog (Total beredar:{' '}
                <span className="font-bold text-primary">
                  {totalCoins.toLocaleString('id-ID')} Koin
                </span>
                ) beserta riwayat mutasinya.
              </p>
            </div>

            <div className="relative w-full sm:w-64">
              <Search
                className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted"
                aria-hidden="true"
              />
              <input
                type="search"
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value)
                  resetPage()
                }}
                placeholder="Cari nama, email, STR/SIP..."
                className="min-h-10 w-full rounded-[8px] border border-[#CBD5E1] bg-white pr-3 pl-8 text-xs text-ink placeholder:text-ink-muted focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
              />
            </div>
          </div>

          <div className="flex flex-wrap gap-1.5">
            {(
              [
                { id: 'all', label: 'Semua' },
                { id: 'verified', label: 'Terverifikasi' },
                { id: 'pending', label: 'Pending' },
                { id: 'suspended', label: 'Ditangguhkan' },
              ] as const
            ).map((opt) => (
              <button
                key={opt.id}
                type="button"
                onClick={() => {
                  setStatusFilter(opt.id)
                  resetPage()
                }}
                className={cn(
                  'cursor-pointer rounded-[6px] border px-2.5 py-1 text-[11px] font-semibold transition-colors',
                  statusFilter === opt.id
                    ? 'border-primary bg-[#EEF0FF] text-primary'
                    : 'border-[#E2E8F0] bg-[#F8FAFC] text-ink-soft hover:text-ink',
                )}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        {paginatedItems.length === 0 ? (
          <div className="flex flex-col items-center justify-center p-10 text-center text-xs text-ink-muted">
            <Stethoscope className="size-8 text-ink-muted/50" />
            <p className="mt-2 font-semibold text-ink">
              Tidak ada psikolog yang sesuai filter saat ini
            </p>
          </div>
        ) : (
          <>
            <div className="divide-y divide-[#E2E8F0] md:hidden">
              {paginatedItems.map((psy) => (
                <div key={psy.id} className="space-y-2.5 p-4 text-xs">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <p className="truncate font-bold text-ink">
                        {psy.fullName}, {psy.titleDegree}
                      </p>
                      <p className="truncate text-[11px] text-ink-muted">{psy.email}</p>
                    </div>
                    <VerificationBadge status={psy.verificationStatus} />
                  </div>

                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="inline-flex items-center gap-1 rounded-[6px] bg-[#EEF0FF] px-2.5 py-1 text-xs font-bold text-primary">
                      <Coins className="size-3.5" aria-hidden="true" />
                      {(psy.coinBalance ?? 0).toLocaleString('id-ID')} Koin
                    </span>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => setAdjustTargetPsy(psy)}
                        className="inline-flex min-h-9 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink hover:bg-[#F8FAFC]"
                      >
                        <SlidersHorizontal className="size-3.5" aria-hidden="true" />
                        <span>Sesuaikan</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => setSelectedPsy(psy)}
                        className="inline-flex min-h-9 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink hover:bg-[#F8FAFC]"
                      >
                        <History className="size-3.5" aria-hidden="true" />
                        <span>Riwayat Mutasi</span>
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="hidden overflow-x-auto md:block">
              <table className="w-full border-collapse text-left">
                <thead>
                  <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                    <th className="px-4 py-3">Psikolog</th>
                    <th className="px-4 py-3">STR / SIP</th>
                    <th className="px-4 py-3">Status</th>
                    <th className="px-4 py-3">Saldo Koin</th>
                    <th className="px-4 py-3 text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#E2E8F0] text-xs">
                  {paginatedItems.map((psy) => (
                    <tr key={psy.id} className="hover:bg-[#F8FAFC]">
                      <td className="max-w-[230px] px-4 py-3.5">
                        <p className="truncate font-semibold text-ink">
                          {psy.fullName}, {psy.titleDegree}
                        </p>
                        <p className="truncate text-[11px] text-ink-muted">{psy.email}</p>
                      </td>
                      <td className="px-4 py-3.5 font-mono text-[11px] text-ink-soft">
                        <p>{psy.strNumber || '-'}</p>
                        <p className="text-ink-muted">{psy.sipNumber || '-'}</p>
                      </td>
                      <td className="px-4 py-3.5 whitespace-nowrap">
                        <VerificationBadge status={psy.verificationStatus} />
                      </td>
                      <td className="px-4 py-3.5 whitespace-nowrap">
                        <span className="inline-flex items-center gap-1 rounded-[6px] bg-[#EEF0FF] px-2.5 py-1 text-xs font-bold text-primary">
                          <Coins className="size-3.5" aria-hidden="true" />
                          {(psy.coinBalance ?? 0).toLocaleString('id-ID')} Koin
                        </span>
                      </td>
                      <td className="px-4 py-3.5 text-right whitespace-nowrap">
                        <div className="inline-flex items-center justify-end gap-1.5">
                          <button
                            type="button"
                            onClick={() => setAdjustTargetPsy(psy)}
                            className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[6px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink transition-colors hover:bg-[#F8FAFC]"
                          >
                            <SlidersHorizontal className="size-3.5" aria-hidden="true" />
                            <span>Sesuaikan</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => setSelectedPsy(psy)}
                            className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[6px] border border-primary/30 bg-[#EEF0FF] px-3 text-xs font-semibold text-primary transition-colors hover:bg-primary hover:text-white"
                          >
                            <History className="size-3.5" aria-hidden="true" />
                            <span>Riwayat Mutasi</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}

        <TablePagination
          totalItems={filteredPsychologists.length}
          currentPage={safePage}
          pageSize={pageSize}
          onPageChange={handlePageChange}
          onPageSizeChange={handlePageSizeChange}
        />
      </div>

      <PsychologistCoinHistoryModal
        psychologist={selectedPsy}
        isOpen={selectedPsy !== null}
        onClose={() => setSelectedPsy(null)}
      />

      <AdminCoinAdjustModal
        key={adjustTargetPsy ? `adjust-psy-${adjustTargetPsy.id}` : 'adjust-psy-closed'}
        isOpen={adjustTargetPsy !== null}
        target={adjustTargetPsy ? { kind: 'psychologist', psychologist: adjustTargetPsy } : null}
        onClose={() => setAdjustTargetPsy(null)}
        onSuccess={(message) => onFeedback?.(message)}
      />
    </div>
  )
}
