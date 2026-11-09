import {
  Building2,
  Calendar,
  CheckCircle2,
  MapPin,
  Search,
  Sparkles,
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
  variant?: 'admin' | 'partner'
  onClose: () => void
  onAssign: (
    referralId: string,
    psychologistId: string | null,
    nextStatus: ReferralStatus,
    psychologistName?: string,
  ) => void
}

type RoleCategoryFilter = 'all' | 'mitra' | 'relawan_profesional' | 'relawan_biasa'
type PartnerStatusFilter = 'all' | 'active'

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

/** Check whether a specialization matches referral clinical context */
function isSpecMatching(spec: string, referralContext: string): boolean {
  const s = spec.toLowerCase()
  const c = referralContext.toLowerCase()
  if (s.includes('depresi') && (c.includes('depres') || c.includes('murung') || c.includes('hampa'))) return true
  if (s.includes('cemas') && (c.includes('cemas') || c.includes('anx') || c.includes('panik') || c.includes('khawatir'))) return true
  if (s.includes('trauma') && (c.includes('trauma') || c.includes('ptsd') || c.includes('kekerasan'))) return true
  if (s.includes('stres') && (c.includes('stres') || c.includes('stress') || c.includes('tekanan') || c.includes('burnout'))) return true
  if (s.includes('keluarga') && (c.includes('keluarga') || c.includes('orang tua') || c.includes('relasi') || c.includes('pasangan'))) return true
  if (s.includes('remaja') && (c.includes('remaja') || c.includes('sekolah') || c.includes('kuliah') || c.includes('akademik'))) return true
  return false
}

