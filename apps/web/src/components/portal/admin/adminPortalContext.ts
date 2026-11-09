import { useOutletContext } from 'react-router'
import type { PortalDatabase } from '@/types/portal'
import type { PortalSession } from '@/lib/portalStore'

export type AdminModule =
  | 'dashboard'
  | 'psychologists'
  | 'partners'
  | 'referrals'
  | 'users_coins'
  | 'content_config'

export interface AdminSummaryCounts {
  pendingMandiri: number
  approvedMandiri: number
  faskesPsy: number
  pendingPartners: number
  approvedPartners: number
  crisisUsers: number
  unassignedRefs: number
  newWaitlist: number
  totalGeneralUsers: number
  activeQuestsCount: number
  totalWaitlistCount: number
  hotlineNumber: string
  pendingPsyAction?: number
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
  if (pathname.includes('/admin/partners')) return 'partners'
  if (pathname.includes('/admin/referrals')) return 'referrals'
  if (pathname.includes('/admin/users-coins')) return 'users_coins'
  if (pathname.includes('/admin/content-config')) return 'content_config'
  return 'dashboard'
}

export function useAdminOutletContext() {
  return useOutletContext<AdminOutletContext>()
}
