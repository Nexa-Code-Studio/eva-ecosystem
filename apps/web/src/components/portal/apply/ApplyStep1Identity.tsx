import {
  CLINICAL_SPECIALIZATIONS,
  FORMAL_INPUT_CLASS,
  FORMAL_INPUT_ERR_CLASS,
  FORMAL_TEXTAREA_CLASS,
} from '@/constants/portal'
import { cn } from '@/lib/cn'

interface ApplyStep1IdentityProps {
  fullName: string
  titleDegree: string
  city: string
  education: string
  yearsOfExperience: string
  specializations: string[]
  bio: string
  errors: Record<string, string>
  onFullNameChange: (val: string) => void
  onTitleDegreeChange: (val: string) => void
  onCityChange: (val: string) => void
  onEducationChange: (val: string) => void
  onYearsChange: (val: string) => void
  onToggleSpecialization: (spec: string) => void
  onBioChange: (val: string) => void
}

export function ApplyStep1Identity({
  fullName,
  titleDegree,
  city,
  education,
  yearsOfExperience,
  specializations,
  bio,
  errors,
  onFullNameChange,
  onTitleDegreeChange,
  onCityChange,
  onEducationChange,
  onYearsChange,
  onToggleSpecialization,
  onBioChange,
}: ApplyStep1IdentityProps) {
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <div>
        <label htmlFor="psy-fullName" className="mb-1.5 block text-xs font-medium text-ink">
          Nama Lengkap (Tanpa Gelar) <span className="text-error">*</span>
        </label>
        <input
          id="psy-fullName"
          type="text"
          placeholder="Contoh: Larasati Kusumawardhani"
          value={fullName}
          onChange={(e) => onFullNameChange(e.target.value)}
          className={cn(FORMAL_INPUT_CLASS, errors.fullName && FORMAL_INPUT_ERR_CLASS)}
        />
        {errors.fullName && <p className="mt-1 text-xs text-error">{errors.fullName}</p>}
      </div>

      <div>
        <label htmlFor="psy-titleDegree" className="mb-1.5 block text-xs font-medium text-ink">
          Gelar Profesi <span className="text-error">*</span>
        </label>
        <input
          id="psy-titleDegree"
          type="text"
          placeholder="M.Psi., Psikolog"
          value={titleDegree}
          onChange={(e) => onTitleDegreeChange(e.target.value)}
          className={cn(FORMAL_INPUT_CLASS, errors.titleDegree && FORMAL_INPUT_ERR_CLASS)}
        />
        {errors.titleDegree && <p className="mt-1 text-xs text-error">{errors.titleDegree}</p>}
      </div>

      <div>
        <label htmlFor="psy-city" className="mb-1.5 block text-xs font-medium text-ink">
          Domisili Kota / Kabupaten <span className="text-error">*</span>
        </label>
        <input
          id="psy-city"
          type="text"
          placeholder="Contoh: JAKARTA SELATAN"
          value={city}
          onChange={(e) => onCityChange(e.target.value.toUpperCase())}
          className={cn(
            FORMAL_INPUT_CLASS,
            'uppercase placeholder:normal-case',
            errors.city && FORMAL_INPUT_ERR_CLASS,
          )}
        />
        {errors.city && <p className="mt-1 text-xs text-error">{errors.city}</p>}
      </div>

      <div>
        <label htmlFor="psy-years" className="mb-1.5 block text-xs font-medium text-ink">
          Pengalaman Praktik (Tahun) <span className="text-error">*</span>
        </label>
        <input
          id="psy-years"
          type="number"
          min={0}
          max={50}
          value={yearsOfExperience}
          onChange={(e) => onYearsChange(e.target.value)}
          className={cn(FORMAL_INPUT_CLASS, errors.yearsOfExperience && FORMAL_INPUT_ERR_CLASS)}
        />
        {errors.yearsOfExperience && (
          <p className="mt-1 text-xs text-error">{errors.yearsOfExperience}</p>
        )}
      </div>

      <div className="sm:col-span-2">
        <label htmlFor="psy-education" className="mb-1.5 block text-xs font-medium text-ink">
          Asal Pendidikan Magister Profesi <span className="text-ink-muted font-normal">(Opsional)</span>
        </label>
        <input
          id="psy-education"
          type="text"
          placeholder="Contoh: Magister Profesi Psikologi Klinis Universitas Indonesia"
          value={education}
          onChange={(e) => onEducationChange(e.target.value)}
          className={FORMAL_INPUT_CLASS}
        />
      </div>

      <div className="sm:col-span-2">
        <span className="mb-1.5 block text-xs font-medium text-ink">
          Bidang Spesialisasi Klinis <span className="text-error">*</span>
        </span>
        <div className="flex flex-wrap gap-2">
          {CLINICAL_SPECIALIZATIONS.map((spec) => {
            const active = specializations.includes(spec)
            return (
              <button
                key={spec}
                type="button"
                onClick={() => onToggleSpecialization(spec)}
                className={cn(
                  'cursor-pointer rounded-[8px] border px-3 py-1.5 text-xs font-medium transition-colors',
                  active
                    ? 'border-primary bg-primary text-white shadow-2xs'
                    : 'border-[#CBD5E1] bg-white text-ink-soft hover:border-primary/40 hover:text-ink',
                )}
              >
                {spec}
              </button>
            )
          })}
        </div>
        {errors.specializations && (
          <p className="mt-1.5 text-xs text-error">{errors.specializations}</p>
        )}
      </div>

      <div className="sm:col-span-2">
        <label htmlFor="psy-bio" className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink">
          <span>Profil Singkat &amp; Pendekatan Terapi</span>
          <span className="font-normal text-ink-muted">(Opsional)</span>
        </label>
        <textarea
          id="psy-bio"
          rows={2}
          placeholder="Ceritakan pendekatan klinis Anda (misal: CBT, ACT, Mindfulness) untuk ditampilkan ke pasien."
          value={bio}
          onChange={(e) => onBioChange(e.target.value)}
          className={FORMAL_TEXTAREA_CLASS}
        />
      </div>
    </div>
  )
}
