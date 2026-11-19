import { Eye, EyeOff, ShieldCheck } from 'lucide-react'
import { FORMAL_INPUT_CLASS, FORMAL_INPUT_ERR_CLASS } from '@/constants/portal'
import { cn } from '@/lib/cn'

interface ApplyStep3AccountProps {
  fullName: string
  titleDegree: string
  strNumber: string
  sipNumber: string
  city: string
  email: string
  phone: string
  password: string
  showPassword: boolean
  isRevisionMode: boolean
  errors: Record<string, string>
  onEditStep1: () => void
  onEmailChange: (val: string) => void
  onPhoneChange: (val: string) => void
  onPasswordChange: (val: string) => void
  onToggleShowPassword: () => void
}

export function ApplyStep3Account({
  fullName,
  titleDegree,
  strNumber,
  sipNumber,
  city,
  email,
  phone,
  password,
  showPassword,
  isRevisionMode,
  errors,
  onEditStep1,
  onEmailChange,
  onPhoneChange,
  onPasswordChange,
  onToggleShowPassword,
}: ApplyStep3AccountProps) {
  return (
    <div className="space-y-4">
      <div className="rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5 text-xs">
        <div className="flex items-center justify-between gap-2">
          <span className="font-semibold text-ink">
            {fullName.trim() || 'Nama Psikolog'}, {titleDegree.trim()}
          </span>
          <button
            type="button"
            onClick={onEditStep1}
            className="cursor-pointer font-semibold text-primary hover:underline"
          >
            Ubah Data
          </button>
        </div>
        <p className="mt-1 font-mono text-[11px] text-ink-soft">
          STR: {strNumber.trim() || '-'} {sipNumber.trim() ? `· SIP: ${sipNumber.trim()}` : ''} ·{' '}
          {city.trim() || 'INDONESIA'}
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label htmlFor="apply-email" className="mb-1.5 block text-xs font-medium text-ink">
            Email Akun Psikolog <span className="text-error">*</span>
          </label>
          <input
            id="apply-email"
            type="email"
            autoComplete="email"
            placeholder="nama@psikolog.id"
            value={email}
            onChange={(e) => onEmailChange(e.target.value)}
            className={cn(FORMAL_INPUT_CLASS, errors.email && FORMAL_INPUT_ERR_CLASS)}
          />
          {errors.email && <p className="mt-1 text-xs text-error">{errors.email}</p>}
        </div>

        <div>
          <label htmlFor="apply-phone" className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink">
            <span>Nomor WhatsApp Aktif</span>
            <span className="font-normal text-ink-muted">(Opsional)</span>
          </label>
          <input
            id="apply-phone"
            type="tel"
            placeholder="081234567890"
            value={phone}
            onChange={(e) => onPhoneChange(e.target.value)}
            className={cn(FORMAL_INPUT_CLASS, errors.phone && FORMAL_INPUT_ERR_CLASS)}
          />
          {errors.phone && <p className="mt-1 text-xs text-error">{errors.phone}</p>}
        </div>

        <div className="sm:col-span-2">
          <label htmlFor="apply-password" className="mb-1.5 block text-xs font-medium text-ink">
            Kata Sandi Akun {isRevisionMode ? '(Opsional jika tidak diubah)' : <span className="text-error">*</span>}
          </label>
          <div className="relative">
            <input
              id="apply-password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="new-password"
              placeholder="Minimal 8 karakter"
              value={password}
              onChange={(e) => onPasswordChange(e.target.value)}
              className={cn(FORMAL_INPUT_CLASS, 'pr-10', errors.password && FORMAL_INPUT_ERR_CLASS)}
            />
            <button
              type="button"
              onClick={onToggleShowPassword}
              aria-label={showPassword ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi'}
              className="absolute inset-y-0 right-0 flex w-10 cursor-pointer items-center justify-center text-ink-soft hover:text-ink"
            >
              {showPassword ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
            </button>
          </div>
          {errors.password && <p className="mt-1 text-xs text-error">{errors.password}</p>}
        </div>
      </div>

      <div className="flex items-start gap-2.5 rounded-[10px] border border-[#E2E8F0] bg-white p-3 text-[11px] text-ink-soft">
        <ShieldCheck className="mt-0.5 size-4 shrink-0 text-emerald-600" />
        <p className="leading-relaxed">
          Dengan mengirim formulir ini, dokumen STR/SIP Anda akan diperiksa oleh tim Admin EVA. Setelah status berubah menjadi <strong className="text-ink">Terverifikasi</strong>, akun langsung aktif untuk membuka jadwal sesi 30 menit di aplikasi <strong className="text-ink">Eva Counselor Mobile</strong>.
        </p>
      </div>
    </div>
  )
}
