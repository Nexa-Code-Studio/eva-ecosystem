import { Coins, Search, ShieldAlert } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useSearchParams } from 'react-router'
import { AdminCoinsTransactionsTab } from './AdminCoinsTransactionsTab'
import { cn } from '@/lib/cn'
import {
  updateGeneralUserStatus,
  type AppUserStatus,
  type PortalDatabase,
} from '@/lib/portalStore'

interface AdminUsersCoinsModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

export function AdminUsersCoinsModule({
  db,
  onFeedback,
}: AdminUsersCoinsModuleProps) {
  const [searchParams, setSearchParams] = useSearchParams()
  const tabParam = searchParams.get('tab')
  const activeSubTab: 'users' | 'coins' = tabParam === 'coins' ? 'coins' : 'users'

  const handleSubTabChange = (tab: 'users' | 'coins') => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      if (tab === 'coins') {
        next.set('tab', 'coins')
      } else {
        next.delete('tab')
      }
      return next
    })
  }

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

  const pendingCoinTransactionsCount = useMemo(
    () => db.coinTransactions.filter((t) => t.status === 'pending').length,
    [db.coinTransactions],
  )

  return (
    <div>
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Manajemen Pengguna &amp; Koin Suara
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Pantau direktori pengguna aplikasi mobile EVA, saldo koin bicara (1 Koin = 1 Menit), serta riwayat transaksi top-up koin.
          </p>
        </div>

        <div className="inline-flex rounded-[8px] border border-[#E2E8F0] bg-white p-1">
          <button
            type="button"
            onClick={() => handleSubTabChange('users')}
            className={cn(
              'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
              activeSubTab === 'users'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            Pengguna Aplikasi ({db.generalUsers.length})
          </button>
          <button
            type="button"
            onClick={() => handleSubTabChange('coins')}
            className={cn(
              'inline-flex cursor-pointer items-center gap-1.5 rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
              activeSubTab === 'coins'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            <span>Riwayat Transaksi Koin ({db.coinTransactions.length})</span>
            {pendingCoinTransactionsCount > 0 && (
              <span
                className={cn(
                  'rounded-[4px] px-1.5 py-0.5 text-[10px] font-bold',
                  activeSubTab === 'coins'
                    ? 'bg-white/20 text-white'
                    : 'bg-amber-100 text-amber-800',
                )}
              >
                {pendingCoinTransactionsCount}
              </span>
            )}
          </button>
        </div>
      </div>

      {activeSubTab === 'users' ? (
        <div className="mt-5 rounded-[12px] border border-[#E2E8F0] bg-white">
          <div className="flex flex-col justify-between gap-3 border-b border-[#E2E8F0] p-4 sm:flex-row sm:items-center">
            <div>
              <h2 className="text-sm font-bold text-ink">
                Direktori Pengguna Aplikasi Mobile
              </h2>
              <p className="text-xs text-ink-muted">
                Data dianonimkan sesuai standar privasi klinis EVA. 1 Koin setara dengan 1 menit berbicara bersama EVA.
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
                  <th className="px-4 py-3">Pengguna &amp; Kota</th>
                  <th className="px-4 py-3">Aktivitas App</th>
                  <th className="px-4 py-3">Saldo Koin &amp; Menit</th>
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
                      <span className="inline-flex items-center gap-1 rounded-[6px] bg-[#EEF0FF] px-2 py-0.5 text-[11px] font-bold text-primary">
                        <Coins className="size-3" />
                        {usr.coinBalance ?? 0} Koin
                      </span>
                      <p className="mt-0.5 text-[11px] text-ink-muted">
                        Terpakai: {usr.totalVoiceMinutesUsed ?? 0} menit bicara
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
        <AdminCoinsTransactionsTab db={db} onFeedback={onFeedback} />
      )}
    </div>
  )
}
