import { buildPsychologistCertificates } from '@/data/mock/psychologists.mock'
import type {
  BackendPricingConfigResponseDto,
  BackendPsychologistProfileResponseDto,
  RegisterPsychologistRequestDto,
} from '@/types/api/contracts'
import type {
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
  return {
    id: dto.id,
    userId: dto.user_id,
    fullName: dto.full_name,
    titleDegree: dto.title_degree,
    email: existing?.email ?? `${dto.full_name.toLowerCase().replace(/[^a-z0-9]+/g, '.')}@eva.id`,
    phone: existing?.phone,
    city: existing?.city,
    education: existing?.education,
    strNumber: dto.str_number,
    sipNumber: dto.sip_number ?? null,
    association: dto.association,
    specializations: dto.specializations ?? [],
    yearsOfExperience: dto.years_of_experience,
    bio: dto.bio ?? null,
    profilePhotoUrl: dto.profile_photo_url ?? null,
    certificateDocUrl: dto.certificate_doc_url ?? null,
    verificationStatus,
    verificationNotes: dto.verification_notes ?? null,
    verifiedAt: dto.verified_at ?? null,
    isOnline: dto.is_online,
    bufferTimeMinutes: dto.buffer_time_minutes,
    practiceSchedule: existing?.practiceSchedule ?? 'Jadwal fleksibel (slot 30 menit online)',
    status: verificationStatus === 'verified' ? 'active' : 'inactive',
    submittedAt: dto.created_at.slice(0, 10),
    reviewedAt: dto.verified_at ? dto.verified_at.slice(0, 10) : existing?.reviewedAt,
    documents:
      existing?.documents && existing.documents.length > 0
        ? existing.documents
        : buildPsychologistCertificates({
            fullName: `${dto.full_name}, ${dto.title_degree}`,
            strNumber: dto.str_number,
            sipNumber: dto.sip_number,
            association: dto.association,
            city: existing?.city,
            education: existing?.education,
            verified: verificationStatus === 'verified',
          }),
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
    city: payload.city?.trim().toUpperCase(),
    education: payload.education?.trim(),
    verified: false,
  })

  return {
    id: `psy-mandiri-${Date.now()}`,
    fullName: payload.full_name.trim(),
    titleDegree: payload.title_degree.trim(),
    email: payload.email.trim(),
    password: payload.password,
    phone: payload.phone?.trim(),
    city: payload.city?.trim().toUpperCase() || 'INDONESIA',
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
    practiceSchedule: payload.practice_schedule?.trim() || 'Slot online 30 menit (Senin - Jumat)',
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
