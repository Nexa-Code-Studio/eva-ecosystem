import { APP_CONFIG } from '@/config/appConfig'
import { getAdminAccountConfig, setPortalSession } from './storage'
import type { AuthResult, BackendAuthTokenResponseDto } from '@/types/api/contracts'

export async function authenticateUser(
  emailInput: string,
  passwordInput: string,
): Promise<AuthResult> {
  const email = emailInput.trim().toLowerCase()
  const password = passwordInput
  const adminAccount = getAdminAccountConfig()

  if (APP_CONFIG.useMockData) {
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

  try {
    const baseUrl = APP_CONFIG.apiBaseUrl.replace(/\/+$/, '')
    const response = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    })

    if (!response.ok) {
      let detail = 'Email atau kata sandi tidak valid.'
      try {
        const err = (await response.json()) as { detail?: string }
        if (err?.detail) detail = err.detail
      } catch {
        // Ignore parse error
      }
      return { ok: false, error: detail }
    }

    const data = (await response.json()) as BackendAuthTokenResponseDto
    if (!data.user?.is_admin) {
      return {
        ok: false,
        error: 'Akun ini tidak memiliki hak akses Administrator EVA.',
      }
    }

    setPortalSession({
      role: 'admin',
      email: data.user.email,
      accessToken: data.access_token,
      loginAt: new Date().toISOString(),
    })
    return { ok: true, role: 'admin', accessToken: data.access_token }
  } catch {
    return {
      ok: false,
      error: 'Tidak dapat terhubung ke server autentikasi backend EVA.',
    }
  }
}
