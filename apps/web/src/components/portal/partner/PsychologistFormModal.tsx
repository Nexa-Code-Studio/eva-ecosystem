import { X } from 'lucide-react'
import type { FormEvent } from 'react'
import { CLINICAL_SPECIALIZATIONS, FORMAL_INPUT_CLASS } from '@/constants/portal'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { cn } from '@/lib/cn'
import type { Psychologist, PsychologistStatus } from '@/types/portal'

interface PsychologistFormModalProps {
  isOpen: boolean
  editingPsy: Psychologist | null
  fullName: string
  sippNumber: string
  selectedSpecs: string[]
  practiceSchedule: string
  psyStatus: PsychologistStatus
  weeklyQuota: string
  yearsExperience: string
  education: string
  errors: Record<string, string>
  onClose: () => void
  onSubmit: (e: FormEvent<HTMLFormElement>) => void
  onFullNameChange: (val: string) => void
  onSippNumberChange: (val: string) => void
  onToggleSpec: (spec: string) => void
  onPracticeScheduleChange: (val: string) => void
  onStatusChange: (val: PsychologistStatus) => void
  onWeeklyQuotaChange: (val: string) => void
  onYearsExperienceChange: (val: string) => void
  onEducationChange: (val: string) => void
}

export function PsychologistFormModal({
  isOpen,
  editingPsy,
  fullName,
  sippNumber,
  selectedSpecs,
  practiceSchedule,
  psyStatus,
  weeklyQuota,
  yearsExperience,
  education,
  errors,
  onClose,
  onSubmit,
  onFullNameChange,
  onSippNumberChange,
  onToggleSpec,
  onPracticeScheduleChange,
  onStatusChange,
  onWeeklyQuotaChange,
  onYearsExperienceChange,
  onEducationChange,
}: PsychologistFormModalProps) {
  useBodyScrollLock(isOpen)

  if (!isOpen) return null

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="psy-modal-title"
      className="fixed inset-0 z-50 flex items-center justify-center bg-[#0F172A]/50 p-4"
    >
      <div className="max-h-[90dvh] w-full max-w-lg overflow-y-auto rounded-[12px] border border-[#E2E8F0] bg-white p-6 shadow-xl">
        <div className="flex items-center justify-between border-b border-[#E2E8F0] pb-3.5">
          <h2 id="psy-modal-title" className="text-base font-semibold text-ink">
            {editingPsy ? 'Edit Data Psikolog Klinis' : 'Tambah Psikolog Klinis Baru'}
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup modal"
            className="flex size-8 cursor-pointer items-center justify-center rounded-[6px] text-ink-soft hover:bg-[#F1F5F9] hover:text-ink"
          >
            <X className="size-4" />
          </button>
        </div>

        <form onSubmit={onSubmit} noValidate className="mt-4 space-y-4">
          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">
              Nama Lengkap &amp; Gelar Psikolog <span className="text-error">*</span>
            </label>
            <input
              type="text"
              placeholder="Contoh: Ayu Kartika Sari, M.Psi., Psikolog"
              value={fullName}
              onChange={(e) => onFullNameChange(e.target.value)}
              className={FORMAL_INPUT_CLASS}
            />
            {errors.fullName && <p className="mt-1 text-xs text-error">{errors.fullName}</p>}
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-1.5 block text-xs font-medium text-ink">
                Nomor SIPP / STR (HIMPSI) <span className="text-error">*</span>
              </label>
              <input
                type="text"
                placeholder="Contoh: 20190412-2024-02-0814"
                value={sippNumber}
                onChange={(e) => onSippNumberChange(e.target.value.toUpperCase())}
                className={cn(FORMAL_INPUT_CLASS, 'uppercase placeholder:normal-case')}
              />
              {errors.sippNumber && (
                <p className="mt-1 text-xs text-error">{errors.sippNumber}</p>
              )}
            </div>

            <div>
              <label className="mb-1.5 block text-xs font-medium text-ink">
                Status Praktik <span className="text-error">*</span>
              </label>
              <select
                value={psyStatus}
                onChange={(e) => onStatusChange(e.target.value as PsychologistStatus)}
                className={FORMAL_INPUT_CLASS}
              >
                <option value="active">Aktif Praktik</option>
                <option value="on_leave">Sedang Cuti</option>
                <option value="inactive">Nonaktif</option>
              </select>
            </div>
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">
              Spesialisasi Klinis <span className="text-error">*</span>
            </label>
            <div className="flex flex-wrap gap-1.5">
              {CLINICAL_SPECIALIZATIONS.map((spec) => {
                const active = selectedSpecs.includes(spec)
                return (
                  <button
                    key={spec}
                    type="button"
                    onClick={() => onToggleSpec(spec)}
                    className={cn(
                      'cursor-pointer rounded-[6px] border px-2.5 py-1 text-xs font-medium transition-colors',
                      active
                        ? 'border-primary bg-primary text-white'
                        : 'border-[#CBD5E1] bg-white text-ink-soft hover:text-ink',
                    )}
                  >
                    {spec}
                  </button>
                )
              })}
            </div>
            {errors.specializations && (
              <p className="mt-1 text-xs text-error">{errors.specializations}</p>
            )}
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">
              Hari &amp; Jam Praktik <span className="text-error">*</span>
            </label>
            <input
              type="text"
              placeholder="Contoh: Senin, Rabu, Jumat (08.30 – 15.00 WIB)"
              value={practiceSchedule}
              onChange={(e) => onPracticeScheduleChange(e.target.value)}
              className={FORMAL_INPUT_CLASS}
            />
            {errors.practiceSchedule && (
              <p className="mt-1 text-xs text-error">{errors.practiceSchedule}</p>
            )}
          </div>

          <div className="grid gap-4 border-t border-[#E2E8F0] pt-3 sm:grid-cols-2">
            <div>
              <label className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink">
                <span>Kuota Rujukan / Minggu</span>
                <span className="font-normal text-ink-muted">(Opsional)</span>
              </label>
              <input
                type="number"
                min={1}
                max={100}
                placeholder="Contoh: 10"
                value={weeklyQuota}
                onChange={(e) => onWeeklyQuotaChange(e.target.value)}
                className={FORMAL_INPUT_CLASS}
              />
            </div>

            <div>
              <label className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink">
                <span>Pengalaman Praktik (Tahun)</span>
                <span className="font-normal text-ink-muted">(Opsional)</span>
              </label>
              <input
                type="number"
                min={1}
                max={50}
                placeholder="Contoh: 6"
                value={yearsExperience}
                onChange={(e) => onYearsExperienceChange(e.target.value)}
                className={FORMAL_INPUT_CLASS}
              />
            </div>

            <div className="sm:col-span-2">
              <label className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink">
                <span>Pendidikan Profesi</span>
                <span className="font-normal text-ink-muted">(Opsional)</span>
              </label>
              <input
                type="text"
                placeholder="Contoh: Magister Profesi Psikologi Klinis UGM"
                value={education}
                onChange={(e) => onEducationChange(e.target.value)}
                className={FORMAL_INPUT_CLASS}
              />
            </div>
          </div>

          <div className="flex items-center justify-end gap-2.5 border-t border-[#E2E8F0] pt-4">
            <button
              type="button"
              onClick={onClose}
              className="inline-flex h-10 cursor-pointer items-center justify-center rounded-[8px] border border-[#CBD5E1] bg-white px-4 text-xs font-semibold text-ink hover:bg-[#F8FAFC]"
            >
              Batal
            </button>
            <button
              type="submit"
              className="inline-flex h-10 cursor-pointer items-center justify-center rounded-[8px] bg-primary px-5 text-xs font-semibold text-white hover:bg-[#464BB8]"
            >
              {editingPsy ? 'Simpan Perubahan' : 'Simpan Data Psikolog'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

