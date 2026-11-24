import type {
  AdminCoinTopupRequestDto,
  AdminCoinTopupResultDto,
  CreateFaqRequestDto,
  PublicFaqsResultDto,
  RegisterPsychologistRequestDto,
  UpdateCoinEconomyConfigRequestDto,
  UpdateCrisisConfigRequestDto,
  UpdateFaqRequestDto,
  UpsertCoinPackageRequestDto,
  UpsertPlatformPricingRequestDto,
  VerifyPsychologistRequestDto,
} from '@/types/api/contracts'
import type { DashboardAnalyticsBaseline } from '@/types/domain/dashboard'
import type {
  CoinEconomyConfig,
  CoinPackage,
  CoinTopupTransaction,
  ConsultationSessionMonitoring,
  CrisisConfig,
  FaqEntry,
  GeneralAppUser,
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
  fetchAdminPsychologists(): Promise<Psychologist[]>
  togglePsychologistDocumentVerified(
    psychologistId: string,
    docIdOrType: string,
  ): Promise<Psychologist>
  verifyPsychologist(
    psychologistId: string,
    payload: VerifyPsychologistRequestDto,
  ): Promise<Psychologist>
  updatePsychologistAccountStatus(
    psychologistId: string,
    status: 'verified' | 'suspended',
    notes?: string,
  ): Promise<Psychologist>
  fetchActivePricing(): Promise<PlatformPricingConfig>
  fetchPricingHistory(): Promise<PlatformPricingConfig[]>
  savePlatformPricing(
    payload: UpsertPlatformPricingRequestDto,
    existingConfigId?: string,
  ): Promise<PlatformPricingConfig>
  fetchConsultationSessions(): Promise<ConsultationSessionMonitoring[]>
  fetchAdminUsers(): Promise<GeneralAppUser[]>
  fetchCoinTransactions(): Promise<CoinTopupTransaction[]>
  topUpUserCoins(payload: AdminCoinTopupRequestDto): Promise<AdminCoinTopupResultDto>
  fetchCoinEconomyConfig(): Promise<CoinEconomyConfig>
  updateCoinEconomyConfig(
    updates: UpdateCoinEconomyConfigRequestDto,
  ): Promise<CoinEconomyConfig>
  fetchCoinPackages(): Promise<CoinPackage[]>
  upsertCoinPackage(input: UpsertCoinPackageRequestDto): Promise<CoinPackage>
  toggleCoinPackageActive(packageId: string): Promise<CoinPackage>
  deleteCoinPackage(packageId: string): Promise<void>
  fetchCrisisConfig(): Promise<CrisisConfig>
  updateCrisisConfig(updates: UpdateCrisisConfigRequestDto): Promise<CrisisConfig>
  fetchPublicFaqs(): Promise<PublicFaqsResultDto>
  fetchAdminFaqs(): Promise<FaqEntry[]>
  createFaqEntry(input: CreateFaqRequestDto): Promise<FaqEntry>
  updateFaqEntry(id: string, input: UpdateFaqRequestDto): Promise<FaqEntry>
  toggleFaqPublished(id: string): Promise<FaqEntry>
  deleteFaqEntry(id: string): Promise<void>
}
