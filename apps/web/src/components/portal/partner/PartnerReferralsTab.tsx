import {
  AlertCircle,
  Calendar,
  Clock,
  Filter,
  Search,
  Sparkles,
  UserCheck,
  X,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { cn } from '@/lib/cn'
import type { PatientReferral, Psychologist, ReferralStatus } from '@/types/portal'

interface PartnerReferralsTabProps {
  referrals: PatientReferral[]
  psychologists: Psychologist[]
  onAssignReferral: (
    referralId: string,
    psychologistId: string | null,
    status: ReferralStatus,
    patientCode: string,
  ) => void
}

type TriageStatusFilter = 'all' | 'unassigned' | 'scheduled' | 'completed'
type TriageSeverityFilter = 'all' | 'severe' | 'moderate'

interface SeverityChip {
  id: TriageSeverityFilter
  label: string
  isRed?: boolean
}

const SEVERITY_CHIPS: SeverityChip[] = [
  { id: 'all', label: 'Semua Tingkat Urgensi' },
  { id: 'severe', label: 'Severe & Extreme', isRed: true },
  { id: 'moderate', label: 'Moderate' },
]

export function PartnerReferralsTab({
  referrals,
  psychologists,
  onAssignReferral,
}: PartnerReferralsTabProps) {
  const [statusFilter, setStatusFilter] = useState<TriageStatusFilter>('all')
  const [severityFilter, setSeverityFilter] = useState<TriageSeverityFilter>('all')
  const [search, setSearch] = useState('')

  // Compute status counts for triage tabs
  const counts = useMemo(() => {
    return {
      all: referrals.length,
      unassigned: referrals.filter((r) => r.status === 'unassigned').length,
      scheduled: referrals.filter((r) => r.status === 'scheduled').length,
      completed: referrals.filter((r) => r.status === 'completed').length,
      severeUnassigned: referrals.filter(
        (r) =>
          r.status === 'unassigned' &&
          (r.dass21.severity === 'Severe' || r.dass21.severity === 'Extreme'),
      ).length,
    }
  }, [referrals])

  // Filter referrals based on status, severity, and search query
  const filteredReferrals = useMemo(() => {
    const q = search.trim().toLowerCase()
    return referrals.filter((ref) => {
      // 1. Status Filter
      if (statusFilter !== 'all' && ref.status !== statusFilter) return false

      // 2. Severity Filter
      const isSevere = ref.dass21.severity === 'Severe' || ref.dass21.severity === 'Extreme'
      const isModerate = ref.dass21.severity === 'Moderate'

      if (severityFilter === 'severe' && !isSevere) return false
      if (severityFilter === 'moderate' && !isModerate) return false

      // 3. Search Query
      if (!q) return true
      const assignedPsy = psychologists.find((p) => p.id === ref.assignedPsychologistId)
      return (
        ref.patientCode.toLowerCase().includes(q) ||
        ref.clinicalSummary.toLowerCase().includes(q) ||
        ref.preferredSchedule.toLowerCase().includes(q) ||
        (assignedPsy && assignedPsy.fullName.toLowerCase().includes(q))
      )
    })
  }, [referrals, psychologists, statusFilter, severityFilter, search])

  const activePsychologists = useMemo(
    () => psychologists.filter((p) => p.status === 'active'),
    [psychologists],
  )

  const handleResetFilters = () => {
    setStatusFilter('all')
    setSeverityFilter('all')
    setSearch('')
  }

  return (
    <section className="mt-6 space-y-4" aria-label="Rujukan Pasien EVA">
      {/* 1. Header Triage & Ringkasan Tanggap */}
      <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-4 sm:p-5 shadow-2xs">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <h2 className="text-base font-bold text-ink tracking-tight">
              Triage Antrean Rujukan Pasien EVA (DASS-21)
            </h2>
            <p className="mt-0.5 text-xs text-ink-muted leading-relaxed">
              Daftar skrining klinis awal yang dikirim atas persetujuan pengguna aplikasi EVA.
              Tugaskan psikolog faskes yang memiliki spesialisasi dan jadwal sesuai untuk
              menjadwalkan sesi konsultasi.
            </p>
          </div>

          {counts.unassigned > 0 && (
            <div className="flex shrink-0 items-center gap-2 rounded-[8px] border border-amber-300 bg-amber-50 px-3 py-1.5 text-xs font-bold text-amber-900">
              <AlertCircle className="size-4 shrink-0 text-amber-700" />
              <span>{counts.unassigned} Pasien Butuh Penugasan</span>
            </div>
          )}
        </div>

        {/* 2. Bilah Filter Status Triage & Pencarian */}
        <div className="mt-4 flex flex-col gap-3 border-t border-[#E2E8F0] pt-4">
          <div className="flex flex-col gap-2.5 sm:flex-row sm:items-center sm:justify-between">
            {/* Status Tabs */}
            <div className="flex flex-wrap items-center gap-1.5" role="tablist">
              <button
                type="button"
                onClick={() => setStatusFilter('all')}
                className={cn(
                  'inline-flex h-9 items-center gap-1.5 rounded-[8px] px-3 text-xs font-bold transition-all cursor-pointer',
                  statusFilter === 'all'
                    ? 'bg-primary text-white shadow-2xs'
                    : 'border border-[#CBD5E1] bg-white text-ink-muted hover:bg-[#F8FAFC] hover:text-ink',
                )}
              >
                <span>Semua</span>
                <span
                  className={cn(
                    'rounded-full px-1.5 py-0.2 text-[10px]',
                    statusFilter === 'all' ? 'bg-white/25 text-white' : 'bg-slate-100 text-ink-muted',
                  )}
                >
                  {counts.all}
                </span>
              </button>

              <button
                type="button"
                onClick={() => setStatusFilter('unassigned')}
                className={cn(
                  'inline-flex h-9 items-center gap-1.5 rounded-[8px] px-3 text-xs font-bold transition-all cursor-pointer',
                  statusFilter === 'unassigned'
                    ? 'bg-amber-600 text-white shadow-2xs'
                    : 'border border-[#CBD5E1] bg-white text-amber-900 hover:bg-amber-50',
                )}
              >
                <span>Butuh Penugasan</span>
                <span
                  className={cn(
                    'rounded-full px-1.5 py-0.2 text-[10px] font-bold',
                    statusFilter === 'unassigned'
                      ? 'bg-white/25 text-white'
                      : 'bg-amber-100 text-amber-900',
                  )}
                >
                  {counts.unassigned}
                </span>
              </button>

              <button
                type="button"
                onClick={() => setStatusFilter('scheduled')}
                className={cn(
                  'inline-flex h-9 items-center gap-1.5 rounded-[8px] px-3 text-xs font-bold transition-all cursor-pointer',
                  statusFilter === 'scheduled'
                    ? 'bg-primary text-white shadow-2xs'
                    : 'border border-[#CBD5E1] bg-white text-ink-muted hover:bg-[#F8FAFC] hover:text-ink',
                )}
              >
                <span>Terjadwal</span>
                <span
                  className={cn(
                    'rounded-full px-1.5 py-0.2 text-[10px]',
                    statusFilter === 'scheduled'
                      ? 'bg-white/25 text-white'
                      : 'bg-slate-100 text-ink-muted',
                  )}
                >
                  {counts.scheduled}
                </span>
              </button>

              <button
                type="button"
                onClick={() => setStatusFilter('completed')}
                className={cn(
                  'inline-flex h-9 items-center gap-1.5 rounded-[8px] px-3 text-xs font-bold transition-all cursor-pointer',
                  statusFilter === 'completed'
                    ? 'bg-primary text-white shadow-2xs'
                    : 'border border-[#CBD5E1] bg-white text-ink-muted hover:bg-[#F8FAFC] hover:text-ink',
                )}
              >
                <span>Selesai Konseling</span>
                <span
                  className={cn(
                    'rounded-full px-1.5 py-0.2 text-[10px]',
                    statusFilter === 'completed'
                      ? 'bg-white/25 text-white'
                      : 'bg-slate-100 text-ink-muted',
                  )}
                >
                  {counts.completed}
                </span>
              </button>
            </div>

            {/* Severity Filter Chips */}
            <div className="flex flex-wrap items-center gap-1 text-xs">
              <span className="text-[11px] font-semibold text-ink-muted flex items-center gap-1 mr-1">
                <Filter className="size-3 text-ink-muted/80" />
                <span>Urgensi:</span>
              </span>
              {SEVERITY_CHIPS.map((chip) => (
                <button
                  key={chip.id}
                  type="button"
                  onClick={() => setSeverityFilter(chip.id)}
                  className={cn(
                    'rounded-[6px] px-2.5 py-1 text-xs font-semibold transition-all cursor-pointer',
                    severityFilter === chip.id
                      ? chip.isRed
                        ? 'bg-red-600 text-white shadow-2xs'
                        : 'bg-slate-800 text-white shadow-2xs'
                      : 'border border-[#E2E8F0] bg-white text-ink-muted hover:bg-slate-50',
                  )}
                >
                  {chip.label}
                </button>
              ))}
            </div>
          </div>

          {/* Search Bar Input */}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-ink-muted" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Cari kode pasien (#REF-...), keluhan pra-konseling, preferensi jadwal, atau nama psikolog PJ..."
              className="h-10 w-full rounded-[10px] border border-[#CBD5E1] bg-white pl-9 pr-9 text-xs text-ink placeholder:text-ink-muted focus:border-primary focus:outline-none"
            />
            {search && (
              <button
                type="button"
                onClick={() => setSearch('')}
                aria-label="Bersihkan pencarian"
                className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-muted hover:text-ink"
              >
                <X className="size-4" />
              </button>
            )}
          </div>
        </div>
      </div>

      {/* 3. Daftar Kartu Triage Pasien */}
      {filteredReferrals.length === 0 ? (
        <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-10 text-center shadow-2xs">
          <p className="text-sm font-semibold text-ink">Tidak ada rujukan pasien yang sesuai.</p>
          <p className="mt-1 text-xs text-ink-muted">
            Coba ubah kata kunci pencarian atau bersihkan filter status dan urgensi DASS-21.
          </p>
          {(statusFilter !== 'all' || severityFilter !== 'all' || search) && (
            <button
              type="button"
              onClick={handleResetFilters}
              className="mt-4 inline-flex h-9 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] px-4 text-xs font-semibold text-ink transition-colors hover:bg-slate-100"
            >
              Reset Semua Filter
            </button>
          )}
        </div>
      ) : (
        <div className="space-y-3.5">
          {filteredReferrals.map((ref) => {
            const assignedPsy = psychologists.find((p) => p.id === ref.assignedPsychologistId)
            const isSevere =
              ref.dass21.severity === 'Severe' || ref.dass21.severity === 'Extreme'
            const isModerate = ref.dass21.severity === 'Moderate'
            const isUnassigned = ref.status === 'unassigned'

            // Temukan rekomendasi psikolog yang memiliki spesialisasi cocok dengan keluhan
            const recommendedPsy = activePsychologists.find((p) =>
              p.specializations.some((s) =>
                ref.clinicalSummary.toLowerCase().includes(s.toLowerCase()),
              ),
            )

            return (
              <div
                key={ref.id}
                className={cn(
                  'rounded-[14px] border bg-white p-4 sm:p-5 shadow-2xs transition-all',
                  isSevere
                    ? 'border-l-4 border-l-[#DC2626] border-[#FECACA] bg-[#FEF2F2]/15'
                    : isModerate
                      ? 'border-l-4 border-l-[#D97706] border-[#FDE68A] bg-[#FFFBEB]/15'
                      : 'border-l-4 border-l-[#0284C7] border-[#E2E8F0]',
                )}
              >
                {/* Header Kartu: Kode Pasien, Demografi, Status DASS-21, dan Jadwal Preferensi */}
                <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 border-b border-[#E2E8F0] pb-3.5">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-mono text-sm font-bold text-ink tracking-tight">
                        {ref.patientCode}
                      </span>
                      <span className="rounded-[6px] bg-[#F1F5F9] px-2 py-0.5 text-xs font-medium text-ink-soft">
                        {ref.gender}, {ref.age} tahun
                      </span>
                      <span
                        className={cn(
                          'inline-flex items-center gap-1 rounded-[6px] px-2 py-0.5 text-xs font-bold',
                          isSevere
                            ? 'border border-red-300 bg-red-100 text-red-900'
                            : isModerate
                              ? 'border border-amber-300 bg-amber-100 text-amber-900'
                              : 'border border-sky-300 bg-sky-100 text-sky-900',
                        )}
                      >
                        {isSevere && <AlertCircle className="size-3 text-red-700" />}
                        <span>DASS-21: {ref.dass21.severity}</span>
                      </span>

                      {isUnassigned && (
                        <span className="inline-flex items-center gap-1 rounded-[6px] border border-amber-400 bg-amber-100 px-2 py-0.5 text-[10px] font-bold text-amber-950">
                          Butuh Penugasan Segera
                        </span>
                      )}
                    </div>

                    <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-ink-muted">
                      <span className="flex items-center gap-1">
                        <Clock className="size-3.5 text-ink-muted/80" />
                        <span>Diterima: {ref.submittedAt}</span>
                      </span>
                      <span>·</span>
                      <span className="flex items-center gap-1">
                        <Calendar className="size-3.5 text-ink-muted/80" />
                        <span>
                          Preferensi Jadwal:{' '}
                          <strong className="text-ink">{ref.preferredSchedule}</strong>
                        </span>
                      </span>
                    </div>
                  </div>

                  {/* Skor Rincian Klinis DASS-21 */}
                  <div className="flex flex-wrap items-center gap-1.5 self-start text-xs">
                    <span className="rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 py-1 text-ink-soft shadow-2xs">
                      Depresi: <strong className="text-ink">{ref.dass21.depression}</strong>
                    </span>
                    <span className="rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 py-1 text-ink-soft shadow-2xs">
                      Kecemasan: <strong className="text-ink">{ref.dass21.anxiety}</strong>
                    </span>
                    <span className="rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 py-1 text-ink-soft shadow-2xs">
                      Stres: <strong className="text-ink">{ref.dass21.stress}</strong>
                    </span>
                  </div>
                </div>

                {/* Ringkasan Kondisi Pra-Konseling */}
                <div className="mt-3.5 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3 text-xs leading-relaxed text-ink">
                  <p className="font-bold text-ink-muted mb-1 flex items-center gap-1">
                    <Sparkles className="size-3 text-primary" />
                    <span>Ringkasan Kondisi Klinis Awal:</span>
                  </p>
                  <p>{ref.clinicalSummary}</p>
                </div>

                {/* Footer Penugasan Cepat Triage */}
                <div className="mt-4 flex flex-col justify-between gap-3 rounded-[10px] border border-[#CBD5E1] bg-white p-3 sm:flex-row sm:items-center">
                  <div className="flex flex-wrap items-center gap-2 text-xs">
                    <UserCheck className="size-4 text-primary shrink-0" />
                    <span className="text-ink-muted">Penanggung Jawab:</span>
                    <span className="font-bold text-ink">
                      {assignedPsy ? assignedPsy.fullName : 'Belum Ada Psikolog Ditugaskan'}
                    </span>
                    {isUnassigned && recommendedPsy && (
                      <span className="inline-flex items-center gap-1 rounded-[4px] bg-indigo-50 border border-indigo-200 px-1.5 py-0.5 text-[10px] font-semibold text-indigo-800">
                        Disarankan: {recommendedPsy.fullName.split(' ')[0]}
                      </span>
                    )}
                  </div>

                  {/* Kontrol Penugasan Psikolog & Status */}
                  <div className="flex flex-wrap items-center gap-2">
                    <select
                      aria-label={`Pilih psikolog faskes untuk ${ref.patientCode}`}
                      value={ref.assignedPsychologistId ?? ''}
                      onChange={(e) => {
                        const nextPsyId = e.target.value || null
                        const nextStatus: ReferralStatus = nextPsyId
                          ? ref.status === 'unassigned'
                            ? 'scheduled'
                            : ref.status
                          : 'unassigned'
                        onAssignReferral(ref.id, nextPsyId, nextStatus, ref.patientCode)
                      }}
                      className="h-9 min-w-[200px] rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink shadow-2xs outline-none focus:border-primary cursor-pointer"
                    >
                      <option value="">(Pilih Psikolog Faskes)</option>
                      {activePsychologists.map((p) => (
                        <option key={p.id} value={p.id}>
                          {p.fullName} ({p.specializations.slice(0, 1).join(', ')})
                        </option>
                      ))}
                    </select>

                    <select
                      aria-label={`Ubah status rujukan ${ref.patientCode}`}
                      value={ref.status}
                      onChange={(e) =>
                        onAssignReferral(
                          ref.id,
                          ref.assignedPsychologistId,
                          e.target.value as ReferralStatus,
                          ref.patientCode,
                        )
                      }
                      className={cn(
                        'h-9 rounded-[8px] border px-3 text-xs font-bold outline-none cursor-pointer shadow-2xs',
                        ref.status === 'unassigned' &&
                          'border-amber-300 bg-amber-50 text-amber-900',
                        ref.status === 'scheduled' &&
                          'border-primary/40 bg-primary/10 text-primary',
                        ref.status === 'completed' &&
                          'border-emerald-300 bg-emerald-50 text-emerald-900',
                      )}
                    >
                      <option value="unassigned">Menunggu Penugasan</option>
                      <option value="scheduled">Terjadwal</option>
                      <option value="completed">Selesai Konseling</option>
                    </select>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </section>
  )
}

