import { UserCheck } from 'lucide-react'
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

export function PartnerReferralsTab({
  referrals,
  psychologists,
  onAssignReferral,
}: PartnerReferralsTabProps) {
  return (
    <section className="mt-6 space-y-4" aria-label="Rujukan Pasien EVA">
      <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
        <h2 className="text-sm font-semibold text-ink">
          Daftar Rujukan Klinis Pasien EVA (DASS-21 Intake Summary)
        </h2>
        <p className="mt-0.5 text-xs text-ink-soft">
          Ringkasan kondisi awal di bawah ini dikirim atas persetujuan pengguna aplikasi EVA tanpa
          menyertakan transkrip obrolan pribadi. Tugaskan psikolog aktif untuk menjadwalkan sesi
          konsultasi.
        </p>
      </div>

      {referrals.length === 0 ? (
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-10 text-center text-xs text-ink-muted">
          Belum ada rujukan pasien yang masuk ke fasilitas kesehatan Anda.
        </div>
      ) : (
        <div className="grid gap-4">
          {referrals.map((ref) => {
            const assignedPsy = psychologists.find((p) => p.id === ref.assignedPsychologistId)
            return (
              <div
                key={ref.id}
                className="rounded-[12px] border border-[#E2E8F0] bg-white p-5 shadow-[0_1px_2px_rgba(15,23,42,0.03)]"
              >
                <div className="flex flex-wrap items-start justify-between gap-3 border-b border-[#E2E8F0] pb-3.5">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-sm font-bold text-ink">
                        {ref.patientCode}
                      </span>
                      <span className="rounded-[5px] bg-[#F1F5F9] px-2 py-0.5 text-xs font-medium text-ink-soft">
                        {ref.gender}, {ref.age} tahun
                      </span>
                      <span
                        className={cn(
                          'rounded-[5px] px-2 py-0.5 text-xs font-semibold',
                          ref.dass21.severity === 'Severe' || ref.dass21.severity === 'Extreme'
                            ? 'border border-crisis-border bg-crisis-bg text-crisis-text'
                            : 'border border-warning/30 bg-warning/10 text-[#B45309]',
                        )}
                      >
                        DASS-21: {ref.dass21.severity}
                      </span>
                    </div>
                    <p className="mt-1 text-xs text-ink-muted">
                      Tanggal Rujukan: {ref.submittedAt} · Preferensi Jadwal:{' '}
                      <strong className="text-ink">{ref.preferredSchedule}</strong>
                    </p>
                  </div>

                  <div className="flex flex-wrap items-center gap-2 text-xs">
                    <span className="rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2.5 py-1">
                      Depresi: <strong>{ref.dass21.depression}</strong>
                    </span>
                    <span className="rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2.5 py-1">
                      Kecemasan: <strong>{ref.dass21.anxiety}</strong>
                    </span>
                    <span className="rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2.5 py-1">
                      Stres: <strong>{ref.dass21.stress}</strong>
                    </span>
                  </div>
                </div>

                <p className="mt-3.5 text-xs leading-relaxed text-ink-soft">
                  <strong className="text-ink">Ringkasan Pra-Konseling: </strong>
                  {ref.clinicalSummary}
                </p>

                <div className="mt-4 flex flex-col justify-between gap-3 rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-3 sm:flex-row sm:items-center">
                  <div className="flex items-center gap-2 text-xs">
                    <UserCheck className="size-4 text-primary" />
                    <span className="text-ink-soft">Psikolog Penanggung Jawab:</span>
                    <span className="font-semibold text-ink">
                      {assignedPsy ? assignedPsy.fullName : 'Belum ditugaskan'}
                    </span>
                  </div>

                  <div className="flex flex-wrap items-center gap-2">
                    <select
                      aria-label={`Pilih psikolog untuk ${ref.patientCode}`}
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
                      className="h-8 rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-xs font-medium text-ink outline-none focus:border-primary"
                    >
                      <option value="">— Pilih Psikolog Faskes —</option>
                      {psychologists
                        .filter((p) => p.status === 'active')
                        .map((p) => (
                          <option key={p.id} value={p.id}>
                            {p.fullName}
                          </option>
                        ))}
                    </select>

                    <select
                      aria-label={`Status rujukan ${ref.patientCode}`}
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
                        'h-8 rounded-[6px] border px-2.5 text-xs font-semibold outline-none',
                        ref.status === 'unassigned' &&
                          'border-warning/30 bg-warning/10 text-[#B45309]',
                        ref.status === 'scheduled' &&
                          'border-primary/30 bg-primary-container text-primary',
                        ref.status === 'completed' &&
                          'border-success/30 bg-success/10 text-success',
                      )}
                    >
                      <option value="unassigned">Menunggu Penugasan</option>
                      <option value="scheduled">Terjadwal</option>
                      <option value="completed">Sesi Selesai</option>
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