export function ReferralAssignmentDrawer({
  referral,
  psychologists,
  partners,
  allReferrals,
  variant = 'admin',
  onClose,
  onAssign,
}: ReferralAssignmentDrawerProps) {
  const [searchQuery, setSearchQuery] = useState('')
  const [adminCategoryFilter, setAdminCategoryFilter] = useState<RoleCategoryFilter>('all')
  const [partnerStatusFilter, setPartnerStatusFilter] = useState<PartnerStatusFilter>('all')

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

  const referralClinicalContext = useMemo(() => {
    if (!referral) return ''
    return `${referral.clinicalSummary} ${referral.dass21.severity}`
  }, [referral])

  const filteredPsychologists = useMemo(() => {
    const q = searchQuery.trim().toLowerCase()

    return psychologists.filter((psy) => {
      if (variant === 'partner') {
        if (partnerStatusFilter === 'active' && psy.status !== 'active') {
          return false
        }
      } else {
        if (adminCategoryFilter === 'mitra' && psy.role !== 'relawan_profesional_mitra') {
          return false
        }
        if (
          adminCategoryFilter === 'relawan_profesional' &&
          psy.role !== 'relawan_profesional_non_mitra'
        ) {
          return false
        }
        if (
          adminCategoryFilter === 'relawan_biasa' &&
          psy.role !== 'relawan_biasa'
        ) {
          return false
        }
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
  }, [psychologists, partners, variant, adminCategoryFilter, partnerStatusFilter, searchQuery])

  if (!referral) return null

  const currentAssignedPsy = psychologists.find(
    (p) => p.id === referral.assignedPsychologistId,
  )

  const activePracticingCount = psychologists.filter(
    (p) => p.status === 'active',
  ).length

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
              {variant === 'partner' ? 'Penugasan Tim Klinis Faskes' : 'Pencocokan & Penugasan Klinis'}
            </span>
            <h2
              id="drawer-referral-title"
              className="mt-1 text-base font-bold text-ink"
            >
              {variant === 'partner'
                ? `Tugaskan Psikolog untuk ${referral.patientCode}`
                : `Pilih Psikolog untuk ${referral.patientCode}`}
            </h2>
            <p className="text-xs text-ink-muted">
              {variant === 'partner'
                ? 'Pilih psikolog internal faskes yang sesuai dengan keluhan klinis dan preferensi jadwal pasien.'
                : 'Cocokkan profil klinis dan preferensi jadwal pasien dengan ketersediaan psikolog jaringan EVA.'}
            </p>
          </div>

          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup panel penugasan"
            className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[8px] border border-[#E2E8F0] text-ink-muted transition-colors hover:bg-slate-100 hover:text-ink focus:outline-none focus:ring-2 focus:ring-primary/20"
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

          <p className="mt-2 text-xs leading-relaxed text-ink-soft">
            <span className="font-semibold text-ink">Keluhan Klinis:</span> {referral.clinicalSummary}
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

        {/* Search & Category Filter Bar */}
        <div className="space-y-2.5 border-b border-[#E2E8F0] bg-white px-5 py-3">
          <div className="relative">
            <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
            <input
              type="search"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={
                variant === 'partner'
                  ? 'Cari nama psikolog internal atau spesialisasi (mis. Trauma, Cemas)...'
                  : 'Cari nama psikolog, spesialisasi, kota, atau jadwal...'
              }
              className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink focus:border-primary focus:bg-white focus:outline-none"
            />
          </div>

          <div className="flex flex-wrap items-center gap-1.5">
            {variant === 'partner' ? (
              <>
                <button
                  type="button"
                  onClick={() => setPartnerStatusFilter('all')}
                  className={cn(
                    'cursor-pointer rounded-[6px] border px-2.5 py-1 text-[11px] font-semibold transition-colors',
                    partnerStatusFilter === 'all'
                      ? 'border-primary bg-primary text-white'
                      : 'border-[#E2E8F0] bg-[#F8FAFC] text-ink-soft hover:border-[#CBD5E1] hover:text-ink',
                  )}
                >
                  Semua ({psychologists.length})
                </button>
                <button
                  type="button"
                  onClick={() => setPartnerStatusFilter('active')}
                  className={cn(
                    'cursor-pointer rounded-[6px] border px-2.5 py-1 text-[11px] font-semibold transition-colors',
                    partnerStatusFilter === 'active'
                      ? 'border-primary bg-primary text-white'
                      : 'border-[#E2E8F0] bg-[#F8FAFC] text-ink-soft hover:border-[#CBD5E1] hover:text-ink',
                  )}
                >
                  Aktif Siap Praktik ({activePracticingCount})
                </button>
              </>
            ) : (
              (
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
                  onClick={() => setAdminCategoryFilter(tab.id)}
                  className={cn(
                    'cursor-pointer rounded-[6px] border px-2.5 py-1 text-[11px] font-semibold transition-colors',
                    adminCategoryFilter === tab.id
                      ? 'border-primary bg-primary text-white'
                      : 'border-[#E2E8F0] bg-[#F8FAFC] text-ink-soft hover:border-[#CBD5E1] hover:text-ink',
                  )}
                >
                  {tab.label}
                </button>
              ))
            )}
          </div>
        </div>

        {/* Scrollable Psychologist Candidate Cards */}
        <div className="flex-1 space-y-3 overflow-y-auto p-5">
          {filteredPsychologists.length === 0 ? (
            <div className="rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-8 text-center text-xs text-ink-muted">
              Tidak ditemukan psikolog yang sesuai dengan kata kunci atau filter pencarian.
            </div>
          ) : (
            filteredPsychologists.map((psy) => {
              const isCurrentlyAssigned = referral.assignedPsychologistId === psy.id
              const categoryMeta = getPsychologistCategoryLabel(psy, partners)
              const activeCount = activeLoadByPsychologist[psy.id] ?? 0
              const weeklyQuota = psy.weeklyQuota ?? 6
              const isQuotaFull = activeCount >= weeklyQuota
              const isPracticeActive = psy.status === 'active' || !psy.status
              const isPracticeOnLeave = psy.status === 'on_leave'
              const isPracticeInactive = psy.status === 'inactive'

              const hasSpecMatch = psy.specializations.some((s) =>
                isSpecMatching(s, referralClinicalContext),
              )

              return (
                <div
                  key={psy.id}
                  className={cn(
                    'rounded-[12px] border p-4 transition-all',
                    isCurrentlyAssigned
                      ? 'border-primary bg-[#EEF0FF]/40 ring-1 ring-primary'
                      : hasSpecMatch && isPracticeActive
                        ? 'border-emerald-200 bg-emerald-50/20 hover:border-emerald-300'
                        : 'border-[#E2E8F0] bg-white hover:border-[#CBD5E1]',
                  )}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <div className="flex flex-wrap items-center gap-1.5">
                        {/* Only show category badge in admin view */}
                        {variant === 'admin' && (
                          <span
                            className={cn(
                              'rounded-[5px] border px-2 py-0.5 text-[10px] font-bold',
                              categoryMeta.badgeClass,
                            )}
                          >
                            {categoryMeta.badgeLabel}
                          </span>
                        )}

                        {/* Specialization Recommendation Highlight */}
                        {hasSpecMatch && isPracticeActive && (
                          <span className="inline-flex items-center gap-1 rounded-[5px] border border-emerald-300 bg-emerald-50 px-2 py-0.5 text-[10px] font-bold text-emerald-800">
                            <Sparkles className="size-3 text-emerald-600" />
                            Rekomendasi Spesialisasi
                          </span>
                        )}

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
                        {/* In admin view, show facility or community */}
                        {variant === 'admin' && (
                          <>
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
                          </>
                        )}
                        {psy.yearsExperience && (
                          <span>{psy.yearsExperience} thn pengalaman</span>
                        )}
                        {variant === 'partner' && (
                          <span className="font-mono text-[10px] text-ink-muted">
                            SIPP: {psy.sippNumber}
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Active Case Load & Availability Badge */}
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

                      <div className="mt-1">
                        {isPracticeOnLeave ? (
                          <span className="inline-flex items-center rounded-[4px] border border-amber-300 bg-amber-50 px-1.5 py-0.5 text-[10px] font-bold text-amber-800">
                            Sedang Cuti
                          </span>
                        ) : isPracticeInactive ? (
                          <span className="inline-flex items-center rounded-[4px] border border-slate-300 bg-slate-100 px-1.5 py-0.5 text-[10px] font-medium text-slate-700">
                            Nonaktif
                          </span>
                        ) : (
                          <span className="text-[10px] font-medium text-emerald-700">
                            Aktif Praktik
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Specializations Chips */}
                  <div className="mt-3 flex flex-wrap gap-1.5">
                    {psy.specializations.map((spec) => {
                      const match = isSpecMatching(spec, referralClinicalContext)
                      return (
                        <span
                          key={spec}
                          className={cn(
                            'rounded-[5px] border px-2 py-0.5 text-[11px]',
                            match
                              ? 'border-emerald-300 bg-emerald-50 font-semibold text-emerald-900'
                              : 'border-[#E2E8F0] bg-[#F8FAFC] font-medium text-ink-soft',
                          )}
                        >
                          {spec}
                        </span>
                      )
                    })}
                  </div>

                  {/* Schedule & Assign Action Row */}
                  <div className="mt-3.5 flex flex-col justify-between gap-2.5 border-t border-[#E2E8F0] pt-3 sm:flex-row sm:items-center">
                    <div className="flex items-center gap-1.5 text-xs text-ink-soft">
                      <Calendar className="size-3.5 shrink-0 text-primary" />
                      <span>
                        Jadwal: <strong className="text-ink">{psy.practiceSchedule}</strong>
                      </span>
                    </div>

                    {isCurrentlyAssigned ? (
                      <span className="inline-flex h-8 items-center justify-center gap-1.5 rounded-[8px] border border-primary/30 bg-[#EEF0FF] px-3 text-xs font-bold text-primary">
                        <UserCheck className="size-3.5" />
                        <span>Psikolog Terpilih</span>
                      </span>
                    ) : !isPracticeActive ? (
                      <span className="inline-flex h-8 items-center justify-center rounded-[8px] border border-slate-200 bg-slate-100 px-3 text-xs font-medium text-ink-muted">
                        Tidak Tersedia ({isPracticeOnLeave ? 'Cuti' : 'Nonaktif'})
                      </span>
                    ) : (
                      <button
                        type="button"
                        onClick={() => {
                          const nextStatus: ReferralStatus =
                            referral.status === 'completed' ? 'completed' : 'scheduled'
                          onAssign(referral.id, psy.id, nextStatus, psy.fullName)
                        }}
                        className="inline-flex h-8 shrink-0 cursor-pointer items-center justify-center gap-1.5 rounded-[8px] bg-primary px-3.5 text-xs font-semibold text-white transition-colors hover:bg-primary-hover focus:outline-none focus:ring-2 focus:ring-primary/20"
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
            Menampilkan {filteredPsychologists.length} dari {psychologists.length} psikolog
          </span>
          <button
            type="button"
            onClick={onClose}
            className="h-8 cursor-pointer rounded-[8px] border border-[#CBD5E1] bg-white px-3.5 font-semibold text-ink-soft transition-colors hover:bg-slate-50 hover:text-ink focus:outline-none focus:ring-2 focus:ring-primary/20"
          >
            Tutup Panel
          </button>
        </div>
      </div>
    </div>
  )
}
