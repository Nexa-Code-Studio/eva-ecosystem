import type {
  RegisterPsychologistRequestDto,
  UpsertPlatformPricingRequestDto,
  VerifyPsychologistRequestDto,
} from '@/types/api/contracts'
import type { DashboardAnalyticsBaseline } from '@/types/domain/dashboard'
import type {
  ConsultationSessionMonitoring,
  PlatformPricingConfig,
  PortalDatabase,
  PortalSession,
  Psychologist,
} from '@/types/domain/portal'

export interface AdminCredentialConfig {
  email: string
  password?: string
  name: string
}

export interface IPortalDataSource {
  readonly mode: 'mock' | 'remote'
  readonly storageKey: string
  readonly sessionKey: string
  loadSnapshot(): PortalDatabase
  saveSnapshot(db: PortalDatabase): void
  resetSnapshot(): void
  getSession(): PortalSession | null
  setSession(session: PortalSession | null): void
  getDashboardBaseline(): DashboardAnalyticsBaseline
  getAdminAccount(): AdminCredentialConfig
  registerPsychologist(payload: RegisterPsychologistRequestDto): Promise<Psychologist>
  verifyPsychologist(
    psychologistId: string,
    payload: VerifyPsychologistRequestDto,
  ): Promise<Psychologist>
  fetchActivePricing(): Promise<PlatformPricingConfig>
  fetchPricingHistory(): Promise<PlatformPricingConfig[]>
  savePlatformPricing(
    payload: UpsertPlatformPricingRequestDto,
    existingConfigId?: string,
  ): Promise<PlatformPricingConfig>
  fetchConsultationSessions(): Promise<ConsultationSessionMonitoring[]>
}
