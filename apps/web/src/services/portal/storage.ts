import { DEMO_CONFIG } from '@/config/demoConfig'
import { INITIAL_DEMO_DB } from '@/demo/data/demoDatabase'
import { EMPTY_PORTAL_DATABASE } from './emptyDatabase'
import type { PortalDatabase, PortalSession, Psychologist } from '@/types/portal'

export const STORAGE_KEY = DEMO_CONFIG.useDummySeedData
  ? 'eva_portal_db_demo_v3'
  : 'eva_portal_db_prod_v1'
export const SESSION_KEY = DEMO_CONFIG.useDummySeedData
  ? 'eva_portal_session_demo_v1'
  : 'eva_portal_session_prod_v1'
export const CHANGE_EVENT = 'eva:portal-db-updated'

export const INITIAL_DB: PortalDatabase = DEMO_CONFIG.useDummySeedData
  ? INITIAL_DEMO_DB
  : EMPTY_PORTAL_DATABASE

export function loadPortalDb(): PortalDatabase {
  if (typeof window === 'undefined') return INITIAL_DB
  try {
    let raw = window.localStorage.getItem(STORAGE_KEY)
    let needsSave = false

    if (!raw) {
      // Check if we can migrate from legacy v2 storage
      const legacyRaw = window.localStorage.getItem('eva_portal_db_demo_v2')
      if (legacyRaw) {
        raw = legacyRaw
        needsSave = true
      } else {
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(INITIAL_DB))
        return INITIAL_DB
      }
    }

    const parsed = JSON.parse(raw) as Partial<PortalDatabase>
    const rawPsychologists = parsed.psychologists ?? INITIAL_DB.psychologists
    const seedMap = new Map(INITIAL_DB.psychologists.map((p) => [p.id, p]))
    const existingIds = new Set<string>()

    const migratedPsychologists: Psychologist[] = rawPsychologists.map((p): Psychologist => {
      existingIds.add(p.id)
      const seedPsy = seedMap.get(p.id)

      let role = p.role ?? seedPsy?.role
      if (!role) {
        if (p.partnerId || p.practiceType === 'faskes') {
          role = 'professional_mitra'
        } else if (p.practiceType === 'mandiri') {
          role = 'relawan_profesional'
        } else {
          role = 'relawan_biasa'
        }
      }
      if (role === 'relawan_pro') role = 'relawan_utama'

      let upgradeRequest = p.upgradeRequest ?? seedPsy?.upgradeRequest
      if (upgradeRequest && ((upgradeRequest.targetRole as string) === 'relawan_pro')) {
        upgradeRequest = {
          ...upgradeRequest,
          targetRole: 'relawan_utama',
        }
      }

      const isPriorityMobile =
        p.isPriorityMobile !== undefined
          ? p.isPriorityMobile
          : seedPsy?.isPriorityMobile !== undefined
            ? seedPsy.isPriorityMobile
            : role === 'relawan_utama'

      const documents =
        p.documents && p.documents.length > 0
          ? p.documents
          : (seedPsy?.documents ?? p.documents)

      return {
        ...p,
        role,
        isPriorityMobile,
        upgradeRequest,
        documents,
      }
    })

    // Backfill any missing seed psychologists (e.g. Relawan Utama, Relawan, and Upgrade applicants)
    for (const seedPsy of INITIAL_DB.psychologists) {
      if (!existingIds.has(seedPsy.id)) {
        migratedPsychologists.push(seedPsy)
        existingIds.add(seedPsy.id)
        needsSave = true
      }
    }

    // Backfill any missing seed partners (e.g. pengajuan ulang, mitra nonaktif, dan pengajuan baru)
    const rawPartners = parsed.partners ?? INITIAL_DB.partners
    const existingPartnerIds = new Set(rawPartners.map((p) => p.id))
    const migratedPartners = [...rawPartners]

    for (const seedPartner of INITIAL_DB.partners) {
      if (!existingPartnerIds.has(seedPartner.id)) {
        migratedPartners.push(seedPartner)
        existingPartnerIds.add(seedPartner.id)
        needsSave = true
      }
    }

    const result: PortalDatabase = {
      partners: migratedPartners,
      psychologists: migratedPsychologists,
      referrals: parsed.referrals ?? INITIAL_DB.referrals,
      generalUsers: parsed.generalUsers ?? INITIAL_DB.generalUsers,
      copingQuests: parsed.copingQuests ?? INITIAL_DB.copingQuests,
      crisisConfig: parsed.crisisConfig ?? INITIAL_DB.crisisConfig,
      waitlistEntries: parsed.waitlistEntries ?? INITIAL_DB.waitlistEntries,
      faqs: parsed.faqs ?? INITIAL_DB.faqs,
    }

    if (needsSave) {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(result))
    }

    return result
  } catch {
    return INITIAL_DB
  }
}

export function savePortalDb(db: PortalDatabase) {
  if (typeof window === 'undefined') return
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(db))
  window.dispatchEvent(new CustomEvent(CHANGE_EVENT))
}

export function resetPortalDbToDefault() {
  if (typeof window === 'undefined') return
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(INITIAL_DB))
  window.dispatchEvent(new CustomEvent(CHANGE_EVENT))
}

export function getPortalSession(): PortalSession | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = window.localStorage.getItem(SESSION_KEY)
    return raw ? (JSON.parse(raw) as PortalSession) : null
  } catch {
    return null
  }
}

export function setPortalSession(session: PortalSession | null) {
  if (typeof window === 'undefined') return
  if (!session) {
    window.localStorage.removeItem(SESSION_KEY)
  } else {
    window.localStorage.setItem(SESSION_KEY, JSON.stringify(session))
  }
  window.dispatchEvent(new CustomEvent(CHANGE_EVENT))
}
