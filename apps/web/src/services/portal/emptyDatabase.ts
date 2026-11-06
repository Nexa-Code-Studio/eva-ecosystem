import type { CoinEconomyConfig, CrisisConfig, PortalDatabase } from '@/types/portal'

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

export const EMPTY_PORTAL_DATABASE: PortalDatabase = {
  partners: [],
  psychologists: [],
  referrals: [],
  generalUsers: [],
  copingQuests: [],
  crisisConfig: DEFAULT_CRISIS_CONFIG,
  waitlistEntries: [],
  faqs: [],
  coinEconomyConfig: DEFAULT_COIN_ECONOMY_CONFIG,
  coinPackages: [],
  coinTransactions: [],
}
