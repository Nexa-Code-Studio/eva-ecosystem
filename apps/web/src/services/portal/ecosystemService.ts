import { loadPortalDb, savePortalDb } from './storage'
import type {
  AppUserStatus,
  CoinEconomyConfig,
  CoinPackage,
  CoinTransactionStatus,
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

export function adjustUserCoinBalance(userId: string, deltaCoins: number, reason: string) {
  const db = loadPortalDb()
  const idx = db.generalUsers.findIndex((u) => u.id === userId)
  if (idx === -1 || !Number.isFinite(deltaCoins) || deltaCoins === 0) return

  const usr = db.generalUsers[idx]
  const nextBalance = Math.max(0, (usr.coinBalance ?? 0) + Math.trunc(deltaCoins))
  db.generalUsers[idx] = {
    ...usr,
    coinBalance: nextBalance,
  }

  if (deltaCoins > 0) {
    const nowStr = new Date().toISOString().slice(0, 16).replace('T', ' ')
    db.coinTransactions.unshift({
      id: `trx-manual-${Date.now()}`,
      invoiceCode: `ADM-GRANT-${Date.now().toString().slice(-5)}`,
      userId: usr.id,
      userCode: usr.userCode,
      userDisplayName: usr.displayName,
      packageId: 'admin-grant',
      packageName: `Penyesuaian Admin (+${Math.trunc(deltaCoins)} Koin)`,
      coinsGranted: Math.trunc(deltaCoins),
      amountIdr: 0,
      paymentMethod: 'QRIS',
      status: 'completed',
      createdAt: nowStr,
      completedAt: nowStr,
      adminNotes: reason.trim() || 'Penambahan koin manual oleh Admin.',
    })
  }

  savePortalDb(db)
}

export function reviewCoinTransaction(
  transactionId: string,
  nextStatus: CoinTransactionStatus,
  adminNotes?: string,
) {
  const db = loadPortalDb()
  const idx = db.coinTransactions.findIndex((t) => t.id === transactionId)
  if (idx === -1) return

  const trx = db.coinTransactions[idx]
  const prevStatus = trx.status
  if (prevStatus === nextStatus) return

  const nowStr = new Date().toISOString().slice(0, 16).replace('T', ' ')
  const userIdx = db.generalUsers.findIndex((u) => u.id === trx.userId)

  if (userIdx !== -1) {
    const usr = db.generalUsers[userIdx]
    let nextCoins = usr.coinBalance ?? 0

    if (prevStatus !== 'completed' && nextStatus === 'completed') {
      nextCoins += trx.coinsGranted
    } else if (prevStatus === 'completed' && (nextStatus === 'refunded' || nextStatus === 'failed')) {
      nextCoins = Math.max(0, nextCoins - trx.coinsGranted)
    }

    db.generalUsers[userIdx] = {
      ...usr,
      coinBalance: nextCoins,
    }
  }

  db.coinTransactions[idx] = {
    ...trx,
    status: nextStatus,
    completedAt: nextStatus === 'completed' ? nowStr : trx.completedAt,
    adminNotes: adminNotes !== undefined ? adminNotes.trim() : trx.adminNotes,
  }

  savePortalDb(db)
}

export function updateCoinEconomyConfig(
  updates: Partial<Pick<CoinEconomyConfig, 'basePricePerCoinIdr' | 'freeTrialCoinsNewUser'>>,
) {
  const db = loadPortalDb()
  const today = new Date().toISOString().slice(0, 10)
  db.coinEconomyConfig = {
    ...db.coinEconomyConfig,
    ...updates,
    updatedAt: today,
  }
  savePortalDb(db)
}

export function upsertCoinPackage(input: Omit<CoinPackage, 'id'> & { id?: string }): CoinPackage {
  const db = loadPortalDb()
  if (input.id) {
    const idx = db.coinPackages.findIndex((p) => p.id === input.id)
    if (idx !== -1) {
      const updated: CoinPackage = {
        ...db.coinPackages[idx],
        ...input,
        id: input.id,
        code: input.code.trim().toUpperCase(),
      }
      db.coinPackages[idx] = updated
      savePortalDb(db)
      return updated
    }
  }

  const created: CoinPackage = {
    ...input,
    id: `pkg-${Date.now()}`,
    code: input.code.trim().toUpperCase(),
  }
  db.coinPackages.push(created)
  savePortalDb(db)
  return created
}

export function toggleCoinPackageActive(packageId: string) {
  const db = loadPortalDb()
  const idx = db.coinPackages.findIndex((p) => p.id === packageId)
  if (idx === -1) return
  db.coinPackages[idx] = {
    ...db.coinPackages[idx],
    isActive: !db.coinPackages[idx].isActive,
  }
  savePortalDb(db)
}

