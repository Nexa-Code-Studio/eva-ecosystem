import { ArrowLeft } from 'lucide-react'
import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router'
import {
  LoginFormView,
  type LoginSubmitState,
  type LoginViewMode,
} from '@/components/portal/login/LoginFormView'
import { PartnerStatusModal } from '@/components/portal/login/PartnerStatusModal'
import { LunaOrb } from '@/components/ui'
import { DEMO_CONFIG } from '@/config/demoConfig'
import { EMAIL_RE } from '@/constants/portal'
import { DemoAccountsMenu } from '@/demo/features/DemoAccountsMenu'
import { authenticateUser, usePortalDb, type PartnerAccount } from '@/lib/portalStore'

export function LoginPage() {
  const navigate = useNavigate()
  const { db } = usePortalDb()

  const [mode, setMode] = useState<LoginViewMode>('login')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [rememberMe, setRememberMe] = useState(false)

  const [emailError, setEmailError] = useState<string | null>(null)
  const [passwordError, setPasswordError] = useState<string | null>(null)
  const [authError, setAuthError] = useState<string | null>(null)
  const [submitState, setSubmitState] = useState<LoginSubmitState>('idle')

  const [statusModalPartner, setStatusModalPartner] = useState<PartnerAccount | null>(null)
  const [demoMenuOpen, setDemoMenuOpen] = useState(false)

  const year = new Date().getFullYear()

  useEffect(() => {
    window.scrollTo(0, 0)
  }, [])

  useEffect(() => {
    if (!statusModalPartner) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setStatusModalPartner(null)
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [statusModalPartner])

  const switchMode = (nextMode: LoginViewMode) => {
    setMode(nextMode)
    setEmailError(null)
    setPasswordError(null)
    setAuthError(null)
    setSubmitState('idle')
  }

  const fillDemoCredentials = (demoEmail: string, demoPassword: string) => {
    setMode('login')
    setEmail(demoEmail)
    setPassword(demoPassword)
    setEmailError(null)
    setPasswordError(null)
    setAuthError(null)
    setStatusModalPartner(null)
    setDemoMenuOpen(false)
  }

  const handleLoginSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (submitState === 'submitting') return

    const trimmedEmail = email.trim()
    let valid = true

    if (!EMAIL_RE.test(trimmedEmail)) {
      setEmailError('Masukkan alamat email yang valid.')
      valid = false
    } else {
      setEmailError(null)
    }

    if (!password) {
      setPasswordError('Kata sandi wajib diisi.')
      valid = false
    } else {
      setPasswordError(null)
    }

    if (!valid) return

    setAuthError(null)
    setSubmitState('submitting')

    window.setTimeout(() => {
      const result = authenticateUser(trimmedEmail, password)
      setSubmitState('idle')

      if (!result.ok) {
        setAuthError(result.error)
        return
      }

      if (result.role === 'admin') {
        navigate('/admin')
        return
      }

      const partner = result.partner
      if (partner.status === 'approved') {
        navigate('/mitra')
        return
      }

      setStatusModalPartner(partner)
    }, 400)
  }

  const handleForgotSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (submitState === 'submitting') return

    const trimmedEmail = email.trim()
    if (!EMAIL_RE.test(trimmedEmail)) {
      setEmailError('Masukkan alamat email terdaftar yang valid.')
      return
    }

    setEmailError(null)
    setSubmitState('submitting')
    window.setTimeout(() => {
      setSubmitState('success')
    }, 600)
  }

  return (
    <div className="flex min-h-[100dvh] flex-col justify-between bg-[#F8F9FE] px-4 py-6 sm:px-6 sm:py-8">
      <header className="mx-auto flex w-full max-w-5xl items-center justify-between">
        <Link
          to="/"
          className="inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft transition-colors duration-150 hover:text-ink"
        >
          <ArrowLeft className="size-4" />
          <span>Kembali ke Beranda</span>
        </Link>
      </header>

      <main id="main-content" className="mx-auto my-8 w-full max-w-[400px]">
        <div className="mb-6 flex flex-col items-center text-center">
          <Link to="/" aria-label="EVA — Beranda" className="inline-flex flex-col items-center gap-3">
            <LunaOrb className="size-12" />
            <span className="text-xl font-bold tracking-[-0.02em] text-ink">EVA</span>
          </Link>
        </div>

        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-6 shadow-[0_1px_3px_rgba(15,23,42,0.04)] sm:p-8">
          <LoginFormView
            mode={mode}
            email={email}
            password={password}
            showPassword={showPassword}
            rememberMe={rememberMe}
            emailError={emailError}
            passwordError={passwordError}
            authError={authError}
            submitState={submitState}
            onEmailChange={(val) => {
              setEmail(val)
              if (emailError) setEmailError(null)
              if (authError) setAuthError(null)
            }}
            onPasswordChange={(val) => {
              setPassword(val)
              if (passwordError) setPasswordError(null)
              if (authError) setAuthError(null)
            }}
            onToggleShowPassword={() => setShowPassword((v) => !v)}
            onRememberMeChange={setRememberMe}
            onSwitchMode={switchMode}
            onLoginSubmit={handleLoginSubmit}
            onForgotSubmit={handleForgotSubmit}
          />
        </div>
      </main>

      <PartnerStatusModal
        partner={statusModalPartner}
        onClose={() => setStatusModalPartner(null)}
        onRevise={(partnerId) => {
          setStatusModalPartner(null)
          navigate(`/pengajuan-mitra?revisi=${encodeURIComponent(partnerId)}`)
        }}
      />

      {DEMO_CONFIG.showDemoAccountsOnLogin && (
        <DemoAccountsMenu
          isOpen={demoMenuOpen}
          partners={db.partners}
          onToggleOpen={() => setDemoMenuOpen((v) => !v)}
          onClose={() => setDemoMenuOpen(false)}
          onSelectCredentials={fillDemoCredentials}
        />
      )}

      <footer className="mx-auto w-full max-w-5xl text-center text-xs text-ink-muted">
        © {year} EVA — Empathetic Vitality Assistant
      </footer>
    </div>
  )
}
