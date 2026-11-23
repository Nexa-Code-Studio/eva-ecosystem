import type {
  AppUserStatus,
  CoinEconomyConfig,
  CoinPackage,
  CoinTransactionStatus,
  CopingQuest,
  CrisisConfig,
  FaqEntry,
  PortalDatabase,
  Psychologist,
  WaitlistEntry,
} from '@/types/domain/portal'

export interface LoginRequestDto {
  email: string
  password: string
}

export type AuthResult =
  | { ok: true; role: 'admin'; accessToken?: string }
  | { ok: false; error: string }

export interface RegisterPsychologistRequestDto {
  full_name: string
  title_degree: string
  email: string
  password: string
  str_number: string
  sip_number?: string | null
  association: string
  specializations: string[]
  years_of_experience: number
  bio?: string | null
  certificate_doc_url?: string | null
  phone?: string
  city?: string
  education?: string
  practice_schedule?: string
}

export type SubmitPsychologistApplicationResultDto =
  | { ok: true; psychologist: Psychologist }
  | { ok: false; error: string }

export interface VerifyPsychologistRequestDto {
  status: 'verified' | 'rejected'
  notes?: string | null
}

export interface UpsertPlatformPricingRequestDto {
  session_duration_minutes: number
  price_per_session: number
  counselor_share_percentage: number
  platform_fee_percentage: number
  extension_price_per_session: number
  notes?: string | null
}

export interface BackendPsychologistProfileResponseDto {
  id: string
  user_id: string
  full_name: string
  title_degree: string
  str_number: string
  sip_number?: string | null
  association: string
  specializations: string[]
  years_of_experience: number
  bio?: string | null
  profile_photo_url?: string | null
  certificate_doc_url?: string | null
  verification_status: string
  verification_notes?: string | null
  verified_at?: string | null
  is_online: boolean
  buffer_time_minutes: number
  created_at: string
}

export interface BackendPricingConfigResponseDto {
  id: string
  session_duration_minutes: number
  price_per_session: number
  counselor_share_percentage: number
  platform_fee_percentage: number
  extension_price_per_session: number
  status: 'active' | 'draft' | 'archived'
  notes?: string | null
  effective_from: string
  effective_until?: string | null
  created_at: string
}

export interface SimulateMobilePsychologistInput {
  fullName: string
  titleDegree?: string
  documentType?: 'both' | 'str' | 'sip'
  strNumber?: string
  strIssuedBy?: string
  strValidUntil?: string
  sippNumber?: string
  sipIssuedBy?: string
  sipValidUntil?: string
  association?: string
  education: string
  email: string
  specializations: string[]
  yearsOfExperience?: number
}

export interface UpdateGeneralUserStatusRequestDto {
  userId: string
  accountStatus: AppUserStatus
}

export type CreateCopingQuestRequestDto = Omit<
  CopingQuest,
  'id' | 'completionCount' | 'isActive'
>

export type UpdateCrisisConfigRequestDto = Partial<CrisisConfig>

export interface CreateWaitlistRequestDto {
  contact: string
  topic?: string | null
}

export interface UpdateWaitlistStatusRequestDto {
  id: string
  status: WaitlistEntry['status']
}

export type CreateFaqRequestDto = Omit<FaqEntry, 'id' | 'isPublished'>

export interface AdjustUserCoinBalanceRequestDto {
  userId: string
  deltaCoins: number
  reason: string
}

export type UpsertCoinPackageRequestDto = Omit<CoinPackage, 'id'> & { id?: string }

export type UpdateCoinEconomyConfigRequestDto = Partial<
  Omit<CoinEconomyConfig, 'updatedAt'>
>

export interface ReviewCoinTransactionRequestDto {
  txId: string
  status: CoinTransactionStatus
  adminNotes?: string
}

export type PortalDatabaseSnapshot = PortalDatabase
