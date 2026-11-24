import { MOCK_ADMIN_ACCOUNT } from './auth.mock'
import {
  INITIAL_CERTIFICATE_TEMPLATES,
  INITIAL_ISSUED_CERTIFICATES,
} from './certificates.mock'
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
  INITIAL_CONSULTATION_SESSIONS,
  INITIAL_COPING_QUESTS,
  INITIAL_CRISIS_CONFIG,
  INITIAL_FAQS,
  INITIAL_GENERAL_USERS,
  INITIAL_PRICING_CONFIG,
  INITIAL_PRICING_HISTORY,
  INITIAL_WAITLIST,
} from './ecosystem.mock'
import {
  INITIAL_PSYCHOLOGISTS,
  buildPsychologistCertificates,
  buildSimulatedMobilePsychologist,
} from './psychologists.mock'
import type { PortalDatabase } from '@/types/domain/portal'

export {
  EMPTY_BASELINE_DASS,
  INITIAL_COIN_ECONOMY_CONFIG,
  INITIAL_COIN_PACKAGES,
  INITIAL_COIN_TRANSACTIONS,
  INITIAL_CONSULTATION_SESSIONS,
  INITIAL_COPING_QUESTS,
  INITIAL_CRISIS_CONFIG,
  INITIAL_FAQS,
  INITIAL_GENERAL_USERS,
  INITIAL_PRICING_CONFIG,
  INITIAL_PRICING_HISTORY,
  INITIAL_PSYCHOLOGISTS,
  INITIAL_WAITLIST,
  INITIAL_CERTIFICATE_TEMPLATES,
  INITIAL_ISSUED_CERTIFICATES,
  MOCK_ADMIN_ACCOUNT,
  MOCK_BASELINE_DASS,
  MOCK_BASELINE_USERS,
  buildMockHistorySeed,
  buildPsychologistCertificates,
  buildSimulatedMobilePsychologist,
  generateCertificateSvgUri,
  getEmptyDashboardAnalyticsBaseline,
  getMockDashboardAnalyticsBaseline,
}

export const INITIAL_MOCK_DB: PortalDatabase = {
  psychologists: INITIAL_PSYCHOLOGISTS,
  consultationSessions: INITIAL_CONSULTATION_SESSIONS,
  pricingConfig: INITIAL_PRICING_CONFIG,
  pricingHistory: INITIAL_PRICING_HISTORY,
  generalUsers: INITIAL_GENERAL_USERS,
  copingQuests: INITIAL_COPING_QUESTS,
  crisisConfig: INITIAL_CRISIS_CONFIG,
  waitlistEntries: INITIAL_WAITLIST,
  faqs: INITIAL_FAQS,
  coinEconomyConfig: INITIAL_COIN_ECONOMY_CONFIG,
  coinPackages: INITIAL_COIN_PACKAGES,
  coinTransactions: INITIAL_COIN_TRANSACTIONS,
  certificateTemplates: INITIAL_CERTIFICATE_TEMPLATES,
  issuedCertificates: INITIAL_ISSUED_CERTIFICATES,
  eligibleCounselorSummaries: [],
}
