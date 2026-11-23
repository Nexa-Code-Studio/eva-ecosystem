import {
  buildPsychologistCertificates,
  buildSimulatedMobilePsychologist,
} from '@/data/mock/psychologists.mock'
import { getActivePortalDataSource, loadPortalDb, savePortalDb } from './storage'
import type {
  RegisterPsychologistRequestDto,
  SimulateMobilePsychologistInput,
  SubmitPsychologistApplicationResultDto,
  VerifyPsychologistRequestDto,
} from '@/types/api/contracts'
import type { Psychologist, PsychologistStatus } from '@/types/domain/portal'

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

export function suspendPsychologistAccount(id: string, notes?: string) {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === id)
  if (idx === -1) return
  db.psychologists[idx] = {
    ...db.psychologists[idx],
    verificationStatus: 'suspended',
    verificationNotes: notes?.trim() || db.psychologists[idx].verificationNotes,
    status: 'inactive',
    isOnline: false,
    reviewedAt: new Date().toISOString().slice(0, 10),
  }
  savePortalDb(db)
}

export function deletePsychologist(id: string) {
  const db = loadPortalDb()
  db.psychologists = db.psychologists.filter((p) => p.id !== id)
  savePortalDb(db)
}

export function togglePsychologistDocumentVerified(psychologistId: string, docId: string) {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
  if (idx === -1) return
  const psy = db.psychologists[idx]
  const docs = psy.documents ?? []

  db.psychologists[idx] = {
    ...psy,
    documents: docs.map((d) => (d.id === docId ? { ...d, verified: !d.verified } : d)),
  }
  savePortalDb(db)
}
