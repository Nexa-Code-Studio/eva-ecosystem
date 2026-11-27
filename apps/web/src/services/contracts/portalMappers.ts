import { buildPsychologistCertificates } from '@/data/mock/psychologists.mock'
import type {
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
  RegisterPsychologistRequestDto,
} from '@/types/api/contracts'
import type {
  CertificateEvaluationSummary,
  CertificateTemplate,
  CertificateTriggerType,
  CoinEconomyConfig,
  CoinPackage,
  CoinPaymentMethod,
  CoinTopupTransaction,
  CoinTransactionStatus,
  ConsultationSessionMonitoring,
  ConsultationSessionStatus,
  CounselorCertificateEligibility,
  CrisisConfig,
  FaqEntry,
  GeneralAppUser,
  IssuedPsychologistCertificate,
  LevelEvaluationBatchSummary,
  PlatformPricingConfig,
  PricingCalculation,
  PsychologistLevelConfig,
  Psychologist,
  VerificationStatus,
} from '@/types/domain/portal'

export function normalizeVerificationStatus(raw?: string | null): VerificationStatus {
  if (raw === 'approved' || raw === 'verified') return 'verified'
  if (raw === 'rejected') return 'rejected'
  if (raw === 'suspended') return 'suspended'
  return 'pending'
}

export function mapBackendPsychologistToDomain(
  dto: BackendPsychologistProfileResponseDto,
  existing?: Partial<Psychologist>,
): Psychologist {
  const verificationStatus = normalizeVerificationStatus(dto.verification_status)
  const resolvedEducation = dto.education ?? existing?.education
  const documents = buildPsychologistCertificates({
    fullName: `${dto.full_name}, ${dto.title_degree}`,
    strNumber: dto.str_number,
    strIssuedBy: dto.str_issuing_institution,
    strValidUntil: dto.str_expiry_date,
    strDocUrl: dto.str_doc_url ?? dto.certificate_doc_url,
    strVerified: dto.str_verified ?? verificationStatus === 'verified',
    strDocId: 'str',
    sipNumber: dto.sip_number,
    sipIssuedBy: dto.sip_issuing_institution,
    sipValidUntil: dto.sip_expiry_date,
    sipDocUrl: dto.sip_doc_url,
    sipVerified: dto.sip_verified ?? verificationStatus === 'verified',
    sipDocId: 'sip',
    association: dto.association,
    education: resolvedEducation,
    verified: verificationStatus === 'verified',
  })

  return {
    id: dto.id,
    userId: dto.user_id,
    fullName: dto.full_name,
    titleDegree: dto.title_degree,
    email:
      dto.email ??
      existing?.email ??
      `${dto.full_name.toLowerCase().replace(/[^a-z0-9]+/g, '.')}@eva.id`,
    phone: existing?.phone,
    city: existing?.city,
    education: resolvedEducation ?? undefined,
    strNumber: dto.str_number,
    sipNumber: dto.sip_number ?? null,
    association: dto.association,
    specializations: dto.specializations ?? [],
    yearsOfExperience: dto.years_of_experience,
    bio: dto.bio ?? null,
    profilePhotoUrl: dto.profile_photo_url ?? null,
    certificateDocUrl: dto.certificate_doc_url ?? dto.str_doc_url ?? null,
    verificationStatus,
    verificationNotes: dto.verification_notes ?? null,
    verifiedAt: dto.verified_at ?? null,
    isOnline: dto.is_online,
    bufferTimeMinutes: dto.buffer_time_minutes,
    coinBalance: Math.round(dto.wallet_balance ?? existing?.coinBalance ?? 0),
    practiceSchedule: existing?.practiceSchedule,
    status: verificationStatus === 'verified' ? (dto.is_online ? 'active' : 'on_leave') : 'inactive',
    submittedAt: dto.created_at.slice(0, 10),
    reviewedAt: dto.verified_at ? dto.verified_at.slice(0, 10) : existing?.reviewedAt,
    documents,
  }
}

