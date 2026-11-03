import type { FacilityType } from '@/types/portal'

export const CLINICAL_SPECIALIZATIONS = [
  'Kecemasan & Panik',
  'Depresi & Mood',
  'Remaja & Mahasiswa',
  'Regulasi Emosi & Stres Akademik',
  'Trauma & Krisis',
  'Relasi & Keluarga',
] as const

export const FACILITY_TYPES: FacilityType[] = [
  'Rumah Sakit',
  'Klinik Utama',
  'Klinik Pratama',
  'Biro Psikologi',
]

export const ADMIN_ACCOUNT = {
  email: 'admin@eva.id',
  password: 'admin123',
  name: 'Administrator Pusat Ekosistem EVA',
}

export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
export const PHONE_RE = /^(\+62|62|0)[0-9]{8,13}$/

export const FORMAL_INPUT_CLASS =
  'h-10 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3.5 text-sm text-ink transition-[border-color,box-shadow] duration-150 outline-none placeholder:text-ink-muted focus:border-primary focus:ring-3 focus:ring-primary/12'

export const FORMAL_TEXTAREA_CLASS =
  'w-full rounded-[8px] border border-[#CBD5E1] bg-white p-3.5 text-sm text-ink transition-[border-color,box-shadow] duration-150 outline-none placeholder:text-ink-muted focus:border-primary focus:ring-3 focus:ring-primary/12'

export const FORMAL_INPUT_ERR_CLASS = 'border-error focus:border-error focus:ring-error/12'

export const FORMAL_PRIMARY_BTN_CLASS =
  'inline-flex h-10 w-full cursor-pointer select-none items-center justify-center gap-2 rounded-[8px] bg-primary px-4 text-sm font-semibold text-white transition-colors duration-150 hover:bg-[#464BB8] active:bg-[#3B3E99] disabled:pointer-events-none disabled:opacity-60'

export const FORMAL_SECONDARY_BTN_CLASS =
  'inline-flex h-9 cursor-pointer select-none items-center justify-center gap-2 rounded-[8px] border border-[#CBD5E1] bg-white px-3.5 text-xs font-semibold text-ink transition-colors duration-150 hover:bg-[#F8FAFC]'

