import { APP_CONFIG } from '@/config/appConfig'
import { getEmptyDashboardAnalyticsBaseline } from '@/data/mock/dashboardMetrics.mock'
import type { IPortalDataSource } from '@/services/contracts/portalDataSource'
import {
  buildDomainPsychologistFromRegister,
  mapBackendAdminSessionToDomain,
  mapBackendAdminUserToDomain,
  mapBackendCoinEconomyToDomain,
  mapBackendCoinPackageToDomain,
  mapBackendCoinTransactionToDomain,
  mapBackendPricingToDomain,
  mapBackendPsychologistToDomain,
  normalizeVerificationStatus,
} from '@/services/contracts/portalMappers'
import { PORTAL_DB_CHANGE_EVENT } from '@/services/mock/mockPortalDataSource'
import { EMPTY_PORTAL_DATABASE } from '@/services/portal/emptyDatabase'
import type {
  AdminCoinTopupRequestDto,
  AdminCoinTopupResultDto,
  BackendAdminCoinTopupResponseDto,
  BackendAdminSessionDto,
  BackendAdminUserDto,
  BackendCoinEconomyConfigDto,
  BackendCoinPackageDto,
  BackendCoinTransactionDto,
  BackendPricingConfigResponseDto,
  BackendPsychologistProfileResponseDto,
  RegisterPsychologistRequestDto,
  UpdateCoinEconomyConfigRequestDto,
  UpsertCoinPackageRequestDto,
  UpsertPlatformPricingRequestDto,
  VerifyPsychologistRequestDto,
} from '@/types/api/contracts'
import type {
  CoinEconomyConfig,
  CoinPackage,
  CoinTopupTransaction,
  ConsultationSessionMonitoring,
  GeneralAppUser,
  PlatformPricingConfig,
  PortalDatabase,
  PortalSession,
  Psychologist,
} from '@/types/domain/portal'

const PROD_STORAGE_KEY = 'eva_portal_db_prod_v2'
const PROD_SESSION_KEY = 'eva_portal_session_prod_v2'
const REQUEST_TIMEOUT_MS = 6000

export class RemotePortalDataSource implements IPortalDataSource {
  readonly mode = 'remote' as const
  readonly storageKey = PROD_STORAGE_KEY
  readonly sessionKey = PROD_SESSION_KEY
  readonly apiBaseUrl = APP_CONFIG.apiBaseUrl.replace(/\/+$/, '')

  private async requestJson<T>(
    path: string,
    init?: RequestInit,
  ): Promise<T> {
    const controller = new AbortController()
    const timeout = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS)
    const session = this.getSession()

