import { useMemo, useState } from 'react'
import { Search } from 'lucide-react'
import { cn } from '@/lib/cn'
import type { PartnerStatus, PortalDatabase } from '@/types/portal'
import { reviewPartnerApplication } from '@/services/portal/partnerService'
import { PartnerStatusBadge } from '../PortalBadges'
import { PartnerDetailPanel } from './PartnerDetailPanel'

interface AdminPartnersModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

export function AdminPartnersModule({ db, onFeedback }: AdminPartnersModuleProps) {
  const [partnerFilter, setPartnerFilter] = useState<'all' | PartnerStatus>('pending')
  const [partnerSearch, setPartnerSearch] = useState('')
  const [selectedPartnerId, setSelectedPartnerId] = useState<string | null>(
    () => db.partners.find((p) => p.status === 'pending')?.id ?? db.partners[0]?.id ?? null,
  )

  const summaryCounts = useMemo(() => {
    const pendingPartners = db.partners.filter((p) => p.status === 'pending').length
    const approvedPartners = db.partners.filter((p) => p.status === 'approved').length
    const rejectedPartners = db.partners.filter((p) => p.status === 'rejected').length
    return { pendingPartners, approvedPartners, rejectedPartners }
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

  return (
    <div>
      <div>
        <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
          Verifikasi &amp; Manajemen Mitra Fasilitas Kesehatan
        </h1>
        <p className="mt-0.5 text-xs text-ink-muted">
          Tinjau dokumen izin operasional Rumah Sakit, Klinik, dan Biro Psikologi yang mendaftar melalui portal website.
        </p>
      </div>

      <div className="mt-5 grid grid-cols-1 gap-6 lg:grid-cols-12">
        {/* Left Column: Partner Queue */}
        <div className="lg:col-span-5">
          <div className="rounded-[12px] border border-[#E2E8F0] bg-white">
            <div className="border-b border-[#E2E8F0] p-3">
              <div className="grid grid-cols-4 gap-1 rounded-[8px] bg-[#F1F5F9] p-1">
                {(
                  [
                    { id: 'pending', label: `Pending (${summaryCounts.pendingPartners})` },
                    { id: 'approved', label: `Aktif (${summaryCounts.approvedPartners})` },
                    { id: 'rejected', label: `Ditolak (${summaryCounts.rejectedPartners})` },
                    { id: 'all', label: `Semua (${db.partners.length})` },
                  ] as const
                ).map((tab) => (
                  <button
                    key={tab.id}
                    type="button"
                    onClick={() => setPartnerFilter(tab.id)}
                    className={cn(
                      'cursor-pointer rounded-[6px] py-1.5 text-[11px] font-semibold transition-colors',
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
                  onChange={(e) => setPartnerSearch(e.target.value)}
                  placeholder="Cari nama faskes, kota, nomor izin..."
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink placeholder:text-ink-muted/70 focus:border-primary focus:bg-white focus:outline-none"
                />
              </div>
            </div>

            <div className="divide-y divide-[#E2E8F0]">
              {filteredPartners.length === 0 ? (
                <div className="p-8 text-center">
                  <p className="text-xs font-medium text-ink-muted">
                    Tidak ada pengajuan mitra yang sesuai dengan filter pencarian.
                  </p>
                </div>
              ) : (
                filteredPartners.map((partner) => {
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
                        <p className="text-sm font-semibold text-ink">{partner.facilityName}</p>
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
                `Pengajuan mitra "${facilityName}" telah disetujui. Akun mitra kini aktif untuk mengelola psikolog.`,
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
