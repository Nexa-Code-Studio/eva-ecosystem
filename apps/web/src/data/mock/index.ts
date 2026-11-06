import { MOCK_ADMIN_ACCOUNT } from './auth.mock'
import { generateCertificateSvgUri } from './certificateSvgTemplates'
import {
  INITIAL_COIN_ECONOMY_CONFIG,
  INITIAL_COIN_PACKAGES,
  INITIAL_COIN_TRANSACTIONS,
} from './coins.mock'
import {
  EMPTY_BASELINE_DASS,
  MOCK_BASELINE_DASS,
  MOCK_BASELINE_USERS,
  buildMockHistorySeed,
  getEmptyDashboardAnalyticsBaseline,
  getMockDashboardAnalyticsBaseline,
} from './dashboardMetrics.mock'
import {
  INITIAL_COPING_QUESTS,
  INITIAL_CRISIS_CONFIG,
  INITIAL_FAQS,
  INITIAL_GENERAL_USERS,
  INITIAL_REFERRAL_LIST,
  INITIAL_WAITLIST,
} from './ecosystem.mock'
import { INITIAL_PARTNERS } from './partners.mock'
import {
  INITIAL_PSYCHOLOGISTS,
  buildSimulatedMobilePsychologist,
  buildSimulatedUpgradeDocuments,
} from './psychologists.mock'
import type { PortalDatabase } from '@/types/domain/portal'

export {
  EMPTY_BASELINE_DASS,
  INITIAL_COIN_ECONOMY_CONFIG,
  INITIAL_COIN_PACKAGES,
  INITIAL_COIN_TRANSACTIONS,
  INITIAL_COPING_QUESTS,
  INITIAL_CRISIS_CONFIG,
  INITIAL_FAQS,
  INITIAL_GENERAL_USERS,
  INITIAL_PARTNERS,
  INITIAL_PSYCHOLOGISTS,
  INITIAL_REFERRAL_LIST,
  INITIAL_WAITLIST,
  MOCK_ADMIN_ACCOUNT,
  MOCK_BASELINE_DASS,
  MOCK_BASELINE_USERS,
  buildMockHistorySeed,
  buildSimulatedMobilePsychologist,
  buildSimulatedUpgradeDocuments,
  generateCertificateSvgUri,
  getEmptyDashboardAnalyticsBaseline,
  getMockDashboardAnalyticsBaseline,
}

export const INITIAL_MOCK_DB: PortalDatabase = {
  partners: INITIAL_PARTNERS,
  psychologists: INITIAL_PSYCHOLOGISTS,
  referrals: INITIAL_REFERRAL_LIST,
  generalUsers: INITIAL_GENERAL_USERS,
  copingQuests: INITIAL_COPING_QUESTS,
  crisisConfig: INITIAL_CRISIS_CONFIG,
  waitlistEntries: INITIAL_WAITLIST,
  faqs: INITIAL_FAQS,
  coinEconomyConfig: INITIAL_COIN_ECONOMY_CONFIG,
  coinPackages: INITIAL_COIN_PACKAGES,
  coinTransactions: INITIAL_COIN_TRANSACTIONS,
}
