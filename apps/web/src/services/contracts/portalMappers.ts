import { buildPsychologistCertificates } from '@/data/mock/psychologists.mock'
import type {
  BackendAdminUserDto,
  BackendCoinEconomyConfigDto,
  BackendCoinPackageDto,
  BackendCoinTransactionDto,
  BackendPricingConfigResponseDto,
  BackendPsychologistProfileResponseDto,
  RegisterPsychologistRequestDto,
} from '@/types/api/contracts'
import type {
  CoinEconomyConfig,
  CoinPackage,
  CoinPaymentMethod,
  CoinTopupTransaction,
  CoinTransactionStatus,
  GeneralAppUser,
  PlatformPricingConfig,
  PricingCalculation,
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
