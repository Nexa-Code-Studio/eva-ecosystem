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
import type { DashboardAnalyticsBaseline } from '@/types/domain/dashboard'
import type {
  BoothFeedbackEntry,
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
  fetchCertificateTemplates(): Promise<CertificateTemplate[]>
  upsertCertificateTemplate(input: UpsertCertificateTemplateRequestDto): Promise<CertificateTemplate>
  toggleCertificateTemplateActive(templateId: string): Promise<CertificateTemplate>
  fetchIssuedCertificates(): Promise<IssuedPsychologistCertificate[]>
  fetchEligibleCounselorsForCertificates(): Promise<CounselorCertificateEligibility[]>
  issueCertificateManual(
    payload: IssueCertificateRequestDto,
  ): Promise<IssuedPsychologistCertificate>
  evaluateAutoCertificates(): Promise<CertificateEvaluationSummary>
  revokeCertificate(
    certificateId: string,
    reason: string,
  ): Promise<IssuedPsychologistCertificate>
  downloadCertificatePdf(certificateId: string): Promise<{ blob: Blob; filename: string }>
  fetchPsychologistLevels(): Promise<PsychologistLevelConfig[]>
  createPsychologistLevel(
    input: UpsertPsychologistLevelRequestDto,
  ): Promise<PsychologistLevelConfig>
  updatePsychologistLevel(
    levelId: string,
    input: UpsertPsychologistLevelRequestDto,
  ): Promise<PsychologistLevelConfig>
  togglePsychologistLevelActive(levelId: string): Promise<PsychologistLevelConfig>
  deletePsychologistLevel(levelId: string): Promise<void>
  evaluateAllPsychologistLevels(): Promise<LevelEvaluationBatchSummary>
  submitBoothFeedback(payload: SubmitBoothFeedbackPayload): Promise<SubmitBoothFeedbackResult>
  fetchAdminBoothFeedbacks(params?: {
    rating?: number
    search?: string
    page?: number
    pageSize?: number
  }): Promise<BoothFeedbackListResult>
  fetchAdminBoothFeedbackPhotoUrl(feedbackId: string, photoId: string): Promise<string>
  deleteAdminBoothFeedback(feedbackId: string): Promise<void>
}
export type { BoothFeedbackEntry }
