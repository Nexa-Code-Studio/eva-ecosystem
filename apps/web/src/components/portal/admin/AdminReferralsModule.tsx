import { useMemo } from 'react'
import { cn } from '@/lib/cn'
import {
  assignReferral,
  type PortalDatabase,
  type ReferralStatus,
} from '@/lib/portalStore'

interface AdminReferralsModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

export function AdminReferralsModule({
  db,
  onFeedback,
}: AdminReferralsModuleProps) {
  const assignablePsychologists = useMemo(
    () =>
      db.psychologists.filter(
        (p) => p.verificationStatus === 'approved' && p.status === 'active',
      ),
    [db.psychologists],
  )

  const unassignedCount = useMemo(
    () => db.referrals.filter((r) => r.status === 'unassigned').length,
    [db.referrals],
  )

  return (
    <div>
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
          <span>Total Rujukan: {db.referrals.length}</span>
          {unassignedCount > 0 && (
            <span className="rounded-[4px] bg-[#FEE2E2] px-2 py-0.5 text-[11px] font-bold text-[#991B1B]">
              {unassignedCount} Belum Ditugaskan
            </span>
          )}
        </div>
      </div>

      <div className="mt-5 space-y-4">
        {db.referrals.length === 0 ? (
          <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-8 text-center text-xs text-ink-muted">
            Belum ada data rujukan pasien masuk saat ini.
          </div>
        ) : (
          db.referrals.map((ref) => {
            const assignedPsy = db.psychologists.find((p) => p.id === ref.assignedPsychologistId)
            const partner = ref.partnerId ? db.partners.find((p) => p.id === ref.partnerId) : null

            return (
              <div key={ref.id} className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
                <div className="flex flex-wrap items-start justify-between gap-4 border-b border-[#E2E8F0] pb-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-sm font-bold text-ink">{ref.patientCode}</span>
                      <span className="text-xs text-ink-muted">
                        · {ref.gender}, {ref.age} tahun · Masuk: {ref.submittedAt}
                      </span>
                    </div>
                    <p className="mt-1 text-xs text-ink-soft">
                      Jadwal Preferensi User: <strong>{ref.preferredSchedule}</strong>
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

                <p className="mt-3 text-xs leading-relaxed text-ink-soft">{ref.clinicalSummary}</p>

                <div className="mt-4 flex flex-col justify-between gap-3 rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5 sm:flex-row sm:items-center">
                  <div className="text-xs">
                    <span className="text-ink-muted">Tujuan Penanganan Saat Ini: </span>
                    {assignedPsy ? (
                      <span className="font-semibold text-ink">
                        {assignedPsy.fullName} (
                        {assignedPsy.role === 'professional_mitra'
                          ? (partner?.facilityName ?? 'Mitra Faskes')
                          : assignedPsy.role === 'relawan_profesional'
                            ? 'Relawan Profesional'
                            : assignedPsy.role === 'relawan_utama' || assignedPsy.role === 'relawan_pro'
                              ? 'Relawan Utama'
                              : 'Relawan'}
                        )
                      </span>
                    ) : (
                      <span className="font-semibold text-[#B45309]">
                        Belum Ditugaskan (Menunggu Penempatan)
                      </span>
                    )}
                  </div>

                  <div className="flex flex-wrap items-center gap-2">
                    <select
                      aria-label={`Pilih psikolog untuk ${ref.patientCode}`}
                      value={ref.assignedPsychologistId ?? ''}
                      onChange={(e) => {
                        const psyId = e.target.value || null
                        const nextStatus: ReferralStatus = psyId ? 'scheduled' : 'unassigned'
                        assignReferral(ref.id, psyId, nextStatus)
                        onFeedback(
                          `Penugasan rujukan "${ref.patientCode}" berhasil diperbarui oleh Admin.`,
                        )
                      }}
                      className="h-9 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink focus:border-primary focus:outline-none"
                    >
                      <option value="">-- Tugaskan ke Psikolog / Relawan --</option>
                      {assignablePsychologists.map((psy) => {
                        const prefix =
                          psy.role === 'professional_mitra'
                            ? '[MITRA] '
                            : psy.role === 'relawan_profesional'
                              ? '[REL. PROFESIONAL] '
                              : psy.role === 'relawan_utama' || psy.role === 'relawan_pro'
                                ? '[REL. UTAMA ★] '
                                : '[RELAWAN] '
                        return (
                          <option key={psy.id} value={psy.id}>
                            {prefix}
                            {psy.fullName} ({psy.city ?? 'ID'})
                          </option>
                        )
                      })}
                    </select>

                    <select
                      aria-label={`Status rujukan ${ref.patientCode}`}
                      value={ref.status}
                      onChange={(e) =>
                        assignReferral(
                          ref.id,
                          ref.assignedPsychologistId,
                          e.target.value as ReferralStatus,
                        )
                      }
                      className="h-9 rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs font-semibold text-ink focus:border-primary focus:outline-none"
                    >
                      <option value="unassigned">Belum Ditugaskan</option>
                      <option value="scheduled">Terjadwal</option>
                      <option value="completed">Selesai Konseling</option>
                    </select>
                  </div>
                </div>
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}

