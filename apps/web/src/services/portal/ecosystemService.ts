import { getActivePortalDataSource, loadPortalDb, savePortalDb } from './storage'
import type {
  AdminCoinTopupRequestDto,
  AdminCoinTopupResultDto,
  CreateFaqRequestDto,
  PublicFaqsResultDto,
  UpdateCoinEconomyConfigRequestDto,
  UpdateCrisisConfigRequestDto,
  UpdateFaqRequestDto,
  UpsertCoinPackageRequestDto,
} from '@/types/api/contracts'
import type {
  AppUserStatus,
  CoinEconomyConfig,
  CoinPackage,
  CoinTopupTransaction,
  CoinTransactionStatus,
  ConsultationSessionMonitoring,
  CopingQuest,
  CrisisConfig,
  FaqEntry,
  GeneralAppUser,
  WaitlistEntry,
} from '@/types/portal'

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

export async function fetchCrisisConfig(): Promise<CrisisConfig> {
  return getActivePortalDataSource().fetchCrisisConfig()
}

export async function updateCrisisConfig(
  updates: UpdateCrisisConfigRequestDto,
): Promise<CrisisConfig> {
  return getActivePortalDataSource().updateCrisisConfig(updates)
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

export async function fetchPublicFaqs(): Promise<PublicFaqsResultDto> {
  return getActivePortalDataSource().fetchPublicFaqs()
}

export async function fetchAdminFaqs(): Promise<FaqEntry[]> {
  return getActivePortalDataSource().fetchAdminFaqs()
}

export async function addFaqEntry(input: CreateFaqRequestDto): Promise<FaqEntry> {
  return getActivePortalDataSource().createFaqEntry(input)
}

export async function updateFaqEntry(
  id: string,
  input: UpdateFaqRequestDto,
): Promise<FaqEntry> {
  return getActivePortalDataSource().updateFaqEntry(id, input)
}

export async function toggleFaqPublished(id: string): Promise<FaqEntry> {
  return getActivePortalDataSource().toggleFaqPublished(id)
}

export async function deleteFaqEntry(id: string): Promise<void> {
  return getActivePortalDataSource().deleteFaqEntry(id)
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

export async function fetchCoinEconomyConfig(): Promise<CoinEconomyConfig> {
  return getActivePortalDataSource().fetchCoinEconomyConfig()
}

export async function updateCoinEconomyConfig(
  updates: UpdateCoinEconomyConfigRequestDto,
): Promise<CoinEconomyConfig> {
  return getActivePortalDataSource().updateCoinEconomyConfig(updates)
}

export async function fetchCoinPackages(): Promise<CoinPackage[]> {
  return getActivePortalDataSource().fetchCoinPackages()
}

export async function upsertCoinPackage(
  input: UpsertCoinPackageRequestDto,
): Promise<CoinPackage> {
  return getActivePortalDataSource().upsertCoinPackage(input)
}

export async function deleteCoinPackage(packageId: string): Promise<void> {
  return getActivePortalDataSource().deleteCoinPackage(packageId)
}

export async function toggleCoinPackageActive(packageId: string): Promise<CoinPackage> {
  return getActivePortalDataSource().toggleCoinPackageActive(packageId)
}

export async function fetchConsultationSessions(): Promise<ConsultationSessionMonitoring[]> {
  return getActivePortalDataSource().fetchConsultationSessions()
}

export async function fetchAdminUsers(): Promise<GeneralAppUser[]> {
  return getActivePortalDataSource().fetchAdminUsers()
}

export async function fetchCoinTransactions(): Promise<CoinTopupTransaction[]> {
  return getActivePortalDataSource().fetchCoinTransactions()
}

export async function topUpUserCoins(
  payload: AdminCoinTopupRequestDto,
): Promise<AdminCoinTopupResultDto> {
  return getActivePortalDataSource().topUpUserCoins(payload)
}

