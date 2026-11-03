import { CheckCircle2, Eye, EyeOff, Loader2 } from 'lucide-react'
import type { FormEvent } from 'react'
import { Link } from 'react-router'
import {
  FORMAL_INPUT_CLASS,
  FORMAL_INPUT_ERR_CLASS,
  FORMAL_PRIMARY_BTN_CLASS,
  FORMAL_SECONDARY_BTN_CLASS,
} from '@/constants/portal'
import { cn } from '@/lib/cn'

export type LoginViewMode = 'login' | 'forgot'
export type LoginSubmitState = 'idle' | 'submitting' | 'success'

interface LoginFormViewProps {
  mode: LoginViewMode
  email: string
  password: string
  showPassword: boolean
  rememberMe: boolean
  emailError: string | null
  passwordError: string | null
  authError: string | null
  submitState: LoginSubmitState
  onEmailChange: (value: string) => void
  onPasswordChange: (value: string) => void
  onToggleShowPassword: () => void
  onRememberMeChange: (checked: boolean) => void
  onSwitchMode: (mode: LoginViewMode) => void
  onLoginSubmit: (e: FormEvent<HTMLFormElement>) => void
  onForgotSubmit: (e: FormEvent<HTMLFormElement>) => void
}

export function LoginFormView({
  mode,
  email,
  password,
  showPassword,
  rememberMe,
  emailError,
  passwordError,
  authError,
  submitState,
  onEmailChange,
  onPasswordChange,
  onToggleShowPassword,
  onRememberMeChange,
  onSwitchMode,
  onLoginSubmit,
  onForgotSubmit,
}: LoginFormViewProps) {
  if (mode === 'forgot') {
    return (
      <>
        <div>
          <h1 className="text-[20px] font-semibold tracking-[-0.015em] text-ink">
            Atur ulang kata sandi
          </h1>
          <p className="mt-1 text-sm text-ink-soft">
            Masukkan alamat email terdaftar untuk menerima tautan pemulihan.
          </p>
        </div>

        {submitState === 'success' ? (
          <div
            role="status"
            className="mt-6 rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-4"
          >
            <div className="flex items-start gap-2.5">
              <CheckCircle2 className="mt-0.5 size-4.5 shrink-0 text-success" />
              <div>
                <p className="text-sm font-semibold text-ink">Tautan pemulihan dikirim</p>
                <p className="mt-1 text-xs leading-relaxed text-ink-soft">
                  Instruksi pengaturan ulang kata sandi telah dikirim ke{' '}
                  <strong className="font-semibold text-ink">{email.trim()}</strong>.
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={() => onSwitchMode('login')}
              className={cn(FORMAL_SECONDARY_BTN_CLASS, 'mt-4 w-full')}
            >
              Kembali ke Halaman Masuk
            </button>
          </div>
        ) : (
          <form onSubmit={onForgotSubmit} noValidate className="mt-6 space-y-4">
            <div>
              <label htmlFor="forgot-email" className="mb-1.5 block text-xs font-medium text-ink">
                Email Terdaftar
              </label>
              <input
                id="forgot-email"
                name="email"
                type="email"
                autoComplete="email"
                inputMode="email"
                placeholder="nama@institusi.id"
                value={email}
                aria-invalid={Boolean(emailError) || undefined}
                aria-describedby={emailError ? 'forgot-email-error' : undefined}
                onChange={(e) => onEmailChange(e.target.value)}
                className={cn(FORMAL_INPUT_CLASS, emailError && FORMAL_INPUT_ERR_CLASS)}
              />
              {emailError && (
                <p id="forgot-email-error" className="mt-1.5 text-xs text-error">
                  {emailError}
                </p>
              )}
            </div>

            <button
              id="forgot-submit"
              type="submit"
              disabled={submitState === 'submitting'}
              className={FORMAL_PRIMARY_BTN_CLASS}
            >
              {submitState === 'submitting' ? (
                <>
                  <Loader2 className="size-4 animate-spin" />
                  <span>Mengirim…</span>
                </>
              ) : (
                <span>Kirim Tautan Pemulihan</span>
              )}
            </button>

            <button
              type="button"
              onClick={() => onSwitchMode('login')}
              className="flex w-full cursor-pointer items-center justify-center py-1.5 text-xs font-medium text-ink-soft transition-colors hover:text-ink"
            >
              Kembali ke halaman masuk
            </button>
          </form>
        )}
      </>
    )
  }

  return (
    <>
      <div>
        <h1 className="text-[20px] font-semibold tracking-[-0.015em] text-ink">Masuk ke EVA</h1>
        <p className="mt-1 text-sm text-ink-soft">Masukkan email dan kata sandi akun Anda.</p>
      </div>

      {authError && (
        <div
          role="alert"
          className="mt-5 rounded-[8px] border border-crisis-border bg-crisis-bg px-3.5 py-3 text-xs font-medium text-crisis-text"
        >
          {authError}
        </div>
      )}

      <form onSubmit={onLoginSubmit} noValidate className="mt-6 space-y-4">
        <div>
          <label htmlFor="login-email" className="mb-1.5 block text-xs font-medium text-ink">
            Email
          </label>
          <input
            id="login-email"
            name="email"
            type="email"
            autoComplete="email"
            inputMode="email"
            placeholder="nama@institusi.id"
            value={email}
            aria-invalid={Boolean(emailError) || undefined}
            aria-describedby={emailError ? 'login-email-error' : undefined}
            onChange={(e) => onEmailChange(e.target.value)}
            className={cn(FORMAL_INPUT_CLASS, emailError && FORMAL_INPUT_ERR_CLASS)}
          />
          {emailError && (
            <p id="login-email-error" className="mt-1.5 text-xs text-error">
              {emailError}
            </p>
          )}
        </div>

        <div>
          <div className="mb-1.5 flex items-center justify-between">
            <label htmlFor="login-password" className="text-xs font-medium text-ink">
              Kata Sandi
            </label>
            <button
              type="button"
              onClick={() => onSwitchMode('forgot')}
              className="cursor-pointer text-xs font-medium text-primary transition-colors hover:text-primary-deep"
            >
              Lupa kata sandi?
            </button>
          </div>
          <div className="relative">
            <input
              id="login-password"
              name="password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="current-password"
              placeholder="Masukkan kata sandi"
              value={password}
              aria-invalid={Boolean(passwordError) || undefined}
              aria-describedby={passwordError ? 'login-password-error' : undefined}
              onChange={(e) => onPasswordChange(e.target.value)}
              className={cn(FORMAL_INPUT_CLASS, 'pr-10', passwordError && FORMAL_INPUT_ERR_CLASS)}
            />
            <button
              type="button"
              onClick={onToggleShowPassword}
              aria-label={showPassword ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi'}
              className="absolute inset-y-0 right-0 flex w-10 cursor-pointer items-center justify-center text-ink-soft transition-colors hover:text-ink"
            >
              {showPassword ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
            </button>
          </div>
          {passwordError && (
            <p id="login-password-error" className="mt-1.5 text-xs text-error">
              {passwordError}
            </p>
          )}
        </div>

        <div className="flex items-center pt-0.5">
          <label
            htmlFor="login-remember"
            className="inline-flex cursor-pointer select-none items-center gap-2 text-xs text-ink-soft"
          >
            <input
              id="login-remember"
              type="checkbox"
              checked={rememberMe}
              onChange={(e) => onRememberMeChange(e.target.checked)}
              className="size-3.5 cursor-pointer rounded-[4px] border-[#CBD5E1] accent-primary"
            />
            <span>Ingat saya di perangkat ini</span>
          </label>
        </div>

        <button
          id="login-submit"
          type="submit"
          disabled={submitState === 'submitting'}
          className={cn(FORMAL_PRIMARY_BTN_CLASS, 'mt-2')}
        >
          {submitState === 'submitting' ? (
            <>
              <Loader2 className="size-4 animate-spin" />
              <span>Memverifikasi…</span>
            </>
          ) : (
            <span>Masuk</span>
          )}
        </button>
      </form>

      <div className="mt-5 border-t border-[#E2E8F0] pt-4 text-center text-xs text-ink-soft">
        Instansi kesehatan belum terdaftar?{' '}
        <Link
          to="/pengajuan-mitra"
          className="font-semibold text-primary hover:text-primary-deep"
        >
          Ajukan kemitraan faskes
        </Link>
      </div>
    </>
  )
}

