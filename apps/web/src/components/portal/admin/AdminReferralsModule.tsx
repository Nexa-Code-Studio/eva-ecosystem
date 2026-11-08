import {
  Building2,
  Calendar,
  CheckCircle2,
  Clock,
  MapPin,
  RefreshCw,
  Search,
  Stethoscope,
  UserPlus,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { ReferralAssignmentDrawer } from './ReferralAssignmentDrawer'
import { cn } from '@/lib/cn'
import {
  assignReferral,
  type PartnerAccount,
  type PortalDatabase,
  type Psychologist,
  type ReferralStatus,
} from '@/lib/portalStore'

function getPsychologistCategoryLabel(
  psy: Psychologist,
  partners: PartnerAccount[],
): { badgeLabel: string; facilityOrRoleName: string; badgeClass: string } {
  if (psy.role === 'professional_mitra' || psy.practiceType === 'faskes') {
    const partner = psy.partnerId
      ? partners.find((p) => p.id === psy.partnerId)
      : undefined
    return {
      badgeLabel: 'Psikolog Mitra Faskes',
      facilityOrRoleName: partner?.facilityName ?? 'Mitra Faskes EVA',
      badgeClass: 'border-[#BFDBFE] bg-[#EFF6FF] text-[#1E40AF]',
    }
  }

  if (psy.role === 'relawan_profesional') {
    return {
      badgeLabel: 'Relawan Profesional',
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

interface AdminReferralsModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

type ReferralStatusFilter = 'all' | ReferralStatus

export function AdminReferralsModule({
  db,
  onFeedback,
}: AdminReferralsModuleProps) {
  const [statusFilter, setStatusFilter] = useState<ReferralStatusFilter>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [activeDrawerReferralId, setActiveDrawerReferralId] = useState<string | null>(
    null,
  )

  const assignablePsychologists = useMemo(
    () =>
      db.psychologists.filter(
        (p) => p.verificationStatus === 'approved' && p.status === 'active',
      ),
    [db.psychologists],
  )

  const statusCounts = useMemo(() => {
    const unassigned = db.referrals.filter((r) => r.status === 'unassigned').length
    const scheduled = db.referrals.filter((r) => r.status === 'scheduled').length
    const completed = db.referrals.filter((r) => r.status === 'completed').length
    return {
      all: db.referrals.length,
      unassigned,
      scheduled,
      completed,
    }
  }, [db.referrals])

  const filteredReferrals = useMemo(() => {
    const q = searchQuery.trim().toLowerCase()
    return db.referrals.filter((ref) => {
      if (statusFilter !== 'all' && ref.status !== statusFilter) return false
      if (!q) return true

      const assignedPsy = db.psychologists.find(
        (p) => p.id === ref.assignedPsychologistId,
      )
      return (
        ref.patientCode.toLowerCase().includes(q) ||
        ref.clinicalSummary.toLowerCase().includes(q) ||
        ref.preferredSchedule.toLowerCase().includes(q) ||
        (assignedPsy?.fullName.toLowerCase().includes(q) ?? false)
      )
    })
  }, [db.referrals, db.psychologists, statusFilter, searchQuery])

  const activeDrawerReferral = useMemo(
    () => db.referrals.find((r) => r.id === activeDrawerReferralId) ?? null,
    [db.referrals, activeDrawerReferralId],
  )

  const handleAssignFromDrawer = (
    referralId: string,
    psychologistId: string | null,
    nextStatus: ReferralStatus,
    psychologistName?: string,
  ) => {
    const targetRef = db.referrals.find((r) => r.id === referralId)
    assignReferral(referralId, psychologistId, nextStatus)

    if (psychologistId && psychologistName) {
      onFeedback(
        `Rujukan pasien "${targetRef?.patientCode ?? referralId}" berhasil ditugaskan kepada ${psychologistName}.`,
      )
    } else {
      onFeedback(
        `Penugasan rujukan "${targetRef?.patientCode ?? referralId}" telah dilepas kembali ke antrean.`,
      )
    }
    setActiveDrawerReferralId(null)
  }

  return (
    <div>
      {/* Header */}
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Rujukan Pasien Klinis (DASS-21)
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Kelola penugasan pasien rujukan hasil skrining DASS-21 ke mitra faskes atau psikolog klinis / relawan pendamping.
          </p>
        </div>

        <div className="inline-flex items-center gap-2 rounded-[8px] border border-[#E2E8F0] bg-white px-3 py-1.5 text-xs font-semibold text-ink">
          <span>Total Rujukan: {statusCounts.all}</span>
          {statusCounts.unassigned > 0 && (
            <span className="rounded-[4px] bg-[#FEE2E2] px-2 py-0.5 text-[11px] font-bold text-[#991B1B]">
              {statusCounts.unassigned} Belum Ditugaskan
            </span>
          )}
        </div>
      </div>

      {/* Filter & Search Toolbar */}
      <div className="mt-5 flex flex-col justify-between gap-3 rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 sm:flex-row sm:items-center">
        <div className="inline-flex flex-wrap rounded-[8px] bg-[#F1F5F9] p-1 text-xs">
          {(
            [
              { id: 'all', label: `Semua (${statusCounts.all})` },
              {
                id: 'unassigned',
                label: `Belum Ditugaskan (${statusCounts.unassigned})`,
              },
              {
                id: 'scheduled',
                label: `Terjadwal (${statusCounts.scheduled})`,
              },
              {
                id: 'completed',
                label: `Selesai Konseling (${statusCounts.completed})`,
              },
            ] as const
          ).map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setStatusFilter(tab.id)}
              className={cn(
                'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
                statusFilter === tab.id
                  ? 'bg-white text-ink shadow-2xs'
                  : 'text-ink-muted hover:text-ink',
              )}
            >
              {tab.label}
            </button>
          ))}
        </div>

        <div className="relative w-full sm:w-72">
          <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
          <input
            type="search"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Cari kode pasien, keluhan, psikolog..."
            className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink focus:border-primary focus:bg-white focus:outline-none"
          />
        </div>
      </div>

      {/* Referral Cards List */}
      <div className="mt-4 space-y-4">
        {filteredReferrals.length === 0 ? (
          <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-8 text-center text-xs text-ink-muted">
            Tidak ada data rujukan pasien yang sesuai dengan filter pencarian saat ini.
          </div>
        ) : (
          filteredReferrals.map((ref) => {
            const assignedPsy = db.psychologists.find(
              (p) => p.id === ref.assignedPsychologistId,
            )
            const categoryMeta = assignedPsy
              ? getPsychologistCategoryLabel(assignedPsy, db.partners)
              : null

            return (
              <div
                key={ref.id}
                className="rounded-[12px] border border-[#E2E8F0] bg-white p-5 transition-colors hover:border-[#CBD5E1]"
              >
                {/* Card Header: Patient Identity & DASS-21 Score */}
                <div className="flex flex-wrap items-start justify-between gap-4 border-b border-[#E2E8F0] pb-4">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-mono text-sm font-bold text-ink">
                        {ref.patientCode}
                      </span>
                      <span className="text-xs text-ink-muted">
                        · {ref.gender}, {ref.age} tahun · Masuk: {ref.submittedAt}
                      </span>
                      <span
                        className={cn(
                          'inline-flex items-center gap-1 rounded-[5px] px-2 py-0.5 text-[11px] font-semibold',
                          ref.status === 'unassigned'
                            ? 'bg-amber-50 text-amber-800'
                            : ref.status === 'scheduled'
                              ? 'bg-[#EEF0FF] text-primary'
                              : 'bg-emerald-50 text-emerald-800',
                        )}
                      >
                        {ref.status === 'unassigned' && <Clock className="size-3" />}
                        {ref.status === 'scheduled' && <Calendar className="size-3" />}
                        {ref.status === 'completed' && (
                          <CheckCircle2 className="size-3" />
                        )}
                        {ref.status === 'unassigned'
                          ? 'Belum Ditugaskan'
                          : ref.status === 'scheduled'
                            ? 'Terjadwal'
                            : 'Selesai Konseling'}
                      </span>
                    </div>
                    <p className="mt-1.5 flex items-center gap-1.5 text-xs text-ink-soft">
                      <Calendar className="size-3.5 text-primary" />
                      <span>
                        Jadwal Preferensi Pasien:{' '}
                        <strong className="text-ink">{ref.preferredSchedule}</strong>
                      </span>
                    </p>
                  </div>

                  <span
                    className={cn(
                      'rounded-[6px] border px-2.5 py-1 text-xs font-bold',
                      ref.dass21.severity === 'Extreme'
                        ? 'border-[#FECACA] bg-[#FEF2F2] text-[#991B1B]'
                        : ref.dass21.severity === 'Severe'
                          ? 'border-[#FDE68A] bg-[#FEF3C7] text-[#92400E]'
                          : 'border-[#BFDBFE] bg-[#EFF6FF] text-[#1E40AF]',
                    )}
                  >
                    DASS-21: {ref.dass21.severity} (D:{ref.dass21.depression} / A:
                    {ref.dass21.anxiety} / S:{ref.dass21.stress})
                  </span>
                </div>

                {/* Clinical Summary */}
                <p className="mt-3 text-xs leading-relaxed text-ink-soft">
                  {ref.clinicalSummary}
                </p>

                {/* Contextual Assignment & Action Footer */}
                {!assignedPsy || ref.status === 'unassigned' ? (
                  <div className="mt-4 flex flex-col justify-between gap-3 rounded-[10px] border border-amber-200/80 bg-amber-50/50 p-3.5 sm:flex-row sm:items-center">
                    <div className="flex items-start gap-2.5 text-xs">
                      <span className="mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-[7px] bg-amber-100 text-amber-800">
                        <Clock className="size-3.5" />
                      </span>
                      <div>
                        <p className="font-bold text-amber-950">
                          Menunggu Penempatan Psikolog / Relawan
                        </p>
                        <p className="text-[11px] text-amber-800/90">
                          Pilih psikolog mitra faskes atau relawan yang sesuai dengan jadwal preferensi dan profil klinis pasien.
                        </p>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => setActiveDrawerReferralId(ref.id)}
                      className="inline-flex h-9 shrink-0 cursor-pointer items-center justify-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-primary-hover"
                    >
                      <UserPlus className="size-3.5" />
                      <span>Pilih &amp; Tugaskan Psikolog</span>
                    </button>
                  </div>
                ) : (
                  <div
                    className={cn(
                      'mt-4 flex flex-col justify-between gap-3 rounded-[10px] border p-3.5 sm:flex-row sm:items-center',
                      ref.status === 'completed'
                        ? 'border-emerald-200 bg-emerald-50/40'
                        : 'border-[#E2E8F0] bg-[#F8FAFC]',
                    )}
                  >
                    <div className="flex items-start gap-3">
                      <span
                        className={cn(
                          'mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-[8px]',
                          ref.status === 'completed'
                            ? 'bg-emerald-100 text-emerald-700'
                            : 'bg-[#EEF0FF] text-primary',
                        )}
                      >
                        <Stethoscope className="size-4" />
                      </span>

                      <div className="text-xs">
                        <div className="flex flex-wrap items-center gap-1.5">
                          <span className="text-[11px] text-ink-muted">
                            Ditangani oleh:
                          </span>
                          <span className="font-bold text-ink">
                            {assignedPsy.fullName}
                          </span>
                          {categoryMeta && (
                            <span
                              className={cn(
                                'rounded-[4px] border px-1.5 py-0.5 text-[10px] font-bold',
                                categoryMeta.badgeClass,
                              )}
                            >
                              {categoryMeta.badgeLabel}
                            </span>
                          )}
                        </div>

                        <div className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-ink-muted">
                          {categoryMeta && (
                            <span className="inline-flex items-center gap-1">
                              <Building2 className="size-3" />
                              {categoryMeta.facilityOrRoleName}
                            </span>
                          )}
                          {assignedPsy.city && (
                            <span className="inline-flex items-center gap-1">
                              <MapPin className="size-3" />
                              {assignedPsy.city}
                            </span>
                          )}
                          <span className="inline-flex items-center gap-1 text-ink-soft">
                            <Calendar className="size-3 text-primary" />
                            Jadwal Praktik: <strong>{assignedPsy.practiceSchedule}</strong>
                          </span>
                        </div>
                      </div>
                    </div>

                    <div className="flex flex-wrap items-center gap-2">
                      {ref.status === 'scheduled' ? (
                        <>
                          <button
                            type="button"
                            onClick={() => {
                              assignReferral(
                                ref.id,
                                ref.assignedPsychologistId,
                                'completed',
                              )
                              onFeedback(
                                `Status rujukan "${ref.patientCode}" ditandai Selesai Konseling bersama ${assignedPsy.fullName}.`,
                              )
                            }}
                            className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[8px] bg-emerald-600 px-3 text-xs font-semibold text-white transition-colors hover:bg-emerald-700"
                          >
                            <CheckCircle2 className="size-3.5" />
                            <span>Tandai Selesai</span>
                          </button>

                          <button
                            type="button"
                            onClick={() => setActiveDrawerReferralId(ref.id)}
                            className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink-soft transition-colors hover:border-primary hover:text-primary"
                          >
                            <RefreshCw className="size-3" />
                            <span>Ganti Psikolog</span>
                          </button>
                        </>
                      ) : (
                        <>
                          <span className="inline-flex h-8 items-center gap-1 rounded-[8px] border border-emerald-200 bg-white px-2.5 text-xs font-bold text-emerald-700">
                            <CheckCircle2 className="size-3.5" />
                            <span>Konseling Selesai</span>
                          </span>

                          <button
                            type="button"
                            onClick={() => setActiveDrawerReferralId(ref.id)}
                            className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink-soft transition-colors hover:border-primary hover:text-primary"
                          >
                            <RefreshCw className="size-3" />
                            <span>Kelola Penugasan</span>
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                )}
              </div>
            )
          })
        )}
      </div>

      {/* Right-Hand Slide-Over Clinical Assignment Drawer */}
      <ReferralAssignmentDrawer
        referral={activeDrawerReferral}
        psychologists={assignablePsychologists}
        partners={db.partners}
        allReferrals={db.referrals}
        onClose={() => setActiveDrawerReferralId(null)}
        onAssign={handleAssignFromDrawer}
      />
    </div>
  )
}
