import { AlertTriangle, ArrowLeft, ArrowRight, CheckCircle2, Loader2 } from 'lucide-react'
import { useEffect } from 'react'
import { Link, useSearchParams } from 'react-router'
import { ApplyStep1Identity } from '@/components/portal/apply/ApplyStep1Identity'
import { ApplyStep2Credentials } from '@/components/portal/apply/ApplyStep2Credentials'
import { ApplyStep3Account } from '@/components/portal/apply/ApplyStep3Account'
import { usePsychologistApplyForm, type WizardStep } from '@/hooks/usePsychologistApplyForm'
import { cn } from '@/lib/cn'

const STEP_LABELS: Record<WizardStep, string> = {
  1: '1. Profil Klinis',
  2: '2. STR & SIP',
  3: '3. Akun & Kirim',
}

export function PsychologistApplyPage() {
  const [searchParams] = useSearchParams()
  const revisionPsyId = searchParams.get('revisi')
  const form = usePsychologistApplyForm(revisionPsyId)
  const year = new Date().getFullYear()

  useEffect(() => {
    document.title = form.isRevisionMode
      ? 'Perbaikan Pendaftaran Psikolog : EVA'
      : 'Pendaftaran Psikolog Profesional Mandiri : EVA'
    window.scrollTo(0, 0)
  }, [form.isRevisionMode])

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
            <img src="/eva_logo.png" alt="EVA" className="size-10 object-contain" />
            <span className="text-lg font-bold tracking-[-0.02em] text-ink">EVA</span>
          </Link>
          <h1 className="mt-2.5 text-[20px] font-semibold tracking-[-0.015em] text-ink">
            {form.isRevisionMode
              ? 'Perbaikan Data Psikolog Profesional'
              : 'Pendaftaran Psikolog Profesional Mandiri'}
          </h1>
          <p className="mt-1 max-w-md text-xs text-ink-soft">
            {form.isRevisionMode
              ? 'Perbarui data kredensial STR/SIP Anda sesuai catatan verifikasi Admin EVA.'
              : 'Bergabung sebagai psikolog independen terverifikasi untuk layanan telekonsultasi online 30 menit di EVA.'}
          </p>
        </div>

        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-6 shadow-[0_1px_3px_rgba(15,23,42,0.04)] sm:p-7">
          {form.submittedPsychologist ? (
            <div role="status" className="py-2">
              <div className="flex items-start gap-3 rounded-[10px] border border-success/30 bg-success/5 p-4">
                <CheckCircle2 className="mt-0.5 size-5 shrink-0 text-success" />
                <div>
                  <h2 className="text-base font-semibold text-ink">
                    {form.isRevisionMode
                      ? 'Perbaikan Berkas Berhasil Dikirim Ulang'
                      : 'Pendaftaran Psikolog Berhasil Dikirim'}
                  </h2>
                  <p className="mt-1 text-xs leading-relaxed text-ink-soft">
                    Data kredensial untuk{' '}
                    <strong className="font-semibold text-ink">
                      {form.submittedPsychologist.fullName}, {form.submittedPsychologist.titleDegree}
                    </strong>{' '}
                    (STR <span className="font-mono">{form.submittedPsychologist.strNumber}</span>)
                    telah masuk ke antrean verifikasi Admin EVA. Setelah disetujui, akun dapat
                    langsung digunakan pada aplikasi <strong>Eva Counselor Mobile</strong>.
                  </p>
                </div>
              </div>
              <div className="mt-5 flex items-center justify-end gap-2">
                <Link
                  to="/login"
                  className="inline-flex h-10 items-center justify-center rounded-[8px] bg-primary px-5 text-xs font-semibold text-white transition-colors hover:bg-[#464BB8]"
                >
                  Cek Status di Halaman Masuk
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

              {form.isRevisionMode && form.revisionTarget?.verificationNotes && (
                <div className="mb-5 flex items-start gap-2.5 rounded-[8px] border border-crisis-border bg-crisis-bg p-3 text-xs leading-relaxed text-crisis-text">
                  <AlertTriangle className="mt-0.5 size-4 shrink-0" />
                  <div>
                    <span className="font-semibold">Catatan Admin: </span>
                    <span>{form.revisionTarget.verificationNotes}</span>
                  </div>
                </div>
              )}

              {form.step === 1 && (
                <ApplyStep1Identity
                  fullName={form.fullName}
                  titleDegree={form.titleDegree}
                  city={form.city}
                  education={form.education}
                  yearsOfExperience={form.yearsOfExperience}
                  specializations={form.specializations}
                  bio={form.bio}
                  errors={form.errors}
                  onFullNameChange={(val) => {
                    form.setFullName(val)
                    form.clearError('fullName')
                  }}
                  onTitleDegreeChange={(val) => {
                    form.setTitleDegree(val)
                    form.clearError('titleDegree')
                  }}
                  onCityChange={(val) => {
                    form.setCity(val)
                    form.clearError('city')
                  }}
                  onEducationChange={form.setEducation}
                  onYearsChange={(val) => {
                    form.setYearsOfExperience(val)
                    form.clearError('yearsOfExperience')
                  }}
                  onToggleSpecialization={form.toggleSpecialization}
                  onBioChange={form.setBio}
                />
              )}

              {form.step === 2 && (
                <ApplyStep2Credentials
                  strNumber={form.strNumber}
                  sipNumber={form.sipNumber}
                  association={form.association}
                  certificateDocUrl={form.certificateDocUrl}
                  practiceSchedule={form.practiceSchedule}
                  errors={form.errors}
                  onStrNumberChange={(val) => {
                    form.setStrNumber(val)
                    form.clearError('strNumber')
                  }}
                  onSipNumberChange={form.setSipNumber}
                  onAssociationChange={(val) => {
                    form.setAssociation(val)
                    form.clearError('association')
                  }}
                  onCertificateDocUrlChange={form.setCertificateDocUrl}
                  onPracticeScheduleChange={(val) => {
                    form.setPracticeSchedule(val)
                    form.clearError('practiceSchedule')
                  }}
                />
              )}

              {form.step === 3 && (
                <ApplyStep3Account
                  fullName={form.fullName}
                  titleDegree={form.titleDegree}
                  strNumber={form.strNumber}
                  sipNumber={form.sipNumber}
                  city={form.city}
                  email={form.email}
                  phone={form.phone}
                  password={form.password}
                  showPassword={form.showPassword}
                  isRevisionMode={form.isRevisionMode}
                  errors={form.errors}
                  onEditStep1={() => form.setStep(1)}
                  onEmailChange={(val) => {
                    form.setEmail(val)
                    form.clearError('email')
                  }}
                  onPhoneChange={(val) => {
                    form.setPhone(val)
                    form.clearError('phone')
                  }}
                  onPasswordChange={(val) => {
                    form.setPassword(val)
                    form.clearError('password')
                  }}
                  onToggleShowPassword={() => form.setShowPassword((v) => !v)}
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
                    Sudah mendaftar? Cek Status
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
                        <span>Mengirim…</span>
                      </>
                    ) : (
                      <span>
                        {form.isRevisionMode
                          ? 'Simpan Perbaikan & Kirim Ulang'
                          : 'Kirim Pendaftaran Psikolog'}
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
        © {year} EVA. Empathetic Vitality Assistant
      </footer>
    </div>
  )
}
