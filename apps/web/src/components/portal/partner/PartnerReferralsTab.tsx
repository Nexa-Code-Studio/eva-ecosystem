import {
  Calendar,
  CheckCircle2,
  Clock,
  RefreshCw,
  Search,
  Stethoscope,
  UserPlus,
  X,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { cn } from '@/lib/cn'
import {
  usePortalDb,
  type PartnerAccount,
  type PatientReferral,
  type Psychologist,
  type ReferralStatus,
} from '@/lib/portalStore'
import { ReferralAssignmentDrawer } from '@/components/portal/admin/ReferralAssignmentDrawer'

interface PartnerReferralsTabProps {
  referrals: PatientReferral[]
  psychologists: Psychologist[]
  partners?: PartnerAccount[]
  allReferrals?: PatientReferral[]
  onAssignReferral: (
    referralId: string,
    psychologistId: string | null,
    status: ReferralStatus,
    patientCode: string,
  ) => void
}

type TriageStatusFilter = 'all' | ReferralStatus

export function PartnerReferralsTab({
  referrals,
  psychologists,
  partners: propsPartners,
  allReferrals: propsAllReferrals,
  onAssignReferral,
}: PartnerReferralsTabProps) {
  const { db } = usePortalDb()
  const partners = propsPartners ?? db.partners
  const allReferrals = propsAllReferrals ?? db.referrals

  const [statusFilter, setStatusFilter] = useState<TriageStatusFilter>('all')
  const [search, setSearch] = useState('')
  const [activeDrawerReferralId, setActiveDrawerReferralId] = useState<string | null>(null)

  // Compute status counts for triage summary and toolbar tabs
  const counts = useMemo(() => {
    return {
      all: referrals.length,
      unassigned: referrals.filter((r) => r.status === 'unassigned').length,
      scheduled: referrals.filter((r) => r.status === 'scheduled').length,
      completed: referrals.filter((r) => r.status === 'completed').length,
    }
  }, [referrals])

  // Filter referrals based on status filter and search query
  const filteredReferrals = useMemo(() => {
    const q = search.trim().toLowerCase()
    return referrals.filter((ref) => {
      // 1. Status Filter
      if (statusFilter !== 'all' && ref.status !== statusFilter) return false

      // 2. Search Query
      if (!q) return true
      const assignedPsy = psychologists.find((p) => p.id === ref.assignedPsychologistId)
      return (
        ref.patientCode.toLowerCase().includes(q) ||
        ref.clinicalSummary.toLowerCase().includes(q) ||
        ref.preferredSchedule.toLowerCase().includes(q) ||
        (assignedPsy && assignedPsy.fullName.toLowerCase().includes(q))
      )
    })
  }, [referrals, psychologists, statusFilter, search])

  const activeDrawerReferral = useMemo(
    () => referrals.find((r) => r.id === activeDrawerReferralId) ?? null,
    [referrals, activeDrawerReferralId],
  )

  const handleResetFilters = () => {
    setStatusFilter('all')
    setSearch('')
  }

  return (
    <section className="mt-6 space-y-4" aria-label="Rujukan Pasien EVA">
      {/* 1. Header Modul Rujukan & Pill Metrik (Identik Admin) */}
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h2 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Rujukan Pasien Klinis (DASS-21)
          </h2>
          <p className="mt-0.5 text-xs text-ink-muted">
            Kelola antrean dan penugasan pasien rujukan hasil skrining DASS-21 ke psikolog naungan fasilitas kesehatan Anda.
          </p>
        </div>

        <div className="inline-flex items-center gap-2 rounded-[8px] border border-[#E2E8F0] bg-white px-3 py-1.5 text-xs font-semibold text-ink">
          <span>Total Rujukan: {counts.all}</span>
          {counts.unassigned > 0 && (
            <span className="rounded-[4px] bg-[#FEE2E2] px-2 py-0.5 text-[11px] font-bold text-[#991B1B]">
              {counts.unassigned} Belum Ditugaskan
            </span>
          )}
        </div>
      </div>

      {/* 2. Toolbar: Segmented Tabs & Instant Search Bar (Identik Admin) */}
      <div className="flex flex-col justify-between gap-3 rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 sm:flex-row sm:items-center">
        {/* Status Segmented Buttons */}
        <div className="inline-flex flex-wrap rounded-[8px] bg-[#F1F5F9] p-1 text-xs">
          {(
            [
              { id: 'all', label: `Semua (${counts.all})` },
              {
                id: 'unassigned',
                label: `Belum Ditugaskan (${counts.unassigned})`,
              },
              { id: 'scheduled', label: `Terjadwal (${counts.scheduled})` },
              { id: 'completed', label: `Selesai Konseling (${counts.completed})` },
            ] as const
          ).map((tab) => {
            const isActive = statusFilter === tab.id
            return (
              <button
                key={tab.id}
                type="button"
                onClick={() => setStatusFilter(tab.id)}
                className={cn(
                  'cursor-pointer rounded-[6px] px-3 py-1 font-semibold transition-colors',
                  isActive
                    ? 'bg-white text-ink shadow-2xs'
                    : 'text-ink-soft hover:text-ink',
                )}
              >
                {tab.label}
              </button>
            )
          })}
        </div>

        {/* Search Input Box */}
        <div className="relative min-w-[260px] sm:w-72">
          <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
          <input
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari kode (#REF-...), keluhan, jadwal..."
            className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-8 pl-8 text-xs text-ink placeholder:text-ink-muted focus:border-primary focus:bg-white focus:outline-none"
          />
          {search && (
            <button
              type="button"
              onClick={() => setSearch('')}
              className="absolute top-1/2 right-2.5 -translate-y-1/2 text-ink-muted hover:text-ink cursor-pointer"
              aria-label="Bersihkan pencarian"
            >
              <X className="size-3.5" />
            </button>
          )}
        </div>
      </div>

      {/* 3. Daftar Kartu Rujukan Pasien (Identik Admin) */}
      <div className="space-y-3.5">
        {filteredReferrals.length === 0 ? (
          <div className="rounded-[12px] border border-dashed border-[#CBD5E1] bg-white p-8 text-center">
            <p className="text-sm font-semibold text-ink">
              Tidak ada rujukan pasien yang sesuai kriteria.
            </p>
            <p className="mt-1 text-xs text-ink-muted">
              Coba sesuaikan kata kunci pencarian atau ubah filter status rujukan.
            </p>
            {(statusFilter !== 'all' || search) && (
              <button
                type="button"
                onClick={handleResetFilters}
                className="mt-3 inline-flex cursor-pointer items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-white px-3 py-1.5 text-xs font-semibold text-ink transition-colors hover:bg-slate-50"
              >
                Reset Filter
              </button>
            )}
          </div>
        ) : (
          filteredReferrals.map((ref) => {
            const assignedPsy = psychologists.find(
              (p) => p.id === ref.assignedPsychologistId,
            )

            return (
              <div
                key={ref.id}
                className="rounded-[12px] border border-[#E2E8F0] bg-white p-5 transition-colors hover:border-[#CBD5E1]"
              >
                {/* Card Header: Patient Identity & DASS-21 Score (Identik Admin) */}
                <div className="flex flex-wrap items-start justify-between gap-4 border-b border-[#E2E8F0] pb-4">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-mono text-sm font-bold text-ink">
                        {ref.patientCode}
                      </span>
                      <span className="text-xs text-ink-muted">
                        · {ref.gender}, {ref.age} tahun · Masuk:{' '}
                        {new Date(ref.submittedAt).toLocaleDateString('id-ID', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </span>

                      {/* Pill Status Rujukan */}
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
                        {ref.status === 'completed' && <CheckCircle2 className="size-3" />}
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

                  {/* DASS-21 Severity Badge */}
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

                {/* Clinical Summary (Teks bersih mengalir bebas kotak tebal, identik Admin) */}
                <p className="mt-3 text-xs leading-relaxed text-ink-soft">
                  {ref.clinicalSummary}
                </p>

                {/* Contextual Assignment & Action Footer (Identik Admin) */}
                {!assignedPsy || ref.status === 'unassigned' ? (
                  <div className="mt-4 flex flex-col justify-between gap-3 rounded-[10px] border border-amber-200/80 bg-amber-50/50 p-3.5 sm:flex-row sm:items-center">
                    <div className="flex items-start gap-2.5 text-xs">
                      <span className="mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-[7px] bg-amber-100 text-amber-800">
                        <Clock className="size-3.5" />
                      </span>
                      <div>
                        <p className="font-bold text-amber-950">
                          Menunggu Penempatan Psikolog Faskes
                        </p>
                        <p className="text-[11px] text-amber-800/90">
                          Pilih psikolog internal faskes yang sesuai dengan jadwal preferensi dan profil klinis pasien.
                        </p>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => setActiveDrawerReferralId(ref.id)}
                      className="inline-flex h-9 shrink-0 cursor-pointer items-center justify-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-primary-hover focus:outline-none focus:ring-2 focus:ring-primary/20"
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
                          <span className="rounded-[4px] border border-emerald-200 bg-emerald-50 px-1.5 py-0.5 text-[10px] font-bold text-emerald-800">
                            Psikolog Faskes
                          </span>
                        </div>

                        <p className="mt-1 text-[11px] text-ink-muted">
                          Jadwal Praktik: <strong className="text-ink">{assignedPsy.practiceSchedule}</strong>
                          {assignedPsy.specializations.length > 0 &&
                            ` · ${assignedPsy.specializations.slice(0, 2).join(', ')}`}
                        </p>
                      </div>
                    </div>

                    {/* Action Controls: Tandai Selesai & Ganti Psikolog (Identik Admin) */}
                    <div className="flex flex-wrap items-center gap-2 self-start sm:self-auto">
                      {ref.status === 'scheduled' ? (
                        <>
                          <button
                            type="button"
                            onClick={() => {
                              onAssignReferral(
                                ref.id,
                                ref.assignedPsychologistId,
                                'completed',
                                ref.patientCode,
                              )
                            }}
                            className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[8px] bg-emerald-600 px-3 text-xs font-semibold text-white transition-colors hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
                          >
                            <CheckCircle2 className="size-3.5" />
                            <span>Tandai Selesai</span>
                          </button>

                          <button
                            type="button"
                            onClick={() => setActiveDrawerReferralId(ref.id)}
                            className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink-soft transition-colors hover:border-primary hover:text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                          >
                            <RefreshCw className="size-3" />
                            <span>Ganti Psikolog</span>
                          </button>
                        </>
                      ) : (
                        <>
                          <span className="inline-flex h-8 items-center gap-1 rounded-[8px] border border-emerald-200 bg-white px-2.5 text-xs font-bold text-emerald-800">
                            <CheckCircle2 className="size-3.5" />
                            <span>Konseling Selesai</span>
                          </span>

                          <button
                            type="button"
                            onClick={() => setActiveDrawerReferralId(ref.id)}
                            className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink-soft transition-colors hover:border-primary hover:text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
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

      {/* 4. Slide-Over Drawer Penugasan Tim Klinis Faskes */}
      <ReferralAssignmentDrawer
        referral={activeDrawerReferral}
        psychologists={psychologists}
        partners={partners}
        allReferrals={allReferrals}
        variant="partner"
        onClose={() => setActiveDrawerReferralId(null)}
        onAssign={(referralId, psychologistId, nextStatus) => {
          const targetRef = referrals.find((r) => r.id === referralId)
          onAssignReferral(
            referralId,
            psychologistId,
            nextStatus,
            targetRef?.patientCode ?? 'Pasien',
          )
          setActiveDrawerReferralId(null)
        }}
      />
    </section>
  )
}
