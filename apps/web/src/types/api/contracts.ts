import type {
  AppUserStatus,
  CoinEconomyConfig,
  CoinPackage,
  CoinTransactionStatus,
  CopingQuest,
  CrisisConfig,
  FaqEntry,
  PartnerAccount,
  PortalDatabase,
  Psychologist,
  PsychologistCertificate,
  ReferralStatus,
  WaitlistEntry,
} from '@/types/domain/portal'

export interface LoginRequestDto {
  email: string
  password: string
}

export type AuthResult =
  | { ok: true; role: 'admin' }
  | { ok: true; role: 'partner'; partner: PartnerAccount }
  | { ok: false; error: string }

export type NewPartnerApplicationInput = Omit<
  PartnerAccount,
  | 'id'
  | 'status'
  | 'submittedAt'
  | 'reviewedAt'
  | 'rejectionReason'
  | 'isResubmitted'
  | 'resubmittedAt'
  | 'acceptingReferrals'
>

export type SubmitPartnerApplicationResultDto =
  | { ok: true; partner: PartnerAccount }
  | { ok: false; error: string }

export interface UpdatePartnerVerificationRequestDto {
  partnerId: string
  decision: 'approved' | 'rejected' | 'suspended'
  rejectionReason?: string
}

export type UpsertPsychologistRequestDto = Omit<Psychologist, 'id'> & { id?: string }

export interface UpdatePsychologistVerificationRequestDto {
  psychologistId: string
  decision: 'approved' | 'rejected' | 'suspended'
  rejectionReason?: string
}

export interface RequestPsychologistUpgradeDto {
  targetRole: 'relawan_profesional_non_mitra'
  notes?: string
  documents?: PsychologistCertificate[]
}

export interface SimulateMobilePsychologistInput {
  role?: 'relawan_biasa' | 'relawan_profesional_non_mitra'
  fullName: string
  sippNumber?: string
  strNumber?: string
  city: string
  education: string
  email: string
  phone: string
  practiceSchedule: string
  specializations: string[]
  sippValidUntil?: string
  sessionDurationMinutes?: number
  sessionFeeCoins?: number
}

export interface AssignReferralRequestDto {
  referralId: string
  psychologistId: string | null
  status: ReferralStatus
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

export interface AdjustUserCoinBalanceDto {
  userId: string
  deltaCoins: number
  reason: string
}

export interface UpdateCoinTransactionStatusDto {
  transactionId: string
  status: CoinTransactionStatus
  adminNotes?: string
}

export type UpsertCoinPackageDto = Omit<CoinPackage, 'id'> & { id?: string }

export type UpdateCoinEconomyConfigDto = Partial<
  Pick<CoinEconomyConfig, 'basePricePerCoinIdr' | 'freeTrialCoinsNewUser'>
>

export type PortalSnapshotDto = PortalDatabase

