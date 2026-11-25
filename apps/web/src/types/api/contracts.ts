import type {
  AppUserStatus,
  CertificateTriggerType,
  CoinEconomyConfig,
  CoinPackage,
  CoinPaymentMethod,
  CoinTopupTransaction,
  CoinTransactionStatus,
  CopingQuest,
  CrisisConfig,
  FaqEntry,
  GeneralAppUser,
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
  email?: string | null
  full_name: string
  title_degree: string
  education?: string | null
  str_number: string
  str_doc_url?: string | null
  str_issuing_institution?: string | null
  str_expiry_date?: string | null
  str_verified?: boolean
  sip_number?: string | null
  sip_doc_url?: string | null
  sip_issuing_institution?: string | null
  sip_expiry_date?: string | null
  sip_verified?: boolean
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

export type UpdateCrisisConfigRequestDto = Partial<Omit<CrisisConfig, 'updatedAt'>>

export interface CreateWaitlistRequestDto {
  contact: string
  topic?: string | null
}

export interface UpdateWaitlistStatusRequestDto {
  id: string
  status: WaitlistEntry['status']
}

export interface CreateFaqRequestDto {
  category: string
  question: string
  answer: string
  sortOrder?: number
  isPublished?: boolean
}

export interface UpdateFaqRequestDto {
  category: string
  question: string
  answer: string
  sortOrder?: number
  isPublished?: boolean
}

export interface PublicFaqsResultDto {
  items: FaqEntry[]
  fromServer: boolean
}

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

export interface AdminCoinTopupRequestDto {
  userId: string
  coinsGranted: number
  amountIdr: number
  paymentMethod: CoinPaymentMethod
  packageName: string
  adminNotes?: string
}

export interface AdminCoinTopupResultDto {
  user: GeneralAppUser
  transaction: CoinTopupTransaction
}

export interface BackendAdminUserDto {
  id: string
  user_code: string
  display_name: string
  email: string
  coin_balance: number
  is_active: boolean
  created_at: string
}

export interface BackendCoinTransactionDto {
  id: string
  invoice_code: string
  user_id: string
  user_code: string
  user_display_name: string
  package_name: string
  transaction_type: string
  coins_delta: number
  balance_after: number
  amount_idr: number
  payment_method: string
  status: string
  admin_notes?: string | null
  created_at: string
  completed_at?: string | null
}

export interface BackendAdminCoinTopupResponseDto {
  user: BackendAdminUserDto
  transaction: BackendCoinTransactionDto
}

export interface BackendCoinPackageDto {
  id: string
  code: string
  name: string
  coins: number
  bonus_coins: number
  price_idr: number
  description: string
  is_popular: boolean
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface BackendCoinEconomyConfigDto {
  base_price_per_coin_idr: number
  free_trial_coins_new_user: number
  updated_at: string
}

export interface BackendCrisisConfigDto {
  hotline_number: string
  hotline_label: string
  extreme_depression_threshold: number
  extreme_anxiety_threshold: number
  auto_safety_net_modal: boolean
  allow_direct_independent_referral: boolean
  updated_at: string
}

export interface BackendFaqEntryDto {
  id: string
  category: string
  question: string
  answer: string
  is_published: boolean
  sort_order: number
  created_at: string
  updated_at: string
}

export interface UpsertCertificateTemplateRequestDto {
  id?: string
  code: string
  title: string
  subtitle: string
  categoryCode: string
  categoryLabel: string
  milestoneCriteria: string
  description: string
  badgeColor: string
  triggerType: CertificateTriggerType
  minCompletedSessions: number
  minAverageRating?: number | null
  autoIssueEnabled: boolean
  isActive: boolean
  svgBodyTemplate?: string | null
}

export interface IssueCertificateRequestDto {
  counselorId: string
  templateId?: string | null
  customTitle?: string
  customSubtitle?: string
  customCategoryCode?: string
  customCategoryLabel?: string
  customMilestoneCriteria?: string
  customDescription?: string
  customBadgeColor?: string
}

export interface BackendCertificateTemplateDto {
  id: string
  code: string
  title: string
  subtitle: string
  category_code: string
  category_label: string
  milestone_criteria: string
  description: string
  badge_color: string
  trigger_type: string
  min_completed_sessions: number
  min_average_rating?: number | null
  auto_issue_enabled: boolean
  is_active: boolean
  svg_body_template?: string | null
  created_at: string
  updated_at: string
}

export interface BackendPsychologistCertificateDto {
  id: string
  certificate_number: string
  sequence_number: number
  issue_year: number
  category_code: string
  counselor_id: string
  template_id?: string | null
  title: string
  subtitle: string
  recipient_name: string
  str_number: string
  milestone_criteria: string
  category_label: string
  description: string
  badge_color: string
  trigger_source: string
  status: string
  issue_date_label: string
  issued_at: string
  revoked_at?: string | null
  revocation_reason?: string | null
}

export interface BackendCounselorCertificateEligibilityDto {
  counselor_id: string
  full_name: string
  str_number: string
  verification_status: string
  completed_sessions_count: number
  average_rating?: number | null
  active_certificates_count: number
}

export interface BackendCertificateEvaluationSummaryDto {
  evaluated_counselors: number
  newly_issued_count: number
  issued_certificates: BackendPsychologistCertificateDto[]
}

export interface BackendAdminSessionDto {
  id: string
  session_code: string
  patient_code: string
  patient_display_name: string
  counselor_id: string
  counselor_name: string
  counselor_title: string
  scheduled_start_time: string
  scheduled_end_time: string
  duration_minutes: number
  is_extended: boolean
  status: string
  total_price_coins: number
  counselor_earning_coins: number
  platform_fee_coins: number
  clinical_summary?: string | null
}

export interface BackendAuthTokenResponseDto {
  access_token: string
  refresh_token: string
  token_type: string
  user: {
    id: string
    name: string
    email: string
    is_admin?: boolean
    coin_balance?: number
  }
}

export interface UpsertPsychologistLevelRequestDto {
  levelTier: number
  name: string
  badgeIcon: string
  minCompletedSessions: number
  minAverageRating: number
  minConsultationHours: number
  minReviewCount: number
  defaultSessionPrice: number
  platformFeePercentage: number
  allowCustomPrice: boolean
  minCustomPrice?: number | null
  maxCustomPrice?: number | null
  isActive: boolean
}

export interface BackendPsychologistLevelDto {
  id: string
  level_tier: number
  name: string
  badge_icon: string
  min_completed_sessions: number
  min_average_rating: number
  min_consultation_hours: number
  min_review_count: number
  default_session_price: number
  platform_fee_percentage: number
  allow_custom_price: boolean
  min_custom_price?: number | null
  max_custom_price?: number | null
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface BackendLevelEvaluationBatchDto {
  evaluated_counselors: number
  upgraded_count: number
  message: string
}

export interface BackendBoothFeedbackPhotoDto {
  id: string
  mime_type: string
  file_size_bytes: number
  sort_order: number
  created_at: string
}

export interface BackendBoothFeedbackItemDto {
  id: string
  rating: number
  message: string
  visitor_name?: string | null
  visitor_contact?: string | null
  event_label: string
  photos: BackendBoothFeedbackPhotoDto[]
  created_at: string
}

export interface BackendBoothFeedbackSummaryDto {
  total_count: number
  average_rating: number
  rating_counts: Record<string, number>
}

export interface BackendAdminBoothFeedbackListDto {
  summary: BackendBoothFeedbackSummaryDto
  items: BackendBoothFeedbackItemDto[]
  total: number
  page: number
  page_size: number
}

export interface BackendPublicBoothFeedbackCreateDto {
  id: string
  rating: number
  photo_count: number
  created_at: string
  message: string
}

export type PortalDatabaseSnapshot = PortalDatabase
