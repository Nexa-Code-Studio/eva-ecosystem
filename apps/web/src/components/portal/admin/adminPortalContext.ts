import { useOutletContext } from 'react-router'
import type { PortalSession } from '@/lib/portalStore'
import type { AdminModuleId } from '@/types/domain/dashboard'
import type { PortalDatabase } from '@/types/portal'

export type AdminModule = AdminModuleId

export interface AdminSummaryCounts {
  pendingPsychologists: number
  verifiedPsychologists: number
  needRevisionPsychologists: number
  activeSessions: number
  extendedSessions: number
  crisisUsers: number
  newWaitlist: number
  totalGeneralUsers: number
  activeQuestsCount: number
  totalWaitlistCount: number
  hotlineNumber: string
  activeCertificatesCount: number
}

export interface AdminOutletContext {
  db: PortalDatabase
  session: PortalSession | null
  counts: AdminSummaryCounts
  onFeedback: (message: string) => void
  onSelectModule: (mod: AdminModule) => void
}

export function getActiveAdminModule(pathname: string): AdminModule {
  if (pathname.includes('/admin/psychologists')) return 'psychologists'
  if (pathname.includes('/admin/certificates')) return 'certificates'
  if (pathname.includes('/admin/monitoring') || pathname.includes('/admin/referrals')) {
    return 'monitoring'
  }
  if (pathname.includes('/admin/settings')) return 'settings'
  if (pathname.includes('/admin/users-coins')) return 'users_coins'
  if (pathname.includes('/admin/finance')) return 'finance'
  if (pathname.includes('/admin/content-config')) return 'content_config'
  return 'dashboard'
}

export function useAdminOutletContext() {
  return useOutletContext<AdminOutletContext>()
}
