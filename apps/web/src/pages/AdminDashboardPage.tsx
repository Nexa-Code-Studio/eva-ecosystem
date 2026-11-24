import { useEffect, useMemo, useState } from 'react'
import { Outlet, useNavigate } from 'react-router'
import { ShieldCheck } from 'lucide-react'
import { ResetPortalDataAction } from '@/components/devtools/PortalDevTools'
import { AdminContentConfigModule } from '@/components/portal/admin/AdminContentConfigModule'
import { AdminDashboardOverview } from '@/components/portal/admin/AdminDashboardOverview'
import { AdminPlatformSettingsModule } from '@/components/portal/admin/AdminPlatformSettingsModule'
import { AdminPsychologistsModule } from '@/components/portal/admin/AdminPsychologistsModule'
import { AdminSessionMonitoringModule } from '@/components/portal/admin/AdminSessionMonitoringModule'
import {
  AdminSidebar,
  type AdminModule,
  type AdminSummaryCounts,
} from '@/components/portal/admin/AdminSidebarAndKpi'
import { AdminUsersCoinsModule } from '@/components/portal/admin/AdminUsersCoinsModule'
import {
  useAdminOutletContext,
  type AdminOutletContext,
} from '@/components/portal/admin/adminPortalContext'
import {
  PortalFeedbackBanner,
  PortalTopbar,
} from '@/components/portal/PortalTopbar'
import {
  fetchAdminPsychologists,
  fetchConsultationSessions,
  fetchCrisisConfig,
  resetPortalDbToDefault,
  setPortalSession,
  usePortalDb,
} from '@/lib/portalStore'

export type { AdminOutletContext }

export function AdminDashboardPage() {
  const navigate = useNavigate()
  const { db, session } = usePortalDb()
  const [feedbackBanner, setFeedbackBanner] = useState<string | null>(null)

  useEffect(() => {
    document.title = 'Panel Admin EVA : Manajemen Portal'
    window.scrollTo({ top: 0, behavior: 'instant' as ScrollBehavior })
  }, [])

  const sessionRole = session?.role
  const sessionToken = session?.accessToken

  useEffect(() => {
    if (!sessionRole || sessionRole !== 'admin') {
      navigate('/login', { replace: true })
      return
    }
    void fetchAdminPsychologists()
    void fetchConsultationSessions()
    void fetchCrisisConfig()
  }, [navigate, sessionRole, sessionToken])

  const counts = useMemo<AdminSummaryCounts>(() => {
    const pendingPsychologists = db.psychologists.filter(
      (p) => p.verificationStatus === 'pending',
    ).length
    const needRevisionPsychologists = 0
    const verifiedPsychologists = db.psychologists.filter(
      (p) => p.verificationStatus === 'verified',
    ).length
    const activeSessions = db.consultationSessions.filter(
      (s) => s.status === 'in_progress' || s.status === 'extended' || s.status === 'waiting',
    ).length
    const extendedSessions = db.consultationSessions.filter(
      (s) => s.isExtended || s.durationMinutes === 60,
    ).length
    const crisisUsers = db.generalUsers.filter(
      (u) => u.crisisProtocolTriggered || u.accountStatus === 'flagged_crisis',
    ).length
    const newWaitlist = db.waitlistEntries.filter((w) => w.status === 'new').length

    return {
      pendingPsychologists,
      verifiedPsychologists,
      needRevisionPsychologists,
      activeSessions,
      extendedSessions,
      crisisUsers,
      newWaitlist,
      totalGeneralUsers: db.generalUsers.length,
      activeQuestsCount: db.copingQuests.filter((q) => q.isActive).length,
      totalWaitlistCount: db.waitlistEntries.length,
      hotlineNumber: db.crisisConfig.hotlineNumber,
    }
  }, [db])

  const handleLogout = () => {
    setPortalSession(null)
    navigate('/login')
  }

  const handleResetDemo = () => {
    if (
      window.confirm(
        'Kembalikan semua data demo ke kondisi awal? Perubahan tersimpan akan direset.',
      )
    ) {
      resetPortalDbToDefault()
      setFeedbackBanner('Semua data demo berhasil dikembalikan ke kondisi awal.')
    }
  }

  const handleSelectModule = (mod: AdminModule) => {
    const pathMap: Record<AdminModule, string> = {
      dashboard: '/admin/dashboard',
      psychologists: '/admin/psychologists',
      monitoring: '/admin/monitoring',
      settings: '/admin/settings',
      users_coins: '/admin/users-coins',
      content_config: '/admin/content-config',
    }
    navigate(pathMap[mod])
  }

  return (
    <div className="min-h-dvh bg-[#F8FAFC] text-ink">
      <PortalTopbar
        maxWidthClass="max-w-none"
        badgeLabel={
          <>
            <ShieldCheck className="size-3.5 text-primary" />
            <span className="hidden sm:inline">Panel Admin EVA</span>
          </>
        }
        title="Admin EVA"
        subtitle={session?.email ?? 'admin@eva.id'}
        onLogout={handleLogout}
        extraActions={<ResetPortalDataAction onReset={handleResetDemo} />}
      />

      <div className="flex w-full flex-col gap-6 px-4 py-6 sm:px-6 lg:flex-row lg:items-start lg:px-8">
        <AdminSidebar counts={counts} onSelectModule={handleSelectModule} />

        <main className="min-w-0 flex-1">
          {feedbackBanner && (
            <div className="mb-5 [&>div]:mt-0">
              <PortalFeedbackBanner
                message={feedbackBanner}
                onClose={() => setFeedbackBanner(null)}
              />
            </div>
          )}

          <Outlet
            context={{
              db,
              session,
              counts,
              onFeedback: setFeedbackBanner,
              onSelectModule: handleSelectModule,
            } satisfies AdminOutletContext}
          />
        </main>
      </div>
    </div>
  )
}

export function AdminDashboardRoute() {
  const { db, onSelectModule } = useAdminOutletContext()
  return <AdminDashboardOverview db={db} onSelectModule={onSelectModule} />
}

export function AdminPsychologistsRoute() {
  const { db, onFeedback } = useAdminOutletContext()
  return <AdminPsychologistsModule psychologists={db.psychologists} onFeedback={onFeedback} />
}

export function AdminMonitoringRoute() {
  const { db } = useAdminOutletContext()
  return <AdminSessionMonitoringModule sessions={db.consultationSessions} />
}

export function AdminSettingsRoute() {
  const { db, onFeedback } = useAdminOutletContext()
  return <AdminPlatformSettingsModule db={db} onFeedback={onFeedback} />
}

export function AdminUsersCoinsRoute() {
  const { db, onFeedback } = useAdminOutletContext()
  return <AdminUsersCoinsModule db={db} onFeedback={onFeedback} />
}

export function AdminContentConfigRoute() {
  const { db, onFeedback } = useAdminOutletContext()
  return <AdminContentConfigModule db={db} onFeedback={onFeedback} />
}
