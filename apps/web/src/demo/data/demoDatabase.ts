import {
  INITIAL_COPING_QUESTS,
  INITIAL_CRISIS_CONFIG,
  INITIAL_FAQS,
  INITIAL_GENERAL_USERS,
  INITIAL_REFERRAL_LIST,
  INITIAL_WAITLIST,
} from './initialEcosystem'
import { INITIAL_PARTNERS } from './initialPartners'
import { INITIAL_PSYCHOLOGISTS } from './initialPsychologists'
import type { PortalDatabase } from '@/types/portal'

export {
  INITIAL_COPING_QUESTS,
  INITIAL_CRISIS_CONFIG,
  INITIAL_FAQS,
  INITIAL_GENERAL_USERS,
  INITIAL_PARTNERS,
  INITIAL_PSYCHOLOGISTS,
  INITIAL_REFERRAL_LIST,
  INITIAL_WAITLIST,
}

export const INITIAL_DEMO_DB: PortalDatabase = {
  partners: INITIAL_PARTNERS,
  psychologists: INITIAL_PSYCHOLOGISTS,
  referrals: INITIAL_REFERRAL_LIST,
  generalUsers: INITIAL_GENERAL_USERS,
  copingQuests: INITIAL_COPING_QUESTS,
  crisisConfig: INITIAL_CRISIS_CONFIG,
  waitlistEntries: INITIAL_WAITLIST,
  faqs: INITIAL_FAQS,
}

