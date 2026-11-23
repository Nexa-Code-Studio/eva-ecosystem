import { getAdminAccountConfig, setPortalSession } from './storage'
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

  return {
    ok: false,
    error: 'Email atau kata sandi tidak sesuai dengan akun Admin terdaftar.',
  }
}
