import { useEffect, useMemo, useState } from 'react'
import { Outlet, useNavigate } from 'react-router'
import { ShieldCheck } from 'lucide-react'
import { ResetPortalDataAction } from '@/components/devtools/PortalDevTools'
import { resetPortalDbToDefault, setPortalSession, usePortalDb } from '@/lib/portalStore'
import {
  PortalFeedbackBanner,
  PortalTopbar,
} from '@/components/portal/PortalTopbar'
import {
  AdminSidebar,
  type AdminModule,
  type AdminSummaryCounts,
} from '@/components/portal/admin/AdminSidebarAndKpi'
import {
  useAdminOutletContext,
  type AdminOutletContext,
} from '@/components/portal/admin/adminPortalContext'
import { AdminDashboardOverview } from '@/components/portal/admin/AdminDashboardOverview'
import { AdminPsychologistsModule } from '@/components/portal/admin/AdminPsychologistsModule'
import { AdminPartnersModule } from '@/components/portal/admin/AdminPartnersModule'
import { AdminReferralsModule } from '@/components/portal/admin/AdminReferralsModule'
import { AdminUsersCoinsModule } from '@/components/portal/admin/AdminUsersCoinsModule'
import { AdminContentConfigModule } from '@/components/portal/admin/AdminContentConfigModule'

export type { AdminOutletContext }

export function AdminDashboardPage() {
  const navigate = useNavigate()
  const { db, session } = usePortalDb()
  const [feedbackBanner, setFeedbackBanner] = useState<string | null>(null)

  useEffect(() => {
    document.title = 'Panel Admin EVA : Manajemen Portal'
    window.scrollTo({ top: 0, behavior: 'instant' as ScrollBehavior })
  }, [])

  useEffect(() => {
    if (!session || session.role !== 'admin') {
      navigate('/login', { replace: true })
    }
  }, [navigate, session])

  const counts = useMemo<AdminSummaryCounts>(() => {
    const pendingMandiri = db.psychologists.filter(
      (p) => p.practiceType === 'mandiri' && p.verificationStatus === 'pending',
    ).length
    const pendingPsyAction = db.psychologists.filter(
      (p) => p.verificationStatus === 'pending' || Boolean(p.upgradeRequest),
    ).length
    const approvedMandiri = db.psychologists.filter(
      (p) => p.practiceType === 'mandiri' && p.verificationStatus === 'approved',
    ).length
    const faskesPsy = db.psychologists.filter((p) => p.practiceType !== 'mandiri').length
    const pendingPartners = db.partners.filter((p) => p.status === 'pending').length
    const approvedPartners = db.partners.filter((p) => p.status === 'approved').length
    const crisisUsers = db.generalUsers.filter(
      (u) => u.crisisProtocolTriggered || u.accountStatus === 'flagged_crisis',
    ).length
    const unassignedRefs = db.referrals.filter((r) => r.status === 'unassigned').length
    const newWaitlist = db.waitlistEntries.filter((w) => w.status === 'new').length

    return {
      pendingMandiri,
      approvedMandiri,
      faskesPsy,
      pendingPartners,
      approvedPartners,
      crisisUsers,
      unassignedRefs,
      newWaitlist,
      totalGeneralUsers: db.generalUsers.length,
      activeQuestsCount: db.copingQuests.filter((q) => q.isActive).length,
      totalWaitlistCount: db.waitlistEntries.length,
      hotlineNumber: db.crisisConfig.hotlineNumber,
      pendingPsyAction,
    }
  }, [db])

  const handleLogout = () => {
    setPortalSession(null)
    navigate('/login')
  }

  const handleResetDemo = () => {
    if (window.confirm('Kembalikan semua data demo ke kondisi awal? Perubahan tersimpan akan direset.')) {
      resetPortalDbToDefault()
      setFeedbackBanner('Semua data demo berhasil dikembalikan ke kondisi awal.')
    }
  }

  const handleSelectModule = (mod: AdminModule) => {
    const pathMap: Record<AdminModule, string> = {
      dashboard: '/admin/dashboard',
      psychologists: '/admin/psychologists',
      partners: '/admin/partners',
      referrals: '/admin/referrals',
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
        <AdminSidebar
          counts={counts}
          onSelectModule={handleSelectModule}
        />

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

// Child Route Components
export function AdminDashboardRoute() {
  const { db, onSelectModule } = useAdminOutletContext()
  return <AdminDashboardOverview db={db} onSelectModule={onSelectModule} />
}

export function AdminPsychologistsRoute() {
  const { db, onFeedback } = useAdminOutletContext()
  return (
    <AdminPsychologistsModule
      psychologists={db.psychologists}
      partners={db.partners}
      onFeedback={onFeedback}
    />
  )
}

export function AdminPartnersRoute() {
  const { db, onFeedback } = useAdminOutletContext()
  return <AdminPartnersModule db={db} onFeedback={onFeedback} />
}

export function AdminReferralsRoute() {
  const { db, onFeedback } = useAdminOutletContext()
  return <AdminReferralsModule db={db} onFeedback={onFeedback} />
}

export function AdminUsersCoinsRoute() {
  const { db, onFeedback } = useAdminOutletContext()
  return <AdminUsersCoinsModule db={db} onFeedback={onFeedback} />
}

export function AdminContentConfigRoute() {
  const { db, onFeedback } = useAdminOutletContext()
  return <AdminContentConfigModule db={db} onFeedback={onFeedback} />
}
