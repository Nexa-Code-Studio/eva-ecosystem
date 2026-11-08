import type { FormEvent } from 'react'
import { FORMAL_INPUT_CLASS } from '@/constants/portal'
import { cn } from '@/lib/cn'
import type { FacilityType } from '@/types/portal'

interface PartnerProfileTabProps {
  profFacilityName: string
  profFacilityType: FacilityType
  profLicense: string
  profCity: string
  profPhone: string
  profAddress: string
  profPicName: string
  profPicRole: string
  profOperatingHours: string
  profWebsite: string
  profAccepting: boolean
  profBpjs: boolean
  profNotes: string
  onSaveProfile: (e: FormEvent<HTMLFormElement>) => void
  onFacilityNameChange: (val: string) => void
  onFacilityTypeChange: (val: FacilityType) => void
  onLicenseChange: (val: string) => void
  onCityChange: (val: string) => void
  onPhoneChange: (val: string) => void
  onAddressChange: (val: string) => void
  onPicNameChange: (val: string) => void
  onPicRoleChange: (val: string) => void
  onOperatingHoursChange: (val: string) => void
  onWebsiteChange: (val: string) => void
  onAcceptingChange: (val: boolean) => void
  onBpjsChange: (val: boolean) => void
  onNotesChange: (val: string) => void
}