    try {
      const response = await fetch(`${this.apiBaseUrl}${path}`, {
        ...init,
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
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

      return (await response.json()) as T
    } finally {
      window.clearTimeout(timeout)
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

  async registerPsychologist(payload: RegisterPsychologistRequestDto): Promise<Psychologist> {
    const db = this.loadSnapshot()
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

      db.psychologists.unshift(mapped)
      this.saveSnapshot(db)
      return mapped
    } catch (err) {
      // Hanya lempar ulang error validasi bisnis (4xx); fallback cache lokal jika offline
      if (err instanceof Error && !err.name.includes('Abort') && !err.message.includes('fetch')) {
        throw err
      }
      const fallback = buildDomainPsychologistFromRegister(payload)
      db.psychologists.unshift(fallback)
      this.saveSnapshot(db)
      return fallback
    }
  }

  async fetchAdminPsychologists(): Promise<Psychologist[]> {
    const db = this.loadSnapshot()
    try {
      const list = await this.requestJson<BackendPsychologistProfileResponseDto[]>('/admin/counselors')
      const existingMap = new Map(db.psychologists.map((p) => [p.id, p]))
      const mapped = list.map((dto) => mapBackendPsychologistToDomain(dto, existingMap.get(dto.id)))
      db.psychologists = mapped
      this.saveSnapshot(db)
      return mapped
    } catch {
      return db.psychologists
    }
  }

  async togglePsychologistDocumentVerified(
    psychologistId: string,
    docIdOrType: string,
  ): Promise<Psychologist> {
    const db = this.loadSnapshot()
    const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
    const current = idx !== -1 ? db.psychologists[idx] : undefined
    const matchedDoc = current?.documents?.find((d) => d.id === docIdOrType)
    const docType: 'str' | 'sip' =
      docIdOrType.toLowerCase() === 'sip' || matchedDoc?.docType === 'SIPP' ? 'sip' : 'str'

    const dto = await this.requestJson<BackendPsychologistProfileResponseDto>(
      `/admin/counselors/${encodeURIComponent(psychologistId)}/documents/${docType}/verify`,
      { method: 'PATCH' },
    )

    const updated = mapBackendPsychologistToDomain(dto, current)
    if (idx !== -1) {
      db.psychologists[idx] = updated
    } else {
      db.psychologists.unshift(updated)
    }
    this.saveSnapshot(db)
    return updated
  }

  async verifyPsychologist(
    psychologistId: string,
    payload: VerifyPsychologistRequestDto,
  ): Promise<Psychologist> {
    const db = this.loadSnapshot()
    const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
    const current = idx !== -1 ? db.psychologists[idx] : undefined
    if (!current) {
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
    const updated: Psychologist = {
      ...current,
      verificationStatus: nextStatus,
      verificationNotes: res.verification_notes ?? payload.notes?.trim() ?? null,
      verifiedAt: res.verified_at ?? (nextStatus === 'verified' ? nowIso : null),
      status: nextStatus === 'verified' ? 'active' : 'inactive',
      isOnline: nextStatus === 'verified',
      reviewedAt: (res.verified_at ?? nowIso).slice(0, 10),
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
    const current = idx !== -1 ? db.psychologists[idx] : undefined

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

    const updated = mapBackendPsychologistToDomain(dto, current)
    if (idx !== -1) {
      db.psychologists[idx] = updated
    } else {
      db.psychologists.unshift(updated)
    }
    this.saveSnapshot(db)
    return updated
  }

  async fetchActivePricing(): Promise<PlatformPricingConfig> {
    const db = this.loadSnapshot()
    try {
      const dto = await this.requestJson<BackendPricingConfigResponseDto>('/pricing/active')
      const mapped = mapBackendPricingToDomain(dto)
      db.pricingConfig = mapped
      this.saveSnapshot(db)
      return mapped
    } catch {
      return db.pricingConfig
    }
  }

  async fetchPricingHistory(): Promise<PlatformPricingConfig[]> {
    const db = this.loadSnapshot()
    try {
      const list = await this.requestJson<BackendPricingConfigResponseDto[]>('/pricing')
      const mapped = list.map(mapBackendPricingToDomain)
      if (mapped.length > 0) {
        db.pricingHistory = mapped
        this.saveSnapshot(db)
      }
      return mapped
    } catch {
      return db.pricingHistory
    }
  }

  async savePlatformPricing(
    payload: UpsertPlatformPricingRequestDto,
    existingConfigId?: string,
  ): Promise<PlatformPricingConfig> {
    const db = this.loadSnapshot()
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
      const archived = db.pricingHistory
        .filter((item) => item.id !== mapped.id)
        .map((item) =>
          item.status === 'active'
            ? { ...item, status: 'archived' as const, effectiveUntil: mapped.effectiveFrom }
            : item,
        )

      db.pricingConfig = mapped
      db.pricingHistory = [mapped, ...archived]
      this.saveSnapshot(db)
      return mapped
    } catch {
      const nowIso = new Date().toISOString()
      const archived = db.pricingHistory.map((item) =>
        item.status === 'active'
          ? { ...item, status: 'archived' as const, effectiveUntil: nowIso }
          : item,
      )
      const fallback: PlatformPricingConfig = {
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
      this.saveSnapshot(db)
      return fallback
    }
  }

  async fetchConsultationSessions(): Promise<ConsultationSessionMonitoring[]> {
    const db = this.loadSnapshot()
    try {
      const list = await this.requestJson<BackendAdminSessionDto[]>('/admin/sessions')
      const mapped = list.map(mapBackendAdminSessionToDomain)
      db.consultationSessions = mapped
      this.saveSnapshot(db)
      return mapped
    } catch {
      return db.consultationSessions
    }
  }

  async fetchAdminUsers(): Promise<GeneralAppUser[]> {
    const db = this.loadSnapshot()
    try {
      const list = await this.requestJson<BackendAdminUserDto[]>('/admin/users')
      const existingMap = new Map(db.generalUsers.map((u) => [u.id, u]))
      const mapped = list.map((dto) => mapBackendAdminUserToDomain(dto, existingMap.get(dto.id)))
      db.generalUsers = mapped
      this.saveSnapshot(db)
      return mapped
    } catch {
      return db.generalUsers
    }
  }

  async fetchCoinTransactions(): Promise<CoinTopupTransaction[]> {
    const db = this.loadSnapshot()
    try {
      const list = await this.requestJson<BackendCoinTransactionDto[]>('/admin/coins/transactions')
      const mapped = list.map(mapBackendCoinTransactionToDomain)
      db.coinTransactions = mapped
      this.saveSnapshot(db)
      return mapped
    } catch {
      return db.coinTransactions
    }
  }

  async topUpUserCoins(payload: AdminCoinTopupRequestDto): Promise<AdminCoinTopupResultDto> {
    const db = this.loadSnapshot()
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

    const existing = db.generalUsers.find((u) => u.id === dto.user.id)
    const updatedUser = mapBackendAdminUserToDomain(dto.user, existing)
    const transaction = mapBackendCoinTransactionToDomain(dto.transaction)

    const idx = db.generalUsers.findIndex((u) => u.id === updatedUser.id)
    if (idx !== -1) {
      db.generalUsers[idx] = updatedUser
    } else {
      db.generalUsers.unshift(updatedUser)
    }
    db.coinTransactions.unshift(transaction)
    this.saveSnapshot(db)

    return { user: updatedUser, transaction }
  }

  async fetchCoinEconomyConfig(): Promise<CoinEconomyConfig> {
    const db = this.loadSnapshot()
    try {
      const dto = await this.requestJson<BackendCoinEconomyConfigDto>('/coins/economy')
      const mapped = mapBackendCoinEconomyToDomain(dto)
      db.coinEconomyConfig = mapped
      this.saveSnapshot(db)
      return mapped
    } catch {
      return db.coinEconomyConfig
    }
  }

  async updateCoinEconomyConfig(
    updates: UpdateCoinEconomyConfigRequestDto,
  ): Promise<CoinEconomyConfig> {
    const db = this.loadSnapshot()
    const payload = {
      base_price_per_coin_idr: Math.trunc(
        updates.basePricePerCoinIdr ?? db.coinEconomyConfig.basePricePerCoinIdr,
      ),
      free_trial_coins_new_user: Math.trunc(
        updates.freeTrialCoinsNewUser ?? db.coinEconomyConfig.freeTrialCoinsNewUser,
      ),
    }
    const dto = await this.requestJson<BackendCoinEconomyConfigDto>('/admin/coins/economy', {
      method: 'PUT',
      body: JSON.stringify(payload),
    })
    const mapped = mapBackendCoinEconomyToDomain(dto)
    db.coinEconomyConfig = mapped
    this.saveSnapshot(db)
    return mapped
  }

  async fetchCoinPackages(): Promise<CoinPackage[]> {
    const db = this.loadSnapshot()
    try {
      const list = await this.requestJson<BackendCoinPackageDto[]>('/admin/coins/packages')
      const mapped = list.map(mapBackendCoinPackageToDomain)
      db.coinPackages = mapped
      this.saveSnapshot(db)
      return mapped
    } catch {
      return db.coinPackages
    }
  }

  async upsertCoinPackage(input: UpsertCoinPackageRequestDto): Promise<CoinPackage> {
    const db = this.loadSnapshot()
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
    const idx = db.coinPackages.findIndex((p) => p.id === mapped.id)
    if (idx !== -1) {
      db.coinPackages[idx] = mapped
    } else {
      db.coinPackages.push(mapped)
    }
    this.saveSnapshot(db)
    return mapped
  }

  async toggleCoinPackageActive(packageId: string): Promise<CoinPackage> {
    const db = this.loadSnapshot()
    const dto = await this.requestJson<BackendCoinPackageDto>(
      `/admin/coins/packages/${encodeURIComponent(packageId)}/toggle`,
      { method: 'PATCH' },
    )
    const mapped = mapBackendCoinPackageToDomain(dto)
    const idx = db.coinPackages.findIndex((p) => p.id === mapped.id)
    if (idx !== -1) {
      db.coinPackages[idx] = mapped
    } else {
      db.coinPackages.push(mapped)
    }
    this.saveSnapshot(db)
    return mapped
  }

  async deleteCoinPackage(packageId: string): Promise<void> {
    const db = this.loadSnapshot()
    await this.requestJson(`/admin/coins/packages/${encodeURIComponent(packageId)}`, {
      method: 'DELETE',
    })
    db.coinPackages = db.coinPackages.filter((p) => p.id !== packageId)
    this.saveSnapshot(db)
  }
}
