import {
  INITIAL_MOCK_DB,
  MOCK_ADMIN_ACCOUNT,
  getMockDashboardAnalyticsBaseline,
} from '@/data/mock'
import type { IPortalDataSource } from '@/services/contracts/portalDataSource'
import type { PortalDatabase, PortalSession, Psychologist } from '@/types/domain/portal'

export const PORTAL_DB_CHANGE_EVENT = 'eva:portal-db-updated'

const MOCK_STORAGE_KEY = 'eva_portal_db_demo_v3'
const MOCK_SESSION_KEY = 'eva_portal_session_demo_v1'

function hydrateAndBackfillMockDb(parsed: Partial<PortalDatabase>): {
  db: PortalDatabase
  needsSave: boolean
} {
  let needsSave = false
  const rawPsychologists = parsed.psychologists ?? INITIAL_MOCK_DB.psychologists
  const seedMap = new Map(INITIAL_MOCK_DB.psychologists.map((p) => [p.id, p]))
  const existingIds = new Set<string>()

  const migratedPsychologists: Psychologist[] = rawPsychologists.map((p): Psychologist => {
    existingIds.add(p.id)
    const seedPsy = seedMap.get(p.id)

    let role = p.role ?? seedPsy?.role
    if (!role) {
      if (p.partnerId || p.practiceType === 'faskes') {
        role = 'relawan_profesional_mitra'
      } else if (p.practiceType === 'mandiri') {
        role = 'relawan_profesional_non_mitra'
      } else {
        role = 'relawan_biasa'
      }
    }
    if ((role as string) === 'professional_mitra') {
      role = 'relawan_profesional_mitra'
      needsSave = true
    } else if ((role as string) === 'relawan_profesional') {
      role = 'relawan_profesional_non_mitra'
      needsSave = true
    } else if ((role as string) === 'relawan_pro' || (role as string) === 'relawan_utama') {
      role = 'relawan_biasa'
      needsSave = true
    }

    let upgradeRequest = p.upgradeRequest ?? seedPsy?.upgradeRequest
    if (upgradeRequest) {
      if ((upgradeRequest.targetRole as string) === 'relawan_profesional') {
        upgradeRequest = {
          ...upgradeRequest,
          targetRole: 'relawan_profesional_non_mitra',
        }
        needsSave = true
      } else if (
        (upgradeRequest.targetRole as string) === 'relawan_pro' ||
        (upgradeRequest.targetRole as string) === 'relawan_utama'
      ) {
        upgradeRequest = null
        needsSave = true
      }
    }

    const documents =
      p.documents && p.documents.length > 0
        ? p.documents
        : (seedPsy?.documents ?? p.documents)

    return {
      ...p,
      role,
      upgradeRequest,
      documents,
    }
  })

  for (const seedPsy of INITIAL_MOCK_DB.psychologists) {
    if (!existingIds.has(seedPsy.id)) {
      migratedPsychologists.push(seedPsy)
      existingIds.add(seedPsy.id)
      needsSave = true
    }
  }

  const rawPartners = parsed.partners ?? INITIAL_MOCK_DB.partners
  const existingPartnerIds = new Set(rawPartners.map((p) => p.id))
  const migratedPartners = [...rawPartners]

  for (const seedPartner of INITIAL_MOCK_DB.partners) {
    if (!existingPartnerIds.has(seedPartner.id)) {
      migratedPartners.push(seedPartner)
      existingPartnerIds.add(seedPartner.id)
      needsSave = true
    }
  }

  const userSeedMap = new Map(INITIAL_MOCK_DB.generalUsers.map((u) => [u.id, u]))
  const rawUsers = parsed.generalUsers ?? INITIAL_MOCK_DB.generalUsers
  const migratedUsers = rawUsers.map((u) => {
    const seedUser = userSeedMap.get(u.id)
    if (u.coinBalance === undefined || u.totalVoiceMinutesUsed === undefined) {
      needsSave = true
    }
    return {
      ...u,
      coinBalance: u.coinBalance ?? seedUser?.coinBalance ?? 10,
      totalVoiceMinutesUsed:
        u.totalVoiceMinutesUsed ?? seedUser?.totalVoiceMinutesUsed ?? u.voiceSessionsCount * 3,
    }
  })

  if (!parsed.coinEconomyConfig || !parsed.coinPackages || !parsed.coinTransactions) {
    needsSave = true
  }

  return {
    db: {
      partners: migratedPartners,
      psychologists: migratedPsychologists,
      referrals: parsed.referrals ?? INITIAL_MOCK_DB.referrals,
      generalUsers: migratedUsers,
      copingQuests: parsed.copingQuests ?? INITIAL_MOCK_DB.copingQuests,
      crisisConfig: parsed.crisisConfig ?? INITIAL_MOCK_DB.crisisConfig,
      waitlistEntries: parsed.waitlistEntries ?? INITIAL_MOCK_DB.waitlistEntries,
      faqs: parsed.faqs ?? INITIAL_MOCK_DB.faqs,
      coinEconomyConfig: parsed.coinEconomyConfig ?? INITIAL_MOCK_DB.coinEconomyConfig,
      coinPackages:
        parsed.coinPackages && parsed.coinPackages.length > 0
          ? parsed.coinPackages
          : INITIAL_MOCK_DB.coinPackages,
      coinTransactions:
        parsed.coinTransactions && parsed.coinTransactions.length > 0
          ? parsed.coinTransactions
          : INITIAL_MOCK_DB.coinTransactions,
    },
    needsSave,
  }
}

export class MockPortalDataSource implements IPortalDataSource {
  readonly mode = 'mock' as const
  readonly storageKey = MOCK_STORAGE_KEY
  readonly sessionKey = MOCK_SESSION_KEY

  loadSnapshot(): PortalDatabase {
    if (typeof window === 'undefined') return INITIAL_MOCK_DB
    try {
      let raw = window.localStorage.getItem(this.storageKey)
      let migratedFromLegacy = false

      if (!raw) {
        const legacyRaw = window.localStorage.getItem('eva_portal_db_demo_v2')
        if (legacyRaw) {
          raw = legacyRaw
          migratedFromLegacy = true
        } else {
          window.localStorage.setItem(this.storageKey, JSON.stringify(INITIAL_MOCK_DB))
          return INITIAL_MOCK_DB
        }
      }

      const parsed = JSON.parse(raw) as Partial<PortalDatabase>
      const { db, needsSave } = hydrateAndBackfillMockDb(parsed)

      if (needsSave || migratedFromLegacy) {
        window.localStorage.setItem(this.storageKey, JSON.stringify(db))
      }

      return db
    } catch {
      return INITIAL_MOCK_DB
    }
  }

  saveSnapshot(db: PortalDatabase): void {
    if (typeof window === 'undefined') return
    window.localStorage.setItem(this.storageKey, JSON.stringify(db))
    window.dispatchEvent(new CustomEvent(PORTAL_DB_CHANGE_EVENT))
  }

  resetSnapshot(): void {
    if (typeof window === 'undefined') return
    window.localStorage.setItem(this.storageKey, JSON.stringify(INITIAL_MOCK_DB))
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
    return getMockDashboardAnalyticsBaseline()
  }

  getAdminAccount() {
    return MOCK_ADMIN_ACCOUNT
  }
}

