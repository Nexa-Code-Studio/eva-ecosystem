export type PsychologistStatus = 'active' | 'on_leave' | 'inactive'
export type VerificationStatus =
  | 'pending'
  | 'verified'
  | 'need_revision'
  | 'rejected'
  | 'suspended'

export type DassSeverity = 'Moderate' | 'Severe' | 'Extreme'

export interface PsychologistCertificate {
  id: string
  docType: 'STR HIMPSI' | 'SIPP' | 'Ijazah Profesi' | 'Sertifikat Klinis'
  title: string
  documentNumber: string
  issuedBy: string
  issuedYear: string
  validUntil: string
  fileName: string
  fileSize: string
  verified: boolean
  imageUrl?: string
}

export interface Psychologist {
  id: string
  userId?: string
  fullName: string
  titleDegree: string
  email: string
  password?: string
  phone?: string
  city?: string
  education?: string
  strNumber: string
  sipNumber?: string | null
  association: string
  specializations: string[]
  yearsOfExperience: number
  bio?: string | null
  profilePhotoUrl?: string | null
  certificateDocUrl?: string | null
  verificationStatus: VerificationStatus
  verificationNotes?: string | null
  verifiedAt?: string | null
  isOnline: boolean
  bufferTimeMinutes: number
  practiceSchedule: string
  status: PsychologistStatus
  submittedAt: string
  reviewedAt?: string
  documents?: PsychologistCertificate[]
}

export interface PlatformPricingConfig {
  id: string
  sessionDurationMinutes: number
  pricePerSession: number
  counselorSharePercentage: number
  platformFeePercentage: number
  extensionPricePerSession: number
  status: 'active' | 'draft' | 'archived'
  notes?: string | null
  effectiveFrom: string
  effectiveUntil?: string | null
  createdAt: string
}

export interface PricingCalculation {
  sessionDurationMinutes: number
  totalPrice: number
  counselorEarning: number
  platformFee: number
  extensionPrice: number
}

export type ConsultationSessionStatus =
  | 'scheduled'
  | 'waiting'
  | 'in_progress'
  | 'completed'
  | 'extended'
  | 'cancelled'

export interface ConsultationSessionMonitoring {
  id: string
  sessionCode: string
  patientCode: string
  patientDisplayName: string
  counselorId: string
  counselorName: string
  counselorTitle: string
  scheduledStartTime: string
  scheduledEndTime: string
  durationMinutes: 30 | 60
  isExtended: boolean
  status: ConsultationSessionStatus
  totalPriceCoins: number
  counselorEarningCoins: number
  platformFeeCoins: number
  dassSeverity?: DassSeverity
  clinicalSummary?: string
}

export type AppUserStatus = 'active' | 'flagged_crisis' | 'suspended'

export interface GeneralAppUser {
  id: string
  userCode: string
  displayName: string
  email: string
  city: string
  occupation: string
  joinedAt: string
  lastActiveAt: string
  voiceSessionsCount: number
  questStreakDays: number
  coinBalance: number
  totalVoiceMinutesUsed: number
  lastDassSeverity: 'Normal' | 'Mild' | 'Moderate' | 'Severe' | 'Extreme'
  crisisProtocolTriggered: boolean
  accountStatus: AppUserStatus
}

export type CoinPaymentMethod =
  | 'QRIS'
  | 'GoPay'
  | 'OVO'
  | 'ShopeePay'
  | 'VA BCA'
  | 'VA Mandiri'

export type CoinTransactionStatus = 'completed' | 'pending' | 'failed' | 'refunded'

export interface CoinPackage {
  id: string
  code: string
  name: string
  coins: number
  bonusCoins: number
  priceIdr: number
  description: string
  isPopular?: boolean
  isActive: boolean
}

export interface CoinEconomyConfig {
  basePricePerCoinIdr: number
  freeTrialCoinsNewUser: number
  updatedAt: string
}

export interface CoinTopupTransaction {
  id: string
  invoiceCode: string
  userId: string
  userCode: string
  userDisplayName: string
  packageId: string
  packageName: string
  coinsGranted: number
  amountIdr: number
  paymentMethod: CoinPaymentMethod
  status: CoinTransactionStatus
  createdAt: string
  completedAt?: string
  adminNotes?: string
}

export interface CopingQuest {
  id: string
  code: string
  title: string
  category: 'Pernapasan' | 'Grounding' | 'Refleksi Kognitif' | 'Regulasi Tidur'
  durationMinutes: number
  targetEmotion: string
  completionCount: number
  isActive: boolean
}

export interface CrisisConfig {
  hotlineNumber: string
  hotlineLabel: string
  extremeDepressionThreshold: number
  extremeAnxietyThreshold: number
  autoSafetyNetModal: boolean
  allowDirectIndependentReferral: boolean
  updatedAt: string
}

export interface WaitlistEntry {
  id: string
  contact: string
  channel: 'Email' | 'WhatsApp'
  topic: string
  submittedAt: string
  status: 'new' | 'invited' | 'archived'
}

export interface FaqEntry {
  id: string
  category: string
  question: string
  answer: string
  isPublished: boolean
}

export interface PortalSession {
  role: 'admin'
  email: string
  accessToken?: string
  loginAt: string
}

export interface PortalDatabase {
  psychologists: Psychologist[]
  consultationSessions: ConsultationSessionMonitoring[]
  pricingConfig: PlatformPricingConfig
  pricingHistory: PlatformPricingConfig[]
  generalUsers: GeneralAppUser[]
  copingQuests: CopingQuest[]
  crisisConfig: CrisisConfig
  waitlistEntries: WaitlistEntry[]
  faqs: FaqEntry[]
  coinEconomyConfig: CoinEconomyConfig
  coinPackages: CoinPackage[]
  coinTransactions: CoinTopupTransaction[]
}
