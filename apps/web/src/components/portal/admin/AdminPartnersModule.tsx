import { useMemo, useState } from 'react'
import { ChevronLeft, ChevronRight, RefreshCw, Search } from 'lucide-react'
import { cn } from '@/lib/cn'
import type { PartnerStatus, PortalDatabase } from '@/types/portal'
import { reviewPartnerApplication } from '@/services/portal/partnerService'
import { PartnerStatusBadge } from '../PortalBadges'
import { PartnerDetailPanel } from './PartnerDetailPanel'

interface AdminPartnersModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

const ITEMS_PER_PAGE = 5

export function AdminPartnersModule({ db, onFeedback }: AdminPartnersModuleProps) {
  const [partnerFilter, setPartnerFilter] = useState<'all' | PartnerStatus>('all')
  const [partnerSearch, setPartnerSearch] = useState('')
  const [currentPage, setCurrentPage] = useState(1)
  const [selectedPartnerId, setSelectedPartnerId] = useState<string | null>(
    () => db.partners[0]?.id ?? null,
  )

  const summaryCounts = useMemo(() => {
    const pendingPartners = db.partners.filter((p) => p.status === 'pending').length
    const approvedPartners = db.partners.filter((p) => p.status === 'approved').length
    const rejectedPartners = db.partners.filter((p) => p.status === 'rejected').length
    const suspendedPartners = db.partners.filter((p) => p.status === 'suspended').length
    return { pendingPartners, approvedPartners, rejectedPartners, suspendedPartners }
  }, [db.partners])

  const filteredPartners = useMemo(() => {
    return db.partners.filter((p) => {
      if (partnerFilter !== 'all' && p.status !== partnerFilter) return false
      if (!partnerSearch.trim()) return true
      const q = partnerSearch.toLowerCase()
      return (
        p.facilityName.toLowerCase().includes(q) ||
        p.city.toLowerCase().includes(q) ||
        p.licenseNumber.toLowerCase().includes(q) ||
        p.picName.toLowerCase().includes(q)
      )
    })
  }, [db.partners, partnerFilter, partnerSearch])

  const totalPages = Math.max(1, Math.ceil(filteredPartners.length / ITEMS_PER_PAGE))
  const paginatedPartners = useMemo(() => {
    const start = (currentPage - 1) * ITEMS_PER_PAGE
    return filteredPartners.slice(start, start + ITEMS_PER_PAGE)
  }, [filteredPartners, currentPage])

  const selectedPartner = useMemo(() => {
    return (
      db.partners.find((p) => p.id === selectedPartnerId) ??
      filteredPartners[0] ??
      db.partners[0] ??
      null
    )
  }, [db.partners, filteredPartners, selectedPartnerId])

  const partnerPsychologists = useMemo(() => {
    if (!selectedPartner) return []
    return db.psychologists.filter((psy) => psy.partnerId === selectedPartner.id)
  }, [db.psychologists, selectedPartner])

  const handleFilterChange = (tabId: 'all' | PartnerStatus) => {
    setPartnerFilter(tabId)
    setCurrentPage(1)
  }

  const handleSearchChange = (val: string) => {
    setPartnerSearch(val)
    setCurrentPage(1)
  }

  const filterTabs = [
    { id: 'all' as const, label: `Semua (${db.partners.length})` },
    { id: 'pending' as const, label: `Pending (${summaryCounts.pendingPartners})` },
    { id: 'approved' as const, label: `Disetujui (${summaryCounts.approvedPartners})` },
    { id: 'rejected' as const, label: `Ditolak (${summaryCounts.rejectedPartners})` },
    { id: 'suspended' as const, label: `Nonaktif (${summaryCounts.suspendedPartners})` },
  ]

  return (
    <div>
      <div>
        <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
          Mitra Fasilitas Kesehatan
        </h1>
        <p className="mt-0.5 text-xs text-ink-muted">
          Tinjau dokumen izin operasional, verifikasi pendaftaran baru/revisi, serta kelola status keaktifan mitra faskes.
        </p>
      </div>

      <div className="mt-5 grid grid-cols-1 gap-6 lg:grid-cols-12">
        {/* Left Column: Partner Queue */}
        <div className="lg:col-span-5">
          <div className="rounded-[12px] border border-[#E2E8F0] bg-white">
            <div className="border-b border-[#E2E8F0] p-3">
              <div className="grid grid-cols-5 gap-1 rounded-[8px] bg-[#F1F5F9] p-1">
                {filterTabs.map((tab) => (
                  <button
                    key={tab.id}
                    type="button"
                    onClick={() => handleFilterChange(tab.id)}
                    className={cn(
                      'cursor-pointer rounded-[6px] py-1.5 text-[10.5px] font-semibold transition-colors text-center truncate',
                      partnerFilter === tab.id
                        ? 'bg-white text-ink shadow-2xs'
                        : 'text-ink-muted hover:text-ink',
                    )}
                  >
                    {tab.label}
                  </button>
                ))}
              </div>

              <div className="relative mt-2.5">
                <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
                <input
                  type="search"
                  value={partnerSearch}
                  onChange={(e) => handleSearchChange(e.target.value)}
                  placeholder="Cari nama faskes, kota, nomor izin..."
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink placeholder:text-ink-muted/70 focus:border-primary focus:bg-white focus:outline-none"
                />
              </div>
            </div>

            <div className="divide-y divide-[#E2E8F0]">
              {paginatedPartners.length === 0 ? (
                <div className="p-8 text-center">
                  <p className="text-xs font-medium text-ink-muted">
                    Tidak ada mitra yang sesuai dengan filter pencarian.
                  </p>
                </div>
              ) : (
                paginatedPartners.map((partner) => {
                  const isSelected = selectedPartner?.id === partner.id
                  return (
                    <button
                      key={partner.id}
                      type="button"
                      onClick={() => setSelectedPartnerId(partner.id)}
                      className={cn(
                        'flex w-full cursor-pointer flex-col gap-1.5 p-4 text-left transition-colors',
                        isSelected ? 'bg-[#EEF0FF]/70' : 'bg-white hover:bg-[#F8FAFC]',
                      )}
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-semibold text-ink">
                            {partner.facilityName}
                          </p>
                          {partner.status === 'pending' && partner.isResubmitted && (
                            <span className="mt-1 inline-flex items-center gap-1 rounded-[4px] border border-[#BFDBFE] bg-[#EFF6FF] px-1.5 py-0.5 text-[10px] font-bold text-[#1D4ED8]">
                              <RefreshCw className="size-2.5" />
                              Revisi Dokumen
                            </span>
                          )}
                        </div>
                        <PartnerStatusBadge
                          status={partner.status}
                          isResubmitted={partner.isResubmitted}
                        />
                      </div>
                      <p className="text-xs text-ink-muted">
                        {partner.facilityType} · {partner.city}
                      </p>
                      <div className="mt-1 flex items-center justify-between text-[11px] text-ink-muted">
                        <span className="font-mono">{partner.licenseNumber}</span>
                        <span>Diajukan: {partner.submittedAt}</span>
                      </div>
                    </button>
                  )
                })
              )}
            </div>

            {/* Left Column Pagination Bar: Hanya muncul jika data melebihi 1 halaman (> 5 mitra) */}
            {filteredPartners.length > ITEMS_PER_PAGE && (
              <div className="flex items-center justify-between border-t border-[#E2E8F0] bg-[#F8FAFC] px-3.5 py-2.5">
                <p className="text-[11px] text-ink-muted">
                  Halaman <span className="font-semibold text-ink">{currentPage}</span> dari{' '}
                  <span className="font-semibold text-ink">{totalPages}</span> ({filteredPartners.length} mitra)
                </p>
                <div className="flex items-center gap-1.5">
                  <button
                    type="button"
                    disabled={currentPage === 1}
                    onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                    className="inline-flex h-7 items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-white px-2 text-[11px] font-semibold text-ink transition-colors hover:bg-[#F1F5F9] disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    <ChevronLeft className="size-3" />
                    <span>Prev</span>
                  </button>
                  <button
                    type="button"
                    disabled={currentPage >= totalPages}
                    onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                    className="inline-flex h-7 items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-white px-2 text-[11px] font-semibold text-ink transition-colors hover:bg-[#F1F5F9] disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    <span>Next</span>
                    <ChevronRight className="size-3" />
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Right Column: Partner Inspection */}
        <div className="lg:col-span-7">
          <PartnerDetailPanel
            key={selectedPartner?.id ?? 'empty'}
            selectedPartner={selectedPartner}
            partnerPsychologists={partnerPsychologists}
            onApprovePartner={(partnerId, facilityName) => {
              reviewPartnerApplication(partnerId, 'approved')
              onFeedback(
                `Kemitraan "${facilityName}" telah aktif dan siap menerima rujukan psikolog.`,
              )
            }}
            onSuspendPartner={(partnerId, facilityName) => {
              reviewPartnerApplication(partnerId, 'suspended')
              onFeedback(`Status kemitraan "${facilityName}" telah dinonaktifkan sementara.`)
            }}
            onRejectPartner={(partnerId, facilityName, reason) => {
              reviewPartnerApplication(partnerId, 'rejected', reason)
              onFeedback(`Pengajuan "${facilityName}" ditolak dengan catatan evaluasi.`)
            }}
          />
        </div>
      </div>
    </div>
  )
}
