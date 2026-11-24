import type {
  CoinEconomyConfig,
  CrisisConfig,
  PlatformPricingConfig,
  PortalDatabase,
} from '@/types/portal'

export const DEFAULT_CRISIS_CONFIG: CrisisConfig = {
  hotlineNumber: '119 EXT 8',
  hotlineLabel: 'Layanan Darurat Kemenkes RI',
  extremeDepressionThreshold: 28,
  extremeAnxietyThreshold: 20,
  autoSafetyNetModal: true,
  allowDirectIndependentReferral: true,
  updatedAt: '2026-10-29',
}

export const DEFAULT_COIN_ECONOMY_CONFIG: CoinEconomyConfig = {
  basePricePerCoinIdr: 1000,
  freeTrialCoinsNewUser: 10,
  updatedAt: '2026-11-01',
}

export const DEFAULT_PLATFORM_PRICING_CONFIG: PlatformPricingConfig = {
  id: 'pricing-default',
  sessionDurationMinutes: 30,
  pricePerSession: 150,
  counselorSharePercentage: 80,
  platformFeePercentage: 20,
  extensionPricePerSession: 150,
  status: 'active',
  notes: 'Konfigurasi default sesi telekonsultasi 30 menit',
  effectiveFrom: '2026-11-01T00:00:00Z',
  effectiveUntil: null,
  createdAt: '2026-11-01T00:00:00Z',
}

export const EMPTY_PORTAL_DATABASE: PortalDatabase = {
  psychologists: [],
  consultationSessions: [],
  pricingConfig: DEFAULT_PLATFORM_PRICING_CONFIG,
  pricingHistory: [DEFAULT_PLATFORM_PRICING_CONFIG],
  generalUsers: [],
  copingQuests: [],
  crisisConfig: DEFAULT_CRISIS_CONFIG,
  waitlistEntries: [],
  faqs: [],
  coinEconomyConfig: DEFAULT_COIN_ECONOMY_CONFIG,
  coinPackages: [],
  coinTransactions: [],
  certificateTemplates: [],
  issuedCertificates: [],
  eligibleCounselorSummaries: [],
  psychologistLevels: [],
}
