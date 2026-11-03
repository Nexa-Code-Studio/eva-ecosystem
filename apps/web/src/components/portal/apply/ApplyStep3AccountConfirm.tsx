import { Eye, EyeOff } from 'lucide-react'
import {
  FORMAL_INPUT_CLASS,
  FORMAL_INPUT_ERR_CLASS,
  FORMAL_TEXTAREA_CLASS,
} from '@/constants/portal'
import { cn } from '@/lib/cn'
import type { FacilityType } from '@/types/portal'

interface ApplyStep3AccountConfirmProps {
  facilityName: string
  facilityType: FacilityType
  licenseNumber: string
  city: string
  picName: string
  phone: string
  email: string
  password: string
  showPassword: boolean
  notes: string
  errors: Record<string, string>
  onEditStep1: () => void
  onEmailChange: (val: string) => void
  onPasswordChange: (val: string) => void
  onToggleShowPassword: () => void
  onNotesChange: (val: string) => void
}

export function ApplyStep3AccountConfirm({
  facilityName,
  facilityType,
  licenseNumber,
  city,
  picName,
  phone,
  email,
  password,
  showPassword,
  notes,
  errors,
  onEditStep1,
  onEmailChange,
  onPasswordChange,
  onToggleShowPassword,
  onNotesChange,
}: ApplyStep3AccountConfirmProps) {
  return (
    <div className="space-y-4">
      <div className="rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-3 text-xs">
        <div className="flex items-center justify-between">
          <span className="font-semibold text-ink">
            {facilityName.trim() || 'Nama Faskes'} ({facilityType})
          </span>
          <button
            type="button"
            onClick={onEditStep1}
            className="cursor-pointer font-semibold text-primary hover:underline"
          >
            Ubah Data
          </button>
        </div>
        <p className="mt-1 text-ink-soft">
          Izin: {licenseNumber.trim() || '—'} · {city.trim() || '—'} · PIC: {picName.trim() || '—'}{' '}
          ({phone.trim() || '—'})
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label htmlFor="apply-email" className="mb-1.5 block text-xs font-medium text-ink">
            Email Login Instansi <span className="text-error">*</span>
          </label>
          <input
            id="apply-email"
            type="email"
            autoComplete="email"
            placeholder="mitra@nama-rs.co.id"
            value={email}
            onChange={(e) => onEmailChange(e.target.value)}
            className={cn(FORMAL_INPUT_CLASS, errors.email && FORMAL_INPUT_ERR_CLASS)}
          />
          {errors.email && <p className="mt-1 text-xs text-error">{errors.email}</p>}
        </div>

        <div>
          <label htmlFor="apply-password" className="mb-1.5 block text-xs font-medium text-ink">
            Kata Sandi Akun <span className="text-error">*</span>
          </label>
          <div className="relative">
            <input
              id="apply-password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="new-password"
              placeholder="Minimal 6 karakter"
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

        <div className="sm:col-span-2">
          <label
            htmlFor="notes"
            className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink"
          >
            <span>Catatan Tambahan Layanan / Rujukan</span>
            <span className="font-normal text-ink-muted">(Opsional)</span>
          </label>
          <textarea
            id="notes"
            rows={2}
            placeholder="Informasi cakupan layanan konseling atau catatan untuk tim verifikasi EVA"
            value={notes}
            onChange={(e) => onNotesChange(e.target.value)}
            className={FORMAL_TEXTAREA_CLASS}
          />
        </div>
      </div>
    </div>
  )
}

