import {
  INITIAL_MOCK_DB,
  MOCK_ADMIN_ACCOUNT,
  getMockDashboardAnalyticsBaseline,
} from '@/data/mock'
import {
  queryMockFinanceSummary,
  queryMockFinanceTransactionDetail,
  queryMockFinanceTransactions,
} from '@/data/mock/financeMetrics.mock'
import type { IPortalDataSource } from '@/services/contracts/portalDataSource'
import {
  buildDomainPsychologistFromRegister,
  normalizeVerificationStatus,
} from '@/services/contracts/portalMappers'
import type {
  AdminCoinTopupRequestDto,
  AdminCoinTopupResultDto,
  CreateFaqRequestDto,
  IssueCertificateRequestDto,
  PublicFaqsResultDto,
  RegisterPsychologistRequestDto,
  UpdateCoinEconomyConfigRequestDto,
  UpdateCrisisConfigRequestDto,
  UpdateFaqRequestDto,
  UpsertCertificateTemplateRequestDto,
  UpsertCoinPackageRequestDto,
  UpsertPlatformPricingRequestDto,
  UpsertPsychologistLevelRequestDto,
  VerifyPsychologistRequestDto,
} from '@/types/api/contracts'
import type {
  FinanceSummary,
  FinanceTransactionDetail,
  FinanceTransactionsQuery,
  PaginatedFinanceTransactions,
} from '@/types/domain/finance'
import type {
  BoothFeedbackEntry,
  BoothFeedbackListResult,
  BoothVisitorRole,
  CertificateEvaluationSummary,
  CertificateTemplate,
  CoinEconomyConfig,
  CoinPackage,
  CoinTopupTransaction,
  ConsultationSessionMonitoring,
  CounselorCertificateEligibility,
  CrisisConfig,
  FaqEntry,
  GeneralAppUser,
  IssuedPsychologistCertificate,
  LevelEvaluationBatchSummary,
  PlatformPricingConfig,
  PortalDatabase,
  PortalSession,
  Psychologist,
  PsychologistLevelConfig,
  SubmitBoothFeedbackPayload,
  SubmitBoothFeedbackResult,
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
      certificateTemplates:
        parsed.certificateTemplates && parsed.certificateTemplates.length > 0
          ? parsed.certificateTemplates
          : INITIAL_MOCK_DB.certificateTemplates,
      issuedCertificates:
        parsed.issuedCertificates && parsed.issuedCertificates.length > 0
          ? parsed.issuedCertificates
          : INITIAL_MOCK_DB.issuedCertificates,
      eligibleCounselorSummaries: parsed.eligibleCounselorSummaries ?? [],
      psychologistLevels:
        parsed.psychologistLevels && parsed.psychologistLevels.length > 0
          ? parsed.psychologistLevels
          : INITIAL_MOCK_DB.psychologistLevels,
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

  async fetchAdminPsychologists(): Promise<Psychologist[]> {
    return this.loadSnapshot().psychologists
  }

  async togglePsychologistDocumentVerified(
    psychologistId: string,
    docIdOrType: string,
  ): Promise<Psychologist> {
    const db = this.loadSnapshot()
    const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
    if (idx === -1) {
      throw new Error('Profil psikolog tidak ditemukan.')
    }

    const psy = db.psychologists[idx]
    const docs = psy.documents ?? []
    const targetType =
      docIdOrType.toLowerCase() === 'str'
        ? 'STR HIMPSI'
        : docIdOrType.toLowerCase() === 'sip'
          ? 'SIPP'
          : null

    const updated: Psychologist = {
      ...psy,
      documents: docs.map((d) =>
        d.id === docIdOrType || (targetType && d.docType === targetType)
          ? { ...d, verified: !d.verified }
          : d,
      ),
    }
    db.psychologists[idx] = updated
    this.saveSnapshot(db)
    return updated
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
    if (payload.status === 'verified' && !currentDocs.some((doc) => doc.verified)) {
      throw new Error(
        'Minimal 1 dokumen STR atau SIP harus diverifikasi valid sebelum menyetujui psikolog.',
      )
    }

    const updated: Psychologist = {
      ...current,
      verificationStatus: payload.status,
      verificationNotes: payload.notes?.trim() || null,
      verifiedAt: payload.status === 'verified' ? nowIso : null,
      status: payload.status === 'verified' ? 'active' : 'inactive',
      isOnline: payload.status === 'verified',
      reviewedAt: today,
    }

    db.psychologists[idx] = updated
    this.saveSnapshot(db)
    return updated
  }

  async updatePsychologistAccountStatus(
    psychologistId: string,
    status: 'verified' | 'suspended',
    notes?: string,
  ): Promise<Psychologist> {
    const db = this.loadSnapshot()
    const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
    if (idx === -1) {
      throw new Error('Profil psikolog tidak ditemukan.')
    }

    const current = db.psychologists[idx]
    const nowIso = new Date().toISOString()
    if (status === 'verified' && !(current.documents ?? []).some((d) => d.verified)) {
      throw new Error(
        'Minimal 1 dokumen STR atau SIP harus valid sebelum mengaktifkan kembali akun psikolog.',
      )
    }

    const updated: Psychologist = {
      ...current,
      verificationStatus: status,
      verificationNotes: notes?.trim() || current.verificationNotes,
      verifiedAt: status === 'verified' ? current.verifiedAt || nowIso : current.verifiedAt,
      status: status === 'verified' ? 'active' : 'inactive',
      isOnline: status === 'verified',
      reviewedAt: nowIso.slice(0, 10),
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

  async fetchAdminUsers(): Promise<GeneralAppUser[]> {
    return this.loadSnapshot().generalUsers
  }

  async fetchCoinTransactions(): Promise<CoinTopupTransaction[]> {
    return this.loadSnapshot().coinTransactions
  }

  async topUpUserCoins(payload: AdminCoinTopupRequestDto): Promise<AdminCoinTopupResultDto> {
    const db = this.loadSnapshot()
    const idx = db.generalUsers.findIndex((u) => u.id === payload.userId)
    if (idx === -1) {
      throw new Error('Pengguna tidak ditemukan.')
    }
    const delta = Math.trunc(payload.coinsGranted)
    if (!Number.isFinite(delta) || delta <= 0) {
      throw new Error('Jumlah koin harus lebih dari 0.')
    }

    const currentUser = db.generalUsers[idx]
    const updatedUser: GeneralAppUser = {
      ...currentUser,
      coinBalance: (currentUser.coinBalance ?? 0) + delta,
    }
    db.generalUsers[idx] = updatedUser

    const isGrant = payload.paymentMethod === 'Grant Admin (Gratis)'
    const effectiveAmountIdr = isGrant ? 0 : Math.max(0, Math.trunc(payload.amountIdr))
    const nowStr = new Date().toISOString().slice(0, 16).replace('T', ' ')

    const transaction: CoinTopupTransaction = {
      id: `trx-manual-${Date.now()}`,
      invoiceCode: `EVA-ADM-${Date.now().toString().slice(-6)}`,
      userId: updatedUser.id,
      userCode: updatedUser.userCode,
      userDisplayName: updatedUser.displayName,
      packageId: isGrant ? 'admin-grant' : 'admin-topup',
      packageName: payload.packageName.trim(),
      coinsGranted: delta,
      amountIdr: effectiveAmountIdr,
      paymentMethod: payload.paymentMethod,
      status: 'completed',
      createdAt: nowStr,
      completedAt: nowStr,
      adminNotes:
        payload.adminNotes?.trim() ||
        (isGrant
          ? 'Penambahan koin gratis oleh Admin EVA.'
          : `Top-up konvensional dikonfirmasi Admin EVA via ${payload.paymentMethod}.`),
    }

    db.coinTransactions.unshift(transaction)
    this.saveSnapshot(db)
    return { user: updatedUser, transaction }
  }

  async fetchCoinEconomyConfig(): Promise<CoinEconomyConfig> {
    return this.loadSnapshot().coinEconomyConfig
  }

  async updateCoinEconomyConfig(
    updates: UpdateCoinEconomyConfigRequestDto,
  ): Promise<CoinEconomyConfig> {
    const db = this.loadSnapshot()
    const today = new Date().toISOString().slice(0, 10)
    const updated: CoinEconomyConfig = {
      ...db.coinEconomyConfig,
      ...updates,
      updatedAt: today,
    }
    db.coinEconomyConfig = updated
    this.saveSnapshot(db)
    return updated
  }

  async fetchCoinPackages(): Promise<CoinPackage[]> {
    return this.loadSnapshot().coinPackages
  }

  async upsertCoinPackage(input: UpsertCoinPackageRequestDto): Promise<CoinPackage> {
    const db = this.loadSnapshot()
    const normalizedCode = input.code.trim().toUpperCase()
    const duplicate = db.coinPackages.find(
      (p) => p.code.trim().toUpperCase() === normalizedCode && p.id !== input.id,
    )
    if (duplicate) {
      throw new Error(`Kode paket "${normalizedCode}" sudah digunakan paket lain.`)
    }

    if (input.id) {
      const idx = db.coinPackages.findIndex((p) => p.id === input.id)
      if (idx !== -1) {
        const updated: CoinPackage = {
          ...db.coinPackages[idx],
          ...input,
          id: input.id,
          code: normalizedCode,
          name: input.name.trim(),
          description: input.description.trim(),
          isPopular: Boolean(input.isPopular),
        }
        db.coinPackages[idx] = updated
        this.saveSnapshot(db)
        return updated
      }
    }

    const created: CoinPackage = {
      ...input,
      id: `pkg-${Date.now()}-${db.coinPackages.length + 1}`,
      code: normalizedCode,
      name: input.name.trim(),
      description: input.description.trim(),
      isPopular: Boolean(input.isPopular),
    }
    db.coinPackages.push(created)
    this.saveSnapshot(db)
    return created
  }

  async toggleCoinPackageActive(packageId: string): Promise<CoinPackage> {
    const db = this.loadSnapshot()
    const idx = db.coinPackages.findIndex((p) => p.id === packageId)
    if (idx === -1) {
      throw new Error('Paket koin tidak ditemukan.')
    }
    const updated: CoinPackage = {
      ...db.coinPackages[idx],
      isActive: !db.coinPackages[idx].isActive,
    }
    db.coinPackages[idx] = updated
    this.saveSnapshot(db)
    return updated
  }

  async deleteCoinPackage(packageId: string): Promise<void> {
    const db = this.loadSnapshot()
    db.coinPackages = db.coinPackages.filter((p) => p.id !== packageId)
    this.saveSnapshot(db)
  }

  async fetchCrisisConfig(): Promise<CrisisConfig> {
    return this.loadSnapshot().crisisConfig
  }

  async updateCrisisConfig(updates: UpdateCrisisConfigRequestDto): Promise<CrisisConfig> {
    const db = this.loadSnapshot()
    const today = new Date().toISOString().slice(0, 10)
    const updated: CrisisConfig = {
      ...db.crisisConfig,
      ...updates,
      hotlineNumber: (updates.hotlineNumber ?? db.crisisConfig.hotlineNumber).trim().toUpperCase(),
      hotlineLabel: (updates.hotlineLabel ?? db.crisisConfig.hotlineLabel).trim(),
      updatedAt: today,
    }
    db.crisisConfig = updated
    this.saveSnapshot(db)
    return updated
  }

  async fetchPublicFaqs(): Promise<PublicFaqsResultDto> {
    const published = this.loadSnapshot()
      .faqs.filter((f) => f.isPublished)
      .sort((a, b) => (a.sortOrder ?? 9999) - (b.sortOrder ?? 9999))
    return { items: published, fromServer: true }
  }

  async fetchAdminFaqs(): Promise<FaqEntry[]> {
    return [...this.loadSnapshot().faqs].sort(
      (a, b) => (a.sortOrder ?? 9999) - (b.sortOrder ?? 9999),
    )
  }

  async createFaqEntry(input: CreateFaqRequestDto): Promise<FaqEntry> {
    const db = this.loadSnapshot()
    const maxOrder = db.faqs.reduce((max, item, idx) => Math.max(max, item.sortOrder ?? idx + 1), 0)
    const created: FaqEntry = {
      id: `faq-${Date.now()}`,
      category: input.category.trim().toUpperCase(),
      question: input.question.trim(),
      answer: input.answer.trim(),
      isPublished: input.isPublished ?? true,
      sortOrder: input.sortOrder ?? maxOrder + 1,
    }
    db.faqs = [...db.faqs, created].sort((a, b) => (a.sortOrder ?? 9999) - (b.sortOrder ?? 9999))
    this.saveSnapshot(db)
    return created
  }

  async updateFaqEntry(id: string, input: UpdateFaqRequestDto): Promise<FaqEntry> {
    const db = this.loadSnapshot()
    const idx = db.faqs.findIndex((f) => f.id === id)
    if (idx === -1) {
      throw new Error('Entri FAQ tidak ditemukan.')
    }
    const existing = db.faqs[idx]
    const updated: FaqEntry = {
      ...existing,
      category: input.category.trim().toUpperCase(),
      question: input.question.trim(),
      answer: input.answer.trim(),
      sortOrder: input.sortOrder ?? existing.sortOrder,
      isPublished: input.isPublished ?? existing.isPublished,
    }
    db.faqs[idx] = updated
    db.faqs = [...db.faqs].sort((a, b) => (a.sortOrder ?? 9999) - (b.sortOrder ?? 9999))
    this.saveSnapshot(db)
    return updated
  }

  async toggleFaqPublished(id: string): Promise<FaqEntry> {
    const db = this.loadSnapshot()
    const idx = db.faqs.findIndex((f) => f.id === id)
    if (idx === -1) {
      throw new Error('Entri FAQ tidak ditemukan.')
    }
    const updated: FaqEntry = { ...db.faqs[idx], isPublished: !db.faqs[idx].isPublished }
    db.faqs[idx] = updated
    this.saveSnapshot(db)
    return updated
  }

  async deleteFaqEntry(id: string): Promise<void> {
    const db = this.loadSnapshot()
    db.faqs = db.faqs.filter((f) => f.id !== id)
    this.saveSnapshot(db)
  }

  async fetchCertificateTemplates(): Promise<CertificateTemplate[]> {
    return this.loadSnapshot().certificateTemplates
  }

  async upsertCertificateTemplate(
    input: UpsertCertificateTemplateRequestDto,
  ): Promise<CertificateTemplate> {
    const db = this.loadSnapshot()
    const normalizedCode = input.code.trim().toUpperCase().replace(/\s+/g, '-')
    const today = new Date().toISOString().slice(0, 10)
    const duplicate = db.certificateTemplates.find(
      (t) => t.code.toUpperCase() === normalizedCode && t.id !== input.id,
    )
    if (duplicate) {
      throw new Error(`Kode template "${normalizedCode}" sudah digunakan.`)
    }

    if (input.id) {
      const idx = db.certificateTemplates.findIndex((t) => t.id === input.id)
      if (idx !== -1) {
        const updated: CertificateTemplate = {
          ...db.certificateTemplates[idx],
          ...input,
          id: input.id,
          code: normalizedCode,
          categoryCode: input.categoryCode.trim().toUpperCase(),
          updatedAt: today,
        }
        db.certificateTemplates[idx] = updated
        this.saveSnapshot(db)
        return updated
      }
    }

    const created: CertificateTemplate = {
      ...input,
      id: `tpl-${Date.now()}`,
      code: normalizedCode,
      categoryCode: input.categoryCode.trim().toUpperCase(),
      updatedAt: today,
    }
    db.certificateTemplates.push(created)
    this.saveSnapshot(db)
    return created
  }

  async toggleCertificateTemplateActive(templateId: string): Promise<CertificateTemplate> {
    const db = this.loadSnapshot()
    const idx = db.certificateTemplates.findIndex((t) => t.id === templateId)
    if (idx === -1) {
      throw new Error('Template sertifikat tidak ditemukan.')
    }
    const updated: CertificateTemplate = {
      ...db.certificateTemplates[idx],
      isActive: !db.certificateTemplates[idx].isActive,
    }
    db.certificateTemplates[idx] = updated
    this.saveSnapshot(db)
    return updated
  }

  async fetchIssuedCertificates(): Promise<IssuedPsychologistCertificate[]> {
    return this.loadSnapshot().issuedCertificates
  }

  async fetchEligibleCounselorsForCertificates(): Promise<CounselorCertificateEligibility[]> {
    const db = this.loadSnapshot()
    return db.psychologists
      .filter((p) => p.verificationStatus === 'verified')
      .map((p) => {
        const completedSessionsCount = db.consultationSessions.filter(
          (s) => s.counselorId === p.id && s.status === 'completed',
        ).length
        return {
          counselorId: p.id,
          fullName: p.fullName,
          strNumber: p.strNumber,
          verificationStatus: p.verificationStatus,
          completedSessionsCount,
          averageRating: completedSessionsCount > 0 ? 4.9 : null,
          activeCertificatesCount: db.issuedCertificates.filter(
            (c) => c.counselorId === p.id && c.status === 'active',
          ).length,
        }
      })
  }

  async issueCertificateManual(
    payload: IssueCertificateRequestDto,
  ): Promise<IssuedPsychologistCertificate> {
    const db = this.loadSnapshot()
    const psy = db.psychologists.find((p) => p.id === payload.counselorId)
    if (!psy || psy.verificationStatus !== 'verified') {
      throw new Error('Psikolog tidak ditemukan atau belum terverifikasi.')
    }
    const tpl = payload.templateId
      ? db.certificateTemplates.find((t) => t.id === payload.templateId)
      : undefined
    const categoryCode = (
      payload.customCategoryCode ||
      tpl?.categoryCode ||
      'PRO'
    )
      .trim()
      .toUpperCase()
    const now = new Date()
    const issueYear = now.getFullYear()
    const maxSeq = db.issuedCertificates
      .filter((c) => c.issueYear === issueYear && c.categoryCode === categoryCode)
      .reduce((max, c) => Math.max(max, c.sequenceNumber), 0)
    const seq = maxSeq + 1
    const certNumber = `EVA/CERT/${issueYear}/${categoryCode}/${String(seq).padStart(5, '0')}`
    const issueDateLabel = now.toLocaleDateString('id-ID', {
      day: '2-digit',
      month: 'long',
      year: 'numeric',
    })
    const rawDesc =
      payload.customDescription ||
      tpl?.description ||
      'Diberikan kepada {psychologist_name} (STR: {str_number}) No {certificate_number}.'

    const created: IssuedPsychologistCertificate = {
      id: `cert-${Date.now()}`,
      certificateNumber: certNumber,
      sequenceNumber: seq,
      issueYear,
      categoryCode,
      counselorId: psy.id,
      templateId: tpl?.id ?? null,
      title: (payload.customTitle || tpl?.title || 'SERTIFIKAT KREDENSIAL EVA').trim(),
      subtitle: (payload.customSubtitle || tpl?.subtitle || 'Clinical Excellence').trim(),
      recipientName: psy.fullName,
      strNumber: psy.strNumber,
      milestoneCriteria: (
        payload.customMilestoneCriteria ||
        tpl?.milestoneCriteria ||
        'Penghargaan Manual Admin'
      ).trim(),
      categoryLabel: (payload.customCategoryLabel || tpl?.categoryLabel || 'Psikolog Mandiri').trim(),
      description: rawDesc
        .replaceAll('{psychologist_name}', psy.fullName)
        .replaceAll('{str_number}', psy.strNumber)
        .replaceAll('{certificate_number}', certNumber)
        .replaceAll('{issue_date}', issueDateLabel),
      badgeColor: payload.customBadgeColor || tpl?.badgeColor || '#2563EB',
      triggerSource: 'manual',
      status: 'active',
      issueDateLabel,
      issuedAt: now.toISOString(),
    }

    db.issuedCertificates.unshift(created)
    this.saveSnapshot(db)
    return created
  }

  async evaluateAutoCertificates(): Promise<CertificateEvaluationSummary> {
    const db = this.loadSnapshot()
    const verified = db.psychologists.filter((p) => p.verificationStatus === 'verified')
    const activeAutoTemplates = db.certificateTemplates.filter(
      (t) => t.isActive && t.autoIssueEnabled && t.triggerType !== 'manual',
    )
    const newlyIssued: IssuedPsychologistCertificate[] = []

    for (const psy of verified) {
      const completedCount = db.consultationSessions.filter(
        (s) => s.counselorId === psy.id && s.status === 'completed',
      ).length
      const avgRating = completedCount > 0 ? 4.9 : 0

      for (const tpl of activeAutoTemplates) {
        const exists = db.issuedCertificates.some(
          (c) => c.counselorId === psy.id && c.templateId === tpl.id && c.status === 'active',
        )
        if (exists) continue
        if (completedCount < tpl.minCompletedSessions) continue
        if (
          tpl.triggerType === 'rating_milestone' &&
          avgRating < (tpl.minAverageRating ?? 4.8)
        ) {
          continue
        }
        const issued = await this.issueCertificateManual({
          counselorId: psy.id,
          templateId: tpl.id,
        })
        issued.triggerSource =
          tpl.triggerType === 'rating_milestone' ? 'auto_rating' : 'auto_sessions'
        newlyIssued.push(issued)
      }
    }

    return {
      evaluatedCounselors: verified.length,
      newlyIssuedCount: newlyIssued.length,
      issuedCertificates: newlyIssued,
    }
  }

  async revokeCertificate(
    certificateId: string,
    reason: string,
  ): Promise<IssuedPsychologistCertificate> {
    const db = this.loadSnapshot()
    const idx = db.issuedCertificates.findIndex((c) => c.id === certificateId)
    if (idx === -1) {
      throw new Error('Sertifikat tidak ditemukan.')
    }
    const updated: IssuedPsychologistCertificate = {
      ...db.issuedCertificates[idx],
      status: 'revoked',
      revokedAt: new Date().toISOString(),
      revocationReason: reason.trim(),
    }
    db.issuedCertificates[idx] = updated
    this.saveSnapshot(db)
    return updated
  }

  async downloadCertificatePdf(certificateId: string): Promise<{ blob: Blob; filename: string }> {
    const cert = this.loadSnapshot().issuedCertificates.find((c) => c.id === certificateId)
    if (!cert) {
      throw new Error('Sertifikat tidak ditemukan.')
    }
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 560"><rect width="800" height="560" fill="#FCFDFE"/><text x="400" y="120" text-anchor="middle" font-size="22" font-weight="bold">${cert.title}</text><text x="400" y="200" text-anchor="middle" font-size="28">${cert.recipientName}</text><text x="400" y="250" text-anchor="middle" font-size="14">${cert.certificateNumber} | ${cert.strNumber}</text></svg>`
    return {
      blob: new Blob([svg], { type: 'image/svg+xml' }),
      filename: `${cert.certificateNumber.replaceAll('/', '_')}.svg`,
    }
  }

  async fetchPsychologistLevels(): Promise<PsychologistLevelConfig[]> {
    return [...this.loadSnapshot().psychologistLevels].sort((a, b) => a.levelTier - b.levelTier)
  }

  async createPsychologistLevel(
    input: UpsertPsychologistLevelRequestDto,
  ): Promise<PsychologistLevelConfig> {
    const db = this.loadSnapshot()
    if (db.psychologistLevels.some((l) => l.levelTier === input.levelTier)) {
      throw new Error(`Tier level #${input.levelTier} sudah digunakan.`)
    }
    const created: PsychologistLevelConfig = {
      id: `lvl-${Date.now()}`,
      levelTier: input.levelTier,
      name: input.name.trim(),
      badgeIcon: input.badgeIcon.trim() || 'award',
      minCompletedSessions: input.minCompletedSessions,
      minAverageRating: input.minAverageRating,
      minConsultationHours: input.minConsultationHours,
      minReviewCount: input.minReviewCount,
      defaultSessionPrice: input.defaultSessionPrice,
      platformFeePercentage: input.platformFeePercentage,
      allowCustomPrice: input.allowCustomPrice,
      minCustomPrice: input.allowCustomPrice ? (input.minCustomPrice ?? null) : null,
      maxCustomPrice: input.allowCustomPrice ? (input.maxCustomPrice ?? null) : null,
      isActive: input.isActive,
      updatedAt: new Date().toISOString().slice(0, 10),
    }
    db.psychologistLevels.push(created)
    db.psychologistLevels.sort((a, b) => a.levelTier - b.levelTier)
    this.saveSnapshot(db)
    return created
  }

  async updatePsychologistLevel(
    levelId: string,
    input: UpsertPsychologistLevelRequestDto,
  ): Promise<PsychologistLevelConfig> {
    const db = this.loadSnapshot()
    const idx = db.psychologistLevels.findIndex((l) => l.id === levelId)
    if (idx === -1) {
      throw new Error('Konfigurasi level tidak ditemukan.')
    }
    if (db.psychologistLevels.some((l) => l.id !== levelId && l.levelTier === input.levelTier)) {
      throw new Error(`Tier level #${input.levelTier} sudah digunakan tier lain.`)
    }
    const updated: PsychologistLevelConfig = {
      ...db.psychologistLevels[idx],
      levelTier: input.levelTier,
      name: input.name.trim(),
      badgeIcon: input.badgeIcon.trim() || 'award',
      minCompletedSessions: input.minCompletedSessions,
      minAverageRating: input.minAverageRating,
      minConsultationHours: input.minConsultationHours,
      minReviewCount: input.minReviewCount,
      defaultSessionPrice: input.defaultSessionPrice,
      platformFeePercentage: input.platformFeePercentage,
      allowCustomPrice: input.allowCustomPrice,
      minCustomPrice: input.allowCustomPrice ? (input.minCustomPrice ?? null) : null,
      maxCustomPrice: input.allowCustomPrice ? (input.maxCustomPrice ?? null) : null,
      isActive: input.isActive,
      updatedAt: new Date().toISOString().slice(0, 10),
    }
    db.psychologistLevels[idx] = updated
    db.psychologistLevels.sort((a, b) => a.levelTier - b.levelTier)
    this.saveSnapshot(db)
    return updated
  }

  async togglePsychologistLevelActive(levelId: string): Promise<PsychologistLevelConfig> {
    const db = this.loadSnapshot()
    const idx = db.psychologistLevels.findIndex((l) => l.id === levelId)
    if (idx === -1) {
      throw new Error('Konfigurasi level tidak ditemukan.')
    }
    const updated: PsychologistLevelConfig = {
      ...db.psychologistLevels[idx],
      isActive: !db.psychologistLevels[idx].isActive,
      updatedAt: new Date().toISOString().slice(0, 10),
    }
    db.psychologistLevels[idx] = updated
    this.saveSnapshot(db)
    return updated
  }

  async deletePsychologistLevel(levelId: string): Promise<void> {
    const db = this.loadSnapshot()
    db.psychologistLevels = db.psychologistLevels.filter((l) => l.id !== levelId)
    this.saveSnapshot(db)
  }

  async evaluateAllPsychologistLevels(): Promise<LevelEvaluationBatchSummary> {
    const db = this.loadSnapshot()
    const verifiedCount = db.psychologists.filter((p) => p.verificationStatus === 'verified').length
    return {
      evaluatedCounselors: verifiedCount,
      upgradedCount: verifiedCount > 0 ? 1 : 0,
      message: `Evaluasi selesai untuk ${verifiedCount} psikolog terverifikasi sesuai konfigurasi tier aktif.`,
    }
  }

  private readMockBoothFeedbacks(): BoothFeedbackEntry[] {
    if (typeof window === 'undefined') return []
    try {
      const raw = window.localStorage.getItem('eva_mock_booth_feedbacks_v1')
      if (!raw) return []
      const parsed = JSON.parse(raw) as Array<
        Omit<BoothFeedbackEntry, 'usageLikelihood' | 'recommendationScore' | 'visitorRole'> & {
          usageLikelihood?: number
          recommendationScore?: number
          visitorRole?: BoothVisitorRole
        }
      >
      return parsed.map((item) => ({
        ...item,
        usageLikelihood: item.usageLikelihood ?? 3,
        recommendationScore: item.recommendationScore ?? 3,
        visitorRole: item.visitorRole === 'counselor' ? 'counselor' : 'user',
      }))
    } catch {
      return []
    }
  }

  private writeMockBoothFeedbacks(entries: BoothFeedbackEntry[]): void {
    if (typeof window === 'undefined') return
    window.localStorage.setItem('eva_mock_booth_feedbacks_v1', JSON.stringify(entries))
  }

  async submitBoothFeedback(payload: SubmitBoothFeedbackPayload): Promise<SubmitBoothFeedbackResult> {
    if (payload.rating < 1 || payload.rating > 5) {
      throw new Error('Ketuk bintang 1 sampai 5 terlebih dahulu.')
    }
    if (payload.usageLikelihood < 1 || payload.usageLikelihood > 5) {
      throw new Error('Pilih skala kemungkinan menggunakan aplikasi antara 1 sampai 5.')
    }
    if (payload.recommendationScore < 1 || payload.recommendationScore > 5) {
      throw new Error('Pilih skala rekomendasi ke teman antara 1 sampai 5.')
    }
    if (payload.visitorRole !== 'user' && payload.visitorRole !== 'counselor') {
      throw new Error('Pilih peran responden yang valid.')
    }
    if (payload.photos.length === 0) {
      throw new Error('Lampirkan minimal 1 foto selfie atau momen di booth.')
    }
    const readAsDataUrl = (file: File) =>
      new Promise<string>((resolve, reject) => {
        const reader = new FileReader()
        reader.onload = () => resolve(String(reader.result || ''))
        reader.onerror = () => reject(new Error('Gagal membaca foto.'))
        reader.readAsDataURL(file)
      })

    const nowIso = new Date().toISOString()
    const id = `bf-${Date.now()}`
    const photos = await Promise.all(
      payload.photos.slice(0, 5).map(async (file, index) => ({
        id: `${id}-p-${index + 1}`,
        mimeType: file.type || 'image/jpeg',
        fileSizeBytes: file.size,
        sortOrder: index,
        createdAt: nowIso,
        mockDataUrl: await readAsDataUrl(file),
      })),
    )

    const entry: BoothFeedbackEntry = {
      id,
      rating: payload.rating,
      usageLikelihood: payload.usageLikelihood,
      recommendationScore: payload.recommendationScore,
      visitorRole: payload.visitorRole,
      message: payload.message.trim(),
      visitorName: payload.visitorName?.trim() || null,
      visitorContact: payload.visitorContact?.trim() || null,
      eventLabel: payload.eventLabel?.trim() || 'Event Booth EVA',
      photos,
      createdAt: nowIso,
    }
    const existing = this.readMockBoothFeedbacks()
    existing.unshift(entry)
    this.writeMockBoothFeedbacks(existing)

    return {
      id,
      rating: entry.rating,
      usageLikelihood: entry.usageLikelihood,
      recommendationScore: entry.recommendationScore,
      visitorRole: entry.visitorRole,
      photoCount: photos.length,
      createdAt: nowIso,
      message: 'Terima kasih! Feedback dan foto booth Anda telah tersimpan (Mode Mock).',
    }
  }

  async fetchAdminBoothFeedbacks(params?: {
    rating?: number
    visitorRole?: BoothVisitorRole
    search?: string
    page?: number
    pageSize?: number
  }): Promise<BoothFeedbackListResult> {
    const all = this.readMockBoothFeedbacks()
    const roleCounts: Record<BoothVisitorRole, number> = { user: 0, counselor: 0 }
    for (const item of all) {
      roleCounts[item.visitorRole] += 1
    }

    const roleScoped = params?.visitorRole
      ? all.filter((item) => item.visitorRole === params.visitorRole)
      : all

    const counts: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
    let sum = 0
    let usageSum = 0
    let highUsageCount = 0
    let recSum = 0
    let promoterCount = 0
    for (const item of roleScoped) {
      if (item.rating >= 1 && item.rating <= 5) {
        counts[item.rating] = (counts[item.rating] ?? 0) + 1
        sum += item.rating
      }
      usageSum += item.usageLikelihood
      if (item.usageLikelihood >= 4) highUsageCount += 1
      recSum += item.recommendationScore
      if (item.recommendationScore >= 4) promoterCount += 1
    }

    const q = params?.search?.trim().toLowerCase() || ''
    const filtered = roleScoped.filter((item) => {
      if (params?.rating && item.rating !== params.rating) return false
      if (
        q &&
        !item.message.toLowerCase().includes(q) &&
        !(item.visitorName || '').toLowerCase().includes(q) &&
        !(item.visitorContact || '').toLowerCase().includes(q)
      ) {
        return false
      }
      return true
    })

    const totalScoped = roleScoped.length
    const pageSize = Math.max(1, params?.pageSize ?? 10)
    const page = Math.max(1, params?.page ?? 1)
    const start = (page - 1) * pageSize
    return {
      summary: {
        totalCount: totalScoped,
        averageRating: totalScoped > 0 ? Math.round((sum / totalScoped) * 100) / 100 : 0,
        ratingCounts: counts,
        roleCounts,
        averageUsageLikelihood: totalScoped > 0 ? Math.round((usageSum / totalScoped) * 100) / 100 : 0,
        highUsageIntentCount: highUsageCount,
        highUsageIntentPercentage:
          totalScoped > 0 ? Math.round((highUsageCount / totalScoped) * 1000) / 10 : 0,
        averageRecommendationScore:
          totalScoped > 0 ? Math.round((recSum / totalScoped) * 100) / 100 : 0,
        promoterCount,
        promoterPercentage:
          totalScoped > 0 ? Math.round((promoterCount / totalScoped) * 1000) / 10 : 0,
      },
      items: filtered.slice(start, start + pageSize),
      total: filtered.length,
      page,
      pageSize,
    }
  }

  async fetchAdminBoothFeedbackPhotoUrl(feedbackId: string, photoId: string): Promise<string> {
    const all = this.readMockBoothFeedbacks()
    const found = all.find((item) => item.id === feedbackId)
    const photo = found?.photos.find((p) => p.id === photoId)
    if (!photo?.mockDataUrl) {
      throw new Error('Foto booth tidak ditemukan di mode mock.')
    }
    return photo.mockDataUrl
  }

  async deleteAdminBoothFeedback(feedbackId: string): Promise<void> {
    const next = this.readMockBoothFeedbacks().filter((item) => item.id !== feedbackId)
    this.writeMockBoothFeedbacks(next)
  }

  async fetchAdminFinanceSummary(params: {
    from: string
    to: string
  }): Promise<FinanceSummary> {
    return queryMockFinanceSummary(params)
  }

  async fetchAdminFinanceTransactions(
    query: FinanceTransactionsQuery,
  ): Promise<PaginatedFinanceTransactions> {
    return queryMockFinanceTransactions(query)
  }

  async fetchAdminFinanceTransactionDetail(
    transactionId: string,
  ): Promise<FinanceTransactionDetail> {
    return queryMockFinanceTransactionDetail(transactionId)
  }
}
