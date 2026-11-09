import {
  Building2,
  Calendar,
  CheckCircle2,
  MapPin,
  Search,
  Stethoscope,
  UserCheck,
  UserMinus,
  X,
} from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { cn } from '@/lib/cn'
import {
  type PartnerAccount,
  type PatientReferral,
  type Psychologist,
  type ReferralStatus,
} from '@/lib/portalStore'

interface ReferralAssignmentDrawerProps {
  referral: PatientReferral | null
  psychologists: Psychologist[]
  partners: PartnerAccount[]
  allReferrals: PatientReferral[]
  onClose: () => void
  onAssign: (
    referralId: string,
    psychologistId: string | null,
    nextStatus: ReferralStatus,
    psychologistName?: string,
  ) => void
}

type RoleCategoryFilter = 'all' | 'mitra' | 'relawan_profesional' | 'relawan_biasa'

function getPsychologistCategoryLabel(
  psy: Psychologist,
  partners: PartnerAccount[],
): { badgeLabel: string; facilityOrRoleName: string; badgeClass: string } {
  if (psy.role === 'relawan_profesional_mitra' || psy.practiceType === 'faskes') {
    const partner = psy.partnerId
      ? partners.find((p) => p.id === psy.partnerId)
      : undefined
    return {
      badgeLabel: 'Relawan Profesional (Mitra)',
      facilityOrRoleName: partner?.facilityName ?? 'Mitra Faskes EVA',
      badgeClass: 'border-[#BFDBFE] bg-[#EFF6FF] text-[#1E40AF]',
    }
  }

  if (psy.role === 'relawan_profesional_non_mitra') {
    return {
      badgeLabel: 'Relawan Profesional (Non Mitra)',
      facilityOrRoleName: 'Praktik Mandiri Terverifikasi',
      badgeClass: 'border-[#C7D2FE] bg-[#EEF0FF] text-primary',
    }
  }

  return {
    badgeLabel: 'Relawan Pendamping',
    facilityOrRoleName: 'Jaringan Relawan EVA',
    badgeClass: 'border-[#E2E8F0] bg-[#F8FAFC] text-ink-soft',
  }
}

