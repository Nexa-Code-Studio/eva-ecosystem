export type FacilityType =
  | 'Rumah Sakit'
  | 'Klinik Utama'
  | 'Klinik Pratama'
  | 'Biro Psikologi'

export type PartnerStatus = 'pending' | 'approved' | 'rejected' | 'suspended'

export interface PartnerAccount {
  id: string
  // Required facility fields
  facilityName: string
  facilityType: FacilityType
  licenseNumber: string
  city: string
  address: string
  // Required PIC fields
  picName: string
  picRole: string
  phone: string
  // Required auth credentials
  email: string
  password: string
  // Optional fields
  website?: string
  operatingHours?: string
  estimatedPsychologists?: number
  bpjsSupported?: boolean
  notes?: string
  // Verification & operational metadata
  status: PartnerStatus
  submittedAt: string
  reviewedAt?: string
  rejectionReason?: string
  isResubmitted?: boolean
  resubmittedAt?: string
  acceptingReferrals: boolean
}

export type PsychologistStatus = 'active' | 'on_leave' | 'inactive'
export type PsychologistPracticeType = 'faskes' | 'mandiri'
export type VerificationStatus = 'pending' | 'approved' | 'rejected' | 'suspended'

export type PsychologistRole =
  | 'professional_mitra'
  | 'relawan_profesional'
  | 'relawan_biasa'

export interface UpgradeRequest {
  targetRole: 'relawan_profesional'
  requestedAt: string
  notes?: string
  documents?: PsychologistCertificate[]
}

export interface PsychologistCertificate {
  id: string
  docType:
    | 'SIPP'
    | 'STR HIMPSI'
    | 'Ijazah Profesi'
    | 'Sertifikat Klinis'
    | 'Sertifikat Pelatihan'
    | 'Bukti Kinerja Relawan'
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
  partnerId: string | null
  practiceType?: PsychologistPracticeType
  verificationStatus?: VerificationStatus
  role?: PsychologistRole
  upgradeRequest?: UpgradeRequest | null
  // Required fields
  fullName: string
  sippNumber: string
  strNumber?: string
  specializations: string[]
  practiceSchedule: string
  status: PsychologistStatus
  // Optional fields & mobile app registration details
  weeklyQuota?: number
  yearsExperience?: number
  education?: string
  city?: string
  email?: string
  phone?: string
  submittedAt?: string
  reviewedAt?: string
  rejectionReason?: string
  documents?: PsychologistCertificate[]
}

export type ReferralStatus = 'unassigned' | 'scheduled' | 'completed'
export type DassSeverity = 'Moderate' | 'Severe' | 'Extreme'

export interface PatientReferral {
  id: string
  partnerId: string | null
  patientCode: string
  age: number
  gender: 'Perempuan' | 'Laki-laki'
  submittedAt: string
  dass21: {
    depression: number
    anxiety: number
    stress: number
    severity: DassSeverity
  }
  clinicalSummary: string
  preferredSchedule: string
  assignedPsychologistId: string | null
  status: ReferralStatus
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
  role: 'admin' | 'partner'
  email: string
  partnerId?: string
  loginAt: string
}

export interface PortalDatabase {
  partners: PartnerAccount[]
  psychologists: Psychologist[]
  referrals: PatientReferral[]
  generalUsers: GeneralAppUser[]
  copingQuests: CopingQuest[]
  crisisConfig: CrisisConfig
  waitlistEntries: WaitlistEntry[]
  faqs: FaqEntry[]
  coinEconomyConfig: CoinEconomyConfig
  coinPackages: CoinPackage[]
  coinTransactions: CoinTopupTransaction[]
}