export function PartnerProfileTab({
  profFacilityName,
  profFacilityType,
  profLicense,
  profCity,
  profPhone,
  profAddress,
  profPicName,
  profPicRole,
  profOperatingHours,
  profWebsite,
  profAccepting,
  profBpjs,
  profNotes,
  onSaveProfile,
  onFacilityNameChange,
  onFacilityTypeChange,
  onLicenseChange,
  onCityChange,
  onPhoneChange,
  onAddressChange,
  onPicNameChange,
  onPicRoleChange,
  onOperatingHoursChange,
  onWebsiteChange,
  onAcceptingChange,
  onBpjsChange,
  onNotesChange,
}: PartnerProfileTabProps) {
  return (
    <section className="mt-6" aria-label="Profil dan Operasional Faskes">
      <form
        onSubmit={onSaveProfile}
        className="rounded-[12px] border border-[#E2E8F0] bg-white p-6 shadow-[0_1px_2px_rgba(15,23,42,0.03)] sm:p-8"
      >
        <div className="border-b border-[#E2E8F0] pb-4">
          <h2 className="text-base font-semibold text-ink">
            Pengaturan Profil &amp; Operasional Fasilitas Kesehatan
          </h2>
          <p className="mt-0.5 text-xs text-ink-soft">
            Perbarui informasi layanan poli psikologi dan status penerimaan rujukan pasien dari
            aplikasi EVA.
          </p>
        </div>

        <div className="mt-5 grid gap-4 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <label className="mb-1.5 block text-xs font-medium text-ink">
              Nama Fasilitas Kesehatan <span className="text-error">*</span>
            </label>
            <input
              type="text"
              value={profFacilityName}
              onChange={(e) => onFacilityNameChange(e.target.value.toUpperCase())}
              className={cn(FORMAL_INPUT_CLASS, 'uppercase placeholder:normal-case')}
            />
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">
              Jenis Fasilitas Kesehatan
            </label>
            <select
              value={profFacilityType}
              onChange={(e) => onFacilityTypeChange(e.target.value as FacilityType)}
              className={FORMAL_INPUT_CLASS}
            >
              <option value="Rumah Sakit">Rumah Sakit</option>
              <option value="Klinik Utama">Klinik Utama</option>
              <option value="Klinik Pratama">Klinik Pratama</option>
              <option value="Biro Psikologi">Biro Psikologi</option>
            </select>
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">
              Nomor Izin Operasional / Kode Faskes
            </label>
            <input
              type="text"
              value={profLicense}
              onChange={(e) => onLicenseChange(e.target.value.toUpperCase())}
              className={cn(FORMAL_INPUT_CLASS, 'uppercase placeholder:normal-case')}
            />
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">Kota / Kabupaten</label>
            <input
              type="text"
              value={profCity}
              onChange={(e) => onCityChange(e.target.value.toUpperCase())}
              className={cn(FORMAL_INPUT_CLASS, 'uppercase placeholder:normal-case')}
            />
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">
              Nomor Telepon / WhatsApp Pendaftaran
            </label>
            <input
              type="tel"
              value={profPhone}
              onChange={(e) => onPhoneChange(e.target.value)}
              className={FORMAL_INPUT_CLASS}
            />
          </div>

          <div className="sm:col-span-2">
            <label className="mb-1.5 block text-xs font-medium text-ink">
              Alamat Lengkap Fasilitas Kesehatan
            </label>
            <input
              type="text"
              value={profAddress}
              onChange={(e) => onAddressChange(e.target.value)}
              className={FORMAL_INPUT_CLASS}
            />
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">
              Nama Penanggung Jawab (PIC)
            </label>
            <input
              type="text"
              value={profPicName}
              onChange={(e) => onPicNameChange(e.target.value)}
              className={FORMAL_INPUT_CLASS}
            />
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">Jabatan PIC</label>
            <input
              type="text"
              value={profPicRole}
              onChange={(e) => onPicRoleChange(e.target.value)}
              className={FORMAL_INPUT_CLASS}
            />
          </div>

          <div>
            <label className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink">
              <span>Jam Operasional Poli Psikologi</span>
              <span className="font-normal text-ink-muted">(Opsional)</span>
            </label>
            <input
              type="text"
              placeholder="Senin – Sabtu, 08.00 – 16.00 WIB"
              value={profOperatingHours}
              onChange={(e) => onOperatingHoursChange(e.target.value)}
              className={FORMAL_INPUT_CLASS}
            />
          </div>

          <div>
            <label className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink">
              <span>Situs Web Resmi Faskes</span>
              <span className="font-normal text-ink-muted">(Opsional)</span>
            </label>
            <input
              type="url"
              placeholder="https://nama-faskes.co.id"
              value={profWebsite}
              onChange={(e) => onWebsiteChange(e.target.value)}
              className={FORMAL_INPUT_CLASS}
            />
          </div>

          <div className="sm:col-span-2 space-y-2.5 pt-1">
            <label className="flex cursor-pointer select-none items-center gap-2.5 text-xs text-ink">
              <input
                type="checkbox"
                checked={profAccepting}
                onChange={(e) => onAcceptingChange(e.target.checked)}
                className="size-4 cursor-pointer rounded-[4px] border-[#CBD5E1] accent-primary"
              />
              <span className="font-medium">
                Fasilitas kesehatan aktif menerima rujukan pasien baru dari aplikasi EVA
              </span>
            </label>

            <label className="flex cursor-pointer select-none items-center gap-2.5 text-xs text-ink-soft">
              <input
                type="checkbox"
                checked={profBpjs}
                onChange={(e) => onBpjsChange(e.target.checked)}
                className="size-4 cursor-pointer rounded-[4px] border-[#CBD5E1] accent-primary"
              />
              <span>Melayani penjaminan BPJS Kesehatan (Opsional)</span>
            </label>
          </div>

          <div className="sm:col-span-2">
            <label className="mb-1.5 flex items-center justify-between text-xs font-medium text-ink">
              <span>Catatan Layanan Faskes</span>
              <span className="font-normal text-ink-muted">(Opsional)</span>
            </label>
            <textarea
              rows={2}
              value={profNotes}
              onChange={(e) => onNotesChange(e.target.value)}
              className="w-full rounded-[8px] border border-[#CBD5E1] bg-white p-3 text-sm text-ink outline-none focus:border-primary"
            />
          </div>
        </div>

        <div className="mt-6 flex justify-end border-t border-[#E2E8F0] pt-4">
          <button
            type="submit"
            className="inline-flex h-10 cursor-pointer items-center justify-center rounded-[8px] bg-primary px-6 text-sm font-semibold text-white transition-colors hover:bg-[#464BB8]"
          >
            Simpan Perubahan Profil
          </button>
        </div>
      </form>
    </section>
  )
}

