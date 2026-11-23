export const CLINICAL_SPECIALIZATIONS = [
  'Kecemasan Dewasa',
  'Depresi & Suasana Hati',
  'Manajemen Stres & Burnout',
  'Konseling Remaja & Akademik',
  'Hubungan & Komunikasi',
  'Trauma & Regulasi Emosi',
  'Quarter-life Crisis',
] as const

export const PROFESSIONAL_ASSOCIATIONS = [
  'Himpunan Psikologi Indonesia (HIMPSI)',
  'Ikatan Psikolog Klinis (IPK) Indonesia',
  'Asosiasi Psikologi Pendidikan Indonesia (APPI)',
] as const

export const EDUCATION_LEVELS = [
  'S2 Magister Psikologi Profesi (Psikolog Klinis)',
  'S2 Magister Psikologi Terapan',
  'S1 Sarjana Psikologi',
  'S3 Doktor Psikologi',
] as const

export const STANDARD_SESSION_DURATION_MINUTES = 30
export const EXTENDED_SESSION_DURATION_MINUTES = 60

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
