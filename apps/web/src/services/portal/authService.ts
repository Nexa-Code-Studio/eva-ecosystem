import {
  getAdminAccountConfig,
  loadPortalDb,
  setPortalSession,
} from './storage'
import type { AuthResult } from '@/types/api/contracts'

export function authenticateUser(emailInput: string, passwordInput: string): AuthResult {
  const email = emailInput.trim().toLowerCase()
  const password = passwordInput
  const adminAccount = getAdminAccountConfig()

  if (
    adminAccount.password &&
    email === adminAccount.email.toLowerCase() &&
    password === adminAccount.password
  ) {
    setPortalSession({
      role: 'admin',
      email: adminAccount.email,
      loginAt: new Date().toISOString(),
    })
    return { ok: true, role: 'admin' }
  }

  const db = loadPortalDb()
  const psychologist = db.psychologists.find((p) => p.email.toLowerCase() === email)

  if (psychologist && (!psychologist.password || psychologist.password === password)) {
    return { ok: true, role: 'counselor_status', psychologist }
  }

  return {
    ok: false,
    error: 'Email atau kata sandi tidak sesuai dengan data akun terdaftar.',
  }
}
