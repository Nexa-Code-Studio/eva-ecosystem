import { APP_CONFIG } from '@/config/appConfig'
import { getEmptyDashboardAnalyticsBaseline } from '@/data/mock/dashboardMetrics.mock'
import type { IPortalDataSource } from '@/services/contracts/portalDataSource'
import {
  buildDomainPsychologistFromRegister,
  mapBackendPricingToDomain,
  mapBackendPsychologistToDomain,
  normalizeVerificationStatus,
} from '@/services/contracts/portalMappers'
import { PORTAL_DB_CHANGE_EVENT } from '@/services/mock/mockPortalDataSource'
import { EMPTY_PORTAL_DATABASE } from '@/services/portal/emptyDatabase'
import type {
  BackendPricingConfigResponseDto,
  BackendPsychologistProfileResponseDto,
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

  async verifyPsychologist(
    psychologistId: string,
    payload: VerifyPsychologistRequestDto,
  ): Promise<Psychologist> {
    const db = this.loadSnapshot()
    const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
    const current = idx !== -1 ? db.psychologists[idx] : undefined

    try {
      await this.requestJson('/counselors/' + encodeURIComponent(psychologistId) + '/verify', {
        method: 'POST',
        body: JSON.stringify(payload),
      })
    } catch {
      // Fallback aman ke cache lokal saat endpoint membutuhkan admin JWT atau offline
    }

    if (!current) {
      throw new Error('Profil psikolog tidak ditemukan.')
    }

    const nowIso = new Date().toISOString()
    const updated: Psychologist = {
      ...current,
      verificationStatus: payload.status,
      verificationNotes: payload.notes?.trim() || null,
      verifiedAt: payload.status === 'verified' ? nowIso : null,
      status: payload.status === 'verified' ? 'active' : 'inactive',
      isOnline: payload.status === 'verified',
      reviewedAt: nowIso.slice(0, 10),
    }

    db.psychologists[idx] = updated
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
    return this.loadSnapshot().consultationSessions
  }
}
