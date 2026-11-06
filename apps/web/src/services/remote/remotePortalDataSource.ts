import { APP_CONFIG } from '@/config/appConfig'
import { getEmptyDashboardAnalyticsBaseline } from '@/data/mock/dashboardMetrics.mock'
import type { IPortalDataSource } from '@/services/contracts/portalDataSource'
import { PORTAL_DB_CHANGE_EVENT } from '@/services/mock/mockPortalDataSource'
import { EMPTY_PORTAL_DATABASE } from '@/services/portal/emptyDatabase'
import type { PortalDatabase, PortalSession } from '@/types/domain/portal'

const PROD_STORAGE_KEY = 'eva_portal_db_prod_v1'
const PROD_SESSION_KEY = 'eva_portal_session_prod_v1'

export class RemotePortalDataSource implements IPortalDataSource {
  readonly mode = 'remote' as const
  readonly storageKey = PROD_STORAGE_KEY
  readonly sessionKey = PROD_SESSION_KEY
  readonly apiBaseUrl = APP_CONFIG.apiBaseUrl

  loadSnapshot(): PortalDatabase {
    if (typeof window === 'undefined') return EMPTY_PORTAL_DATABASE
    try {
      const raw = window.localStorage.getItem(this.storageKey)
      if (!raw) {
        return EMPTY_PORTAL_DATABASE
      }
      const parsed = JSON.parse(raw) as Partial<PortalDatabase>
      return {
        partners: parsed.partners ?? EMPTY_PORTAL_DATABASE.partners,
        psychologists: parsed.psychologists ?? EMPTY_PORTAL_DATABASE.psychologists,
        referrals: parsed.referrals ?? EMPTY_PORTAL_DATABASE.referrals,
        generalUsers: parsed.generalUsers ?? EMPTY_PORTAL_DATABASE.generalUsers,
        copingQuests: parsed.copingQuests ?? EMPTY_PORTAL_DATABASE.copingQuests,
        crisisConfig: parsed.crisisConfig ?? EMPTY_PORTAL_DATABASE.crisisConfig,
        waitlistEntries: parsed.waitlistEntries ?? EMPTY_PORTAL_DATABASE.waitlistEntries,
        faqs: parsed.faqs ?? EMPTY_PORTAL_DATABASE.faqs,
      }
    } catch {
      return EMPTY_PORTAL_DATABASE
    }
  }

  saveSnapshot(db: PortalDatabase): void {
    if (typeof window === 'undefined') return
    window.localStorage.setItem(this.storageKey, JSON.stringify(db))
    window.dispatchEvent(new CustomEvent(PORTAL_DB_CHANGE_EVENT))
  }

  resetSnapshot(): void {
    if (typeof window === 'undefined') return
    window.localStorage.setItem(this.storageKey, JSON.stringify(EMPTY_PORTAL_DATABASE))
    window.dispatchEvent(new CustomEvent(PORTAL_DB_CHANGE_EVENT))
  }

  getSession(): PortalSession | null {
    if (typeof window === 'undefined') return null
    try {
      const raw = window.localStorage.getItem(this.sessionKey)
      return raw ? (JSON.parse(raw) as PortalSession) : null
    } catch {
      return null
    }
  }

  setSession(session: PortalSession | null): void {
    if (typeof window === 'undefined') return
    if (!session) {
      window.localStorage.removeItem(this.sessionKey)
    } else {
      window.localStorage.setItem(this.sessionKey, JSON.stringify(session))
    }
    window.dispatchEvent(new CustomEvent(PORTAL_DB_CHANGE_EVENT))
  }

  getDashboardBaseline() {
    return getEmptyDashboardAnalyticsBaseline()
  }

  getAdminAccount() {
    return {
      email: 'admin@eva.id',
      name: 'Administrator Pusat Ekosistem EVA',
    }
  }
}

