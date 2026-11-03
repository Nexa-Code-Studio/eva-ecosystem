import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router'
import { RotateCcw, ShieldCheck } from 'lucide-react'
import { DEMO_CONFIG } from '@/config/demoConfig'
import { cn } from '@/lib/cn'
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
import { AdminDashboardOverview } from '@/components/portal/admin/AdminDashboardOverview'
import { AdminPsychologistsModule } from '@/components/portal/admin/AdminPsychologistsModule'
import { AdminPartnersModule } from '@/components/portal/admin/AdminPartnersModule'
import { AdminUsersReferralsModule } from '@/components/portal/admin/AdminUsersReferralsModule'
import { AdminMobileContentTab } from '@/components/portal/admin/AdminMobileContentTab'
import { AdminWebsiteContentTab } from '@/components/portal/admin/AdminWebsiteContentTab'

export function AdminDashboardPage() {
  const navigate = useNavigate()
  const { db, session } = usePortalDb()

  const [activeModule, setActiveModule] = useState<AdminModule>('dashboard')
  const [cmsSubTab, setCmsSubTab] = useState<'mobile' | 'website'>('mobile')
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
        extraActions={
          DEMO_CONFIG.showResetDemoButton ? (
            <button
              type="button"
              onClick={handleResetDemo}
              title="Kembalikan database demo ke kondisi awal"
              className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs font-semibold text-ink-muted transition-colors hover:border-amber-400 hover:text-ink"
            >
              <RotateCcw className="size-3.5" />
              <span className="hidden md:inline">Reset Demo</span>
            </button>
          ) : undefined
        }
      />

      <div className="flex w-full flex-col gap-6 px-4 py-6 sm:px-6 lg:flex-row lg:items-start lg:px-8">
        <AdminSidebar
          activeModule={activeModule}
          counts={counts}
          onSelectModule={setActiveModule}
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

          {activeModule === 'dashboard' && (
            <AdminDashboardOverview
              db={db}
              onSelectModule={setActiveModule}
            />
          )}

          {activeModule === 'psychologists' && (
            <AdminPsychologistsModule
              psychologists={db.psychologists}
              partners={db.partners}
              onFeedback={setFeedbackBanner}
            />
          )}

          {activeModule === 'partners' && (
            <AdminPartnersModule db={db} onFeedback={setFeedbackBanner} />
          )}

          {activeModule === 'users_referrals' && (
            <AdminUsersReferralsModule db={db} onFeedback={setFeedbackBanner} />
          )}

          {activeModule === 'content_config' && (
            <div>
              <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
                <div>
                  <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
                    Konten Aplikasi Mobile &amp; Operasional Website
                  </h1>
                  <p className="mt-0.5 text-xs text-ink-muted">
                    Kelola katalog Misi Koping Harian, konfigurasi Hotline Krisis SafetyNet, serta pendaftar Waitlist &amp; FAQ Website.
                  </p>
                </div>

                <div className="inline-flex rounded-[8px] border border-[#E2E8F0] bg-white p-1">
                  <button
                    type="button"
                    onClick={() => setCmsSubTab('mobile')}
                    className={cn(
                      'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
                      cmsSubTab === 'mobile'
                        ? 'bg-primary text-white'
                        : 'text-ink-soft hover:text-ink',
                    )}
                  >
                    Misi Koping & Krisis (Mobile)
                  </button>
                  <button
                    type="button"
                    onClick={() => setCmsSubTab('website')}
                    className={cn(
                      'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
                      cmsSubTab === 'website'
                        ? 'bg-primary text-white'
                        : 'text-ink-soft hover:text-ink',
                    )}
                  >
                    Waitlist & FAQ (Website)
                  </button>
                </div>
              </div>

              {cmsSubTab === 'mobile' ? (
                <AdminMobileContentTab db={db} onFeedback={setFeedbackBanner} />
              ) : (
                <AdminWebsiteContentTab db={db} onFeedback={setFeedbackBanner} />
              )}
            </div>
          )}
        </main>
      </div>
    </div>
  )
}
