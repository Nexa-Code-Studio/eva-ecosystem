import { AlertTriangle, CheckCircle2, Coins, Plus, Search, ShieldAlert, SlidersHorizontal, XCircle } from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router'
import { AdminActionConfirmModal, type ConfirmDialogTone } from './AdminActionConfirmModal'
import { AdminCoinAdjustModal } from './AdminCoinAdjustModal'
import { AdminCoinTopupModal } from './AdminCoinTopupModal'
import { AdminCoinsTransactionsTab } from './AdminCoinsTransactionsTab'
import { AdminPsychologistCoinsTab } from './AdminPsychologistCoinsTab'
import { TablePagination } from '@/components/portal/TablePagination'
import { useUrlPagination } from '@/hooks/useUrlPagination'
import { cn } from '@/lib/cn'
import {
  fetchAdminPsychologists,
  fetchAdminUsers,
  fetchCoinEconomyConfig,
  fetchCoinPackages,
  fetchCoinTransactions,
  updateGeneralUserStatus,
  type AppUserStatus,
  type GeneralAppUser,
  type PortalDatabase,
} from '@/lib/portalStore'

interface AdminUsersCoinsModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

type UserStatusFilter = 'all' | AppUserStatus

interface PendingStatusChange {
  user: GeneralAppUser
  nextStatus: AppUserStatus
}

const STATUS_LABEL_MAP: Record<AppUserStatus, string> = {
  active: 'Aktif',
  flagged_crisis: 'Pantauan Prioritas',
  suspended: 'Ditangguhkan',
}

function getStatusModalConfig(nextStatus: AppUserStatus): {
  title: string
  tone: ConfirmDialogTone
  impactSummary: string
} {
  if (nextStatus === 'suspended') {
    return {
      title: 'Tangguhkan Akun Pengguna?',
      tone: 'danger',
      impactSummary:
        'Akses aplikasi mobile akan dibatasi sementara dan pengguna tidak dapat memulai sesi panggilan baru hingga akun dipulihkan.',
    }
  }
  if (nextStatus === 'flagged_crisis') {
    return {
      title: 'Tandai Akun dalam Pantauan Prioritas?',
      tone: 'amber',
      impactSummary:
        'Pengguna akan masuk daftar pemantauan krisis SafetyNet agar tim klinis dapat memprioritaskan tindak lanjut.',
    }
  }
  return {
    title: 'Pulihkan Status Akun ke Aktif Normal?',
    tone: 'emerald',
    impactSummary:
      'Pengguna kembali memiliki akses normal ke seluruh fitur Voice AI EVA dan pemesanan sesi psikolog.',
  }
}

function UserAccountStatusBadge({ status }: { status: AppUserStatus }) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-[6px] px-2 py-0.5 text-[11px] font-semibold',
        status === 'active'
          ? 'bg-[#F0FDF4] text-[#166534]'
          : status === 'flagged_crisis'
            ? 'bg-[#FEF3C7] text-[#92400E]'
            : 'bg-[#F1F5F9] text-ink-soft',
      )}
    >
      {status === 'active' ? (
        <CheckCircle2 className="size-3" aria-hidden="true" />
      ) : status === 'flagged_crisis' ? (
        <AlertTriangle className="size-3" aria-hidden="true" />
      ) : (
        <XCircle className="size-3" aria-hidden="true" />
      )}
      <span>{STATUS_LABEL_MAP[status]}</span>
    </span>
  )
}

function DassSeverityBadge({ severity }: { severity: string }) {
  return (
    <span
      className={cn(
        'inline-flex rounded-[6px] border px-2 py-0.5 text-[11px] font-semibold',
        severity === 'Extreme'
          ? 'border-[#FECACA] bg-[#FEF2F2] text-[#991B1B]'
          : severity === 'Severe'
            ? 'border-[#FDE68A] bg-[#FEF3C7] text-[#92400E]'
            : 'border-[#E2E8F0] bg-[#F8FAFC] text-ink-soft',
      )}
    >
      {severity}
    </span>
  )
}

