import { Search } from 'lucide-react'
import { useMemo, useState } from 'react'
import {
  PsychologistKpiCards,
  type PsyFilterTab,
  type PsychologistKpiCounts,
} from './psychologists/PsychologistKpiCards'
import { PsychologistTable } from './psychologists/PsychologistTable'
import { PsychologistDetailModal } from './psychologists/PsychologistDetailModal'
import {
  MobilePsychologistSimulatorModal,
  MobilePsychologistSimulatorTrigger,
} from '@/components/devtools/PortalDevTools'
import { cn } from '@/lib/cn'
import { reviewIndependentPsychologist, type PartnerAccount, type Psychologist } from '@/lib/portalStore'

interface AdminPsychologistsModuleProps {
  psychologists: Psychologist[]
  partners: PartnerAccount[]
  onFeedback: (msg: string) => void
}

export function AdminPsychologistsModule({
  psychologists,
  partners,
  onFeedback,
}: AdminPsychologistsModuleProps) {
  const [activeFilter, setActiveFilter] = useState<PsyFilterTab>('all')
  const [search, setSearch] = useState('')
  const [selectedPsyId, setSelectedPsyId] = useState<string | null>(null)
  const [isDetailModalOpen, setIsDetailModalOpen] = useState(false)
  const [isSimModalOpen, setIsSimModalOpen] = useState(false)

  // Compute counts for KPI cards & tabs
  const counts: PsychologistKpiCounts = useMemo(() => {
    const mitra = psychologists.filter(
      (p) => p.role === 'professional_mitra' || (!p.role && p.partnerId),
    ).length
    const relawanProfesional = psychologists.filter(
      (p) =>
        p.role === 'relawan_profesional' ||
        (!p.role && !p.partnerId && p.practiceType === 'mandiri'),
    ).length
    const relawan = psychologists.filter(
      (p) => p.role === 'relawan_biasa' || (p.role as string) === 'relawan',
    ).length
    const pendingVerifikasi = psychologists.filter(
      (p) => p.verificationStatus === 'pending',
    ).length
    const pendingUpgrade = psychologists.filter((p) => Boolean(p.upgradeRequest)).length
    const pendingAction = psychologists.filter(
      (p) => p.verificationStatus === 'pending' || Boolean(p.upgradeRequest),
    ).length

    return {
      total: psychologists.length,
      mitra,
      relawanProfesional,
      relawan,
      pendingAction,
      pendingVerifikasi,
      pendingUpgrade,
      relawanBiasa: relawan,
    }
  }, [psychologists])

  // Filter psychologists based on tab and search
  const filteredPsychologists = useMemo(() => {
    const q = search.trim().toLowerCase()
    return psychologists.filter((p) => {
      const isMitra = p.role === 'professional_mitra' || (!p.role && p.partnerId)
      const isRelawanProf =
        p.role === 'relawan_profesional' ||
        (!p.role && !p.partnerId && p.practiceType === 'mandiri')
      const isRelawan = p.role === 'relawan_biasa' || (p.role as string) === 'relawan'
      const hasUpgrade = Boolean(p.upgradeRequest)
      const isPendingVerif = p.verificationStatus === 'pending'

      if (activeFilter === 'mitra' && !isMitra) return false
      if (activeFilter === 'relawan_profesional' && !isRelawanProf) return false
      if ((activeFilter === 'relawan' || activeFilter === 'relawan_biasa') && !isRelawan)
        return false
      if (activeFilter === 'pending_action' && !isPendingVerif && !hasUpgrade) return false

      if (!q) return true
      const partner = p.partnerId ? partners.find((pt) => pt.id === p.partnerId) : null
      return (
        p.fullName.toLowerCase().includes(q) ||
        p.sippNumber.toLowerCase().includes(q) ||
        (p.strNumber?.toLowerCase().includes(q) ?? false) ||
        (p.city?.toLowerCase().includes(q) ?? false) ||
        (partner?.facilityName.toLowerCase().includes(q) ?? false) ||
        p.specializations.some((s) => s.toLowerCase().includes(q))
      )
    })
  }, [psychologists, partners, activeFilter, search])

  const selectedPsy = useMemo(() => {
    if (!selectedPsyId) return null
    return psychologists.find((p) => p.id === selectedPsyId) ?? null
  }, [psychologists, selectedPsyId])

  const handleOpenDetail = (psy: Psychologist) => {
    setSelectedPsyId(psy.id)
    setIsDetailModalOpen(true)
  }

  const handleApproveMandiri = (psyId: string, fullName: string) => {
    reviewIndependentPsychologist(psyId, 'approved')
    onFeedback(
      `Kredensial pendaftaran "${fullName}" telah disetujui. Akun kini aktif berpraktik di aplikasi mobile.`,
    )
  }

  const selectedPsyPartner = useMemo(() => {
    if (!selectedPsy?.partnerId) return null
    return partners.find((p) => p.id === selectedPsy.partnerId) ?? null
  }, [partners, selectedPsy])

  const filterTabs: Array<{ id: PsyFilterTab; label: string }> = [
    { id: 'all', label: `Semua (${counts.total})` },
    { id: 'mitra', label: `Profesional Mitra (${counts.mitra})` },
    { id: 'relawan_profesional', label: `Relawan Profesional (${counts.relawanProfesional})` },
    { id: 'relawan', label: `Relawan Pendamping (${counts.relawan})` },
    { id: 'pending_action', label: `Antrean Upgrade / Verifikasi (${counts.pendingAction})` },
  ]

  return (
    <div className="flex flex-col gap-4 sm:gap-5">
      {/* Page Header */}
      <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Verifikasi Psikolog &amp; Relawan
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Kelola data psikolog mitra, relawan pendamping, verifikasi berkas izin praktik, dan pengajuan upgrade.
          </p>
        </div>
        <MobilePsychologistSimulatorTrigger onOpen={() => setIsSimModalOpen(true)} />
      </div>

      {/* KPI Metric Cards */}
      <PsychologistKpiCards
        counts={counts}
        activeFilter={activeFilter}
        onSelectFilter={setActiveFilter}
      />

      {/* Search & Filter Controls (Responsive Dropdown on Mobile, Pills on Desktop) */}
      <div className="flex flex-col gap-3 rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative flex-1">
          <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
          <input
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari nama psikolog/relawan, nomor SIPP, STR, instansi faskes, atau kota domisili..."
            className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink placeholder:text-ink-muted/70 focus:border-primary focus:bg-white focus:outline-none"
          />
        </div>

        {/* Mobile View (< sm): Compact Dropdown Select */}
        <div className="block sm:hidden">
          <label htmlFor="mobile-psy-filter" className="sr-only">Filter Kategori Psikolog &amp; Relawan</label>
          <select
            id="mobile-psy-filter"
            value={activeFilter}
            onChange={(e) => setActiveFilter(e.target.value as PsyFilterTab)}
            className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] px-3 text-xs font-semibold text-ink focus:border-primary focus:bg-white focus:outline-none"
          >
            {filterTabs.map((tab) => (
              <option key={tab.id} value={tab.id}>
                {tab.label}
              </option>
            ))}
          </select>
        </div>

        {/* Desktop View (>= sm): Horizontal Pills */}
        <div className="hidden shrink-0 flex-wrap gap-1 rounded-[8px] bg-[#F1F5F9] p-1 sm:flex">
          {filterTabs.map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveFilter(tab.id)}
              className={cn(
                'cursor-pointer rounded-[6px] px-2.5 py-1 text-xs font-semibold whitespace-nowrap transition-colors',
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

      {/* Full Data Table */}
      <PsychologistTable
        psychologists={filteredPsychologists}
        partners={partners}
        onSelectPsychologist={handleOpenDetail}
      />

      {/* Integrated Detail & Certificate Verification / Upgrade Review Modal */}
      <PsychologistDetailModal
        isOpen={isDetailModalOpen}
        psy={selectedPsy}
        partner={selectedPsyPartner}
        onClose={() => {
          setIsDetailModalOpen(false)
          setSelectedPsyId(null)
        }}
        onApproveMandiri={handleApproveMandiri}
        onFeedback={onFeedback}
      />

      {/* Simulation Modal (DevTools Adapter) */}
      <MobilePsychologistSimulatorModal
        isOpen={isSimModalOpen}
        psychologists={psychologists}
        onClose={() => setIsSimModalOpen(false)}
        onCreated={(created, isUpgrade) => {
          setIsSimModalOpen(false)
          if (isUpgrade) {
            onFeedback(
              `Simulasi permohonan upgrade "${created.fullName}" berhasil ditambahkan ke antrean verifikasi.`,
            )
          } else {
            onFeedback(
              `Simulasi pendaftaran "${created.fullName}" berhasil ditambahkan ke antrean verifikasi.`,
            )
          }
        }}
      />
    </div>
  )
}
