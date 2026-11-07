import { loadPortalDb, savePortalDb } from './storage'
import {
  buildSimulatedMobilePsychologist,
  buildSimulatedUpgradeDocuments,
} from '@/data/mock/psychologists.mock'
import type {
  Psychologist,
  PsychologistStatus,
  SimulateMobilePsychologistInput,
} from '@/types/portal'

export function simulateMobilePsychologistSubmission(
  input: SimulateMobilePsychologistInput,
): Psychologist {
  const db = loadPortalDb()
  const created = buildSimulatedMobilePsychologist(input)
  db.psychologists.unshift(created)
  savePortalDb(db)
  return created
}

export function simulateVolunteerUpgradeSubmission(
  psychologistId: string,
  targetRole: 'relawan_profesional',
  notes: string,
): Psychologist | null {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
  if (idx === -1) return null

  const psy = db.psychologists[idx]
  const today = new Date().toISOString().slice(0, 10)
  const upgradeDocs = buildSimulatedUpgradeDocuments(psy)

  db.psychologists[idx] = {
    ...psy,
    rejectionReason: undefined,
    upgradeRequest: {
      targetRole,
      requestedAt: today,
      notes,
      documents: upgradeDocs,
    },
  }

  savePortalDb(db)
  return db.psychologists[idx]
}

export function upsertPsychologist(
  input: Omit<Psychologist, 'id'> & { id?: string },
): Psychologist {
  const db = loadPortalDb()
  const role = input.role || (input.partnerId ? 'professional_mitra' : 'relawan_profesional')
  const practiceType = role === 'professional_mitra' ? 'faskes' : 'mandiri'
  const verificationStatus = input.verificationStatus ?? (input.partnerId ? 'approved' : 'pending')

  if (input.id) {
    const idx = db.psychologists.findIndex((p) => p.id === input.id)
    if (idx !== -1) {
      const existing = db.psychologists[idx]
      const nextRole =
        input.role || existing.role || (existing.partnerId ? 'professional_mitra' : 'relawan_profesional')
      const updated: Psychologist = {
        ...existing,
        ...input,
        role: nextRole,
        id: input.id,
      }
      db.psychologists[idx] = updated
      savePortalDb(db)
      return updated
    }
  }

  const created: Psychologist = {
    practiceType,
    verificationStatus,
    role,
    ...input,
    id: `psy-${Date.now()}`,
  }
  db.psychologists.unshift(created)
  savePortalDb(db)
  return created
}

export function updatePsychologistStatus(id: string, status: PsychologistStatus) {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === id)
  if (idx === -1) return
  db.psychologists[idx] = { ...db.psychologists[idx], status }
  savePortalDb(db)
}

export function deletePsychologist(id: string) {
  const db = loadPortalDb()
  db.psychologists = db.psychologists.filter((p) => p.id !== id)
  db.referrals = db.referrals.map((r) =>
    r.assignedPsychologistId === id
      ? { ...r, assignedPsychologistId: null, status: 'unassigned' }
      : r,
  )
  savePortalDb(db)
}

export function togglePsychologistDocumentVerified(psychologistId: string, docId: string) {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
  if (idx === -1) return
  const psy = db.psychologists[idx]
  const docs = psy.documents ?? []
  const upgradeDocs = psy.upgradeRequest?.documents ?? []

  const nextDocs = docs.map((d) => (d.id === docId ? { ...d, verified: !d.verified } : d))
  const nextUpgradeDocs = upgradeDocs.map((d) =>
    d.id === docId ? { ...d, verified: !d.verified } : d,
  )

  db.psychologists[idx] = {
    ...psy,
    documents: nextDocs,
    upgradeRequest: psy.upgradeRequest
      ? {
          ...psy.upgradeRequest,
          documents: nextUpgradeDocs,
        }
      : psy.upgradeRequest,
  }
  savePortalDb(db)
}

export function reviewIndependentPsychologist(
  psychologistId: string,
  decision: 'approved' | 'rejected' | 'suspended',
  rejectionReason?: string,
) {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
  if (idx === -1) return

  const today = new Date().toISOString().slice(0, 10)
  const currentDocs = db.psychologists[idx].documents ?? []

  db.psychologists[idx] = {
    ...db.psychologists[idx],
    verificationStatus: decision,
    status: decision === 'approved' ? 'active' : 'inactive',
    reviewedAt: today,
    rejectionReason:
      decision === 'rejected' ? rejectionReason?.trim() : db.psychologists[idx].rejectionReason,
    documents:
      decision === 'approved'
        ? currentDocs.map((d) => ({ ...d, verified: true }))
        : currentDocs,
  }
  savePortalDb(db)
}

export function approvePsychologistUpgrade(psychologistId: string) {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
  if (idx === -1) return
  const psy = db.psychologists[idx]
  if (!psy.upgradeRequest) return

  const targetRole = psy.upgradeRequest.targetRole
  const upgradeDocs = (psy.upgradeRequest.documents ?? []).map((d) => ({
    ...d,
    verified: true,
  }))
  const existingDocs = psy.documents ?? []
  const upgradeDocIds = new Set(upgradeDocs.map((d) => d.id))
  const mergedDocs = [
    ...existingDocs.filter((d) => !upgradeDocIds.has(d.id)),
    ...upgradeDocs,
  ]

  const sippDoc = upgradeDocs.find((d) => d.docType === 'SIPP')
  const strDoc = upgradeDocs.find((d) => d.docType === 'STR HIMPSI')

  const nextSippNumber =
    targetRole === 'relawan_profesional' && sippDoc?.documentNumber
      ? sippDoc.documentNumber
      : psy.sippNumber
  const nextStrNumber =
    targetRole === 'relawan_profesional' && strDoc?.documentNumber
      ? strDoc.documentNumber
      : psy.strNumber

  db.psychologists[idx] = {
    ...psy,
    role: targetRole,
    upgradeRequest: null,
    documents: mergedDocs,
    sippNumber: nextSippNumber,
    strNumber: nextStrNumber,
    rejectionReason: undefined,
  }
  savePortalDb(db)
}

export function rejectPsychologistUpgrade(psychologistId: string, reason?: string) {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
  if (idx === -1) return
  const psy = db.psychologists[idx]
  if (!psy.upgradeRequest) return

  db.psychologists[idx] = {
    ...psy,
    upgradeRequest: null,
    rejectionReason: reason ? `Pengajuan upgrade ditolak: ${reason.trim()}` : psy.rejectionReason,
  }
  savePortalDb(db)
}

export function requestPsychologistUpgrade(
  psychologistId: string,
  input: {
    targetRole: 'relawan_profesional'
    notes?: string
    documents?: Psychologist['documents']
  },
) {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
  if (idx === -1) return

  const today = new Date().toISOString().slice(0, 10)
  db.psychologists[idx] = {
    ...db.psychologists[idx],
    rejectionReason: undefined,
    upgradeRequest: {
      targetRole: input.targetRole,
      requestedAt: today,
      notes: input.notes,
      documents: input.documents,
    },
  }
  savePortalDb(db)
}
