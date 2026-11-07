import { FORMAL_INPUT_CLASS, FORMAL_INPUT_ERR_CLASS } from '@/constants/portal'
import { cn } from '@/lib/cn'

interface ApplyStep2PicOperationalProps {
  picName: string
  picRole: string
  phone: string
  estimatedPsychologists: string
  operatingHours: string
  website: string
  bpjsSupported: boolean
  errors: Record<string, string>
  onPicNameChange: (val: string) => void
  onPicRoleChange: (val: string) => void
  onPhoneChange: (val: string) => void
  onEstimatedPsychologistsChange: (val: string) => void
  onOperatingHoursChange: (val: string) => void
  onWebsiteChange: (val: string) => void
  onBpjsSupportedChange: (val: boolean) => void
}

export function ApplyStep2PicOperational({
  picName,
  picRole,
  phone,
  estimatedPsychologists,
  operatingHours,
  website,
  bpjsSupported,
  errors,
  onPicNameChange,
  onPicRoleChange,
  onPhoneChange,
  onEstimatedPsychologistsChange,
  onOperatingHoursChange,
  onWebsiteChange,
  onBpjsSupportedChange,
}: ApplyStep2PicOperationalProps) {
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <div>
        <label htmlFor="picName" className="mb-1.5 block text-xs font-medium text-ink">
          Nama Lengkap &amp; Gelar PIC <span className="text-error">*</span>
        </label>
        <input
          id="picName"
          type="text"
          placeholder="Contoh: dr. Hendra Wijaya, Sp.KJ"
          value={picName}
          onChange={(e) => onPicNameChange(e.target.value)}
          className={cn(FORMAL_INPUT_CLASS, errors.picName && FORMAL_INPUT_ERR_CLASS)}
        />
        {errors.picName && <p className="mt-1 text-xs text-error">{errors.picName}</p>}
      </div>

      <div>
        <label htmlFor="picRole" className="mb-1.5 block text-xs font-medium text-ink">
          Jabatan Struktural / Fungsional <span className="text-error">*</span>
        </label>
        <input
          id="picRole"
          type="text"
          placeholder="Contoh: Kepala Poli Psikologi"
          value={picRole}
          onChange={(e) => onPicRoleChange(e.target.value)}
          className={cn(FORMAL_INPUT_CLASS, errors.picRole && FORMAL_INPUT_ERR_CLASS)}
        />
        {errors.picRole && <p className="mt-1 text-xs text-error">{errors.picRole}</p>}
      </div>

      <div>
        <label htmlFor="phone" className="mb-1.5 block text-xs font-medium text-ink">
          Nomor Telepon / WhatsApp Resmi <span className="text-error">*</span>
        </label>
        <input
          id="phone"
          type="tel"
          placeholder="Contoh: 081234567890"
          value={phone}
          onChange={(e) => onPhoneChange(e.target.value)}
          className={cn(FORMAL_INPUT_CLASS, errors.phone && FORMAL_INPUT_ERR_CLASS)}
        />
        {errors.phone && <p className="mt-1 text-xs text-error">{errors.phone}</p>}
      </div>

      <div>
        <label
          htmlFor="estimatedPsychologists"
          className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink"
        >
          <span>Estimasi Jumlah Psikolog</span>
          <span className="font-normal text-ink-muted">(Opsional)</span>
        </label>
        <input
          id="estimatedPsychologists"
          type="number"
          min={1}
          max={200}
          placeholder="Contoh: 5"
          value={estimatedPsychologists}
          onChange={(e) => onEstimatedPsychologistsChange(e.target.value)}
          className={FORMAL_INPUT_CLASS}
        />
      </div>

      <div>
        <label
          htmlFor="operatingHours"
          className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink"
        >
          <span>Jam Layanan Poli Psikologi</span>
          <span className="font-normal text-ink-muted">(Opsional)</span>
        </label>
        <input
          id="operatingHours"
          type="text"
          placeholder="Senin – Sabtu, 08.00 – 16.00"
          value={operatingHours}
          onChange={(e) => onOperatingHoursChange(e.target.value)}
          className={FORMAL_INPUT_CLASS}
        />
      </div>

      <div>
        <label
          htmlFor="website"
          className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink"
        >
          <span>Situs Web Resmi Faskes</span>
          <span className="font-normal text-ink-muted">(Opsional)</span>
        </label>
        <input
          id="website"
          type="url"
          placeholder="https://nama-faskes.co.id"
          value={website}
          onChange={(e) => onWebsiteChange(e.target.value)}
          className={FORMAL_INPUT_CLASS}
        />
      </div>

      <div className="sm:col-span-2 pt-0.5">
        <label
          htmlFor="bpjsSupported"
          className="inline-flex cursor-pointer select-none items-center gap-2 text-xs text-ink-soft"
        >
          <input
            id="bpjsSupported"
            type="checkbox"
            checked={bpjsSupported}
            onChange={(e) => onBpjsSupportedChange(e.target.checked)}
            className="size-3.5 cursor-pointer rounded-[4px] border-[#CBD5E1] accent-primary"
          />
          <span>
            Fasilitas kesehatan melayani penjaminan BPJS Kesehatan{' '}
            <span className="text-ink-muted">(Opsional)</span>
          </span>
        </label>
      </div>
    </div>
  )
}

