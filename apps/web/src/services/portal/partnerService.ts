import { loadPortalDb, savePortalDb, setPortalSession } from './storage'
import { ADMIN_ACCOUNT } from '@/constants/portal'
import type { AuthResult, NewPartnerApplicationInput, PartnerAccount } from '@/types/portal'

export function authenticateUser(emailInput: string, passwordInput: string): AuthResult {
  const email = emailInput.trim().toLowerCase()
  const password = passwordInput

  if (email === ADMIN_ACCOUNT.email.toLowerCase() && password === ADMIN_ACCOUNT.password) {
    setPortalSession({
      role: 'admin',
      email: ADMIN_ACCOUNT.email,
      loginAt: new Date().toISOString(),
    })
    return { ok: true, role: 'admin' }
  }

  const db = loadPortalDb()
  const partner = db.partners.find((p) => p.email.toLowerCase() === email)

  if (!partner || partner.password !== password) {
    return {
      ok: false,
      error: 'Email atau kata sandi tidak sesuai dengan data akun terdaftar.',
    }
  }

  if (partner.status === 'approved') {
    setPortalSession({
      role: 'partner',
      email: partner.email,
      partnerId: partner.id,
      loginAt: new Date().toISOString(),
    })
  }

  return { ok: true, role: 'partner', partner }
}

export function submitPartnerApplication(
  input: NewPartnerApplicationInput,
): { ok: true; partner: PartnerAccount } | { ok: false; error: string } {
  const db = loadPortalDb()
  const exists = db.partners.some((p) => p.email.toLowerCase() === input.email.trim().toLowerCase())
  if (exists || input.email.trim().toLowerCase() === ADMIN_ACCOUNT.email) {
    return {
      ok: false,
      error:
        'Alamat email ini sudah terdaftar pada sistem. Gunakan email lain atau masuk ke akun Anda.',
    }
  }

  const today = new Date().toISOString().slice(0, 10)
  const newPartner: PartnerAccount = {
    ...input,
    id: `partner-${Date.now()}`,
    email: input.email.trim(),
    status: 'pending',
    submittedAt: today,
    acceptingReferrals: true,
  }

  db.partners.unshift(newPartner)
  savePortalDb(db)
  return { ok: true, partner: newPartner }
}

export function resubmitPartnerApplication(
  partnerId: string,
  updates: Partial<NewPartnerApplicationInput>,
): PartnerAccount | null {
  const db = loadPortalDb()
  const idx = db.partners.findIndex((p) => p.id === partnerId)
  if (idx === -1) return null

  const today = new Date().toISOString().slice(0, 10)
  const updated: PartnerAccount = {
    ...db.partners[idx],
    ...updates,
    status: 'pending',
    isResubmitted: true,
    resubmittedAt: today,
  }

  db.partners[idx] = updated
  savePortalDb(db)
  return updated
}

export function reviewPartnerApplication(
  partnerId: string,
  decision: 'approved' | 'rejected' | 'suspended',
  rejectionReason?: string,
) {
  const db = loadPortalDb()
  const idx = db.partners.findIndex((p) => p.id === partnerId)
  if (idx === -1) return

  const today = new Date().toISOString().slice(0, 10)
  db.partners[idx] = {
    ...db.partners[idx],
    status: decision,
    reviewedAt: today,
    rejectionReason:
      decision === 'rejected' ? rejectionReason?.trim() : db.partners[idx].rejectionReason,
    isResubmitted: decision === 'approved' ? false : db.partners[idx].isResubmitted,
  }
  savePortalDb(db)
}

export function updatePartnerFacilityProfile(
  partnerId: string,
  updates: Partial<
    Pick<
      PartnerAccount,
      | 'facilityName'
      | 'facilityType'
      | 'licenseNumber'
      | 'city'
      | 'address'
      | 'picName'
      | 'picRole'
      | 'phone'
      | 'website'
      | 'operatingHours'
      | 'bpjsSupported'
      | 'notes'
      | 'acceptingReferrals'
    >
  >,
) {
  const db = loadPortalDb()
  const idx = db.partners.findIndex((p) => p.id === partnerId)
  if (idx === -1) return
  db.partners[idx] = { ...db.partners[idx], ...updates }
  savePortalDb(db)
}

