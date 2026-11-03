import { useMemo, useState } from 'react'
import { Search, ShieldAlert } from 'lucide-react'
import { cn } from '@/lib/cn'
import type { AppUserStatus, PortalDatabase, ReferralStatus } from '@/types/portal'
import { assignReferral, updateGeneralUserStatus } from '@/services/portal/ecosystemService'

interface AdminUsersReferralsModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

export function AdminUsersReferralsModule({
  db,
  onFeedback,
}: AdminUsersReferralsModuleProps) {
  const [userRefSubTab, setUserRefSubTab] = useState<'users' | 'referrals'>('users')
  const [userSearch, setUserSearch] = useState('')

  const filteredUsers = useMemo(() => {
    if (!userSearch.trim()) return db.generalUsers
    const q = userSearch.toLowerCase()
    return db.generalUsers.filter(
      (u) =>
        u.displayName.toLowerCase().includes(q) ||
        u.userCode.toLowerCase().includes(q) ||
        u.city.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q),
    )
  }, [db.generalUsers, userSearch])

  const assignablePsychologists = useMemo(
    () =>
      db.psychologists.filter(
        (p) => p.verificationStatus === 'approved' && p.status === 'active',
      ),
    [db.psychologists],
  )

  return (
    <div>
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Manajemen Pengguna Aplikasi &amp; Rujukan DASS-21
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Pantau pengguna aplikasi mobile EVA, sinyal protokol krisis SafetyNet, dan arahkan rujukan pasien ke faskes mitra atau psikolog/relawan.
          </p>
        </div>

        <div className="inline-flex rounded-[8px] border border-[#E2E8F0] bg-white p-1">
          <button
            type="button"
            onClick={() => setUserRefSubTab('users')}
            className={cn(
              'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
              userRefSubTab === 'users'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            Pengguna Aplikasi ({db.generalUsers.length})
          </button>
          <button
            type="button"
            onClick={() => setUserRefSubTab('referrals')}
            className={cn(
              'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
              userRefSubTab === 'referrals'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            Rujukan DASS-21 ({db.referrals.length})
          </button>
        </div>
      </div>

      {userRefSubTab === 'users' ? (
        <div className="mt-5 rounded-[12px] border border-[#E2E8F0] bg-white">
          <div className="flex flex-col justify-between gap-3 border-b border-[#E2E8F0] p-4 sm:flex-row sm:items-center">
            <div>
              <h2 className="text-sm font-bold text-ink">
                Direktori Pengguna Aplikasi Mobile
              </h2>
              <p className="text-xs text-ink-muted">
                Data dianonimkan sesuai standar privasi klinis EVA.
              </p>
            </div>
            <div className="relative w-full sm:w-72">
              <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
              <input
                type="search"
                value={userSearch}
                onChange={(e) => setUserSearch(e.target.value)}
                placeholder="Cari kode user, email, atau kota..."
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink focus:border-primary focus:bg-white focus:outline-none"
              />
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-left">
              <thead>
                <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                  <th className="px-4 py-3">Pengguna & Kota</th>
                  <th className="px-4 py-3">Aktivitas App</th>
                  <th className="px-4 py-3">Skrining DASS-21</th>
                  <th className="px-4 py-3">Protokol Krisis</th>
                  <th className="px-4 py-3">Status Akun</th>
                  <th className="px-4 py-3 text-right">Moderasi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#E2E8F0] text-xs">
                {filteredUsers.map((usr) => (
                  <tr key={usr.id} className="hover:bg-[#F8FAFC]">
                    <td className="px-4 py-3.5">
                      <p className="font-semibold text-ink">{usr.displayName}</p>
                      <p className="text-[11px] text-ink-muted">
                        {usr.email} · {usr.city}
                      </p>
                    </td>
                    <td className="px-4 py-3.5">
                      <p className="font-medium text-ink">
                        {usr.voiceSessionsCount} sesi suara · Streak {usr.questStreakDays} hari
                      </p>
                      <p className="text-[11px] text-ink-muted">
                        Aktif terakhir: {usr.lastActiveAt}
                      </p>
                    </td>
                    <td className="px-4 py-3.5">
                      <span
                        className={cn(
                          'inline-flex rounded-[6px] border px-2 py-0.5 text-[11px] font-semibold',
                          usr.lastDassSeverity === 'Extreme'
                            ? 'border-[#FECACA] bg-[#FEF2F2] text-[#991B1B]'
                            : usr.lastDassSeverity === 'Severe'
                              ? 'border-[#FDE68A] bg-[#FEF3C7] text-[#92400E]'
                              : 'border-[#E2E8F0] bg-[#F8FAFC] text-ink-soft',
                        )}
                      >
                        {usr.lastDassSeverity}
                      </span>
                    </td>
                    <td className="px-4 py-3.5">
                      {usr.crisisProtocolTriggered ? (
                        <span className="inline-flex items-center gap-1 rounded-[6px] border border-[#FECACA] bg-[#FEF2F2] px-2 py-0.5 text-[11px] font-bold text-[#B91C1C]">
                          <ShieldAlert className="size-3.5" /> SafetyNet Aktif (119)
                        </span>
                      ) : (
                        <span className="text-ink-muted">Aman</span>
                      )}
                    </td>
                    <td className="px-4 py-3.5">
                      <span
                        className={cn(
                          'inline-flex rounded-[6px] px-2 py-0.5 text-[11px] font-semibold',
                          usr.accountStatus === 'active'
                            ? 'bg-[#F0FDF4] text-[#166534]'
                            : usr.accountStatus === 'flagged_crisis'
                              ? 'bg-[#FEF3C7] text-[#92400E]'
                              : 'bg-[#F1F5F9] text-ink-muted',
                        )}
                      >
                        {usr.accountStatus === 'active'
                          ? 'Aktif'
                          : usr.accountStatus === 'flagged_crisis'
                            ? 'Pantauan Prioritas'
                            : 'Ditangguhkan'}
                      </span>
                    </td>
                    <td className="px-4 py-3.5 text-right">
                      <select
                        aria-label={`Ubah status ${usr.displayName}`}
                        value={usr.accountStatus}
                        onChange={(e) => {
                          updateGeneralUserStatus(usr.id, e.target.value as AppUserStatus)
                          onFeedback(`Status akun pengguna "${usr.userCode}" berhasil diperbarui.`)
                        }}
                        className="h-8 rounded-[6px] border border-[#CBD5E1] bg-white px-2 text-xs font-semibold text-ink focus:border-primary focus:outline-none"
                      >
                        <option value="active">Aktif Normal</option>
                        <option value="flagged_crisis">Pantauan Prioritas</option>
                        <option value="suspended">Tangguhkan Akun</option>
                      </select>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="mt-5 space-y-4">
          {db.referrals.map((ref) => {
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
          })}
        </div>
      )}
    </div>
  )
}