export function buildDomainPsychologistFromRegister(
  payload: RegisterPsychologistRequestDto,
): Psychologist {
  const today = new Date().toISOString().slice(0, 10)
  const documents = buildPsychologistCertificates({
    fullName: `${payload.full_name.trim()}, ${payload.title_degree.trim()}`,
    strNumber: payload.str_number.trim().toUpperCase(),
    sipNumber: payload.sip_number?.trim().toUpperCase() || null,
    association: payload.association.trim(),
    education: payload.education?.trim(),
    verified: false,
  })

  return {
    id: `psy-mandiri-${Date.now()}`,
    fullName: payload.full_name.trim(),
    titleDegree: payload.title_degree.trim(),
    email: payload.email.trim(),
    password: payload.password,
    education: payload.education?.trim(),
    strNumber: payload.str_number.trim().toUpperCase(),
    sipNumber: payload.sip_number?.trim().toUpperCase() || null,
    association: payload.association.trim(),
    specializations: payload.specializations,
    yearsOfExperience: payload.years_of_experience,
    bio: payload.bio?.trim() || null,
    certificateDocUrl: payload.certificate_doc_url?.trim() || documents[0]?.fileName || null,
    verificationStatus: 'pending',
    verificationNotes: null,
    verifiedAt: null,
    isOnline: false,
    bufferTimeMinutes: 10,
    coinBalance: 0,
    status: 'inactive',
    submittedAt: today,
    documents,
  }
}

export function mapBackendPricingToDomain(
  dto: BackendPricingConfigResponseDto,
): PlatformPricingConfig {
  return {
    id: dto.id,
    sessionDurationMinutes: dto.session_duration_minutes,
    pricePerSession: dto.price_per_session,
    counselorSharePercentage: dto.counselor_share_percentage,
    platformFeePercentage: dto.platform_fee_percentage,
    extensionPricePerSession: dto.extension_price_per_session,
    status: dto.status,
    notes: dto.notes ?? null,
    effectiveFrom: dto.effective_from,
    effectiveUntil: dto.effective_until ?? null,
    createdAt: dto.created_at,
  }
}

export function calculatePricingBreakdown(
  config: Pick<
    PlatformPricingConfig,
    | 'sessionDurationMinutes'
    | 'pricePerSession'
    | 'counselorSharePercentage'
    | 'platformFeePercentage'
    | 'extensionPricePerSession'
  >,
  isExtended = false,
): PricingCalculation {
  const basePrice = Math.max(0, config.pricePerSession)
  const extPrice = Math.max(0, config.extensionPricePerSession)
  const totalPrice = isExtended ? basePrice + extPrice : basePrice
  const counselorEarning = Math.round((totalPrice * config.counselorSharePercentage) / 100)
  const platformFee = Math.max(0, totalPrice - counselorEarning)

  return {
    sessionDurationMinutes: isExtended
      ? config.sessionDurationMinutes * 2
      : config.sessionDurationMinutes,
    totalPrice,
    counselorEarning,
    platformFee,
    extensionPrice: extPrice,
  }
}

export function mapBackendAdminUserToDomain(
  dto: BackendAdminUserDto,
  existing?: GeneralAppUser,
): GeneralAppUser {
  return {
    id: dto.id,
    userCode: dto.user_code,
    displayName: dto.display_name,
    email: dto.email,
    city: existing?.city ?? '-',
    occupation: existing?.occupation ?? 'Pengguna EVA Mobile',
    joinedAt: dto.created_at.slice(0, 10),
    lastActiveAt: existing?.lastActiveAt ?? dto.created_at.slice(0, 16).replace('T', ' '),
    voiceSessionsCount: existing?.voiceSessionsCount ?? 0,
    questStreakDays: existing?.questStreakDays ?? 0,
    coinBalance: dto.coin_balance,
    totalVoiceMinutesUsed: existing?.totalVoiceMinutesUsed ?? 0,
    lastDassSeverity: existing?.lastDassSeverity ?? 'Normal',
    crisisProtocolTriggered: existing?.crisisProtocolTriggered ?? false,
    accountStatus: dto.is_active ? (existing?.accountStatus ?? 'active') : 'suspended',
  }
}