export function ReferralAssignmentDrawer({
  referral,
  psychologists,
  partners,
  allReferrals,
  onClose,
  onAssign,
}: ReferralAssignmentDrawerProps) {
  const [searchQuery, setSearchQuery] = useState('')
  const [categoryFilter, setCategoryFilter] = useState<RoleCategoryFilter>('all')

  useEffect(() => {
    if (!referral) return
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose()
      }
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [referral, onClose])

  // Calculate active scheduled referrals count per psychologist
  const activeLoadByPsychologist = useMemo(() => {
    const counts: Record<string, number> = {}
    for (const ref of allReferrals) {
      if (ref.assignedPsychologistId && ref.status === 'scheduled') {
        counts[ref.assignedPsychologistId] =
          (counts[ref.assignedPsychologistId] ?? 0) + 1
      }
    }
    return counts
  }, [allReferrals])

  const filteredPsychologists = useMemo(() => {
    const q = searchQuery.trim().toLowerCase()

    return psychologists.filter((psy) => {
      if (categoryFilter === 'mitra' && psy.role !== 'relawan_profesional_mitra') {
        return false
      }
      if (
        categoryFilter === 'relawan_profesional' &&
        psy.role !== 'relawan_profesional_non_mitra'
      ) {
        return false
      }
      if (
        categoryFilter === 'relawan_biasa' &&
        psy.role !== 'relawan_biasa'
      ) {
        return false
      }

      if (!q) return true

      const partnerName = psy.partnerId
        ? (partners.find((p) => p.id === psy.partnerId)?.facilityName ?? '')
        : ''

      return (
        psy.fullName.toLowerCase().includes(q) ||
        (psy.city ?? '').toLowerCase().includes(q) ||
        psy.practiceSchedule.toLowerCase().includes(q) ||
        partnerName.toLowerCase().includes(q) ||
        psy.specializations.some((spec) => spec.toLowerCase().includes(q))
      )
    })
  }, [psychologists, partners, categoryFilter, searchQuery])

  if (!referral) return null

  const currentAssignedPsy = psychologists.find(
    (p) => p.id === referral.assignedPsychologistId,
  )

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="drawer-referral-title"
      className="fixed inset-0 z-50 flex justify-end bg-ink/45 backdrop-blur-[1px]"
      onClick={onClose}
    >
      <div
        className="flex h-full w-full max-w-xl flex-col border-l border-[#E2E8F0] bg-white shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Top Drawer Header */}
        <div className="flex items-start justify-between gap-3 border-b border-[#E2E8F0] px-5 py-4">
          <div>
            <span className="inline-flex items-center gap-1 rounded-[5px] bg-[#EEF0FF] px-2 py-0.5 text-[10px] font-bold text-primary uppercase">
              <Stethoscope className="size-3" />
              Pencocokan &amp; Penugasan Klinis
            </span>
            <h2
              id="drawer-referral-title"
              className="mt-1 text-base font-bold text-ink"
            >
              Pilih Psikolog untuk {referral.patientCode}
            </h2>
            <p className="text-xs text-ink-muted">
              Cocokkan profil klinis dan preferensi jadwal pasien dengan ketersediaan psikolog.
            </p>
          </div>

          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup panel penugasan"
            className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[8px] border border-[#E2E8F0] text-ink-muted transition-colors hover:bg-slate-100 hover:text-ink"
          >
            <X className="size-4" />
          </button>
        </div>

        {/* Sticky Patient Context Card */}
        <div className="border-b border-[#E2E8F0] bg-[#F8FAFC] px-5 py-3.5">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <span className="font-mono text-xs font-bold text-ink">
                {referral.patientCode}
              </span>
              <span className="text-xs text-ink-muted">
                · {referral.gender}, {referral.age} tahun
              </span>
            </div>

            <span
              className={cn(
                'rounded-[6px] border px-2 py-0.5 text-[11px] font-bold',
                referral.dass21.severity === 'Extreme'
                  ? 'border-[#FECACA] bg-[#FEF2F2] text-[#991B1B]'
                  : referral.dass21.severity === 'Severe'
                    ? 'border-[#FDE68A] bg-[#FEF3C7] text-[#92400E]'
                    : 'border-[#BFDBFE] bg-[#EFF6FF] text-[#1E40AF]',
              )}
            >
              DASS-21: {referral.dass21.severity} (D:{referral.dass21.depression} / A:
              {referral.dass21.anxiety} / S:{referral.dass21.stress})
            </span>
          </div>

          <p className="mt-2 line-clamp-2 text-xs leading-relaxed text-ink-soft">
            {referral.clinicalSummary}
          </p>

          <div className="mt-2.5 flex flex-wrap items-center justify-between gap-2 rounded-[8px] border border-[#E2E8F0] bg-white px-3 py-2 text-xs">
            <div className="flex items-center gap-1.5 text-ink">
              <Calendar className="size-3.5 text-primary" />
              <span className="text-ink-muted">Preferensi Jadwal Pasien:</span>
              <strong className="font-semibold text-ink">
                {referral.preferredSchedule}
              </strong>
            </div>

            {currentAssignedPsy && (
              <button
                type="button"
                onClick={() =>
                  onAssign(referral.id, null, 'unassigned')
                }
                className="inline-flex cursor-pointer items-center gap-1 rounded-[6px] border border-rose-200 bg-rose-50 px-2 py-1 text-[11px] font-semibold text-rose-700 transition-colors hover:bg-rose-100"
              >
                <UserMinus className="size-3" />
                <span>Lepas Penugasan</span>
              </button>
            )}
          </div>
        </div>

        {/* Search & Role Category Filter Bar */}
        <div className="space-y-2.5 border-b border-[#E2E8F0] bg-white px-5 py-3">
          <div className="relative">
            <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
            <input
              type="search"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Cari nama psikolog, spesialisasi (mis. Trauma, Kecemasan), kota, atau jadwal..."
              className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink focus:border-primary focus:bg-white focus:outline-none"
            />
          </div>

          <div className="flex flex-wrap items-center gap-1.5">
            {(
              [
                { id: 'all', label: `Semua (${psychologists.length})` },
                {
                  id: 'mitra',
                  label: `Relawan Profesional (Mitra) (${psychologists.filter((p) => p.role === 'relawan_profesional_mitra').length})`,
                },
                {
                  id: 'relawan_profesional',
                  label: `Relawan Profesional (Non Mitra) (${psychologists.filter((p) => p.role === 'relawan_profesional_non_mitra').length})`,
                },
                {
                  id: 'relawan_biasa',
                  label: `Relawan Pendamping (${psychologists.filter((p) => p.role === 'relawan_biasa').length})`,
                },
              ] as const
            ).map((tab) => (
              <button
                key={tab.id}
                type="button"
                onClick={() => setCategoryFilter(tab.id)}
                className={cn(
                  'cursor-pointer rounded-[6px] border px-2.5 py-1 text-[11px] font-semibold transition-colors',
                  categoryFilter === tab.id
                    ? 'border-primary bg-primary text-white'
                    : 'border-[#E2E8F0] bg-[#F8FAFC] text-ink-soft hover:border-[#CBD5E1] hover:text-ink',
                )}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {/* Scrollable Psychologist Candidate Cards */}
        <div className="flex-1 space-y-3 overflow-y-auto p-5">
          {filteredPsychologists.length === 0 ? (
            <div className="rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-8 text-center text-xs text-ink-muted">
              Tidak ditemukan psikolog atau relawan yang sesuai dengan kata kunci pencarian.
            </div>
          ) : (
            filteredPsychologists.map((psy) => {
              const isCurrentlyAssigned = referral.assignedPsychologistId === psy.id
              const categoryMeta = getPsychologistCategoryLabel(psy, partners)
              const activeCount = activeLoadByPsychologist[psy.id] ?? 0
              const weeklyQuota = psy.weeklyQuota ?? 6
              const isQuotaFull = activeCount >= weeklyQuota

              return (
                <div
                  key={psy.id}
                  className={cn(
                    'rounded-[12px] border p-4 transition-all',
                    isCurrentlyAssigned
                      ? 'border-primary bg-[#EEF0FF]/40 ring-1 ring-primary'
                      : 'border-[#E2E8F0] bg-white hover:border-[#CBD5E1]',
                  )}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <div className="flex flex-wrap items-center gap-1.5">
                        <span
                          className={cn(
                            'rounded-[5px] border px-2 py-0.5 text-[10px] font-bold',
                            categoryMeta.badgeClass,
                          )}
                        >
                          {categoryMeta.badgeLabel}
                        </span>
                        {isCurrentlyAssigned && (
                          <span className="inline-flex items-center gap-1 rounded-[5px] bg-emerald-100 px-2 py-0.5 text-[10px] font-bold text-emerald-800">
                            <CheckCircle2 className="size-3" /> Sedang Ditugaskan
                          </span>
                        )}
                      </div>

                      <h3 className="mt-1.5 text-sm font-bold text-ink">
                        {psy.fullName}
                      </h3>

                      <div className="mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-ink-muted">
                        <span className="inline-flex items-center gap-1">
                          <Building2 className="size-3 text-ink-muted" />
                          {categoryMeta.facilityOrRoleName}
                        </span>
                        {psy.city && (
                          <span className="inline-flex items-center gap-1">
                            <MapPin className="size-3 text-ink-muted" />
                            {psy.city}
                          </span>
                        )}
                        {psy.yearsExperience && (
                          <span>· {psy.yearsExperience} thn pengalaman</span>
                        )}
                      </div>
                    </div>

                    {/* Active Case Load Badge */}
                    <div className="shrink-0 text-right">
                      <span
                        className={cn(
                          'inline-flex items-center rounded-[6px] border px-2 py-0.5 text-[11px] font-semibold',
                          isQuotaFull
                            ? 'border-amber-200 bg-amber-50 text-amber-800'
                            : 'border-emerald-200 bg-emerald-50 text-emerald-800',
                        )}
                      >
                        Beban: {activeCount}/{weeklyQuota} kasus
                      </span>
                      <p className="mt-0.5 font-mono text-[10px] text-ink-muted">
                        {psy.sippNumber}
                      </p>
                    </div>
                  </div>

                  {/* Specializations */}
                  <div className="mt-3 flex flex-wrap gap-1.5">
                    {psy.specializations.map((spec) => (
                      <span
                        key={spec}
                        className="rounded-[5px] border border-[#E2E8F0] bg-[#F8FAFC] px-2 py-0.5 text-[11px] font-medium text-ink-soft"
                      >
                        {spec}
                      </span>
                    ))}
                  </div>

                  {/* Schedule & Assign Action Row */}
                  <div className="mt-3.5 flex flex-col justify-between gap-2.5 border-t border-[#E2E8F0] pt-3 sm:flex-row sm:items-center">
                    <div className="flex items-center gap-1.5 text-xs text-ink-soft">
                      <Calendar className="size-3.5 shrink-0 text-primary" />
                      <span>
                        Jadwal Praktik: <strong className="text-ink">{psy.practiceSchedule}</strong>
                      </span>
                    </div>

                    {isCurrentlyAssigned ? (
                      <span className="inline-flex h-8 items-center justify-center gap-1.5 rounded-[8px] border border-primary/30 bg-[#EEF0FF] px-3 text-xs font-bold text-primary">
                        <UserCheck className="size-3.5" />
                        <span>Psikolog Terpilih</span>
                      </span>
                    ) : (
                      <button
                        type="button"
                        onClick={() => {
                          const nextStatus: ReferralStatus =
                            referral.status === 'completed' ? 'completed' : 'scheduled'
                          onAssign(referral.id, psy.id, nextStatus, psy.fullName)
                        }}
                        className="inline-flex h-8 shrink-0 cursor-pointer items-center justify-center gap-1.5 rounded-[8px] bg-primary px-3.5 text-xs font-semibold text-white transition-colors hover:bg-primary-hover"
                      >
                        <UserCheck className="size-3.5" />
                        <span>Tugaskan Psikolog</span>
                      </button>
                    )}
                  </div>
                </div>
              )
            })
          )}
        </div>

        {/* Drawer Footer */}
        <div className="flex items-center justify-between border-t border-[#E2E8F0] bg-[#F8FAFC] px-5 py-3 text-xs">
          <span className="text-ink-muted">
            Menampilkan {filteredPsychologists.length} dari {psychologists.length} psikolog aktif
          </span>
          <button
            type="button"
            onClick={onClose}
            className="h-8 cursor-pointer rounded-[8px] border border-[#CBD5E1] bg-white px-3.5 font-semibold text-ink-soft transition-colors hover:bg-slate-50 hover:text-ink"
          >
            Tutup Panel
          </button>
        </div>
      </div>
    </div>
  )
}
