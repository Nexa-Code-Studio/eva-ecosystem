import {
  INITIAL_MOCK_DB,
  MOCK_ADMIN_ACCOUNT,
  getMockDashboardAnalyticsBaseline,
} from '@/data/mock'
import type { IPortalDataSource } from '@/services/contracts/portalDataSource'
import {
  buildDomainPsychologistFromRegister,
  normalizeVerificationStatus,
} from '@/services/contracts/portalMappers'
import type {
  RegisterPsychologistRequestDto,
  UpsertPlatformPricingRequestDto,
  VerifyPsychologistRequestDto,
} from '@/types/api/contracts'
import type {
  ConsultationSessionMonitoring,
  PlatformPricingConfig,
  PortalDatabase,
  PortalSession,
  Psychologist,
} from '@/types/domain/portal'

export const PORTAL_DB_CHANGE_EVENT = 'eva:portal-db-updated'

const MOCK_STORAGE_KEY = 'eva_portal_db_demo_v6'
const MOCK_SESSION_KEY = 'eva_portal_session_demo_v2'

function hydrateMockDb(parsed: Partial<PortalDatabase>): {
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
    const normalizedStatus = normalizeVerificationStatus(p.verificationStatus)
    if (normalizedStatus !== p.verificationStatus) {
      needsSave = true
    }

    const filteredStoredDocs = p.documents?.filter(
      (doc) => doc.docType === 'STR HIMPSI' || doc.docType === 'SIPP',
    )
    if (p.documents && filteredStoredDocs && filteredStoredDocs.length !== p.documents.length) {
      needsSave = true
    }

    const documents =
      filteredStoredDocs && filteredStoredDocs.length > 0
        ? filteredStoredDocs
        : (seedPsy?.documents ?? filteredStoredDocs)

    return {
      ...p,
      titleDegree: p.titleDegree || seedPsy?.titleDegree || 'M.Psi., Psikolog',
      strNumber: p.strNumber || seedPsy?.strNumber || 'STR-PK-PENDING',
      association: p.association || seedPsy?.association || 'Himpunan Psikologi Indonesia (HIMPSI)',
      yearsOfExperience: p.yearsOfExperience ?? seedPsy?.yearsOfExperience ?? 1,
      isOnline: p.isOnline ?? (normalizedStatus === 'verified'),
      bufferTimeMinutes: p.bufferTimeMinutes ?? 10,
      submittedAt: p.submittedAt || seedPsy?.submittedAt || '2026-11-17',
      verificationStatus: normalizedStatus,
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

  const pricingConfig = parsed.pricingConfig ?? INITIAL_MOCK_DB.pricingConfig
  const pricingHistory =
    parsed.pricingHistory && parsed.pricingHistory.length > 0
      ? parsed.pricingHistory
      : INITIAL_MOCK_DB.pricingHistory
  const consultationSessions =
    parsed.consultationSessions && parsed.consultationSessions.length > 0
      ? parsed.consultationSessions
      : INITIAL_MOCK_DB.consultationSessions

  return {
    db: {
      psychologists: migratedPsychologists,
      consultationSessions,
      pricingConfig,
      pricingHistory,
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
      const raw = window.localStorage.getItem(this.storageKey)
      if (!raw) {
        window.localStorage.setItem(this.storageKey, JSON.stringify(INITIAL_MOCK_DB))
        return INITIAL_MOCK_DB
      }

      const parsed = JSON.parse(raw) as Partial<PortalDatabase>
      const { db, needsSave } = hydrateMockDb(parsed)

      if (needsSave) {
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

  async registerPsychologist(payload: RegisterPsychologistRequestDto): Promise<Psychologist> {
    const db = this.loadSnapshot()
    const emailLower = payload.email.trim().toLowerCase()
    const exists = db.psychologists.some((p) => p.email.toLowerCase() === emailLower)
    if (exists) {
      throw new Error('Alamat email ini sudah terdaftar pada antrean atau direktori psikolog.')
    }
    const created = buildDomainPsychologistFromRegister(payload)
    db.psychologists.unshift(created)
    this.saveSnapshot(db)
    return created
  }

  async verifyPsychologist(
    psychologistId: string,
    payload: VerifyPsychologistRequestDto,
  ): Promise<Psychologist> {
    const db = this.loadSnapshot()
    const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
    if (idx === -1) {
      throw new Error('Profil psikolog tidak ditemukan.')
    }

    const nowIso = new Date().toISOString()
    const today = nowIso.slice(0, 10)
    const current = db.psychologists[idx]
    const currentDocs = current.documents ?? []

    const updated: Psychologist = {
      ...current,
      verificationStatus: payload.status,
      verificationNotes: payload.notes?.trim() || null,
      verifiedAt: payload.status === 'verified' ? nowIso : null,
      status: payload.status === 'verified' ? 'active' : 'inactive',
      isOnline: payload.status === 'verified',
      reviewedAt: today,
      documents:
        payload.status === 'verified'
          ? currentDocs.map((doc) => ({ ...doc, verified: true }))
          : currentDocs,
    }

    db.psychologists[idx] = updated
    this.saveSnapshot(db)
    return updated
  }

  async fetchActivePricing(): Promise<PlatformPricingConfig> {
    return this.loadSnapshot().pricingConfig
  }

  async fetchPricingHistory(): Promise<PlatformPricingConfig[]> {
    return this.loadSnapshot().pricingHistory
  }

  async savePlatformPricing(
    payload: UpsertPlatformPricingRequestDto,
  ): Promise<PlatformPricingConfig> {
    const db = this.loadSnapshot()
    const nowIso = new Date().toISOString()
    const archivedHistory = db.pricingHistory.map((item) =>
      item.status === 'active'
        ? { ...item, status: 'archived' as const, effectiveUntil: nowIso }
        : item,
    )

    const nextConfig: PlatformPricingConfig = {
      id: `pricing-${Date.now()}`,
      sessionDurationMinutes: payload.session_duration_minutes,
      pricePerSession: payload.price_per_session,
      counselorSharePercentage: payload.counselor_share_percentage,
      platformFeePercentage: payload.platform_fee_percentage,
      extensionPricePerSession: payload.extension_price_per_session,
      status: 'active',
      notes: payload.notes?.trim() || null,
      effectiveFrom: nowIso,
      effectiveUntil: null,
      createdAt: nowIso,
    }

    db.pricingConfig = nextConfig
    db.pricingHistory = [nextConfig, ...archivedHistory]
    this.saveSnapshot(db)
    return nextConfig
  }

  async fetchConsultationSessions(): Promise<ConsultationSessionMonitoring[]> {
    return this.loadSnapshot().consultationSessions
  }
}