export function mapBackendCoinTransactionToDomain(
  dto: BackendCoinTransactionDto,
): CoinTopupTransaction {
  return {
    id: dto.id,
    invoiceCode: dto.invoice_code,
    userId: dto.user_id,
    userCode: dto.user_code,
    userDisplayName: dto.user_display_name,
    packageId: dto.transaction_type === 'grant_admin' ? 'admin-grant' : 'admin-topup',
    packageName: dto.package_name,
    coinsGranted: dto.coins_delta,
    amountIdr: dto.amount_idr,
    paymentMethod: dto.payment_method as CoinPaymentMethod,
    status: (dto.status as CoinTransactionStatus) || 'completed',
    createdAt: dto.created_at.slice(0, 16).replace('T', ' '),
    completedAt: dto.completed_at ? dto.completed_at.slice(0, 16).replace('T', ' ') : undefined,
    adminNotes: dto.admin_notes ?? undefined,
  }
}

export function mapBackendCoinPackageToDomain(dto: BackendCoinPackageDto): CoinPackage {
  return {
    id: dto.id,
    code: dto.code,
    name: dto.name,
    coins: dto.coins,
    bonusCoins: dto.bonus_coins,
    priceIdr: dto.price_idr,
    description: dto.description,
    isPopular: dto.is_popular,
    isActive: dto.is_active,
  }
}

export function mapBackendCoinEconomyToDomain(
  dto: BackendCoinEconomyConfigDto,
): CoinEconomyConfig {
  return {
    basePricePerCoinIdr: dto.base_price_per_coin_idr,
    freeTrialCoinsNewUser: dto.free_trial_coins_new_user,
    updatedAt: dto.updated_at.slice(0, 10),
  }
}

export function mapBackendSessionStatus(
  rawStatus: string,
  isExtended: boolean,
): ConsultationSessionStatus {
  const normalized = rawStatus.trim().toLowerCase()
  if (normalized === 'live') {
    return isExtended ? 'extended' : 'in_progress'
  }
  if (
    normalized === 'scheduled' ||
    normalized === 'waiting' ||
    normalized === 'in_progress' ||
    normalized === 'completed' ||
    normalized === 'extended' ||
    normalized === 'cancelled' ||
    normalized === 'expired'
  ) {
    return normalized
  }
  return 'scheduled'
}

export function mapBackendAdminSessionToDomain(
  dto: BackendAdminSessionDto,
): ConsultationSessionMonitoring {
  return {
    id: dto.id,
    sessionCode: dto.session_code,
    patientCode: dto.patient_code,
    patientDisplayName: dto.patient_display_name,
    counselorId: dto.counselor_id,
    counselorName: dto.counselor_name,
    counselorTitle: dto.counselor_title,
    scheduledStartTime: dto.scheduled_start_time,
    scheduledEndTime: dto.scheduled_end_time,
    durationMinutes: dto.duration_minutes,
    isExtended: dto.is_extended,
    status: mapBackendSessionStatus(dto.status, dto.is_extended),
    totalPriceCoins: dto.total_price_coins,
    counselorEarningCoins: dto.counselor_earning_coins,
    platformFeeCoins: dto.platform_fee_coins,
    clinicalSummary: dto.clinical_summary ?? undefined,
  }
}

export function mapBackendCrisisConfigToDomain(dto: BackendCrisisConfigDto): CrisisConfig {
  return {
    hotlineNumber: dto.hotline_number,
    hotlineLabel: dto.hotline_label,
    extremeDepressionThreshold: dto.extreme_depression_threshold,
    extremeAnxietyThreshold: dto.extreme_anxiety_threshold,
    autoSafetyNetModal: dto.auto_safety_net_modal,
    allowDirectIndependentReferral: dto.allow_direct_independent_referral,
    updatedAt: dto.updated_at.slice(0, 10),
  }
}

export function mapBackendFaqToDomain(dto: BackendFaqEntryDto): FaqEntry {
  return {
    id: dto.id,
    category: dto.category,
    question: dto.question,
    answer: dto.answer,
    isPublished: dto.is_published,
    sortOrder: dto.sort_order,
  }
}

