import { FileCheck2, Video } from 'lucide-react'
import {
  FORMAL_INPUT_CLASS,
  FORMAL_INPUT_ERR_CLASS,
  PROFESSIONAL_ASSOCIATIONS,
} from '@/constants/portal'
import { cn } from '@/lib/cn'

interface ApplyStep2CredentialsProps {
  strNumber: string
  sipNumber: string
  association: string
  certificateDocUrl: string
  practiceSchedule: string
  errors: Record<string, string>
  onStrNumberChange: (val: string) => void
  onSipNumberChange: (val: string) => void
  onAssociationChange: (val: string) => void
  onCertificateDocUrlChange: (val: string) => void
  onPracticeScheduleChange: (val: string) => void
}

export function ApplyStep2Credentials({
  strNumber,
  sipNumber,
  association,
  certificateDocUrl,
  practiceSchedule,
  errors,
  onStrNumberChange,
  onSipNumberChange,
  onAssociationChange,
  onCertificateDocUrlChange,
  onPracticeScheduleChange,
}: ApplyStep2CredentialsProps) {
  return (
    <div className="space-y-4">
      <div className="flex items-start gap-2.5 rounded-[10px] border border-[#C7D2FE] bg-[#EEF0FF]/60 p-3 text-xs text-ink">
        <Video className="mt-0.5 size-4 shrink-0 text-primary" />
        <p className="leading-relaxed text-ink-soft">
          Seluruh sesi konseling di EVA dijalankan secara <strong className="text-ink">100% telekonsultasi video daring berdurasi 30 menit</strong> melalui aplikasi <strong className="text-ink">Eva Counselor Mobile</strong> tanpa praktik tatap muka/offline.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label htmlFor="psy-strNumber" className="mb-1.5 block text-xs font-medium text-ink">
            Nomor STR Aktif <span className="text-error">*</span>
          </label>
          <input
            id="psy-strNumber"
            type="text"
            placeholder="Contoh: STR-PK-2024-884120"
            value={strNumber}
            onChange={(e) => onStrNumberChange(e.target.value.toUpperCase())}
            className={cn(
              FORMAL_INPUT_CLASS,
              'font-mono uppercase placeholder:font-sans placeholder:normal-case',
              errors.strNumber && FORMAL_INPUT_ERR_CLASS,
            )}
          />
          {errors.strNumber && <p className="mt-1 text-xs text-error">{errors.strNumber}</p>}
        </div>

        <div>
          <label htmlFor="psy-sipNumber" className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink">
            <span>Nomor SIP / SIPP</span>
            <span className="font-normal text-ink-muted">(Direkomendasikan)</span>
          </label>
          <input
            id="psy-sipNumber"
            type="text"
            placeholder="Contoh: 20240618-2029-01-1402"
            value={sipNumber}
            onChange={(e) => onSipNumberChange(e.target.value.toUpperCase())}
            className={cn(
              FORMAL_INPUT_CLASS,
              'font-mono uppercase placeholder:font-sans placeholder:normal-case',
            )}
          />
        </div>

        <div className="sm:col-span-2">
          <label htmlFor="psy-association" className="mb-1.5 block text-xs font-medium text-ink">
            Organisasi / Asosiasi Profesi <span className="text-error">*</span>
          </label>
          <select
            id="psy-association"
            value={association}
            onChange={(e) => onAssociationChange(e.target.value)}
            className={cn(FORMAL_INPUT_CLASS, errors.association && FORMAL_INPUT_ERR_CLASS)}
          >
            {PROFESSIONAL_ASSOCIATIONS.map((assoc) => (
              <option key={assoc} value={assoc}>
                {assoc}
              </option>
            ))}
          </select>
          {errors.association && <p className="mt-1 text-xs text-error">{errors.association}</p>}
        </div>

        <div className="sm:col-span-2">
          <label
            htmlFor="psy-certificateUrl"
            className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink"
          >
            <span>Tautan Dokumen STR &amp; SIP (Google Drive / PDF URL)</span>
            <span className="font-normal text-ink-muted">(Opsional)</span>
          </label>
          <div className="relative">
            <input
              id="psy-certificateUrl"
              type="url"
              placeholder="https://drive.google.com/file/d/... (salinan STR & SIPP)"
              value={certificateDocUrl}
              onChange={(e) => onCertificateDocUrlChange(e.target.value)}
              className={cn(FORMAL_INPUT_CLASS, 'pl-9')}
            />
            <FileCheck2 className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-ink-muted" />
          </div>
          <p className="mt-1 text-[11px] text-ink-muted">
            Jika belum memiliki tautan PDF, Anda tetap dapat mengunggah salinan berkas langsung dari aplikasi mobile setelah akun dibuat.
          </p>
        </div>

        <div className="sm:col-span-2">
          <label htmlFor="psy-schedule" className="mb-1.5 block text-xs font-medium text-ink">
            Estimasi Jam Layanan Telekonsultasi <span className="text-error">*</span>
          </label>
          <input
            id="psy-schedule"
            type="text"
            placeholder="Contoh: Senin - Jumat (18.00 - 21.00 WIB)"
            value={practiceSchedule}
            onChange={(e) => onPracticeScheduleChange(e.target.value)}
            className={cn(FORMAL_INPUT_CLASS, errors.practiceSchedule && FORMAL_INPUT_ERR_CLASS)}
          />
          {errors.practiceSchedule && (
            <p className="mt-1 text-xs text-error">{errors.practiceSchedule}</p>
          )}
        </div>
      </div>
    </div>
  )
}
