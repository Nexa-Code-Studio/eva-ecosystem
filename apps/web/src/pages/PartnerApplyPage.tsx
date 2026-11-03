import { AlertTriangle, ArrowLeft, ArrowRight, CheckCircle2, Loader2 } from 'lucide-react'
import { useEffect } from 'react'
import { Link, useSearchParams } from 'react-router'
import { ApplyStep1Facility } from '@/components/portal/apply/ApplyStep1Facility'
import { ApplyStep2PicOperational } from '@/components/portal/apply/ApplyStep2PicOperational'
import { ApplyStep3AccountConfirm } from '@/components/portal/apply/ApplyStep3AccountConfirm'
import { LunaOrb } from '@/components/ui'
import { usePartnerApplyForm, type WizardStep } from '@/hooks/usePartnerApplyForm'
import { cn } from '@/lib/cn'

const STEP_LABELS: Record<WizardStep, string> = {
  1: '1. Data Faskes',
  2: '2. PIC & Layanan',
  3: '3. Akun & Kirim',
}

export function PartnerApplyPage() {
  const [searchParams] = useSearchParams()
  const revisionPartnerId = searchParams.get('revisi')
  const form = usePartnerApplyForm(revisionPartnerId)
  const year = new Date().getFullYear()

  useEffect(() => {
    window.scrollTo(0, 0)
  }, [])

  return (
    <div className="flex min-h-[100dvh] flex-col justify-between bg-[#F8F9FE] px-4 py-6 sm:px-6 sm:py-8">
      <header className="mx-auto flex w-full max-w-4xl items-center justify-between">
        <Link
          to="/login"
          className="inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft transition-colors hover:text-ink"
        >
          <ArrowLeft className="size-4" />
          <span>Kembali ke Halaman Masuk</span>
        </Link>
        <Link to="/" className="text-xs font-medium text-ink-soft hover:text-primary">
          Beranda EVA
        </Link>
      </header>

      <main id="main-content" className="mx-auto my-6 w-full max-w-xl">
        <div className="mb-5 flex flex-col items-center text-center">
          <Link to="/" className="inline-flex flex-col items-center gap-2">
            <LunaOrb className="size-10" />
            <span className="text-lg font-bold tracking-[-0.02em] text-ink">EVA</span>
          </Link>
          <h1 className="mt-2.5 text-[20px] font-semibold tracking-[-0.015em] text-ink">
            {form.isRevisionMode
              ? 'Perbaikan Pengajuan Mitra Faskes'
              : 'Pengajuan Mitra Fasilitas Kesehatan'}
          </h1>
          <p className="mt-1 max-w-md text-xs text-ink-soft">
            {form.isRevisionMode
              ? 'Perbarui data fasilitas kesehatan Anda sesuai catatan verifikasi Admin.'
              : 'Daftarkan Rumah Sakit, Klinik, atau Biro Psikologi Anda ke ekosistem EVA.'}
          </p>
        </div>

        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-6 shadow-[0_1px_3px_rgba(15,23,42,0.04)] sm:p-7">
          {form.submittedPartner ? (
            <div role="status" className="py-2">
              <div className="flex items-start gap-3 rounded-[10px] border border-success/30 bg-success/5 p-4">
                <CheckCircle2 className="mt-0.5 size-5 shrink-0 text-success" />
                <div>
                  <h2 className="text-base font-semibold text-ink">
                    {form.isRevisionMode
                      ? 'Perbaikan Pengajuan Berhasil Dikirim Ulang'
                      : 'Pengajuan Kemitraan Berhasil Dikirim'}
                  </h2>
                  <p className="mt-1 text-xs leading-relaxed text-ink-soft">
                    Data untuk{' '}
                    <strong className="font-semibold text-ink">
                      {form.submittedPartner.facilityName}
                    </strong>{' '}
                    telah masuk ke antrean verifikasi Admin EVA. Akun Anda akan aktif setelah izin
                    operasional faskes disetujui.
                  </p>
                </div>
              </div>
              <div className="mt-5 flex items-center justify-end">
                <Link
                  to="/login"
                  className="inline-flex h-10 items-center justify-center rounded-[8px] bg-primary px-5 text-xs font-semibold text-white transition-colors hover:bg-[#464BB8]"
                >
                  Ke Halaman Masuk
                </Link>
              </div>
            </div>
          ) : (
            <form onSubmit={form.handleSubmit} noValidate>
              <div className="mb-5 grid grid-cols-3 gap-1.5">
                {([1, 2, 3] as const).map((s) => {
                  const isCurrent = form.step === s
                  const isReachable = form.isRevisionMode || s <= form.highestReachedStep
                  return (
                    <button
                      key={s}
                      type="button"
                      disabled={!isReachable}
                      onClick={() => form.handleJumpToStep(s)}
                      className={cn(
                        'h-8 rounded-[6px] px-2 text-xs font-medium transition-colors',
                        isCurrent
                          ? 'bg-primary-container/70 font-semibold text-primary'
                          : isReachable
                            ? 'cursor-pointer bg-[#F8FAFC] text-ink-soft hover:bg-[#F1F5F9] hover:text-ink'
                            : 'cursor-not-allowed bg-[#F8FAFC] text-ink-muted/60',
                      )}
                    >
                      {STEP_LABELS[s]}
                    </button>
                  )
                })}
              </div>

              {form.isRevisionMode && form.revisionTarget?.rejectionReason && (
                <div className="mb-5 flex items-start gap-2.5 rounded-[8px] border border-crisis-border bg-crisis-bg p-3 text-xs leading-relaxed text-crisis-text">
                  <AlertTriangle className="mt-0.5 size-4 shrink-0" />
                  <div>
                    <span className="font-semibold">Catatan Admin: </span>
                    <span>{form.revisionTarget.rejectionReason}</span>
                  </div>
                </div>
              )}

              {form.step === 1 && (
                <ApplyStep1Facility
                  facilityName={form.facilityName}
                  facilityType={form.facilityType}
                  city={form.city}
                  licenseNumber={form.licenseNumber}
                  address={form.address}
                  errors={form.errors}
                  onFacilityNameChange={(val) => {
                    form.setFacilityName(val)
                    form.clearError('facilityName')
                  }}
                  onFacilityTypeChange={form.setFacilityType}
                  onCityChange={(val) => {
                    form.setCity(val)
                    form.clearError('city')
                  }}
                  onLicenseNumberChange={(val) => {
                    form.setLicenseNumber(val)
                    form.clearError('licenseNumber')
                  }}
                  onAddressChange={(val) => {
                    form.setAddress(val)
                    form.clearError('address')
                  }}
                />
              )}

              {form.step === 2 && (
                <ApplyStep2PicOperational
                  picName={form.picName}
                  picRole={form.picRole}
                  phone={form.phone}
                  estimatedPsychologists={form.estimatedPsychologists}
                  operatingHours={form.operatingHours}
                  website={form.website}
                  bpjsSupported={form.bpjsSupported}
                  errors={form.errors}
                  onPicNameChange={(val) => {
                    form.setPicName(val)
                    form.clearError('picName')
                  }}
                  onPicRoleChange={(val) => {
                    form.setPicRole(val)
                    form.clearError('picRole')
                  }}
                  onPhoneChange={(val) => {
                    form.setPhone(val)
                    form.clearError('phone')
                  }}
                  onEstimatedPsychologistsChange={form.setEstimatedPsychologists}
                  onOperatingHoursChange={form.setOperatingHours}
                  onWebsiteChange={form.setWebsite}
                  onBpjsSupportedChange={form.setBpjsSupported}
                />
              )}

              {form.step === 3 && (
                <ApplyStep3AccountConfirm
                  facilityName={form.facilityName}
                  facilityType={form.facilityType}
                  licenseNumber={form.licenseNumber}
                  city={form.city}
                  picName={form.picName}
                  phone={form.phone}
                  email={form.email}
                  password={form.password}
                  showPassword={form.showPassword}
                  notes={form.notes}
                  errors={form.errors}
                  onEditStep1={() => form.setStep(1)}
                  onEmailChange={(val) => {
                    form.setEmail(val)
                    form.clearError('email')
                  }}
                  onPasswordChange={(val) => {
                    form.setPassword(val)
                    form.clearError('password')
                  }}
                  onToggleShowPassword={() => form.setShowPassword((v) => !v)}
                  onNotesChange={form.setNotes}
                />
              )}

              <div className="mt-6 flex items-center justify-between gap-3 border-t border-[#E2E8F0] pt-4">
                {form.step > 1 ? (
                  <button
                    type="button"
                    onClick={form.handlePrevStep}
                    className="inline-flex h-10 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-4 text-xs font-semibold text-ink transition-colors hover:bg-[#F8FAFC]"
                  >
                    <ArrowLeft className="size-3.5" />
                    <span>Sebelumnya</span>
                  </button>
                ) : (
                  <Link
                    to="/login"
                    className="text-xs font-medium text-ink-soft transition-colors hover:text-ink"
                  >
                    Sudah mengajukan? Masuk
                  </Link>
                )}

                {form.step < 3 ? (
                  <button
                    key="wizard-next-btn"
                    type="button"
                    onClick={form.handleNextStep}
                    className="inline-flex h-10 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-5 text-xs font-semibold text-white transition-colors hover:bg-[#464BB8]"
                  >
                    <span>Lanjutkan</span>
                    <ArrowRight className="size-3.5" />
                  </button>
                ) : (
                  <button
                    key="wizard-submit-btn"
                    type="submit"
                    disabled={form.submitting}
                    className="inline-flex h-10 cursor-pointer items-center gap-2 rounded-[8px] bg-primary px-5 text-xs font-semibold text-white transition-colors hover:bg-[#464BB8] disabled:opacity-60"
                  >
                    {form.submitting ? (
                      <>
                        <Loader2 className="size-4 animate-spin" />
                        <span>Menyimpan…</span>
                      </>
                    ) : (
                      <span>
                        {form.isRevisionMode
                          ? 'Simpan Perbaikan & Ajukan Ulang'
                          : 'Kirim Pengajuan Mitra'}
                      </span>
                    )}
                  </button>
                )}
              </div>
            </form>
          )}
        </div>
      </main>

      <footer className="mx-auto w-full max-w-4xl text-center text-xs text-ink-muted">
        © {year} EVA — Empathetic Vitality Assistant
      </footer>
    </div>
  )
}
