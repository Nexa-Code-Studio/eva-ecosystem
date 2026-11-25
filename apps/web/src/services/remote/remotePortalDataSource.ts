import { APP_CONFIG } from '@/config/appConfig'
import { getEmptyDashboardAnalyticsBaseline } from '@/data/mock/dashboardMetrics.mock'
import type { IPortalDataSource } from '@/services/contracts/portalDataSource'
import {
  buildDomainPsychologistFromRegister,
  mapBackendAdminBoothFeedbackListToDomain,
  mapBackendAdminSessionToDomain,
  mapBackendAdminUserToDomain,
  mapBackendCertificateTemplateToDomain,
  mapBackendCertificateToDomain,
  mapBackendCoinEconomyToDomain,
  mapBackendCoinPackageToDomain,
  mapBackendCoinTransactionToDomain,
  mapBackendCounselorEligibilityToDomain,
  mapBackendCrisisConfigToDomain,
  mapBackendEvaluationSummaryToDomain,
  mapBackendFaqToDomain,
  mapBackendLevelEvaluationToDomain,
  mapBackendPricingToDomain,
  mapBackendPsychologistLevelToDomain,
  mapBackendPsychologistToDomain,
  normalizeVerificationStatus,
} from '@/services/contracts/portalMappers'
import { PORTAL_DB_CHANGE_EVENT } from '@/services/mock/mockPortalDataSource'
import { EMPTY_PORTAL_DATABASE } from '@/services/portal/emptyDatabase'
import type {
  AdminCoinTopupRequestDto,
  AdminCoinTopupResultDto,
  BackendAdminBoothFeedbackListDto,
  BackendAdminCoinTopupResponseDto,
  BackendAdminSessionDto,
  BackendAdminUserDto,
  BackendCertificateEvaluationSummaryDto,
  BackendCertificateTemplateDto,
  BackendCoinEconomyConfigDto,
  BackendCoinPackageDto,
  BackendCoinTransactionDto,
  BackendCounselorCertificateEligibilityDto,
  BackendCrisisConfigDto,
  BackendFaqEntryDto,
  BackendLevelEvaluationBatchDto,
  BackendPricingConfigResponseDto,
  BackendPsychologistCertificateDto,
  BackendPsychologistLevelDto,
  BackendPsychologistProfileResponseDto,
  BackendPublicBoothFeedbackCreateDto,
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
  BoothFeedbackListResult,
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

const PROD_STORAGE_KEY = 'eva_portal_db_prod_v2'
const PROD_SESSION_KEY = 'eva_portal_session_prod_v2'
const REQUEST_TIMEOUT_MS = 6000

export class RemotePortalDataSource implements IPortalDataSource {
  readonly mode = 'remote' as const
  readonly storageKey = PROD_STORAGE_KEY
  readonly sessionKey = PROD_SESSION_KEY
  readonly apiBaseUrl = APP_CONFIG.apiBaseUrl.replace(/\/+$/, '')

  private async fetchWithAuth(
    path: string,
    init?: RequestInit,
    defaultHeaders: Record<string, string> = { 'Content-Type': 'application/json' },
  ): Promise<Response> {
    const controller = new AbortController()
    const timeout = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS)
    const session = this.getSession()

    try {
      const response = await fetch(`${this.apiBaseUrl}${path}`, {
        ...init,
        signal: controller.signal,
        headers: {
          ...defaultHeaders,
          ...(session?.accessToken ? { Authorization: `Bearer ${session.accessToken}` } : {}),
          ...init?.headers,
        },
      })

      if (!response.ok) {
        let detail = `Permintaan API gagal (${response.status})`
        try {
          const errBody = (await response.json()) as { detail?: string }
          if (errBody?.detail) detail = errBody.detail
        } catch {
          // Abaikan parse error body non-JSON
        }
        throw new Error(detail)
      }

      return response
    } finally {
      window.clearTimeout(timeout)
    }
  }

  private async requestJson<T>(
    path: string,
    init?: RequestInit,
  ): Promise<T> {
    const response = await this.fetchWithAuth(path, init)
    return (await response.json()) as T
  }

  private async requestBlob(path: string, fallbackFilename: string): Promise<{ blob: Blob; filename: string }> {
    const response = await this.fetchWithAuth(path, { method: 'GET' }, {})
    const disposition = response.headers.get('Content-Disposition') ?? ''
    const match = /filename="?([^";]+)"?/i.exec(disposition)
    const blob = await response.blob()
    return {
      blob,
      filename: match?.[1] || fallbackFilename,
    }
  }

  loadSnapshot(): PortalDatabase {
    if (typeof window === 'undefined') return EMPTY_PORTAL_DATABASE
    try {
      const raw = window.localStorage.getItem(this.storageKey)
      if (!raw) {
        return EMPTY_PORTAL_DATABASE
      }
      const parsed = JSON.parse(raw) as Partial<PortalDatabase>
      return {
        psychologists: (parsed.psychologists ?? EMPTY_PORTAL_DATABASE.psychologists).map((p) => ({
          ...p,
          verificationStatus: normalizeVerificationStatus(p.verificationStatus),
        })),
        consultationSessions:
          parsed.consultationSessions ?? EMPTY_PORTAL_DATABASE.consultationSessions,
        pricingConfig: parsed.pricingConfig ?? EMPTY_PORTAL_DATABASE.pricingConfig,
        pricingHistory:
          parsed.pricingHistory && parsed.pricingHistory.length > 0
            ? parsed.pricingHistory
            : EMPTY_PORTAL_DATABASE.pricingHistory,
        generalUsers: parsed.generalUsers ?? EMPTY_PORTAL_DATABASE.generalUsers,
        copingQuests: parsed.copingQuests ?? EMPTY_PORTAL_DATABASE.copingQuests,
        crisisConfig: parsed.crisisConfig ?? EMPTY_PORTAL_DATABASE.crisisConfig,
        waitlistEntries: parsed.waitlistEntries ?? EMPTY_PORTAL_DATABASE.waitlistEntries,
        faqs: parsed.faqs ?? EMPTY_PORTAL_DATABASE.faqs,
        coinEconomyConfig: parsed.coinEconomyConfig ?? EMPTY_PORTAL_DATABASE.coinEconomyConfig,
        coinPackages: parsed.coinPackages ?? EMPTY_PORTAL_DATABASE.coinPackages,
        coinTransactions: parsed.coinTransactions ?? EMPTY_PORTAL_DATABASE.coinTransactions,
        certificateTemplates:
          parsed.certificateTemplates ?? EMPTY_PORTAL_DATABASE.certificateTemplates,
        issuedCertificates:
          parsed.issuedCertificates ?? EMPTY_PORTAL_DATABASE.issuedCertificates,
        eligibleCounselorSummaries:
          parsed.eligibleCounselorSummaries ?? EMPTY_PORTAL_DATABASE.eligibleCounselorSummaries,
        psychologistLevels:
          parsed.psychologistLevels ?? EMPTY_PORTAL_DATABASE.psychologistLevels,
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

  private updateSnapshot(mutator: (db: PortalDatabase) => void): PortalDatabase {
    const db = this.loadSnapshot()
    mutator(db)
    this.saveSnapshot(db)
    return db
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
      email: APP_CONFIG.demoAdminEmail,
      password: APP_CONFIG.demoAdminPassword,
      name: 'Administrator Pusat Ekosistem EVA',
    }
  }

  private upsertItem<T extends { id: string }>(
    list: T[],
    item: T,
    insertPosition: 'start' | 'end' = 'start',
  ): void {
    const idx = list.findIndex((entry) => entry.id === item.id)
    if (idx !== -1) {
      list[idx] = item
    } else if (insertPosition === 'start') {
      list.unshift(item)
    } else {
      list.push(item)
    }
  }

  async registerPsychologist(payload: RegisterPsychologistRequestDto): Promise<Psychologist> {
    try {
      const dto = await this.requestJson<BackendPsychologistProfileResponseDto>(
        '/counselors/register',
        {
          method: 'POST',
          body: JSON.stringify({
            full_name: payload.full_name,
            title_degree: payload.title_degree,
            email: payload.email,
            password: payload.password,
            education: payload.education ?? null,
            str_number: payload.str_number,
            sip_number: payload.sip_number ?? null,
            association: payload.association,
            specializations: payload.specializations,
            years_of_experience: payload.years_of_experience,
            bio: payload.bio ?? null,
            certificate_doc_url: payload.certificate_doc_url ?? null,
          }),
        },
      )

      const mapped = mapBackendPsychologistToDomain(dto, {
        email: payload.email,
        phone: payload.phone,
        city: payload.city,
        education: payload.education,
        practiceSchedule: payload.practice_schedule,
      })

      this.updateSnapshot((db) => {
        db.psychologists.unshift(mapped)
      })
      return mapped
    } catch (err) {
      // Hanya lempar ulang error validasi bisnis (4xx); fallback cache lokal jika offline
      if (err instanceof Error && !err.name.includes('Abort') && !err.message.includes('fetch')) {
        throw err
      }
      const fallback = buildDomainPsychologistFromRegister(payload)
      this.updateSnapshot((db) => {
        db.psychologists.unshift(fallback)
      })
      return fallback
    }
  }

  async fetchAdminPsychologists(): Promise<Psychologist[]> {
    try {
      const list = await this.requestJson<BackendPsychologistProfileResponseDto[]>('/admin/counselors')
      let mapped: Psychologist[] = []
      this.updateSnapshot((db) => {
        const existingMap = new Map(db.psychologists.map((p) => [p.id, p]))
        mapped = list.map((dto) => mapBackendPsychologistToDomain(dto, existingMap.get(dto.id)))
        db.psychologists = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().psychologists
    }
  }

  async togglePsychologistDocumentVerified(
    psychologistId: string,
    docIdOrType: string,
  ): Promise<Psychologist> {
    const initial = this.loadSnapshot().psychologists.find((p) => p.id === psychologistId)
    const matchedDoc = initial?.documents?.find((d) => d.id === docIdOrType)
    const docType: 'str' | 'sip' =
      docIdOrType.toLowerCase() === 'sip' || matchedDoc?.docType === 'SIPP' ? 'sip' : 'str'

    const dto = await this.requestJson<BackendPsychologistProfileResponseDto>(
      `/admin/counselors/${encodeURIComponent(psychologistId)}/documents/${docType}/verify`,
      { method: 'PATCH' },
    )

    let updated!: Psychologist
    this.updateSnapshot((db) => {
      const current = db.psychologists.find((p) => p.id === psychologistId)
      updated = mapBackendPsychologistToDomain(dto, current)
      this.upsertItem(db.psychologists, updated, 'start')
    })
    return updated
  }

  async verifyPsychologist(
    psychologistId: string,
    payload: VerifyPsychologistRequestDto,
  ): Promise<Psychologist> {
    const exists = this.loadSnapshot().psychologists.some((p) => p.id === psychologistId)
    if (!exists) {
      throw new Error('Profil psikolog tidak ditemukan.')
    }

    const res = await this.requestJson<{
      verification_status: string
      verification_notes?: string | null
      verified_at?: string | null
    }>('/counselors/' + encodeURIComponent(psychologistId) + '/verify', {
      method: 'POST',
      body: JSON.stringify(payload),
    })

    const nextStatus = normalizeVerificationStatus(res.verification_status)
    const nowIso = new Date().toISOString()

    let updated!: Psychologist
    this.updateSnapshot((db) => {
      const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
      const current = idx !== -1 ? db.psychologists[idx] : undefined
      if (!current) {
        throw new Error('Profil psikolog tidak ditemukan.')
      }
      updated = {
        ...current,
        verificationStatus: nextStatus,
        verificationNotes: res.verification_notes ?? payload.notes?.trim() ?? null,
        verifiedAt: res.verified_at ?? (nextStatus === 'verified' ? nowIso : null),
        status: nextStatus === 'verified' ? 'active' : 'inactive',
        isOnline: nextStatus === 'verified',
        reviewedAt: (res.verified_at ?? nowIso).slice(0, 10),
      }
      db.psychologists[idx] = updated
    })
    return updated
  }

  async updatePsychologistAccountStatus(
    psychologistId: string,
    status: 'verified' | 'suspended',
    notes?: string,
  ): Promise<Psychologist> {
    const dto = await this.requestJson<BackendPsychologistProfileResponseDto>(
      `/admin/counselors/${encodeURIComponent(psychologistId)}/status`,
      {
        method: 'PATCH',
        body: JSON.stringify({
          status,
          notes: notes?.trim() || null,
        }),
      },
    )

    let updated!: Psychologist
    this.updateSnapshot((db) => {
      const current = db.psychologists.find((p) => p.id === psychologistId)
      updated = mapBackendPsychologistToDomain(dto, current)
      this.upsertItem(db.psychologists, updated, 'start')
    })
    return updated
  }

  async fetchActivePricing(): Promise<PlatformPricingConfig> {
    try {
      const dto = await this.requestJson<BackendPricingConfigResponseDto>('/pricing/active')
      const mapped = mapBackendPricingToDomain(dto)
      this.updateSnapshot((db) => {
        db.pricingConfig = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().pricingConfig
    }
  }

  async fetchPricingHistory(): Promise<PlatformPricingConfig[]> {
    try {
      const list = await this.requestJson<BackendPricingConfigResponseDto[]>('/pricing')
      const mapped = list.map(mapBackendPricingToDomain)
      if (mapped.length > 0) {
        this.updateSnapshot((db) => {
          db.pricingHistory = mapped
        })
      }
      return mapped
    } catch {
      return this.loadSnapshot().pricingHistory
    }
  }

  async savePlatformPricing(
    payload: UpsertPlatformPricingRequestDto,
    existingConfigId?: string,
  ): Promise<PlatformPricingConfig> {
    try {
      const endpoint =
        existingConfigId && existingConfigId !== 'pricing-default' && !existingConfigId.startsWith('pricing-')
          ? `/pricing/${encodeURIComponent(existingConfigId)}`
          : '/pricing'
      const method = endpoint.startsWith('/pricing/') ? 'PUT' : 'POST'

      const dto = await this.requestJson<BackendPricingConfigResponseDto>(endpoint, {
        method,
        body: JSON.stringify(payload),
      })

      const mapped = mapBackendPricingToDomain(dto)
      this.updateSnapshot((db) => {
        const archived = db.pricingHistory
          .filter((item) => item.id !== mapped.id)
          .map((item) =>
            item.status === 'active'
              ? { ...item, status: 'archived' as const, effectiveUntil: mapped.effectiveFrom }
              : item,
          )
        db.pricingConfig = mapped
        db.pricingHistory = [mapped, ...archived]
      })
      return mapped
    } catch {
      const nowIso = new Date().toISOString()
      let fallback!: PlatformPricingConfig
      this.updateSnapshot((db) => {
        const archived = db.pricingHistory.map((item) =>
          item.status === 'active'
            ? { ...item, status: 'archived' as const, effectiveUntil: nowIso }
            : item,
        )
        fallback = {
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
        db.pricingConfig = fallback
        db.pricingHistory = [fallback, ...archived]
      })
      return fallback
    }
  }

  async fetchConsultationSessions(): Promise<ConsultationSessionMonitoring[]> {
    try {
      const list = await this.requestJson<BackendAdminSessionDto[]>('/admin/sessions')
      const mapped = list.map(mapBackendAdminSessionToDomain)
      this.updateSnapshot((db) => {
        db.consultationSessions = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().consultationSessions
    }
  }

  async fetchAdminUsers(): Promise<GeneralAppUser[]> {
    try {
      const list = await this.requestJson<BackendAdminUserDto[]>('/admin/users')
      let mapped: GeneralAppUser[] = []
      this.updateSnapshot((db) => {
        const existingMap = new Map(db.generalUsers.map((u) => [u.id, u]))
        mapped = list.map((dto) => mapBackendAdminUserToDomain(dto, existingMap.get(dto.id)))
        db.generalUsers = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().generalUsers
    }
  }

  async fetchCoinTransactions(): Promise<CoinTopupTransaction[]> {
    try {
      const list = await this.requestJson<BackendCoinTransactionDto[]>('/admin/coins/transactions')
      const mapped = list.map(mapBackendCoinTransactionToDomain)
      this.updateSnapshot((db) => {
        db.coinTransactions = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().coinTransactions
    }
  }

  async topUpUserCoins(payload: AdminCoinTopupRequestDto): Promise<AdminCoinTopupResultDto> {
    const dto = await this.requestJson<BackendAdminCoinTopupResponseDto>(
      `/admin/users/${encodeURIComponent(payload.userId)}/coins/topup`,
      {
        method: 'POST',
        body: JSON.stringify({
          coins_granted: Math.trunc(payload.coinsGranted),
          amount_idr:
            payload.paymentMethod === 'Grant Admin (Gratis)'
              ? 0
              : Math.max(0, Math.trunc(payload.amountIdr)),
          payment_method: payload.paymentMethod,
          package_name: payload.packageName.trim(),
          admin_notes: payload.adminNotes?.trim() || null,
        }),
      },
    )

    let result!: AdminCoinTopupResultDto
    this.updateSnapshot((db) => {
      const existing = db.generalUsers.find((u) => u.id === dto.user.id)
      const updatedUser = mapBackendAdminUserToDomain(dto.user, existing)
      const transaction = mapBackendCoinTransactionToDomain(dto.transaction)

      this.upsertItem(db.generalUsers, updatedUser, 'start')
      this.upsertItem(db.coinTransactions, transaction, 'start')
      result = { user: updatedUser, transaction }
    })

    return result
  }

  async fetchCoinEconomyConfig(): Promise<CoinEconomyConfig> {
    try {
      const dto = await this.requestJson<BackendCoinEconomyConfigDto>('/coins/economy')
      const mapped = mapBackendCoinEconomyToDomain(dto)
      this.updateSnapshot((db) => {
        db.coinEconomyConfig = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().coinEconomyConfig
    }
  }

  async updateCoinEconomyConfig(
    updates: UpdateCoinEconomyConfigRequestDto,
  ): Promise<CoinEconomyConfig> {
    const currentEconomy = this.loadSnapshot().coinEconomyConfig
    const payload = {
      base_price_per_coin_idr: Math.trunc(
        updates.basePricePerCoinIdr ?? currentEconomy.basePricePerCoinIdr,
      ),
      free_trial_coins_new_user: Math.trunc(
        updates.freeTrialCoinsNewUser ?? currentEconomy.freeTrialCoinsNewUser,
      ),
    }
    const dto = await this.requestJson<BackendCoinEconomyConfigDto>('/admin/coins/economy', {
      method: 'PUT',
      body: JSON.stringify(payload),
    })
    const mapped = mapBackendCoinEconomyToDomain(dto)
    this.updateSnapshot((db) => {
      db.coinEconomyConfig = mapped
    })
    return mapped
  }

  async fetchCoinPackages(): Promise<CoinPackage[]> {
    try {
      const list = await this.requestJson<BackendCoinPackageDto[]>('/admin/coins/packages')
      const mapped = list.map(mapBackendCoinPackageToDomain)
      this.updateSnapshot((db) => {
        db.coinPackages = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().coinPackages
    }
  }

  async upsertCoinPackage(input: UpsertCoinPackageRequestDto): Promise<CoinPackage> {
    const isEdit = Boolean(input.id && !input.id.startsWith('pkg-'))
    const endpoint = isEdit
      ? `/admin/coins/packages/${encodeURIComponent(input.id!)}`
      : '/admin/coins/packages'
    const method = isEdit ? 'PUT' : 'POST'

    const dto = await this.requestJson<BackendCoinPackageDto>(endpoint, {
      method,
      body: JSON.stringify({
        code: input.code.trim().toUpperCase(),
        name: input.name.trim(),
        coins: Math.trunc(input.coins),
        bonus_coins: Math.trunc(input.bonusCoins),
        price_idr: Math.trunc(input.priceIdr),
        description: input.description.trim(),
        is_popular: Boolean(input.isPopular),
        is_active: Boolean(input.isActive),
      }),
    })

    const mapped = mapBackendCoinPackageToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.coinPackages, mapped, 'end')
    })
    return mapped
  }

  async toggleCoinPackageActive(packageId: string): Promise<CoinPackage> {
    const dto = await this.requestJson<BackendCoinPackageDto>(
      `/admin/coins/packages/${encodeURIComponent(packageId)}/toggle`,
      { method: 'PATCH' },
    )
    const mapped = mapBackendCoinPackageToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.coinPackages, mapped, 'end')
    })
    return mapped
  }

  async deleteCoinPackage(packageId: string): Promise<void> {
    await this.requestJson(`/admin/coins/packages/${encodeURIComponent(packageId)}`, {
      method: 'DELETE',
    })
    this.updateSnapshot((db) => {
      db.coinPackages = db.coinPackages.filter((p) => p.id !== packageId)
    })
  }

  async fetchCrisisConfig(): Promise<CrisisConfig> {
    try {
      const dto = await this.requestJson<BackendCrisisConfigDto>('/content/crisis-config')
      const mapped = mapBackendCrisisConfigToDomain(dto)
      this.updateSnapshot((db) => {
        db.crisisConfig = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().crisisConfig
    }
  }

  async updateCrisisConfig(updates: UpdateCrisisConfigRequestDto): Promise<CrisisConfig> {
    const current = this.loadSnapshot().crisisConfig
    const dto = await this.requestJson<BackendCrisisConfigDto>('/admin/content/crisis-config', {
      method: 'PUT',
      body: JSON.stringify({
        hotline_number: (updates.hotlineNumber ?? current.hotlineNumber).trim().toUpperCase(),
        hotline_label: (updates.hotlineLabel ?? current.hotlineLabel).trim(),
        extreme_depression_threshold: Math.trunc(
          updates.extremeDepressionThreshold ?? current.extremeDepressionThreshold,
        ),
        extreme_anxiety_threshold: Math.trunc(
          updates.extremeAnxietyThreshold ?? current.extremeAnxietyThreshold,
        ),
        auto_safety_net_modal:
          updates.autoSafetyNetModal ?? current.autoSafetyNetModal,
        allow_direct_independent_referral:
          updates.allowDirectIndependentReferral ?? current.allowDirectIndependentReferral,
      }),
    })
    const mapped = mapBackendCrisisConfigToDomain(dto)
    this.updateSnapshot((db) => {
      db.crisisConfig = mapped
    })
    return mapped
  }

  async fetchPublicFaqs(): Promise<PublicFaqsResultDto> {
    try {
      const list = await this.requestJson<BackendFaqEntryDto[]>('/content/faqs')
      return { items: list.map(mapBackendFaqToDomain), fromServer: true }
    } catch {
      return { items: [], fromServer: false }
    }
  }

  async fetchAdminFaqs(): Promise<FaqEntry[]> {
    try {
      const list = await this.requestJson<BackendFaqEntryDto[]>('/admin/content/faqs')
      const mapped = list.map(mapBackendFaqToDomain)
      this.updateSnapshot((db) => {
        db.faqs = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().faqs
    }
  }

  async createFaqEntry(input: CreateFaqRequestDto): Promise<FaqEntry> {
    const dto = await this.requestJson<BackendFaqEntryDto>('/admin/content/faqs', {
      method: 'POST',
      body: JSON.stringify({
        category: input.category.trim().toUpperCase(),
        question: input.question.trim(),
        answer: input.answer.trim(),
        sort_order: input.sortOrder ?? null,
        is_published: input.isPublished ?? true,
      }),
    })
    const mapped = mapBackendFaqToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.faqs, mapped, 'end')
      db.faqs.sort((a, b) => (a.sortOrder ?? 9999) - (b.sortOrder ?? 9999))
    })
    return mapped
  }

  async updateFaqEntry(id: string, input: UpdateFaqRequestDto): Promise<FaqEntry> {
    const dto = await this.requestJson<BackendFaqEntryDto>(
      `/admin/content/faqs/${encodeURIComponent(id)}`,
      {
        method: 'PUT',
        body: JSON.stringify({
          category: input.category.trim().toUpperCase(),
          question: input.question.trim(),
          answer: input.answer.trim(),
          sort_order: input.sortOrder ?? null,
          is_published: input.isPublished ?? null,
        }),
      },
    )
    const mapped = mapBackendFaqToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.faqs, mapped, 'end')
      db.faqs.sort((a, b) => (a.sortOrder ?? 9999) - (b.sortOrder ?? 9999))
    })
    return mapped
  }

  async toggleFaqPublished(id: string): Promise<FaqEntry> {
    const dto = await this.requestJson<BackendFaqEntryDto>(
      `/admin/content/faqs/${encodeURIComponent(id)}/toggle`,
      { method: 'PATCH' },
    )
    const mapped = mapBackendFaqToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.faqs, mapped, 'end')
    })
    return mapped
  }

  async deleteFaqEntry(id: string): Promise<void> {
    await this.requestJson(`/admin/content/faqs/${encodeURIComponent(id)}`, {
      method: 'DELETE',
    })
    this.updateSnapshot((db) => {
      db.faqs = db.faqs.filter((f) => f.id !== id)
    })
  }

  async fetchCertificateTemplates(): Promise<CertificateTemplate[]> {
    try {
      const list = await this.requestJson<BackendCertificateTemplateDto[]>(
        '/admin/certificates/templates',
      )
      const mapped = list.map(mapBackendCertificateTemplateToDomain)
      this.updateSnapshot((db) => {
        db.certificateTemplates = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().certificateTemplates
    }
  }

  async upsertCertificateTemplate(
    input: UpsertCertificateTemplateRequestDto,
  ): Promise<CertificateTemplate> {
    const isEdit = Boolean(input.id && !input.id.startsWith('tpl-'))
    const endpoint = isEdit
      ? `/admin/certificates/templates/${encodeURIComponent(input.id!)}`
      : '/admin/certificates/templates'
    const method = isEdit ? 'PUT' : 'POST'

    const dto = await this.requestJson<BackendCertificateTemplateDto>(endpoint, {
      method,
      body: JSON.stringify({
        code: input.code.trim().toUpperCase(),
        title: input.title.trim(),
        subtitle: input.subtitle.trim(),
        category_code: input.categoryCode.trim().toUpperCase(),
        category_label: input.categoryLabel.trim(),
        milestone_criteria: input.milestoneCriteria.trim(),
        description: input.description.trim(),
        badge_color: input.badgeColor.trim(),
        trigger_type: input.triggerType,
        min_completed_sessions: Math.max(0, Math.trunc(input.minCompletedSessions)),
        min_average_rating:
          input.triggerType === 'rating_milestone' ? (input.minAverageRating ?? 4.8) : null,
        auto_issue_enabled: Boolean(input.autoIssueEnabled),
        is_active: Boolean(input.isActive),
        svg_body_template: input.svgBodyTemplate ?? null,
      }),
    })

    const mapped = mapBackendCertificateTemplateToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.certificateTemplates, mapped, 'end')
    })
    return mapped
  }

  async toggleCertificateTemplateActive(templateId: string): Promise<CertificateTemplate> {
    const dto = await this.requestJson<BackendCertificateTemplateDto>(
      `/admin/certificates/templates/${encodeURIComponent(templateId)}/toggle`,
      { method: 'PATCH' },
    )
    const mapped = mapBackendCertificateTemplateToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.certificateTemplates, mapped, 'end')
    })
    return mapped
  }

  async fetchIssuedCertificates(): Promise<IssuedPsychologistCertificate[]> {
    try {
      const list = await this.requestJson<BackendPsychologistCertificateDto[]>(
        '/admin/certificates',
      )
      const mapped = list.map(mapBackendCertificateToDomain)
      this.updateSnapshot((db) => {
        db.issuedCertificates = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().issuedCertificates
    }
  }

  async fetchEligibleCounselorsForCertificates(): Promise<CounselorCertificateEligibility[]> {
    try {
      const list = await this.requestJson<BackendCounselorCertificateEligibilityDto[]>(
        '/admin/certificates/eligible-counselors',
      )
      const mapped = list.map(mapBackendCounselorEligibilityToDomain)
      this.updateSnapshot((db) => {
        db.eligibleCounselorSummaries = mapped
      })
      return mapped
    } catch {
      return this.loadSnapshot().eligibleCounselorSummaries
    }
  }

  async issueCertificateManual(
    payload: IssueCertificateRequestDto,
  ): Promise<IssuedPsychologistCertificate> {
    const dto = await this.requestJson<BackendPsychologistCertificateDto>(
      '/admin/certificates/issue',
      {
        method: 'POST',
        body: JSON.stringify({
          counselor_id: payload.counselorId,
          template_id: payload.templateId || null,
          custom_title: payload.customTitle?.trim() || null,
          custom_subtitle: payload.customSubtitle?.trim() || null,
          custom_category_code: payload.customCategoryCode?.trim().toUpperCase() || null,
          custom_category_label: payload.customCategoryLabel?.trim() || null,
          custom_milestone_criteria: payload.customMilestoneCriteria?.trim() || null,
          custom_description: payload.customDescription?.trim() || null,
          custom_badge_color: payload.customBadgeColor?.trim() || null,
        }),
      },
    )

    const mapped = mapBackendCertificateToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.issuedCertificates, mapped, 'start')
    })
    return mapped
  }

  async evaluateAutoCertificates(): Promise<CertificateEvaluationSummary> {
    const dto = await this.requestJson<BackendCertificateEvaluationSummaryDto>(
      '/admin/certificates/evaluate-auto',
      { method: 'POST' },
    )
    const mapped = mapBackendEvaluationSummaryToDomain(dto)
    if (mapped.issuedCertificates.length > 0) {
      this.updateSnapshot((db) => {
        for (const item of mapped.issuedCertificates) {
          this.upsertItem(db.issuedCertificates, item, 'start')
        }
      })
    }
    return mapped
  }

  async revokeCertificate(
    certificateId: string,
    reason: string,
  ): Promise<IssuedPsychologistCertificate> {
    const dto = await this.requestJson<BackendPsychologistCertificateDto>(
      `/admin/certificates/${encodeURIComponent(certificateId)}/revoke`,
      {
        method: 'PATCH',
        body: JSON.stringify({ reason: reason.trim() }),
      },
    )
    const mapped = mapBackendCertificateToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.issuedCertificates, mapped, 'start')
    })
    return mapped
  }

  async downloadCertificatePdf(certificateId: string): Promise<{ blob: Blob; filename: string }> {
    return this.requestBlob(
      `/admin/certificates/${encodeURIComponent(certificateId)}/download`,
      `sertifikat-${certificateId}.pdf`,
    )
  }

  async fetchPsychologistLevels(): Promise<PsychologistLevelConfig[]> {
    const list = await this.requestJson<BackendPsychologistLevelDto[]>('/admin/psychologist-levels')
    const mapped = list
      .map(mapBackendPsychologistLevelToDomain)
      .sort((a, b) => a.levelTier - b.levelTier)
    this.updateSnapshot((db) => {
      db.psychologistLevels = mapped
    })
    return mapped
  }

  async createPsychologistLevel(
    input: UpsertPsychologistLevelRequestDto,
  ): Promise<PsychologistLevelConfig> {
    const dto = await this.requestJson<BackendPsychologistLevelDto>('/admin/psychologist-levels', {
      method: 'POST',
      body: JSON.stringify({
        level_tier: input.levelTier,
        name: input.name.trim(),
        badge_icon: input.badgeIcon.trim() || 'award',
        min_completed_sessions: input.minCompletedSessions,
        min_average_rating: input.minAverageRating,
        min_consultation_hours: input.minConsultationHours,
        min_review_count: input.minReviewCount,
        default_session_price: input.defaultSessionPrice,
        platform_fee_percentage: input.platformFeePercentage,
        allow_custom_price: input.allowCustomPrice,
        min_custom_price: input.allowCustomPrice ? (input.minCustomPrice ?? null) : null,
        max_custom_price: input.allowCustomPrice ? (input.maxCustomPrice ?? null) : null,
        is_active: input.isActive,
      }),
    })
    const mapped = mapBackendPsychologistLevelToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.psychologistLevels, mapped, 'end')
      db.psychologistLevels.sort((a, b) => a.levelTier - b.levelTier)
    })
    return mapped
  }

  async updatePsychologistLevel(
    levelId: string,
    input: UpsertPsychologistLevelRequestDto,
  ): Promise<PsychologistLevelConfig> {
    const dto = await this.requestJson<BackendPsychologistLevelDto>(
      `/admin/psychologist-levels/${encodeURIComponent(levelId)}`,
      {
        method: 'PUT',
        body: JSON.stringify({
          level_tier: input.levelTier,
          name: input.name.trim(),
          badge_icon: input.badgeIcon.trim() || 'award',
          min_completed_sessions: input.minCompletedSessions,
          min_average_rating: input.minAverageRating,
          min_consultation_hours: input.minConsultationHours,
          min_review_count: input.minReviewCount,
          default_session_price: input.defaultSessionPrice,
          platform_fee_percentage: input.platformFeePercentage,
          allow_custom_price: input.allowCustomPrice,
          min_custom_price: input.allowCustomPrice ? (input.minCustomPrice ?? null) : null,
          max_custom_price: input.allowCustomPrice ? (input.maxCustomPrice ?? null) : null,
          is_active: input.isActive,
        }),
      },
    )
    const mapped = mapBackendPsychologistLevelToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.psychologistLevels, mapped, 'end')
      db.psychologistLevels.sort((a, b) => a.levelTier - b.levelTier)
    })
    return mapped
  }

  async togglePsychologistLevelActive(levelId: string): Promise<PsychologistLevelConfig> {
    const dto = await this.requestJson<BackendPsychologistLevelDto>(
      `/admin/psychologist-levels/${encodeURIComponent(levelId)}/toggle`,
      { method: 'PATCH' },
    )
    const mapped = mapBackendPsychologistLevelToDomain(dto)
    this.updateSnapshot((db) => {
      this.upsertItem(db.psychologistLevels, mapped, 'end')
      db.psychologistLevels.sort((a, b) => a.levelTier - b.levelTier)
    })
    return mapped
  }

  async deletePsychologistLevel(levelId: string): Promise<void> {
    await this.requestJson(`/admin/psychologist-levels/${encodeURIComponent(levelId)}`, {
      method: 'DELETE',
    })
    await this.fetchPsychologistLevels().catch(() => undefined)
  }

  async evaluateAllPsychologistLevels(): Promise<LevelEvaluationBatchSummary> {
    const dto = await this.requestJson<BackendLevelEvaluationBatchDto>(
      '/admin/psychologist-levels/evaluate-all',
      { method: 'POST' },
    )
    return mapBackendLevelEvaluationToDomain(dto)
  }

  async submitBoothFeedback(payload: SubmitBoothFeedbackPayload): Promise<SubmitBoothFeedbackResult> {
    const form = new FormData()
    form.append('rating', String(payload.rating))
    form.append('message', payload.message.trim())
    if (payload.visitorName?.trim()) {
      form.append('visitor_name', payload.visitorName.trim())
    }
    if (payload.visitorContact?.trim()) {
      form.append('visitor_contact', payload.visitorContact.trim())
    }
    if (payload.eventLabel?.trim()) {
      form.append('event_label', payload.eventLabel.trim())
    }
    for (const file of payload.photos) {
      form.append('photos', file)
    }

    const controller = new AbortController()
    const timeout = window.setTimeout(() => controller.abort(), 30000)
    try {
      const response = await fetch(`${this.apiBaseUrl}/content/booth-feedbacks`, {
        method: 'POST',
        body: form,
        signal: controller.signal,
      })
      if (!response.ok) {
        let detail = `Gagal mengirim feedback (${response.status})`
        try {
          const errBody = (await response.json()) as { detail?: string }
          if (errBody?.detail) detail = errBody.detail
        } catch {
          // Ignore non-JSON body
        }
        throw new Error(detail)
      }
      const dto = (await response.json()) as BackendPublicBoothFeedbackCreateDto
      return {
        id: dto.id,
        rating: dto.rating,
        photoCount: dto.photo_count,
        createdAt: dto.created_at,
        message: dto.message,
      }
    } finally {
      window.clearTimeout(timeout)
    }
  }

  async fetchAdminBoothFeedbacks(params?: {
    rating?: number
    search?: string
    page?: number
    pageSize?: number
  }): Promise<BoothFeedbackListResult> {
    const searchParams = new URLSearchParams()
    if (params?.rating) {
      searchParams.set('rating', String(params.rating))
    }
    if (params?.search?.trim()) {
      searchParams.set('search', params.search.trim())
    }
    if (params?.page) {
      searchParams.set('page', String(params.page))
    }
    if (params?.pageSize) {
      searchParams.set('page_size', String(params.pageSize))
    }
    const qs = searchParams.toString()
    const path = qs ? `/admin/content/booth-feedbacks?${qs}` : '/admin/content/booth-feedbacks'
    const dto = await this.requestJson<BackendAdminBoothFeedbackListDto>(path)
    return mapBackendAdminBoothFeedbackListToDomain(dto)
  }

  async fetchAdminBoothFeedbackPhotoUrl(feedbackId: string, photoId: string): Promise<string> {
    const { blob } = await this.requestBlob(
      `/admin/content/booth-feedbacks/${encodeURIComponent(feedbackId)}/photos/${encodeURIComponent(photoId)}`,
      `booth-${photoId}.jpg`,
    )
    return URL.createObjectURL(blob)
  }

  async deleteAdminBoothFeedback(feedbackId: string): Promise<void> {
    await this.requestJson(`/admin/content/booth-feedbacks/${encodeURIComponent(feedbackId)}`, {
      method: 'DELETE',
    })
  }
}