export function mapBackendCertificateTemplateToDomain(
  dto: BackendCertificateTemplateDto,
): CertificateTemplate {
  const trigger: CertificateTriggerType =
    dto.trigger_type === 'rating_milestone' || dto.trigger_type === 'manual'
      ? dto.trigger_type
      : 'sessions_milestone'
  return {
    id: dto.id,
    code: dto.code,
    title: dto.title,
    subtitle: dto.subtitle,
    categoryCode: dto.category_code,
    categoryLabel: dto.category_label,
    milestoneCriteria: dto.milestone_criteria,
    description: dto.description,
    badgeColor: dto.badge_color,
    triggerType: trigger,
    minCompletedSessions: dto.min_completed_sessions,
    minAverageRating: dto.min_average_rating ?? null,
    autoIssueEnabled: dto.auto_issue_enabled,
    isActive: dto.is_active,
    svgBodyTemplate: dto.svg_body_template ?? null,
    updatedAt: dto.updated_at.slice(0, 10),
  }
}

export function mapBackendCertificateToDomain(
  dto: BackendPsychologistCertificateDto,
): IssuedPsychologistCertificate {
  return {
    id: dto.id,
    certificateNumber: dto.certificate_number,
    sequenceNumber: dto.sequence_number,
    issueYear: dto.issue_year,
    categoryCode: dto.category_code,
    counselorId: dto.counselor_id,
    templateId: dto.template_id ?? null,
    title: dto.title,
    subtitle: dto.subtitle,
    recipientName: dto.recipient_name,
    strNumber: dto.str_number,
    milestoneCriteria: dto.milestone_criteria,
    categoryLabel: dto.category_label,
    description: dto.description,
    badgeColor: dto.badge_color,
    triggerSource: dto.trigger_source,
    status: dto.status === 'revoked' ? 'revoked' : 'active',
    issueDateLabel: dto.issue_date_label,
    issuedAt: dto.issued_at,
    revokedAt: dto.revoked_at ?? null,
    revocationReason: dto.revocation_reason ?? null,
  }
}

export function mapBackendCounselorEligibilityToDomain(
  dto: BackendCounselorCertificateEligibilityDto,
): CounselorCertificateEligibility {
  return {
    counselorId: dto.counselor_id,
    fullName: dto.full_name,
    strNumber: dto.str_number,
    verificationStatus: dto.verification_status,
    completedSessionsCount: dto.completed_sessions_count,
    averageRating: dto.average_rating ?? null,
    activeCertificatesCount: dto.active_certificates_count,
  }
}

export function mapBackendEvaluationSummaryToDomain(
  dto: BackendCertificateEvaluationSummaryDto,
): CertificateEvaluationSummary {
  return {
    evaluatedCounselors: dto.evaluated_counselors,
    newlyIssuedCount: dto.newly_issued_count,
    issuedCertificates: dto.issued_certificates.map(mapBackendCertificateToDomain),
  }
}

export function mapBackendPsychologistLevelToDomain(
  dto: BackendPsychologistLevelDto,
): PsychologistLevelConfig {
  return {
    id: dto.id,
    levelTier: dto.level_tier,
    name: dto.name,
    badgeIcon: dto.badge_icon || 'award',
    minCompletedSessions: dto.min_completed_sessions,
    minAverageRating: dto.min_average_rating,
    minConsultationHours: dto.min_consultation_hours,
    minReviewCount: dto.min_review_count,
    defaultSessionPrice: dto.default_session_price,
    platformFeePercentage: dto.platform_fee_percentage,
    allowCustomPrice: dto.allow_custom_price,
    minCustomPrice: dto.min_custom_price ?? null,
    maxCustomPrice: dto.max_custom_price ?? null,
    isActive: dto.is_active,
    updatedAt: dto.updated_at.slice(0, 10),
  }
}

export function mapBackendLevelEvaluationToDomain(
  dto: BackendLevelEvaluationBatchDto,
): LevelEvaluationBatchSummary {
  return {
    evaluatedCounselors: dto.evaluated_counselors,
    upgradedCount: dto.upgraded_count,
    message: dto.message,
  }
}

export { mapBackendAdminBoothFeedbackListToDomain } from './boothFeedbackMappers'