export function AdminUsersCoinsModule({
  db,
  onFeedback,
}: AdminUsersCoinsModuleProps) {
  const [searchParams, setSearchParams] = useSearchParams()
  const tabParam = searchParams.get('tab')
  const activeSubTab: 'users' | 'psychologists' | 'coins' =
    tabParam === 'coins'
      ? 'coins'
      : tabParam === 'psychologists'
        ? 'psychologists'
        : 'users'

  const handleSubTabChange = (tab: 'users' | 'psychologists' | 'coins') => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      if (tab === 'users') {
        next.delete('tab')
      } else {
        next.set('tab', tab)
      }
      next.delete('page')
      return next
    })
  }

  const [userSearch, setUserSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<UserStatusFilter>('all')
  const [topupTargetUser, setTopupTargetUser] = useState<GeneralAppUser | null>(null)
  const [isTopupModalOpen, setIsTopupModalOpen] = useState(false)
  const [adjustTargetUser, setAdjustTargetUser] = useState<GeneralAppUser | null>(null)
  const [pendingStatusChange, setPendingStatusChange] = useState<PendingStatusChange | null>(null)
  const usersTableCardRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    void fetchAdminUsers()
    void fetchAdminPsychologists()
    void fetchCoinTransactions()
    void fetchCoinEconomyConfig()
    void fetchCoinPackages()
  }, [])

  const statusCounts = useMemo(
    () => ({
      all: db.generalUsers.length,
      active: db.generalUsers.filter((u) => u.accountStatus === 'active').length,
      flagged_crisis: db.generalUsers.filter((u) => u.accountStatus === 'flagged_crisis').length,
      suspended: db.generalUsers.filter((u) => u.accountStatus === 'suspended').length,
    }),
    [db.generalUsers],
  )

  const filteredUsers = useMemo(() => {
    const q = userSearch.trim().toLowerCase()
    return db.generalUsers.filter((u) => {
      if (statusFilter !== 'all' && u.accountStatus !== statusFilter) return false
      if (!q) return true
      return (
        u.displayName.toLowerCase().includes(q) ||
        u.userCode.toLowerCase().includes(q) ||
        u.city.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q)
      )
    })
  }, [db.generalUsers, statusFilter, userSearch])

  const {
    pageSize: usersPageSize,
    safePage: usersSafePage,
    paginatedItems: paginatedUsers,
    resetPage: resetUsersPage,
    handlePageChange: handleUsersPageChange,
    handlePageSizeChange: handleUsersPageSizeChange,
  } = useUrlPagination(filteredUsers, {
    defaultPageSize: 10,
    scrollTargetRef: usersTableCardRef,
  })

  const handleUserSearchChange = (value: string) => {
    setUserSearch(value)
    resetUsersPage()
  }

  const handleStatusFilterChange = (nextFilter: UserStatusFilter) => {
    setStatusFilter(nextFilter)
    resetUsersPage()
  }

  const resetAllUserFilters = () => {
    setUserSearch('')
    setStatusFilter('all')
    resetUsersPage()
  }

  const requestStatusChange = (user: GeneralAppUser, nextStatus: AppUserStatus) => {
    if (user.accountStatus === nextStatus) return
    setPendingStatusChange({ user, nextStatus })
  }

  const pendingCoinTransactionsCount = useMemo(
    () => db.coinTransactions.filter((t) => t.status === 'pending').length,
    [db.coinTransactions],
  )

  const isUserFiltered = Boolean(userSearch.trim()) || statusFilter !== 'all'

  return (
    <div>
      <div className="flex flex-col justify-between gap-4 xl:flex-row xl:items-center">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Manajemen Pengguna &amp; EVA Coin
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Pantau direktori pengguna aplikasi mobile EVA, saldo koin terpadu (Voice AI 1 Koin/mnt &amp; konsultasi psikolog), serta riwayat top-up koin.
          </p>
        </div>

        <div
          role="tablist"
          aria-label="Submenu Pengguna & Koin"
          className="grid w-full shrink-0 grid-cols-3 gap-1 rounded-[8px] border border-[#E2E8F0] bg-white p-1 sm:inline-flex sm:w-auto"
        >
          <button
            type="button"
            role="tab"
            aria-selected={activeSubTab === 'users'}
            onClick={() => handleSubTabChange('users')}
            className={cn(
              'min-h-11 cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors sm:min-h-0',
              activeSubTab === 'users'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            Pengguna ({db.generalUsers.length})
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={activeSubTab === 'psychologists'}
            onClick={() => handleSubTabChange('psychologists')}
            className={cn(
              'min-h-11 cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors sm:min-h-0',
              activeSubTab === 'psychologists'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            Psikolog ({db.psychologists.length})
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={activeSubTab === 'coins'}
            onClick={() => handleSubTabChange('coins')}
            className={cn(
              'inline-flex min-h-11 cursor-pointer items-center justify-center gap-1.5 rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors sm:min-h-0',
              activeSubTab === 'coins'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            <span>Transaksi Koin ({db.coinTransactions.length})</span>
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

      {activeSubTab === 'psychologists' ? (
        <AdminPsychologistCoinsTab psychologists={db.psychologists} onFeedback={onFeedback} />
      ) : activeSubTab === 'users' ? (
        <div className="mt-5 space-y-3">
          <div
            ref={usersTableCardRef}
            className="overflow-hidden rounded-[12px] border border-[#E2E8F0] bg-white"
          >
            <div className="flex flex-col gap-3 border-b border-[#E2E8F0] p-4">
              <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
                <div>
                  <h2 className="text-sm font-bold text-ink">
                    Direktori Pengguna Aplikasi Mobile
                  </h2>
                  <p className="text-xs text-ink-muted">
                    Data dianonimkan sesuai standar privasi klinis EVA. 1 Koin setara 1 menit berbicara bersama EVA.
                  </p>
                </div>
                <div className="relative w-full sm:w-72">
                  <label htmlFor="users-search-input" className="sr-only">
                    Cari kode pengguna, email, atau kota
                  </label>
                  <Search
                    className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted"
                    aria-hidden="true"
                  />
                  <input
                    id="users-search-input"
                    type="search"
                    value={userSearch}
                    onChange={(e) => handleUserSearchChange(e.target.value)}
                    placeholder="Cari kode user, email, atau kota..."
                    className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink focus:border-primary focus:bg-white focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary sm:h-9 sm:min-h-0"
                  />
                </div>
              </div>

              <div className="flex flex-wrap items-center gap-1.5">
                {(
                  [
                    { id: 'all', label: `Semua (${statusCounts.all})` },
                    { id: 'active', label: `Aktif (${statusCounts.active})` },
                    { id: 'flagged_crisis', label: `Pantauan Krisis (${statusCounts.flagged_crisis})` },
                    { id: 'suspended', label: `Ditangguhkan (${statusCounts.suspended})` },
                  ] as const
                ).map((chip) => (
                  <button
                    key={chip.id}
                    type="button"
                    aria-pressed={statusFilter === chip.id}
                    onClick={() => handleStatusFilterChange(chip.id)}
                    className={cn(
                      'min-h-11 cursor-pointer rounded-[6px] border px-2.5 py-1 text-xs font-semibold transition-colors sm:min-h-8',
                      statusFilter === chip.id
                        ? 'border-primary bg-[#EEF0FF] text-primary'
                        : 'border-[#768396] bg-white text-ink-soft hover:text-ink',
                    )}
                  >
                    {chip.label}
                  </button>
                ))}
              </div>
            </div>

            {paginatedUsers.length === 0 ? (
              <div className="px-4 py-8 text-center text-xs text-ink-soft">
                <p className="font-semibold text-ink">
                  {isUserFiltered
                    ? 'Tidak ada pengguna yang cocok dengan filter status atau kata kunci pencarian.'
                    : 'Belum ada pengguna aplikasi terdaftar.'}
                </p>
                <p className="mt-1 text-ink-muted">
                  {isUserFiltered
                    ? 'Atur ulang filter status atau pencarian untuk menampilkan seluruh direktori pengguna.'
                    : 'Pengguna baru yang mendaftar lewat aplikasi mobile EVA akan otomatis muncul di sini.'}
                </p>
                {isUserFiltered && (
                  <button
                    type="button"
                    onClick={resetAllUserFilters}
                    className="mt-3 inline-flex min-h-11 cursor-pointer items-center rounded-[8px] border border-[#768396] bg-white px-3 text-xs font-semibold text-ink hover:bg-[#F8FAFC] sm:h-8 sm:min-h-0"
                  >
                    Reset Filter &amp; Pencarian
                  </button>
                )}
              </div>
            ) : (
              <>
                {/* Mobile Card View (< md) */}
                <div className="divide-y divide-[#E2E8F0] md:hidden">
                  {paginatedUsers.map((usr) => (
                    <div key={usr.id} className="space-y-3 p-4 text-xs">
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0">
                          <p className="truncate font-bold text-ink">{usr.displayName}</p>
                          <p className="truncate text-[11px] text-ink-muted">
                            {usr.email} - {usr.city}
                          </p>
                        </div>
                        <UserAccountStatusBadge status={usr.accountStatus} />
                      </div>

                      <div className="flex flex-wrap items-center gap-2">
                        <span className="inline-flex items-center gap-1 rounded-[6px] bg-[#EEF0FF] px-2 py-0.5 text-[11px] font-bold text-primary">
                          <Coins className="size-3" aria-hidden="true" />
                          {usr.coinBalance ?? 0} Koin
                        </span>
                        <span className="text-[11px] text-ink-muted">
                          Terpakai {usr.totalVoiceMinutesUsed ?? 0} mnt
                        </span>
                        <DassSeverityBadge severity={usr.lastDassSeverity} />
                        {usr.crisisProtocolTriggered && (
                          <span className="inline-flex items-center gap-1 rounded-[6px] border border-[#FECACA] bg-[#FEF2F2] px-2 py-0.5 text-[11px] font-bold text-[#B91C1C]">
                            <ShieldAlert className="size-3.5" aria-hidden="true" /> SafetyNet (119)
                          </span>
                        )}
                      </div>

                      <p className="text-[11px] text-ink-muted">
                        {usr.voiceSessionsCount} sesi suara · Streak {usr.questStreakDays} hari · Aktif {usr.lastActiveAt}
                      </p>

                      <div className="grid grid-cols-1 gap-2 pt-1 sm:grid-cols-3">
                        <button
                          type="button"
                          onClick={() => {
                            setTopupTargetUser(usr)
                            setIsTopupModalOpen(true)
                          }}
                          className="inline-flex min-h-11 w-full cursor-pointer items-center justify-center gap-1.5 rounded-[8px] border border-primary/40 bg-[#EEF0FF] px-3 text-xs font-semibold text-primary hover:bg-primary hover:text-white"
                        >
                          <Plus className="size-3.5" aria-hidden="true" />
                          <span>Tambah Koin</span>
                        </button>
                        <button
                          type="button"
                          onClick={() => setAdjustTargetUser(usr)}
                          className="inline-flex min-h-11 w-full cursor-pointer items-center justify-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink hover:bg-[#F8FAFC]"
                        >
                          <SlidersHorizontal className="size-3.5" aria-hidden="true" />
                          <span>Sesuaikan</span>
                        </button>
                        <div>
                          <label htmlFor={`mobile-status-${usr.id}`} className="sr-only">
                            Ubah status {usr.displayName}
                          </label>
                          <select
                            id={`mobile-status-${usr.id}`}
                            value={usr.accountStatus}
                            onChange={(e) =>
                              requestStatusChange(usr, e.target.value as AppUserStatus)
                            }
                            className="min-h-11 w-full rounded-[8px] border border-[#768396] bg-white px-2.5 text-xs font-semibold text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
                          >
                            <option value="active">Aktif Normal</option>
                            <option value="flagged_crisis">Pantauan Prioritas</option>
                            <option value="suspended">Tangguhkan Akun</option>
                          </select>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>

                {/* Desktop Table View (>= md) */}
                <div className="hidden overflow-x-auto md:block">
                  <table className="w-full border-collapse text-left">
                    <thead>
                      <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                        <th className="px-3 py-3">Pengguna &amp; Kota</th>
                        <th className="px-3 py-3">Aktivitas</th>
                        <th className="px-3 py-3">Saldo Koin</th>
                        <th className="px-3 py-3">DASS-21</th>
                        <th className="px-3 py-3">Krisis</th>
                        <th className="px-3 py-3">Status</th>
                        <th className="px-3 py-3 text-right">Moderasi</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[#E2E8F0] text-xs">
                      {paginatedUsers.map((usr) => (
                        <tr key={usr.id} className="hover:bg-[#F8FAFC]">
                          <td className="max-w-[190px] px-3 py-3.5">
                            <p className="truncate font-semibold text-ink">{usr.displayName}</p>
                            <p className="truncate text-[11px] text-ink-muted">
                              {usr.email} · {usr.city}
                            </p>
                          </td>
                          <td className="px-3 py-3.5 whitespace-nowrap">
                            <p className="font-medium text-ink">
                              {usr.voiceSessionsCount} sesi · {usr.questStreakDays}h streak
                            </p>
                            <p className="text-[11px] text-ink-muted">
                              {usr.lastActiveAt}
                            </p>
                          </td>
                          <td className="px-3 py-3.5 whitespace-nowrap">
                            <span className="inline-flex items-center gap-1 rounded-[6px] bg-[#EEF0FF] px-2 py-0.5 text-[11px] font-bold text-primary">
                              <Coins className="size-3" aria-hidden="true" />
                              {usr.coinBalance ?? 0} Koin
                            </span>
                            <p className="mt-0.5 text-[11px] text-ink-muted">
                              {usr.totalVoiceMinutesUsed ?? 0} mnt terpakai
                            </p>
                          </td>
                          <td className="px-3 py-3.5 whitespace-nowrap">
                            <DassSeverityBadge severity={usr.lastDassSeverity} />
                          </td>
                          <td className="px-3 py-3.5 whitespace-nowrap">
                            {usr.crisisProtocolTriggered ? (
                              <span className="inline-flex items-center gap-1 rounded-[6px] border border-[#FECACA] bg-[#FEF2F2] px-2 py-0.5 text-[11px] font-bold text-[#B91C1C]">
                                <ShieldAlert className="size-3.5" aria-hidden="true" /> SafetyNet (119)
                              </span>
                            ) : (
                              <span className="text-ink-muted">Aman</span>
                            )}
                          </td>
                          <td className="px-3 py-3.5 whitespace-nowrap">
                            <UserAccountStatusBadge status={usr.accountStatus} />
                          </td>
                          <td className="px-3 py-3.5 text-right whitespace-nowrap">
                            <div className="inline-flex items-center justify-end gap-1.5">
                              <button
                                type="button"
                                onClick={() => {
                                  setTopupTargetUser(usr)
                                  setIsTopupModalOpen(true)
                                }}
                                className="inline-flex h-8 shrink-0 cursor-pointer items-center gap-1 rounded-[6px] border border-primary/40 bg-[#EEF0FF] px-2.5 text-xs font-semibold whitespace-nowrap text-primary transition-colors hover:bg-primary hover:text-white"
                              >
                                <Plus className="size-3.5" aria-hidden="true" />
                                <span>Koin</span>
                              </button>
                              <button
                                type="button"
                                onClick={() => setAdjustTargetUser(usr)}
                                className="inline-flex h-8 shrink-0 cursor-pointer items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-xs font-semibold whitespace-nowrap text-ink transition-colors hover:bg-[#F8FAFC]"
                              >
                                <SlidersHorizontal className="size-3.5" aria-hidden="true" />
                                <span>Sesuaikan</span>
                              </button>
                              <select
                                aria-label={`Ubah status ${usr.displayName}`}
                                value={usr.accountStatus}
                                onChange={(e) =>
                                  requestStatusChange(usr, e.target.value as AppUserStatus)
                                }
                                className="h-8 rounded-[6px] border border-[#768396] bg-white px-2 text-xs font-semibold text-ink focus:border-primary focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
                              >
                                <option value="active">Aktif</option>
                                <option value="flagged_crisis">Pantauan</option>
                                <option value="suspended">Tangguhkan</option>
                              </select>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </>
            )}
          </div>

          <TablePagination
            currentPage={usersSafePage}
            totalItems={filteredUsers.length}
            pageSize={usersPageSize}
            pageSizeOptions={[5, 10, 25, 50]}
            itemLabel="pengguna"
            ariaLabel="Paginasi pengguna aplikasi"
            onPageChange={handleUsersPageChange}
            onPageSizeChange={handleUsersPageSizeChange}
          />
        </div>
      ) : (
        <AdminCoinsTransactionsTab
          db={db}
          onFeedback={onFeedback}
          onOpenGlobalTopup={() => {
            setTopupTargetUser(null)
            setIsTopupModalOpen(true)
          }}
        />
      )}

      <AdminCoinTopupModal
        key={topupTargetUser?.id ?? (isTopupModalOpen ? 'global-open' : 'closed')}
        isOpen={isTopupModalOpen}
        users={db.generalUsers}
        coinPackages={db.coinPackages}
        economyConfig={db.coinEconomyConfig}
        preselectedUser={topupTargetUser}
        onClose={() => {
          setIsTopupModalOpen(false)
          setTopupTargetUser(null)
        }}
        onSuccess={onFeedback}
      />

      <AdminCoinAdjustModal
        key={adjustTargetUser ? `adjust-user-${adjustTargetUser.id}` : 'adjust-user-closed'}
        isOpen={adjustTargetUser !== null}
        target={adjustTargetUser ? { kind: 'user', user: adjustTargetUser } : null}
        onClose={() => setAdjustTargetUser(null)}
        onSuccess={onFeedback}
      />

      {pendingStatusChange && (
        <AdminActionConfirmModal
          key={`${pendingStatusChange.user.id}-${pendingStatusChange.nextStatus}`}
          isOpen
          title={getStatusModalConfig(pendingStatusChange.nextStatus).title}
          description={`Anda akan mengubah status akun "${pendingStatusChange.user.displayName}" (${pendingStatusChange.user.userCode}) dari ${STATUS_LABEL_MAP[pendingStatusChange.user.accountStatus]} menjadi ${STATUS_LABEL_MAP[pendingStatusChange.nextStatus]}.`}
          impactSummary={getStatusModalConfig(pendingStatusChange.nextStatus).impactSummary}
          confirmLabel={`Ya, Ubah ke ${STATUS_LABEL_MAP[pendingStatusChange.nextStatus]}`}
          tone={getStatusModalConfig(pendingStatusChange.nextStatus).tone}
          onClose={() => setPendingStatusChange(null)}
          onConfirm={() => {
            updateGeneralUserStatus(
              pendingStatusChange.user.id,
              pendingStatusChange.nextStatus,
            )
            onFeedback(
              `Status akun "${pendingStatusChange.user.userCode}" diperbarui menjadi ${STATUS_LABEL_MAP[pendingStatusChange.nextStatus]}.`,
            )
          }}
        />
      )}
    </div>
  )
}
