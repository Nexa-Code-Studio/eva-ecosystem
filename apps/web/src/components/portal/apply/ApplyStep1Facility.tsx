import {
  FACILITY_TYPES,
  FORMAL_INPUT_CLASS,
  FORMAL_INPUT_ERR_CLASS,
} from '@/constants/portal'
import { cn } from '@/lib/cn'
import type { FacilityType } from '@/types/portal'

interface ApplyStep1FacilityProps {
  facilityName: string
  facilityType: FacilityType
  city: string
  licenseNumber: string
  address: string
  errors: Record<string, string>
  onFacilityNameChange: (val: string) => void
  onFacilityTypeChange: (val: FacilityType) => void
  onCityChange: (val: string) => void
  onLicenseNumberChange: (val: string) => void
  onAddressChange: (val: string) => void
}

export function ApplyStep1Facility({
  facilityName,
  facilityType,
  city,
  licenseNumber,
  address,
  errors,
  onFacilityNameChange,
  onFacilityTypeChange,
  onCityChange,
  onLicenseNumberChange,
  onAddressChange,
}: ApplyStep1FacilityProps) {
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <div className="sm:col-span-2">
        <label htmlFor="facilityName" className="mb-1.5 block text-xs font-medium text-ink">
          Nama Instansi / Fasilitas Kesehatan <span className="text-error">*</span>
        </label>
        <input
          id="facilityName"
          type="text"
          placeholder="Contoh: RSUP DR. SARDJITO / KLINIK PRATAMA SEHAT JIWA"
          value={facilityName}
          onChange={(e) => onFacilityNameChange(e.target.value.toUpperCase())}
          className={cn(
            FORMAL_INPUT_CLASS,
            'uppercase placeholder:normal-case',
            errors.facilityName && FORMAL_INPUT_ERR_CLASS,
          )}
        />
        {errors.facilityName && <p className="mt-1 text-xs text-error">{errors.facilityName}</p>}
      </div>

      <div>
        <label htmlFor="facilityType" className="mb-1.5 block text-xs font-medium text-ink">
          Jenis Fasilitas Kesehatan <span className="text-error">*</span>
        </label>
        <select
          id="facilityType"
          value={facilityType}
          onChange={(e) => onFacilityTypeChange(e.target.value as FacilityType)}
          className={FORMAL_INPUT_CLASS}
        >
          {FACILITY_TYPES.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label htmlFor="city" className="mb-1.5 block text-xs font-medium text-ink">
          Kota / Kabupaten <span className="text-error">*</span>
        </label>
        <input
          id="city"
          type="text"
          placeholder="Contoh: YOGYAKARTA / JAKARTA SELATAN"
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

      <div className="sm:col-span-2">
        <label htmlFor="licenseNumber" className="mb-1.5 block text-xs font-medium text-ink">
          Nomor Izin Operasional / Kode Faskes Kemenkes <span className="text-error">*</span>
        </label>
        <input
          id="licenseNumber"
          type="text"
          placeholder="Contoh: 3471015/KEMENKES/RS-A/2024"
          value={licenseNumber}
          onChange={(e) => onLicenseNumberChange(e.target.value.toUpperCase())}
          className={cn(
            FORMAL_INPUT_CLASS,
            'uppercase placeholder:normal-case',
            errors.licenseNumber && FORMAL_INPUT_ERR_CLASS,
          )}
        />
        {errors.licenseNumber && <p className="mt-1 text-xs text-error">{errors.licenseNumber}</p>}
      </div>

      <div className="sm:col-span-2">
        <label htmlFor="address" className="mb-1.5 block text-xs font-medium text-ink">
          Alamat Lengkap Fasilitas Kesehatan <span className="text-error">*</span>
        </label>
        <input
          id="address"
          type="text"
          placeholder="Nama jalan, nomor gedung, kecamatan, dan kode pos"
          value={address}
          onChange={(e) => onAddressChange(e.target.value)}
          className={cn(FORMAL_INPUT_CLASS, errors.address && FORMAL_INPUT_ERR_CLASS)}
        />
        {errors.address && <p className="mt-1 text-xs text-error">{errors.address}</p>}
      </div>
    </div>
  )
}

