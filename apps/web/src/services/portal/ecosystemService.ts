import { loadPortalDb, savePortalDb } from './storage'
import type {
  AppUserStatus,
  CopingQuest,
  CrisisConfig,
  FaqEntry,
  ReferralStatus,
  WaitlistEntry,
} from '@/types/portal'

export function assignReferral(
  referralId: string,
  psychologistId: string | null,
  status: ReferralStatus,
) {
  const db = loadPortalDb()
  const idx = db.referrals.findIndex((r) => r.id === referralId)
  if (idx === -1) return

  const assignedPsy = psychologistId
    ? db.psychologists.find((p) => p.id === psychologistId)
    : null

  db.referrals[idx] = {
    ...db.referrals[idx],
    partnerId: assignedPsy ? assignedPsy.partnerId : db.referrals[idx].partnerId,
    assignedPsychologistId: psychologistId,
    status,
  }
  savePortalDb(db)
}

export function updateGeneralUserStatus(userId: string, accountStatus: AppUserStatus) {
  const db = loadPortalDb()
  const idx = db.generalUsers.findIndex((u) => u.id === userId)
  if (idx === -1) return
  db.generalUsers[idx] = { ...db.generalUsers[idx], accountStatus }
  savePortalDb(db)
}

export function addCopingQuest(
  input: Omit<CopingQuest, 'id' | 'completionCount' | 'isActive'>,
): CopingQuest {
  const db = loadPortalDb()
  const created: CopingQuest = {
    ...input,
    code: input.code.trim().toUpperCase(),
    id: `quest-${Date.now()}`,
    completionCount: 0,
    isActive: true,
  }
  db.copingQuests.unshift(created)
  savePortalDb(db)
  return created
}

export function toggleCopingQuest(id: string) {
  const db = loadPortalDb()
  const idx = db.copingQuests.findIndex((q) => q.id === id)
  if (idx === -1) return
  db.copingQuests[idx] = {
    ...db.copingQuests[idx],
    isActive: !db.copingQuests[idx].isActive,
  }
  savePortalDb(db)
}

export function deleteCopingQuest(id: string) {
  const db = loadPortalDb()
  db.copingQuests = db.copingQuests.filter((q) => q.id !== id)
  savePortalDb(db)
}

export function updateCrisisConfig(updates: Partial<CrisisConfig>) {
  const db = loadPortalDb()
  const today = new Date().toISOString().slice(0, 10)
  db.crisisConfig = {
    ...db.crisisConfig,
    ...updates,
    updatedAt: today,
  }
  savePortalDb(db)
}

export function addWaitlistEntry(contactInput: string, topicInput?: string | null): WaitlistEntry {
  const db = loadPortalDb()
  const contact = contactInput.trim()
  const isEmail = contact.includes('@')
  const today = new Date().toISOString().slice(0, 10)
  const created: WaitlistEntry = {
    id: `wl-${Date.now()}`,
    contact,
    channel: isEmail ? 'Email' : 'WhatsApp',
    topic: topicInput?.trim() || 'Early Access Pengguna Beta',
    submittedAt: today,
    status: 'new',
  }
  db.waitlistEntries.unshift(created)
  savePortalDb(db)
  return created
}

export function updateWaitlistStatus(id: string, status: WaitlistEntry['status']) {
  const db = loadPortalDb()
  const idx = db.waitlistEntries.findIndex((w) => w.id === id)
  if (idx === -1) return
  db.waitlistEntries[idx] = { ...db.waitlistEntries[idx], status }
  savePortalDb(db)
}

export function addFaqEntry(input: Omit<FaqEntry, 'id' | 'isPublished'>): FaqEntry {
  const db = loadPortalDb()
  const created: FaqEntry = {
    ...input,
    id: `faq-${Date.now()}`,
    isPublished: true,
  }
  db.faqs.push(created)
  savePortalDb(db)
  return created
}

export function toggleFaqPublished(id: string) {
  const db = loadPortalDb()
  const idx = db.faqs.findIndex((f) => f.id === id)
  if (idx === -1) return
  db.faqs[idx] = { ...db.faqs[idx], isPublished: !db.faqs[idx].isPublished }
  savePortalDb(db)
}

export function deleteFaqEntry(id: string) {
  const db = loadPortalDb()
  db.faqs = db.faqs.filter((f) => f.id !== id)
  savePortalDb(db)
}

