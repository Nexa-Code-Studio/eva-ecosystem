import {
  buildPsychologistCertificates,
  buildSimulatedMobilePsychologist,
} from '@/data/mock/psychologists.mock'
import { getActivePortalDataSource, loadPortalDb, savePortalDb } from './storage'
import type {
  AdminPsychologistCoinAdjustRequestDto,
  AdminPsychologistCoinAdjustResultDto,
  RegisterPsychologistRequestDto,
  SimulateMobilePsychologistInput,
  SubmitPsychologistApplicationResultDto,
  VerifyPsychologistRequestDto,
} from '@/types/api/contracts'
import type {
  Psychologist,
  PsychologistCoinTransaction,
  PsychologistStatus,
} from '@/types/domain/portal'

export function simulateMobilePsychologistSubmission(
  input: SimulateMobilePsychologistInput,
): Psychologist {
  const db = loadPortalDb()
  const created = buildSimulatedMobilePsychologist(input)
  db.psychologists.unshift(created)
  savePortalDb(db)
  return created
}

export async function registerPsychologistApplication(
  payload: RegisterPsychologistRequestDto,
): Promise<SubmitPsychologistApplicationResultDto> {
  try {
    const psychologist = await getActivePortalDataSource().registerPsychologist(payload)
    return { ok: true, psychologist }
  } catch (err) {
    return {
      ok: false,
      error:
        err instanceof Error
          ? err.message
          : 'Gagal mengirim pendaftaran psikolog. Silakan periksa kembali data Anda.',
    }
  }
}

export function resubmitPsychologistApplication(
  psychologistId: string,
  payload: RegisterPsychologistRequestDto,
): Psychologist | null {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
  if (idx === -1) return null

  const today = new Date().toISOString().slice(0, 10)
  const existing = db.psychologists[idx]
  const docs = buildPsychologistCertificates({
    fullName: `${payload.full_name.trim()}, ${payload.title_degree.trim()}`,
    strNumber: payload.str_number.trim().toUpperCase(),
    sipNumber: payload.sip_number?.trim().toUpperCase() || null,
    association: payload.association.trim(),
    education: payload.education?.trim() || existing.education,
    verified: false,
  })

  const updated: Psychologist = {
    ...existing,
    fullName: payload.full_name.trim(),
    titleDegree: payload.title_degree.trim(),
    email: payload.email.trim(),
    password: payload.password || existing.password,
    phone: payload.phone?.trim() || existing.phone,
    city: payload.city?.trim().toUpperCase() || existing.city,
    education: payload.education?.trim() || existing.education,
    strNumber: payload.str_number.trim().toUpperCase(),
    sipNumber: payload.sip_number?.trim().toUpperCase() || null,
    association: payload.association.trim(),
    specializations: payload.specializations,
    yearsOfExperience: payload.years_of_experience,
    bio: payload.bio?.trim() || null,
    certificateDocUrl: payload.certificate_doc_url?.trim() || docs[0]?.fileName || null,
    verificationStatus: 'pending',
    verificationNotes: null,
    verifiedAt: null,
    submittedAt: today,
    documents: docs,
  }

  db.psychologists[idx] = updated
  savePortalDb(db)
  return updated
}

export async function fetchAdminPsychologists(): Promise<Psychologist[]> {
  return getActivePortalDataSource().fetchAdminPsychologists()
}

export async function fetchAdminPsychologistTransactions(
  psychologistId: string,
): Promise<PsychologistCoinTransaction[]> {
  return getActivePortalDataSource().fetchAdminPsychologistTransactions(psychologistId)
}

export async function adjustPsychologistCoins(
  payload: AdminPsychologistCoinAdjustRequestDto,
): Promise<AdminPsychologistCoinAdjustResultDto> {
  return getActivePortalDataSource().adjustPsychologistCoins(payload)
}

export async function reviewPsychologistVerification(
  psychologistId: string,
  payload: VerifyPsychologistRequestDto,
): Promise<Psychologist> {
  return getActivePortalDataSource().verifyPsychologist(psychologistId, payload)
}

export function updatePsychologistStatus(id: string, status: PsychologistStatus) {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === id)
  if (idx === -1) return
  db.psychologists[idx] = {
    ...db.psychologists[idx],
    status,
    isOnline: status === 'active',
  }
  savePortalDb(db)
}

export async function suspendPsychologistAccount(
  id: string,
  notes?: string,
): Promise<Psychologist> {
  return getActivePortalDataSource().updatePsychologistAccountStatus(id, 'suspended', notes)
}

export async function reactivatePsychologistAccount(
  id: string,
  notes?: string,
): Promise<Psychologist> {
  return getActivePortalDataSource().updatePsychologistAccountStatus(id, 'verified', notes)
}

export function deletePsychologist(id: string) {
  const db = loadPortalDb()
  db.psychologists = db.psychologists.filter((p) => p.id !== id)
  savePortalDb(db)
}

export async function togglePsychologistDocumentVerified(
  psychologistId: string,
  docIdOrType: string,
): Promise<Psychologist> {
  return getActivePortalDataSource().togglePsychologistDocumentVerified(
    psychologistId,
    docIdOrType,
  )
}
